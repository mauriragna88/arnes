#Requires -Version 5.1
<#
.SYNOPSIS
ARGOS CHAT - Chat nativo de ARNES ARGOS (CLI propio, sin TUI de OpenCode)

.DESCRIPTION
Loop de chat interactivo con el agente atlas-player via `opencode run` (headless).
Prompt propio, colores rojo/negro, comandos propios. El motor es OpenCode por debajo
pero la interfaz es 100% ARNES ARGOS.

.EXAMPLE
.\argos-chat.ps1                 -> chat interactivo
.\argos-chat.ps1 -Quest "haz login form con Zod"  -> quest directo sin TUI
#>
[CmdletBinding()]
param(
    [string]$Quest = '',
    [switch]$Agent = $false,
    [string]$AgentName = 'atlas-player'
)

$ErrorActionPreference = 'Stop'
$Root = Resolve-Path (Join-Path $PSScriptRoot '..')
$ArnesDir = Join-Path $Root '.arnes'

# Forzar UTF-8
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

# === Banner mini ===
function Show-MiniBanner {
    Write-Host ''
    Write-Host "  ╔══════════════════════════════════════════════════════════════╗" -ForegroundColor DarkRed
    Write-Host "  ║   ARNES ARGOS - Chat del Orquestador RPG - Los 100 Ojos   ║" -ForegroundColor White
    Write-Host "  ╚══════════════════════════════════════════════════════════════╝" -ForegroundColor DarkRed
    Write-Host ''
}

# === Ejecutar un quest via opencode run (headless, sin TUI) ===
function Invoke-ArgoQuest {
    param([string]$Message)

    $hasOpenCode = [bool](Get-Command opencode -ErrorAction SilentlyContinue)
    if (-not $hasOpenCode) {
        Write-Host '  [!] opencode no encontrado en PATH' -ForegroundColor Red
        return
    }

    Write-Host ''
    Write-Host "  ▸ Delegando a Atlas (agent: $AgentName)..." -ForegroundColor Cyan
    Write-Host "  ▸ Quest: $Message" -ForegroundColor DarkGray
    Write-Host '  ▸ Trabajando...' -ForegroundColor DarkGray
    Write-Host ''

    # Ejecutar opencode en modo headless, capturar salida
    $output = @(& opencode run --agent $AgentName "$Message" 2>&1)
    $exit = $LASTEXITCODE

    # Mostrar salida (limpiar el ruido de stderr de npm)
    $output | Where-Object { $_ -notmatch '^opencode\.exe|^En l|^\+|^~~~|CategoryInfo|FullyQualifiedErrorId' } | ForEach-Object {
        Write-Host "  $_" -ForegroundColor White
    }

    Write-Host ''
    Write-Host "  [OK] Quest procesado (exit=$exit)" -ForegroundColor Green
    Write-Host '  (El resultado completo quedo en la sesion de opencode; revisa con: opencode)'
}

# === Chat interactivo propio ===
function Show-InteractiveChat {
    Show-MiniBanner
    Write-Host '  Bienvenido al chat de ARNES ARGOS.' -ForegroundColor Green
    Write-Host '  Escribe tus quests (ej: "haz login form con Zod") o usa los comandos:' -ForegroundColor White
    Write-Host '    /party    ver party' -ForegroundColor DarkGray
    Write-Host '    /memory   estado de memoria' -ForegroundColor DarkGray
    Write-Host '    /models   ver catalogo de modelos' -ForegroundColor DarkGray
    Write-Host '    /status   estado del harness' -ForegroundColor DarkGray
    Write-Host '    /quit     salir' -ForegroundColor DarkGray
    Write-Host ''

    while ($true) {
        Write-Host ''
        $input = Read-Host '  [ARGOS] >'

        switch -Regex ($input) {
            '^\s*/quit\s*$' {
                Write-Host '  Adios, jugador. Rojo y negro. 👁️' -ForegroundColor White
                exit 0
            }
            '^\s*/party\s*$' {
                Show-Party
                continue
            }
            '^\s*/memory\s*$' {
                $mem = Join-Path $PSScriptRoot 'arnes-memory.ps1'
                & $mem stats
                continue
            }
            '^\s*/models\s*$' {
                $raw = @(cmd /c 'opencode models' 2>$null)
                $models = @($raw | Where-Object { $_ -match '^[\w-]+/.+' })
                Write-Host "  Catalogo vivo: $($models.Count) modelos" -ForegroundColor Cyan
                $models | Group-Object { ($_ -split '/')[0] } | Sort-Object Name | Select-Object -First 10 | ForEach-Object {
                    Write-Host "  [$($_.Name)]" -ForegroundColor Yellow
                    $_.Group | Select-Object -First 5 | ForEach-Object { Write-Host "    $_" -ForegroundColor White }
                }
                continue
            }
            '^\s*/status\s*$' {
                Write-Host '  ARNES ARGOS - Estado' -ForegroundColor Cyan
                Write-Host "  Agentes: 16 · Memoria: arnes.db · Proceso: SDD/FDD/ADR" -ForegroundColor Green
                continue
            }
            default {
                if ([string]::IsNullOrWhiteSpace($input)) { continue }
                Invoke-ArgoQuest -Message $input
            }
        }
    }
}

function Show-Party {
    Write-Host ''
    Write-Host '  ARNES ARGOS - PARTY (16 agentes)' -ForegroundColor Cyan
    Write-Host '  Atlas (Player) · Vivi (Frontend) · Ansem (Backend) · Kuja (QA)' -ForegroundColor White
    Write-Host '  Eiko (DevOps) · Amarant (Arq) · Eremez (Research) · Auron (Sec)' -ForegroundColor White
    Write-Host '  Bran (Analista) · Quina (Tokens) · Varys (Tracker) · Tywin (Verif)' -ForegroundColor White
    Write-Host '  Sam (Consejero) · Bard (Mejora) · Tidus (Infra) · Ragnarok (Compras)' -ForegroundColor White
    Write-Host ''
}

# === MAIN ===
if ($Quest) {
    Show-MiniBanner
    Write-Host "  Quest directo: $Quest" -ForegroundColor Yellow
    Invoke-ArgoQuest -Message $Quest
} else {
    Show-InteractiveChat
}
