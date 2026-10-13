# Global session and thin world scenes

Marloth avoids Unity-style **invisible scene actors** that own game rules. Session and population logic live in **library code**; Godot integration is a thin autoload plus an optional in-scene kickstart.

## MarlothGlobal (autoload)

`MarlothGlobal` is a GDExtension autoload (`addons/marloth/global.tscn`). It:

1. **Stores** root handles (sim pointer, session-ready flag, active pawn/controller references) without encoding world rules.
2. **Initializes / deinitializes** the sim and world session (`start_world_session` / `end_world_session`).
3. **Exposes thin APIs** that call session library helpers; ticks the sim and reports actor pose while a session is active.

It does **not** hard-code scene paths or implement spawn selection inline beyond calling the library.

## MarlothWorldScene (thin in-scene)

World scenes (e.g. [`scenes/margen_world_debug.tscn`](../../../../scenes/margen_world_debug.tscn)) include a **`MarlothWorldScene`** child. On `_ready` (non-editor), it waits **one frame** (so mesh generation and spawn markers exist), then calls `MarlothGlobal.start_world_session(scene_root)`.

GUI/menu scenes omit this node. The node itself does not look up spawns, load pawn scenes, or own sim APIs beyond that kickstart.

## Player spawn selection

| Contract | Value |
|----------|--------|
| Godot group | `player_spawn` |
| Emit | margen-godot tags realized player-spawn markers with that group (display name `PlayerSpawnLocation` is debug-only) |
| Select | Session library: `get_nodes_in_group("player_spawn")`, keep **descendants of the world scene root**, take the **first**. Empty → explicit fail (no possession). |

Do **not** select by hardcoded node paths or `find_child` by name.

Default pawn presentation: `res://scenes/entities/character_pawn.tscn` (loaded by Global, not a per-scene export).

See [players-characters-actors](../gameplay/players-characters-actors.md) and [world-generation](world-generation.md).
