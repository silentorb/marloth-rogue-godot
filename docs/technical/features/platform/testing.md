# Testing

Standards for automated and manual verification. Expand this doc as the suite grows (functional layers, Godot automation, etc.).

## Layers (today)

| Layer | Use for… |
|-------|----------|
| **Unit** (`tests/`) | Logic and contracts that can run without a Godot process (`dotnet test`). |
| **Manual / Godot play** | Scene wiring, input, rendering, and anything not yet covered by automation. Use the Dev Container `GODOT_BIN` / Launch Godot editor task when needed. |

Prefer the **lowest** layer that can soundly assert the requirement.

## Docs-backed assertions

Tests verify **documented** requirements in `docs/` (values and rules stated in feature docs or technical design), not undocumented code quirks.

## Bug regressions / debugging

When fixing a **user-reported bug** the suite did not catch:

1. Confirm whether an existing test **should** have failed.
2. If not, add a **failing test first** at the lowest sound layer (unit → manual / Godot play).
3. Fix the product code; keep the test green.
4. If the report defines missing behavior, update the docs in the same change and assert against that.

**Escalate instead of a bad test:** do not invent coverage that needs heavy hacking, new general harnesses you were not asked to build, or that is likely brittle, flaky, hanging, or non-deterministic. Stop and explain trade-offs; wait for direction to skip, expand testing capabilities, or redesign for testability.

See also [`.cursor/rules/bug-regression-tests.mdc`](../../../../.cursor/rules/bug-regression-tests.mdc).
