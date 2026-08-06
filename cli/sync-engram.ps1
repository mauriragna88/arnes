# sync-engram.ps1 - Sincroniza archivos JSONL de memoria .arnes/memory/ con el servidor engram
# ==========================================================================================
# Lee cada archivo .jsonl en .arnes/memory/ y hace POST a http://127.0.0.1:7437/observations
# Si el servidor no esta disponible, sale limpiamente y reporta fallback a JSONL.
# Es idempotente: correrlo multiples veces no duplica datos (la idempotencia depende del server).
#Requires -Version 5.1

param(
    [string]$ArnesRoot = "$PSScriptRoot\..",
    [string]$EngramUrl = "http://127.0.0.1:7437"
)

$ErrorActionPreference = "Continue"

$memoryDir = Join-Path $ArnesRoot ".arnes\memory"

if (-not (Test-Path $memoryDir)) {
    Write-Host "[engram] Memory directory not found: $memoryDir" -ForegroundColor Yellow
    exit 0
}

# --- Health check ---
try {
    $health = Invoke-RestMethod -Uri "$EngramUrl/health" -TimeoutSec 3 -ErrorAction Stop
    Write-Host "[engram] Server VIVO" -ForegroundColor Green
}
catch {
    Write-Host "[engram] Server NO disponible. Sync skipped." -ForegroundColor Yellow
    exit 0
}

# --- Sync each JSONL file ---
$synced = 0
$files = 0
$failed = 0

Get-ChildItem $memoryDir -Filter "*.jsonl" | ForEach-Object {
    $files++
    $lines = Get-Content $_.FullName | Where-Object { $_.Trim() -ne "" }

    foreach ($line in $lines) {
        try {
            $obs = $line | ConvertFrom-Json

            $body = @{
                content = $obs.content
                type    = if ($obs.type) { $obs.type } else { "observation" }
                title   = if ($obs.title) { $obs.title } else { "sync" }
                scope   = "project"
            }

            if ($obs.quest_id) {
                $body["metadata"] = @{ quest_id = $obs.quest_id }
            }

            if ($obs.timestamp) {
                $body["timestamp"] = $obs.timestamp
            }

            $json = $body | ConvertTo-Json -Depth 3 -Compress

            Invoke-RestMethod `
                -Uri "$EngramUrl/observations" `
                -Method Post `
                -Body $json `
                -ContentType "application/json" `
                -TimeoutSec 5 `
                -ErrorAction Stop | Out-Null

            $synced++
        }
        catch {
            Write-Host "  WARN: Failed to sync line from $($_.Name): $_" -ForegroundColor Yellow
            $failed++
        }
    }
}

if ($synced -gt 0) {
    Write-Host "[engram] Synced $synced observations from $files files" -ForegroundColor Green
}
else {
    Write-Host "[engram] No observations synced. $failed errors from $files files." -ForegroundColor Yellow
}

if ($failed -gt 0) {
    exit 1
}

exit 0