# World generation (margen stack)

Marloth’s procedural worlds will come from the **margen** stack: engine-agnostic generation in **Rust**, **mythic** utility crates in the same repo, a **C ABI** (`margen_ffi` / `include/margen.h`), and a **margen-godot** GDExtension when Godot needs meshes and scenes. Legacy Unreal code remains **read-only reference** in the workspace—not a build dependency of the Godot game.

For Marloth-specific glue (when generation is wired into scenes), prefer this repo’s game code (likely **C#** P/Invoke or the GDExtension) and docs; do not put algorithms in margen-godot.

See also [Technical design](../../technical-design.md) for presentation vs logic boundaries.

## Ownership

| Piece | Repo / crate | Role |
|-------|--------------|------|
| **mythic_*** | sibling repo **`margen`** — `mythic_math`, `mythic_dice`, `mythic_distribution` | General utilities from Unreal **MythicSimulation**. **Not** world generation. |
| **margen_generation** | Same repo | Core types, biomes, spatial `BiomeDistribution`. |
| **margen_generation_graphing** | Same repo | Story DAG, branching, `sectors_to_dag`. |
| **margen_generation_structure** | Same repo | Clusters, story → expanded `CellGrid`, prefab-seed `windingPath` / `generate_world_grid`. |
| **margen_generation_graphing_analysis** | Same repo | `partition_sectors`, `generate_goals`. |
| **margen_ffi** | Same repo — crate `margen_ffi`, header `include/margen.h` | C ABI for engine hosts (story-grid today). |
| **margen-godot** | Sibling repo **`margen-godot`** | Godot GDExtension: convert margen **output datasets** into engine types via the C ABI. No generation algorithms here. |
| **marloth** | This repo | Godot game, C# Core/Client, and future **integrator** code that calls margen (via the extension and/or P/Invoke). |

Detailed design and port roadmap: margen repo [`docs/overview.md`](../../../../margen/docs/overview.md), [`docs/story-graph.md`](../../../../margen/docs/story-graph.md), [`docs/winding-path.md`](../../../../margen/docs/winding-path.md), [`docs/sector-analysis.md`](../../../../margen/docs/sector-analysis.md), and [`docs/mythic.md`](../../../../margen/docs/mythic.md) (sibling workspace folder **`margen`**). Style: [`docs/rust-style.md`](../../../../margen/docs/rust-style.md).

## Story graph

Progression-first layout: abstract story DAG → spatial `CellGrid`. Player-facing intent: [story progression](../../game/features/gameplay/story-progression.md). Technical pipeline: margen [`docs/story-graph.md`](../../../../margen/docs/story-graph.md).

In Unreal reference, this path is toggled with `GENERATE_STORY`; the default path uses prefab start + winding-path growth and analysis-derived sectors. Both remain valid design options.

**Margen Stage 1–2 (structure):** `generate_story_graph` → `story_to_location_branching` → `story_to_clusters` → `rasterize_cluster_grid` (optional `connect_cluster_cells`, default off) via `generate_story_grid`; produces an expanded room-footprint `CellGrid` with spatial `BiomeDistribution` sampling when multiple biomes are configured.

**Margen production grid:** `generate_world_grid` (minimal prefab seed + `winding_path`) is ported; see margen [`docs/winding-path.md`](../../../../margen/docs/winding-path.md).

**Margen Stage 2 (analysis):** `partition_sectors` and `generate_goals` are ported in `margen_generation_graphing_analysis` (path-depth sector assignment and level-switch placement). The C ABI still exposes story-grid generation only; Godot integration is not yet wired.

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

The margen repo also has its own `.devcontainer` for Rust build/test; the marloth compose file includes a **`margen`** service for optional side-by-side work.

## Build and test (margen)

From an environment with a Rust toolchain:

```bash
cargo test
cargo build -p margen_ffi --release
```

Run these commands in the **margen** repo root.

## Engine boundary

Margen outputs **datasets** (graphs, structure, surfaces, etc.). Integrators translate those into Godot or other engines at a **late** boundary—keeping generation deterministic and engine-agnostic—through the **C ABI**.
