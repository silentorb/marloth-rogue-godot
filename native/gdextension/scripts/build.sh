#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NATIVE_ROOT="$(cd "${ROOT}/.." && pwd)"
BUILD_TYPE="${BUILD_TYPE:-Debug}"
TARGET="${TARGET:-linux}"
PROFILE="release"
if [[ "${BUILD_TYPE}" == "Debug" ]]; then
	PROFILE="debug"
fi

GENERATOR=()
if command -v ninja >/dev/null 2>&1; then
	GENERATOR=(-G Ninja)
fi

case "${TARGET}" in
	linux)
		echo "Building marloth_ffi (${PROFILE}, host)..."
		(
			cd "${NATIVE_ROOT}"
			if [[ "${PROFILE}" == "release" ]]; then
				cargo build -p marloth_ffi --release
			else
				cargo build -p marloth_ffi
			fi
		)

		echo "Building marloth_godot (${BUILD_TYPE}, linux)..."
		cmake -S "${ROOT}" -B "${ROOT}/build" "${GENERATOR[@]}" \
			-DCMAKE_BUILD_TYPE="${BUILD_TYPE}" \
			-DMARLOTH_NATIVE_ROOT="${NATIVE_ROOT}"
		cmake --build "${ROOT}/build" --parallel
		;;
	windows)
		TRIPLE="x86_64-pc-windows-msvc"
		TOOLCHAIN="${MARGEN_GODOT_ROOT:-/home/chris/dev/margen-godot}/cmake/clang-cl-xwin-x86_64.cmake"
		if [[ ! -f "${TOOLCHAIN}" ]]; then
			echo "Missing clang-cl/xwin toolchain file: ${TOOLCHAIN}" >&2
			exit 1
		fi
		if ! command -v cargo-xwin >/dev/null 2>&1 && ! cargo xwin --help >/dev/null 2>&1; then
			echo "cargo-xwin is required for TARGET=windows." >&2
			echo "Run via marloth-win (./scripts/devcontainer.sh windows-project)." >&2
			exit 1
		fi
		if [[ -z "${XWIN_CACHE_DIR:-}" ]]; then
			export XWIN_CACHE_DIR="/opt/cargo-xwin"
		fi
		echo "Building marloth_ffi (${PROFILE}, ${TRIPLE} via cargo-xwin)..."
		if [[ -n "${CARGO_TARGET_DIR:-}" ]]; then
			echo "CARGO_TARGET_DIR=${CARGO_TARGET_DIR}"
			mkdir -p "${CARGO_TARGET_DIR}"
		fi
		(
			cd "${NATIVE_ROOT}"
			if [[ "${PROFILE}" == "release" ]]; then
				cargo xwin build -p marloth_ffi --release --target "${TRIPLE}"
			else
				cargo xwin build -p marloth_ffi --target "${TRIPLE}"
			fi
		)
		# Wipe stale toolchain cache when switching.
		if [[ -f "${ROOT}/build-windows/CMakeCache.txt" ]]; then
			prev_tc=$(grep -E '^CMAKE_TOOLCHAIN_FILE:' "${ROOT}/build-windows/CMakeCache.txt" 2>/dev/null | cut -d= -f2- || true)
			if [[ "${prev_tc}" != "${TOOLCHAIN}" ]]; then
				echo "Toolchain changed; clearing ${ROOT}/build-windows ..."
				rm -rf "${ROOT}/build-windows"
			fi
		fi
		if [[ -d "${ROOT}/build-windows" ]] && [[ ! -w "${ROOT}/build-windows" ]]; then
			echo "Clearing unwritable ${ROOT}/build-windows ..."
			rm -rf "${ROOT}/build-windows"
		fi
		cmake -S "${ROOT}" -B "${ROOT}/build-windows" "${GENERATOR[@]}" \
			-DCMAKE_TOOLCHAIN_FILE="${TOOLCHAIN}" \
			-DCMAKE_BUILD_TYPE="${BUILD_TYPE}" \
			-DMARLOTH_NATIVE_ROOT="${NATIVE_ROOT}" \
			-DMARLOTH_FFI_TARGET="${TRIPLE}"
		cmake --build "${ROOT}/build-windows" --parallel
		;;
	*)
		echo "Unknown TARGET=${TARGET}" >&2
		exit 1
		;;
esac

echo "Built: ${ROOT}/bin/"
