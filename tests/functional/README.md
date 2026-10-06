# Functional tests

| Suite | How to run | Needs Godot |
|-------|------------|-------------|
| Sim unit | `cd native && cargo test -p marloth_sim` | No |
| Godot playbooks | `./scripts/run_godot_functional_tests.sh` | Yes (`GODOT_BIN`) |

Godot playbooks use `MarlothAutomationHost` (GDExtension) and the Rust driver under `godot_driver/`. Built-in playbook ids:

- `MainSceneBootstrap`
- `MargenExtensionLoaded`
- `MargenWorldDebug`
- `MarlothSimHostLoaded`

Natives: `scripts/ensure-margen-natives.sh` and `scripts/ensure-marloth-natives.sh`.

See [docs/technical/features/platform/testing.md](../../docs/technical/features/platform/testing.md).
