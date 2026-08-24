# Game feature docs (read on demand)

**Features index** for Marloth. **Source of truth** for design, feel, and player-facing rules beyond the high-level pillars in [game-design.md](../game-design.md). **Do not** open every file for general engineering tasks.

Feature docs are grouped under `ui/`, `gameplay/`, `session/`, and `platform/` (create a group directory when the first feature file lands there).

1. Skim the **trigger** lines below.
2. If a trigger matches your current task, read **only** that markdown file.

When a topic has both player-facing rules and engineering contracts, keep the player-facing requirements here and the APIs/implementation contracts under [technical features](../../technical/features/README.md).

| File | Read when… |
|------|------------|
| [../game-design.md](../game-design.md) | Reading **gameplay vision**, genre pillars, or high-level feel. **Do not edit** unless the user explicitly instructed changes to that file. |
| [gameplay/story-progression.md](gameplay/story-progression.md) | **Progression beats**, story graph player flow, gating/backtracking intent, or future narrative layers on the generation DAG. |
