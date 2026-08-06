#Requires -Version 5.1
<#
.SYNOPSIS
ARNES PICKER - Selector interactivo con flechas (estilo /models de OpenCode)

.DESCRIPTION
Navegable con flechas arriba/abajo, Enter para seleccionar, Q para continuar,
Esc para cancelar. Colores rojo/negro del arnes.

.EXAMPLE
$choice = .\arnes-picker.ps1 -Title "Elige modelo para Vivi" -Options @("opencode-go/gpt-5.6-luna", "opencode-go/deepseek-v4-flash")
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Title,

    [Parameter(Mandatory = $true)]
    [string[]]$Options,

    [int]$DefaultIndex = 0,

    [string]$Group = ''
)

$ErrorActionPreference = 'Stop'

# Sin opciones = salida vacia
if ($Options.Count -eq 0) {
    Write-Output ''
    exit 0
}

# Normalizar indice
if ($DefaultIndex -lt 0 -or $DefaultIndex -ge $Options.Count) { $DefaultIndex = 0 }
$selected = $DefaultIndex

# Detectar si estamos en consola interactiva
$interactive = $true
try {
    $null = [Console]::CursorVisible
} catch {
    $interactive = $false
}

if (-not $interactive) {
    # Modo no interactivo: devolver el default
    Write-Output $Options[$DefaultIndex]
    exit 0
}

# Renderizar la lista
function Show-Picker {
    Clear-Host
    Write-Host ''
    Write-Host "  $Title" -ForegroundColor Cyan
    if ($Group) {
        Write-Host "  [$Group]" -ForegroundColor DarkGray
    }
    Write-Host '  ' + ('-' * 60) -ForegroundColor DarkGray
    for ($i = 0; $i -lt $Options.Count; $i++) {
        if ($i -eq $selected) {
            Write-Host ("  > {0}" -f $Options[$i]) -ForegroundColor Red -NoNewline
            Write-Host "  <-" -ForegroundColor White
        } else {
            Write-Host ("    {0}" -f $Options[$i]) -ForegroundColor White
        }
    }
    Write-Host ''
    Write-Host '  [↑/↓] mover   [Enter] seleccionar   [Q] siguiente   [Esc] cancelar' -ForegroundColor DarkGray
}

Show-Picker

while ($true) {
    $key = [Console]::ReadKey($true)
    switch ($key.Key) {
        'UpArrow' {
            if ($selected -gt 0) { $selected-- }
            Show-Picker
        }
        'DownArrow' {
            if ($selected -lt $Options.Count - 1) { $selected++ }
            Show-Picker
        }
        'Enter' {
            Clear-Host
            Write-Output $Options[$selected]
            exit 0
        }
        'Q' {
            Clear-Host
            Write-Output $Options[$selected]
            exit 0
        }
        'q' {
            Clear-Host
            Write-Output $Options[$selected]
            exit 0
        }
        'Escape' {
            Clear-Host
            Write-Output ''
            exit 130
        }
    }
}
