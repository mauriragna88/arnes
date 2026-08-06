#Requires -Version 5.1
<#
.SYNOPSIS
ARGOS RECOMMEND - Mini-guia inteligente de modelos

.DESCRIPTION
Detecta proveedores conectados (connections.json global) y recomienda el mejor
modelo por agente. Pregunta al usuario: ahorrar tokens o maxima calidad.
Basado en benchmarks de la industria (coding, agentic, value).

.EXAMPLE
.\argos-recommend.ps1          -> recomendar modelos por agente
.\argos-recommend.ps1 -Apply   -> guardar recomendacion en agent-models.json
#>
[CmdletBinding()]
param(
    [switch]$Apply
)

$ErrorActionPreference = 'Stop'
$ScriptDir = $PSScriptRoot
$GlobalConfigDir = Join-Path $env:USERPROFILE '.config\arnes'
$ConnPath = Join-Path $GlobalConfigDir 'connections.json'
$ProjectDir = (Get-Location).Path
$ArnesDir = Join-Path $ProjectDir '.arnes'
$AgentModelsPath = Join-Path $ArnesDir 'agent-models.json'

# Forzar UTF-8
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

# === Agentes con descripcion breve (para tomar la mejor decision) ===
$AGENTS = @(
    @{ key = 'atlas';    name = 'Atlas';    role = 'Orquestador: delega, decide, loopea. Poco volumen, necesita buen razonamiento' }
    @{ key = 'vivi';     name = 'Vivi';     role = 'Frontend: React, Tailwind, UI/UX. Volumen alto, velocidad + calidad visual' }
    @{ key = 'ansem';    name = 'Ansem';    role = 'Backend: APIs, Supabase, Zod. Volumen alto, precisión' }
    @{ key = 'kuja';     name = 'Kuja';     role = 'QA: tests, edge cases, seguridad. Precisión, buen razonamiento' }
    @{ key = 'eiko';     name = 'Eiko';     role = 'DevOps: builds, CI/CD, fixes. Volumen medio, velocidad' }
    @{ key = 'amarant';  name = 'Amarant';  role = 'Arquitectura: SDD, diseño, decisiones. Bajo volumen, MAXIMO razonamiento' }
    @{ key = 'eremez';   name = 'Eremez';   role = 'Research: docs, librerias, web. Volumen medio, velocidad' }
    @{ key = 'auron';    name = 'Auron';    role = 'Seguridad: L0 gate, OWASP, RLS. Bajo volumen, alto razonamiento' }
    @{ key = 'bran';     name = 'Bran';     role = 'Analista: %, dead code, growth. Bajo volumen, razonamiento medio' }
    @{ key = 'quina';    name = 'Quina';    role = 'Tokens: presupuesto, /status. Volumen bajisimo, barato' }
    @{ key = 'varys';    name = 'Varys';    role = 'Tracker: observa, evidence_pack. Volumen alto, velocidad' }
    @{ key = 'tywin';    name = 'Tywin';    role = 'Verificador: PASS/FAIL. Volumen medio, razonamiento alto' }
    @{ key = 'sam';      name = 'Sam';      role = 'Consejero: memoria historica, recomendaciones. Bajo volumen, razonamiento alto' }
    @{ key = 'bard';     name = 'Bard';     role = 'Mejora: refactor, deuda, docs. Volumen bajo, razonamiento medio' }
    @{ key = 'tidus';    name = 'Tidus';    role = 'Infra: health-check, cuotas. Volumen bajisimo, barato' }
    @{ key = 'ragnarok'; name = 'Ragnarok'; role = 'Compras: investiga web, compara. Volumen bajo, razonamiento medio-alto' }
)

# === Benchmarks por familia de modelo (resumen 2026) ===
# value: 1=barato 2=equilibrado 3=calidad maxima
$BENCHMARKS = @{
    'opencode-go/deepseek-v4-flash' = @{ quality = 2; cost = 1; speed = 3; desc = 'Workhorse barato y rapido. Excelente coding general' }
    'opencode-go/deepseek-v4-pro'   = @{ quality = 3; cost = 2; speed = 2; desc = 'Razonamiento profundo. Mejor para logica compleja' }
    'opencode-go/qwen3.8-max'       = @{ quality = 3; cost = 3; speed = 2; desc = 'TOP agente/orquestacion. El mas inteligente' }
    'opencode-go/gpt-5.6-luna'      = @{ quality = 3; cost = 2; speed = 3; desc = 'GPT velocidad/valor. Excelente generalista' }
    'opencode-go/glm-5.2'           = @{ quality = 2; cost = 2; speed = 2; desc = 'Equilibrado (Zhipu)' }
    'opencode-go/kimi-k2.6'         = @{ quality = 2; cost = 2; speed = 2; desc = 'Razonamiento chino solido' }
    'openai/gpt-5.6-luna'           = @{ quality = 3; cost = 2; speed = 3; desc = 'GPT-5.6 Luna: velocidad + valor' }
    'openai/gpt-5.6-terra'          = @{ quality = 4; cost = 3; speed = 2; desc = 'GPT-5.6 Terra: balanceado premium' }
    'openai/gpt-5.6-sol'            = @{ quality = 5; cost = 3; speed = 1; desc = 'GPT-5.6 Sol: MAXIMO razonamiento' }
    'claude/claude-opus-5'          = @{ quality = 5; cost = 3; speed = 1; desc = 'Claude Opus 5: elite' }
    'claude/claude-sonnet-5'        = @{ quality = 4; cost = 2; speed = 3; desc = 'Claude Sonnet 5: balance elite' }
    'bai/claude-opus-5'             = @{ quality = 5; cost = 3; speed = 1; desc = 'Claude Opus 5 via B.AI' }
    'bai/claude-fable-5'            = @{ quality = 4; cost = 2; speed = 3; desc = 'Claude Fable 5 via B.AI: rapido' }
    'bai/gpt-5.6-sol'               = @{ quality = 5; cost = 3; speed = 1; desc = 'GPT-5.6 Sol via B.AI' }
    'nvidia/deepseek-ai/deepseek-v4-flash' = @{ quality = 2; cost = 0; speed = 3; desc = 'DeepSeek Flash GRATIS (NVIDIA)' }
    'nvidia/deepseek-ai/deepseek-v4-pro'   = @{ quality = 3; cost = 0; speed = 2; desc = 'DeepSeek Pro GRATIS (NVIDIA)' }
}

# === Obtener modelos disponibles de proveedores conectados ===
function Get-AvailableModels {
    if (-not (Test-Path $ConnPath)) { return @() }
    $data = Get-Content $ConnPath -Raw | ConvertFrom-Json
    $models = @()
    foreach ($p in $data.providers.PSObject.Properties) {
        if ($p.Value.connected) {
            foreach ($m in @($p.Value.models)) {
                $models += ("{0}/{1}" -f $p.Name, $m)
            }
        }
    }
    return @($models | Sort-Object -Unique)
}

# === Recomendar modelo para un rol segun prioridad ===
function Get-Recommendation {
    param(
        [string]$AgentKey,
        [string]$Priority  # ahorro | equilibrio | calidad
    )
    $models = Get-AvailableModels
    if ($models.Count -eq 0) { return '' }

    $best = $null
    $bestScore = -1
    foreach ($m in $models) {
        $bm = $BENCHMARKS[$m]
        if (-not $bm) { continue }
        # Score segun prioridad
        $score = switch ($Priority) {
            'ahorro' { $bm.cost * 10 + $bm.speed * 5 - $bm.quality * 2 }
            'calidad' { $bm.quality * 10 + $bm.speed * 2 - $bm.cost }
            default { $bm.quality * 7 + $bm.speed * 3 - $bm.cost }
        }
        if ($score -gt $bestScore) {
            $bestScore = $score
            $best = $m
        }
    }
    return $best
}

# === MAIN ===
Write-Host ''
Write-Host '  ╔══════════════════════════════════════════════════════════╗' -ForegroundColor DarkRed
Write-Host '  ║   ARNES ARGOS - Recomendacion inteligente de modelos     ║' -ForegroundColor White
Write-Host '  ╚══════════════════════════════════════════════════════════╝' -ForegroundColor DarkRed
Write-Host ''

# 1. Verificar conexiones
$models = Get-AvailableModels
if ($models.Count -eq 0) {
    Write-Host '  [!] No hay proveedores conectados.' -ForegroundColor Yellow
    Write-Host '  Primero conecta tus modelos de IA:' -ForegroundColor White
    Write-Host '    argos connect' -ForegroundColor Cyan
    Write-Host '  (Se hace UNA VEZ por computadora - conexiones globales)' -ForegroundColor DarkGray
    exit 1
}

Write-Host "  Proveedores conectados ($($models.Count) modelos disponibles):" -ForegroundColor Cyan
$models | ForEach-Object { Write-Host "    $_" -ForegroundColor White }
Write-Host ''

# 2. Preguntar prioridad
Write-Host '  ¿Que prefieres?' -ForegroundColor White
Write-Host '  [1] AHORRAR tokens (usa modelos baratos/gratis)' -ForegroundColor Yellow
Write-Host '  [2] EQUILIBRIO (calidad/costo balanceado)' -ForegroundColor Green
Write-Host '  [3] MAXIMA CALIDAD (los mejores modelos sin importar costo)' -ForegroundColor Magenta
$choice = Read-Host '  Elige [1/2/3]'
$priority = switch ($choice) { '1' { 'ahorro' } '3' { 'calidad' } default { 'equilibrio' } }

Write-Host ''
Write-Host "  ▸ Prioridad: $priority" -ForegroundColor Cyan
Write-Host ''

# 3. Recomendar por agente
$recommendations = [ordered]@{}
foreach ($a in $AGENTS) {
    $rec = Get-Recommendation -AgentKey $a.key -Priority $priority
    if ($rec) {
        $recommendations[$a.key] = $rec
        Write-Host ("  {0,-10} {1,-25} -> {2}" -f $a.name, $a.role.Substring(0, [Math]::Min(25, $a.role.Length)), $rec) -ForegroundColor White
    }
}

# 4. Guardar
if ($Apply) {
    $out = [ordered]@{
        version = '1.0'
        priority = $priority
        updated_at = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
        agents = $recommendations
    }
    $out | ConvertTo-Json -Depth 6 | Set-Content -Path $AgentModelsPath -Encoding UTF8
    Write-Host ''
    Write-Host '  [OK] Recomendacion guardada en .arnes/agent-models.json' -ForegroundColor Green
    Write-Host '  Puedes ajustar manualmente con: argos configure' -ForegroundColor DarkGray
} else {
    Write-Host ''
    Write-Host '  Para guardar: usa -Apply  (argos recommend -Apply)' -ForegroundColor DarkGray
}
