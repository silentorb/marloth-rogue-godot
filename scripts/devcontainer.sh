#!/usr/bin/env bash
# Manage marloth devcontainer compose services (WSL host) and dual-mode helpers.
#
# Run from the marloth repo root (works with marloth.code-workspace — no need to
# cd into .devcontainer). Compose commands (build/rebuild/up/down/ps/logs/exec/
# shell) need Docker on the WSL host. functional-tests runs locally when already
# attached to the marloth container; otherwise it compose-execs into marloth.
#
# Examples:
#   ./scripts/devcontainer.sh rebuild              # marloth + marloth-win images, recreate
#   ./scripts/devcontainer.sh rebuild marloth-win  # Windows cross-build image only
#   ./scripts/devcontainer.sh up marloth-win
#   ./scripts/devcontainer.sh exec marloth-win ./scripts/build-windows.sh
#   ./scripts/devcontainer.sh logs -f marloth-win
#   ./scripts/devcontainer.sh functional-tests     # attached or from WSL host
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE_FILE="${ROOT}/.devcontainer/docker-compose.yml"
COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-devcontainer}"
COMPOSE=(docker compose -p "${COMPOSE_PROJECT_NAME}" -f "${COMPOSE_FILE}")
DEFAULT_GODOT_BIN="/opt/godot/Godot_v4.6-stable_mono_linux.x86_64"
MARLOTH_SERVICE=marloth

DEFAULT_SERVICES=(marloth marloth-win)
ALL_SERVICES=(marloth marloth-win margen)

usage() {
	cat <<EOF
Usage: $(basename "$0") <command> [options] [services...]

Commands:
  build [--no-cache] [services...]   Build images (default: marloth marloth-win)
  rebuild [--no-cache] [services...] Build images and recreate containers (up -d --force-recreate)
  up [services...]                   Start services in the background
  down [--volumes]                   Stop all compose services (optional: remove volumes)
  ps                                 Show service status
  logs [-f] <service>                Tail service logs (-f to follow)
  exec <service> <command...>        Run a command in a running service
  functional-tests [args...]         Run Godot playbooks (attached or via marloth service)
  shell [service]                    Open bash in a service (default: marloth-win)

Services: marloth, marloth-win, margen, or all

Notes:
  - Godot functional tests: ./scripts/devcontainer.sh functional-tests (or the VS Code task);
    works when attached and from the WSL host.
  - After rebuilding marloth, use Cursor: Dev Containers → Rebuild and Reopen in Container.
  - down --volumes removes marloth-godot-cache (Godot import/shader cache).
EOF
}

require_docker() {
	if ! command -v docker >/dev/null 2>&1; then
		echo "docker is not on PATH." >&2
		echo "Run this script from the WSL host, not from inside an attached dev container." >&2
		exit 1
	fi
	if [[ ! -f "${COMPOSE_FILE}" ]]; then
		echo "Compose file not found: ${COMPOSE_FILE}" >&2
		exit 1
	fi
}

resolve_services() {
	local -n _out=$1
	shift
	_out=()
	if [[ $# -eq 0 ]]; then
		_out=("${DEFAULT_SERVICES[@]}")
		return 0
	fi
	while [[ $# -gt 0 ]]; do
		case "$1" in
		all)
			_out=("${ALL_SERVICES[@]}")
			;;
		marloth | marloth-win | margen)
			_out+=("$1")
			;;
		*)
			echo "Unknown service: $1" >&2
			echo "Valid services: marloth, marloth-win, margen, all" >&2
			exit 1
			;;
		esac
		shift
	done
}

parse_build_flags() {
	BUILD_FLAGS=()
	while [[ $# -gt 0 ]]; do
		case "$1" in
		--no-cache)
			BUILD_FLAGS+=(--no-cache)
			shift
			;;
		--)
			shift
			break
			;;
		-*)
			echo "Unknown option: $1" >&2
			usage >&2
			exit 1
			;;
		*)
			break
			;;
		esac
	done
	REMAINING_ARGS=("$@")
}

cmd_build() {
	parse_build_flags "$@"
	local services=()
	resolve_services services "${REMAINING_ARGS[@]}"
	echo "Building: ${services[*]}"
	"${COMPOSE[@]}" build "${BUILD_FLAGS[@]}" "${services[@]}"
}

cmd_rebuild() {
	parse_build_flags "$@"
	local services=()
	resolve_services services "${REMAINING_ARGS[@]}"
	echo "Rebuilding: ${services[*]}"
	"${COMPOSE[@]}" build "${BUILD_FLAGS[@]}" "${services[@]}"
	"${COMPOSE[@]}" up -d --force-recreate "${services[@]}"
	if [[ " ${services[*]} " == *" marloth "* ]]; then
		echo
		echo "marloth image rebuilt. In Cursor: Dev Containers → Rebuild and Reopen in Container."
	fi
}

cmd_up() {
	local services=()
	resolve_services services "$@"
	"${COMPOSE[@]}" up -d "${services[@]}"
}

cmd_down() {
	local remove_volumes=0
	if [[ "${1:-}" == "--volumes" ]]; then
		remove_volumes=1
		shift
	fi
	if [[ $# -gt 0 ]]; then
		echo "down ignores service names; stopping the full compose project." >&2
	fi
	if [[ "${remove_volumes}" -eq 1 ]]; then
		"${COMPOSE[@]}" down --volumes
	else
		"${COMPOSE[@]}" down
	fi
}

cmd_ps() {
	"${COMPOSE[@]}" ps
}

cmd_logs() {
	local follow=0
	if [[ "${1:-}" == "-f" ]]; then
		follow=1
		shift
	fi
	if [[ $# -ne 1 ]]; then
		echo "logs requires exactly one service." >&2
		exit 1
	fi
	if [[ "${follow}" -eq 1 ]]; then
		"${COMPOSE[@]}" logs -f "$1"
	else
		"${COMPOSE[@]}" logs "$1"
	fi
}

cmd_exec() {
	if [[ $# -lt 2 ]]; then
		echo "exec requires: <service> <command...>" >&2
		exit 1
	fi
	local service=$1
	shift
	"${COMPOSE[@]}" exec -T "${service}" "$@"
}

cmd_shell() {
	local service="${1:-marloth-win}"
	"${COMPOSE[@]}" exec "${service}" bash
}

in_marloth_container() {
	[[ -x "${DEFAULT_GODOT_BIN}" ]] && command -v dotnet >/dev/null 2>&1
}

cmd_functional_tests() {
	if in_marloth_container; then
		exec "${ROOT}/scripts/run_godot_functional_tests.sh" "$@"
	fi

	require_docker
	echo "Running Godot functional tests in ${MARLOTH_SERVICE} ..."
	cmd_up "${MARLOTH_SERVICE}"

	if ! "${COMPOSE[@]}" exec -T "${MARLOTH_SERVICE}" test -x "${DEFAULT_GODOT_BIN}" 2>/dev/null; then
		echo "${MARLOTH_SERVICE} is missing ${DEFAULT_GODOT_BIN}." >&2
		echo "Rebuild: $(basename "$0") rebuild ${MARLOTH_SERVICE}" >&2
		exit 2
	fi
	if ! "${COMPOSE[@]}" exec -T "${MARLOTH_SERVICE}" sh -c 'command -v dotnet >/dev/null' 2>/dev/null; then
		echo "${MARLOTH_SERVICE} is missing dotnet." >&2
		echo "Rebuild: $(basename "$0") rebuild ${MARLOTH_SERVICE}" >&2
		exit 2
	fi

	cmd_exec "${MARLOTH_SERVICE}" bash -lc \
		"cd /workspaces/marloth && ./scripts/run_godot_functional_tests.sh $(printf '%q ' "$@")"
}

main() {
	if [[ $# -eq 0 ]]; then
		usage
		exit 1
	fi

	local command=$1
	shift

	case "${command}" in
	functional-tests)
		cmd_functional_tests "$@"
		;;
	-h | --help | help)
		usage
		;;
	build | rebuild | up | down | ps | logs | exec | shell)
		require_docker
		case "${command}" in
		build) cmd_build "$@" ;;
		rebuild) cmd_rebuild "$@" ;;
		up) cmd_up "$@" ;;
		down) cmd_down "$@" ;;
		ps) cmd_ps ;;
		logs) cmd_logs "$@" ;;
		exec) cmd_exec "$@" ;;
		shell) cmd_shell "$@" ;;
		esac
		;;
	*)
		echo "Unknown command: ${command}" >&2
		usage >&2
		exit 1
		;;
	esac
}

main "$@"
