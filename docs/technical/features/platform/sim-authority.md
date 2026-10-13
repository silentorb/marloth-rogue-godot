# Sim authority (Rust in-process)

Authoritative game rules and world state live in **`marloth_sim`** (Rust). Godot is a **client** (presentation / input) plus isolated **services** the sim may call. Both roles share one Godot process by coincidence; the sim APIs treat them separately.

Positions and yaw are **right-handed Z-up** in the sim; `MarlothGlobal` (client glue) converts for Godot. See [coordinates.md](coordinates.md).

## Rules for new features

1. Put gameplay rules, ticks, and state in `native/crates/marloth_sim` (or crates it owns).
2. Keep the Godot scene tree **thin**: nodes apply bulk snapshots; they do not own rules. Prefer **MarlothGlobal** + session library over invisible in-scene logic actors ([global-session](global-session.md)).
3. Cross the boundary with **bulk** blobs (input frames, snapshot entity arrays, service request/reply buffers)—not chatty per-field FFI.
4. Use C++ GDExtension only as glue (`MarlothGlobal`, service adapters). Prefer GDScript only when Godot APIs force it.
5. Add unit tests in `marloth_sim` for discrete contracts; use Godot playbooks for scene/client behavior.

## Interim: client CharacterBody3D locomotion

For the first-person pawn slice, **planar locomotion and look** run on the Godot client (`CharacterBody3D` + `move_and_slide` via `MarlothPlayerController`). The sim still owns **Player / Character / Actor** associations and stores **last-known actor pose** reported each tick from Global. This is intentional interim behavior until locomotion moves fully into `marloth_sim`. Details: [players-characters-actors](../gameplay/players-characters-actors.md).

See [Technical design](../../technical-design.md) and [testing.md](testing.md).
