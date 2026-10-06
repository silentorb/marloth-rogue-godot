#!/usr/bin/env bash
# Ensure Linux marloth GDExtension natives exist under addons/marloth/bin.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ADDON_BIN="${ROOT}/addons/marloth/bin"
GDEXT="${ROOT}/native/gdextension"

if [[ -f "${ADDON_BIN}/libmarloth_godot.linux.template_debug.x86_64.so" && -f "${ADDON_BIN}/libmarloth_ffi.so" ]]; then
	# Keep extension listed for Godot.
	EXT_LIST="${ROOT}/.godot/extension_list.cfg"
	mkdir -p "${ROOT}/.godot"
	if [[ ! -f "${EXT_LIST}" ]] || ! grep -q 'addons/marloth/marloth.gdextension' "${EXT_LIST}" 2>/dev/null; then
		{
			echo "res://addons/margen/margen.gdextension"
			echo "res://addons/marloth/marloth.gdextension"
		} >"${EXT_LIST}"
	fi
	exit 0
fi

echo "Building marloth natives..."
export CARGO_HOME="${CARGO_HOME:-${ROOT}/.cargo-home}"
export CARGO_TARGET_DIR="${CARGO_TARGET_DIR:-${ROOT}/native/target}"
mkdir -p "${CARGO_HOME}" "${CARGO_TARGET_DIR}"
"${GDEXT}/scripts/build.sh"
PLATFORM=linux "${GDEXT}/scripts/install-to-marloth.sh"

EXT_LIST="${ROOT}/.godot/extension_list.cfg"
mkdir -p "${ROOT}/.godot"
{
	echo "res://addons/margen/margen.gdextension"
	echo "res://addons/marloth/marloth.gdextension"
} >"${EXT_LIST}"
