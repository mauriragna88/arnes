# Changelog

Todos los cambios relevantes de ARNES ARGOS se registran en este archivo.

## [Unreleased]

### Añadido

- `argos stats`: dashboard de actividad (quests, tokens, tasa de éxito, racha, top agentes).
- `argos xp`: ranking de experiencia por agente con niveles.
- `argos theme`: gestión de temas visuales (atlas/vivi/amarant/eiko/auron).
- Niveles XP visibles en `/party` (chat) y en `argos status`.
- Suite de tests unificada: `npm test` (unit TS + funcionales PS + política read/write +
  parseo de scripts + escaneo de secretos + smoke test).
- CI en GitHub Actions (Windows PowerShell 5.1 + Ubuntu/pwsh) con `tests/run-all.ps1`.
- Test del grafo de relaciones (`arnes-graph`) contra SQLite real.
- Test de contrato de orquestación (`arnes-cycle` / `argos-party` / `arnes-engine`) sin llamadas reales.
- Escáner de secretos sobre archivos rastreados (`tests/scan-secrets.ps1`).
- Grafo activado: seed de edges reales del proyecto en `.arnes/graph/edges.jsonl`.
- Doctor más honesto: reporta el nombre de los agentes faltantes.
- `evenatan-ui.ps1` marcado como legado/deprecado (el CLI activo es `argos`).

### Corregido

- Se serializó la sincronización de `argos` con un mutex nombrado para evitar colisiones entre
  dos procesos que actualizan los agentes de OpenCode al mismo tiempo.
- La aplicación de modelos dejó de reescribir archivos de agentes cuando el contenido generado
  es idéntico al existente, reduciendo el tiempo de arranque repetido.
- Tests unitarios TypeScript: imports ESM corregidos (se ejecutan con `node --test` + `tsx`).

### Documentación

- Se aclaró el estado actual del proyecto y la separación entre capacidades implementadas y
  roadmap.
- Se añadió la guía técnica de arranque, contribución y diagnóstico para GitHub.

## Historial

Las funcionalidades anteriores están descritas en `README.md`, `docs/PLAN-ARNES.md` y
`docs/WHAT-IS-LEFT.md`. Las versiones publicadas se añadirán aquí cuando exista un release.
