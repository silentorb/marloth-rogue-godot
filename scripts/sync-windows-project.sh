#!/usr/bin/env bash
# Sync Marloth to a Windows-openable Godot project under $MARLOTH_WIN_OUT/project.
# Expects Windows natives already in workspace addons/*/bin/ (natives build).
# Intended to run inside the marloth container (rsync).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WIN_ROOT="${MARLOTH_WIN_OUT:-/mnt/e/dev/games/marloth-godot}"
OUT="${WIN_ROOT}/project"
CONFIGURATION="${CONFIGURATION:-Debug}"
BUILD_TYPE="${BUILD_TYPE:-${CONFIGURATION}}"
MARGEN_BIN="${ROOT}/addons/margen/bin"
MARLOTH_BIN="${ROOT}/addons/marloth/bin"

if [[ -z "${WIN_ROOT}" ]]; then
	echo "MARLOTH_WIN_OUT is unset." >&2
	exit 1
fi

if [[ ! -d "$(dirname "${WIN_ROOT}")" ]]; then
	echo "Parent of MARLOTH_WIN_OUT is missing or unmounted: $(dirname "${WIN_ROOT}")" >&2
	exit 1
fi

if ! command -v rsync >/dev/null 2>&1; then
	echo "rsync is required to sync the Windows project tree." >&2
	echo "Rebuild: Dev Containers → Rebuild and Reopen in Container." >&2
	exit 2
fi

case "${BUILD_TYPE}" in
Debug|debug)
	EXT_DLL="${MARGEN_BIN}/libmargen_godot.windows.template_debug.x86_64.dll"
	MARLOTH_EXT="${MARLOTH_BIN}/libmarloth_godot.windows.template_debug.x86_64.dll"
	;;
Release|release)
	EXT_DLL="${MARGEN_BIN}/libmargen_godot.windows.template_release.x86_64.dll"
	MARLOTH_EXT="${MARLOTH_BIN}/libmarloth_godot.windows.template_release.x86_64.dll"
	;;
*)
	echo "Unsupported BUILD_TYPE/CONFIGURATION: ${BUILD_TYPE}" >&2
	exit 2
	;;
esac

FFI_DLL="${MARGEN_BIN}/margen_ffi.dll"
MARLOTH_FFI="${MARLOTH_BIN}/marloth_ffi.dll"
if [[ ! -f "${EXT_DLL}" ]]; then
	echo "Missing Windows margen extension DLL: ${EXT_DLL}" >&2
	echo "Run the marloth-win natives build first (./scripts/devcontainer.sh windows-project)." >&2
	exit 1
fi
if [[ ! -f "${FFI_DLL}" ]]; then
	echo "Missing margen_ffi.dll: ${FFI_DLL}" >&2
	echo "Run the marloth-win natives build first (./scripts/devcontainer.sh windows-project)." >&2
	exit 1
fi
if [[ ! -f "${MARLOTH_EXT}" ]]; then
	echo "Missing Windows marloth extension DLL: ${MARLOTH_EXT}" >&2
	echo "Run the marloth-win natives build first (./scripts/devcontainer.sh windows-project)." >&2
	exit 1
fi
if [[ ! -f "${MARLOTH_FFI}" ]]; then
	echo "Missing marloth_ffi.dll: ${MARLOTH_FFI}" >&2
	echo "Run the marloth-win natives build first (./scripts/devcontainer.sh windows-project)." >&2
	exit 1
fi

echo "Preparing project output directory: ${OUT}"
mkdir -p "${OUT}"

echo "Syncing marloth → ${OUT} ..."
rsync -a --delete \
	--exclude '.git/' \
	--exclude '.godot/' \
	--exclude '.vs/' \
	--exclude 'bin/' \
	--exclude 'obj/' \
	--exclude '**/bin/' \
	--exclude '**/obj/' \
	--exclude 'addons/margen/bin/' \
	--exclude 'addons/marloth/bin/' \
	--exclude 'native/target/' \
	--exclude 'native/gdextension/build/' \
	--exclude 'native/gdextension/bin/' \
	--exclude '.cargo-home/' \
	--exclude '.devcontainer/' \
	--exclude 'tests/' \
	--exclude 'logs/' \
	"${ROOT}/" "${OUT}/"

echo "Installing Windows margen DLLs into ${OUT}/addons/margen/bin/ ..."
mkdir -p "${OUT}/addons/margen/bin"
find "${MARGEN_BIN}" -maxdepth 1 -type f \( -name '*.dll' -o -name '*.pdb' \) -exec cp -a {} "${OUT}/addons/margen/bin/" \;

echo "Installing Windows marloth DLLs into ${OUT}/addons/marloth/bin/ ..."
mkdir -p "${OUT}/addons/marloth/bin"
find "${MARLOTH_BIN}" -maxdepth 1 -type f \( -name '*.dll' -o -name '*.pdb' \) -exec cp -a {} "${OUT}/addons/marloth/bin/" \;

mkdir -p "${OUT}/logs"

echo
echo "Windows project ready: ${OUT}"
echo "Open that folder in Windows Godot 4.6 (e.g. E:\\dev\\games\\marloth-godot\\project)."
echo "Do not launch Windows Godot from this Linux container."
echo "Logs: ${OUT}/logs/marloth.log"
