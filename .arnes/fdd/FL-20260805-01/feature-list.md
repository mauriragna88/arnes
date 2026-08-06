# Feature List — Sistema de Login

> **FDD List ID**: `FL-20260805-01`
> **Fecha**: 2026-08-05
> **Autor**: Usuario + Atlas
> **Estado**: `active`

---

## Objetivo del Feature Set

Sistema de autenticación completo para el proyecto: login, password reset y dashboard
post-login. Cada feature es entregable independiente.

## Features (ordenadas por prioridad/valor)

| # | Feature | Prioridad | Tamaño | Depende de | Estado |
|---|---|---|---|---|---|
| F1 | Login Form con Zod | Alta | M | — | done |
| F2 | Password Reset | Media | S | F1 | done |
| F3 | Dashboard post-login | Media | M | F1 | pending |
| F4 | Session timeout + refresh | Alta | S | F1 | pending |

## Reglas de la lista

1. Cada feature es independientemente entregable
2. Tamaños: S = <1 quest, M = 1-2 quests, L = 3+ (subdividir)
3. Orden: F1 desbloquea a las demás
4. Al completarse: `done` → se archiva su plan individual

## Progreso

- [x] F1 — Login Form con Zod (done)
- [x] F2 — Password Reset (done)
- [ ] F3 — Dashboard post-login (pending)
- [ ] F4 — Session timeout + refresh (pending)

---
*Memoria: al crear/actualizar, guardar en arnes.db `atlas/quest-history`*
