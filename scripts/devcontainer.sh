#!/usr/bin/env bash
# Dual-mode helpers for the attached marloth container (and optional compose mgmt).
#
# Prefer running tasks while attached (Cursor Dev Containers).
# - functional-tests: runs locally when attached
# - windows-dist / windows-project: marloth-win natives + dist export or project sync
# - windows-build: alias of windows-dist
#
# Examples:
#   ./scripts/devcontainer.sh functional-tests
#   ./scripts/devcontainer.sh windows-dist
#   ./scripts/devcontainer.sh windows-project
#   ./scripts/devcontainer.sh rebuild   # needs docker; prefer Dev Containers → Rebuild
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE_FILE="${ROOT}/.devcontainer/docker-compose.yml"
COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-devcontainer}"
COMPOSE=(docker compose -p "${COMPOSE_PROJECT_NAME}" -f "${COMPOSE_FILE}")
DEFAULT_GODOT_BIN="/opt/godot/Godot_v4.6-stable_mono_linux.x86_64"
MARLOTH_SERVICE=marloth
WIN_SERVICE=marloth-win

DEFAULT_SERVICES=(marloth marloth-win)
ALL_SERVICES=(marloth marloth-win margen)

usage() {
	cat <<EOF
Usage: $(basename "$0") <command> [options] [services...]

Commands:
  build [--no-cache] [services...]   Build images (default: marloth marloth-win)
  rebuild [--no-cache] [services...] Build images and recreate containers
  up [services...]                   Start services in the background
  down [--volumes]                   Stop all compose services (optional: remove volumes)
  ps                                 Show service status
  logs [-f] <service>                Tail service logs (-f to follow)
  exec <service> <command...>        Run a command in a running service
  functional-tests [args...]         Run Godot playbooks (attached, or via marloth)
  windows-dist                       Packaged Windows app → \$MARLOTH_WIN_OUT/dist
  windows-project                    Editor play tree → \$MARLOTH_WIN_OUT/project
  windows-build                      Alias of windows-dist
  shell [service]                    Open bash in a service (default: marloth)

Services: marloth, marloth-win, margen, or all

Notes:
  - functional-tests / windows-dist / windows-project work when attached. Prefer the VS Code tasks.
  - windows-dist: POST natives to marloth-win, then Godot export into dist/.
  - windows-project: POST natives, then rsync + win-x64 publish into project/.
  - After Dockerfile changes: Dev Containers → Rebuild and Reopen in Container
    (devcontainer.json runServices starts marloth-win with the attach session).
  - down --volumes removes marloth-godot-cache (Godot import/shader cache).
EOF
}

require_docker() {
	if ! command -v docker >/dev/null 2>&1; then
		echo "docker is not on PATH." >&2
		echo "This compose command needs Docker. Prefer Cursor: Dev Containers → Rebuild Container." >&2
		echo "For playbooks / Windows outputs, use: $(basename "$0") functional-tests | windows-dist | windows-project" >&2
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
	local service="${1:-marloth}"
	"${COMPOSE[@]}" exec "${service}" bash
}

in_marloth_container() {
	[[ -x "${DEFAULT_GODOT_BIN}" ]] && command -v dotnet >/dev/null 2>&1
}

win_agent_url() {
	local host="${MARLOTH_WIN_AGENT_HOST:-marloth-win}"
	local port="${MARLOTH_WIN_AGENT_PORT:-9876}"
	echo "http://${host}:${port}"
}

call_windows_build_agent() {
	local base
	base="$(win_agent_url)"
	if ! command -v curl >/dev/null 2>&1; then
		echo "curl is required to call the marloth-win build agent." >&2
		return 2
	fi

	if ! curl -sfS --connect-timeout 2 --max-time 5 "${base}/health" >/dev/null; then
		echo "marloth-win build agent is not reachable at ${base}." >&2
		echo "Ensure marloth-win is running (devcontainer.json runServices) and Rebuild/Reopen the container." >&2
		return 2
	fi

	echo "Triggering Windows natives build via ${base}/build ..."
	# Stream response body to stdout; HTTP status reflects build exit (200/500) or 409 busy.
	local http_code
	http_code="$(
		curl -sS -X POST \
			--connect-timeout 5 \
			--max-time 3600 \
			-w "\n%{http_code}" \
			"${base}/build"
	)"
	local body status
	body="$(printf '%s' "${http_code}" | sed '$d')"
	status="$(printf '%s' "${http_code}" | tail -n1)"
	printf '%s\n' "${body}"
	case "${status}" in
	200) return 0 ;;
	409)
		echo "Windows natives build already in progress on marloth-win." >&2
		return 1
		;;
	*)
		echo "marloth-win build agent returned HTTP ${status}." >&2
		return 1
		;;
	esac
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
		echo "Rebuild: Dev Containers → Rebuild and Reopen in Container." >&2
		exit 2
	fi
	if ! "${COMPOSE[@]}" exec -T "${MARLOTH_SERVICE}" sh -c 'command -v dotnet >/dev/null' 2>/dev/null; then
		echo "${MARLOTH_SERVICE} is missing dotnet." >&2
		echo "Rebuild: Dev Containers → Rebuild and Reopen in Container." >&2
		exit 2
	fi

	cmd_exec "${MARLOTH_SERVICE}" bash -lc \
		"cd /workspaces/marloth && ./scripts/run_godot_functional_tests.sh $(printf '%q ' "$@")"
}

cmd_windows_build() {
	local mode="${1:-dist}"
	shift || true
	if [[ $# -gt 0 ]]; then
		echo "windows-${mode} does not take extra arguments." >&2
		exit 2
	fi
	case "${mode}" in
	dist|project) ;;
	*)
		echo "Unknown Windows mode: ${mode} (expected dist or project)." >&2
		exit 2
		;;
	esac

	if in_marloth_container; then
		exec "${ROOT}/scripts/build-windows.sh" "${mode}"
	fi

	# Outside attach: ensure both services, then orchestrate on marloth (natives agent + mode).
	require_docker
	echo "Ensuring ${MARLOTH_SERVICE} and ${WIN_SERVICE} are up ..."
	cmd_up "${MARLOTH_SERVICE}" "${WIN_SERVICE}"
	local i
	for i in 1 2 3 4 5 6 7 8 9 10; do
		if "${COMPOSE[@]}" exec -T "${WIN_SERVICE}" curl -sfS --connect-timeout 1 "http://127.0.0.1:${MARLOTH_WIN_AGENT_PORT:-9876}/health" >/dev/null 2>&1; then
			break
		fi
		sleep 1
	done
	if ! "${COMPOSE[@]}" exec -T "${MARLOTH_SERVICE}" test -x "${DEFAULT_GODOT_BIN}" 2>/dev/null; then
		echo "${MARLOTH_SERVICE} is missing ${DEFAULT_GODOT_BIN}." >&2
		echo "Rebuild: Dev Containers → Rebuild and Reopen in Container." >&2
		exit 2
	fi
	cmd_exec "${MARLOTH_SERVICE}" bash -lc "cd /workspaces/marloth && ./scripts/build-windows.sh $(printf '%q' "${mode}")"
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
	windows-dist | windows-build)
		cmd_windows_build dist "$@"
		;;
	windows-project)
		cmd_windows_build project "$@"
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
