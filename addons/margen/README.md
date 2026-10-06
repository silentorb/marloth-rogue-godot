# margen GDExtension (Marloth)

Loads the **margen-godot** GDExtension built from the sibling [`margen-godot`](../../../margen-godot) repo.

## Build and install the native library (Linux)

From `margen-godot`:

```bash
git submodule update --init --recursive
./scripts/build.sh
./scripts/install-to-marloth.sh
```

That copies `libmargen_godot.*.so` and `libmargen_ffi.so` into `addons/margen/bin/`. The `.gdextension` file in this folder is checked in with Marloth-relative paths.

Godot functional tests call [`scripts/ensure-margen-natives.sh`](../../scripts/ensure-margen-natives.sh) automatically (via [`scripts/run_godot_functional_tests.sh`](../../scripts/run_godot_functional_tests.sh)).

## Windows natives + dist / project

From the attached **`marloth`** container (see [AGENTS.md](../../AGENTS.md)):

```bash
./scripts/devcontainer.sh windows-dist      # → $MARLOTH_WIN_OUT/dist/
./scripts/devcontainer.sh windows-project   # → $MARLOTH_WIN_OUT/project/
```

Both POST to the **`marloth-win`** compose-network build agent (`http://marloth-win:9876/build`), which runs [`scripts/build-windows-natives.sh`](../../scripts/build-windows-natives.sh) and installs Windows DLLs into workspace `addons/margen/bin/` (`libmargen_godot.windows.*.dll` + `margen_ffi.dll`).

- **dist:** [`scripts/export-windows.sh`](../../scripts/export-windows.sh) (Godot headless Windows Desktop export) into `$MARLOTH_WIN_OUT/dist`. [`scripts/verify-margen-windows.sh`](../../scripts/verify-margen-windows.sh) audits that dir (set `VERIFY_MARGEN_STRICT=1` to fail the build on WARN/FAIL). Run `dist/marloth.exe` on Windows — no editor required. `windows-build` is an alias of `windows-dist`.
- **project:** [`scripts/sync-windows-project.sh`](../../scripts/sync-windows-project.sh) rsyncs sources and publishes win-x64 C# into `$MARLOTH_WIN_OUT/project`. Open that folder in Windows Godot 4.6 .NET.

Natives are built with **cargo-xwin** / **clang-cl** (`x86_64-pc-windows-msvc`), not MinGW.

Or from `margen-godot` alone:

```bash
TARGET=windows ./scripts/build.sh
MARLOTH_ROOT=/path/to/marloth ./scripts/install-to-marloth.sh
```

Then from marloth: `./scripts/export-windows.sh` (dist) or `./scripts/sync-windows-project.sh` (project).
## Debug scene

Open [`scenes/margen_world_debug.tscn`](../../scenes/margen_world_debug.tscn) in the Godot editor (or run the scene). It instances `MargenWorldMesh`, which generates a winding-path world grid and displays prism faces with placeholder materials.

F5 / Windows Desktop export boots [`main.tscn`](../../main.tscn), which instances this debug world until a real shell exists. Playbooks that need the debug scene alone still load `res://scenes/margen_world_debug.tscn` directly.

Contract for automated tests: seed=`7`, max_blocks=`20`, cell_size=`(2,2,2)` — see [world-generation.md](../../docs/technical/features/platform/world-generation.md).

## Functional tests (primary gate)

In the Linux **dev container**:

```bash
./scripts/run_godot_functional_tests.sh
```

Playbooks:

| Playbook | Asserts |
|----------|---------|
| `MargenExtensionLoaded` | `ClassDB` contains `MargenWorldMesh` |
| `MargenWorldDebug` | Debug scene auto-generates a mesh within the documented vertex band |

If these **fail on Linux**, fix the extension/API/code before debugging Windows. If they **pass on Linux** but the Windows dist fails to load margen, use the diagnostics runbook below.

## Diagnosing load failures (Windows)

Symptom: `Cannot get class 'MargenWorldMesh'` when running `dist/marloth.exe` on Windows.

### Ruled out (prior session)

Wrong `--path`, missing/corrupt DLLs, bad `res://` paths, wrong entry symbol, basic PE corruption, and MinGW runtime DLLs (`libstdc++` / `libgcc` / `libwinpthread`) after the MSVC / cargo-xwin switch.

### Still open (use Track B)

godot-cpp **4.5** API vs Godot **4.6.1**, feature-tag selection, `margen_ffi.dll` Windows search path, silent init failure, MOTW/Defender.

### Runbook

1. **First:** `./scripts/run_godot_functional_tests.sh` (Linux) — must PASS.
2. After `windows-dist`: `./scripts/verify-margen-windows.sh` (defaults to `$MARLOTH_WIN_OUT/dist`).
3. On Windows, run `E:\dev\games\marloth-godot\dist\marloth.exe`. For DLL LoadLibrary diagnostics against workspace natives (not the dist), use:
   ```powershell
   .\scripts\windows\verify-margen-extension.ps1
   ```
4. Check local file logs at `E:\dev\games\marloth-godot\dist\logs\marloth.log` (Godot `debug/file_logging/log_path`). Also capture live stdout via the console wrapper `marloth.console.exe` when present.
5. Optional API audit from margen-godot: `./scripts/verify-godot-cpp-api.sh 4.6.1`.
