---
name: arnes-fdd-archive
description: >
  ARNES FDD Fase 4 - Archivo. Cierra la feature: marca done en la feature-list, registra
  quest en memoria, actualiza grafo, exporta snapshot. La feature queda documentada.
  Trigger: Cuando review emitió PASS y la feature está lista para cerrarse.
---

## Purpose

Cerrar el ciclo de la feature: queda documentada, la memoria actualizada, el grafo al día.
La feature-list refleja el progreso del feature set completo.

## Flujo

1. Verificar que review emitió PASS (o deuda documentada y aceptada por Atlas)
2. Marcar feature done en la feature-list: `.arnes/fdd/<FL>/`
3. Registrar quest en memoria:
   ```powershell
   .\cli\arnes-memory.ps1 quest -Json '{"description":"<feature>","quest_type":"<tipo>","party":["<agentes>"],"result":"PASS","tokens_used":<N>}'
   ```
4. Guardar resumen:
   ```powershell
   .\cli\arnes-memory.ps1 save -Agent atlas -Topic "atlas/quest-history" -Type action -Content "Feature F<N> completada: <resumen>"
   ```
5. Actualizar grafo (relaciones de la feature):
   ```powershell
   .\cli\arnes-graph.ps1 add -NodeA "<X>" -NodeB "<Y>" -Relation "<rel>" -Agent "<agente>"
   ```
6. Marcar plan como `archived` en feature-plan.md
7. Exportar snapshot:
   ```powershell
   .\cli\arnes-memory.ps1 export
   ```
8. Reportar a Atlas: feature archivada + progreso del feature set (F1/3 done)

## Reglas

1. **Nada de archivar sin review PASS** — gate inalterable
2. **Feature-list al día** — el progreso del set siempre visible
3. **Memoria + grafo + export** — los 3 obligatorios al cerrar
4. **Auto-loop natural** — al archivar F<N>, sigue F<N+1> si el set sigue activo

## Criterios de "archived"

- [ ] Review PASS
- [ ] Feature done en la lista
- [ ] Quest registrado
- [ ] Grafo actualizado
- [ ] JSONL exportado
