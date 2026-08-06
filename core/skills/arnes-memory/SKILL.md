---
name: arnes-memory
description: >
  Memoria cerebral del harness ARNES (arnes.db SQLite + FTS5). Guarda, busca y exporta
  recuerdos de los agentes. Anti-alucinacion por diseno: el agente busca HECHOS reales
  en su memoria antes de actuar, en vez de inventar.
  Trigger: Antes de trabajar, cuando necesites recordar algo de sesiones pasadas, cuando
  termines una tarea y debas guardar lo aprendido, o cuando Atlas te pida contexto.
---

## Purpose

El cerebro del harness. Cada agente tiene su namespace privado en arnes.db y puede:
- **Buscar** recuerdos relevantes ANTES de trabajar (recall selectivo = no alucinar)
- **Guardar** aprendizajes DESPUES de trabajar (memoria episodica/semantica)
- **Exportar** a JSONL para git/backup

## Como usar (CLI)

Todas las operaciones se ejecutan con `arnes-memory.ps1` (PowerShell) que envuelve `arnes_brain.py`:

### Guardar un recuerdo (despues de trabajar)
```powershell
.\cli\arnes-memory.ps1 save -Agent vivi -Topic "vivi/ui-patterns" -Type pattern -Content "User prefiere dark mode"
```
- `-Agent`: tu nombre (vivi, ansem, kuja, atlas...)
- `-Topic`: namespace/topic_key (ej: `vivi/components-built`, `ansem/rls-policies`)
- `-Type`: bugfix | decision | pattern | discovery | preference | verdict | recommendation | action | session_summary

### Buscar recuerdos (ANTES de trabajar — anti-alucinacion)
```powershell
.\cli\arnes-memory.ps1 search -Query "dark mode" -Agent vivi
```
El FTS5 busca en todo el contenido. Si hay un hecho relevante (ej: "ya existe Sidebar.tsx"),
el agente lo usa y NO reinventa ni alucina.

### Ver tu memoria completa (namespace privado)
```powershell
.\cli\arnes-memory.ps1 agent -Agent vivi
```

### Contexto reciente del harness
```powershell
.\cli\arnes-memory.ps1 context
```

### Exportar / importar (para git/backup)
```powershell
.\cli\arnes-memory.ps1 export
.\cli\arnes-memory.ps1 import
```

### Stats del cerebro
```powershell
.\cli\arnes-memory.ps1 stats
```

## Flujo obligatorio para cada agente

### ANTES de actuar (recall — nunca alucinar):
1. Busca en tu namespace lo relevante al quest:
   `search -Agent <tu> -Query <keywords del quest>`
2. Si encuentras un hecho (componente existente, patrón que funcionó, bug recurrente),
   ÚSALO en tu trabajo. NO reinventes lo que ya existe.

### DESPUES de actuar (guardar — memoria episodica):
1. Guarda lo aprendido:
   `save -Agent <tu> -Topic <tu>/<patron> -Type <tipo> -Content "<leccion breve>"`
2. Ejemplos de topic_key:
   - `vivi/components-built` — componentes ya creados (NO recrear)
   - `vivi/ui-patterns` — patrones UI que funcionaron
   - `ansem/rls-policies` — RLS que funcionaron
   - `kuja/bugs-found` — bugs + root cause
   - `eiko/build-failures` — builds rotos + causa

## Reglas de oro

1. **Recuerda antes de actuar** — el recall es OBLIGATORIO antes de trabajo creativo
2. **Guarda despues de actuar** — el aprendizaje es OBLIGATORIO al terminar
3. **Hechos, no opiniones** — guarda lo que PASO, no lo que crees que paso
4. **Conciso pero completo** — suficiente contexto para que tu yo futuro lo entienda
5. **Namespace propio** — no escribas en el namespace de otro agente (eso es del blackboard)
6. **El 4+4=8 aplica** — si el dato es obvio y nunca cambia, no gastes tokens guardandolo

## Ubicacion de archivos

- `arnes.db` — SQLite (cerebro activo, FTS5)
- `.arnes/memory/export/*.jsonl` — snapshots para git/backup
- `cli/arnes-memory.ps1` — CLI PowerShell
- `cli/arnes_brain.py` — motor Python (SQLite nativo)
