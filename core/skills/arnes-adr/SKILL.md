---
name: arnes-adr
description: >
  ARNES ADR - Architecture Decision Records. Registra cada decision de arquitectura del
  harness y los proyectos: contexto, decision, alternativas, consecuencias. La memoria
  de largo plazo de "por que hicimos X".
  Trigger: Cuando se toma una decision de arquitectura (elegir libreria, patron, estructura,
  proveedor, metodo), Amarant registra un ADR.
---

## Purpose

Todo el arnes sabe POR QUÉ se decidió lo que se decidió. Sin ADR, las decisiones se olvidan
y el "porque" se pierde. Con ADR, cualquier agente (o el usuario) puede consultar la razón.

## Flujo

1. Crear archivo: `.arnes/adr/ADR-<NNN>-<slug>.md` (copiar de template.md)
2. Llenar:
   - **Contexto**: qué motivó la decisión
   - **Decisión**: qué elegimos
   - **Alternativas**: tabla pros/contras de las opciones
   - **Consecuencias**: positivas + negativas/riesgos
   - **Razón**: por qué esta sobre las demás
3. Guardar en memoria:
   ```powershell
   .\cli\arnes-memory.ps1 save -Agent amarant -Topic "amarant/arch-decisions" -Type decision -Content "ADR-NNN: <titulo> - <resumen>"
   ```
4. Conectar en grafo si aplica:
   ```powershell
   .\cli\arnes-graph.ps1 add -NodeA "<decision>" -NodeB "<tecnologia>" -Relation "decided" -Agent amarant
   ```

## Reglas

1. **Decisión grande = ADR** — elegir librería, cambiar arquitectura, adoptar metodología, cambiar proveedor
2. **Contexto completo** — sin contexto, el ADR no sirve en 3 meses
3. **Alternativas reales** — no solo la elegida; las que se descartaron y por qué
4. **Consecuencias honestas** — riesgos incluidos, no solo lo bonito
5. **Amarant registra** — él es el dueño de la arquitectura (puede delegar la redacción)
6. **Se guarda en memoria** — arnes.db lo referencia para siempre

## Ejemplos de ADR ya registrados (2026-08-05)

- ADR-001: Memoria SQLite+FTS5 (no JSONL, no engram)
- ADR-002: SDD/FDD/ADR propios (sin gentle-ai)
- ADR-003: Skills v2 propias + web como complemento

## Comando de referencia

```powershell
Get-Content .arnes/adr/template.md
```
