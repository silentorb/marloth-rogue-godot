# World generation (margen stack)

Marloth’s procedural worlds will come from the **margen** stack: engine-agnostic generation in C++, optional **mythic** utilities in the same repo, and a **margen-godot** GDExtension when Godot needs meshes and scenes. Legacy Unreal code remains **read-only reference** in the workspace—not a build dependency of the Godot game.

For Marloth-specific glue (when generation is wired into scenes), prefer this repo’s game code and docs; do not put algorithms in margen-godot.

See also [Technical design](../../technical-design.md) for presentation vs logic boundaries.

## Ownership

| Piece | Repo / namespace | Role |
|-------|------------------|------|
| **mythic** | sibling repo **`margen`** — `mythic::`, CMake target `mythic::mythic` | General utilities ported from Unreal **MythicSimulation** (`Dice`, `Vec3i`, `InlineVector`, `FixedArray`, …). **Not** world generation. |
| **margen** | Same repo — `margen::`, CMake target `margen::margen` | World generation only (Session 0: **GenerationGraphing** — DAG, story, location branching). Links **mythic** publicly. |
| **margen-godot** | Sibling repo **`margen-godot`** | Godot GDExtension: convert margen **output datasets** into engine types. No generation algorithms here. |
| **marloth** | This repo | Godot game, C# Core/Client, and future **integrator** code that calls margen (directly or via the extension). |

Detailed design and port roadmap: margen repo `docs/overview.md` and `docs/mythic.md` (sibling workspace folder **`margen`**).

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

From a Linux environment with CMake and a C++ toolchain:

```bash
cmake -S . -B build -G "Unix Makefiles" -DCMAKE_BUILD_TYPE=Debug
cmake --build build
ctest --test-dir build --output-on-failure
```

Run these commands in the **margen** repo root. Tests use **Catch2** (`tests/mythic/`, `tests/margen/`).

## Engine boundary

Margen outputs **datasets** (graphs, structure, surfaces, etc.). Integrators translate those into Godot or other engines at a **late** boundary—keeping generation deterministic and engine-agnostic.
