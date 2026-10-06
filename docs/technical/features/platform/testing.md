# Automated testing (unit and functional)

This project separates **authoritative game logic** (`marloth_sim`) from **Godot presentation** (client role + services). Automated tests mirror that split: unit tests stay fast and engine-agnostic, while Godot functional tests run against a real Godot process and control it remotely over protobuf gRPC.

For background on architecture and directories, see [Technical design](../../technical-design.md).

## Frameworks and runners

- **`cargo test`** for `marloth_sim` (and other native crates) unit tests.
- **Godot functional automation** uses `MarlothAutomationHost` (GDExtension) which starts a tonic gRPC server when `MARLOTH_AUTOMATION_ENABLED` is set. Built-in playbooks live in `marloth_automation`.
- The Rust **godot_driver** (`tests/functional/godot_driver`) is the gRPC client: it launches headless Godot and runs named playbooks.

## Godot as subject-under-test

The Godot process is a **minimally modified** SUT, not a per-test custom build.

| Allowed | Not allowed |
|---------|-------------|
| **General** automation framework code in the normal game process (RPC host, playbook registry, shared helpers) — dormant unless enabled (e.g. `MARLOTH_AUTOMATION_ENABLED`) | Building or configuring a **different** Godot process / project / scene set **per test case** |
| One shared headless launch of the **same** game binary/project for many tests | Baking test-case scenes, test runners, or case-specific scripts into the shipped Godot project as the primary model |
| After start, remotely commanding the process to run named playbooks | Requiring GdUnit/Gut-style in-project test trees as the main approach |

Specialization lives in built-in playbooks inside `marloth_automation`; the process under test stays one general automation-capable build.

## Repository layout

| Area | Typical location | Purpose |
|------|------------------|---------|
| **Unit (sim)** | `native/crates/marloth_sim` (`cargo test -p marloth_sim`) | Discrete logic—no Godot runtime. |
| **Functional (Godot driver)** | `tests/functional/godot_driver` | Spawns Godot, tonic client, asserts playbook Ok. |
| **Playbooks** | `native/crates/marloth_automation` | Built-in playbook ids (`MainSceneBootstrap`, `MargenExtensionLoaded`, `MargenWorldDebug`, `MarlothSimHostLoaded`). |
| **Automation host** | `MarlothAutomationHost` GDExtension + autoload scene | gRPC server + main-thread poll. |
| **Functional (GDExtension)** | Same playbook stack | Extension load, ClassDB, mesh handoff — see [world-generation.md](world-generation.md). |

See also [tests/functional/README.md](../../../../tests/functional/README.md).

## Exact vs tolerance

- **Unit tests** assert **exact** discrete contracts: flags, counts, enums, integer ticks, and other values the docs specify without slack.
- **Functional tests** (Godot playbooks) may assert **within a documented tolerance range**. Floats, `Vector3` / rotations, speeds, remaining distances, Control rects, and physics poses are valid when the test names a tolerance (absolute, relative, or both) that matches the requirement.
- Same input + same tick/frame count + same `GODOT_BIN` build should land **inside that band** every run. If a run flaps across the band, the test is under-specified (widen the documented range, fix the product, or escalate)—do not silently add retries.
- Put the tolerance next to the requirement (feature doc and/or test comment).

## 3D real-time limits

Push coverage as far as it stays **reproducible**. Do not pretend Jolt or the GPU are bit-exact.

**Prefer (exact)**

- Authoritative rules in `marloth_sim` with **injected time** (`step` / fixed `1/60`), seeded RNG, and discrete outcomes.
- Godot **scene lifecycle and tree shape**: current scene path, root name, required node paths.
- **Input routing**: bulk input frames → documented handlers, not pixels.
- Headless **process frames** for idle/UI; **physics frames** when the assertion is about physics stepping.

**Functional: reproducible within tolerance**

- Jolt / `CharacterBody3D` / rigid bodies: wait frames, then assert within range. Discrete physics **events** remain first-class; they do not replace ranged pose checks.
- Same Godot **4.6** + Jolt build (Dev Container `GODOT_BIN`). Bit-identical physics across machines is **not** required; staying inside the published band on the Dev Container **is**.

**Do not automate (escalate / manual)**

- Rendering, shaders, lighting, particles, animation blend weights, audio, GPU/Vulkan, screenshots.
- Wall-clock timers, unconstrained sleeps as the primary sync mechanism.
- Per-test Godot projects, GdUnit/Gut in-tree runners, or baking case scenes into the shipped project as the primary model.

When movement/combat exists, keep rules in `marloth_sim` (fixed ticks) and treat Jolt as presentation or a gated integration layer—not as the place unit tests live.

## Godot functional test flow

1. Driver starts `GODOT_BIN` with:
   - `MARLOTH_AUTOMATION_ENABLED=1`
   - `MARLOTH_AUTOMATION_HOST`
   - `MARLOTH_AUTOMATION_PORT`
2. Autoload `MarlothAutomationHost` starts gRPC server inside Godot.
3. Each test calls `RunPlaybook` — assertions and scene/input orchestration run **inside** Godot in the playbook.
4. Driver sends `Shutdown` and tears down process/channel.

## Commands

From repository root:

```bash
cd native && cargo test -p marloth_sim
```

Godot client smoke (**marloth** dev container only; `GODOT_BIN` is set automatically):

```bash
./scripts/run_godot_functional_tests.sh
```

Outside the dev container, run only sim unit tests (no Godot playbooks).

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
| **Unit** (`cargo test -p marloth_sim`) | Pure logic, discrete contracts—no Godot runtime. |
| **Godot playbook** | Scene lifecycle, input routing, UI layout, or other client-only behavior (poses/events within documented tolerances). |
| **Godot playbook (GDExtension)** | Extension load / ClassDB / mesh handoff (margen + marloth natives required). |

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
| Presentation vs logic, native layout | [Technical design](../../technical-design.md) |
| Automation RPC Ok/Error | [Error handling](error-handling.md) |
| Gameplay vision (not test mechanics) | [Game design](../../game/game-design.md) |
