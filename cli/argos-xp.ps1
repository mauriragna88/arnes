#Requires -Version 5.1
<#
.SYNOPSIS
ARGOS XP - ranking de experiencia por agente basado en quest-ledger.

.DESCRIPTION
Lee `.arnes/quest-ledger.json` del proyecto, acumula XP por agente
(PASS = +100 XP, FAIL = +10 XP) y calcula nivel con la formula
nivel = floor(sqrt(xp/100)) + 1. Muestra el ranking completo o un agente.

.EXAMPLE
.\cli\argos-xp.ps1
.\cli\argos-xp.ps1 -Agent vivi
#>
[CmdletBinding()]
param(
    [string]$Agent = ''
)

$ErrorActionPreference = 'Stop'

$Root = Resolve-Path (Join-Path $PSScriptRoot '..')
$WorkDir = (Get-Location).Path
$ArnesDir = Join-Path $WorkDir '.arnes'
$LedgerFile = Join-Path $ArnesDir 'quest-ledger.json'

if (-not (Test-Path $LedgerFile)) {
    Write-Host '  [!] No hay quest-ledger.json en este proyecto.' -ForegroundColor Yellow
    Write-Host '      Completa un quest primero (argos quest o argos party).' -ForegroundColor Yellow
    exit 1
}

$ledger = Get-Content $LedgerFile -Raw | ConvertFrom-Json

# ==== Formula de nivel ====
function Get-Level([int]$xp) {
    if ($xp -le 0) { return 1 }
    return [math]::Floor([math]::Sqrt($xp / 100.0)) + 1
}

# ==== Acumular XP por agente ====
$xpMap = @{}
$questMap = @{}
$tokenMap = @{}
foreach ($q in @($ledger.quests)) {
    $name = [string]$q.agent
    if (-not $name) { continue }
    if (-not $xpMap.ContainsKey($name)) { $xpMap[$name] = 0; $questMap[$name] = 0; $tokenMap[$name] = 0 }
    $xpMap[$name] += if ([string]$q.verdict -eq 'PASS') { 100 } else { 10 }
    $questMap[$name]++
    $tokenMap[$name] += [int]$q.tokens_used
}

if ($xpMap.Count -eq 0) {
    Write-Host '  [!] El quest-ledger no tiene quests registrados.' -ForegroundColor Yellow
    exit 1
}

# ==== Output ====
if ($Agent) {
    $name = $Agent.ToLower()
    if (-not $xpMap.ContainsKey($name)) {
        Write-Host "  [!] No hay XP para el agente '$Agent'." -ForegroundColor Yellow
        exit 1
    }
    $xp = $xpMap[$name]
    Write-Host ''
    Write-Host "  $name - Nivel $(Get-Level $xp) (XP $xp)" -ForegroundColor Cyan
    Write-Host "    Quests: $($questMap[$name]) | Tokens usados: $($tokenMap[$name])" -ForegroundColor White
    Write-Host ''
    exit 0
}

Write-Host ''
Write-Host '  ARNES ARGOS - RANKING XP' -ForegroundColor DarkRed
Write-Host '  ========================' -ForegroundColor DarkRed
Write-Host ''
$rows = $xpMap.GetEnumerator() | Sort-Object Value -Descending
foreach ($r in $rows) {
    $lvl = Get-Level ([int]$r.Value)
    Write-Host ("  {0,-12} Nivel {1,-4} XP {2,-6} Quest(s) {3,-3} Tokens {4}" -f $r.Key, $lvl, $r.Value, $questMap[$r.Key], $tokenMap[$r.Key]) -ForegroundColor White
}
Write-Host ''
