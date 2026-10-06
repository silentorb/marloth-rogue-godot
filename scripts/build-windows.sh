#!/usr/bin/env bash
# Orchestrate Windows GDExtension natives (margen + marloth via marloth-win)
# + dist export or project sync (marloth).
#
# Usage: build-windows.sh [dist|project]
#   dist (default): POST natives, then export-windows.sh → $MARLOTH_WIN_OUT/dist
#   project:        POST natives, then sync-windows-project.sh → $MARLOTH_WIN_OUT/project
#
# On marloth-win (no Godot): natives only (also the HTTP agent entrypoint).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WIN_ROOT="${MARLOTH_WIN_OUT:-/mnt/e/dev/games/marloth-godot}"
GODOT_BIN="${GODOT_BIN:-/opt/godot/Godot_v4.6-stable_linux.x86_64}"
if [[ ! -x "${GODOT_BIN}" && -x /opt/godot/Godot_v4.6-stable_mono_linux.x86_64 ]]; then
	GODOT_BIN=/opt/godot/Godot_v4.6-stable_mono_linux.x86_64
fi
MODE="${1:-dist}"

# marloth-win has the MSVC/cargo-xwin toolchain but not the Godot editor.
if [[ ! -x "${GODOT_BIN}" ]]; then
	exec "${ROOT}/scripts/build-windows-natives.sh"
fi

case "${MODE}" in
dist|project) ;;
*)
	echo "Usage: $0 [dist|project]" >&2
	exit 2
	;;
esac

if [[ -z "${WIN_ROOT}" ]]; then
	echo "MARLOTH_WIN_OUT is unset." >&2
	exit 1
fi

if [[ ! -d "$(dirname "${WIN_ROOT}")" ]]; then
	echo "Parent of MARLOTH_WIN_OUT is missing or unmounted: $(dirname "${WIN_ROOT}")" >&2
	exit 1
fi

base="http://${MARLOTH_WIN_AGENT_HOST:-marloth-win}:${MARLOTH_WIN_AGENT_PORT:-9876}"
if ! command -v curl >/dev/null 2>&1; then
	echo "curl is required to call the marloth-win build agent." >&2
	exit 2
fi
if ! curl -sfS --connect-timeout 2 --max-time 5 "${base}/health" >/dev/null; then
	echo "marloth-win build agent is not reachable at ${base}." >&2
	echo "Ensure marloth-win is running (devcontainer.json runServices) and Rebuild/Reopen the container." >&2
	exit 2
fi

echo "Triggering Windows natives build via ${base}/build ..."
http_code="$(
	curl -sS -X POST \
		--connect-timeout 5 \
		--max-time 3600 \
		-w "\n%{http_code}" \
		"${base}/build"
)"
body="$(printf '%s' "${http_code}" | sed '$d')"
status="$(printf '%s' "${http_code}" | tail -n1)"
printf '%s\n' "${body}"
case "${status}" in
200) ;;
409)
	echo "Windows natives build already in progress on marloth-win." >&2
	exit 1
	;;
*)
	echo "marloth-win build agent returned HTTP ${status}." >&2
	exit 1
	;;
esac

if [[ "${MODE}" == "project" ]]; then
	"${ROOT}/scripts/sync-windows-project.sh"
	exit 0
fi

"${ROOT}/scripts/export-windows.sh"

DIST_DIR="${WIN_ROOT}/dist"
VERIFY_SCRIPT="${ROOT}/scripts/verify-margen-windows.sh"
if [[ -x "${VERIFY_SCRIPT}" ]]; then
	echo
	echo "Running margen Windows dist audit..."
	if ! "${VERIFY_SCRIPT}" "${DIST_DIR}"; then
		if [[ "${VERIFY_MARGEN_STRICT:-0}" == "1" ]]; then
			echo "verify-margen-windows.sh failed (VERIFY_MARGEN_STRICT=1)." >&2
			exit 1
		fi
		echo "verify-margen-windows.sh reported FAIL (non-strict; dist still succeeded)." >&2
	fi
fi
