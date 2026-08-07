<#
.SYNOPSIS
ARGOS SUPERPOWERS - launcher: health-check + arranque de Pi como runtime (single brain).
.SUMMARY
Solo arranca la experiencia. El desarrollo ocurre DENTRO de Pi. La única memoria
persistente es <proyecto>/.arnes/arnes.db (pi corre con --no-session).
#>
[CmdletBinding()]
param([switch]$DryRun)
$ErrorActionPreference = 'Stop'

# 1. project root + .arnes
$root = (Get-Location).Path
$arnes = Join-Path $root '.arnes'
if (-not (Test-Path (Join-Path $arnes 'arnes.db'))) {
    Write-Host '  [ARGOS] Sin .arnes/arnes.db aqui.' -ForegroundColor Yellow
    Write-Host '  [ARGOS] Se abrira Pi normal (sin ARGOS).' -ForegroundColor Yellow
    if ($DryRun) { exit 0 }
    & pi --no-session
    exit $LASTEXITCODE
}

# 2. health-check basico (memoria)
Write-Host '  [ARGOS] Health-check...' -ForegroundColor Cyan
$memCli = Join-Path $root 'cli\arnes-memory.ps1'
$stats = & $memCli stats 2>&1 | Out-String
if ($LASTEXITCODE -ne 0) {
    Write-Host "  [ARGOS] FALLO memoria: $stats" -ForegroundColor Red
    exit 1
}

# 3. pi + superpowers + modelos
if (-not (Get-Command pi -ErrorAction SilentlyContinue)) {
    Write-Host '  [ARGOS] FALLO: pi no instalado' -ForegroundColor Red
    exit 1
}
$sp = & { $ErrorActionPreference = 'Continue'; (& pi list 2>&1 | Out-String) }
if ($sp -notmatch 'superpowers') {
    Write-Host '  [ARGOS] AVISO: superpowers no visible en pi list' -ForegroundColor Yellow
}
$models = Join-Path $env:USERPROFILE '.config\arnes\agent-models.json'
if (-not (Test-Path $models)) {
    Write-Host '  [ARGOS] AVISO: no hay agent-models.json global' -ForegroundColor Yellow
}

# 4. banner
Write-Host '╔══════════════════════════════════════════════════╗' -ForegroundColor Red
Write-Host '║               ARGOS SUPERPOWERS                  ║' -ForegroundColor Red
Write-Host '╠══════════════════════════════════════════════════╣' -ForegroundColor Red
Write-Host '║ Runtime       Pi Coding Agent                    ║' -ForegroundColor Gray
Write-Host '║ Brain         ARGOS Cognitive Memory V3          ║' -ForegroundColor Gray
Write-Host '║ Memory        .arnes/arnes.db                    ║' -ForegroundColor Gray
Write-Host '║ RAG           FTS5 / BM25                        ║' -ForegroundColor Gray
Write-Host '║ Graph         READY                              ║' -ForegroundColor Gray
Write-Host '║ Party         16 agents                          ║' -ForegroundColor Gray
Write-Host '║ Superpowers   READY                              ║' -ForegroundColor Gray
Write-Host '╚══════════════════════════════════════════════════╝' -ForegroundColor Red
Write-Host ''

# 5. transferir a Pi (single brain)
if ($DryRun) { exit 0 }
& pi --no-session
exit $LASTEXITCODE
