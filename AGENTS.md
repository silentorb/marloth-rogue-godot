# Agent notes — marloth

## Project

- **Engine**: Godot **4.6**, Forward Plus renderer, **Jolt** for 3D physics.
- **Entry**: `run/main_scene` is `res://main.tscn` (see `project.godot`).
- **Name / assembly**: Application id is `marloth`; `project.godot` sets `[dotnet]` `project/assembly_name` for C# when used.
- **C# modules**:
  - **`Marloth.Core`** — engine-agnostic logic; see [`src/Marloth.Core/`](src/Marloth.Core/).
  - **`Marloth.Client`** — Godot presentation and `GodotRpcHost`; see [`src/Marloth.Client/AGENTS.md`](src/Marloth.Client/AGENTS.md). Sources compile into the host assembly.
  - **`Marloth.Automation`** — in-process Godot playbook helpers; see [`src/Marloth.Automation/AGENTS.md`](src/Marloth.Automation/AGENTS.md).
  - **`Marloth.Automation.Contracts`** — gRPC/playbook contracts; see [`src/Marloth.Automation.Contracts/AGENTS.md`](src/Marloth.Automation.Contracts/AGENTS.md).
  - Root [marloth.csproj](marloth.csproj) is the Godot host and **compiles Client scripts into the main assembly** (Godot only resolves C# scripts from that assembly).

## Layout

- Open via [`marloth.code-workspace`](marloth.code-workspace) on **WSL/host** (File → Open Workspace from File…), then optionally **Reopen in Container**. Prefer the workspace file over opening the single folder.
- Primary game content lives at the marloth repo root (`project.godot`, scenes, scripts, assets).
- Sibling workspace folders (not build or runtime dependencies of marloth unless a task says otherwise):
  - **`unreal-marloth`** (reference only): Unreal **`Source/`** — Generation*, Modeling, SimulationGeneration, and related game modules. Use only when the task concerns legacy Unreal code; do not assume it is built or edited as part of this Godot tree.
  - **`unreal-marloth-plugins`** (reference only): Unreal **`Plugins/`** — Mythic, MythicTesting, UINavigation (and any future plugins mounted the same way). MythicSimulation is the main utility dependency for generation ports.
  - **`minimap`** (reference only): further-along 2D Godot project; extract applicable features and design/implementation patterns from it.
  - **`margen`**: engine-agnostic world generation library (Rust crates **`margen`** / **`mythic`**) plus a **C ABI** (`margen-ffi`); separate git tree—edit and commit there when work targets generation or mythic ports, not marloth.
  - **`margen-godot`**: GDExtension that converts margen datasets into Godot entities via the C ABI; separate git tree—edit and commit there when work targets the extension, not marloth.
- Those siblings use absolute host paths in [`marloth.code-workspace`](marloth.code-workspace). [`.devcontainer/devcontainer.json`](.devcontainer/devcontainer.json) and [`.devcontainer/docker-compose.yml`](.devcontainer/docker-compose.yml) bind-mount the same paths into the container (marloth repo at `..:/workspaces/marloth`, readonly Unreal Source/Plugins, writable margen siblings) so folders stay available after **Reopen in Container** (workspace entry alone is not enough inside the container).

## Conventions

- **Line endings:** Use **Unix (LF)** for all text in this repo. [`.gitattributes`](.gitattributes) enforces `eol=lf` on checkout/commit; [`.editorconfig`](.editorconfig) sets `end_of_line = lf`. The workspace and Dev Container set **`files.eol`** to `\n` in VS Code / Cursor so new files default to LF. If you create or edit files on Windows outside that setup, set the editor to LF (not CRLF) and avoid reintroducing `\r\n`; use `git add --renormalize .` if you need to fix a batch of files after changing `.gitattributes`.
- Prefer changing game logic and scenes in this repo; keep Godot editor–managed files (`*.tscn`, `project.godot`) consistent with how Godot serializes them.
- Match existing script language and style in the files you touch (GDScript vs C#).
- **`docs/game/game-design.md` is locked:** Do **not** create, edit, or delete that file unless the **user explicitly instructed** changes to it in the current conversation. Put secondary design detail in [docs/game/features/](docs/game/features/) instead. Reading it is fine; proposing edits without that instruction is not. See [`.cursor/rules/game-design-lock.mdc`](.cursor/rules/game-design-lock.mdc).
- **Bug regressions:** When fixing a user-reported bug the suite missed, add a regression test at the lowest sound layer—or escalate instead of brittle/flaky coverage. See [`.cursor/rules/bug-regression-tests.mdc`](.cursor/rules/bug-regression-tests.mdc) and [docs/technical/features/platform/testing.md](docs/technical/features/platform/testing.md) (**Bug regressions / debugging**).
- **Error handling:** Prefer explicit outcomes for expected failures; use exceptions only for truly exceptional cases or documented fail-fast abort boundaries. Non-trivial paths need a deliberate failure strategy. See [`.cursor/rules/error-handling.mdc`](.cursor/rules/error-handling.mdc) and [docs/technical/features/platform/error-handling.md](docs/technical/features/platform/error-handling.md).
- **Plans:** Every Cursor plan must include a dedicated **Testing** section and a **Commit strategy** (see [`.cursor/rules/plan-commit-workflow.mdc`](.cursor/rules/plan-commit-workflow.mdc)).
- **Offline dev:** Do not add runtime `curl`/`wget` download steps to scripts or tasks. Fetch tools and dependencies in **Dockerfiles** / image build only. See [`.cursor/rules/offline-container-downloads.mdc`](.cursor/rules/offline-container-downloads.mdc).
- **Native / margen:** Algorithms are Rust in the margen repo ([docs/rust-style.md](../margen/docs/rust-style.md)). Hosts consume the **C ABI**; margen-godot GDExtension sources remain C++ (godot-cpp).

## Environment

- The **dev container** installs **Godot .NET 4.6** (Linux) and sets **`GODOT_BIN`** (see [`.devcontainer/devcontainer.json`](.devcontainer/devcontainer.json)). WSLg + Mesa Dozen (Vulkan-on-D3D12) support GUI runs; use this for **testing** (headless Godot playbooks or the **Launch Godot editor** VS Code task). Automated layers: [docs/technical/features/platform/testing.md](docs/technical/features/platform/testing.md), layout: [tests/functional/README.md](tests/functional/README.md).
- **Offline policy:** Tool downloads happen in [`.devcontainer/Dockerfile`](.devcontainer/Dockerfile) and [`.devcontainer/Dockerfile.windows-cross`](.devcontainer/Dockerfile.windows-cross) only — not in repo scripts. See [`.cursor/rules/offline-container-downloads.mdc`](.cursor/rules/offline-container-downloads.mdc). Godot’s `.godot/` project cache is redirected to a compose volume (`marloth-godot-cache`) so it does not accumulate on the host bind mount.
- **Compose management:** From the WSL host, use [`scripts/devcontainer.sh`](scripts/devcontainer.sh) (`rebuild`, `up`, `exec`, …). Godot functional tests run in the **`marloth`** service; `./scripts/devcontainer.sh functional-tests` (and the VS Code task) works when attached (runs locally) or from the WSL host (compose exec).
- **Windows play:** compose service **`marloth-win`** ([`.devcontainer/Dockerfile.windows-cross`](.devcontainer/Dockerfile.windows-cross)) provides MinGW / Rust `windows-gnu` / .NET `win-x64` for cross-building a Windows play tree. From the WSL host:

  ```bash
  ./scripts/devcontainer.sh up marloth-win
  ./scripts/devcontainer.sh exec marloth-win ./scripts/build-windows.sh
  ```

  That syncs a playable tree to **`$MARLOTH_WIN_OUT`** (default `/mnt/e/dev/games/marloth-godot` → `E:\dev\games\marloth-godot`), including Windows margen DLLs and C# `win-x64` assemblies. Open that folder in **Windows Godot 4.6 .NET**. Cursor stays attached to the **`marloth`** service, not `marloth-win`.
- Do **not** spawn Windows Godot remotely from the Linux container (no HTTP launcher / remote client).

## Product and engineering docs

[`docs/`](docs/) is the **source of truth for functionality**. How that tree is split (game vs technical), how to read feature indexes, and the docs-win rule live in [docs/README.md](docs/README.md)—open that file when you need docs layout, not this one.
