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
1. **RECALL**: `read .arnes/memory/export/ansem-memory.jsonl`
   `read .arnes/graph/edges.jsonl` — no recrear schemas existentes
2. **Convenciones**: memoria `ansem/endpoint-conventions`, `ansem/schemas`
3. **Implementar**: API route/action tipada, Zod para validar inputs SIEMPRE, manejo de
   errores explícito, RLS en tablas Supabase
4. **Seguridad**: input validado, nunca confiar en el cliente (verificar con Auron si L0)
5. **Verificar**: typecheck + tests de la lógica (proporcional a complejidad)
6. **GUARDAR**: `write` una linea en `.arnes/memory/export/ansem-memory.jsonl` (topic `ansem/<tipo>`, type `pattern`)
7. **GRAFO**: `write` la relacion en `.arnes/graph/edges.jsonl` (source "<schema>", target "rls-policy", relation protected_by, agent ansem)

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
- **Antes**: `read .arnes/memory/export/ansem-memory.jsonl` (schemas, rls-policies, zod-patterns)
- **Después**: `write` a `.arnes/memory/export/ansem-memory.jsonl` (schemas, endpoint-conventions, xp)

## Reglas de la skill
1. Zod SIEMPRE para validar inputs
2. Manejo de errores explícito, nunca silencioso
3. RLS habilitado en toda tabla Supabase
4. No confiar en input del cliente
5. No recrear schemas que la memoria/grafo dice que existen
