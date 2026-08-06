---
name: arnes-skill-v2
description: >
  TEMPLATE de skill propia v2 para el harness ARNES. Define la estructura canónica:
  trigger, inputs, pasos propios, output, conexión a memoria (arnes.db) y complementos web.
  Trigger: Cuando se crea o actualiza una skill de agente (FASE 3.5).
---

## Purpose

Las skills v2 son el PROCEDIMIENTO propio del ARNES: cómo ejecuta cada agente su trabajo.
NO dependen de gentle-ai. Las skills web instaladas (react, tailwind, playwright...) son
COMPLEMENTO DE PODER — potencian la ejecución, pero el procedimiento es nuestro.

## Estructura canónica de una skill v2

```
---
name: <agente>-<skill>
description: <trigger de activación>
---

## Propósito
<qué logra esta skill y cuándo se usa>

## Trigger (cuándo se dispara automáticamente)
- <condición 1>
- <condición 2>

## Inputs
- <entrada necesaria>

## Pasos (procedimiento PROPIO del arnes)
1. <paso 1 — consultar memoria antes de actuar>
2. <paso 2 — ejecutar con pasos propios>
3. <paso 3 — verificar>
4. <paso 4 — guardar en memoria>

## Output esperado
- <artefacto verificable>

## Complementos web (arsenal, NO dependencia)
| Skill web | Cuándo la potencia |
|---|---|
| <skill-web> | <cómo ayuda> |

## Memoria
- **Antes**: buscar en arnes.db (anti-alucinación)
- **Después**: guardar patrón/lección en arnes.db

## Reglas de la skill
1. <regla 1>
2. <regla 2>
```

## Reglas para crear skills v2

1. **Procedimiento propio** — los pasos son del arnes, no copia de skills web
2. **Trigger claro** — cuándo se dispara automáticamente
3. **Memoria integrada** — antes (recall) y después (guardar)
4. **Complementos web explícitos** — qué skills potencian la ejecución
5. **Output verificable** — qué se entrega y cómo se comprueba
6. **Proporcionalidad** — no sobre-especificar; el mínimo que garantiza calidad
