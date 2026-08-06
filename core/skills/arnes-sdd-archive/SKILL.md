---
name: arnes-sdd-archive
description: >
  ARNES SDD Fase 7 - Archivo. Cierra el change: sincroniza el spec a documentacion,
  registra la memoria final, marca el change como archived y limpia el estado activo.
  Trigger: Cuando verify emitio PASS y Atlas aprobo el cierre.
---

## Purpose

La fase **archive** cierra el ciclo SDD. El change queda documentado, la memoria actualizada,
y el grafo refleja las relaciones finales. El siguiente cambio puede comenzar limpio.

## Flujo

1. Verificar que verify emitio PASS (o FAIL aceptado por Atlas con deuda documentada)
2. Registrar el quest final:
   ```powershell
   .\cli\arnes-memory.ps1 quest -Json '{"description":"<desc>","quest_type":"<tipo>","party":["<agentes>"],"result":"PASS","tokens_used":<N>}'
   ```
3. Guardar resumen en memoria:
   ```powershell
   .\cli\arnes-memory.ps1 save -Agent atlas -Topic "atlas/quest-history" -Type action -Content "Change C-XXX completado: <resumen>"
   ```
4. Actualizar grafo (si quedaron relaciones sin registrar):
   ```powershell
   .\cli\arnes-graph.ps1 add -NodeA "<X>" -NodeB "<Y>" -Relation "..." -Agent "<agente>"
   ```
5. Marcar todos los archivos del change con Estado: `archived`
6. Exportar snapshot de memoria:
   ```powershell
   .\cli\arnes-memory.ps1 export
   ```
7. Reportar a Atlas: change archivado con resumen

## Reglas

1. **Nada de archivar sin verify** — un change sin verify no existe (gate inalterable)
2. **Memoria final obligatoria** — el quest queda en arnes.db para siempre
3. **Grafo al dia** — las relaciones finales deben estar registradas
4. **Export JSONL** — snapshot portable para git/backup
5. **Actualizar docs** — si el change afecta documentacion, se refleja en docs/

## Criterios de "archived" (todo cumplido)

- [ ] verify PASS (o deuda documentada y aceptada)
- [ ] Quest registrado en arnes.db
- [ ] Memoria guardada (atlas/quest-history)
- [ ] Grafo actualizado
- [ ] JSONL exportado
