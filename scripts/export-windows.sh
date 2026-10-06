#!/usr/bin/env bash
# Headless Godot Windows Desktop export into $MARLOTH_WIN_OUT/dist.
# Intended to run inside the marloth container (Godot + mono Windows templates).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WIN_ROOT="${MARLOTH_WIN_OUT:-/mnt/e/dev/games/marloth-godot}"
OUT="${WIN_ROOT}/dist"
GODOT_BIN="${GODOT_BIN:-/opt/godot/Godot_v4.6-stable_mono_linux.x86_64}"
CONFIGURATION="${CONFIGURATION:-Debug}"
BUILD_TYPE="${BUILD_TYPE:-${CONFIGURATION}}"
TEMPLATES_DIR="${HOME}/.local/share/godot/export_templates/4.6.stable.mono"
PRESET_NAME="Windows Desktop"
EXE_NAME="marloth.exe"
ADDON_BIN="${ROOT}/addons/margen/bin"

if [[ -z "${WIN_ROOT}" ]]; then
	echo "MARLOTH_WIN_OUT is unset." >&2
	exit 1
fi

if [[ ! -d "$(dirname "${WIN_ROOT}")" ]]; then
	echo "Parent of MARLOTH_WIN_OUT is missing or unmounted: $(dirname "${WIN_ROOT}")" >&2
	exit 1
fi

if [[ ! -x "${GODOT_BIN}" ]]; then
	echo "Godot binary not found: ${GODOT_BIN}" >&2
	echo "Rebuild: Dev Containers → Rebuild and Reopen in Container." >&2
	exit 2
fi

if [[ ! -d "${TEMPLATES_DIR}" ]] || [[ ! -f "${TEMPLATES_DIR}/windows_debug_x86_64.exe" ]]; then
	echo "Godot mono Windows export templates missing at ${TEMPLATES_DIR}." >&2
	echo "Rebuild: Dev Containers → Rebuild and Reopen in Container." >&2
	exit 2
fi

if [[ ! -f "${ROOT}/export_presets.cfg" ]]; then
	echo "Missing export_presets.cfg in ${ROOT}" >&2
	exit 1
fi

case "${BUILD_TYPE}" in
Debug|debug)
	EXPORT_FLAG="--export-debug"
	EXT_DLL="${ADDON_BIN}/libmargen_godot.windows.template_debug.x86_64.dll"
	;;
Release|release)
	EXPORT_FLAG="--export-release"
	EXT_DLL="${ADDON_BIN}/libmargen_godot.windows.template_release.x86_64.dll"
	;;
*)
	echo "Unsupported BUILD_TYPE/CONFIGURATION: ${BUILD_TYPE}" >&2
	exit 2
	;;
esac

FFI_DLL="${ADDON_BIN}/margen_ffi.dll"
if [[ ! -f "${EXT_DLL}" ]]; then
	echo "Missing Windows margen extension DLL: ${EXT_DLL}" >&2
	echo "Run the marloth-win natives build first (./scripts/devcontainer.sh windows-dist)." >&2
	exit 1
fi
if [[ ! -f "${FFI_DLL}" ]]; then
	echo "Missing margen_ffi.dll: ${FFI_DLL}" >&2
	echo "Run the marloth-win natives build first (./scripts/devcontainer.sh windows-dist)." >&2
	exit 1
fi

echo "Preparing dist output directory: ${OUT}"
mkdir -p "${OUT}"
# Replace only this sibling so $MARLOTH_WIN_OUT/project can coexist.
find "${OUT}" -mindepth 1 -maxdepth 1 -exec rm -rf {} +

EXPORT_PATH="${OUT}/${EXE_NAME}"

echo "Importing project (headless)..."
"${GODOT_BIN}" --headless --path "${ROOT}" --import

# Godot 4.6.stable may rewrite Sdk to Godot.NET.Sdk/4.6.0 on import; keep GodotSharp 4.6.1 pin.
if grep -q 'Godot\.NET\.Sdk/4\.6\.0' "${ROOT}/marloth.csproj" 2>/dev/null; then
	if ! grep -q 'PackageReference Include="GodotSharp" Version="4.6.1"' "${ROOT}/marloth.csproj"; then
		echo "marloth.csproj missing GodotSharp 4.6.1 pin after import; export would NU1605." >&2
		exit 1
	fi
fi

# Older project publishes on marloth-win left root-owned win-x64 objs on the shared
# .godot volume; clear RID-specific caches we can write so Godot's dotnet publish works.
for rid_dir in "${ROOT}/.godot/mono/temp/obj"/*/win-x64; do
	if [[ -d "${rid_dir}" ]] && [[ ! -w "${rid_dir}" ]]; then
		echo "Removing unwritable RID cache (likely root-owned): ${rid_dir}"
		rm -rf "${rid_dir}" 2>/dev/null || {
			echo "Cannot remove ${rid_dir}; fix ownership on the marloth-godot-cache volume." >&2
			exit 1
		}
	fi
done

echo "Exporting ${PRESET_NAME} (${EXPORT_FLAG}) → ${EXPORT_PATH} ..."
set +e
"${GODOT_BIN}" --headless --path "${ROOT}" ${EXPORT_FLAG} "${PRESET_NAME}" "${EXPORT_PATH}" 2>&1 | tee /tmp/marloth-windows-export.log
export_rc=${PIPESTATUS[0]}
set -e

if grep -q 'Export .NET Project: Failed to build project' /tmp/marloth-windows-export.log; then
	echo "Godot .NET publish failed during export. See /tmp/marloth-windows-export.log" >&2
	grep -E 'error |ERROR:|NU[0-9]+' /tmp/marloth-windows-export.log | tail -40 >&2 || true
	exit 1
fi

if [[ ! -f "${EXPORT_PATH}" ]]; then
	echo "Export finished but ${EXPORT_PATH} was not created (godot exit ${export_rc})." >&2
	exit 1
fi

# Godot .NET Windows exports place managed assemblies under data_<name>_windows_*.
data_dir="$(find "${OUT}" -maxdepth 1 -type d -name 'data_*_windows_*' | head -n1 || true)"
if [[ -z "${data_dir}" ]]; then
	echo "Export missing data_*_windows_* directory (managed assemblies). .NET publish likely failed." >&2
	ls -la "${OUT}" >&2 || true
	exit 1
fi
if ! find "${data_dir}" -maxdepth 2 -type f -name 'marloth.dll' | grep -q .; then
	echo "Export data dir ${data_dir} is missing marloth.dll." >&2
	ls -la "${data_dir}" >&2 || true
	exit 1
fi

# Local file logging (project setting logs/marloth.log) needs this dir beside the exe.
mkdir -p "${OUT}/logs"

echo
echo "Windows dist ready: ${EXPORT_PATH}"
echo "Managed assemblies: ${data_dir}"
echo "Run that executable on Windows (e.g. E:\\dev\\games\\marloth-godot\\dist\\marloth.exe)."
echo "Logs: ${OUT}/logs/marloth.log"
