# Functional tests

Core-focused flows live in **`Marloth.Functional.Tests`** (`Marloth.Core` only). They run under plain `dotnet test` with no Godot executable. Journeys may assert **within documented tolerance ranges** for floats and vectors; put the band next to the requirement. Shared helper: `WithinRange` in that project (not in product assemblies).

Godot client functional tests live in **`Marloth.Functional.Godot.Tests`**. They launch a **minimally modified** headless Godot process (general automation host only), then remotely load **playbook libraries** and run named **playbooks** inside that process via protobuf gRPC (`GodotRpcHost`).

Playbook implementations live in **`Marloth.Functional.Godot.Playbooks`** (and additional libraries as needed). Shared in-process helpers are in **`Marloth.Automation`** (independent of Contracts and tests).

## Godot as subject-under-test

- One shared game process/project for many tests — not a different Godot build per case.
- General framework code (RPC host, loader, helpers) may ship in the normal binary but stays dormant unless `MARLOTH_AUTOMATION_ENABLED` is set.
- Per-case specialization is loaded **after** start (`LoadPlaybookLibrary` / `RunPlaybook`).

## Godot functional prerequisites

- Set **`GODOT_BIN`** to a Godot 4.x .NET executable that this environment can run. The **dev container** sets this automatically to the installed Linux binary.
- Optional: set **`MARLOTH_AUTOMATION_PORT`** to force a fixed gRPC port (otherwise tests auto-pick a free local port).

From repo root (in the dev container, `GODOT_BIN` is already set):

```bash
./scripts/run_godot_functional_tests.sh
```

That script builds `Marloth.Automation`, playbook libraries, and `marloth.csproj`, then runs the Godot xUnit suite.

Or invoke directly (after those builds):

```bash
dotnet test tests/functional/Marloth.Functional.Godot.Tests/Marloth.Functional.Godot.Tests.csproj
```

Run everything that does **not** need Godot locally or in CI:

```bash
dotnet test tests/unit/Marloth.Core.Tests/Marloth.Core.Tests.csproj
dotnet test tests/functional/Marloth.Functional.Tests/Marloth.Functional.Tests.csproj
```

See [docs/technical/features/platform/testing.md](../../docs/technical/features/platform/testing.md) for the full testing overview (including 3D determinism and tolerance policy).
