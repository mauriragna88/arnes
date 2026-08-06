---
name: arnes-fdd-review
description: >
  ARNES FDD Fase 3 - Review. Revisa la feature implementada contra su plan: verifica
  criterios de done, calidad y que cumple el valor prometido. Rol: Kuja (QA) + Tywin (verdict).
  Trigger: Cuando implement termino la feature y antes de archivarla.
---

## Purpose

Verificar que la feature entrega el valor prometido y pasa los gates de calidad.
El review es por FEATURE (rápido y enfocado), no un mega-audit de todo el set.

## Flujo

1. Leer feature-plan: `.arnes/fdd/<FL>/F<N>-plan.md` (criterios de done)
2. Ejecutar verificaciones reales:
   - `npm run lint`, `npm run typecheck`, `npm test`, `npm run build`
3. Contrastar cada criterio del plan contra el código
4. Kuja: tests de la feature (proporcional — trivial = poco, complejo = completo)
5. Tywin: verdict PASS / FAIL_PARTIAL / FAIL_TOTAL con evidencia
6. Guardar verdict: `arnes-memory save -Agent tywin -Topic tywin/verdicts`

## Output esperado

```
FEATURE F<N> REVIEW:
  - Criterios: 5/5 cumplidos
  - lint/types/tests/build: PASS
  - Verdict: PASS
  - Evidencia: <comandos + resultados>
```

## Reglas

1. **Evidencia, no opinión** — cada check con comando ejecutado
2. **FAIL = remediation** — qué falta exactamente para el siguiente intento
3. **Proporcionalidad** — una feature S no necesita el mismo review que una L
4. **Guardar verdict** — la memoria sabe si la feature pasó o no

## Comando de referencia

```powershell
Get-Content .arnes/fdd/<FL>/F<N>-plan.md
```
