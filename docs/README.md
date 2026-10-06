# Documentation

This directory holds material for humans and for AI agents: deeper notes than fit in the always-loaded [AGENTS.md](../AGENTS.md) at the repo root.

Start from **AGENTS.md** for project defaults (engine, workspace, conventions). Open files under `docs/` only when a task needs that context.

**`./docs` is the source of truth for functionality.** Code and tests implement these documents. When behavior changes, update the docs in the same change (or first). If code and docs disagree, docs win and code is fixed.

## Layout

| Path | Contents |
|------|----------|
| [game/](game/) | Game vision, pillars, and **game** feature notes (`game/features/`). |
| [technical/](technical/) | Engineering architecture, tooling, and **technical** feature notes (`technical/features/`). |

## Division of requirements

- **Game** — player-facing vision, feel, and rules. High-level pillars live in [game/game-design.md](game/game-design.md) (locked for agents unless the user explicitly instructs edits). Secondary design under [game/features/](game/features/).
- **Technical** — architecture, contracts, and how systems are built and tested. Overview in [technical/technical-design.md](technical/technical-design.md). Feature contracts under [technical/features/](technical/features/).
- **Paired features** — when a gameplay/UI/session topic exists, prefer a game doc for *what players experience* and a technical doc for *APIs/contracts/implementation*.

Entry points:

- [game/game-design.md](game/game-design.md) — vision and primary pillars (locked; do not edit without explicit user instruction)
- [game/features/README.md](game/features/README.md) — game **features index** (secondary design / player-facing rules)
- [technical/technical-design.md](technical/technical-design.md) — architecture, Rust authority, TDD, presentation vs logic, Godot layout
- [technical/features/README.md](technical/features/README.md) — technical **features index** (contracts / implementation)

[game/scoping/](game/scoping/) is for human brainstorming; it is not intended for AI agents.

## Feature catalogs (read on demand)

Do **not** preload this tree for routine tasks. Skim the trigger tables in the feature indexes, then read **only** the matching file(s).

Feature docs are grouped under `ui/`, `gameplay/`, `session/`, and `platform/` (create a group directory when the first file lands there). **`platform/`** under technical features holds cross-cutting engineering policy (error handling, testing).

- [Game features](game/features/README.md)
- [Technical features](technical/features/README.md)
- Testing / bug regressions: [technical/features/platform/testing.md](technical/features/platform/testing.md)
- Error handling: [technical/features/platform/error-handling.md](technical/features/platform/error-handling.md)
