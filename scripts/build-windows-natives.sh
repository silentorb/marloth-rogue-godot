#!/usr/bin/env bash
# Cross-compile Windows GDExtension natives (margen + marloth) into workspace addons.
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

# Isolate cargo output from bind-mounted */target used by the marloth
# (Debian newer glibc) session. Host build-scripts compiled there need GLIBC that
# bookworm-based marloth-win cannot provide (e.g. GLIBC_2.39).
export CARGO_TARGET_DIR="${CARGO_TARGET_DIR:-/var/cache/margen-cargo-target}"
mkdir -p "${CARGO_TARGET_DIR}"

# Writable cargo home for registry on marloth-win (image may lock /usr/local/cargo).
export CARGO_HOME="${CARGO_HOME:-/var/cache/marloth-cargo-home}"
mkdir -p "${CARGO_HOME}"

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

echo "Building Windows marloth natives (${BUILD_TYPE}) → ${ROOT}/addons/marloth/bin ..."
(
	cd "${ROOT}/native/gdextension"
	TARGET=windows BUILD_TYPE="${BUILD_TYPE}" MARGEN_GODOT_ROOT="${MARGEN_GODOT_ROOT}" ./scripts/build.sh
	PLATFORM=windows ./scripts/install-to-marloth.sh
)

echo "Windows marloth natives installed under ${ROOT}/addons/marloth/bin/"
