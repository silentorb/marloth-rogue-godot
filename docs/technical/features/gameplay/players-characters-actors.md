# Players, characters, and actors

Authoritative **Player**, **Character**, and **Actor** records live in `marloth_sim`. They are **not** scene-tree nodes. Godot presents an **Actor** as a generic `CharacterBody3D` pawn and drives it through a **PawnController**.

Player-facing intent: [players-characters](../../../game/features/gameplay/players-characters.md). Coordinates: [coordinates](../platform/coordinates.md). Authority: [sim-authority](../platform/sim-authority.md).

## Associations

| Record | Lives in | Association |
|--------|----------|-------------|
| **Player** | `marloth_sim` | At most one **Character** (`Option`) |
| **Character** | `marloth_sim` | At most one **Actor** (`Option`) |
| **Actor** | `marloth_sim` | Id + RH Z-up pose/yaw; snapshot entity id = actor id |

Ids are `u32` newtypes (`PlayerId`, `CharacterId`, `ActorId`). Tables are multiplayer-ready `Vec`s; only **local player 0** is bootstrapped today.

## Bootstrap

`Sim::bootstrap_local_player(spawn_pose)` creates player 0, a character, and an actor at the given RH Z-up pose, then links Player→Character→Actor. **Fails** if already bootstrapped.

`MarlothSimHost` resolves `MargenWorldMesh/Actors/PlayerSpawnLocation`, converts Godot transform → sim pose, calls bootstrap, instances `scenes/entities/character_pawn.tscn`, and possesses it with `MarlothPlayerController`. Missing spawn marker is an **explicit failure** (error log; no possession).

## Pose report (interim locomotion)

Pawn locomotion uses Godot `CharacterBody3D` + `move_and_slide` on the **client** for this slice. Each tick the host reports the possessed pawn’s pose into the sim via `Sim::set_actor_pose` (unknown actor id → error). Snapshots emit one `SnapshotEntity` per actor. Sim `InputFrame` axes do **not** move actors while client locomotion owns movement.

This is an intentional interim versus full sim-authoritative locomotion; see [sim-authority](../platform/sim-authority.md).

## PawnController (client)

| Class | Role |
|-------|------|
| `MarlothPawnController` | Base: `possess` / `unpossess`, pawn + `actor_id` |
| `MarlothPlayerController` | Local human: WASD + mouse look → `move_and_slide` |
| `MarlothAIController` | Stub (no motion); same possession API for later AI |

The pawn scene is **not** player-specific. Either controller type may possess the same pawn class; only `MarlothPlayerController` is wired on boot.

Spawned pawn is named `CharacterPawn` under `MarlothSimHost` and joins group `character_pawn`.

## Testing

- **Unit** (`cargo test -p marloth_sim`): bootstrap links, pose → snapshot, double-bootstrap fails, unknown actor pose fails.
- **Playbook** `LocalPlayerPawnSpawned`: ClassDB for controllers; node `MarlothSimHost/CharacterPawn` exists after `main.tscn` load.
