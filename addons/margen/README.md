# margen GDExtension (Marloth)

Loads the **margen-godot** GDExtension built from the sibling [`margen-godot`](../../../margen-godot) repo.

## Build and install the native library

From `margen-godot`:

```bash
git submodule update --init --recursive
./scripts/build.sh
./scripts/install-to-marloth.sh
```

That copies `libmargen_godot.*.so` and `libmargen_ffi.so` into `addons/margen/bin/`. The `.gdextension` file in this folder is checked in with Marloth-relative paths.

## Debug scene

Open [`scenes/margen_world_debug.tscn`](../../scenes/margen_world_debug.tscn) in the Godot editor (or run the scene). It instances `MargenWorldMesh`, which generates a winding-path world grid and displays prism faces with placeholder materials.
