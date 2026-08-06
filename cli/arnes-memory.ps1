#Requires -Version 5.1
<#
.SYNOPSIS
ARNES MEMORY - CLI de memoria cerebral (arnes.db SQLite+FTS5)

.DESCRIPTION
El cerebro del harness. Guarda, busca y exporta recuerdos de los agentes.
100% local - Python + SQLite nativo. CERO dependencias externas.

.EXAMPLE
.\arnes-memory.ps1 init
.\arnes-memory.ps1 save -Agent vivi -Topic vivi/ui-patterns -Type pattern -Content "User prefiere dark mode"
.\arnes-memory.ps1 search -Query "dark mode" -Agent vivi
.\arnes-memory.ps1 context
.\arnes-memory.ps1 agent -Agent vivi
.\arnes-memory.ps1 export
.\arnes-memory.ps1 stats
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateSet('init', 'save', 'search', 'context', 'agent', 'export', 'import', 'stats', 'quest', 'quests', 'edge', 'edges')]
    [string]$Command,

    [string]$Agent,
    [string]$Topic,
    [ValidateSet('bugfix', 'decision', 'pattern', 'discovery', 'preference', 'verdict', 'recommendation', 'action', 'session_summary')]
    [string]$Type = 'discovery',
    [string]$Content,
    [string]$Query,
    [string]$QuestId,
    [string]$Json,
    [int]$Limit = 20,
    [string]$OutDir,
    [string]$InDir
)

$ErrorActionPreference = 'Stop'
$Root = Resolve-Path (Join-Path $PSScriptRoot '..')
$ArnesDir = Join-Path $Root '.arnes'
$DbPath = Join-Path $ArnesDir 'arnes.db'
$BrainScript = Join-Path $PSScriptRoot 'arnes_brain.py'

# Verificar Python
$python = Get-Command python -ErrorAction SilentlyContinue
if (-not $python) {
    Write-Host '[ERROR] Python no encontrado. El arnes necesita Python 3.14+.' -ForegroundColor Red
    exit 1
}

# Cargar la config para obtener los agentes conocidos (init)
function Get-KnownAgents {
    $agents = @()
    $configPath = Join-Path $ArnesDir 'config.json'
    if (Test-Path $configPath) {
        try {
            $cfg = Get-Content $configPath -Raw | ConvertFrom-Json
            foreach ($prop in $cfg.characters.PSObject.Properties) {
                $agents += [ordered]@{
                    id    = $prop.Name
                    name  = $prop.Value.name
                    class = $prop.Value.class
                    role  = $prop.Value.role
                    model = $prop.Value.model_opencode
                }
            }
        } catch {}
    }
    # Auditores + player
    $extra = @(
        @{ id = 'atlas'; name = 'Atlas'; class = 'Player'; role = 'Orchestrator' },
        @{ id = 'varys'; name = 'Varys'; class = 'Spider'; role = 'Tracker' },
        @{ id = 'tywin'; name = 'Tywin'; class = 'Verifier'; role = 'Auditor' },
        @{ id = 'sam'; name = 'Sam'; class = 'Archivist'; role = 'Counselor' },
        @{ id = 'tidus'; name = 'Tidus'; class = 'Warden'; role = 'Infrastructure' },
        @{ id = 'ragnarok'; name = 'Ragnarok'; class = 'Warden'; role = 'Procurement' }
    )
    foreach ($e in $extra) {
        if ($agents.id -notcontains $e.id) { $agents += $e }
    }
    return $agents
}

# Función helper: ejecutar python con stdin desde archivo temporal (evita encoding cp1252)
function Invoke-Brain {
    param([string]$CommandName, [string]$JsonData = '')
    if ($JsonData) {
        $tmp = Join-Path $env:TEMP ("arnes-" + [guid]::NewGuid().ToString('N') + ".json")
        Set-Content -Path $tmp -Value $JsonData -Encoding UTF8
        try {
            $out = Get-Content $tmp -Raw | & $python $BrainScript $DbPath $CommandName "-" 2>$null
            return $out
        } finally { Remove-Item $tmp -Force -ErrorAction SilentlyContinue }
    } else {
        $out = & $python $BrainScript $DbPath $CommandName @($CommandArgs) 2>$null
        return $out
    }
}

switch ($Command) {
    'init' {
        $agentsJson = Get-KnownAgents | ConvertTo-Json -Depth 5 -Compress
        $tmp = Join-Path $env:TEMP ("arnes-init-" + [guid]::NewGuid().ToString('N') + ".json")
        Set-Content -Path $tmp -Value $agentsJson -Encoding UTF8
        try {
            $out = Get-Content $tmp -Raw | & $python $BrainScript $DbPath init "-" 2>$null
            $stats = $out | Out-String | ConvertFrom-Json
            Write-Host ''
            Write-Host '  ARNES BRAIN inicializado' -ForegroundColor Cyan
            Write-Host ("  {0,-18} {1}" -f 'Agentes:', $stats.agents) -ForegroundColor White
            Write-Host ("  {0,-18} {1}" -f 'Observaciones:', $stats.observations) -ForegroundColor White
            Write-Host ("  {0,-18} {1}" -f 'Quests:', $stats.quests) -ForegroundColor White
            Write-Host ("  {0,-18} {1}" -f 'DB:', $DbPath) -ForegroundColor DarkGray
        } finally { Remove-Item $tmp -Force -ErrorAction SilentlyContinue }
    }
    'save' {
        if (-not $Content) { throw 'Falta -Content' }
        $saveAgent = if ($Agent) { $Agent } else { 'atlas' }
        $saveTopic = if ($Topic) { $Topic } else { 'atlas/general' }
        $data = @{
            agent     = $saveAgent
            topic_key = $saveTopic
            type      = $Type
            content   = $Content
            quest_id  = $QuestId
        } | ConvertTo-Json -Compress
        $tmp = Join-Path $env:TEMP ("arnes-save-" + [guid]::NewGuid().ToString('N') + ".json")
        Set-Content -Path $tmp -Value $data -Encoding UTF8
        try {
            $out = Get-Content $tmp -Raw | & $python $BrainScript $DbPath save "-" 2>$null
            $res = $out | Out-String | ConvertFrom-Json
            Write-Host ("  [OK] Memoria guardada (id={0})" -f $res.id) -ForegroundColor Green
            Write-Host ("       {0} | {1}" -f $saveAgent, $saveTopic) -ForegroundColor DarkGray
        } finally { Remove-Item $tmp -Force -ErrorAction SilentlyContinue }
    }
    'search' {
        if (-not $Query) { throw 'Falta -Query' }
        $agentArg = if ($Agent) { $Agent } else { '-' }
        $out = & $python $BrainScript $DbPath search $Query $agentArg $Limit 2>$null
        $results = $out | Out-String | ConvertFrom-Json
        if (-not $results -or $results.Count -eq 0) {
            Write-Host '  No se encontraron recuerdos.' -ForegroundColor Yellow
            exit 0
        }
        Write-Host ("  {0} recuerdo(s) encontrado(s)" -f $results.Count) -ForegroundColor Cyan
        foreach ($r in ($results | Select-Object -First 10)) {
            Write-Host ('  [{0}] {1}' -f $r.id, $r.topic_key) -ForegroundColor Yellow
            $short = $r.content
            if ($short.Length -gt 100) { $short = $short.Substring(0, 100) + '...' }
            Write-Host ("       {0}" -f $short) -ForegroundColor White
            Write-Host ("       ({0} | {1})" -f $r.agent, $r.created_at) -ForegroundColor DarkGray
        }
    }
    'context' {
        $out = & $python $BrainScript $DbPath context $Limit 2>$null
        $results = $out | Out-String | ConvertFrom-Json
        Write-Host ("  Contexto reciente: {0} observaciones" -f $results.Count) -ForegroundColor Cyan
        foreach ($r in ($results | Select-Object -First 10)) {
            Write-Host ('  [{0}] {1} | {2}' -f $r.id, $r.agent, $r.topic_key) -ForegroundColor White
        }
    }
    'agent' {
        if (-not $Agent) { throw 'Falta -Agent' }
        $out = & $python $BrainScript $DbPath agent $Agent $Limit 2>$null
        $results = $out | Out-String | ConvertFrom-Json
        Write-Host ("  Memoria de {0}: {1} recuerdos" -f $Agent, $results.Count) -ForegroundColor Cyan
        foreach ($r in ($results | Select-Object -First 10)) {
            Write-Host ('  [{0}] {1}' -f $r.id, $r.topic_key) -ForegroundColor Yellow
            $short = $r.content
            if ($short.Length -gt 80) { $short = $short.Substring(0, 80) + '...' }
            Write-Host ("       {0}" -f $short) -ForegroundColor White
        }
    }
    'export' {
        $target = if ($OutDir) { $OutDir } else { Join-Path $ArnesDir 'memory\export' }
        $out = & $python $BrainScript $DbPath export $target 2>$null
        Write-Host ("  [OK] Memoria exportada a {0}" -f $target) -ForegroundColor Green
    }
    'import' {
        $target = if ($InDir) { $InDir } else { Join-Path $ArnesDir 'memory\export' }
        if (-not (Test-Path $target)) { Write-Host '  No hay JSONL para importar.' -ForegroundColor Yellow; exit 0 }
        $out = & $python $BrainScript $DbPath import $target 2>$null
        $res = $out | Out-String | ConvertFrom-Json
        Write-Host ("  [OK] {0} recuerdos importados" -f $res.imported) -ForegroundColor Green
    }
    'stats' {
        $out = & $python $BrainScript $DbPath stats 2>$null
        $s = $out | Out-String | ConvertFrom-Json
        Write-Host ''
        Write-Host '  ARNES BRAIN - STATS' -ForegroundColor Cyan
        Write-Host ("  {0,-18} {1}" -f 'Agentes:', $s.agents) -ForegroundColor White
        Write-Host ("  {0,-18} {1}" -f 'Observaciones:', $s.observations) -ForegroundColor White
        Write-Host ("  {0,-18} {1}" -f 'Quests:', $s.quests) -ForegroundColor White
        Write-Host ("  {0,-18} {1}" -f 'Sesiones:', $s.sessions) -ForegroundColor White
        Write-Host ("  {0,-18} {1}" -f 'Edges:', $s.edges) -ForegroundColor White
        Write-Host ("  {0,-18} {1:N0} bytes" -f 'DB:', $s.db_size_bytes) -ForegroundColor White
    }
    'quest' {
        if (-not $Json) { throw 'Falta -Json (JSON con datos del quest)' }
        $tmp = Join-Path $env:TEMP ("arnes-quest-" + [guid]::NewGuid().ToString('N') + ".json")
        Set-Content -Path $tmp -Value $Json -Encoding UTF8
        try {
            $out = Get-Content $tmp -Raw | & $python $BrainScript $DbPath quest "-" 2>$null
            Write-Host ("  [OK] Quest registrado: {0}" -f ($out | Out-String).Trim()) -ForegroundColor Green
        } finally { Remove-Item $tmp -Force -ErrorAction SilentlyContinue }
    }
    'quests' {
        $out = & $python $BrainScript $DbPath quests 2>$null
        $results = $out | Out-String | ConvertFrom-Json
        Write-Host ("  Historial de quests: {0}" -f $results.Count) -ForegroundColor Cyan
        foreach ($q in ($results | Select-Object -First 10)) {
            $color = if ($q.result -eq 'PASS') { 'Green' } else { 'Red' }
            Write-Host ("  {0} [{1}] {2} ({3} tokens)" -f $q.id, $q.result, $q.quest_type, $q.tokens_used) -ForegroundColor $color
        }
    }
    'edge' {
        if (-not $Json) { throw 'Falta -Json (JSON con node_a, node_b, relation)' }
        $tmp = Join-Path $env:TEMP ("arnes-edge-" + [guid]::NewGuid().ToString('N') + ".json")
        Set-Content -Path $tmp -Value $Json -Encoding UTF8
        try {
            $out = Get-Content $tmp -Raw | & $python $BrainScript $DbPath edge "-" 2>$null
            Write-Host ("  [OK] Edge registrado: {0}" -f ($out | Out-String).Trim()) -ForegroundColor Green
        } finally { Remove-Item $tmp -Force -ErrorAction SilentlyContinue }
    }
    'edges' {
        $nodeArg = if ($Query) { $Query } else { '-' }
        $out = & $python $BrainScript $DbPath edges $nodeArg 2>$null
        $results = $out | Out-String | ConvertFrom-Json
        Write-Host ("  Relaciones: {0}" -f $results.Count) -ForegroundColor Cyan
        foreach ($e in ($results | Select-Object -First 15)) {
            Write-Host ("  {0} -[{1}]-> {2} ({3})" -f $e.node_a, $e.relation, $e.node_b, $e.agent) -ForegroundColor White
        }
    }
}
