#Requires -Version 5.1
<#
.SYNOPSIS
argos audit - Contract Audit DB <-> API <-> Frontend (ARNES, ADR-006).

DESPLIEGA el gate deterministico a CUALQUIER proyecto y lo corre.

Comandos:
  argos audit init        -> despliega scripts/contract-audit/ al proyecto actual
                             (detecta rutas: supabase/migrations, database.types.ts, app/api, src)
                             + anade npm script "contract:audit"
  argos audit             -> corre el gate en el proyecto actual (exit 0/1)
  argos audit status      -> muestra si el gate esta desplegado y que capas aplican
  argos audit --json      -> salida JSON (para Tywin / CI)

Integracion:
  - Proyecto 0: se despliega automaticamente en "argos init" (forzoso)
  - Proyecto en seguimiento (RES/CHAT): corre "argos audit init" UNA vez
  - Tywin lo invoca pre-verdict; Auron lo incluye en el L0 Gate
#>
param(
    [Parameter(Position = 0)]
    [ValidateSet('', 'init', 'status', 'run')]
    [string]$Command = '',

    [switch]$Json
)

$ErrorActionPreference = 'Stop'
$ScriptDir = $PSScriptRoot
$Root = Resolve-Path (Join-Path $ScriptDir '..')
$ProjectDir = (Get-Location).Path
$TemplateDir = Join-Path $Root 'core\contract-audit'
$TargetDir = Join-Path $ProjectDir 'scripts\contract-audit'
$ConfigPath = Join-Path $TargetDir 'config.json'

try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

function Write-Step {
    param([string]$Msg)
    Write-Host ("  ▸ {0}" -f $Msg) -ForegroundColor Cyan
}
function Write-Ok {
    param([string]$Msg)
    Write-Host ("  [OK] {0}" -f $Msg) -ForegroundColor Green
}
function Write-Warn {
    param([string]$Msg)
    Write-Host ("  [!] {0}" -f $Msg) -ForegroundColor Yellow
}

# === Auto-deteccion de rutas del proyecto ===
function Get-DetectedConfig {
    $types = $null
    $foundTypes = @(Get-ChildItem -Path $ProjectDir -Recurse -File -Filter 'database.types.ts' -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch 'node_modules' } | Select-Object -First 1)
    if ($foundTypes) {
        # Ruta relativa compatible con PS 5.1 (Path.GetRelativePath no existe en .NET Framework)
        $types = $foundTypes[0].FullName.Substring($ProjectDir.Length).TrimStart('\', '/')
    }

    $scanDirs = @('src', 'app')
    $existingScan = @($scanDirs | Where-Object { Test-Path (Join-Path $ProjectDir $_) })
    if ($existingScan.Count -eq 0) { $existingScan = @('.') }

    $migrations = 'supabase/migrations'
    if (-not (Test-Path (Join-Path $ProjectDir $migrations))) { $migrations = $null }

    $apiRoutes = 'app/api'
    if (-not (Test-Path (Join-Path $ProjectDir $apiRoutes))) { $apiRoutes = $null }

    return [ordered]@{
        version = '1.0'
        project = (Split-Path $ProjectDir -Leaf)
        supabase = [ordered]@{
            migrations_dir = $migrations
            types_file = $types
            local_stack = $true
        }
        code = [ordered]@{
            scan_dirs = $existingScan
            extensions = @('.ts', '.tsx', '.js', '.jsx')
            max_line_distance_from = 8
        }
        api = [ordered]@{
            routes_dir = $apiRoutes
            require_input_schema = $true
            forbid_select_star = $true
        }
        tiers = [ordered]@{
            minimum = @('L1', 'L2')
            full = @('L1', 'L2', 'L3', 'L4', 'L5', 'L6')
        }
    }
}

# === Anadir npm script "contract:audit" al package.json del proyecto ===
function Add-NpmScript {
    $pkgPath = Join-Path $ProjectDir 'package.json'
    if (-not (Test-Path $pkgPath)) { return $false }
    try {
        $pkg = Get-Content $pkgPath -Raw | ConvertFrom-Json
        if (-not $pkg.scripts) { $pkg | Add-Member -NotePropertyName 'scripts' -NotePropertyValue ([ordered]@{}) -Force }
        $pkg.scripts | Add-Member -NotePropertyName 'contract:audit' -NotePropertyValue 'pwsh ./scripts/contract-audit/run-all.ps1' -Force
        $json = $pkg | ConvertTo-Json -Depth 12
        # UTF-8 SIN BOM (PS 5.1 Set-Content -Encoding UTF8 agrega BOM y rompe JSON.parse)
        [IO.File]::WriteAllText($pkgPath, $json, (New-Object Text.UTF8Encoding $false))
        return $true
    } catch {
        return $false
    }
}

# === INIT ===
function Invoke-Init {
    Write-Step 'Contract Audit - desplegando gate al proyecto'

    if (-not (Test-Path $TemplateDir)) {
        Write-Warn "Template no encontrado: $TemplateDir (repos arnes incompleto)"
        exit 1
    }
    if (-not (Test-Path $TargetDir)) {
        New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null
    }

    # Copiar scripts del template
    foreach ($f in @('types-diff.ps1', 'select-audit.mjs', 'fk-audit.sql', 'run-all.ps1', 'README.md')) {
        $src = Join-Path $TemplateDir $f
        if (Test-Path $src) {
            Copy-Item $src (Join-Path $TargetDir $f) -Force
        }
    }

    # Config detectada (no sobreescribir config existente sin flag -Force)
    $cfgDetected = Get-DetectedConfig
    if (-not (Test-Path $ConfigPath)) {
        $cfgJson = $cfgDetected | ConvertTo-Json -Depth 6
        # UTF-8 SIN BOM (el BOM rompe JSON.parse en Node)
        [IO.File]::WriteAllText($ConfigPath, $cfgJson, (New-Object Text.UTF8Encoding $false))
        Write-Ok "config.json generado con rutas detectadas"
    } else {
        Write-Warn 'config.json ya existe - no se sobreescribio'
    }

    # npm script
    $hasNpm = Add-NpmScript
    if ($hasNpm) {
        Write-Ok 'npm script "contract:audit" anadido al package.json'
    } else {
        Write-Warn 'no package.json - corre el gate con: pwsh ./scripts/contract-audit/run-all.ps1'
    }

    Write-Ok 'Gate desplegado. Resumen de deteccion:'
    Write-Host ''
    Write-Host ("    supabase/migrations: {0}" -f $(if ($cfgDetected.supabase.migrations_dir) { 'DETECTADO' } else { 'no (gate L1/L3 saltaran)' })) -ForegroundColor White
    Write-Host ("    database.types.ts:    {0}" -f $(if ($cfgDetected.supabase.types_file) { $cfgDetected.supabase.types_file } else { 'NO ENCONTRADO' })) -ForegroundColor White
    Write-Host ("    codigo (scan):         {0}" -f ($cfgDetected.code.scan_dirs -join ', ')) -ForegroundColor White
    Write-Host ''
    Write-Host '  Corre el gate ahora:  argos audit' -ForegroundColor Green
    Write-Host '  (o: npm run contract:audit)  — Tywin lo invoca automatico pre-verdict' -ForegroundColor DarkGray
}

# === STATUS ===
function Invoke-Status {
    Write-Step 'Contract Audit - estado del gate'
    if (-not (Test-Path $TargetDir)) {
        Write-Warn 'El gate NO esta desplegado en este proyecto.'
        Write-Host '  Corre:  argos audit init' -ForegroundColor Cyan
        Write-Host '  (proyectos nuevos: se despliega solo en "argos init")' -ForegroundColor DarkGray
        exit 0
    }
    Write-Ok 'Gate desplegado en scripts/contract-audit/'
    $cfg = $null
    if (Test-Path $ConfigPath) { $cfg = Get-Content $ConfigPath -Raw | ConvertFrom-Json }
    if ($cfg) {
        Write-Host ''
        Write-Host ("    types_file:     {0}" -f $(if ($cfg.supabase.types_file) { $cfg.supabase.types_file } else { 'no detectado' })) -ForegroundColor White
        Write-Host ("    scan_dirs:      {0}" -f ($cfg.code.scan_dirs -join ', ')) -ForegroundColor White
        Write-Host ("    migrations_dir: {0}" -f $(if ($cfg.supabase.migrations_dir) { $cfg.supabase.migrations_dir } else { 'no detectado' })) -ForegroundColor White
    }
    # npm script?
    $pkgPath = Join-Path $ProjectDir 'package.json'
    if (Test-Path $pkgPath) {
        $pkg = Get-Content $pkgPath -Raw | ConvertFrom-Json
        if ($pkg.scripts.'contract:audit') {
            Write-Ok 'npm script "contract:audit" presente'
        }
    }
    Write-Host ''
    Write-Host '  Corre el gate:  argos audit' -ForegroundColor Green
}

# === RUN ===
function Invoke-Run {
    if (-not (Test-Path $TargetDir)) {
        Write-Warn 'El gate NO esta desplegado en este proyecto.'
        Write-Host '  Corre:  argos audit init' -ForegroundColor Cyan
        exit 1
    }
    $runner = Join-Path $TargetDir 'run-all.ps1'
    if (-not (Test-Path $runner)) {
        Write-Warn 'run-all.ps1 no encontrado en scripts/contract-audit/'
        exit 1
    }
    if ($Json) {
        & $runner -Json
    } else {
        & $runner
    }
    exit $LASTEXITCODE
}

# === MAIN ===
switch ($Command) {
    'init' { Invoke-Init }
    'status' { Invoke-Status }
    'run' { Invoke-Run }
    default {
        if ($Json) { Invoke-Run } else { Invoke-Status }
    }
}
