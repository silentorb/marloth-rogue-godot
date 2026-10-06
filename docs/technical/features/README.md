# Technical feature docs (read on demand)

**Source of truth** for architecture and engineering contracts. **Do not** open every file for general tasks.

Feature docs are grouped under `ui/`, `gameplay/`, `session/`, and `platform/` (create a group directory when the first feature file lands there). **`platform/`** holds cross-cutting engineering policy.

1. Skim the **trigger** lines below.
2. If a trigger matches your current task, read **only** that markdown file (and linked paths as needed).

When a topic has both player-facing rules and engineering contracts, keep contracts here and player-facing requirements under [game features](../../game/features/README.md).

| File | Read when… |
|------|------------|
| [platform/error-handling.md](platform/error-handling.md) | Adding or changing **APIs**, loaders, boot paths, or any **multi-step** logic where failures must be chosen (throw vs explicit outcome vs abort). |
| [platform/testing.md](platform/testing.md) | Working on **automated tests**: unit vs functional layout, **`cargo test`**, protobuf gRPC Godot **playbooks**, **Godot-dependent** tests (`GODOT_BIN`), **3D determinism** / functional **tolerance ranges**, or **bug-driven regression** policy (failing test first / escalate brittle coverage). |
| [platform/world-generation.md](platform/world-generation.md) | **World generation** ownership (**mythic** vs **margen** vs **margen-godot**), **story graph** vs winding path, Unreal **Source/** vs **Plugins/** reference folders, devcontainer mounts, or porting from **`unreal-marloth`** / **`unreal-marloth-plugins`**. |
| [platform/sim-authority.md](platform/sim-authority.md) | Where **new gameplay** belongs (`marloth_sim`), thin scene tree, bulk client/services sync. |
| [../../game/features/gameplay/story-progression.md](../../game/features/gameplay/story-progression.md) | **Story progression** player flow, gating/backtracking design, or future narrative layers on the generation DAG. |
| [../technical-design.md](../technical-design.md) | **Architecture**, docs-as-SoT, presentation vs logic boundaries, **Godot directory layout**, or TDD intent. |
| [../../game/game-design.md](../../game/game-design.md) | Reading **gameplay vision** or high-level feel. **Do not edit** unless the user explicitly instructed changes to that file. |

*(Add rows as technical feature docs are written.)*
