# ARNES ARGOS — Harness RPG de IA para Desarrollo

> Rojo y Negro, como el Atlas de la Liga MX.
> **ARGOS**: el gigante mitológico de los 100 ojos — todo lo ve, todo lo vigila.
> **16 agentes RPG**: 6 party + 7 auditores/especiales + 2 warden + Atlas orchestrator.
> **100% independiente**: memoria propia (SQLite+FTS5), SDD/FDD/ADR propios, skills propias.
> **CERO dependencia** de gentle-ai, engram, openspec o arneses externos.

---

## 🚀 Instalación rápida

```powershell
# 1. Entra a tu carpeta de trabajo
cd C:\Users\LapOne Mx\Documents\GitHub\arnes   # o cualquier proyecto

# 2. Abre ARNES ARGOS (el entorno)
argos
#    → detecta si el proyecto es nuevo
#    → si es nuevo: inicializa → conecta proveedores (/connect) → configura modelos (/configuremodel)
#    → si ya está: menú con chat, connect, configure, status, memory

# Comandos directos:
argos connect       # conectar proveedores (nuestro /connect)
argos configure     # configurar modelo por agente (nuestro /configuremodel)
argos chat          # chat con Atlas (orquestador)
argos status        # estado del entorno
```

## 🏢 La Empresa ARNES ARGOS (16 agentes)

| Departamento | Agente | Clase | Modelo |
|---|---|---|---|
| Dirección | **Atlas** | Player/Orchestrator | qwen3.8-max |
| Sistemas/Infra | **Tidus** | Warden | deepseek-v4-flash |
| Compras | **Ragnarok** | Warden | gpt-5.6-luna |
| Programación | **Vivi** | Mage (Frontend) | gpt-5.6-luna |
| Programación | **Ansem** | Paladin (Backend) | deepseek-v4-flash |
| QA | **Kuja** | Rogue | deepseek-v4-flash |
| DevOps | **Eiko** | Cleric | deepseek-v4-flash |
| Arquitectura | **Amarant** | Monk | gpt-5.6-luna |
| Investigación | **Eremez** | Ranger | deepseek-v4-flash |
| Mejora Continua | **Bard** | Bard | gpt-5.6-luna |
| Seguridad | **Auron** | Warden (L0 Gate) | deepseek-v4-flash |
| Analista | **Bran** | Seer | gpt-5.6-luna |
| Finanzas | **Quina** | Banker | deepseek-v4-flash |
| Tracker | **Varys** | Spider | gpt-5.6-luna |
| Verificador | **Tywin** | Verifier | deepseek-v4-flash |
| Consejero | **Sam** | Archivist | gpt-5.6-luna |

## 🧠 ARNES BRAIN (memoria cerebral)

- `arnes.db` — SQLite + FTS5 (el hipocampo: hechos y recuerdos)
- Knowledge Graph — tabla edges (el neocortex: relaciones)
- Export JSONL para git/backup
- Anti-alucinación por diseño: los agentes buscan HECHOS antes de actuar

```powershell
.\cli\arnes-memory.ps1 stats          # estado del cerebro
.\cli\arnes-memory.ps1 search -Query "dark mode" -Agent vivi
.\cli\arnes-memory.ps1 save -Agent vivi -Topic "vivi/ui-patterns" -Type pattern -Content "..."
.\cli\arnes-graph.ps1 path -Start "Login.tsx" -End "tailwind"
```

## 📋 Metodologías propias

| Metodología | Skills | Para qué |
|---|---|---|
| **SDD** | arnes-sdd-propose/spec/design/tasks/apply/verify/archive | Cambios con spec profunda |
| **FDD** | arnes-fdd-plan/implement/review/archive | Features incrementales |
| **TDD** | kuja-backstab + vitest/playwright | Tests primero, proporcional (4+4=8) |
| **ADR** | arnes-adr | Decisiones de arquitectura registradas |
| **Knowledge Graph** | arnes-graph | Relaciones entre componentes/agentes |

## 🎯 Skills propias v2 (16 skills, cero gentle-ai)

Cada agente tiene su skill propia con procedimiento del arnes + skills web como arsenal:
`core/skills/v2/` — vivi-fireball, ansem-smite, kuja-backstab, eiko-mend, amarant-foresight,
eremez-mark, auron-bulwark, bran-vision, quina-ledger, varys-whisper, tywin-judgment,
sam-counsel, atlas-orchestrate, tidus-tide-check, ragnarok-scout.

## 🔌 Proveedores de modelos

- **OpenCode Go** ($10/mes) — DeepSeek V4 Flash (workhorse), Qwen3.8 Max (Atlas)
- **OpenAI** (cuenta GPT vía OAuth) — GPT-5.6 Luna para razonamiento
- **NVIDIA NIM** (gratis) — DeepSeek V4 Flash/Pro sin costo
- **B.AI** — Claude Opus/Fable, GPT-5.6, Qwen3.8

**Mini-guía completa**: `docs/PROVIDERS-GUIDE.md` — cómo se conecta cada proveedor
(OAuth de OpenAI, API de NVIDIA, catálogo Go), las URLs y los comandos.

Configuración en `.arnes/config.json` — reconfigurable con `atlas-shell.ps1 -Setup` (wizard con flechas).

## 📚 Documentación

- `docs/PLAN-ARNES.md` — roadmap maestro + continuidad entre sesiones
- `docs/WHAT-IS-LEFT.md` — estado del proyecto
- `.arnes/next-steps.json` — fases y criterios de aceptación
- `.arnes/adr/` — decisiones de arquitectura
- `.arnes/sdd/` — cambios SDD
- `.arnes/fdd/` — feature sets

## ⚠️ Firma de artefactos (opcional)

```powershell
$env:ARNES_ARTIFACT_HMAC_KEY = "usa-un-secreto-largo-y-aleatorio"
```

No guardes esta clave en Git.

## 🔄 Cómo retomar entre sesiones

1. Abre `docs/PLAN-ARNES.md`
2. Verifica estado: `git status`, `.arnes/config.json`, `opencode auth list`
3. Continúa con la fase pendiente del plan
4. Al terminar sesión: guarda digest en memoria (`arnes-memory.ps1 save -Agent atlas -Topic atlas/digest-<fecha>`)
