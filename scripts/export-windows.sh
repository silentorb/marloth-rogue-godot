#!/usr/bin/env bash
# Headless Godot Windows Desktop export into $MARLOTH_WIN_OUT/dist.
# Intended to run inside the marloth container (Godot + Windows templates).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WIN_ROOT="${MARLOTH_WIN_OUT:-/mnt/e/dev/games/marloth-godot}"
OUT="${WIN_ROOT}/dist"
GODOT_BIN="${GODOT_BIN:-/opt/godot/Godot_v4.6-stable_linux.x86_64}"
if [[ ! -x "${GODOT_BIN}" && -x /opt/godot/Godot_v4.6-stable_mono_linux.x86_64 ]]; then
	GODOT_BIN=/opt/godot/Godot_v4.6-stable_mono_linux.x86_64
fi
CONFIGURATION="${CONFIGURATION:-Debug}"
BUILD_TYPE="${BUILD_TYPE:-${CONFIGURATION}}"
TEMPLATES_DIR="${HOME}/.local/share/godot/export_templates/4.6.stable"
if [[ ! -d "${TEMPLATES_DIR}" ]]; then
	# Older images shipped mono templates only.
	TEMPLATES_DIR="${HOME}/.local/share/godot/export_templates/4.6.stable.mono"
fi
PRESET_NAME="Windows Desktop"
EXE_NAME="marloth.exe"
ADDON_BIN="${ROOT}/addons/margen/bin"
MARLOTH_BIN="${ROOT}/addons/marloth/bin"

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
	echo "Godot Windows export templates missing at ${TEMPLATES_DIR}." >&2
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
	MARLOTH_EXT="${MARLOTH_BIN}/libmarloth_godot.windows.template_debug.x86_64.dll"
	;;
Release|release)
	EXPORT_FLAG="--export-release"
	EXT_DLL="${ADDON_BIN}/libmargen_godot.windows.template_release.x86_64.dll"
	MARLOTH_EXT="${MARLOTH_BIN}/libmarloth_godot.windows.template_release.x86_64.dll"
	;;
*)
	echo "Unsupported BUILD_TYPE/CONFIGURATION: ${BUILD_TYPE}" >&2
	exit 2
	;;
esac

FFI_DLL="${ADDON_BIN}/margen_ffi.dll"
MARLOTH_FFI="${MARLOTH_BIN}/marloth_ffi.dll"
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
if [[ ! -f "${MARLOTH_EXT}" ]]; then
	echo "Missing Windows marloth extension DLL: ${MARLOTH_EXT}" >&2
	echo "Run the marloth-win natives build first (./scripts/devcontainer.sh windows-dist)." >&2
	exit 1
fi
if [[ ! -f "${MARLOTH_FFI}" ]]; then
	echo "Missing marloth_ffi.dll: ${MARLOTH_FFI}" >&2
	echo "Run the marloth-win natives build first (./scripts/devcontainer.sh windows-dist)." >&2
	exit 1
fi

echo "Preparing dist output directory: ${OUT}"
mkdir -p "${OUT}"
find "${OUT}" -mindepth 1 -maxdepth 1 -exec rm -rf {} +

EXPORT_PATH="${OUT}/${EXE_NAME}"

echo "Importing project (headless)..."
"${GODOT_BIN}" --headless --path "${ROOT}" --import

echo "Exporting ${PRESET_NAME} (${EXPORT_FLAG}) → ${EXPORT_PATH} ..."
set +e
"${GODOT_BIN}" --headless --path "${ROOT}" ${EXPORT_FLAG} "${PRESET_NAME}" "${EXPORT_PATH}" 2>&1 | tee /tmp/marloth-windows-export.log
export_rc=${PIPESTATUS[0]}
set -e

if [[ ! -f "${EXPORT_PATH}" ]]; then
	echo "Export finished but ${EXPORT_PATH} was not created (godot exit ${export_rc})." >&2
	tail -40 /tmp/marloth-windows-export.log >&2 || true
	exit 1
fi

mkdir -p "${OUT}/logs"

echo
echo "Windows dist ready: ${EXPORT_PATH}"
echo "Run that executable on Windows (e.g. E:\\dev\\games\\marloth-godot\\dist\\marloth.exe)."
echo "Logs: ${OUT}/logs/marloth.log"
