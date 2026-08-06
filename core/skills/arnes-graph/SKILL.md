---
name: arnes-graph
description: >
  Grafo de relaciones del harness ARNES (arnes.db edges). El NEOCORTEX del arnes:
  guarda RELACIONES entre nodos (componentes, librerias, agentes, modulos, tablas).
  Responde preguntas de relacion: "quien toco X", "que depende de Y", "existe camino entre A y B".
  Anti-alucinacion por relaciones: si el grafo dice que un componente YA usa Zod,
  el agente NO lo reimplementa.
  Trigger: Cuando necesites saber relaciones entre codigo, quien trabajo en que zona,
  dependencias entre componentes, o mapear el proyecto.
---

## Purpose

El grafo complementa la memoria: SQLite guarda los HECHOS (observaciones), el grafo
guarda las CONEXIONES (edges). Cuando necesitas saber "quien toco esto" o "que usa que",
consultas el grafo — es más rápido y preciso que adivinar.

## Como usar (CLI)

### Agregar una relacion (despues de trabajar)
```powershell
.\cli\arnes-graph.ps1 add -NodeA "Login.tsx" -NodeB "zod" -Relation "uses" -Agent vivi
```
Relaciones comunes:
- `uses` — un componente usa una libreria
- `imports` — un componente importa otro
- `created_by` — un agente creo un nodo
- `touched_by` — un agente trabajo en un nodo
- `protected_by` — una tabla esta protegida por una policy
- `depends_on` — un modulo depende de otro
- `implements` — una clase implementa una interfaz

### Consultar relaciones de un nodo
```powershell
.\cli\arnes-graph.ps1 query -Node "Login.tsx"
```

### Vecinos (recorrido de relaciones)
```powershell
.\cli\arnes-graph.ps1 neighbors -Node "Login.tsx" -Depth 2
```

### Path-finding (camino entre nodos)
```powershell
.\cli\arnes-graph.ps1 path -Start "Login.tsx" -End "tailwind"
```
Retorna el camino más corto: Login.tsx →[imports]→ Sidebar.tsx →[uses]→ tailwind

### Stats del grafo
```powershell
.\cli\arnes-graph.ps1 stats
```

## Preguntas que responde (ejemplos reales)

| Pregunta | Comando |
|---|---|
| "¿Qué usa Login.tsx?" | `query -Node "Login.tsx"` |
| "¿Quién trabajó en auth?" | `query -Node "auth"` o `neighbors -Node "auth" -Depth 2` |
| "¿Sidebar depende de tailwind?" | `path -Start "Sidebar.tsx" -End "tailwind"` |
| "¿Hay relación entre users y vivi?" | `path -Start "users" -End "vivi"` |
| "¿Qué componentes creó Vivi?" | `query -Node "vivi"` (con relation created_by) |

## Flujo obligatorio (anti-alucinacion)

### ANTES de crear algo nuevo:
1. `query -Node <nombre-del-componente>` — ¿ya existe? ¿alguien lo toco?
2. `neighbors -Node <libreria> -Depth 1` — ¿qué se conecta con esta libreria?
3. Si el grafo muestra que X YA usa Y → NO lo reimplementes, reutiliza

### DESPUES de trabajar:
1. `add -NodeA <lo-que-hiciste> -NodeB <lo-que-usa> -Relation <relacion> -Agent <tu>`
2. Esto alimenta el mapa del proyecto para toda la empresa ARNES

## Reglas de oro

1. **El grafo es el neocortex** — guarda RELACIONES, no hechos (los hechos van a arnes-memory)
2. **Nodos son cosas**: componentes, librerias, tablas, agentes, modulos, servicios
3. **Aristas son acciones**: uses, imports, created_by, touched_by, depends_on
4. **Anti-alucinacion**: si el grafo dice que existe, existe. No lo re-inventes.
5. **Siempre con -Agent**: cada relacion sabe QUIEN la creo (auditabilidad)
6. **Proporcionalidad**: no agregues edges obvios que nunca cambian (4+4=8)
7. **Despues de un quest grande**: registra TODAS las relaciones nuevas del trabajo

## Ejemplo completo de una sesion

```
1. Vivi crea Navbar.tsx (usa tailwind)
   .\cli\arnes-graph.ps1 add -NodeA "Navbar.tsx" -NodeB "tailwind" -Relation "uses" -Agent vivi

2. Ansem consulta antes de tocar auth:
   .\cli\arnes-graph.ps1 query -Node "auth"
   → ve que Login.tsx ya existe y usa zod → NO reimplementa

3. Atlas pregunta "quien puede tocar el Login sin romper nada?"
   .\cli\arnes-graph.ps1 neighbors -Node "Login.tsx" -Depth 2
   → ve vivi (creo Login) y la relacion con Sidebar → sabe a quien delegar
```

## Ubicacion

- `cli/arnes-graph.ps1` — CLI PowerShell
- `cli/arnes_brain.py` — motor (funciones: add_edge, query_edges, neighbors, path, graph_stats)
- Tabla `edges` en `arnes.db`
