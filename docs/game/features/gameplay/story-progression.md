# Story progression

Marloth worlds can be shaped by a **story graph**: a structured sequence of progression beats that defines how the player moves through space before (and while) richer narrative content is layered on top.

This is **not** dialogue, cutscenes, or quest text today. It is the **skeleton of player flow** — ordered locations, gating, and backtracking that create an abstract sense of narrative movement.

## What the player experiences

The story graph encodes a deliberate flow:

1. **Discover** a space or beat.
2. **Obtain access** (key, switch, unlocked connection) when a gate requires it.
3. **Revisit** earlier areas when branching layout forces backtracking (keys are intentionally not placed adjacent to their gates).
4. **Advance** along the progression chain toward later beats.

Each graph node is a **beat in that flow** even when no authored content is attached yet. The world layout reflects progression order, not only geometry.

## Connection semantics

Story connections carry attributes (see technical [story graph](../../../margen/docs/story-graph.md) in the margen repo):

- **Direct** — neighboring progression with no gating between beats.
- **Unlocks** — the source beat contains what is needed to open progress toward the target (doors, switches, keys downstream).

These attributes drive both **spatial layout** and **switch placement** in the generation pipeline.

## Future vision

The same progression skeleton is intended to become the **foundation for richer narrative layers**:

- Authored events tied to nodes or edges
- Characters and dialogue at beats
- Objectives and quest steps mapped to sectors or connections
- Pacing and reveal order driven by the graph structure

New narrative systems should **attach to** the graph (metadata, scripting, content refs), not replace the underlying progression DAG — so layout, gating, and story content stay aligned.

## Relationship to other generation paths

Unreal reference code supports two grid-creation strategies:

| Path | Emphasis |
|------|----------|
| **Story graph** | Progression-first: abstract DAG → sparse spatial clusters → rooms |
| **Winding path** | Geometry-first: prefab start → procedural maze growth → analysis-derived sectors |

Neither path is documented here as deprecated. Marloth may use one or both depending on level type. The story graph path is the one best suited to ** authored progression and future narrative depth**.

## Engineering references

- Player-facing rules: this file.
- Pipeline and port status: margen repo [`docs/story-graph.md`](../../../../margen/docs/story-graph.md) (sibling workspace folder **`margen`**).
- Stack ownership: [world generation (technical)](../../technical/features/platform/world-generation.md).
