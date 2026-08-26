#!/usr/bin/env bash
# Sync Marloth to a Windows play tree and cross-compile C# + margen natives.
# Intended to run inside the marloth-win compose service.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="${MARLOTH_WIN_OUT:-/mnt/e/dev/games/marloth-godot}"
MARGEN_ROOT="${MARGEN_ROOT:-/home/chris/dev/margen}"
MARGEN_GODOT_ROOT="${MARGEN_GODOT_ROOT:-/home/chris/dev/margen-godot}"
BUILD_TYPE="${BUILD_TYPE:-Debug}"
CONFIGURATION="${CONFIGURATION:-Debug}"

if [[ -z "${OUT}" ]]; then
	echo "MARLOTH_WIN_OUT is unset." >&2
	exit 1
fi

if [[ ! -d "$(dirname "${OUT}")" ]]; then
	echo "Parent of MARLOTH_WIN_OUT is missing or unmounted: $(dirname "${OUT}")" >&2
	exit 1
fi

if [[ ! -d "${MARGEN_ROOT}" ]]; then
	echo "MARGEN_ROOT not found: ${MARGEN_ROOT}" >&2
	exit 1
fi

if [[ ! -d "${MARGEN_GODOT_ROOT}" ]]; then
	echo "MARGEN_GODOT_ROOT not found: ${MARGEN_GODOT_ROOT}" >&2
	exit 1
fi

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
	--exclude 'addons/margen/bin/*.so' \
	--exclude 'addons/margen/bin/*.dll' \
	--exclude '.devcontainer/' \
	--exclude 'tests/' \
	"${ROOT}/" "${OUT}/"

echo "Building Windows margen natives (${BUILD_TYPE})..."
(
	cd "${MARGEN_GODOT_ROOT}"
	# Bind mounts often differ in UID from the container user.
	git config --global --add safe.directory "${MARGEN_GODOT_ROOT}" || true
	git config --global --add safe.directory "${MARGEN_ROOT}" || true
	if [[ -d "${MARGEN_GODOT_ROOT}/.git" ]] || [[ -f "${MARGEN_GODOT_ROOT}/.git" ]]; then
		git submodule update --init --recursive
	fi
	TARGET=windows BUILD_TYPE="${BUILD_TYPE}" MARGEN_ROOT="${MARGEN_ROOT}" ./scripts/build.sh
	PLATFORM=windows MARLOTH_ROOT="${OUT}" ./scripts/install-to-marloth.sh
)

MONO_OUT="${OUT}/.godot/mono/temp/bin/${CONFIGURATION}"
mkdir -p "${MONO_OUT}"

echo "Publishing C# win-x64 → ${MONO_OUT} ..."
dotnet publish "${ROOT}/marloth.csproj" \
	-c "${CONFIGURATION}" \
	-r win-x64 \
	--self-contained false \
	-p:GodotTargetPlatform=windows \
	-o "${MONO_OUT}"

echo
echo "Windows play tree ready: ${OUT}"
echo "Open that folder in Windows Godot 4.6 .NET (e.g. E:\\dev\\games\\marloth-godot)."
echo "Do not launch Windows Godot from this Linux container."
