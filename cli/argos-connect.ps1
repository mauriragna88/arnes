#Requires -Version 5.1
<#
.SYNOPSIS
ARGOS CONNECT - Gestor de conexiones y proveedores (nuestro propio /connect)

.DESCRIPTION
Maneja .arnes/connections.json: proveedores, API keys, OAuth, modelos disponibles.
Todo propio de ARNES ARGOS - nada de opencode auth, nada de gentle-ai.

.EXAMPLE
.\argos-connect.ps1 list              -> ver conexiones
.\argos-connect.ps1 add -Name openai -Type oauth -BaseUrl https://api.openai.com/v1
.\argos-connect.ps1 status
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet('init', 'list', 'status', 'add', 'remove', 'set-key', 'models')]
    [string]$Command = 'list',

    [string]$Name,
    [ValidateSet('oauth', 'api')]
    [string]$Type,
    [string]$BaseUrl,
    [string]$ApiKey,
    [string]$KeyEnv,
    [string]$DisplayName
)

$ErrorActionPreference = 'Stop'
$Root = Resolve-Path (Join-Path $PSScriptRoot '..')
# === RUTA GLOBAL: conexiones se configuran UNA VEZ por computadora ===
# No en el proyecto - es config de la maquina, no del proyecto.
$GlobalConfigDir = Join-Path $env:USERPROFILE '.config\arnes'
if (-not (Test-Path $GlobalConfigDir)) { New-Item -ItemType Directory -Path $GlobalConfigDir -Force | Out-Null }
$ConnPath = Join-Path $GlobalConfigDir 'connections.json'
$ProjectDir = (Get-Location).Path
$ArnesDir = Join-Path $ProjectDir '.arnes'

# Proveedores conocidos (defaults - el usuario puede agregar custom)
$KNOWN_PROVIDERS = @{
    'openai' = @{ type = 'oauth'; name = 'OpenAI (cuenta GPT)'; base_url = 'https://api.openai.com/v1'; models = @('gpt-5.6-sol', 'gpt-5.6-terra', 'gpt-5.6-luna', 'gpt-5.5', 'gpt-5.4') }
    'claude' = @{ type = 'oauth'; name = 'Claude (cuenta)'; base_url = 'https://api.anthropic.com/v1'; models = @('claude-opus-5', 'claude-sonnet-5', 'claude-fable-5') }
    'opencode-go' = @{ type = 'api'; name = 'OpenCode Go'; base_url = 'https://api.opencode.ai/v1'; key_env = 'OPENCODE_GO_API_KEY'; models = @('deepseek-v4-flash', 'deepseek-v4-pro', 'qwen3.8-max', 'gpt-5.6-luna', 'glm-5.2', 'kimi-k2.6') }
    'nvidia' = @{ type = 'api'; name = 'NVIDIA NIM (gratis)'; base_url = 'https://integrate.api.nvidia.com/v1'; key_env = 'NVIDIA_API_KEY'; models = @('deepseek-ai/deepseek-v4-flash', 'deepseek-ai/deepseek-v4-pro', 'qwen/qwen3-coder-480b') }
    'bai' = @{ type = 'api'; name = 'B.AI (Claude/GPT/Qwen)'; base_url = 'https://api.b.ai/v1'; key_env = 'BAI_API_KEY'; models = @('claude-opus-5', 'claude-fable-5', 'gpt-5.6-sol', 'qwen3.8-max', 'deepseek-v4-flash') }
    'z-ai' = @{ type = 'api'; name = 'Z.AI (Zhipu GLM)'; base_url = 'https://open.bigmodel.cn/api/paas/v4'; key_env = 'ZHIPU_API_KEY'; models = @('glm-5.2') }
    'siliconflow' = @{ type = 'api'; name = 'SiliconFlow'; base_url = 'https://api.siliconflow.cn/v1'; key_env = 'SILICONFLOW_API_KEY'; models = @() }
    'tokenrouter' = @{ type = 'api'; name = 'TokenRouter'; base_url = 'https://api.tokenrouter.com/v1'; key_env = 'TOKENROUTER_API_KEY'; models = @('kimi-k3-free') }
    'minimax' = @{ type = 'api'; name = 'MiniMax'; base_url = ''; key_env = 'MINIMAX_API_KEY'; models = @('minimax-m3') }
}

function Read-Connections {
    if (Test-Path $ConnPath) {
        return Get-Content $ConnPath -Raw | ConvertFrom-Json
    }
    return $null
}

function Write-Connections {
    param($Data)
    $Data | ConvertTo-Json -Depth 10 | Set-Content -Path $ConnPath -Encoding UTF8
}

function Init-Connections {
    if (Test-Path $ConnPath) { Write-Output '  [OK] connections.json ya existe.'; return }
    $providers = [ordered]@{}
    foreach ($k in $KNOWN_PROVIDERS.Keys | Sort-Object) {
        $p = $KNOWN_PROVIDERS[$k]
        $providers[$k] = [ordered]@{
            type       = $p.type
            name       = $p.name
            base_url   = $p.base_url
            key_env    = if ($p.key_env) { $p.key_env } else { '' }
            api_key    = ''
            connected  = $false
            models     = @($p.models)
            added_at   = ''
        }
    }
    $data = [ordered]@{
        version    = '1.0'
        updated_at = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
        providers  = $providers
    }
    Write-Connections $data
    Write-Output "  [OK] connections.json creado en $ConnPath"
}

function Show-Status {
    $data = Read-Connections
    if (-not $data) { Write-Output '  [!] No hay connections.json. Usa: argos-connect.ps1 init'; return }
    Write-Host ''
    Write-Host '  ARNES ARGOS - CONEXIONES' -ForegroundColor Cyan
    Write-Host '  ========================' -ForegroundColor Cyan
    foreach ($p in $data.providers.PSObject.Properties) {
        $v = $p.Value
        $status = if ($v.connected) { '[OK]' } else { '[--]' }
        $type = if ($v.type -eq 'oauth') { 'OAuth' } else { 'API' }
        $color = if ($v.connected) { 'Green' } else { 'DarkGray' }
        Write-Host ("  {0} {1,-12} {2,-35} {3}" -f $status, $p.Name, $v.name, $type) -ForegroundColor $color
        if ($v.connected) {
            Write-Host ("      base: {0}" -f $v.base_url) -ForegroundColor DarkGray
            Write-Host ("      modelos: {0}" -f ($v.models -join ', ')) -ForegroundColor DarkGray
        }
    }
}

function Show-Models {
    param([string]$Provider)
    $data = Read-Connections
    if (-not $data) { Write-Output '  [!] No hay connections.json.'; return }
    $p = $data.providers.$Provider
    if (-not $p) { Write-Output "  [!] Proveedor '$Provider' no existe."; return }
    Write-Host "  Modelos de $Provider ($($p.name)):" -ForegroundColor Cyan
    foreach ($m in @($p.models)) {
        Write-Host "    $m" -ForegroundColor White
    }
}

switch ($Command) {
    'init' { Init-Connections }
    'list' { Show-Status }
    'status' { Show-Status }
    'add' {
        if (-not $Name) { throw 'Falta -Name (ej: openai, claude, nvidia, custom-name)' }
        $data = Read-Connections
        if (-not $data) { Init-Connections; $data = Read-Connections }
        $p = $KNOWN_PROVIDERS[$Name]
        if (-not $p -and $Type) {
            # Proveedor custom
            $p = @{ type = $Type; name = $DisplayName; base_url = $BaseUrl; key_env = $KeyEnv; models = @() }
        }
        if (-not $p) { throw "Proveedor '$Name' no conocido y falta -Type/-BaseUrl para custom." }
        $data.providers | Add-Member -NotePropertyName $Name -NotePropertyValue ([ordered]@{
            type      = $p.type
            name      = $p.name
            base_url  = $p.base_url
            key_env   = if ($p.key_env) { $p.key_env } else { '' }
            api_key   = ''
            connected = $false
            models    = @($p.models)
            added_at  = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
        }) -Force
        Write-Connections $data
        Write-Output "  [OK] Proveedor '$Name' agregado. Conectalo con set-key."
    }
    'set-key' {
        if (-not $Name) { throw 'Falta -Name' }
        if (-not $ApiKey -and -not $KeyEnv) { throw 'Falta -ApiKey o -KeyEnv' }
        $data = Read-Connections
        if (-not $data) { Init-Connections; $data = Read-Connections }
        if (-not $data.providers.$Name) { throw "Proveedor '$Name' no existe." }
        if ($ApiKey) { $data.providers.$Name.api_key = $ApiKey }
        if ($KeyEnv) { $data.providers.$Name.key_env = $KeyEnv }
        $data.providers.$Name.connected = $true
        $data.updated_at = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
        Write-Connections $data
        Write-Output "  [OK] '$Name' conectado (api_key configurada)."
    }
    'remove' {
        if (-not $Name) { throw 'Falta -Name' }
        $data = Read-Connections
        if (-not $data -or -not $data.providers.$Name) { throw "Proveedor '$Name' no existe." }
        $data.providers.PSObject.Properties.Remove($Name)
        $data.updated_at = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
        Write-Connections $data
        Write-Output "  [OK] Proveedor '$Name' eliminado."
    }
    'models' {
        if ($Name) { Show-Models -Provider $Name } else { Show-Status }
    }
    default { Show-Status }
}
