# engram-helpers.ps1 - Wrapper de la API HTTP de Engram para Atlas Harness RPG
# ===================================================================
# Invoca engram server via HTTP (puerto 7437 por default).
# No depende del binario engram.exe (que esta bloqueado por WDAC).
# Solo necista que el server este levantado: `engram serve` o MCP ya activo.
#Requires -Version 5.1

# --- Config ---
$script:ENGRAM_BASE = $env:ENGRAM_BASE
if (-not $script:ENGRAM_BASE) {
    $port = if ($env:ENGRAM_PORT) { $env:ENGRAM_PORT } else { "7437" }
    $script:ENGRAM_BASE = "http://127.0.0.1:$port"
}

# --- HTTP helper ---
function Invoke-Engram {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]$Method,
        [Parameter(Mandatory)] [string]$Path,
        [object]$Body,
        [int]$TimeoutSec = 10
    )
    $url = "$script:ENGRAM_BASE$Path"
    $params = @{
        Uri         = $url
        Method      = $Method
        TimeoutSec  = $TimeoutSec
        ErrorAction = "Stop"
    }
    if ($Body) {
        $params.ContentType = "application/json"
        if ($Body -is [string]) { $params.Body = $Body } else { $params.Body = $Body | ConvertTo-Json -Depth 10 -Compress }
    }
    try {
        $resp = Invoke-RestMethod @params
        return $resp
    } catch {
        if ($_.Exception.Response -and $_.Exception.Response.StatusCode) {
            $code = [int]$_.Exception.Response.StatusCode
            $msg = "Engram HTTP $code en $url"
        } else {
            $msg = "Engram unreachable: $($_.Exception.Message)"
        }
        Write-Warning "[engram] $msg"
        return $null
    }
}

# --- Health ---
function Test-EngramAlive {
    try {
        $r = Invoke-Engram -Method GET -Path "/health" -TimeoutSec 3
        return ($null -ne $r)
    } catch { return $false }
}

# === mem_save ===
# Guarda una observacion en engram.
# Campos:
#   title     (string, required)
#   type      (string: bugfix|decision|architecture|discovery|pattern|config|preference|action|verdict|recommendation)
#   scope     (string: project|agent:<name>), default "project"
#   topic_key (string, optional, recommended)
#   content   (string, required, markdown)
#   project_name (string, optional, default = git remote o cwd)
function Save-Memory {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]$Title,
        [Parameter(Mandatory)] [string]$Content,
        [string]$Type = "discovery",
        [string]$Scope = "project",
        [string]$TopicKey,
        [string]$ProjectName
    )
    $body = [ordered]@{
        title    = $Title
        type     = $Type
        scope    = $Scope
        content  = $Content
    }
    if ($TopicKey) { $body.topic_key = $TopicKey }
    if ($ProjectName) { $body.project_name = $ProjectName }
    $r = Invoke-Engram -Method POST -Path "/observations" -Body $body
    if ($r) {
        if ($r.observation_id) { return $r.observation_id }
        elseif ($r.id) { return $r.id }
        else { return $r }
    }
    return $null
}

# === mem_search ===
# Busca observaciones por FTS5 full-text.
function Search-Memory {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]$Query,
        [string]$ProjectName,
        [int]$Limit = 20
    )
    $q = "/search?q=$([uri]::EscapeDataString($Query))&limit=$Limit"
    if ($ProjectName) { $q += "&project=$([uri]::EscapeDataString($ProjectName))" }
    return Invoke-Engram -Method GET -Path $q
}

# === mem_context ===
# Contexto reciente de la sesion actual.
function Get-MemoryContext {
    [CmdletBinding()]
    param([string]$ProjectName)
    $q = "/context"
    if ($ProjectName) { $q += "?project=$([uri]::EscapeDataString($ProjectName))" }
    return Invoke-Engram -Method GET -Path $q
}

# === mem_get_observation ===
# Lee la observacion completa por ID.
function Get-Memory {
    [CmdletBinding()]
    param([Parameter(Mandatory)] [int]$Id)
    return Invoke-Engram -Method GET -Path "/observations/$Id"
}

# === mem_update ===
# Actualiza una observacion existente por ID.
function Update-Memory {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [int]$Id,
        [string]$Content,
        [string]$Title
    )
    $body = [ordered]@{ id = $Id }
    if ($Content) { $body.content = $Content }
    if ($Title) { $body.title = $Title }
    return Invoke-Engram -Method PUT -Path "/observations/$Id" -Body $body
}

# === list recent ===
# (API usada por el plugin TUI opencode-sdd-engram-manage)
function Get-RecentMemories {
    [CmdletBinding()]
    param(
        [string]$ProjectName,
        [int]$Limit = 50
    )
    $q = "/observations/recent?limit=$Limit"
    if ($ProjectName) { $q += "&project=$([uri]::EscapeDataString($ProjectName))" }
    return Invoke-Engram -Method GET -Path $q
}

# === delete ===
# Borrado logico de una observacion.
function Remove-Memory {
    [CmdletBinding()]
    param([Parameter(Mandatory)] [int]$Id)
    return Invoke-Engram -Method DELETE -Path "/observations/$Id"
}

# === mem_suggest_topic_key ===
# Sugerencia de topic_key para una observacion.
function Suggest-TopicKey {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]$Content,
        [Parameter(Mandatory)] [string]$Type
    )
    $body = @{ content = $Content; type = $Type }
    return Invoke-Engram -Method POST -Path "/suggest" -Body $body
}

# === mem_session_summary ===
# Guarda el resumen de sesion al cerrar o antes de compaction.
function Save-SessionSummary {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]$Summary,
        [string]$ProjectName
    )
    $body = [ordered]@{
        summary     = $Summary
        type        = "session_summary"
        scope       = "project"
        topic_key   = "atlas/session-summary"
    }
    if ($ProjectName) { $body.project_name = $ProjectName }
    return Invoke-Engram -Method POST -Path "/sessions" -Body $body
}

# === Project helpers ===
function Get-CurrentProject {
    try {
        $root = (Get-Location).Path
        $g = Get-Item "$root\.git" -EA SilentlyContinue
        if ($g) {
            $remote = git remote get-url origin 2>$null
            if ($remote -match "github\.com[/:]([^/]+/[^/]+?)(\.git)?$") {
                return $Matches[1]
            }
        }
    } catch {}
    return (Split-Path -Leaf (Get-Location).Path)
}

# === Exports ===
# NOTA: Este archivo se carga via dot-source (. $h) desde atlas.ps1, NO como modulo.
# Por eso NO usamos Export-ModuleMember — las funciones y aliases quedan
# disponibles automaticamente en el scope del caller.
#
# Funcion:                Alias:
#   Invoke-Engram
#   Test-EngramAlive
#   Save-Memory              mem_save
#   Search-Memory            mem_search
#   Get-MemoryContext        mem_context
#   Get-Memory               mem_get_observation
#   Update-Memory            mem_update
#   Get-RecentMemories
#   Remove-Memory
#   Suggest-TopicKey         mem_suggest_topic_key
#   Save-SessionSummary      mem_session_summary
#   Get-CurrentProject
