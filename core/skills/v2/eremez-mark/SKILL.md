---
name: eremez-mark
description: >
  Skill propia de Eremez (Ranger, Research). Investiga librerías, docs, mejores prácticas.
  Nunca alucina: si no sabe algo, lo investiga antes de responder con fuentes.
  Trigger: Cuando el quest es research, comparar librerías, buscar docs, entender una API.
---

## Propósito
Investigación confiable con fuentes. El explorador del arnes.

## Trigger
- Quest de investigación, comparación, búsqueda de docs
- Librería/API desconocida que el party va a usar
- "Investiga X", "compara Y con Z", "¿cómo se usa W?"

## Inputs
- Pregunta de investigación
- Dominio del proyecto (para filtrar relevancia)

## Pasos (procedimiento PROPIO del arnes)
1. **RECALL**: `arnes-memory.ps1 search -Agent eremez -Query "<tema>"`
   memoria `eremez/library-research` — si ya lo investigamos, reutilizar con cache
2. **Buscar**: context7 (docs oficiales), web, GitHub, docs del repo
3. **Evaluar**: relevancia al stack del arnes (Next.js, TypeScript, Tailwind, Supabase)
4. **Sintetizar**: respuesta con fuentes citadas + recomendación clara
5. **GUARDAR**: `arnes-memory.ps1 save -Agent eremez -Topic "eremez/library-research" -Type discovery`
6. **GRAFO**: registrar relaciones de librerías investigadas

## Output esperado
- Investigación con fuentes, pros/cons, recomendación clara — sin alucinaciones

## Complementos web (arsenal, NO dependencia)
| Skill web | Cuándo la potencia |
|---|---|
| context7 | docs de librerías actualizadas |
| rag | patrones de retrieval |

## Memoria
- **Antes**: `search -Agent eremez` (library-research, docs-cache, github-repos)
- **Después**: `save -Agent eremez` (library-research, xp)

## Reglas de la skill
1. NUNCA alucinar — si no sabes, investiga antes de responder
2. Siempre citar fuentes
3. Cachear investigaciones (no repetir trabajo)
4. Recomendación final clara
5. Context7 para librerías — las docs cambian rápido, no confiar en memoria del modelo
