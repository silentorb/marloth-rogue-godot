# Error handling

Cross-cutting standards for product and agent-authored code. Feature docs may still define specific fail-fast or abort contracts; this file is the shared policy for **how** to choose and wire failures.

## Principles

1. Prefer **explicit outcomes** (`Try*`, local Ok/Error result types, validated returns, Rust `Result`) for **expected** failure modes callers can or must handle.
2. Use **panic / exceptions / abort** for **truly exceptional** cases: programmer invariants (misused APIs), corrupted impossible state, or a documented **fail-fast abort** boundary where recovery is not defined (e.g. boot / scene load).
3. Do **not** swallow failures (empty `catch` / ignored `Result`, silent defaults that look like success).
4. Do **not** leave half-initialized interactive state when multi-step setup fails.
5. For any path longer than a line or two: **choose and document** the failure mode (return outcome, abort UI, soft no-op) before implementing.

Do **not** introduce a shared `Result<T>` library across languages unless a later design change explicitly adds one. Prefer idiomatic Rust `Result` in sim/FFI status codes, and Ok/Error on the automation wire.

## Layer guidance

| Layer | Guidance |
|-------|----------|
| **`marloth_sim`** | Panic on API misuse and broken invariants in debug; prefer `Result` / validated returns for expected misses. No Godot logging. |
| **Client / boot (GDExtension)** | Fail-fast remains valid when the product contract is abort. Prefer a **single** surface that logs (`push_error`) and exits rather than scattering failures across `_ready`. Scene changes must check return codes—do not ignore them. |
| **C ABI (`marloth_ffi`)** | Return status codes (`MARLOTH_OK` / errors) + `marloth_last_error()` for expected failures. |
| **Automation / gRPC** | Keep Ok/Error on the wire for business failures. Do not invent a parallel exception API for playbook/RPC outcomes. Playbook runs return **Ok/Error** so the wire protocol can report failure **without aborting** the Godot process. |

## Agent checklist

When adding or editing multi-step logic:

1. List failure points on the path.
2. Classify each as **expected** (explicit outcome) vs **exceptional / abort** (panic or single abort boundary).
3. Ensure callers (or the abort boundary) **see** the failure—no silent success lookalikes.
4. Cover the documented failure contract with tests when sound (see [testing.md](testing.md)).
