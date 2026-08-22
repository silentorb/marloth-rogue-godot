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
- Sibling workspace folders (agent **reference only** — not build or runtime dependencies of marloth or the Dev Container):
  - **`unreal-marloth`**: legacy Unreal source. Use only when the task concerns it; do not assume it is built or edited as part of this Godot tree.
  - **`minimap`**: further-along 2D Godot project; extract applicable features and design/implementation patterns from it.
- Those siblings use absolute host paths in the workspace file. [`.devcontainer/devcontainer.json`](.devcontainer/devcontainer.json) bind-mounts the same paths into the container so the folders stay available after Reopen in Container (workspace entry alone is not enough inside the container).

## Conventions

- **Line endings:** Use **Unix (LF)** for all text in this repo. [`.gitattributes`](.gitattributes) enforces `eol=lf` on checkout/commit; [`.editorconfig`](.editorconfig) sets `end_of_line = lf`. The workspace and Dev Container set **`files.eol`** to `\n` in VS Code / Cursor so new files default to LF. If you create or edit files on Windows outside that setup, set the editor to LF (not CRLF) and avoid reintroducing `\r\n`; use `git add --renormalize .` if you need to fix a batch of files after changing `.gitattributes`.
- Prefer changing game logic and scenes in this repo; keep Godot editor–managed files (`*.tscn`, `project.godot`) consistent with how Godot serializes them.
- Match existing script language and style in the files you touch (GDScript vs C#).
- **`docs/game/game-design.md` is locked:** Do **not** create, edit, or delete that file unless the **user explicitly instructed** changes to it in the current conversation. Put secondary design detail in [docs/game/features/](docs/game/features/) instead. Reading it is fine; proposing edits without that instruction is not. See [`.cursor/rules/game-design-lock.mdc`](.cursor/rules/game-design-lock.mdc).
- **Bug regressions:** When fixing a user-reported bug the suite missed, add a regression test at the lowest sound layer—or escalate instead of brittle/flaky coverage. See [`.cursor/rules/bug-regression-tests.mdc`](.cursor/rules/bug-regression-tests.mdc) and [docs/technical/features/platform/testing.md](docs/technical/features/platform/testing.md) (**Bug regressions / debugging**).
- **Error handling:** Prefer explicit outcomes for expected failures; use exceptions only for truly exceptional cases or documented fail-fast abort boundaries. Non-trivial paths need a deliberate failure strategy. See [`.cursor/rules/error-handling.mdc`](.cursor/rules/error-handling.mdc) and [docs/technical/features/platform/error-handling.md](docs/technical/features/platform/error-handling.md).
- **Plans:** Every Cursor plan must include a dedicated **Testing** section and a **Commit strategy** (see [`.cursor/rules/plan-commit-workflow.mdc`](.cursor/rules/plan-commit-workflow.mdc)).

## Environment

- The **dev container** installs **Godot .NET 4.6** (Linux) and sets **`GODOT_BIN`** (see [`.devcontainer/devcontainer.json`](.devcontainer/devcontainer.json)). WSLg + Mesa Dozen (Vulkan-on-D3D12) support GUI runs; use this for **testing** (headless Godot playbooks or the **Launch Godot editor** VS Code task). Automated layers: [docs/technical/features/platform/testing.md](docs/technical/features/platform/testing.md), layout: [tests/functional/README.md](tests/functional/README.md).
- For day-to-day editor/play outside the container, use a separate **Windows clone** of the same repo and sync with **Git**.
- Do **not** spawn Windows Godot remotely from the container (no HTTP launcher / remote client).

## Product and engineering docs

[`docs/`](docs/) is the **source of truth for functionality**. How that tree is split (game vs technical), how to read feature indexes, and the docs-win rule live in [docs/README.md](docs/README.md)—open that file when you need docs layout, not this one.
