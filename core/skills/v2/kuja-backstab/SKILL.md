---
name: kuja-backstab
description: >
  Skill propia de Kuja (Rogue, QA DPS). Tests quirúrgicos con verificación proporcional:
  trivial = 1-2 tests o ninguno (regla 4+4=8), complejo = suite completa.
  Trigger: Cuando el quest pide tests, QA, edge cases, o verify de un cambio.
---

## Propósito
Probar con precisión quirúrgica. Un test que vale más que diez genéricos.

## Trigger
- Quest pide tests (unit, E2E, edge cases)
- TURN 5 verify (después de que el party implementó)
- Kuja asignada al quest fix/QA

## Inputs
- Código a probar (componentes, lógica, APIs)
- Spec con criterios de aceptación si existe

## Pasos (procedimiento PROPIO del arnes)
1. **RECALL**: `arnes-memory.ps1 search -Agent kuja -Query "<dominio>"`
   memoria `kuja/test-suites` — no rehacer suites que ya existen
2. **Clasificar complejidad** (regla Proportional Verification):
   - Trivial (sum, getter, flag) → 1-2 tests directos o NINGUNO si es obvio (4+4=8)
   - Media (componente con estado, API 2-3 validaciones) → happy path + 1-2 edge cases
   - Alta (auth, pagos, RLS, concurrencia, parser) → suite completa + mutation si crítico
3. **TDD**: escribir test primero (red) → implementación mínima (green) → refactor
4. **Edge cases**: boundary, null/undefined, overflow — proporcional a la complejidad
5. **Ejecutar**: vitest/playwright según el tipo
6. **GUARDAR**: `arnes-memory.ps1 save -Agent kuja -Topic "kuja/test-suites" -Type pattern`
7. **GRAFO**: registrar relación si el test toca un componente nuevo

## Output esperado
- Tests pasando (o FAIL con bug encontrado + root cause), sin verificación teatral

## Complementos web (arsenal, NO dependencia)
| Skill web | Cuándo la potencia |
|---|---|
| vitest | unit tests |
| playwright | E2E browser |
| testing-principles | qué probar |
| mocking | mocks cuando hacen falta |

## Memoria
- **Antes**: `search -Agent kuja` (test-suites, bugs-found, edge-cases)
- **Después**: `save -Agent kuja` (bugs-found, test-suites, verification-levels)

## Reglas de la skill
1. Verification is sacred — pero proporcional (regla 9 del agent.md)
2. No weaken tests — nunca skip/todo para hacer pass
3. Backstab > Brute force — un test quirúrgico vale más que 10 genéricos
4. Realistic data — no mocks vacíos
5. Root cause — encuentra el bug real, no el síntoma
