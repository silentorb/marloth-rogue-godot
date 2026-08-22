#!/usr/bin/env bash
# Run Marloth.Functional.Godot.Tests (xUnit + gRPC playbook automation).
# Prerequisites:
#   - GODOT_BIN: path to a Godot 4.x .NET executable this environment can execute.
#     In the dev container this is set automatically (see .devcontainer/devcontainer.json).
#   - Optional: MARLOTH_AUTOMATION_PORT (default: auto-picked by tests).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [[ -z "${GODOT_BIN:-}" ]]; then
  echo "GODOT_BIN is not set. Example: export GODOT_BIN=/opt/godot/Godot_v4.6-stable_mono_linux.x86_64" >&2
  exit 2
fi

# Helpers + playbook libraries must exist before Godot loads them at runtime.
dotnet build "${ROOT}/src/Marloth.Automation/Marloth.Automation.csproj" -v q
dotnet build "${ROOT}/tests/functional/Marloth.Functional.Godot.Playbooks/Marloth.Functional.Godot.Playbooks.csproj" -v q

# Ensure Godot's C# assemblies (including [ScriptPath] metadata) are up to date.
dotnet build "${ROOT}/marloth.csproj" -v q

dotnet test "${ROOT}/tests/functional/Marloth.Functional.Godot.Tests/Marloth.Functional.Godot.Tests.csproj" \
  "$@"
