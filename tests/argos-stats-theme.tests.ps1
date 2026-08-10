# ============================================================
# ARNES - verificacion de argos stats (F3) y argos theme (F2)
#
# Crea un proyecto temporal con quest-ledger conocido y verifica
# el dashboard de stats y el round-trip del tema en config.json.
#
# Uso:  powershell -NoProfile -ExecutionPolicy Bypass -File tests/argos-stats-theme.tests.ps1
# Exit: 0 = PASS | 1 = FAIL
# ============================================================
$ErrorActionPreference = 'Stop'
$Root = Resolve-Path (Join-Path $PSScriptRoot '..')
$StatsCli = Join-Path $Root 'cli\argos-stats.ps1'
$ThemeCli = Join-Path $Root 'cli\argos-theme.ps1'
$work = Join-Path $Root ('.arnes-stats-test-' + [guid]::NewGuid().ToString('N'))
$workArnes = Join-Path $work '.arnes'

function Assert-That {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw "Assertion failed: $Message" }
}

New-Item -ItemType Directory -Path $workArnes -Force | Out-Null
try {
    # Ledger conocido: 3 quests, 2 PASS + 1 FAIL, tokens 100+200+300=600
    $ledger = [ordered]@{
        quests = @(
            [ordered]@{ agent = 'vivi'; verdict = 'PASS'; tokens_used = 100; quest_id = 'T-1'; timestamp = (Get-Date).AddDays(-1).ToString('o') },
            [ordered]@{ agent = 'ansem'; verdict = 'PASS'; tokens_used = 200; quest_id = 'T-2'; timestamp = (Get-Date).ToString('o') },
            [ordered]@{ agent = 'kuja'; verdict = 'FAIL'; tokens_used = 300; quest_id = 'T-3'; timestamp = (Get-Date).ToString('o') }
        )
    } | ConvertTo-Json -Depth 5
    Set-Content -LiteralPath (Join-Path $workArnes 'quest-ledger.json') -Value $ledger -Encoding UTF8

    Push-Location $work
    try {
        # ==== STATS ====
        $stats = (& powershell -NoProfile -ExecutionPolicy Bypass -File $StatsCli | Out-String)
        Assert-That ($stats -match 'Quests:\s+3') "stats: 3 quests -> $stats"
        Assert-That ($stats -match 'Tasa de exito:\s+66\.7%') "stats: 2/3 PASS = 66.7% -> $stats"
        Assert-That ($stats -match 'Tokens usados:\s+600') "stats: tokens 600 -> $stats"

        # ==== THEME ====
        $setOut = (& powershell -NoProfile -ExecutionPolicy Bypass -File $ThemeCli set -Name vivi | Out-String)
        Assert-That ($setOut -match "Tema cambiado a 'vivi'") "theme set vivi -> $setOut"
        $cfg = Get-Content (Join-Path $workArnes 'config.json') -Raw | ConvertFrom-Json
        Assert-That ([string]$cfg.theme -eq 'vivi') "config.json theme == vivi (obtenido $($cfg.theme))"
        $showOut = (& powershell -NoProfile -ExecutionPolicy Bypass -File $ThemeCli show | Out-String)
        Assert-That ($showOut -match 'vivi') "theme show refleja vivi -> $showOut"

        Write-Output 'PASS argos-stats-theme: dashboard calcula bien y tema persiste'
        exit 0
    } finally { Pop-Location }
} finally {
    if (Test-Path -LiteralPath $work) {
        Remove-Item -LiteralPath $work -Recurse -Force
    }
}
