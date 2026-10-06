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
| **margen_ffi** | Same repo — crate `margen_ffi`, header `include/margen.h` | C ABI for engine hosts (story grid + **world-faces** / `RenderFace` export). |
| **margen-godot** | Sibling repo **`margen-godot`** | Godot GDExtension: `MargenWorldMesh` converts face datasets into `ArrayMesh` + placeholder materials via the C ABI. |
| **marloth** | This repo | Godot game; loads the extension from [`addons/margen/`](../../../../addons/margen/) and provides a debug scene. |

Detailed design and port roadmap: margen repo [`docs/overview.md`](../../../../margen/docs/overview.md), [`docs/story-graph.md`](../../../../margen/docs/story-graph.md), [`docs/winding-path.md`](../../../../margen/docs/winding-path.md), [`docs/sector-analysis.md`](../../../../margen/docs/sector-analysis.md), and [`docs/mythic.md`](../../../../margen/docs/mythic.md) (sibling workspace folder **`margen`**). Style: [`docs/rust-style.md`](../../../../margen/docs/rust-style.md).

## Story graph

Progression-first layout: abstract story DAG → spatial `CellGrid`. Player-facing intent: [story progression](../../game/features/gameplay/story-progression.md). Technical pipeline: margen [`docs/story-graph.md`](../../../../margen/docs/story-graph.md).

In Unreal reference, this path is toggled with `GENERATE_STORY`; the default path uses prefab start + winding-path growth and analysis-derived sectors. Both remain valid design options.

**Margen Stage 1–2 (structure):** `generate_story_graph` → `story_to_location_branching` → `story_to_clusters` → `rasterize_cluster_grid` (optional `connect_cluster_cells`, default off) via `generate_story_grid`; produces an expanded room-footprint `CellGrid` with spatial `BiomeDistribution` sampling when multiple biomes are configured.

**Margen production grid:** `generate_world_grid` (minimal prefab seed + `winding_path`) is ported; see margen [`docs/winding-path.md`](../../../../margen/docs/winding-path.md).

**Margen Stage 2 (analysis):** `partition_sectors` and `generate_goals` are ported in `margen_generation_graphing_analysis` (path-depth sector assignment and level-switch placement).

**Margen Surfacing + visible geometry:** `generate_render_faces` is ported in `margen_generation_surfacing`. The C ABI exposes **`margen_generate_world_faces`** (production `generate_world_grid` → face IR). **margen-godot** builds meshes via `MargenWorldMesh`; Marloth registers the extension under [`addons/margen/`](../../../../addons/margen/) and ships debug scene [`scenes/margen_world_debug.tscn`](../../../../scenes/margen_world_debug.tscn). The entry scene [`main.tscn`](../../../../main.tscn) instances that debug world until a real shell exists (F5 / Windows dist boot). Build the native library from **margen-godot** (`./scripts/build.sh`, then `./scripts/install-to-marloth.sh`) before opening the debug scene. For Windows outputs, from the attached marloth container run `./scripts/devcontainer.sh windows-dist` (packaged app → `$MARLOTH_WIN_OUT/dist`) or `windows-project` (editor tree → `$MARLOTH_WIN_OUT/project`); default parent is `/mnt/e/dev/games/marloth-godot`. File logging for PC runs goes to `logs/marloth.log` beside the project (editor) or dist dir.

### Debug scene contract (functional tests)

[`scenes/margen_world_debug.tscn`](../../../../scenes/margen_world_debug.tscn) uses:

| Property | Value |
|----------|-------|
| `seed` | `7` |
| `max_blocks` | `20` |
| `cell_size` | `(2, 2, 2)` |
| `auto_generate` | `true` |

Godot playbooks (via `./scripts/run_godot_functional_tests.sh`, which runs [`scripts/ensure-margen-natives.sh`](../../../../scripts/ensure-margen-natives.sh)):

| Playbook | Requirement |
|----------|-------------|
| `MargenExtensionLoaded` | `ClassDB.class_exists("MargenWorldMesh")` |
| `MargenWorldDebug` | After load + frames: `MeshInstance3D` at `MargenWorldMesh/MeshInstance3D` has a mesh with `surface_count > 0` and total `vertex_count` in **`[200, 4000]`** (inclusive). Calibrated observation on Godot 4.6 headless: **800** vertices across **3** surfaces for this seed/max_blocks. |

The vertex band is a functional tolerance (not bit-exact). Tighten the band in this doc and in `MargenWorldDebugPlaybook` if generation becomes more tightly specified. Lower-layer C ABI coverage remains in margen (`cargo test` / `ffi_world_faces_smoke`).

Windows-only load failures after Linux playbooks PASS: see [`addons/margen/README.md`](../../../../addons/margen/README.md) **Diagnosing load failures**.

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

The margen repo also has its own `.devcontainer` for Rust build/test; the marloth compose file includes a **`margen`** service for optional side-by-side work and a **`marloth-win`** service for Windows cross-compiles (HTTP build agent on the compose network; not the Cursor attach target).

## Build and test (margen)

From an environment with a Rust toolchain:

```bash
cargo test
cargo build -p margen_ffi --release
```

Run these commands in the **margen** repo root.

## Engine boundary

Margen outputs **datasets** (graphs, structure, surfaces, etc.). Integrators translate those into Godot or other engines at a **late** boundary—keeping generation deterministic and engine-agnostic—through the **C ABI**.
