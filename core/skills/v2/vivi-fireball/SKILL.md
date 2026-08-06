---
name: vivi-fireball
description: >
  Skill propia de Vivi (Mage, Frontend DPS). Genera componentes React con TypeScript strict,
  Tailwind responsive, dark mode + rojo atlas, estados loading/error/empty, ARIA.
  Trigger: Cuando el quest pide crear un componente React/TSX nuevo.
---

## Propósito
Crear componentes frontend de alta calidad siguiendo el procedimiento propio del arnes.

## Trigger
- Quest pide crear componente React/TSX (botón, modal, form, dashboard, card...)
- Vivi asignada al quest frontend

## Inputs
- Descripción del componente (props, comportamiento, estilo)
- Spec/design del change si existe (.arnes/sdd/)

## Pasos (procedimiento PROPIO del arnes)
1. **RECALL**: buscar en memoria antes de crear:
   `arnes-memory.ps1 search -Agent vivi -Query "<tipo de componente>"`
   `arnes-graph.ps1 query -Node "<nombre>"` — si ya existe, REUTILIZAR, no recrear
2. **Revisar preferencias**: memoria `vivi/ui-patterns` (dark mode + rojo atlas + container queries)
3. **Estructura**: Server Component por defecto; `use client` solo si necesita hooks de browser
4. **Implementar**: TypeScript strict (sin any), Tailwind responsive mobile-first, estados
   loading/error/empty, ARIA roles, zod si valida inputs
5. **Verificar**: lint + typecheck + test del archivo (regla Kuja proporcional: trivial = 1-2 tests)
6. **GUARDAR**: `arnes-memory.ps1 save -Agent vivi -Topic "vivi/components-built" -Type pattern -Content "<componente>"`
7. **GRAFO**: `arnes-graph.ps1 add -NodeA "<Componente>.tsx" -NodeB "<libreria>" -Relation uses -Agent vivi`

## Output esperado
- Componente .tsx/.tsx funcional, tipado, accesible, con sus tests si la lógica lo amerita

## Complementos web (arsenal, NO dependencia)
| Skill web | Cuándo la potencia |
|---|---|
| react | patrones React 19, Server Components |
| tailwind | utility classes responsive |
| design-systems | tokens y composición |
| accessibility | WCAG + ARIA |

## Memoria
- **Antes**: `search -Agent vivi` (components-built, ui-patterns, failed-attempts)
- **Después**: `save -Agent vivi` (components-built, ui-patterns, xp)

## Reglas de la skill
1. Server Component por defecto
2. Sin `any` — TypeScript strict
3. Dark mode + rojo atlas (preferencia del usuario)
4. Estados completos: loading, error, empty
5. No recrear lo que la memoria/grafo dice que existe
