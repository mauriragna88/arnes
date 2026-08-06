# Estado del Proyecto — Que nos Falta

> creado: 2026-07-25
> actualizado: 2026-08-05 (PLAN ARNES v2 — ecosistema 100% propio, ver `PLAN-ARNES.md`)

## ⚠️ IMPORTANTE — LEE PRIMERO `docs/PLAN-ARNES.md`

El roadmap maestro está en **`docs/PLAN-ARNES.md`**. Ese documento es la fuente de verdad para la visión ARNES v2:
ecosistema 100% propio (memoria SQLite, knowledge graph, SDD/FDD/ADR propios) SIN depender de gentle-ai ni engram.
Este archivo resume el estado heredado; el plan futuro vive en PLAN-ARNES.md.

## Completado (lo que ya funciona)

- [x] Estructura SDD completa (proposal, spec, design, tasks)
- [x] Config base `.arnes/config.json` con plataforma/suscripcion/party
- [x] CONVENTIONS.md - reglas universales del harness
- [x] Skill Registry con skills internas + externas mapeadas a cada clase
- [x] Atlas Player Agent (`atlas-player.agent.md`) con quest detect, party select, loop, circuit breaker
- [x] Quest Detector subagent
- [x] Model Router subagent (3 plataformas x free/pro tiers)
- [x] Loop Engine subagent con state machine IDLE → QUESTING → EVALUATE → AUTO_NEXT
- [x] 6 Party Class Agent files:
  - Vivi (Mage frontend) con skills Fireball/Flare/Inferno/Meteor Shower
  - Eiko (Cleric Healer) con skills Mend/Esuna/Cura/Mass Heal
  - Ansem (Paladin Backend) con skills Smite/Divine Shield/Holy Ground
  - Kuja (Rogue QA) con skills Backstab/Shadow Clone/Eviscerate
  - Amarant (Monk Architecture) con skills Foresight/Meditation/Zen
  - Eremez (Ranger Research) con skills Mark/Swarm/Wide Net
- [x] 6 Skill Tree JSON files (uno por clase)
- [x] 3 Tactics files (party composition, turn economy, mana conservation)
- [x] CLI Evenatan (`activate.ps1`) con deteccion auto + UI rojo-negro
- [x] Deploy hooks para:
  - OpenCode (atlas-agent.json + alt.json model mapping)
  - Codex (codexrc.json)
  - Claude (claude_desktop_config.json)
- [x] Cross-platform adapter rules (`adapter-rules.md`)
- [x] Research de skills externas con rankings (`RESEARCH-SKILLS-2026.md`)
- [x] Memoria por subagente (memory-system.md)
- [x] Flujo de uso completo documentado (`USAGE-FLOW.md`)
- [x] **Varys Documentalist** (auditor de docs) — NEW 2026-07-27
- [x] Atlas primary agent configurado en `~/.config/opencode/opencode.json`
- [x] Model chain con auto-fallback NVIDIA → SiliconFlow → Z.ai

## Pendiente (lo que nos falta)

### 🔴 NUEVO PLAN ARNES v2 — ver `docs/PLAN-ARNES.md` para el detalle completo

**FASES (en orden de ejecución):**

| Fase | Qué | Estado |
|---|---|---|
| **FASE 1 — ARNES BRAIN** | arnes.db (SQLite+FTS5) + arnes-memory CLI + skills memoria | ⬅️ PRÓXIMA |
| **FASE 2 — ARNES GRAPH** | Capa de relaciones (edges) + arnes-graph CLI | Pendiente |
| **FASE 3 — ARNES SDD** | Skills arnes-sdd-* propias (sin gentle-ai) | Pendiente |
| **FASE 4 — ARNES FDD** | Skills arnes-fdd-* + features | Pendiente |
| **FASE 5 — ARNES ADR** | Registro de decisiones + skill arnes-adr | Pendiente |
| **FASE 6 — ATLAS SHELL + GIT** | Banner + wizard modelos + chat + git + docs | Pendiente |

### Pendientes heredados (de la versión anterior)

1. **Probar Atlas en OpenCode real**
   - Verificar que el agente `atlas` carga con system prompt RPG
   - Verificar que la delegacion con `task(subagent_type="vivi")` funciona

2. **Git roto** — `.git/` existe pero vacío (0 archivos, sin HEAD). `git init` de nuevo en FASE 6.

3. **atlas-player en opencode.json** apunta a `nvidia/deepseek-ai/deepseek-v4-pro` — actualizar a qwen3.8-max (FASE 6 o antes).

4. **Config de modelos 2026-08-05 ya aplicada** — ver PLAN-ARNES.md sección "Configuración de modelos".

5. **Skills sdd-* de gentle-ai instaladas** — reemplazar por arnes-sdd-* propias (FASE 3).

6. **Basura en repo**: `imagen10.jpg` y `Sin título.jpg` — limpiar en FASE 6.

### Media Prioridad — Quality of Life

7. **XP system en CLI**
   - Trackear XP ganada y guardarlodefic.json
   - Mostrar nivel en /party y /status
   - Skills se desbloquean segun unlocks/skills cuando sube level

### Baja Prioridad — Nice to have

8. **Temas personalizables**
   - Atlas rojo-negro, Tema Vivi (violeta), Tema Amarant (bronce), etc.

9. **Stats dashboard**
   - Total tokens usados por sesion/dia/semana
   - Costo aproximado en USD si api tiene pricing
   - Racha de quests completados

10. **Marketplace publish**
    - subir Atlas RPG a Smithery y skills.sh para que otros la puedan instalar

## Decisiones Tomadas (2026-08-05)

1. ✅ **Modelos reasignados** — DeepSeek V4 Flash como workhorse (75%), GPT-5.6 Luna para razonamiento, Qwen3.8 Max para Atlas. Proveedores: Go + OpenAI (OAuth) + NVIDIA (GRATIS).
2. ✅ **ARNES v2 100% independiente** — memoria SQLite propia, SDD/FDD/ADR propios. CERO dependencia de gentle-ai/engram.
3. ✅ **Memoria = SQLite (arnes.db) + FTS5** — búsqueda instantánea tipo cerebro, con export JSONL para git.
4. ✅ **FDD aprobado** — se construye como FASE 4.
5. ✅ **Knowledge Graph aprobado** — capa de relaciones (FASE 2).
6. ✅ **Harness > modelo** — el sistema verifica; el modelo es intercambiable.
7. ✅ **Atlas Shell** — banner + wizard de modelos con flechas + chat directo (FASE 6).
8. ✅ **Continuidad entre sesiones** — este documento + PLAN-ARNES.md son la fuente de retoma.
