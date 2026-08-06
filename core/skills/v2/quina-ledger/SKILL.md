---
name: quina-ledger
description: >
  Skill propia de Quina (Token Banker). Controla el presupuesto de tokens del harness:
  cuánto se gastó, cuánto queda, alertas de umbral.
  Trigger: Quest de /status de presupuesto, revisión de gasto, alerta de tokens.
---

## Propósito
El departamento de finanzas del arnes: que los tokens alcancen todo el mes.

## Trigger
- "¿Cuánto hemos gastado?", "¿alcanza el presupuesto?", /status
- Antes de un quest grande (boss fight) — estimar costo
- Cuando un agente gasta de más

## Inputs
- Datos de quests (tokens_used en arnes.db)
- Budget configurado (config.json preferences)

## Pasos (procedimiento PROPIO del arnes)
1. **RECALL**: `arnes-memory.ps1 quests` — todos los quests con tokens_used
2. **Calcular**: gasto total, gasto por agente, gasto por tipo de quest, tendencia
3. **Comparar con budget**: config.json (si hay budget semanal/mensual)
4. **Emitir alerta**: 🟢 sano (gasto < 50%), 🟡 ojo (< 80%), 🔴 crítico (> 80%)
5. **Recomendar**: qué ajustar (agente más barato, menos quests, etc.)
6. **GUARDAR**: `arnes-memory.ps1 save -Agent quina -Topic "quina/token-spent" -Type pattern`

## Output esperado
- Reporte de gasto con semáforo y recomendación de ahorro

## Complementos web (arsenal, NO dependencia)
| Skill web | Cuándo la potencia |
|---|---|
| (ninguna obligatoria) | Quina es puramente interna |

## Memoria
- **Antes**: `search -Agent quina` (token-spent, budget-alerts)
- **Después**: `save -Agent quina` (token-spent, xp)

## Reglas de la skill
1. El budget es sagrado — no gastar sin saber cuánto queda
2. Hablar con números (tokens, % del budget)
3. Alertar ANTES de que se acabe, no después
4. Proporcionalidad: reportes concisos, no novelas
