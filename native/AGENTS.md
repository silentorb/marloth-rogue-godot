# Agent notes — native (Rust + GDExtension)

## Purpose

In-process **server-like** authority (`marloth_sim`) and C++ Godot glue. Godot provides a **client** role and isolated **services**; the sim does not treat them as one API.

## Layout

| Path | Role |
|------|------|
| `crates/marloth_sim` | Authoritative game state / ticks |
| `crates/marloth_ffi` | C ABI (`include/marloth.h`) |
| `crates/marloth_automation` | tonic gRPC host + built-in playbooks |
| `crates/marloth_automation_proto` | Protobuf definitions |
| `gdextension/` | godot-cpp: `MarlothSimHost`, `MarlothAutomationHost` |

## Build

```bash
export CARGO_HOME="${CARGO_HOME:-$PWD/../.cargo-home}"
export CARGO_TARGET_DIR="${CARGO_TARGET_DIR:-$PWD/target}"
./gdextension/scripts/build.sh
./gdextension/scripts/install-to-marloth.sh
```

`godot-cpp` is taken from `$MARGEN_GODOT_ROOT/godot-cpp` (sibling margen-godot).

## Rules

- Prefer **bulk** FFI (input frames, snapshot arrays, service blobs).
- No generation algorithms here — those stay in **margen**.
- Future gameplay rules land in `marloth_sim`, not in Godot scene scripts.
