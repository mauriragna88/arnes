#Requires -Version 5.1
<#
.SYNOPSIS
ARGOS STATS - dashboard de actividad basado en quest-ledger.

.DESCRIPTION
Lee `.arnes/quest-ledger.json` y muestra: quests totales, tokens usados,
desglose por dia (ultimos 7), por agente, tasa de exito y racha de dias activos.

.EXAMPLE
.\cli\argos-stats.ps1
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$WorkDir = (Get-Location).Path
$LedgerFile = Join-Path $WorkDir '.arnes\quest-ledger.json'

if (-not (Test-Path $LedgerFile)) {
    Write-Host '  [!] No hay quest-ledger.json en este proyecto.' -ForegroundColor Yellow
    exit 1
}

$ledger = Get-Content $LedgerFile -Raw | ConvertFrom-Json
$quests = @($ledger.quests)
if ($quests.Count -eq 0) {
    Write-Host '  [!] El quest-ledger no tiene quests registrados.' -ForegroundColor Yellow
    exit 1
}

$today = (Get-Date).Date
$totalTokens = 0
$passCount = 0
$byDay = @{}
$byAgent = @{}
$byWeek = @{}

foreach ($q in $quests) {
    $tokens = [int]$q.tokens_used
    $totalTokens += $tokens
    if ([string]$q.verdict -eq 'PASS') { $passCount++ }

    $ts = [datetime]::MinValue
    if (-not [DateTime]::TryParse([string]$q.timestamp, [ref]$ts)) { continue }
    $dayKey = $ts.Date.ToString('yyyy-MM-dd')
    $weekKey = ('{0}-W{1:00}' -f $ts.Year, [Globalization.CultureInfo]::InvariantCulture.Calendar.GetWeekOfYear($ts, [System.DayOfWeek]::Monday, [System.DayOfWeek]::Monday))
    if (-not $byDay.ContainsKey($dayKey)) { $byDay[$dayKey] = 0 }
    $byDay[$dayKey] += $tokens
    if (-not $byWeek.ContainsKey($weekKey)) { $byWeek[$weekKey] = 0 }
    $byWeek[$weekKey] += $tokens

    $name = [string]$q.agent
    if ($name) {
        if (-not $byAgent.ContainsKey($name)) { $byAgent[$name] = @{ quests = 0; tokens = 0 } }
        $byAgent[$name].quests++
        $byAgent[$name].tokens += $tokens
    }
}

# Racha: dias consecutivos con actividad terminando hoy (o ayer si hoy no hubo)
$activeDays = @($byDay.Keys | Sort-Object -Descending)
$streak = 0
$cursor = $today
if ($activeDays.Count -gt 0 -and $activeDays[0] -ne $today.ToString('yyyy-MM-dd')) {
    $cursor = $today.AddDays(-1)
}
while ($activeDays -contains $cursor.ToString('yyyy-MM-dd')) {
    $streak++
    $cursor = $cursor.AddDays(-1)
}

$successPct = [math]::Round(($passCount / $quests.Count) * 100, 1)
$topAgent = ($byAgent.GetEnumerator() | Sort-Object { $_.Value.tokens } -Descending | Select-Object -First 1)

Write-Host ''
Write-Host '  ARNES ARGOS - STATS' -ForegroundColor Cyan
Write-Host '  ==================' -ForegroundColor Cyan
Write-Host ("  Quests:          {0}" -f $quests.Count) -ForegroundColor White
Write-Host ("  Tasa de exito:   {0}%  ({1} PASS / {2})" -f $successPct, $passCount, $quests.Count) -ForegroundColor White
Write-Host ("  Tokens usados:   {0}" -f $totalTokens) -ForegroundColor White
Write-Host ("  Racha de dias:   {0}" -f $streak) -ForegroundColor White
Write-Host ("  Top por tokens:  {0} ({1} tkns, {2} quests)" -f $topAgent.Key, $topAgent.Value.tokens, $topAgent.Value.quests) -ForegroundColor White

Write-Host ''
Write-Host '  Ultimos 7 dias:' -ForegroundColor Cyan
$last7 = @($byDay.GetEnumerator() | Sort-Object Key -Descending | Select-Object -First 7)
foreach ($d in $last7) {
    Write-Host ("    {0}  {1} tkns" -f $d.Key, $d.Value) -ForegroundColor White
}

Write-Host ''
Write-Host '  Por agente:' -ForegroundColor Cyan
foreach ($a in ($byAgent.GetEnumerator() | Sort-Object { $_.Value.tokens } -Descending)) {
    Write-Host ("    {0,-12} {1} tkns · {2} quests" -f $a.Key, $a.Value.tokens, $a.Value.quests) -ForegroundColor White
}
Write-Host ''
