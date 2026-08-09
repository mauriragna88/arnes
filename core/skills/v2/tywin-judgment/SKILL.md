---
name: tywin-judgment
description: >
  Skill propia de Tywin (Verifier). Audita el output del quest contra el spec y emite
  verdict PASS/FAIL con evidencia. Un FAIL sin remediation es auditoría incompleta.
  Trigger: TURN 6, después de que Varys entrega el evidence_pack.
---

## Propósito
El juicio final: ¿el trabajo cumple lo que se pidió?

## Trigger
- TURN 6 (después del evidence_pack de Varys)
- Fin de cualquier quest con implementación

## Inputs
- evidence_pack de Varys (criterios, artefactos, comandos, diff)
- Spec del change si existe (.arnes/sdd/) — criterios de aceptación

## Pasos (procedimiento PROPIO del arnes)
1. **RECALL**: leer specs y criterios relevantes (solo read)
   `read .arnes/memory/export/tywin-memory.jsonl` — veredictos previos del dominio
   `read .arnes/sdd/<change-id>/spec.md` si existe — criterios de aceptación
2. **Verificar con lectura directa** (no confiar en el ejecutor):
   - `read` los archivos del change: tipos, imports, tests, estructura
   - Contrastar CADA criterio del spec contra lo leído
3. **Emitir verdict**:
   - PASS: todos los criterios cumplidos
   - FAIL_PARTIAL: algunos cumplidos + remediation listado
   - FAIL_TOTAL: no cumple + remediation completo (QUÉ falta exactamente)
4. **GUARDAR**: `write` una linea en `.arnes/memory/export/tywin-memory.jsonl` (topic `tywin/verdicts`, type `verdict`)
5. **Entregar a Atlas**: verdict + remediation (si FAIL)

## Output esperado
- verdict (PASS/FAIL) con evidencia + remediation brief si falla

## Complementos web (arsenal, NO dependencia)
| Skill web | Cuándo la potencia |
|---|---|
| testing-principles | qué verificar |
| validation-pipeline | gates de validación |

## Memoria
- **Antes**: `read .arnes/memory/export/tywin-memory.jsonl` (verdicts, fail-reasons)
- **Después**: `write` a `.arnes/memory/export/tywin-memory.jsonl` (verdicts, xp)

## Reglas de la skill
1. Evidencia, no opinión — cada PASS/FAIL con archivo leído (read) y criterio contrastado
2. FAIL SIN remediation = auditoría incompleta (gate inalterable)
3. No aprobar sin tests si el spec los pedía
4. Todo retry conserva las referencias de evidencia y vuelve a pasar por Tywin
