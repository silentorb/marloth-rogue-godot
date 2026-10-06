# Sim authority (Rust in-process)

Authoritative game rules and world state live in **`marloth_sim`** (Rust). Godot is a **client** (presentation / input) plus isolated **services** the sim may call. Both roles share one Godot process by coincidence; the sim APIs treat them separately.

## Rules for new features

1. Put gameplay rules, ticks, and state in `native/crates/marloth_sim` (or crates it owns).
2. Keep the Godot scene tree **thin**: nodes apply bulk snapshots; they do not own rules.
3. Cross the boundary with **bulk** blobs (input frames, snapshot entity arrays, service request/reply buffers)—not chatty per-field FFI.
4. Use C++ GDExtension only as glue (`MarlothSimHost`, service adapters). Prefer GDScript only when Godot APIs force it.
5. Add unit tests in `marloth_sim` for discrete contracts; use Godot playbooks for scene/client behavior.

See [Technical design](../../technical-design.md) and [testing.md](testing.md).
