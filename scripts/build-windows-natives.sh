#!/usr/bin/env bash
# Cross-compile Windows margen GDExtension natives into the workspace addons tree.
# Intended to run inside marloth-win (HTTP build agent).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MARGEN_ROOT="${MARGEN_ROOT:-/home/chris/dev/margen}"
MARGEN_GODOT_ROOT="${MARGEN_GODOT_ROOT:-/home/chris/dev/margen-godot}"
BUILD_TYPE="${BUILD_TYPE:-Debug}"

if [[ ! -d "${MARGEN_ROOT}" ]]; then
	echo "MARGEN_ROOT not found: ${MARGEN_ROOT}" >&2
	exit 1
fi

if [[ ! -d "${MARGEN_GODOT_ROOT}" ]]; then
	echo "MARGEN_GODOT_ROOT not found: ${MARGEN_GODOT_ROOT}" >&2
	exit 1
fi

# Isolate cargo output from the bind-mounted margen/target used by the marloth
# (Debian newer glibc) session. Host build-scripts compiled there need GLIBC that
# bookworm-based marloth-win cannot provide (e.g. GLIBC_2.39).
export CARGO_TARGET_DIR="${CARGO_TARGET_DIR:-/var/cache/margen-cargo-target}"
mkdir -p "${CARGO_TARGET_DIR}"

echo "Building Windows margen natives (${BUILD_TYPE}) → ${ROOT}/addons/margen/bin ..."
(
	cd "${MARGEN_GODOT_ROOT}"
	# Bind mounts often differ in UID from the container user.
	git config --global --add safe.directory "${MARGEN_GODOT_ROOT}" || true
	git config --global --add safe.directory "${MARGEN_ROOT}" || true
	if [[ -d "${MARGEN_GODOT_ROOT}/.git" ]] || [[ -f "${MARGEN_GODOT_ROOT}/.git" ]]; then
		git submodule update --init --recursive
	fi
	TARGET=windows BUILD_TYPE="${BUILD_TYPE}" MARGEN_ROOT="${MARGEN_ROOT}" ./scripts/build.sh
	PLATFORM=windows MARLOTH_ROOT="${ROOT}" ./scripts/install-to-marloth.sh
)

echo "Windows margen natives installed under ${ROOT}/addons/margen/bin/"
