# Automated testing (unit and functional)

This project separates **authoritative game logic** (`Marloth.Core` and later Core-side libraries) from **Godot presentation** (`Marloth.Client`). Automated tests mirror that split: unit tests stay fast and engine-agnostic, while Godot functional tests run against a real Godot process and control it remotely over protobuf gRPC.

For background on architecture and directories, see [Technical design](../../technical-design.md).

## Frameworks and runners

- **xUnit + Microsoft.NET.Test.Sdk** for all test projects.
- **Godot functional automation** uses a runtime autoload node (`GodotRpcHost`) in `Marloth.Client` that hosts a gRPC server implementing contracts from `Marloth.Automation.Contracts`.
- Godot functional tests act as an RPC client. They load **playbook libraries** (managed DLLs) into the live process and run named **playbooks** in-process; the gRPC surface stays a thin control plane.

## Godot as subject-under-test

The Godot process is a **minimally modified** SUT, not a per-test custom build.

| Allowed | Not allowed |
|---------|-------------|
| **General** automation framework code in the normal game process (RPC host, playbook loader/registry, shared helpers) — dormant unless enabled (e.g. `MARLOTH_AUTOMATION_ENABLED`) | Building or configuring a **different** Godot process / project / scene set **per test case** |
| One shared headless launch of the **same** game binary/project for many tests | Baking test-case scenes, test runners, or case-specific scripts into the shipped Godot project as the primary model |
| After start, remotely commanding the process to **load specialized playbook libraries** and run named playbooks | Requiring GdUnit/Gut-style in-project test trees as the main approach |

Specialization lives in externally built playbook DLLs under `tests/`; the process under test stays one general automation-capable build.

## Repository layout

| Area | Typical location | References | Purpose |
|------|------------------|------------|---------|
| **Unit** | `tests/unit/` (`Marloth.Core.Tests`) | Core only | Discrete logic and contracts—no Godot runtime. |
| **Functional (simulation)** | `tests/functional/Marloth.Functional.Tests` | `Marloth.Core` only | Broader Core journeys with injected time. CI-friendly with `dotnet test` only. |
| **Functional (Godot playbooks)** | `tests/functional/Marloth.Functional.Godot.Playbooks` | Contracts + `Marloth.Automation` | One or more `IPlaybook` types per library; loaded into Godot after start. |
| **Functional (Godot client)** | `tests/functional/Marloth.Functional.Godot.Tests` | Contracts (gRPC client) | xUnit tests that launch Godot, `LoadPlaybookLibrary`, and `RunPlaybook`. |
| **Automation helpers** | `src/Marloth.Automation` | GodotSharp only | Standalone in-process helpers (process/physics frame wait, input push, scene lookup). No Contracts/playbook/test references. |
| **Automation contracts** | `src/Marloth.Automation.Contracts` | Protobuf/gRPC | Wire protocol + `IPlaybook` / `IPlaybookContext` / `PlaybookResult`. |

See also [tests/functional/README.md](../../../../tests/functional/README.md).

## Exact vs tolerance

- **Unit tests** assert **exact** discrete contracts: flags, counts, enums, integer ticks, and other values the docs specify without slack.
- **Functional tests** (Core journeys and Godot playbooks) may assert **within a documented tolerance range**. Floats, `Vector3` / rotations, speeds, remaining distances, Control rects, and physics poses are valid when the test names a tolerance (absolute, relative, or both) that matches the requirement.
- Same input + same tick/frame count + same `GODOT_BIN` build should land **inside that band** every run. If a run flaps across the band, the test is under-specified (widen the documented range, fix the product, or escalate)—do not silently add retries.
- Put the tolerance next to the requirement (feature doc and/or test comment). Shared helpers for within-range scalar/vector checks live under `tests/`, not in product assemblies.
- Control layout uses a **1px** epsilon; that is the UI instance of the same rule.

## 3D real-time limits

Push coverage as far as it stays **reproducible**. Do not pretend Jolt or the GPU are bit-exact.

**Prefer (exact)**

- Authoritative rules in Core with **injected time** (`Tick(dt)` / fixed `1/60`), seeded RNG, and discrete outcomes.
- Godot **scene lifecycle and tree shape**: current scene path, root name, required node paths.
- **Input routing**: held keys / `PushInput` → documented handlers, not pixels.
- Headless **process frames** for idle/UI; **physics frames** when the assertion is about physics stepping.

**Functional: reproducible within tolerance**

- Jolt / `CharacterBody3D` / rigid bodies: wait `PhysicsFrame`, then assert within range (height above floor, displacement after N ticks, angle within degrees). Discrete physics **events** (contact started, on-floor) remain first-class; they do not replace ranged pose checks.
- Same Godot **4.6** + Jolt build (Dev Container `GODOT_BIN`). Bit-identical physics across machines is **not** required; staying inside the published band on the Dev Container **is**.

**Do not automate (escalate / manual)**

- Rendering, shaders, lighting, particles, animation blend weights, audio, GPU/Vulkan, screenshots.
- Wall-clock timers, unconstrained `await Task.Delay`.
- Per-test Godot projects, GdUnit/Gut in-tree runners, or baking case scenes into the shipped project as the primary model.

When movement/combat exists, keep rules in Core (fixed ticks) and treat Jolt as presentation or a gated integration layer—not as the place unit tests live.

## Godot functional test flow

1. xUnit fixture starts `GODOT_BIN` with:
   - `MARLOTH_AUTOMATION_ENABLED=1`
   - `MARLOTH_AUTOMATION_HOST`
   - `MARLOTH_AUTOMATION_PORT`
2. Autoload `GodotRpcHost` starts gRPC server inside Godot.
3. Fixture calls `LoadPlaybookLibrary` with the path to a playbook DLL (multiple libraries supported; ids are `AssemblyName.PlaybookId`).
4. Each test calls `RunPlaybook` — assertions and scene/input orchestration run **inside** Godot in the playbook.
5. Fixture sends `Shutdown` and tears down process/channel.

## Commands

From repository root (after `dotnet restore`):

```bash
dotnet test tests/unit/Marloth.Core.Tests/Marloth.Core.Tests.csproj
dotnet test tests/functional/Marloth.Functional.Tests/Marloth.Functional.Tests.csproj
```

Godot client smoke (dev container sets `GODOT_BIN` automatically):

```bash
./scripts/run_godot_functional_tests.sh
```

Or equivalently (after building Automation + Playbooks + `marloth.csproj`):

```bash
dotnet test tests/functional/Marloth.Functional.Godot.Tests/Marloth.Functional.Godot.Tests.csproj
```

Outside the container, export `GODOT_BIN` to a Godot 4.6 .NET executable first. If `GODOT_BIN` is not set, run only unit + simulation functional suites.

## Bug regressions / debugging

Debugging should be as test-driven as practical. When a **user-reported bug** was not caught by the suite, a regression test is part of the fix—unless a sound test is not available.

### Workflow

1. Reproduce the failure (manually or via a new failing test).
2. Prefer a **failing test first** at the **lowest layer** that can express the bug.
3. Fix product code; keep the test; leave it in the suite.
4. Assert **documented** requirements (feature docs / [technical design](../../technical-design.md)). If the bug reveals missing documented behavior, update the docs in the same change and test against that—not against undocumented quirks.

### Layer choice

| Prefer | When |
|--------|------|
| **Unit** (`tests/unit/`) | Pure logic, discrete contracts—no Godot runtime. |
| **Simulation functional** | Multi-step Core journeys still without Godot, including ranged float/vector asserts. |
| **Godot playbook** | Scene lifecycle, input routing, UI layout, or other client-only behavior (poses/events within documented tolerances). |

### Escalate instead of a bad test

Stop and discuss with the user (do **not** quietly ship weak coverage) when a reproduction would require:

- Hacking or expanding general testing harnesses beyond the fix
- Likely **brittle** assertions (e.g. parsing project XML, depending on ambient build artifacts)
- Likely **flaky**, **hanging**, or **non-deterministic** behavior (including functional asserts that flap across their published band)
- Deliberately breaking the SUT environment in ways happy-path automation does not support cleanly

Then the user can choose: skip the test for this bug, invest in harness work, or redesign code for testability.

Agent rule: [`.cursor/rules/bug-regression-tests.mdc`](../../../../.cursor/rules/bug-regression-tests.mdc).

## Related docs

| Topic | Document |
|-------|----------|
| Presentation vs logic, `./tests` in tree | [Technical design](../../technical-design.md) |
| Automation RPC Ok/Error | [Error handling](error-handling.md) |
| Gameplay vision (not test mechanics) | [Game design](../../game/game-design.md) |
