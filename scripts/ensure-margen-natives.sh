#!/usr/bin/env bash
# Ensure Linux margen GDExtension natives are installed under addons/margen/bin/
# and that .godot/extension_list.cfg lists the extension (needed for headless CLI runs).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ADDON_BIN="${ROOT}/addons/margen/bin"
EXT_SO="${ADDON_BIN}/libmargen_godot.linux.template_debug.x86_64.so"
FFI_SO="${ADDON_BIN}/libmargen_ffi.so"
MARGEN_GODOT_ROOT="${MARGEN_GODOT_ROOT:-${ROOT}/../margen-godot}"
MARGEN_ROOT="${MARGEN_ROOT:-${ROOT}/../margen}"
EXTENSION_LIST="${ROOT}/.godot/extension_list.cfg"
EXTENSION_RES="res://addons/margen/margen.gdextension"

has_natives() {
	[[ -f "${EXT_SO}" && -s "${EXT_SO}" && -f "${FFI_SO}" && -s "${FFI_SO}" ]]
}

ensure_extension_list() {
	mkdir -p "${ROOT}/.godot"
	if [[ ! -w "${ROOT}/.godot" ]]; then
		echo "Cannot write ${ROOT}/.godot (owned by $(stat -c '%U:%G' "${ROOT}/.godot" 2>/dev/null || echo unknown))." >&2
		echo "The marloth-godot-cache volume must be writable by the container user." >&2
		echo "Fix: sudo chown -R \"\$(id -u):\$(id -g)\" ${ROOT}/.godot" >&2
		echo "Or from the WSL host: ./scripts/devcontainer.sh down --volumes && reopen the container." >&2
		exit 1
	fi
	if [[ -f "${EXTENSION_LIST}" ]] && grep -qxF "${EXTENSION_RES}" "${EXTENSION_LIST}"; then
		return 0
	fi
	if [[ -f "${EXTENSION_LIST}" ]]; then
		printf '%s\n' "${EXTENSION_RES}" >>"${EXTENSION_LIST}"
	else
		printf '%s\n' "${EXTENSION_RES}" >"${EXTENSION_LIST}"
	fi
	echo "Wrote ${EXTENSION_LIST} with ${EXTENSION_RES}"
}

if has_natives; then
	echo "margen Linux natives present in ${ADDON_BIN}"
	ensure_extension_list
	exit 0
fi

if [[ ! -d "${MARGEN_GODOT_ROOT}" ]]; then
	echo "Missing margen natives under ${ADDON_BIN}." >&2
	echo "Expected:" >&2
	echo "  ${EXT_SO}" >&2
	echo "  ${FFI_SO}" >&2
	echo "Set MARGEN_GODOT_ROOT to the margen-godot repo (and MARGEN_ROOT to margen), or build manually:" >&2
	echo "  cd <margen-godot> && ./scripts/build.sh && MARLOTH_ROOT=${ROOT} ./scripts/install-to-marloth.sh" >&2
	exit 1
fi

if [[ ! -d "${MARGEN_ROOT}" ]]; then
	echo "MARGEN_ROOT not found: ${MARGEN_ROOT}" >&2
	exit 1
fi

echo "Building Linux margen natives from ${MARGEN_GODOT_ROOT} ..."
(
	cd "${MARGEN_GODOT_ROOT}"
	if [[ -d "${MARGEN_GODOT_ROOT}/.git" ]] || [[ -f "${MARGEN_GODOT_ROOT}/.git" ]]; then
		git config --global --add safe.directory "${MARGEN_GODOT_ROOT}" || true
		git config --global --add safe.directory "${MARGEN_ROOT}" || true
		git submodule update --init --recursive
	fi
	TARGET=linux BUILD_TYPE="${BUILD_TYPE:-Debug}" MARGEN_ROOT="${MARGEN_ROOT}" ./scripts/build.sh
	PLATFORM=linux MARLOTH_ROOT="${ROOT}" ./scripts/install-to-marloth.sh
)

if ! has_natives; then
	echo "margen natives still missing after build/install." >&2
	exit 1
fi

ensure_extension_list
echo "margen Linux natives ready."
