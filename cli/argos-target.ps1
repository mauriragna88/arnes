#Requires -Version 5.1
<#
.SYNOPSIS
ARGOS TARGET - selecciona y lanza el CLI de trabajo (OpenCode, Codex o Claude)
cargando el entorno ARNES (agentes/personas).

.DESCRIPTION
El puente entre ARNES y el CLI que quieras usar:
  opencode  -> sincroniza los 16 agentes con modelo propio (~/.config/opencode/agents) y abre opencode
  codex     -> despliega la persona Atlas a ~/.codex/AGENTS.md y abre codex
  claude    -> despliega la persona Atlas a ~/.claude/CLAUDE.md y abre claude

El default queda guardado en ~/.config/arnes/target.json (UNA vez por maquina).
Para opencode/codex/claude, el modelo lo gestiona el propio CLI; ARNES aporta
personas, agentes y memoria (.arnes/arnes.db accesible por archivo).

.EXAMPLE
.\argos-target.ps1                        # lanza el default (opencode si no hay config)
.\argos-target.ps1 -Target auto           # menu si hay varios CLIs instalados
.\argos-target.ps1 -Target codex -Quest "haz login con Zod"
.\argos-target.ps1 set codex              # fija el default
.\argos-target.ps1 show
.\argos-target.ps1 list
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet('', 'launch', 'set', 'show', 'list')]
    [string]$Command = 'launch',

    [Parameter(Position = 1)]
    [ValidateSet('', 'opencode', 'codex', 'claude', 'auto')]
    [string]$Target = '',

    [string]$Name = '',
    [string]$Quest = '',

    # Overrides para tests (hermetico)
    [string]$ConfigDir = '',
    [string]$TargetDir = '',
    [switch]$NoLaunch
)

$ErrorActionPreference = 'Stop'
$Root = Resolve-Path (Join-Path $PSScriptRoot '..')
$PersonaFile = Join-Path $Root 'core\atlas-player.agent.md'

if (-not $ConfigDir) { $ConfigDir = Join-Path $env:USERPROFILE '.config\arnes' }
if (-not $TargetDir) { $TargetDir = $ConfigDir }
$TargetFile = Join-Path $ConfigDir 'target.json'

# ==== Targets disponibles ====
$TargetMeta = @{
    opencode = 'OpenCode (16 agentes + modelos por agente)'
    codex    = 'Codex CLI (persona Atlas en AGENTS.md)'
    claude   = 'Claude Code (persona Atlas en CLAUDE.md)'
}

function Get-InstalledTargets {
    $result = @()
    if (Get-Command opencode -ErrorAction SilentlyContinue) { $result += 'opencode' }
    if (Get-Command codex -ErrorAction SilentlyContinue) { $result += 'codex' }
    if (Get-Command claude -ErrorAction SilentlyContinue) { $result += 'claude' }
    return $result
}

# Read-Input local: devuelve vacio en modo NO interactivo (igual que argos.ps1)
function Read-Input {
    param([string]$Prompt = '')
    try { return Read-Host $Prompt } catch { return '' }
}

function Get-CurrentTarget {
    if (Test-Path $TargetFile) {
        try {
            $cfg = Get-Content $TargetFile -Raw | ConvertFrom-Json
            if ($cfg.target) { return [string]$cfg.target }
        } catch { }
    }
    return 'opencode'
}

function Write-AtlasPersona {
    param([string]$Target)
    if (-not (Test-Path $PersonaFile)) {
        Write-Host '  [!] No se encontro core/atlas-player.agent.md' -ForegroundColor Yellow
        return $false
    }
    $persona = Get-Content $PersonaFile -Raw
    $header = "# ARNES ARGOS - Atlas (entorno generado por 'argos target $Target')`n# Persona del orquestador. La memoria del proyecto vive en .arnes/ (arnes.db).`n`n"
    if ($Target -eq 'codex') {
        $out = Join-Path $TargetDir 'AGENTS.md'
    } else {
        $out = Join-Path $TargetDir 'CLAUDE.md'
    }
    if (-not (Test-Path (Split-Path $out -Parent))) { New-Item -ItemType Directory -Path (Split-Path $out -Parent) -Force | Out-Null }
    Set-Content -Path $out -Value ($header + $persona) -Encoding UTF8
    Write-Host ("  [OK] Persona Atlas desplegada: {0}" -f $out) -ForegroundColor Green
    return $true
}

switch ($Command) {
    'show' {
        $current = Get-CurrentTarget
        Write-Host ("  Target actual: {0} ({1})" -f $current, $TargetMeta[$current]) -ForegroundColor Cyan
        Write-Host '  Para cambiar: argos target set <opencode|codex|claude>' -ForegroundColor DarkGray
        exit 0
    }
    'list' {
        Write-Host ''
        Write-Host '  ARNES ARGOS - TARGETS' -ForegroundColor Cyan
        $current = Get-CurrentTarget
        $installed = Get-InstalledTargets
        foreach ($k in @('opencode', 'codex', 'claude')) {
            $mark = if ($k -eq $current) { ' *' } else { '  ' }
            $status = if ($k -in $installed) { 'instalado' } else { 'NO instalado' }
            Write-Host ("  {0} {1,-10} {2}  [{3}]" -f $mark, $k, $TargetMeta[$k], $status) -ForegroundColor White
        }
        Write-Host ''
        Write-Host '  Uso: argos target set <nombre> | argos target <nombre> [quest]' -ForegroundColor DarkGray
        Write-Host ''
        exit 0
    }
    'set' {
        if (-not $Name) {
            Write-Host '  Uso: argos target set <opencode|codex|claude>' -ForegroundColor Yellow
            exit 1
        }
        if (-not $TargetMeta.ContainsKey($Name)) {
            Write-Host "  [!] Target invalido: $Name. Usa opencode, codex o claude." -ForegroundColor Yellow
            exit 1
        }
        if (-not (Test-Path $ConfigDir)) { New-Item -ItemType Directory -Path $ConfigDir -Force | Out-Null }
        @{ target = $Name } | ConvertTo-Json | Set-Content -Path $TargetFile -Encoding UTF8
        Write-Host ("  [OK] Target default: {0} ({1})" -f $Name, $TargetMeta[$Name]) -ForegroundColor Green
        exit 0
    }
    default {
        # ==== LAUNCH ====
        $resolved = if ($Target) { $Target } else { Get-CurrentTarget }

        if ($resolved -eq 'auto') {
            $installed = Get-InstalledTargets
            if ($installed.Count -eq 0) {
                Write-Host '  [!] No hay ningun CLI instalado (opencode/codex/claude).' -ForegroundColor Red
                Write-Host '      Instala al menos uno y vuelve a intentar.' -ForegroundColor Yellow
                exit 1
            }
            if ($installed.Count -eq 1) {
                $resolved = $installed[0]
            } else {
                Write-Host ''
                Write-Host '  ARNES ARGOS - ELIGE TU ENTORNO' -ForegroundColor DarkRed
                for ($i = 0; $i -lt $installed.Count; $i++) {
                    Write-Host ("  [{0}] {1} - {2}" -f ($i + 1), $installed[$i], $TargetMeta[$installed[$i]]) -ForegroundColor White
                }
                $sel = Read-Input '  Elige (1-3)'
                $idx = 0
                if ([int]::TryParse($sel, [ref]$idx) -and $idx -ge 1 -and $idx -le $installed.Count) {
                    $resolved = $installed[$idx - 1]
                } else {
                    Write-Host '  Usando default: opencode' -ForegroundColor Yellow
                    $resolved = 'opencode'
                }
            }
        }

        if (-not $TargetMeta.ContainsKey($resolved)) {
            Write-Host "  [!] Target invalido: $resolved" -ForegroundColor Yellow
            exit 1
        }

        Write-Host ''
        Write-Host ("  ARNES -> {0}  |  {1}" -f $resolved.ToUpper(), $TargetMeta[$resolved]) -ForegroundColor DarkRed
        Write-Host ''

        switch ($resolved) {
            'opencode' {
                # Reutiliza el flujo completo (mutex + sync + verificacion + launch)
                if ($Quest) {
                    & (Join-Path $PSScriptRoot 'argos-opencode.ps1') -Quest $Quest
                } else {
                    & (Join-Path $PSScriptRoot 'argos-opencode.ps1')
                }
            }
            'codex' {
                Write-Host '  [1/2] Desplegando entorno a Codex...' -ForegroundColor Cyan
                [void](Write-AtlasPersona -Target 'codex')
                Write-Host '  [2/2] Abriendo Codex...' -ForegroundColor Cyan
                if ($NoLaunch) { exit 0 }
                if (-not (Get-Command codex -ErrorAction SilentlyContinue)) {
                    Write-Host '  [!] codex no encontrado. Instala: npm install -g @openai/codex' -ForegroundColor Red
                    exit 1
                }
                if ($Quest) {
                    & codex exec $Quest
                } else {
                    & codex
                }
            }
            'claude' {
                Write-Host '  [1/2] Desplegando entorno a Claude...' -ForegroundColor Cyan
                [void](Write-AtlasPersona -Target 'claude')
                Write-Host '  [2/2] Abriendo Claude...' -ForegroundColor Cyan
                if ($NoLaunch) { exit 0 }
                if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
                    Write-Host '  [!] claude no encontrado. Instala: npm install -g @anthropic-ai/claude-code' -ForegroundColor Red
                    exit 1
                }
                if ($Quest) {
                    & claude -p $Quest
                } else {
                    & claude
                }
            }
        }
    }
}
