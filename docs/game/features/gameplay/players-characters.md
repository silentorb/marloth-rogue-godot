# Players and characters

The player experiences Marloth through a **character** in the world. For now there is a **single local player** with one character; multiplayer is reserved for later.

## What the player experiences

1. After the world loads, the player appears at the **player spawn** location (generated with the world).
2. Control is **first-person**: look and walk from the character’s viewpoint.
3. The body in the world is a generic **character pawn** (not branded as “the player”); later the same kind of body can be driven by AI.

## Scope (current)

- One human player, one character, one possessed pawn.
- Spawn comes from the world population marker (`PlayerSpawnLocation`), not a hand-placed scene actor in the debug level.

## Out of scope (later)

- Multiple simultaneous players
- Switching characters
- AI-driven characters using the same pawn type
- Third-person or other camera modes as primary play
