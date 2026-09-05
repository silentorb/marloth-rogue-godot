# Functional tests

Core-focused flows live in **`Marloth.Functional.Tests`** (`Marloth.Core` only). They run under plain `dotnet test` with no Godot executable. Journeys may assert **within documented tolerance ranges** for floats and vectors; put the band next to the requirement. Shared helper: `WithinRange` in that project (not in product assemblies).

Godot client functional tests live in **`Marloth.Functional.Godot.Tests`**. They launch a **minimally modified** headless Godot process (general automation host only), then remotely load **playbook libraries** and run named **playbooks** inside that process via protobuf gRPC (`GodotRpcHost`).

Playbook implementations live in **`Marloth.Functional.Godot.Playbooks`** (and additional libraries as needed). Shared in-process helpers are in **`Marloth.Automation`** (independent of Contracts and tests).

## Godot as subject-under-test

- One shared game process/project for many tests — not a different Godot build per case.
- General framework code (RPC host, loader, helpers) may ship in the normal binary but stays dormant unless `MARLOTH_AUTOMATION_ENABLED` is set.
- Per-case specialization is loaded **after** start (`LoadPlaybookLibrary` / `RunPlaybook`).

## Godot functional prerequisites

**Requires the `marloth` dev container** (Dev Containers: Reopen in Container). There is no WSL-host or `marloth-win` fallback — if `GODOT_BIN` is missing, fix the environment instead of routing elsewhere.

- **`GODOT_BIN`** — set automatically in the dev container to the installed Linux Godot 4.x .NET binary (`/opt/godot/...`).
- Optional: **`MARLOTH_AUTOMATION_PORT`** to force a fixed gRPC port (otherwise tests auto-pick a free local port).
- **margen GDExtension:** Linux natives under `addons/margen/bin/` (`libmargen_godot.linux.template_debug.x86_64.so` + `libmargen_ffi.so`). [`scripts/run_godot_functional_tests.sh`](../../scripts/run_godot_functional_tests.sh) calls [`scripts/ensure-margen-natives.sh`](../../scripts/ensure-margen-natives.sh), which builds/installs from `$MARGEN_GODOT_ROOT` when missing.

From repo root in the **marloth** dev container:

```bash
./scripts/run_godot_functional_tests.sh
```

Or the same entry point the VS Code task uses (works **attached** or from the **WSL host**):

```bash
./scripts/devcontainer.sh functional-tests
```

When already attached, that runs the test script locally. From the WSL host it starts **`marloth`** if needed and execs the test script there. No host fallback inside the test script itself.

If Godot or dotnet is missing in the image, rebuild once:

```bash
./scripts/devcontainer.sh rebuild marloth
```

Then **Dev Containers: Rebuild and Reopen in Container** if you use attach for editing.

That script ensures margen natives, builds `Marloth.Automation`, playbook libraries, and `marloth.csproj`, then runs the Godot xUnit suite (including `MainSceneBootstrap` and margen playbooks). See [`.cursor/rules/offline-container-downloads.mdc`](../../.cursor/rules/offline-container-downloads.mdc).

Or invoke directly (after those builds and natives):

```bash
dotnet test tests/functional/Marloth.Functional.Godot.Tests/Marloth.Functional.Godot.Tests.csproj
```

Run everything that does **not** need Godot locally or in CI:

```bash
dotnet test tests/unit/Marloth.Core.Tests/Marloth.Core.Tests.csproj
dotnet test tests/functional/Marloth.Functional.Tests/Marloth.Functional.Tests.csproj
```

See [docs/technical/features/platform/testing.md](../../docs/technical/features/platform/testing.md) for the full testing overview (including 3D determinism and tolerance policy), and [addons/margen/README.md](../../addons/margen/README.md) for margen diagnostics.
