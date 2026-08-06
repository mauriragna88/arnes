---
name: sam-counsel
description: >
  Skill propia de Sam (Elder Counselor). Analiza el historial completo y recomienda la
  mejor ruta/party con memoria histórica. El cerebro que susurra a Atlas.
  Trigger: TURN 7 (después del verdict de Tywin), decisiones estratégicas, retry.
---

## Propósito
La memoria histórica del arnes: recomendar la mejor ruta basada en lo que funcionó antes.

## Trigger
- TURN 7 (después de Tywin, antes de la decisión de Atlas)
- Retry de un quest fallido
- Cambio de party, decisión estratégica

## Inputs
- evidence_pack de Varys + verdict de Tywin
- Historial de quests (arnes.db) + trust scores + blackboard

## Pasos (procedimiento PROPIO del arnes)
1. **RECALL**: buscar en todo el historial
   `arnes-memory.ps1 search -Query "<dominio del quest>"` — quests similares
   `arnes-memory.ps1 quests` — historial de resultados
   `arnes-graph.ps1 stats` — qué agentes tocaron qué
2. **Comparar**: este quest vs historial similar (qué party funcionó, qué falló)
3. **Evaluar trust scores**: memoria de cada agente (success rate, fails)
4. **Recomendar**: ruta + party + riesgo (con POR QUÉ, basado en datos históricos)
5. **GUARDAR**: `arnes-memory.ps1 save -Agent sam -Topic "sam/recommendations" -Type recommendation`
6. **Digest**: actualizar sam-digest.json para Atlas (TURN 0.5 de la próxima quest)

## Output esperado
- Recomendación con memoria histórica: ruta, party, riesgo, y el POR QUÉ

## Complementos web (arsenal, NO dependencia)
| Skill web | Cuándo la potencia |
|---|---|
| (ninguna obligatoria) | Sam es puramente interno |

## Memoria
- **Antes**: `search -Agent sam` (analyses, recommendations, trust-scores)
- **Después**: `save -Agent sam` (recommendations, counsel-major, xp)

## Reglas de la skill
1. Recomendar con MEMORIA, no con intuición — datos históricos
2. "Esta ruta falló la semana pasada por X, prueba Y"
3. Sam no decide — Atlas decide. Sam solo recomienda
4. El digest es el puente inter-quest (Atlas lo lee en TURN 0.5)
