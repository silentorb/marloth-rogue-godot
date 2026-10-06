# Marloth technical design

# High-level requirements

- **Marloth** is a Godot game; Godot remains the underlying engine/runtime.
- **Rust** is the primary language for authoritative game logic (`marloth_sim`). **C++** is used only for GDExtension glue (godot-cpp). **GDScript** is allowed only where Godot is awkward without it.
- Mostly developed by AI agents.
- Heavily requirements-driven, documented under the `./docs` directory. **`./docs` is the source of truth for functionality**: vision/pillars in `docs/game/game-design.md` (agents must not edit that file without explicit user instruction); secondary game rules under `docs/game/features/`; architecture and contracts under `docs/technical/`. Code and tests implement those documents. When behavior changes, update the docs in the same change (or first). If code and docs disagree, docs win and code is fixed.
- Heavily test-driven, using both **unit tests** (`cargo test` on sim crates) and **functional tests** (Godot playbooks over gRPC). Prefer unit tests for discrete contracts; use Godot playbooks for multi-step and client behavior (functional asserts may use **documented tolerance ranges**). Tests verify **documented** requirements, not undocumented code quirks. User-reported gaps that the suite missed get a regression test when a sound one exists at the lowest practical layer; otherwise escalate rather than adding brittle or flaky coverage (see [features/platform/testing.md](features/platform/testing.md) **Bug regressions / debugging**).
- Prefer **explicit error outcomes** for expected failures; use **exceptions / fail-fast** only for truly exceptional cases or documented abort boundaries (see [features/platform/error-handling.md](features/platform/error-handling.md)).
- No global state, except where needed for integration with Godot and third-party libraries.
- Prefer a clean separation between presentation (Godot scenes, input, rendering) and authoritative game logic.

# Runtime roles (in-process)

One Godot process. Rust is **server-like** (authoritative state, tick owner) but **not** a network server. It talks to **one** Godot runtime.

| Role | Owner | Responsibility |
|------|--------|----------------|
| **Sim (authority)** | `native/crates/marloth_sim` via `marloth_ffi` | Owns game state; advances ticks from bulk input; emits bulk snapshots and service requests. |
| **Client** | Godot scenes + `MarlothSimHost` (GDExtension) | Presentation, input capture, applying snapshots. Minimal scene-tree state. |
| **Services** | Godot capabilities exposed through a separate service surface | Physics queries, asset/path helpers, etc., as needed by the sim. Isolated so the sim does not treat client and services as one API. |

Boundary style: **bulk** sync (input frames, snapshot entity arrays, service request/reply blobs) over chatty per-field FFI. Same-process shared buffers = Rust-owned arenas exposed as `ptr + len`.

World generation remains in sibling **margen** / **margen-godot** (Rust algorithms → C ABI → GDExtension).

# Native project boundaries

| Path | Role |
|------|------|
| `native/crates/marloth_sim` | Engine-agnostic authoritative simulation |
| `native/crates/marloth_ffi` | C ABI (`native/include/marloth.h`) |
| `native/crates/marloth_automation` | In-process tonic gRPC automation host + built-in playbooks |
| `native/crates/marloth_automation_proto` | Protobuf/gRPC contracts |
| `native/gdextension` | C++ godot-cpp: `MarlothSimHost`, `MarlothAutomationHost` |
| `addons/marloth/` | GDExtension loader + installed natives |
| `tests/functional/godot_driver` | Rust cargo tests that launch headless Godot and run playbooks |

# Godot project layout

| Directory / path | Purpose |
|------------------|---------|
| `./native` | Rust workspace + C++ GDExtension sources |
| `./addons/marloth` | Marloth GDExtension |
| `./addons/margen` | Margen GDExtension (sibling build) |
| `./tests/functional` | Godot playbook driver and docs |
| `./main.tscn` | Entry / main scene (`run/main_scene`) |
| `./logs/` | Local Godot file logs (`logs/marloth.log`) |
| `project.godot` | Godot project settings |

Additional layout dirs (e.g. `assets/`, `scenes/`, `entities/`, `ui/`) may be added as content grows; document them here when they become standard.
