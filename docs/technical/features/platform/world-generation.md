# World generation (margen stack)

Marloth’s procedural worlds will come from the **margen** stack: engine-agnostic generation in C++, optional **mythic** utilities in the same repo, and a **margen-godot** GDExtension when Godot needs meshes and scenes. Legacy Unreal code remains **read-only reference** in the workspace—not a build dependency of the Godot game.

For Marloth-specific glue (when generation is wired into scenes), prefer this repo’s game code and docs; do not put algorithms in margen-godot.

See also [Technical design](../../technical-design.md) for presentation vs logic boundaries.

## Ownership

| Piece | Repo / namespace | Role |
|-------|------------------|------|
| **mythic** | sibling repo **`margen`** — `mythic::`, CMake target `mythic::mythic` | General utilities ported from Unreal **MythicSimulation** (`Dice`, `Vector3i`, `InlineVector`, `FixedArray`, …). **Not** world generation. |
| **margen** | Same repo — `margen::`, CMake target `margen::margen` | World generation (Stage 0 graphing + Stage 1 core types and story → `CellGrid`). Links **mythic** publicly. |
| **margen-godot** | Sibling repo **`margen-godot`** | Godot GDExtension: convert margen **output datasets** into engine types. No generation algorithms here. |
| **marloth** | This repo | Godot game, C# Core/Client, and future **integrator** code that calls margen (directly or via the extension). |

Detailed design and port roadmap: margen repo [`docs/overview.md`](../../../../margen/docs/overview.md), [`docs/story-graph.md`](../../../../margen/docs/story-graph.md), and [`docs/mythic.md`](../../../../margen/docs/mythic.md) (sibling workspace folder **`margen`**).

## Story graph

Progression-first layout: abstract story DAG → spatial `CellGrid`. Player-facing intent: [story progression](../../game/features/gameplay/story-progression.md). Technical pipeline: margen [`docs/story-graph.md`](../../../../margen/docs/story-graph.md).

In Unreal reference, this path is toggled with `GENERATE_STORY`; the default path uses prefab start + winding-path growth and analysis-derived sectors. Both remain valid design options.

**Margen Stage 1 (current):** `generateStoryGraph` → `storyToLocationBranching` → `storyToClusters` via `generateStoryGrid`; produces a sparse tagged `CellGrid`. Cluster rasterization and Godot integration are not yet wired.

## Unreal reference folders (read-only)

Do **not** mount the full Unreal project root into the dev container (avoids mixing `Content/` with code). Use two workspace folders:

| Workspace name | Host path | Contents |
|----------------|-----------|----------|
| **`unreal-marloth`** | `/mnt/e/dev/games/marloth/Source` | Generation*, Modeling, SimulationGeneration, … (~10 generation-related modules). |
| **`unreal-marloth-plugins`** | `/mnt/e/dev/games/marloth/Plugins` | **Mythic**, **MythicTesting**, **UINavigation** (only these three plugins today). |

When citing Unreal sources in ports or reviews, prefer paths under **`unreal-marloth-plugins/Mythic/...`** for MythicSimulation and **`unreal-marloth/Generation...`** for generation modules.

## Dev environment mounts

[`marloth.code-workspace`](../../../../marloth.code-workspace) lists all sibling folders. Inside the dev container, the same paths are bind-mounted via:

- [`.devcontainer/devcontainer.json`](../../../../.devcontainer/devcontainer.json) — `workspaceFolder` `/workspaces/marloth`, readonly Plugins mount
- [`.devcontainer/docker-compose.yml`](../../../../.devcontainer/docker-compose.yml) — `..:/workspaces/marloth`, plus readonly Source/Plugins and writable margen / margen-godot

The margen repo also has its own `.devcontainer` for C++ build/test; the marloth compose file includes a **`margen`** service for optional side-by-side work.

## Build and test (margen)

From a Linux environment with CMake, Ninja, and a C++ toolchain:

```bash
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Debug
cmake --build build
ctest --test-dir build --output-on-failure
```

Run these commands in the **margen** repo root. Tests use **Catch2** (`tests/mythic/`, `tests/margen/`).

## Engine boundary

Margen outputs **datasets** (graphs, structure, surfaces, etc.). Integrators translate those into Godot or other engines at a **late** boundary—keeping generation deterministic and engine-agnostic.
