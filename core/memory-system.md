# Sistema de Memoria del Harness RPG Atlas

> Cada party member tiene su propia memoria persistente via engram.
> Atlas tiene memoria aggregator que consulta todas las memorias de los miembros
> para tomar decisiones inteligentes.

---

## Donde vive la memoria

**DB SQLite**: `~/.engram/engram.db` (15 MB activo + WAL)
**Server HTTP**: `http://127.0.0.1:7437` (variable `ENGRAM_PORT`)
**Binario**: `C:\Users\LapOne Mx\go\bin\engram.exe` (Go)
**MCP en OpenCode**: configurado en `opencode.json` como
```json
"engram": { "command": ["engram", "mcp", "--tools=agent"], "type": "local" }
```
**Helper PS**: `cli/engram-helpers.ps1` (wrappers HTTP sin depender del binario WDAC-bloqueado)

## Endpoints HTTP confirmados del server

| Method | Ruta | Uso |
|---|---|---|
| GET | `/health` | Smoke check |
| POST | `/observations` | mem_save (crear observacion) |
| GET | `/observations/recent?project=<name>&limit=50` | Listar recientes (usa el plugin TUI) |
| GET | `/observations/<id>` | mem_get_observation |
| PUT | `/observations/<id>` | mem_update |
| DELETE | `/observations/<id>` | Borrado logico |
| GET | `/search?q=<query>&limit=<n>&project=<n>` | mem_search (FTS5) |
| GET | `/context?project=<n>` | mem_context (sesion actual) |
| POST | `/suggest` | mem_suggest_topic_key |
| POST | `/sessions` | mem_session_summary |

## Tools del MCP `engram --tools=agent`

Confirmados validando el binario con strings:

| Tool | Descripcion |
|---|---|
| `mem_save` | Crear observacion |
| `mem_search` | FTS5 search |
| `mem_context` | Contexto de sesion actual |
| `mem_get_observation` | Leer 1 observacion |
| `mem_update` | Editar observacion por ID |
| `mem_suggest_topic_key` | Sugerir topic_key estable |
| `mem_session_summary` | Guardar resumen de sesion |
| `mem_session_start` | Iniciar tracking de sesion (extra) |
| `mem_session_end` | Cerrar tracking de sesion (extra) |
| `mem_capture_passive` | Capture pasiva de eventos |
| `mem_compare` | Comparar observaciones |
| `mem_current_project` | Resolver proyecto actual |
| `mem_delete` | Borrado logico (alias del DELETE) |
| `mem_pin` | Fijar observacion relevante |
| `mem_unpin` | Quitar pin |
| `mem_review` | Review tool |
| `mem_judge` | Juicio (validacion automatica) |
| `mem_timeline` | Historia de un agente/proyecto |
| `mem_stats` | Estadisticas de uso |
| `mem_windows` | Ventanas temporales |
| `mem_merge_projects` | Mergear observaciones entre proyectos |
| `mem_doctor` | Diagnostico de salud del engram |
| `mem_save_prompt` | Guardar prompt template |

## Arquitectura

```
                 +--------------------------------------+
                 |   ATLAS (Player) - Memoria AGREGADOR |
                 |                                      |
                 |   - Lee todas las memorias           |
                 |   - Decide auto-loop / pause / retry  |
                 |   - Guarda session_summary            |
                 |                                      |
                 |   topic_keys (scope: project):       |
                 |     atlas/session-summary            |
                 |     atlas/decisions                   |
                 |     atlas/quest-history               |
                 |     atlas/party-results               |
                 |     atlas/user-preferences            |
                 |     atlas/circuit-breaker             |
                 +------+-----+-----+-----+-----+------+
                        |     |     |     |     |
                        v     v     v     v     v
                    +-----+ +---+ +---+ +---+ +---+
                    |VIVI | |AIK| |ANS| |KUJ| |AMA|
                    |     | |O  | |EM | |A  | |RNT|
                    +--+--+ +---+ +---+ +---+ +---+
                       |        |     |     |     |
                       v        v     v     v     v
                  scope:     scope:  scope: scope: scope:
                  agent:vivi agent: agent: agent: agent:
                             eiko    ansem  kuja   amarant
```

## Tabla de Namespaces por Agente

| Agente | scope | topic_key pattern | Type aceptado | Que guarda |
|---|---|---|---|---|
| **Atlas** | `project` | `atlas/session-summary` | session_summary | Cierre de sesion |
| **Atlas** | `project` | `atlas/decisions` | decision | L0 changes, directions |
| **Atlas** | `project` | `atlas/quest-history` | action | Quests completed/failed |
| **Atlas** | `project` | `atlas/party-results` | pattern | Que party funciono por tipo |
| **Atlas** | `project` | `atlas/user-preferences` | preference | Platform, tier, theme, budget |
| **Atlas** | `project` | `atlas/circuit-breaker` | bugfix | Agent fails + cooldowns |
| **Varys** | `project` | `varys/<quest>/turn-<N>` | action | Log por turn de cada party member |
| **Tywin** | `project` | `tywin/<quest>/verdict` | verdict | PASS/FAIL con evidencia |
| **Sam** | `project` | `sam/<quest>/analysis` | recommendation | Post-quest, decision final |
| **Auron** | `project` | `auron/threat-model` | bugfix | CVEs, OWASP encontrados |
| **Bran** | `project` | `bran/completion-history` | discovery | % completado, dead code, tendencies |
| **Quina** | `project` | `quina/token-spent` | pattern | Gasto por agente × quest |
| **Vivi** | `agent:vivi` | `vivi/design-preferences` | preference | Colors, fonts, layout styles |
| **Vivi** | `agent:vivi` | `vivi/components-built` | pattern | Componentes ya creados |
| **Vivi** | `agent:vivi` | `vivi/ui-patterns` | pattern | Patrones UI que funcionaron |
| **Vivi** | `agent:vivi` | `vivi/failed-attempts` | bugfix | Intentos fallidos (no repetir) |
| **Vivi** | `agent:vivi` | `vivi/xp` | pattern | XP, spells unlocked |
| **Vivi** | `agent:vivi` | `vivi/eiko-requests` | pattern | Veces Eiko la rescato |
| **Eiko** | `agent:eiko` | `eiko/build-failures` | bugfix | Builds rotos + root cause |
| **Eiko** | `agent:eiko` | `eiko/ci-cd-fixes` | bugfix | Pipelines arreglados |
| **Eiko** | `agent:eiko` | `eiko/deployment-issues` | bugfix | Problemas comunes |
| **Eiko** | `agent:eiko` | `eiko/vivi-care` | pattern | Stats de rescates |
| **Eiko** | `agent:eiko` | `eiko/circuit-breaker` | bugfix | Stats de circuitos cerrados |
| **Ansem** | `agent:ansem` | `ansem/schemas` | pattern | Schemas DB creados |
| **Ansem** | `agent:ansem` | `ansem/endpoint-conventions` | pattern | Naming de APIs |
| **Ansem** | `agent:ansem` | `ansem/rls-policies` | pattern | RLS que funcionaron |
| **Ansem** | `agent:ansem` | `ansem/zod-patterns` | pattern | Validaciones tipicas |
| **Kuja** | `agent:kuja` | `kuja/bugs-found` | bugfix | Bugs + fixes aplicados |
| **Kuja** | `agent:kuja` | `kuja/test-suites` | pattern | Suites ya creadas |
| **Kuja** | `agent:kuja` | `kuja/edge-cases` | discovery | Edge cases detectados |
| **Amarant** | `agent:amarant` | `amarant/arch-decisions` | decision | ADRs |
| **Amarant** | `agent:amarant` | `amarant/specs-created` | pattern | SDD specs hechos |
| **Amarant** | `agent:amarant` | `amarant/failed-plans` | bugfix | Planes que no funcionaron |
| **Eremez** | `agent:eremez` | `eremez/library-research` | discovery | Librerias investigadas + rec |
| **Eremez** | `agent:eremez` | `eremez/docs-cache` | pattern | Docs cacheadas con timestamp |
| **Eremez** | `agent:eremez` | `eremez/github-repos` | discovery | Repos relevantes |

## Principio de Operation

### 1. Antes de lanzar un quest
Atlas `mem_search` las memorias relevantes:
- `atlas/quest-history` → "last time we did frontend login, Vivi+Eiko worked"
- `eremez/library-research` si usa nueva libreria → "vimos que x library es mejor"
- `ansem/schemas` si backend → "ya existe schema de users, no recrear"
- `vivi/ui-patterns` si frontend → "el team prefiere dark mode + rojo atlas"

### 2. Durante el combate (turn-based)
Cada member puede `mem_save` a su namespace:
- Vivi: "Encontre que Tailwind container queries funcionan perfecto aqui. Lo guardo."
- Eiko: "El build se rompio por conflict de dependencies. La proxima lowercase primero."
- Ansem: "RLS policies en users: funciono filtrar por user_id."

### 3. Turn 4-5 (Varys + Tywin)
- Varys `mem_save` con `scope: project, topic_key: varys/<quest>/turn-4` (log de acciones)
- Tywin `mem_save` con `scope: project, topic_key: tywin/<quest>/verdict` (veredict)

### 4. Turn 7 (Sam)
Sam hace:
1. `mem_search("tywin verdict <quest>")` para ver el dictamen
2. `mem_search("varys <quest>")` para ver el log de turnos
3. `mem_save` con `scope: project, topic_key: sam/<quest>/analysis`

### 5. Turn 8 (Atlas decision)
Atlas:
1. `mem_search("atlas/quest-history")` → ver historial
2. Si 3 quests seguidas pasaron → sube party level (+1 streak)
3. Si algun member fallo → busca su `agent:<member>/circuit-breaker` namespace
4. Decide si continuar auto-loop o pausar:
   - Auto-continuar si: quest trivial/simple, party en HP>50%, no L0
   - Pausar si: boss fight done, L0 detected, circuit breaker triggereado, budget exceeded
   - Pausar si: finity signal del user ("eso es todo por hoy", "pause", "/quit")

### 6. Cierre de sesion (SESSION CLOSE PROTOCOL - MANDATORIO)
Atlas debe llamar a `mem_session_summary` con esta estructura:

```
## Goal
[Que estabamos trabajando esta sesion]

## Instructions
[Preferencias o constraints del user descubiertos]

## Discoveries
- [Findings tecnicos, gotchas, aprendizajes no obvios]

## Accomplished
- [Items completados con detalle clave]

## Next Steps
- [Que queda pendiente para la proxima sesion]

## Relevant Files
- path/to/file - [que hace o que cambio]
```

### 7. Cuando se reanuda despues de pausa
Atlas llama `mem_context()` al arrancar y luego `mem_search("atlas/session-summary")`.
Con esto le dice al user:
"Bienvenida de vuelta! La ultima vez estabamos en el quest X, fallaron Y intentos.
Recomiendo seguir con Z porque nuestra memory dice que el patron funciono en el quest W."

**ESTO ES CRITICAL** - sin esto, Atlas no parece inteligente.

## Deteccion de Smart Snippets

Atlas debe detectar "smart snippets" de las memorias del equipo:

- Vivi guardo "User prefiere dark mode + rojo atlas en UI". Proxima quest, Vivi
  no necesita que le pidan dark mode - ya lo sabe.
- Eiko guardo "Prisma migrations se rompen si no corremos prisma generate primero".
  Proxima vez que Eiko vea Prisma migrations en el quest, lo sabe.

Esto hace que Atlas parezca pensante, no reactivo.

## Memoria como "AI Trust Score"

Atlas puede rankear party members basado en su memoria:
- Vivi: 95% success rate en UI quests, 0 fails en ultimos 10 → confia fondo
- Ansem: 80% success rate, 1 fall reciente → confia medio
- Kuja: 60% success rate, 2 fails en 60min → pausado por circuit breaker
- Amarant: 100% en arch quests, propone superpowers siempre → confia plena
- Eremez: 90% en research, sofisticado en patterns → confia alto
- Eiko: 100% en todos sus rescates → confia maxima

Esto se usa para auto-asignar trust al member en cada quest.

## Fallback si engram no disponible

Si el server no responde (`Test-EngramAlive` retorna false), usar archivos planos en
`$project/.arnes/memory/`:

```
.arnes/memory/
  atlas-decisions.jsonl
  atlas-quest-history.jsonl
  vivi-xp.jsonl
  vivi-ui-patterns.jsonl
  eiko-care-stats.jsonl
  eiko-build-failures.jsonl
  ansem-schemas.jsonl
  kuja-bugs.jsonl
  amarant-decisions.jsonl
  eremez-research.jsonl
  varys-turn-log.jsonl
  tywin-verdicts.jsonl
  sam-analyses.jsonl
  auron-threat-model.jsonl
  bran-completion-history.jsonl
  quina-token-spent.jsonl
  cost-tracking.jsonl
```

Formato JSONL (1 observacion por linea). Update cada vez que termina un quest,
load al iniciar sesion. Cuando engram vuelva, sync estos archivos al server.

## Uso desde Atlas

El CLI `atlas.ps1` debe hacer esto al arrancar:

```powershell
# Cargar helpers de engram
. "$arnesRoot\cli\engram-helpers.ps1"

# Verificar que engram este vivo
if (-not (Test-EngramAlive)) {
    Write-Host "[WARN] Engram server no responde en $script:ENGRAM_BASE" -ForegroundColor Yellow
    Write-Host "       Memoria desactivada. Activalo con 'engram serve'." -ForegroundColor Yellow
} else {
    $ctx = Get-MemoryContext
    if ($ctx) {
        Write-Host "[engram] Contexto cargado: $($ctx.Count) observaciones recientes" -ForegroundColor Green
    }
}
```

Cada party member, en su `agent.md`, debe tener como ultima instruccion:

> Despues de completar tu accion en este turn, llamas a `mem_save` con:
> - `scope: agent:<tu_nombre>` (tu namespace privado)
> - `topic_key: <nombre>/<patron>` (ej: `vivi/ui-patterns`)
> - `type: pattern | bugfix | discovery | preference` segun corresponda
> - `content: descripcio breve + leccion aprendida`

## Lo que falta para activar esto de verdad

1. **Verificar que engram server arranque** - Probar `engram serve` desde cmd
   (desde powershell App Control bloquea el binario)
2. **Confirmar `engram mcp --tools=agent` funcionavia OpenCode MCP** - cuando
   OpenCode arranca, el invoca el MCP; si OpenCode puede, el server queda arriba
3. **Inyectar el flujo de memoria en cada agent.md** - cada agente del harness
   debe incluir en su system prompt el flujo "despues de actuar, escribe a memoria"
4. **Crear tests de humo** - un mini script que pruebe Save-Memory → Search-Memory
   → Get-Memory → Remove-Memory para verificar el ciclo completo

---

# ARQUITECTURA HYBRID DE MEMORIA COMPARTIDA (NUEVO 2026-08-04)

> **Esta seccion documenta el upgrade mayor del sistema de memoria del harness.
> Resuelve 6 fallas criticas detectadas por auditoria Oracle el 2026-08-04.

## Fallas resueltas

| ID | Falla | Severidad | Fix aplicado |
|---|---|---|---|
| **A** | Silo Problem: agentes no pueden leer memoria de otros | CRITICAL | `shared-blackboard.json` — cross-agent knowledge |
| **B** | Atlas Blind Spot: Party Select (TURN 1) antes que Sam aconseje (TURN 7) | CRITICAL | `sam-digest.json` leido en TURN 0.5 |
| **C** | Sam's Amnesia: no existian archivos persistentes de Sam | HIGH | Creados `sam-*.jsonl` (4 archivos) |
| **D** | Varys No-Op: Varys coleccionaba evidencia pero no escribia a memoria | HIGH | Varys ahora hace write-back a per-agent + blackboard |
| **E** | No Blackboard: no existia archivo compartido de conocimiento | CRITICAL | Creado `.arnes/shared-blackboard.json` |
| **F** | Inter-Quest Forgetting: nada fluye entre quest N y N+1 | CRITICAL | `sam-digest.json` es el puente formal |

## Patron arquitectonico: Pattern C (Hybrid)

No es pure blackboard (contention risk) ni pure messenger (Varys ya era eso pero fallaba). Es **Hybrid**:

- **Per-agent memory stays** — cada agente sigue escribiendo a su JSONL private
- **Shared blackboard added** — Varys y Tywin escriben cross-agent learnings aqui
- **Sam digest added** — Sam genera digest post-quest, Atlas lee pre-quest
- **Varys writes back** — Varys append a per-agent memory con aprendizajes reales
- **Sam persists** — Sam tiene 4 archivos JSONL propios + el digest

## Archivos del sistema hibrido

### Schemas (formales, en `core/protocols/`)
- `core/protocols/shared-blackboard.schema.json` — schema del blackboard
- `core/protocols/sam-digest.schema.json` — schema del digest

### Datos (en `.arnes/`)
- `.arnes/shared-blackboard.json` — cross-agent shared knowledge (Varys/Tywin/Sam escriben, Atlas lee)
- `.arnes/sam-digest.json` — cross-quest memory bridge (Sam escribe, Atlas lee pre-quest)

### Memoria de Sam (en `.arnes/memory/`)
- `sam-archive.jsonl` — historial completo de quests
- `sam-recommendations.jsonl` — todos los consejos emitidos
- `sam-trust-scores.jsonl` — trust scores snapshot evolutivo
- `sam-counsel-major.jsonl` — consejos mayores archivados

### Memoria de Varys (en `.arnes/memory/`)
- `varys-turn-log.jsonl` — log persistente por quest observado

## Flujo de datos — Diagrama

```
QUEST N EJECUCION (TURN 4):
  ┌──────────┐    ┌──────────┐    ┌──────────┐
  │  VIVI    │    │  ANSEM   │    │  KUJA    │
  │ writes   │    │ writes   │    │ writes   │
  │ vivi.jsonl│   │ ansem.jsonl│  │ kuja.jsonl│
  └────┬─────┘    └────┬─────┘    └────┬─────┘
       │               │               │
       └───────────────┼───────────────┘
                       │
                  ┌────▼────┐
                  │  VARYS  │ ← observa, genera evidence_pack
                  │ writes  │ ← ESCRIBE a shared-blackboard.json
                  │ varys-  │ ← ESCRIBE write-back a per-agent memory
                  │ log.jsonl│
                  └────┬────┘
                       │
                  ┌────▼────┐
                  │  TYWIN  │ ← lee evidence_pack, emite verdict
                  │ tambien │ ← ESCRIBE a shared-blackboard.json
                  └────┬────┘
                       │
                  ┌────▼────┐
                  │   SAM   │ ← lee shared-blackboard.json
                  │ genera  │ ← lee per-agent memory files
                  │ digest  │ ← GENERA sam-digest.json
                  │ persiste│ ← append a sam-*.jsonl
                  │ actualiza│ ←actualiza shared-blackboard.json
                  └────┬────┘
                       │
                  ┌────▼────┐
                  │  ATLAS  │ ← lee sam-digest.json (TURN 8)
                  │ decide  │ ← escribe decision
                  └─────────┘

QUEST N+1 INICIA (TURN 0.5):
                  ┌─────────┐
                  │  ATLAS  │ ← lee sam-digest.json (TURN 0.5)
                  │ lee     │ ← lee shared-blackboard.json
                  │ shared- │ ← AHORA tiene contexto historico
                  │ board   │   para TURN 1 (Party Select)
                  └─────────┘
```

## Responsabilidades por rol (actualizado)

| Rol | Escribe a | Lee de | Cuando |
|---|---|---|---|
| **Vivi** | `vivi-memory.jsonl` | `shared-blackboard.json` (patrones de otros) | Post-quest aprende |
| **Ansem** | `ansem-memory.jsonl` | `shared-blackboard.json` | Post-quest aprende |
| **Varys** | `shared-blackboard.json`, `<agent>-memory.jsonl` (write-back), `varys-turn-log.jsonl` | Party output | TURN 5 |
| **Tywin** | `shared-blackboard.json` (verdict) | `evidence_pack` de Varys | TURN 6 |
| **Sam** | `sam-digest.json`, `sam-*.jsonl`, `shared-blackboard.json` (trust scores) | `shared-blackboard.json`, `sam-*.jsonl`, `*.jsonl` historico | TURN 7 |
| **Atlas** | `loop-state.json` (decision) | `sam-digest.json`, `shared-blackboard.json` | TURN 0.5 (pre-quest) + TURN 8 (decision) |

## Anti-patrones (lo que NO debe pasar)

- **NO** un agente lee el JSONL privado de otro agente — usan el blackboard para eso
- **NO** Varys reporta solo a Tywin sin escribir a blackboard — el write-back es obligatorio
- **NO** Sam genera consejo sin persistir digest — el digest es el puente inter-quest
- **NO** Atlas decide party sin leer `sam-digest.json` en TURN 0.5
- **NO** se sobreescribe el blackboard sin actualizar `updated_at` y `updated_by`
- **NO** se duplican patrones en el blackboard — se updatea `last_used` si ya existe similar

## Constraints de Escritura (Sequential Write Guarantee)

### 1. Varys (TURN 5) y Sam (TURN 7) escriben a `shared-blackboard.json` secuencialmente, nunca en paralelo

La arquitectura turn-based garantiza esto por diseno: TURN 5 (Varys) → TURN 6 (Tywin) → TURN 7 (Sam) → TURN 8 (Atlas). El harness nunca paraleliza estos turnos porque Sam debe leer el verdict de Tywin (TURN 6) antes de escribir su digest (TURN 7). Si el harness intentara paralelizar TURN 5 y TURN 7, `shared-blackboard.json` se corromperia por escritura concurrente. Esta constraint es por diseno, no un bug.

### 2. Sam escribe `sam-digest.json` atomicamente (full overwrite), no incrementalmente

El digest es un snapshot del estado post-quest, no un log. Sam:
1. Lee `shared-blackboard.json` (contiene evidence_pack de Varys + verdict de Tywin)
2. Lee archivos `sam-*.jsonl` historicos para detectar tendencias
3. Genera el digest completo
4. Sobrescribe `sam-digest.json` por completo (no appendea)

Esto garantiza que Atlas siempre lee un digest coherente y completo en TURN 0.5, no fragmentos parciales.

### 3. Varys appendea a archivos JSONL por agente (no sobrescribe)

Cada write-back de Varys agrega una nueva linea al JSONL del agente correspondiente (ej: `vivi.jsonl`, `ansem.jsonl`). Varys nunca sobrescribe el JSONL de un agente — appendea. Ningun agente debe sobrescribir el JSONL de otro agente. Cada JSONL es propiedad exclusiva de su agente (o de Varys cuando hace write-back).

### 4. El blackboard es la unica fuente de verdad cross-agent

`shared-blackboard.json` es el single source of truth para conocimiento compartido entre agentes.

Si engram esta vivo → sync bidireccional: blackboard se escribe a engram, engram se lee al blackboard.
Si engram esta muerto → blackboard es el fallback unico sin sync.

Los JSONL por agente son memorias privadas. El blackboard es la unica via de comunicacion entre agentes que no comparten namespace.
