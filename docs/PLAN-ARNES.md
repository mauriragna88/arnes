# PLAN ARNES — Roadmap Maestro del Harness

> **Documento de continuidad entre sesiones.**
> Creado: 2026-08-05 · Última actualización: 2026-08-05
> **Estado actual: FASE 1 PENDIENTE — este documento es el punto de retoma para cualquier sesión futura.**

---

## 🎯 MISIÓN DEL ARNES

Construir el **ARNES v2** — un ecosistema de desarrollo 100% propio e independiente:
- **CERO dependencia** de gentle-ai, engram, openspec, o cualquier arnes externo
- Memoria cerebral propia (SQLite + FTS5), Knowledge Graph, SDD, FDD, ADR propios
- El harness hace el trabajo pesado → el modelo de IA es intercambiable (DeepSeek/Qwen/GPT)
- Anti-alucinación por diseño: memoria + verificación, no confianza ciega en el LLM

**Principio rector**: "Como mejor tengamos nuestro arnes, el modelo de IA es indistinto porque tiende a alucinar más." → El sistema verifica, el modelo ejecuta.

---

## 📦 DEPENDENCIAS PERMITIDAS (verificadas 2026-08-05 en la máquina)

| Recurso | Versión | Uso |
|---|---|---|
| SQLite + FTS5 | 3.50.4 (probado en vivo) | arnes.db — memoria cerebral |
| Python | 3.14.4 | Motor de memoria (sqlite3 nativo) |
| Node | v24.12.0 | OpenCode + scripts |
| PowerShell | 5.1 | Atlas Shell + CLI |
| Git | 2.52.0 | Repo + versionado |
| winsqlite3.dll | Nativo Windows | Backup SQLite |

**PROHIBIDO depender de**: gentle-ai · engram · Neo4j · bases externas · SDKs ajenos. Todo corre con Python + SQLite + PowerShell.

---

## 🧠 ARQUITECTURA CEREBRAL (ARNES BRAIN)

### Analogía: SQLite = hipocampo, Knowledge Graph = neocortex

```
ARNES BRAIN (arnes.db - SQLite + FTS5)
│
├── agents          → quién eres (id, clase, modelo, trust_score)
├── observations    → recuerdos (agente, topic_key, tipo, contenido, timestamp)
├── quests          → misiones (qué se hizo, party, resultado, tokens)
├── sessions        → sesiones (inicio, fin, resumen)
├── edges           → RELACIONES (node_a, node_b, relation, agent, ts) [FASE 2]
└── FTS5 index      → índice de recuerdos (búsqueda instantánea)
```

### Conceptos cerebrales implementados

| Concepto | Implementación | Beneficio |
|---|---|---|
| Memoria episódica | observations con quest_id | "¿qué hicimos la última vez?" |
| Memoria semántica | patterns/learnings | Hechos inyectados, no suposiciones |
| Memoria procedural | skills + XP | El agente sabe qué le funcionó |
| Recall selectivo | FTS5 query de lo relevante | No satura la ventana del LLM |
| Consolidación (sueño) | digest periódico por agente | Recuerdos compactos y duraderos |
| Plasticidad sináptica | trust_score sube/baja | Lo que falla se debilita |
| Anti-alucinación (RAG) | El agente busca HECHOS antes de actuar | No inventa, verifica |

### Patrón Atlas-consulta-agente

```
ATLAS necesita saber → task() al agente → agente busca en SU memoria (arnes.db)
→ agente responde → Atlas usa la respuesta. (Ahorra tokens, cada uno vive su rol.)
```

### Formato híbrido memoria

- `arnes.db` = memoria activa (SQLite, rápida, consultable)
- `.arnes/memory/export/*.jsonl` = snapshot para git/backup (auto-export al cerrar sesión)
- Auto-recuperación: si no hay db → crear desde JSONL; si no hay JSONL → exportar desde db

---

## 🏗️ METODOLOGÍAS (ARNES METHOD)

| Metodología | Para qué | Estado |
|---|---|---|
| **SDD** (Spec-Driven) | Features grandes: spec → design → tasks → apply → verify | FASE 3 |
| **FDD** (Feature-Driven) | Listas de features: feature list → plan → implement → review | FASE 4 |
| **TDD** (Test-Driven) | Test primero, red→green→refactor | ✅ Ya existe (vitest) |
| **Proportional Verification** (regla de Kuja, 2026-08-05) | El esfuerzo del test ES proporcional a la complejidad. Trivial = 1-2 tests o ninguno (regla 4+4=8). NO sobre-verificar con "verificación teatral" | ✅ Aplicada en rogue.agent.md |
| **ADR** (Architecture Decision Records) | Toda decisión de arquitectura queda registrada | FASE 5 |
| **DDD** (Domain-Driven) | Glosario de dominio si el proyecto lo pide | Opcional |
| **Knowledge Graph** | Relaciones entre todo (quién tocó qué) | FASE 2 |
| **Skills PROPIAS v2** | Skills de los 13 agentes 100% propias, sin gentle-ai (las de internet solo como referencia) | FASE 3.5 |

---

## 🔒 REGLA INALTERABLE (DECISIÓN DEL USUARIO 2026-08-05)

**El arnes NO depende de gentle-ai EN NADA: ni skills, ni SDD, ni memoria, ni nada.**
- Las skills de internet (superpowers, ui-ux-pro-max, taste-skill) **SÍ SE MANTIENEN CARGADAS** como
  **complemento de poder** para que los agentes sean top — pero NUNCA son una dependencia obligatoria.
- Los agentes cargan skills **100% propias del arnes** (v2) como identidad y proceso.
- Las skills web son el ARSENAL extra: cuando una skill propia lo necesite, puede apoyarse en las web
  para ejecutar mejor (ej: vivi-fireball usa react + tailwind instalados, pero el PROCEDIMIENTO es nuestro).
- Cero referencias "Gentle-AI Origin" en el skill-registry.
- FASE 3.5 es dedicada a crear estas skills propias + mapear las web como complemento.

---

## 📋 FASES DE IMPLEMENTACIÓN

### FASE 1 — ARNES BRAIN (memoria propia) ✅ COMPLETADA 2026-08-05
- [x] Crear `arnes.db` (SQLite + FTS5): schema agents, observations, quests, sessions, edges
- [x] `arnes-memory.ps1` CLI: save, search, context, export-jsonl, import-jsonl
- [x] Skill `arnes-memory` (el cerebro)
- [x] Skill `arnes-agent-memory` (instrucción para que cada agente guarde/consulte SU memoria)
- [x] Skill `arnes-context-digest` (consolidación / "sueño")
- [x] Integrar en los agent.md: "después de actuar, guarda a memoria" (7 party members)
- [x] Test de humo: save → search → context → export → quest → edge ✅
- [x] Sync skills a OpenCode: ~/.config/opencode/skills/atlas/arnes-*

**Detalles técnicos**:
- `cli/arnes_brain.py` — motor Python (SQLite nativo, FTS5, triggers auto-sync)
- `cli/arnes-memory.ps1` — CLI PowerShell (usa archivo temporal para evitar encoding cp1252)
- `arnes.db` ubicado en `.arnes/arnes.db` (53KB inicial)
- 15 agentes registrados (atlas + party + auditores + tidus + ragnarok)
- 4 observaciones de prueba, 1 quest (Q-001), 1 edge (Login.tsx → zod)
- **Gotcha**: en PowerShell 5.1, pasar JSON por pipe corrompe acentos → usar archivo temporal + `Get-Content -Raw`

### FASE 2 — ARNES GRAPH (relaciones) ✅ COMPLETADA 2026-08-05
- [x] Tabla `edges` sobre arnes.db (ya existia del schema FASE 1)
- [x] `arnes-graph.ps1` CLI: add, query, neighbors, path, stats
- [x] Motor extendido: add_edge, query_edges, neighbors (BFS), path (BFS), graph_stats
- [x] Skill `arnes-graph`
- [x] Mapa de código: componentes ↔ librerías ↔ agentes (Login.tsx → zod, Sidebar → tailwind, users → rls-policy)
- [x] Test de humo: query, neighbors depth=2, path-finding Login→tailwind ✅

**Detalles técnicos**:
- `cli/arnes-graph.ps1` — CLI PowerShell del grafo
- Motor: `arnes_brain.py` con BFS para neighbors y path-finding
- Estado actual: 6 nodos, 5 edges (uses: 3, imports: 1, protected_by: 1)
- Anti-alucinación por relaciones: "si el grafo dice que existe, existe"

### FASE 3 — ARNES SDD (sin gentle-ai) ✅ COMPLETADA 2026-08-05
- [x] Skills propias file-based: `arnes-sdd-propose/spec/design/tasks/apply/verify/archive`
- [x] Carpeta `.arnes/sdd/` con templates (proposal, spec, design, tasks)
- [x] Change de ejemplo: `.arnes/sdd/C-20260805-01/` (Login Form con Zod)
- [x] 7 skills sincronizadas a OpenCode
- [x] Ciclo SDD probado: proposal aprobado → quest Q-002 registrado

**Detalles técnicos**:
- Templates en `.arnes/sdd/templates/` (proposal.md, spec.md, design.md, tasks.md)
- Cada change vive en `.arnes/sdd/C-YYYYMMDD-NN/`
- Skills: arnes-sdd-propose → spec → design → tasks → apply → verify → archive
- Flujo conectado a memoria: cada fase guarda en arnes.db (specs-created, quest-history)
- La fase verify la ejecuta Tywin (PASS/FAIL con evidencia)

### FASE 3.5 — ARNES SKILLS PROPIAS (DECISIÓN 2026-08-05: cero gentle-ai) ✅ COMPLETADA
> **El usuario decidió: skills 100% propias, sin depender de gentle-ai EN NADA (ni skills, ni nada).**
> Las skills de internet instaladas (superpowers, ui-ux-pro-max, taste-skill, etc.) **SE MANTIENEN**
> como **complemento de poder / arsenal** para que los agentes sean top — nunca como dependencia obligatoria.
> El PROCEDIMIENTO es nuestro; las skills web potencian la ejecución.

- [x] Crear skills propias renovadas en `core/skills/v2/` (16 skills) — sin "Gentle-AI Origin"
- [x] Actualizar `.atl/skill-registry.md` — mapeo RPG → skills PROPIAS v2 (sin gentle-ai)
- [x] Cada skill propia define: trigger, inputs, pasos, output esperado, conexión a memoria (arnes.db)
- [x] Skills del arnes (15 agentes): vivi-fireball, ansem-smite, kuja-backstab, eiko-mend, amarant-foresight, eremez-mark, auron-bulwark, bran-vision, quina-ledger, varys-whisper, tywin-judgment, sam-counsel, atlas-orchestrate, tidus-tide-check, ragnarok-scout
- [x] La capa RPG (niveles/XP/damage) se mantiene pero apunta a las skills propias v2
- [x] Mapear skills web como COMPLEMENTO (no dependencia): cada skill propia lista qué skills web potencian su ejecución
- [x] Template `arnes-skill-v2` para crear futuras skills

**Detalles técnicos**:
- Ubicación: `core/skills/v2/<agente>-<skill>/SKILL.md`
- Sincronizadas a OpenCode: `~/.config/opencode/skills/atlas/v2/` (16 skills)
- Skill-registry renovado con compact rules v2 (archivo → skill propia)

### FASE 4 — ARNES FDD ✅ COMPLETADA 2026-08-05
- [x] Skills `arnes-fdd-plan/implement/review/archive`
- [x] Carpeta `.arnes/fdd/` con templates (feature-list, feature-plan)
- [x] Feature set de ejemplo: `.arnes/fdd/FL-20260805-01/` (Sistema de Login, 4 features)
- [x] Features conectadas a memoria (cada feature registra quest en arnes.db)
- [x] 4 skills sincronizadas a OpenCode

**Detalles técnicos**:
- FDD = features independientemente entregables (valor visible al terminar cada una)
- Diferencia con SDD: SDD = spec profunda para un change; FDD = lista de features incrementales
- Templates: feature-list.md (el mapa) + feature-plan.md (plan por feature)
- Feature set de ejemplo: F1 Login done, F2 Password Reset done, F3/F4 pending

### FASE 5 — ARNES ADR ✅ COMPLETADA 2026-08-05
- [x] Skill `arnes-adr`
- [x] Carpeta `.arnes/adr/` con template.md
- [x] 3 ADRs registrados: ADR-001 (SQLite+FTS5), ADR-002 (proceso propio), ADR-003 (skills propias)
- [x] Amarant registra decisiones (contexto, decisión, alternativas, consecuencias)

**Detalles técnicos**:
- Formato: contexto → decisión → alternativas → consecuencias → razón
- Ubicación: `.arnes/adr/ADR-NNN-slug.md`
- Conexión a memoria: `amarant/arch-decisions` en arnes.db

### FASE 6 — ATLAS SHELL + GIT
- [ ] `atlas` → banner ARNES mamalón (ya existe en atlas-init.ps1) → menú
- [ ] Wizard de configuración con flechas (estilo /models de OpenCode)
- [ ] Detección de proveedores (Go/OpenAI/NVIDIA) + selector de modelos por agente
- [ ] Reconfiguración parcial (cambiar solo un agente si pierdes un proveedor)
- [ ] Chat directo (opción 1 del menú → opencode --agent atlas-player)
- [ ] Git re-init (el .git está vacío/roto), .gitignore, commit inicial

### FASE 7 — TIDUS (Infrastructure & Growth Warden) ✅ COMPLETADA 2026-08-05
> **Departamento de Sistemas del harness.** Vigila que el entorno y cada agente tengan recursos suficientes.

- [x] `core/classes/tidus.agent.md` creado ✅ (health-check, cuotas, growth)
- [x] Integrar en `cli/atlas.ps1` SyncAgents (mapeo tidus → core/classes/tidus.agent.md)
- [x] Skill `tidus-tide-check` (health-check de recursos: disco, RAM, CPU) — en core/skills/v2/
- [x] Skill `tidus-cuota-check` (revisar cuotas Go/OpenAI/NVIDIA) — parte de tidus-tide-check
- [x] Integrar health-check al inicio de sesión (test realizado: semáforo GREEN)
- [x] Conectar a arnes.db: `tidus://health-history` ✅ (health-check guardado)
- [x] Registrado en config.json (modelo deepseek-v4-flash)

**Test realizado**: disco 156GB libres, RAM 20GB, CPU 30%, OpenCode conectado → GREEN

### FASE 8 — RAGNAROK (Procurement & Research Warden) ✅ COMPLETADA 2026-08-05
> **Departamento de Compras del harness.** Investiga la web (repos, Reddit, X), busca skills/metodologías
> nuevas, compara contra lo que tenemos y propone la "compra". El arnes nunca se estanca.

- [x] `core/classes/ragnarok.agent.md` creado ✅ (scout, tendencias, comparativas, adopción)
- [x] Integrar en `cli/atlas.ps1` SyncAgents (mapeo ragnarok → core/classes/ragnarok.agent.md)
- [x] Skill `ragnarok-scout` (scan web: repos git, Reddit, X, awesome-lists) — en core/skills/v2/
- [x] Skill `ragnarok-compare` (War Cry: lo nuevo vs lo actual, ROI) — en core/skills/v2/
- [x] Scan de novedades al inicio de sesión (ciclo Scout → War Cry probado)
- [x] Conectar a arnes.db: `ragnarok://adopciones`, `ragnarok://rechazos` ✅ (scout-results guardado)
- [x] Documentación: lo adoptado se agrega a docs/ del repo
- [x] Registrado en config.json (modelo gpt-5.6-luna)

**Test realizado**: ciclo Scout → War Cry → Recomendación (mantener dual capa ADR-003)

### FASE 9 — AURON L0 GATE (Permiso de Trabajo en Altura) ✅ COMPLETADA 2026-08-05
> **Auron = supervisor de seguridad industrial.** Antes de todo quest L0 verifica que el agente
> tenga "equipo": skill requerida, docs revisadas, plan de rollback, entorno correcto, impacto, backup.

- [x] `core/auditors/auron.agent.md` actualizado ✅ (checklist L0 Gate de 6 checks)
- [x] Conectar a arnes.db: `auron://l0-permits/<quest_id>` ✅ (test guardado)
- [x] Test: quest L0 sin plan de rollback → Auron bloquea (FAIL) ✅ PASÓ
- [x] Test: quest L0 completo → Auron permite (PASS) ✅ PASÓ
- [x] Test: quest L0 sin skill requerida → Auron bloquea (FAIL) ✅ PASÓ

**Test realizado**: 3/3 tests correctos — L0 Gate operativo

---

## 🛠️ SKILLS A CREAR (total)

| Skill | Fase |
|---|---|
| `arnes-memory` | 1 |
| `arnes-agent-memory` | 1 |
| `arnes-context-digest` | 1 |
| `arnes-graph` | 2 |
| `arnes-sdd-propose` | 3 |
| `arnes-sdd-spec` | 3 |
| `arnes-sdd-design` | 3 |
| `arnes-sdd-tasks` | 3 |
| `arnes-sdd-apply` | 3 |
| `arnes-sdd-verify` | 3 |
| `arnes-sdd-archive` | 3 |
| `arnes-fdd-plan` | 4 |
| `arnes-fdd-implement` | 4 |
| `arnes-fdd-review` | 4 |
| `arnes-fdd-archive` | 4 |
| `arnes-adr` | 5 |
| `arnes-skill-v2` (template de skill propia) | 3.5 |
| `tidus-tide-check` (health-check recursos) | 7 |
| `tidus-cuota-check` (cuotas proveedores) | 7 |
| `ragnarok-scout` (scan web novedades) | 8 |
| `ragnarok-compare` (comparativa War Cry) | 8 |
| Skills v2 de los 13 agentes (vivi-fireball, ansem-smite, kuja-backstab, eiko-mend, amarant-foresight, eremez-mark, auron-bulwark, bran-vision, quina-ledger, varys-whisper, tywin-judgment, sam-counsel, atlas-orchestrate) | 3.5 |

---

## 🎯 CONFIGURACIÓN DE MODELOS (2026-08-05 — ya aplicada)

### Proveedores conectados (verificados con `opencode auth list`)
- ✅ **OpenCode Go** (api) — suscripción $10/mes
- ✅ **OpenAI** (oauth) — cuenta GPT con plan (13 modelos GPT-5.x disponibles)
- ✅ **NVIDIA NIM API** (api) — GRATIS (1000-5000 credits, 40 req/min)
- ✅ MiniMax, Z.AI, bai, tokenrouter, Alibaba...

### Asignación actual en `.arnes/config.json`

| Agente | Modelo | Proveedor | Costo |
|---|---|---|---|
| Atlas | `qwen3.8-max` | Go | plan |
| Vivi | `gpt-5.6-luna` | OpenAI | plan GPT |
| Ansem | `deepseek-v4-flash` | NVIDIA | GRATIS |
| Kuja | `deepseek-v4-flash` | NVIDIA | GRATIS |
| Eiko | `deepseek-v4-flash` | Go | plan |
| Amarant | `gpt-5.6-luna` | OpenAI | plan GPT |
| Eremez | `deepseek-v4-flash` | NVIDIA | GRATIS |
| Auron | `deepseek-v4-pro` | NVIDIA | GRATIS |
| Bran | `gpt-5.6-luna` | OpenAI | plan GPT |
| Quina | `deepseek-v4-flash` | Go | plan |
| Varys | `gpt-5.6-luna` | OpenAI | plan GPT |
| Tywin | `deepseek-v4-flash` | NVIDIA | GRATIS |
| Sam | `gpt-5.6-luna` | OpenAI | plan GPT |

**Nota**: el usuario quiere PODER cambiar esto con un wizard interactivo de flechas (FASE 6). El proveedor NVIDIA permite DeepSeek V4 Pro GRATIS.

---

## 🔴 PENDIENTES IMPORTANTES / GOTCHAS

1. **Git roto**: `.git/` existe pero vacío (0 archivos, sin HEAD). `git init` de nuevo en FASE 6.
2. **BOM UTF-8 obligatorio** en `atlas-init.ps1` — si un editor guarda sin BOM, el banner se corrompe (PS 5.1 lee sin BOM como ANSI).
3. **atlas-player en opencode.json** apunta a `nvidia/deepseek-ai/deepseek-v4-pro` — debe actualizarse a qwen3.8-max en FASE 6 (o antes).
4. **skills sdd-* de gentle-ai instaladas** en `~/.config/opencode/skills/` — reemplazar por las nuestras en FASE 3.
5. **skill-registry.md referencias "Gentle-AI Origin"** — actualizar a skills propias v2 en FASE 3.5.
5. **Engram** MCP configurado en opencode.json — decidir si se remueve o se deja como opcional (el arnes ya no depende de él).
6. **Basura en repo**: `imagen10.jpg` y `Sin título.jpg` — limpiar en FASE 6.
7. **PowerShell 5.1** — el `$_` en comandos bash se come por interpolación; usar scripts temporales o escaping.
8. **Consola cp1252** — no imprimir emojis Unicode desde python directo en consola; usar archivos temporales o ASCII.

---

## 📁 ARCHIVOS CLAVE DEL REPO

| Ruta | Función |
|---|---|
| `cli/atlas-init.ps1` | Inicializador con banner ARNES mamalón (tiene BOM UTF-8) |
| `cli/atlas.ps1` | Launcher principal (onboarding, sync, lanza OpenCode/Codex/Claude) |
| `cli/atlas-ff.ps1` | Command center (models, routes, doctor, configure) |
| `cli/atlas-model-config.ps1` | Configurador de cadena de modelos |
| `cli/model-catalog.ps1` | Catálogo vivo de modelos (opencode models) |
| `cli/agent-model-resolver.ps1` | Resuelve modelo por agente contra catálogo |
| `core/memory-system.md` | Diseño de memoria (engram + fallback JSONL — a migrar a arnes.db) |
| `core/protocols/` | Schemas de blackboard, sam-digest, handoff |
| `.arnes/config.json` | Config principal (modelos por agente) |
| `.arnes/model-recommendations.json` | Party recomendada por plan |
| `.arnes/model-routing-policy.json` | Preferencias y fallbacks por agente |
| `.arnes/shared-blackboard.json` | Conocimiento cross-agent |
| `.arnes/sam-digest.json` | Puente de memoria inter-quest |
| `.openspec/` | SDD actual (file-based, reusable como base de arnes-sdd) |
| `core/classes/tidus.agent.md` | **NUEVO** Tidus — Infrastructure & Growth Warden (FASE 7) |
| `core/classes/ragnarok.agent.md` | **NUEVO** Ragnarok — Procurement & Research Warden (FASE 8) |
| `core/auditors/auron.agent.md` | **AMPLIADO** Auron — checklist L0 Gate (permiso trabajo en altura, FASE 9) |

---

## 🏢 LA EMPRESA ARNES (organización completa 2026-08-05)

```
ARNES = EMPRESA
├── Dirección General      → ATLAS (orquestador)
├── Sistemas/Infra         → TIDUS (nuevo) + Eiko (builds)
├── Programación           → Vivi (frontend) + Ansem (backend)
├── Compras               → RAGNAROK (nuevo) — web, repos, proveedores, skills nuevas
├── Controlling/Finanzas   → Quina (tokens)
├── Mejora Continua        → BARD — código, deuda técnica, DX
├── Seguridad              → AURON — permiso de trabajo en altura (L0 gate)
├── QA                     → Kuja — TDD + verificación proporcional
├── Arquitectura           → Amarant — SDD/ADR
├── Investigación          → Eremez — docs, librerías
├── Auditoría              → Varys + Tywin + Sam
└── Marketing/Ventas       → ⚠️ futuro (README/docs = "ventas")
```

**Flujo entre departamentos**:
- Tidus detecta skill faltante → Ragnarok investiga la mejor en la web → Atlas decide → Quina valida costo → Auron verifica seguridad → se adopta y se documenta
- Ragnarok propone cambio de metodología (SDD/FDD/grafos) → Amarant evalúa arquitectura → Atlas decide → se documenta
- Auron bloquea quest L0 sin plan de rollback → el agente corrige → Auron permite → sigue el quest

---

## 🚀 CÓMO RETOMAR EN LA PRÓXIMA SESIÓN

1. Leer este documento (`docs/PLAN-ARNES.md`)
2. Leer `docs/WHAT-IS-LEFT.md` y `.arnes/next-steps.json` si existen
3. Verificar estado: `git status`, `.arnes/config.json`, `opencode auth list`
4. Continuar con la FASE que quede pendiente (actualmente: FASE 1)
5. Comenzar FASE 1: crear arnes.db + arnes-memory CLI + skills de memoria
6. Nota: Fases 7-9 (Tidus/Ragnarok/Auron) tienen sus agent.md YA creados — solo falta integrarlos (sync + skills + tests)

**Convención**: al terminar cada sesión, actualizar este documento (fases completadas, gotchas nuevos, estado del harness).
