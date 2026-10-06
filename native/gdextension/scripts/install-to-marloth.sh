#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MARLOTH_ROOT="$(cd "${ROOT}/../.." && pwd)"
ADDON_BIN="${MARLOTH_ROOT}/addons/marloth/bin"
PLATFORM="${PLATFORM:-all}"

if [[ ! -d "${ROOT}/bin" ]]; then
	echo "Run ./scripts/build.sh first." >&2
	exit 1
fi

shopt -s nullglob
libs_so=("${ROOT}/bin/libmarloth_godot."*.so)
libs_dll=("${ROOT}/bin/libmarloth_godot."*.dll)

mkdir -p "${ADDON_BIN}"
installed=0

if [[ "${PLATFORM}" == "linux" || "${PLATFORM}" == "all" ]]; then
	if ((${#libs_so[@]} > 0)); then
		if [[ ! -f "${ROOT}/bin/libmarloth_ffi.so" ]]; then
			echo "Missing ${ROOT}/bin/libmarloth_ffi.so" >&2
			exit 1
		fi
		cp "${libs_so[@]}" "${ADDON_BIN}/"
		cp "${ROOT}/bin/libmarloth_ffi.so" "${ADDON_BIN}/"
		echo "Installed Linux marloth natives to ${ADDON_BIN}"
		installed=1
	elif [[ "${PLATFORM}" == "linux" ]]; then
		echo "No built libmarloth_godot.*.so" >&2
		exit 1
	fi
fi

if [[ "${PLATFORM}" == "windows" || "${PLATFORM}" == "all" ]]; then
	if ((${#libs_dll[@]} > 0)); then
		if [[ ! -f "${ROOT}/bin/marloth_ffi.dll" ]]; then
			echo "Missing ${ROOT}/bin/marloth_ffi.dll" >&2
			exit 1
		fi
		cp "${libs_dll[@]}" "${ADDON_BIN}/"
		cp "${ROOT}/bin/marloth_ffi.dll" "${ADDON_BIN}/"
		echo "Installed Windows marloth natives to ${ADDON_BIN}"
		installed=1
	elif [[ "${PLATFORM}" == "windows" ]]; then
		echo "No built libmarloth_godot.*.dll" >&2
		exit 1
	fi
fi

if ((installed == 0)); then
	echo "No built libmarloth_godot.* found in ${ROOT}/bin" >&2
	exit 1
fi
