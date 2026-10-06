# Marloth GDExtension

Loads `marloth_godot` + `marloth_ffi` from `bin/`.

Build/install from the repo:

```bash
# Linux (dev container)
./scripts/ensure-marloth-natives.sh
# or:
./native/gdextension/scripts/build.sh
./native/gdextension/scripts/install-to-marloth.sh

# Windows DLLs (marloth-win agent; also runs as part of windows-project / windows-dist)
./scripts/devcontainer.sh windows-project
```

Windows Godot needs `addons/marloth/bin/*.dll` beside `marloth.gdextension`. Without them you get
`GDExtension dynamic library not found: 'res://addons/marloth/marloth.gdextension'`.

Classes: `MarlothSimHost` (client↔sim bulk tick), `MarlothAutomationHost` (gRPC playbooks when `MARLOTH_AUTOMATION_ENABLED`).

See [`native/AGENTS.md`](../../native/AGENTS.md).
