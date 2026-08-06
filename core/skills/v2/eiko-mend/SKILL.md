---
name: eiko-mend
description: >
  Skill propia de Eiko (Cleric, Healer/DevOps). Repara builds rotos, arregla CI/CD,
  deploy seguro, container issues. El healer que rescata al party.
  Trigger: Cuando un build falla, CI/CD se rompe, deploy tiene problemas, o Eiko entra a rescatar.
---

## Propósito
Sanar el entorno de desarrollo: builds, CI/CD, deploys, containers.

## Trigger
- Build roto, tests que no compilan, deploy fallido, CI pipeline roto
- Eiko asignada como healer/rescate

## Inputs
- Error de build/deploy/CI (log o mensaje)
- Contexto del quest que falló

## Pasos (procedimiento PROPIO del arnes)
1. **RECALL**: `arnes-memory.ps1 search -Agent eiko -Query "<tipo de error>"`
   memoria `eiko/build-failures` — si es un error conocido, aplicar fix documentado
2. **Diagnóstico**: leer el error real (log), identificar ROOT CAUSE no el síntoma
3. **Fix mínimo**: el cambio más pequeño que arregla (no refactors durante un rescate)
4. **Verificar**: build pasa → tests pasan → deploy dry-run si aplica
5. **GUARDAR**: `arnes-memory.ps1 save -Agent eiko -Topic "eiko/build-failures" -Type bugfix`
6. **GRAFO**: registrar la relación del fix si toca nodos nuevos

## Output esperado
- Build/CI/deploy funcionando, con la causa raíz documentada en memoria

## Complementos web (arsenal, NO dependencia)
| Skill web | Cuándo la potencia |
|---|---|
| ci-cd | pipelines GitHub Actions |
| docker / docker-compose | container issues |
| deploy / vercel-deploy | despliegues |
| git-discipline | conflictos de merge |

## Memoria
- **Antes**: `search -Agent eiko` (build-failures, ci-cd-fixes, deployment-issues)
- **Después**: `save -Agent eiko` (build-failures, vivi-care, xp)

## Reglas de la skill
1. Root cause, no síntoma
2. Fix mínimo durante rescate — refactor después
3. Verificar SIEMPRE que el build pasa antes de reportar healed
4. Documentar cada fallo con su causa (memoria)
