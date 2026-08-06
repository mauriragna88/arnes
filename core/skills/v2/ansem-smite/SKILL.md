---
name: ansem-smite
description: >
  Skill propia de Ansem (Paladin, Backend Tank). Crea APIs, schemas, validación Zod,
  lógica de negocio y RLS. Backend robusto y verificado.
  Trigger: Cuando el quest pide crear/modificar backend (API, schema, query, RLS).
---

## Propósito
Implementar backend sólido con validación, seguridad y verificación.

## Trigger
- Quest pide API routes, server actions, schemas, queries Supabase, RLS
- Ansem asignado al quest backend

## Inputs
- Descripción del endpoint/schema/lógica
- Spec/design del change si existe

## Pasos (procedimiento PROPIO del arnes)
1. **RECALL**: `arnes-memory.ps1 search -Agent ansem -Query "<tipo>"`
   `arnes-graph.ps1 query -Node "<schema|endpoint>"` — no recrear schemas existentes
2. **Convenciones**: memoria `ansem/endpoint-conventions`, `ansem/schemas`
3. **Implementar**: API route/action tipada, Zod para validar inputs SIEMPRE, manejo de
   errores explícito, RLS en tablas Supabase
4. **Seguridad**: input validado, nunca confiar en el cliente (verificar con Auron si L0)
5. **Verificar**: typecheck + tests de la lógica (proporcional a complejidad)
6. **GUARDAR**: `arnes-memory.ps1 save -Agent ansem -Topic "ansem/<tipo>" -Type pattern`
7. **GRAFO**: `arnes-graph.ps1 add -NodeA "<schema>" -NodeB "rls-policy" -Relation protected_by -Agent ansem`

## Output esperado
- API/action/schema funcional, validado con Zod, RLS habilitado, con tests si la lógica lo amerita

## Complementos web (arsenal, NO dependencia)
| Skill web | Cuándo la potencia |
|---|---|
| api-design | semántica HTTP, errores |
| typescript | tipos estrictos |
| postgresql / supabase-cli | queries y RLS |
| schema-design | modelado de datos |

## Memoria
- **Antes**: `search -Agent ansem` (schemas, rls-policies, zod-patterns)
- **Después**: `save -Agent ansem` (schemas, endpoint-conventions, xp)

## Reglas de la skill
1. Zod SIEMPRE para validar inputs
2. Manejo de errores explícito, nunca silencioso
3. RLS habilitado en toda tabla Supabase
4. No confiar en input del cliente
5. No recrear schemas que la memoria/grafo dice que existen
