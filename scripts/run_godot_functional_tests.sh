#!/usr/bin/env bash
# Run Godot functional playbooks via the Rust godot_driver (tonic client).
#
# Must run inside the marloth dev container (Reopen in Container). Prerequisites
# come from the image — no runtime downloads, no host fallback:
#   - GODOT_BIN: Godot 4.x Linux binary (/opt/godot in the marloth image).
#   - Rust toolchain (cargo)
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

DEFAULT_GODOT_BIN="/opt/godot/Godot_v4.6-stable_linux.x86_64"
# Prefer non-mono; fall back to mono binary still present in older images.
FALLBACK_GODOT_BIN="/opt/godot/Godot_v4.6-stable_mono_linux.x86_64"

require_dev_container() {
	if ! resolve_godot_bin; then
		echo "Godot functional tests must run in the marloth dev container." >&2
		if [[ -n "${GODOT_BIN:-}" ]]; then
			echo "  GODOT_BIN=${GODOT_BIN} (not executable or missing)" >&2
		else
			echo "  Expected: ${DEFAULT_GODOT_BIN} (or mono fallback)" >&2
		fi
		echo "Use Dev Containers: Reopen in Container, then rerun this script." >&2
		echo "If the image is stale: ./scripts/devcontainer.sh rebuild marloth" >&2
		exit 2
	fi

	if ! command -v cargo >/dev/null 2>&1; then
		echo "cargo is not on PATH." >&2
		echo "Godot functional tests must run in the marloth dev container." >&2
		exit 2
	fi
}

resolve_godot_bin() {
	if [[ -n "${GODOT_BIN:-}" && -x "${GODOT_BIN}" ]]; then
		return 0
	fi
	if [[ -x "${DEFAULT_GODOT_BIN}" ]]; then
		GODOT_BIN="${DEFAULT_GODOT_BIN}"
		export GODOT_BIN
		return 0
	fi
	if [[ -x "${FALLBACK_GODOT_BIN}" ]]; then
		GODOT_BIN="${FALLBACK_GODOT_BIN}"
		export GODOT_BIN
		return 0
	fi
	return 1
}

require_dev_container

"${ROOT}/scripts/ensure-margen-natives.sh"
"${ROOT}/scripts/ensure-marloth-natives.sh"

export CARGO_HOME="${CARGO_HOME:-${ROOT}/.cargo-home}"
export CARGO_TARGET_DIR="${CARGO_TARGET_DIR:-${ROOT}/native/target}"
mkdir -p "${CARGO_HOME}" "${CARGO_TARGET_DIR}"

# Build automation proto / ffi deps used by the driver.
(
	cd "${ROOT}/native"
	cargo build -p marloth_automation_proto
)

cargo test --manifest-path "${ROOT}/tests/functional/godot_driver/Cargo.toml" -- --test-threads=1 "$@"
