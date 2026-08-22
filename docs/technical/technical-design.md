# Marloth technical design

# High-level requirements

- **Marloth** is a Godot game; Godot remains the underlying engine/runtime.
- C# is the primary programming language.
- Mostly developed by AI agents.
- Heavily requirements-driven, documented under the `./docs` directory. **`./docs` is the source of truth for functionality**: vision/pillars in `docs/game/game-design.md` (agents must not edit that file without explicit user instruction); secondary game rules under `docs/game/features/`; architecture and contracts under `docs/technical/`. Code and tests implement those documents. When behavior changes, update the docs in the same change (or first). If code and docs disagree, docs win and code is fixed.
- Heavily test-driven. Prefer unit tests where sound; use Godot play / manual checks when automation is not yet available. Tests verify **documented** requirements, not undocumented code quirks. User-reported gaps that the suite missed get a regression test when a sound one exists at the lowest practical layer; otherwise escalate rather than adding brittle or flaky coverage (see [features/platform/testing.md](features/platform/testing.md) **Bug regressions / debugging**).
- Prefer **explicit error outcomes** for expected failures; use **exceptions** only for truly exceptional cases or documented fail-fast abort boundaries (see [features/platform/error-handling.md](features/platform/error-handling.md)).
- No global state, except where needed for integration with Godot and third-party libraries.
- Prefer a clean separation between presentation (Godot scenes, input, rendering) and authoritative game logic when that split exists.

# Godot project layout

Directories used for Godot-related and project files today (not exhaustive):

| Directory / path | Purpose |
|------------------|---------|
| `./src` | C# libraries (e.g. `Marloth.Core`) |
| `./tests` | Test projects |
| `./main.tscn` | Entry / main scene (`run/main_scene`) |
| `project.godot` | Godot project settings |
| `marloth.csproj` | Godot host / main assembly |

Additional layout dirs (e.g. `assets/`, `scenes/`, `entities/`, `ui/`) may be added as content grows; document them here when they become standard.
