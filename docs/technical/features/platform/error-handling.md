# Error handling

Cross-cutting standards for product and agent-authored code. Feature docs may still define specific fail-fast or abort contracts; this file is the shared policy for **how** to choose and wire failures.

## Principles

1. Prefer **explicit outcomes** (`Try*`, local Ok/Error result types, validated returns) for **expected** failure modes callers can or must handle.
2. Use **exceptions** for **truly exceptional** cases: programmer invariants (misused APIs), corrupted impossible state, or a documented **fail-fast abort** boundary where recovery is not defined (e.g. boot / scene load).
3. Do **not** swallow failures (empty `catch`, silent defaults that look like success).
4. Do **not** leave half-initialized interactive state when multi-step setup fails.
5. For any path longer than a line or two: **choose and document** the failure mode (throw, return outcome, abort UI, soft no-op) before implementing.

Do **not** introduce a shared `Result<T>` library unless a later design change explicitly adds one. When adding explicit flows, prefer local Ok/Error types or `Try*` APIs consistent with `PlaybookResult` / playbook load outcomes.

## Layer guidance

| Layer | Guidance |
|-------|----------|
| **Core** | Throw on API misuse and broken invariants. Prefer `Try*` / nullable for expected misses. No Godot logging. |
| **Client / boot** | Fail-fast remains valid when the product contract is abort. Prefer a **single catch boundary** that surfaces (`GD.PushError`) and exits rather than scattering uncaught throws across `_Ready`. Scene changes via `ChangeSceneToFile` must check `Error.Ok` and surface failure—do not ignore the return code. |
| **Automation / gRPC** | Keep Ok/Error on the wire for business failures. Do not invent a parallel exception API for playbook/RPC outcomes. Playbook library load returns **Ok/Error** so the wire protocol can report failure **without aborting** the Godot process. |

## Agent checklist

When adding or editing multi-step logic:

1. List failure points on the path.
2. Classify each as **expected** (explicit outcome) vs **exceptional / abort** (throw or single catch boundary).
3. Ensure callers (or the abort boundary) **see** the failure—no silent success lookalikes.
4. Cover the documented failure contract with tests when sound (see [testing.md](testing.md)).
