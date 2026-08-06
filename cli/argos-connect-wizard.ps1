#Requires -Version 5.1
<#
.SYNOPSIS
ARGOS CONNECT WIZARD - Asistente interactivo para conectar proveedores

.DESCRIPTION
Wizard con flechas (estilo /connect de OpenCode pero NUESTRO):
1. Lista proveedores conocidos (OpenAI OAuth, Claude OAuth, OpenCode Go, NVIDIA, B.AI...)
2. El usuario elige con flechas
3. Para API: pide la key (o nombre de variable de entorno)
4. Para OAuth: explica el flujo del navegador
5. Opcion de agregar proveedor custom

.EXAMPLE
.\argos-connect-wizard.ps1
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$Root = Resolve-Path (Join-Path $PSScriptRoot '..')
# === RUTA GLOBAL: conexiones UNA VEZ por computadora ===
$GlobalConfigDir = Join-Path $env:USERPROFILE '.config\arnes'
if (-not (Test-Path $GlobalConfigDir)) { New-Item -ItemType Directory -Path $GlobalConfigDir -Force | Out-Null }
$ConnPath = Join-Path $GlobalConfigDir 'connections.json'
$ProjectDir = (Get-Location).Path
$ArnesDir = Join-Path $ProjectDir '.arnes'
$Picker = Join-Path $PSScriptRoot 'arnes-picker.ps1'
$ConnMgr = Join-Path $PSScriptRoot 'argos-connect.ps1'

# Forzar UTF-8
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

# Asegurar que existe connections.json
& $ConnMgr init | Out-Null

function Show-Header {
    Write-Host ''
    Write-Host '  ╔══════════════════════════════════════════════════════════╗' -ForegroundColor DarkRed
    Write-Host '  ║   ARNES ARGOS - Conectar proveedores (nuestro /connect)  ║' -ForegroundColor White
    Write-Host '  ╚══════════════════════════════════════════════════════════╝' -ForegroundColor DarkRed
    Write-Host ''
}

function Get-Connections {
    if (Test-Path $ConnPath) { return Get-Content $ConnPath -Raw | ConvertFrom-Json }
    return $null
}

function Save-Connections {
    param($Data)
    $Data | ConvertTo-Json -Depth 10 | Set-Content -Path $ConnPath -Encoding UTF8
}

# === MAIN ===
Show-Header

$data = Get-Connections
if (-not $data) {
    & $ConnMgr init | Out-Null
    $data = Get-Connections
}

# Build lista de opciones: [nombre] nombre legible (estado)
$options = @()
foreach ($p in $data.providers.PSObject.Properties) {
    $v = $p.Value
    $status = if ($v.connected) { '[CONECTADO]' } else { '[sin conectar]' }
    $options += ("{0} | {1} ({2}) {3}" -f $p.Name, $v.name, $v.type, $status)
}
$options += '--- Agregar proveedor custom ---'
$options += '--- Volver ---'

$choice = & $Picker -Title 'Elige un proveedor para conectar' -Options $options -Group 'ARNES ARGOS connect'
if ([string]::IsNullOrWhiteSpace($choice) -or $choice -like '*Volver*' -or $LASTEXITCODE -eq 130) {
    Write-Host '  Cancelado.' -ForegroundColor Yellow
    exit 0
}

if ($choice -like '*Agregar proveedor custom*') {
    Write-Host ''
    $cName = Read-Host '  Nombre del proveedor (ej: groq, mistral, ollama)'
    $cType = Read-Host '  Tipo [api/oauth] (default api)'
    if ([string]::IsNullOrWhiteSpace($cType)) { $cType = 'api' }
    $cUrl = Read-Host '  Base URL (ej: https://api.groq.com/v1)'
    $cDisplay = Read-Host '  Nombre legible (default = nombre)'
    if ([string]::IsNullOrWhiteSpace($cDisplay)) { $cDisplay = $cName }
    & $ConnMgr add -Name $cName -Type $cType -BaseUrl $cUrl -DisplayName $cDisplay
    Write-Host ''
    Write-Host '  Ahora configura la API key:' -ForegroundColor Yellow
    $cKey = Read-Host '  API key (o Enter para usar variable de entorno)'
    if ($cKey) {
        & $ConnMgr set-key -Name $cName -ApiKey $cKey
    } else {
        $cEnv = Read-Host '  Nombre de variable de entorno (ej: GROQ_API_KEY)'
        if ($cEnv) { & $ConnMgr set-key -Name $cName -KeyEnv $cEnv }
    }
    Write-Host '  [OK] Proveedor custom conectado.' -ForegroundColor Green
    exit 0
}

# Parsear nombre del choice: "nombre | ..."
$providerName = ($choice -split ' \| ')[0].Trim()

$provider = $data.providers.$providerName
if (-not $provider) { Write-Host "  [!] Proveedor '$providerName' no encontrado." -ForegroundColor Red; exit 1 }

Write-Host ''
Write-Host "  Conectando: $($provider.name) ($providerName)" -ForegroundColor Cyan

if ($provider.type -eq 'api') {
    $current = if ($provider.api_key) { 'key ya configurada' } else { 'sin key' }
    Write-Host "  Estado: $current" -ForegroundColor DarkGray
    Write-Host ''
    $keyInput = Read-Host '  API key (Enter = usar variable de entorno, Q = cancelar)'
    if ($keyInput -eq 'q' -or $keyInput -eq 'Q') { Write-Host '  Cancelado.'; exit 0 }
    if ($keyInput) {
        & $ConnMgr set-key -Name $providerName -ApiKey $keyInput
        Write-Host "  [OK] $providerName conectado con API key." -ForegroundColor Green
    } else {
        $envName = if ($provider.key_env) { $provider.key_env } else { Read-Host '  Nombre de variable de entorno (ej: NVIDIA_API_KEY)' }
        if (-not $envName) { Write-Host '  [!] Sin key ni env - no se conecto.' -ForegroundColor Yellow; exit 1 }
        $hasEnv = [bool](Get-Item "Env:$envName" -ErrorAction SilentlyContinue)
        & $ConnMgr set-key -Name $providerName -KeyEnv $envName
        if ($hasEnv) {
            Write-Host "  [OK] $providerName conectado via env:$envName" -ForegroundColor Green
        } else {
            Write-Host "  [OK] $providerName configurado para usar env:$envName (aun no definida en el sistema)" -ForegroundColor Yellow
        }
    }
} else {
    # OAuth - explicar flujo del navegador
    Write-Host ''
    Write-Host "  $($provider.name) usa OAuth (login por navegador)." -ForegroundColor White
    Write-Host '  El flujo es:' -ForegroundColor DarkGray
    Write-Host '    1. Se abre el navegador con la URL de autorizacion' -ForegroundColor DarkGray
    Write-Host '    2. Te logueas con tu cuenta' -ForegroundColor DarkGray
    Write-Host '    3. El token se guarda localmente' -ForegroundColor DarkGray
    Write-Host ''
    $resp = Read-Host '  Abrir navegador ahora? [Y/n]'
    if ($resp -eq '' -or $resp -eq 'y' -or $resp -eq 'Y') {
        Write-Host "  Abriendo $($provider.base_url) en el navegador..." -ForegroundColor Cyan
        Start-Process $provider.base_url
        Write-Host '  Completa el login en el navegador y vuelve aqui.' -ForegroundColor Yellow
        $done = Read-Host '  Cuando termines, escribe OK'
        if ($done -eq 'OK' -or $done -eq 'ok') {
            # Marcar conectado (token en auth.json de OpenCode queda disponible para el motor)
            $data = Get-Connections
            $data.providers.$providerName.connected = $true
            $data.updated_at = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
            Save-Connections $data
            Write-Host "  [OK] $providerName marcado como conectado (OAuth)." -ForegroundColor Green
        }
    }
}

Write-Host ''
Write-Host '  Estado actual de tus conexiones:' -ForegroundColor Cyan
& $ConnMgr status
