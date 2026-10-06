# Marloth technical design

# High-level requirements

- **Marloth** is a Godot game; Godot remains the underlying engine/runtime.
- C# is the primary programming language.
- Mostly developed by AI agents.
- Heavily requirements-driven, documented under the `./docs` directory. **`./docs` is the source of truth for functionality**: vision/pillars in `docs/game/game-design.md` (agents must not edit that file without explicit user instruction); secondary game rules under `docs/game/features/`; architecture and contracts under `docs/technical/`. Code and tests implement those documents. When behavior changes, update the docs in the same change (or first). If code and docs disagree, docs win and code is fixed.
- Heavily test-driven, using both **unit tests** and **functional tests**. Prefer unit tests for discrete contracts; use Core functional journeys and Godot playbooks for multi-step and client behavior (functional asserts may use **documented tolerance ranges**). Tests verify **documented** requirements, not undocumented code quirks. User-reported gaps that the suite missed get a regression test when a sound one exists at the lowest practical layer; otherwise escalate rather than adding brittle or flaky coverage (see [features/platform/testing.md](features/platform/testing.md) **Bug regressions / debugging**).
- Prefer **explicit error outcomes** for expected failures; use **exceptions** only for truly exceptional cases or documented fail-fast abort boundaries (see [features/platform/error-handling.md](features/platform/error-handling.md)).
- No global state, except where needed for integration with Godot and third-party libraries.
- Prefer a clean separation between presentation (Godot scenes, input, rendering) and authoritative game logic when that split exists.

# C# project boundaries

Details in each project’s `AGENTS.md`:

- **Marloth.Core** — engine-agnostic authoritative logic and contracts.
- **Marloth.Client** — Godot presentation, input, scene roots; automation RPC host (`GodotRpcHost`). Node scripts under this tree compile into the Godot host assembly.
- **Marloth.Automation** — in-process Godot helpers for playbooks (no Contracts).
- **Marloth.Automation.Contracts** — protobuf/gRPC wire protocol and `IPlaybook` types.

# Godot project layout

Directories used for Godot-related and project files today (not exhaustive):

| Directory / path | Purpose |
|------------------|
| `./src` | C# libraries (`Marloth.Core`, `Marloth.Client`, `Marloth.Automation`, `Marloth.Automation.Contracts`) |
| `./tests/unit` | Engine-agnostic unit tests |
| `./tests/functional` | Core functional journeys and Godot playbook automation |
| `./main.tscn` | Entry / main scene (`run/main_scene`); instances the margen debug world until a real shell exists |
| `./logs/` | Local Godot file logs (`logs/marloth.log`; configured in `project.godot`) |
| `project.godot` | Godot project settings |
| `marloth.csproj` | Godot host / main assembly |

Additional layout dirs (e.g. `assets/`, `scenes/`, `entities/`, `ui/`) may be added as content grows; document them here when they become standard.
