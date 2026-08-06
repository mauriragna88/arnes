#Requires -Version 5.1
<#
.SYNOPSIS
ARGOS - El entorno de ARNES ARGOS (Los 100 Ojos)

.DESCRIPTION
El punto de entrada. Detecta si el proyecto esta inicializado, conecta proveedores,
configura modelos por agente, y lanza el chat donde Atlas orquesta.
DENTRO de argos, Atlas es el orquestador principal.
Todo propio: no usa opencode auth, no gentle-ai, no engram.

.EXAMPLE
argos                    -> abrir entorno (detecta proyecto + menu)
argos connect            -> wizard de conexiones (/connect)
argos configure          -> wizard de modelos por agente (/configuremodel)
argos chat               -> chat con Atlas
argos status             -> estado del entorno
argos init               -> inicializar proyecto
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet('', 'init', 'connect', 'configure', 'chat', 'status', 'models', 'memory')]
    [string]$Command = '',

    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Args
)

$ErrorActionPreference = 'Stop'
$ScriptDir = $PSScriptRoot
$Root = Resolve-Path (Join-Path $ScriptDir '..')
# El proyecto es la carpeta ACTUAL donde el usuario ejecuto argos (no el repo del script)
$ProjectDir = (Get-Location).Path
$ArnesDir = Join-Path $ProjectDir '.arnes'
$ConfigPath = Join-Path $ArnesDir 'config.json'
$ConnPath = Join-Path $ArnesDir 'connections.json'
$AgentModelsPath = Join-Path $ArnesDir 'agent-models.json'

# Forzar UTF-8
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

# === BANNER ARGOS ===
function Show-Banner {
    Write-Host ''
    Write-Host "      ▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄" -ForegroundColor DarkRed
    Write-Host ''
    Write-Host "        █████╗ ██████╗ ██████╗  ██████╗ ███████╗" -ForegroundColor Red
    Write-Host "       ██╔══██╗██╔══██╗██╔════╝ ██╔═══██╗██╔════╝" -ForegroundColor White
    Write-Host "       ███████║██████╔╝██║  ███╗██║   ██║███████╗" -ForegroundColor Red
    Write-Host "       ██╔══██║██╔══██╗██║   ██║██║   ██║╚════██║" -ForegroundColor White
    Write-Host "       ██║  ██║██║  ██║╚██████╔╝╚██████╔╝███████║" -ForegroundColor Red
    Write-Host "       ╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝  ╚═════╝ ╚══════╝" -ForegroundColor White
    Write-Host ''
    Write-Host "      ╔═══════════════════════════════════════════════════════════════════╗" -ForegroundColor DarkRed
    Write-Host "      ║   ARNES ARGOS - EL ENTORNO DE LOS 100 OJOS   ║" -ForegroundColor White
    Write-Host "      ╚═══════════════════════════════════════════════════════════════════╝" -ForegroundColor DarkRed
    Write-Host ''
    Write-Host "      ▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀" -ForegroundColor DarkRed
    Write-Host ''
}

# === Detectar estado del proyecto ===
function Get-ProjectState {
    $state = [ordered]@{
        is_argos = $false
        has_config = $false
        has_connections = $false
        has_models = $false
        project_name = (Split-Path (Get-Location) -Leaf)
    }
    if (Test-Path $ArnesDir) { $state.is_argos = $true }
    if (Test-Path $ConfigPath) { $state.has_config = $true }
    if (Test-Path $ConnPath) { $state.has_connections = $true }
    if (Test-Path $AgentModelsPath) { $state.has_models = $true }
    return $state
}

# === Inicializar proyecto ===
function Init-Project {
    Write-Host ''
    Write-Host "  ▸ Inicializando ARNES ARGOS en: $(Get-Location)" -ForegroundColor Cyan
    # Crear .arnes si no existe
    if (-not (Test-Path $ArnesDir)) { New-Item -ItemType Directory -Path $ArnesDir -Force | Out-Null }
    # Crear connections.json
    $conn = Join-Path $ScriptDir 'argos-connect.ps1'
    & $conn init
    # Crear agent-models.json con defaults
    if (-not (Test-Path $AgentModelsPath)) {
        $defaults = [ordered]@{
            version = '1.0'
            updated_at = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
            agents = [ordered]@{
                atlas = 'opencode-go/qwen3.8-max'
                vivi = 'openai/gpt-5.6-luna'
                ansem = 'nvidia/deepseek-ai/deepseek-v4-flash'
                kuja = 'nvidia/deepseek-ai/deepseek-v4-flash'
                eiko = 'opencode-go/deepseek-v4-flash'
                amarant = 'openai/gpt-5.6-luna'
                eremez = 'nvidia/deepseek-ai/deepseek-v4-flash'
                auron = 'nvidia/deepseek-ai/deepseek-v4-pro'
                bran = 'openai/gpt-5.6-luna'
                quina = 'opencode-go/deepseek-v4-flash'
                varys = 'openai/gpt-5.6-luna'
                tywin = 'nvidia/deepseek-ai/deepseek-v4-flash'
                sam = 'openai/gpt-5.6-luna'
                bard = 'openai/gpt-5.6-luna'
                tidus = 'opencode-go/deepseek-v4-flash'
                ragnarok = 'openai/gpt-5.6-luna'
            }
        }
        $defaults | ConvertTo-Json -Depth 6 | Set-Content -Path $AgentModelsPath -Encoding UTF8
        Write-Host "  [OK] agent-models.json creado (modelos por agente)." -ForegroundColor Green
    }
    Write-Host "  [OK] Proyecto inicializado." -ForegroundColor Green
    Write-Host ''
}

# === Configurar modelos por agente (wizard) ===
function Show-ConfigureModels {
    Write-Host ''
    Write-Host '  ▸ Configuracion de modelos por agente' -ForegroundColor Cyan
    $picker = Join-Path $ScriptDir 'arnes-picker.ps1'
    $connMgr = Join-Path $ScriptDir 'argos-connect.ps1'

    # Obtener todos los modelos de proveedores conectados
    $allModels = @()
    $data = $null
    if (Test-Path $ConnPath) { $data = Get-Content $ConnPath -Raw | ConvertFrom-Json }
    if ($data) {
        foreach ($p in $data.providers.PSObject.Properties) {
            if ($p.Value.connected) {
                foreach ($m in @($p.Value.models)) {
                    $allModels += ("{0}/{1}" -f $p.Name, $m)
                }
            }
        }
    }
    if ($allModels.Count -eq 0) {
        Write-Host '  [!] No hay proveedores conectados. Primero: argos connect' -ForegroundColor Yellow
        return
    }
    $allModels = $allModels | Sort-Object -Unique

    # Leer agent-models actual
    $agentModels = [ordered]@{}
    if (Test-Path $AgentModelsPath) {
        $am = Get-Content $AgentModelsPath -Raw | ConvertFrom-Json
        foreach ($a in $am.agents.PSObject.Properties) {
            $agentModels[$a.Name] = $a.Value
        }
    }

    $agents = @(
        @{ key = 'atlas'; name = 'Atlas (Orquestador)' },
        @{ key = 'vivi'; name = 'Vivi (Frontend)' },
        @{ key = 'ansem'; name = 'Ansem (Backend)' },
        @{ key = 'kuja'; name = 'Kuja (QA)' },
        @{ key = 'eiko'; name = 'Eiko (DevOps)' },
        @{ key = 'amarant'; name = 'Amarant (Arquitectura)' },
        @{ key = 'eremez'; name = 'Eremez (Research)' },
        @{ key = 'auron'; name = 'Auron (Seguridad)' },
        @{ key = 'bran'; name = 'Bran (Analista)' },
        @{ key = 'quina'; name = 'Quina (Tokens)' },
        @{ key = 'varys'; name = 'Varys (Tracker)' },
        @{ key = 'tywin'; name = 'Tywin (Verificador)' },
        @{ key = 'sam'; name = 'Sam (Consejero)' },
        @{ key = 'bard'; name = 'Bard (Mejora)' },
        @{ key = 'tidus'; name = 'Tidus (Infra)' },
        @{ key = 'ragnarok'; name = 'Ragnarok (Compras)' }
    )

    foreach ($a in $agents) {
        $current = if ($agentModels.Contains($a.key)) { $agentModels[$a.key] } else { '' }
        $defaultIdx = 0
        if ($current) {
            $found = [Array]::IndexOf($allModels, $current)
            if ($found -ge 0) { $defaultIdx = $found }
        }
        Write-Host ''
        $chosen = & $picker -Title "Modelo para $($a.name)" -Options $allModels -DefaultIndex $defaultIdx -Group "Modelos de proveedores conectados"
        if ($LASTEXITCODE -eq 130 -or [string]::IsNullOrWhiteSpace($chosen)) {
            Write-Host '  Cancelado.' -ForegroundColor Yellow
            return
        }
        $agentModels[$a.key] = $chosen
        Write-Host "  OK $($a.name) -> $chosen" -ForegroundColor Green
    }

    # Guardar
    $out = [ordered]@{
        version = '1.0'
        updated_at = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
        agents = [ordered]@{}
    }
    foreach ($k in $agentModels.Keys) { $out.agents[$k] = $agentModels[$k] }
    $out | ConvertTo-Json -Depth 6 | Set-Content -Path $AgentModelsPath -Encoding UTF8
    Write-Host ''
    Write-Host '  [OK] Configuracion guardada en .arnes/agent-models.json' -ForegroundColor Green
}

# === Menu principal ===
function Show-Menu {
    Clear-Host
    Show-Banner
    $state = Get-ProjectState

    Write-Host '  ▸ Proyecto:' -ForegroundColor Cyan
    Write-Host ("    {0}  (carpeta: {1})" -f $state.project_name, (Get-Location)) -ForegroundColor White
    Write-Host '  ▸ Estado del entorno:' -ForegroundColor Cyan
    if ($state.has_connections) { Write-Host '    [OK] Conexiones configuradas (.arnes/connections.json)' -ForegroundColor Green } else { Write-Host '    [--] Sin conexiones' -ForegroundColor DarkGray }
    if ($state.has_models) { Write-Host '    [OK] Modelos por agente (.arnes/agent-models.json)' -ForegroundColor Green } else { Write-Host '    [--] Modelos sin configurar' -ForegroundColor DarkGray }
    if ($state.is_argos) { Write-Host '    [OK] Memoria disponible (arnes.db)' -ForegroundColor Green } else { Write-Host '    [--] Sin memoria' -ForegroundColor DarkGray }
    Write-Host ''

    Write-Host '  ================================================' -ForegroundColor DarkGray
    Write-Host '  [1] Chat con Atlas (orquestador)' -ForegroundColor White
    Write-Host '  [2] Conectar proveedores (/connect)' -ForegroundColor White
    Write-Host '  [3] Configurar modelos por agente (/configuremodel)' -ForegroundColor White
    Write-Host '  [4] Estado del entorno (/status)' -ForegroundColor White
    Write-Host '  [5] Memoria (/memory)' -ForegroundColor White
    Write-Host '  [Q] Salir' -ForegroundColor White
    Write-Host '  ================================================' -ForegroundColor DarkGray
    Write-Host ''

    $choice = Read-Host '  Selecciona una opcion'
    switch ($choice) {
        '1' { Launch-Chat }
        '2' { & (Join-Path $ScriptDir 'argos-connect-wizard.ps1'); Read-Host '  Enter para volver'; Show-Menu }
        '3' { Show-ConfigureModels; Read-Host '  Enter para volver'; Show-Menu }
        '4' { Show-Status; Read-Host '  Enter para volver'; Show-Menu }
        '5' { $mem = Join-Path $ScriptDir 'arnes-memory.ps1'; & $mem stats; Read-Host '  Enter para volver'; Show-Menu }
        'q' { Write-Host '  Adios. Los 100 ojos te observan. 👁️'; exit 0 }
        'Q' { Write-Host '  Adios. Los 100 ojos te observan. 👁️'; exit 0 }
        default { Show-Menu }
    }
}

function Launch-Chat {
    Write-Host ''
    Write-Host '  ▸ Lanzando chat con Atlas (orquestador)...' -ForegroundColor Cyan
    $chat = Join-Path $ScriptDir 'argos-chat.ps1'
    & $chat
}

function Show-Status {
    Write-Host ''
    Write-Host '  ARNES ARGOS - ESTADO' -ForegroundColor Cyan
    Write-Host '  ==================' -ForegroundColor Cyan
    $state = Get-ProjectState
    Write-Host ("  Proyecto:    {0}" -f $state.project_name) -ForegroundColor White
    Write-Host ("  Carpeta:     {0}" -f (Get-Location)) -ForegroundColor White
    Write-Host ("  Entorno:     {0}" -f $(if ($state.is_argos) { 'ARGOS activo' } else { 'no inicializado' })) -ForegroundColor $(if ($state.is_argos) { 'Green' } else { 'Yellow' })
    Write-Host ''
    $conn = Join-Path $ScriptDir 'argos-connect.ps1'
    & $conn status
}

# === MAIN ===
Show-Banner

switch ($Command) {
    'init' { Init-Project; Read-Host '  Enter para continuar'; Show-Menu }
    'connect' { & (Join-Path $ScriptDir 'argos-connect-wizard.ps1') }
    'configure' { Show-ConfigureModels }
    'chat' { Launch-Chat }
    'status' { Show-Status }
    'models' { Show-ConfigureModels }
    'memory' { $mem = Join-Path $ScriptDir 'arnes-memory.ps1'; & $mem stats }
    default {
        # Detectar proyecto nuevo
        $state = Get-ProjectState
        if (-not $state.is_argos) {
            Write-Host '  ▸ Proyecto nuevo detectado - inicializando...' -ForegroundColor Yellow
            Init-Project
            Write-Host '  ▸ Primero conectemos tus proveedores de modelos:' -ForegroundColor Cyan
            & (Join-Path $ScriptDir 'argos-connect-wizard.ps1')
            Write-Host '  ▸ Ahora configura que modelo usa cada agente:' -ForegroundColor Cyan
            Show-ConfigureModels
            Write-Host '  ▸ Listo! Abriendo menu principal...' -ForegroundColor Green
            Start-Sleep -Seconds 1
            Show-Menu
        } elseif (-not $state.has_connections -or -not $state.has_models) {
            Write-Host '  ▸ Te faltan conexiones o configuracion de modelos.' -ForegroundColor Yellow
            Write-Host '  ▸ Vamos a completar la configuracion inicial:' -ForegroundColor Cyan
            if (-not $state.has_connections) {
                & (Join-Path $ScriptDir 'argos-connect-wizard.ps1')
            }
            if (-not $state.has_models) {
                Show-ConfigureModels
            }
            Write-Host '  ▸ Listo! Abriendo menu principal...' -ForegroundColor Green
            Start-Sleep -Seconds 1
            Show-Menu
        } else {
            Show-Menu
        }
    }
}
