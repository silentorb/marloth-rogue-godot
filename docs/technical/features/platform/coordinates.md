# Coordinates

All **Rust** authority and generation data use **right-handed Z-up**:

| Axis | Meaning |
|------|---------|
| **+X** | Right / east |
| **+Y** | Forward / north |
| **+Z** | Up |

That includes `marloth_sim` snapshots (`pos_*`, yaw about **+Z**) and margen C ABI vectors (`MargenVec3`). Details for generation: sibling margen [`docs/coordinates.md`](../../../../margen/docs/coordinates.md).

**Godot** is right-handed **Y-up**. Convert only in C++ hosts (GDExtension), not in Rust:

\[
(x,\ y,\ z) \mapsto (x,\ z,\ -y)
\]

Yaw about sim **+Z** maps to Godot Euler yaw about **+Y** with a sign flip (`godot_yaw = -sim_yaw`) so +Y forward becomes Godot −Z. Margen mesh hosts also remap Godot `cell_size` `(sx, sy_up, sz) →` margen `(sx, sz, sy_up)` before ABI calls.

**Face winding:** margen face IR is RH-outward (CCW from outside). Godot `ArrayMesh` front faces are **clockwise**; **margen-godot** reverses fan indices (and normals) at mesh build. Details: margen [`docs/coordinates.md`](../../../../margen/docs/coordinates.md) **Face winding**.
