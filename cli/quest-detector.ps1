# quest-detector.ps1 - B2 Classify user prompt into quest type + suggested party
# =============================================
# Detects quest_type (frontend/backend/fix/architecture/research/devops/boss)
# Returns JSON with: quest_type, complexity, suggested_party, is_l0, estimated_hp/mp
#
# Usage:
#   .\quest-detector.ps1 -Prompt "crea login form con Zod"
#   .\quest-detector.ps1 -Prompt "..." -Json

#Requires -Version 5.1
[CmdletBinding()]
param(
    [string]$Prompt = "",
    [switch]$Json,
    [switch]$Silent
)

$ErrorActionPreference = "Stop"

if (-not $Prompt) {
    Write-Error "Prompt required"
    exit 1
}

$promptLower = $Prompt.ToLower()

# === Detection rules: keyword -> quest_type ===
$patterns = @{
    "frontend" = @("componente","component","tsx","jsx","ui","css","tailwind","modal","dashboard","formulario","form","login form","signup","pagina","pantalla","responsive","animacion","sidebar","navbar","header","footer","button","input","select","checkbox","radio","card","hero","alert","tooltip","dialog","dropdown","menu","tabs","accordion","carousel","toast","avatar","badge","progress","skeleton","table","list","grid","layout","flexbox","gridbox","styled","emotion","css-in-js")
    "backend" = @("api","endpoint","route","supabase","postgres","postgresql","prisma","schema","query","mutation","rls","server action","middleware","zod","webhook","backend","server","database","table","migration","stored procedure","trigger","function","sql","rest","graphql","trpc","rpc","edge function","cron")
    "fix" = @("bug","fix","broken","error","fail","no funciona","crashea","crash","404","500","regression","regress","broken","doesn't work","won't work","failing","exception","stack trace","undefined","null pointer","race condition","memory leak","crashed")
    "architecture" = @("arquitectura","architecture","plan","redisen","refactor mayor","migrar","migration","monorepo","design system","project structure","adr","module","module boundary","clean architecture","hexagonal","microservice","monolith","serverless","event-driven","cqrs","event sourcing")
    "research" = @("investiga","busca","compara","que libreria","best practice","mejor forma","docs","documentation","como se hace","how to","tutorial","benchmark","comparison","library comparison","alternatives","vs")
    "devops" = @("deploy","ci","cd","docker","production","prod","rollback","vercel","netlify","railway","fly","github actions","pipeline","workflow","build","release","tag","semver","infrastructure","k8s","kubernetes","terraform","ansible","helm")
    "boss" = @("feature completa","nueva area","modulo entero","v1","mvp","from scratch","build a","rebuild","new project","greenfield","kickstart","bootstrap","launch","go-live","prod-ready","complete feature","end to end")
}

# L0 indicators (require user confirmation)
$l0Indicators = @("delete","bulk delete","destroy","drop table","rm -rf","production deploy","prod deploy","force push","git reset","schema migration","rls change","rls policy","rls modification","auth change","rollback prod","rollback production","secret rotation","aws","gcp","azure","database migration","breaking change")

# Count matches per quest_type
$scores = @{}
foreach ($qt in $patterns.Keys) {
    $score = 0
    foreach ($kw in $patterns[$qt]) {
        if ($promptLower.Contains($kw)) { $score++ }
    }
    $scores[$qt] = $score
}

# Find max
$bestType = "unknown"
$bestScore = 0
foreach ($qt in $scores.Keys) {
    if ($scores[$qt] -gt $bestScore) {
        $bestScore = $scores[$qt]
        $bestType = $qt
    }
}

if ($bestScore -eq 0) {
    $bestType = "unknown"
}

# === L0 detection ===
$isL0 = $false
foreach ($ind in $l0Indicators) {
    if ($promptLower.Contains($ind)) {
        $isL0 = $true
        break
    }
}

# === Suggested party by quest_type ===
$parties = @{
    "frontend"      = @("vivi","eiko")
    "backend"       = @("ansem","eiko")
    "fix"           = @("kuja","eiko")
    "architecture"  = @("amarant","eremez")
    "research"      = @("eremez")
    "devops"        = @("eiko")
    "boss"          = @("vivi","ansem","eiko","kuja","amarant","eremez")
    "unknown"       = @("amarant")
}
$suggestedParty = $parties[$bestType]

# === Complexity heuristic ===
$promptLen = $Prompt.Length
$complexity = "simple"
$estimatedHP = 20
$estimatedMP = 3000

if ($promptLen -lt 30) {
    $complexity = "trivial"
    $estimatedHP = 10
    $estimatedMP = 1000
} elseif ($promptLen -lt 80) {
    $complexity = "simple"
    $estimatedHP = 20
    $estimatedMP = 3000
} elseif ($promptLen -lt 200) {
    $complexity = "medium"
    $estimatedHP = 40
    $estimatedMP = 6000
} elseif ($promptLen -lt 500) {
    $complexity = "complex"
    $estimatedHP = 70
    $estimatedMP = 12000
} else {
    $complexity = "boss"
    $estimatedHP = 150
    $estimatedMP = 25000
}

if ($bestType -eq "boss") {
    $complexity = "boss"
    $estimatedHP = 150
    $estimatedMP = 25000
}

if ($isL0) {
    $complexity = "complex"
    $estimatedHP = 100
    $estimatedMP = 15000
}

# === Multi-quest chain detection ===
$chainKeywords = @(" y "," then "," luego "," despues "," also "," and then "," segundo "," finalmente "," finally "," next ")
$hasChain = $false
foreach ($kw in $chainKeywords) {
    if ($promptLower.Contains($kw)) {
        $hasChain = $true
        break
    }
}

# === Quest chain splitting ===
# Divide prompt en sub-quests cuando hay chain keywords
$subQuests = @($Prompt)
if ($hasChain) {
    $splitPattern = "(\s+(y|then|luego|despues|also|and then|segundo|finalmente|finally|next)\s+)"
    $parts = [regex]::Split($Prompt, $splitPattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    # Limpiar: solo las partes con contenido (no delimitadores puros)
    $cleanParts = @()
    foreach ($p in $parts) {
        $t = $p.Trim()
        if ($t -match "^(y|then|luego|despues|also|segundo|finalmente|finally|next)$") { continue }
        if ($t.Length -gt 3) { $cleanParts += $t }
    }
    if ($cleanParts.Count -gt 1) {
        $subQuests = @($cleanParts)
    }
}

# === Build output ===
$result = @{
    prompt = $Prompt
    quest_type = $bestType
    confidence = $bestScore
    complexity = $complexity
    suggested_party = $suggestedParty
    is_l0 = $isL0
    has_chain = $hasChain
    sub_quests = $subQuests
    sub_quest_count = $subQuests.Count
    estimated_hp = $estimatedHP
    estimated_mp = $estimatedMP
    all_scores = $scores
    timestamp = (Get-Date).ToString("o")
}

if ($Json) {
    $result | ConvertTo-Json -Depth 4
    exit 0
}

if (-not $Silent) {
    Write-Host ""
    Write-Host "  QUEST DETECTOR" -ForegroundColor Cyan
    Write-Host "  ==============" -ForegroundColor Cyan
    Write-Host "  Quest type:    $bestType (score: $bestScore)" -ForegroundColor White
    Write-Host "  Complexity:    $complexity" -ForegroundColor White
    Write-Host "  Party:         $($suggestedParty -join ', ')" -ForegroundColor Yellow
    Write-Host "  L0 quest:      $isL0" -ForegroundColor $(if ($isL0) { "Red" } else { "DarkGray" })
    Write-Host "  Has chain:     $hasChain" -ForegroundColor DarkGray
    Write-Host "  Estimated HP:  $estimatedHP" -ForegroundColor DarkGray
    Write-Host "  Estimated MP:  $estimatedMP tokens" -ForegroundColor DarkGray
    Write-Host ""
}
