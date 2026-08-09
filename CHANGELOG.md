# Changelog

Todos los cambios relevantes de ARNES ARGOS se registran en este archivo.

## [Unreleased]

### Corregido

- Se serializó la sincronización de `argos` con un mutex nombrado para evitar colisiones entre
  dos procesos que actualizan los agentes de OpenCode al mismo tiempo.
- La aplicación de modelos dejó de reescribir archivos de agentes cuando el contenido generado
  es idéntico al existente, reduciendo el tiempo de arranque repetido.

### Documentación

- Se aclaró el estado actual del proyecto y la separación entre capacidades implementadas y
  roadmap.
- Se añadió la guía técnica de arranque, contribución y diagnóstico para GitHub.

## Historial

Las funcionalidades anteriores están descritas en `README.md`, `docs/PLAN-ARNES.md` y
`docs/WHAT-IS-LEFT.md`. Las versiones publicadas se añadirán aquí cuando exista un release.
