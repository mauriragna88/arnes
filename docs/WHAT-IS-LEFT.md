# Estado del Proyecto — Que nos Falta

> creado: 2026-07-25
> actualizado: 2026-08-09 (estado del CLI Argos y documentación para GitHub)

## ⚠️ IMPORTANTE — LEE PRIMERO `docs/PLAN-ARNES.md`

El roadmap maestro está en **`docs/PLAN-ARNES.md`**. Ese documento es la fuente de verdad para la visión ARNES v2:
ecosistema 100% propio (memoria SQLite, knowledge graph, SDD/FDD/ADR propios) SIN herramientas externas.
Este archivo resume el estado heredado; el plan futuro vive en PLAN-ARNES.md.

## Completado (lo que ya funciona)

- [x] CLI npm `argos` con entrada multiplataforma basada en PowerShell
- [x] Diagnóstico de prerequisitos con `argos doctor`
- [x] Configuración global de proveedores y modelos por agente
- [x] Sincronización de agentes, modelos y skill trees con OpenCode
- [x] Mutex de sincronización para evitar colisiones entre procesos concurrentes
- [x] Escrituras idempotentes de modelos para reducir el tiempo de arranque repetido
- [x] Memoria propia SQLite/FTS5 y knowledge graph
- [x] Metodologías propias SDD, FDD y ADR documentadas
- [x] Documentación pública base, changelog, contribución y troubleshooting de arranque
- [x] Suite de tests unificada (`npm test`) y CI en GitHub Actions
- [x] Grafo de relaciones activado con edges reales y test propio
- [x] Comandos `argos xp`, `argos stats` y `argos theme`
- [x] Doctor con detección de agentes faltantes por nombre
- [x] Release v0.1.0 publicado en GitHub

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
- [x] CLI legacy `activate.ps1` con deteccion auto + UI rojo-negro
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

### 🔴 Roadmap — ver `docs/PLAN-ARNES.md` para el detalle completo

**FASES (en orden de ejecución):**

| Fase | Qué | Estado |
|---|---|---|
| **FASE 1 — ARNES BRAIN** | arnes.db (SQLite+FTS5) + arnes-memory CLI + skills memoria | Hecho |
| **FASE 2 — ARNES GRAPH** | Capa de relaciones (edges) + arnes-graph CLI | Hecho |
| **FASE 3 — ARNES SDD** | Skills arnes-sdd-* propias | Hecho |
| **FASE 4 — ARNES FDD** | Skills arnes-fdd-* + features | F1 (XP) · F2 (temas) · F3 (stats) done · F4 blocked |
| **FASE 5 — ARNES ADR** | Registro de decisiones + skill arnes-adr | Hecho |
| **FASE 6 — ARGOS CLI + GITHUB** | CLI, modelos, diagnóstico, documentación y publicación | Publicado (release v0.1.0) |

### Pendientes heredados (de la versión anterior)

1. **Probar Atlas en OpenCode real**
   - Verificar que el agente `atlas` carga con system prompt RPG
   - Verificar que la delegacion con `task(subagent_type="vivi")` funciona

2. **Validar Atlas en OpenCode real** con una sesión completa y documentar resultados.

3. **Cerrar la publicación de GitHub**: separar cambios acumulados, revisar secretos, elegir
   commits atómicos y crear el primer release.

4. **Limpiar artefactos locales** antes de publicar, incluyendo imágenes o configuraciones que
   no formen parte del producto.

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
2. ✅ **ARNES v2 100% independiente** — memoria SQLite propia, SDD/FDD/ADR propios. CERO herramientas externas.
3. ✅ **Memoria = SQLite (arnes.db) + FTS5** — búsqueda instantánea tipo cerebro, con export JSONL para git.
4. ✅ **FDD aprobado** — se construye como FASE 4.
5. ✅ **Knowledge Graph aprobado** — capa de relaciones (FASE 2).
6. ✅ **Harness > modelo** — el sistema verifica; el modelo es intercambiable.
7. ✅ **Atlas Shell** — banner + wizard de modelos con flechas + chat directo (FASE 6).
8. ✅ **Continuidad entre sesiones** — este documento + PLAN-ARNES.md son la fuente de retoma.

## Documentos de referencia

- [`README.md`](../README.md) — instalación y uso público.
- [`CHANGELOG.md`](../CHANGELOG.md) — cambios por release.
- [`CONTRIBUTING.md`](../CONTRIBUTING.md) — contribución y validación.
- [`ARGOS-STARTUP.md`](./ARGOS-STARTUP.md) — diagnóstico del arranque.

## SIGUIENTE SESIÓN (guardado 2026-08-10 — para retomar con "continua")

**Estado: todo commiteado y pusheado (master, árbol limpio).** Último commit: `f3ebaa6`.

### Ya implementado hoy (no rehacer)
- `argos target` (selector opencode/codex/claude con party completo en Claude y roster en Codex).
- `argos goal` / `/autowork` (modo autónomo por objetivo con memoria: remediation → siguiente prompt).
- `argos xp`, `argos stats`, `argos theme`.
- Varys guarda la bitácora de secuencia (`varys/evidence-packs/<quest>`); Atlas decide con CONTEXTO DE MEMORIA.
- Suite unificada `npm test` + CI + grafo activado + release v0.1.0 + paquete npm preparado.

### Pendiente PARA EL USUARIO (externo, no es código)
1. **Probar la sesión real**: `argos quest "<algo>"`, `argos goal "<objetivo>" -MaxIterations 3`,
   `argos target codex` y `argos target claude` — es el examen de fuego del ciclo con APIs reales.
2. **Rotar la API key de B.AI** que estaba en el backup local eliminado.
3. **Publicar en npm**: `npm adduser` (login) → `npm publish` (el paquete ya está listo, v0.1.0).
4. **F4 del FDD**: publicar Atlas en Smithery y skills.sh (requiere el npm publish antes).

### Pendiente DE CÓDIGO si el usuario lo pide
- F2 temas: aplicar el tema elegido (`argos theme set X`) a las UI reales (hoy solo persiste).
- F3 stats: costo aproximado USD por sesión/día.
- F1: desbloqueo de skills por nivel de XP (hoy solo muestra niveles).
- Limpieza legado: `activate.ps1` / `evenatan-ui.ps1` (marcado deprecado, no borrado).
- Si la prueba real falla en la cadena quest/party: depurar con el stub `tests/stubs/fake-cycle.ps1`.

### Regla de retoma
Cuando el usuario diga "continua", leer este bloque + `README.md` y seguir con lo pendiente
en el orden: prueba real del usuario → ajustes que surjan → F4 marketplace → mejoras FDD.

## Estado del árbol de trabajo

El repositorio puede contener cambios acumulados de sesiones anteriores. Antes de publicar en
GitHub hay que revisar `git status`, separar los cambios por responsabilidad y no incluir claves,
memoria local ni configuraciones privadas.
