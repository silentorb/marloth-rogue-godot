#!/usr/bin/env bash
# Post-export audit of a Godot Windows Desktop dist under $MARLOTH_WIN_OUT/dist.
# Sections: sanity (expected PASS) vs hypothesis (open Windows load issues).
set -euo pipefail

ROOT_DEFAULT="${MARLOTH_WIN_OUT:-/mnt/e/dev/games/marloth-godot}/dist"
EXPORT_DIR=""
STRICT="${VERIFY_MARGEN_STRICT:-0}"
JSON_OUT=0
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MARLOTH_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
MARGEN_GODOT_ROOT="${MARGEN_GODOT_ROOT:-}"
if [[ -z "${MARGEN_GODOT_ROOT}" ]]; then
	if [[ -d "${MARLOTH_ROOT}/../margen-godot" ]]; then
		MARGEN_GODOT_ROOT="$(cd "${MARLOTH_ROOT}/../margen-godot" && pwd)"
	elif [[ -d /home/chris/dev/margen-godot ]]; then
		MARGEN_GODOT_ROOT="/home/chris/dev/margen-godot"
	fi
fi

usage() {
	echo "Usage: $0 [--strict] [--json] [EXPORT_DIR]" >&2
	echo "  EXPORT_DIR defaults to \$MARLOTH_WIN_OUT/dist or /mnt/e/dev/games/marloth-godot/dist" >&2
}

while [[ $# -gt 0 ]]; do
	case "$1" in
		--strict) STRICT=1; shift ;;
		--json) JSON_OUT=1; shift ;;
		-h|--help) usage; exit 0 ;;
		*)
			if [[ -n "${EXPORT_DIR}" ]]; then
				echo "Unexpected argument: $1" >&2
				usage
				exit 2
			fi
			EXPORT_DIR="$1"
			shift
			;;
	esac
done

if [[ -z "${EXPORT_DIR}" ]]; then
	EXPORT_DIR="${ROOT_DEFAULT}"
fi

EXE="${EXPORT_DIR}/marloth.exe"
PCK="${EXPORT_DIR}/marloth.pck"
GDEXT="${MARLOTH_ROOT}/addons/margen/margen.gdextension"
SRC_BIN="${MARLOTH_ROOT}/addons/margen/bin"
SRC_DEBUG_DLL="${SRC_BIN}/libmargen_godot.windows.template_debug.x86_64.dll"
SRC_RELEASE_DLL="${SRC_BIN}/libmargen_godot.windows.template_release.x86_64.dll"
SRC_FFI_DLL="${SRC_BIN}/margen_ffi.dll"
ENTRY_SYMBOL="margen_godot_library_init"

OBJDUMP=""
if command -v llvm-objdump >/dev/null 2>&1; then
	OBJDUMP="llvm-objdump"
elif command -v objdump >/dev/null 2>&1; then
	OBJDUMP="objdump"
fi

pass=0
warn=0
fail=0
declare -a lines=()

report() {
	local level="$1"
	local section="$2"
	local msg="$3"
	lines+=("${level}|${section}|${msg}")
	case "${level}" in
		PASS) pass=$((pass + 1)) ;;
		WARN) warn=$((warn + 1)) ;;
		FAIL) fail=$((fail + 1)) ;;
	esac
}

find_export_dll() {
	local name="$1"
	# Prefer next to the exe (Godot [dependencies] empty target), then recurse once.
	if [[ -f "${EXPORT_DIR}/${name}" ]]; then
		echo "${EXPORT_DIR}/${name}"
		return 0
	fi
	local hit
	hit="$(find "${EXPORT_DIR}" -maxdepth 3 -type f -name "${name}" 2>/dev/null | head -n1 || true)"
	if [[ -n "${hit}" ]]; then
		echo "${hit}"
		return 0
	fi
	return 1
}

if [[ ! -d "${EXPORT_DIR}" ]]; then
	report FAIL sanity "export dir missing: ${EXPORT_DIR}"
else
	report PASS sanity "export dir exists: ${EXPORT_DIR}"
fi

if [[ ! -f "${EXE}" ]]; then
	report FAIL sanity "missing ${EXE}"
else
	report PASS sanity "marloth.exe present ($(wc -c <"${EXE}") bytes)"
fi

data_dir=""
if [[ -d "${EXPORT_DIR}" ]]; then
	data_dir="$(find "${EXPORT_DIR}" -maxdepth 1 -type d -name 'data_*_windows_*' | head -n1 || true)"
fi
if [[ -z "${data_dir}" ]]; then
	report FAIL sanity "missing data_*_windows_* managed assembly directory"
else
	report PASS sanity "managed data dir present: $(basename "${data_dir}")"
	if find "${data_dir}" -maxdepth 2 -type f -name 'marloth.dll' | grep -q .; then
		report PASS sanity "marloth.dll present in export data dir"
	else
		report FAIL sanity "marloth.dll missing under ${data_dir}"
	fi
fi

if [[ ! -f "${PCK}" ]]; then
	# embed_pck may be enabled in some presets; warn rather than fail.
	if [[ -f "${EXE}" ]]; then
		report WARN sanity "marloth.pck absent (may be embedded in exe)"
	else
		report FAIL sanity "missing ${PCK}"
	fi
else
	report PASS sanity "marloth.pck present ($(wc -c <"${PCK}") bytes)"
fi

if [[ ! -f "${GDEXT}" ]]; then
	report FAIL sanity "missing workspace ${GDEXT}"
else
	report PASS sanity "workspace margen.gdextension present"
	if grep -q 'windows.debug.x86_64' "${GDEXT}"; then
		report PASS sanity "windows.debug.x86_64 library key present"
	else
		report FAIL sanity "windows.debug.x86_64 library key missing"
	fi
	if grep -q "${ENTRY_SYMBOL}" "${GDEXT}"; then
		report PASS sanity "entry_symbol=${ENTRY_SYMBOL}"
	else
		report FAIL sanity "entry_symbol mismatch (expected ${ENTRY_SYMBOL})"
	fi
fi

check_dll() {
	local path="$1"
	local label="$2"
	if [[ ! -f "${path}" ]]; then
		report FAIL sanity "missing ${label}: ${path}"
		return 1
	fi
	if [[ ! -s "${path}" ]]; then
		report FAIL sanity "zero-byte ${label}: ${path}"
		return 1
	fi
	report PASS sanity "${label} present ($(wc -c <"${path}") bytes)"
	return 0
}

EXPORT_DEBUG_DLL=""
EXPORT_RELEASE_DLL=""
EXPORT_FFI_DLL=""
if EXPORT_DEBUG_DLL="$(find_export_dll "libmargen_godot.windows.template_debug.x86_64.dll")"; then
	check_dll "${EXPORT_DEBUG_DLL}" "exported debug extension DLL"
	debug_ok=$?
else
	report WARN sanity "exported debug extension DLL not found under ${EXPORT_DIR}"
	debug_ok=1
fi
if EXPORT_RELEASE_DLL="$(find_export_dll "libmargen_godot.windows.template_release.x86_64.dll")"; then
	check_dll "${EXPORT_RELEASE_DLL}" "exported release extension DLL" || true
else
	report WARN sanity "exported release extension DLL absent (expected when BUILD_TYPE=Debug only)"
fi
if EXPORT_FFI_DLL="$(find_export_dll "margen_ffi.dll")"; then
	check_dll "${EXPORT_FFI_DLL}" "exported margen_ffi.dll"
	ffi_ok=$?
else
	report FAIL sanity "exported margen_ffi.dll not found under ${EXPORT_DIR}"
	ffi_ok=1
fi

# Prefer PE checks on exported DLL; fall back to workspace install used as export input.
PE_DLL="${EXPORT_DEBUG_DLL}"
if [[ -z "${PE_DLL}" || ! -f "${PE_DLL}" ]]; then
	PE_DLL="${SRC_DEBUG_DLL}"
fi
if [[ -n "${OBJDUMP}" && -f "${PE_DLL}" ]]; then
	pe_tmp="$(mktemp)"
	# objdump PE output can contain NULs; keep it in a file so bash vars are not truncated.
	"${OBJDUMP}" -f "${PE_DLL}" >"${pe_tmp}.hdr" 2>/dev/null || true
	"${OBJDUMP}" -p "${PE_DLL}" >"${pe_tmp}" 2>/dev/null || true
	if grep -qi 'pei-x86-64\|pe-x86-64\|x86-64' "${pe_tmp}.hdr"; then
		report PASS sanity "debug DLL is PE x86_64 (${PE_DLL})"
	else
		report FAIL sanity "debug DLL PE machine type unexpected (${PE_DLL})"
	fi
	if grep -q "${ENTRY_SYMBOL}" "${pe_tmp}"; then
		report PASS sanity "exports ${ENTRY_SYMBOL}"
	else
		report FAIL sanity "does not export ${ENTRY_SYMBOL}"
	fi

	mingw_hits=$(grep -iE 'DLL Name: *(libstdc\+\+-6|libgcc_s_seh-1|libwinpthread-1)\.dll' "${pe_tmp}" || true)
	if [[ -n "${mingw_hits}" ]]; then
		report FAIL hypothesis "debug DLL still imports MinGW runtimes: ${mingw_hits}"
	else
		report PASS hypothesis "debug DLL has no MinGW runtime DLL imports"
	fi

	vcrun_hits=$(grep -iE 'DLL Name: *(VCRUNTIME140|MSVCP140|VCRUNTIME140_1)\.dll' "${pe_tmp}" || true)
	if [[ -n "${vcrun_hits}" ]]; then
		report WARN hypothesis "debug DLL imports MSVC CRT DLLs (expected static /MT): ${vcrun_hits}"
	else
		report PASS hypothesis "debug DLL has no VCRUNTIME/MSVCP140 DLL imports (static MSVC CRT)"
	fi

	ffi_import=$(grep -i 'DLL Name: *margen_ffi\.dll' "${pe_tmp}" || true)
	if [[ -n "${ffi_import}" ]]; then
		report PASS hypothesis "extension imports margen_ffi.dll (export [dependencies] should place it beside the exe)"
	else
		report WARN hypothesis "extension does not import margen_ffi.dll by name"
	fi
	rm -f "${pe_tmp}" "${pe_tmp}.hdr"
elif [[ -z "${OBJDUMP}" ]]; then
	report WARN sanity "objdump unavailable; skipped PE/export/import checks"
elif [[ ! -f "${PE_DLL}" ]]; then
	report WARN sanity "no debug DLL for PE checks (export or ${SRC_DEBUG_DLL})"
fi

if [[ -f "${SRC_DEBUG_DLL}" ]]; then
	report PASS hypothesis "workspace source debug DLL present for export input"
else
	report WARN hypothesis "workspace source debug DLL missing: ${SRC_DEBUG_DLL}"
fi
if [[ -f "${SRC_FFI_DLL}" ]]; then
	report PASS hypothesis "workspace source margen_ffi.dll present for export input"
else
	report WARN hypothesis "workspace source margen_ffi.dll missing: ${SRC_FFI_DLL}"
fi
if [[ -f "${SRC_RELEASE_DLL}" ]]; then
	report PASS hypothesis "workspace source release DLL present"
fi

if [[ -f "${GDEXT}" ]]; then
	keys=$(awk '/^\[libraries\]/{p=1;next} /^\[/{p=0} p && /=/{print $1}' "${GDEXT}" || true)
	if echo "${keys}" | grep -qx 'windows.debug.x86_64'; then
		report PASS hypothesis "windows.debug.x86_64 is a candidate for debug export feature tags"
	else
		report FAIL hypothesis "no windows.debug.x86_64 key for debug export feature set"
	fi
fi

if [[ -n "${MARGEN_GODOT_ROOT}" && -x "${MARGEN_GODOT_ROOT}/scripts/verify-godot-cpp-api.sh" ]]; then
	api_out=$("${MARGEN_GODOT_ROOT}/scripts/verify-godot-cpp-api.sh" "${GODOT_VERSION:-4.6.1}" 2>&1 || true)
	while IFS= read -r line; do
		[[ -z "${line}" ]] && continue
		[[ "${line}" == *"="* && "${line}" != *": "* ]] && continue
		[[ "${line}" == *"----"* ]] && continue
		[[ "${line}" == margen-godot* ]] && continue
		if [[ "${line}" == PASS:* ]]; then
			report PASS hypothesis "api: ${line#PASS: }"
		elif [[ "${line}" == WARN:* ]]; then
			report WARN hypothesis "api: ${line#WARN: }"
		elif [[ "${line}" == FAIL:* ]]; then
			report FAIL hypothesis "api: ${line#FAIL: }"
		fi
	done <<<"${api_out}"
else
	report WARN hypothesis "margen-godot verify-godot-cpp-api.sh not found; skipped API audit"
fi

report WARN hypothesis "run dist/marloth.exe on Windows; use scripts/windows/verify-margen-extension.ps1 when debugging editor/project DLL loads"

if [[ "${JSON_OUT}" -eq 1 ]]; then
	printf '{'
	printf '"export_dir":"%s",' "${EXPORT_DIR}"
	printf '"pass":%s,' "${pass}"
	printf '"warn":%s,' "${warn}"
	printf '"fail":%s,' "${fail}"
	printf '"lines":['
	first=1
	for line in "${lines[@]}"; do
		if [[ ${first} -eq 1 ]]; then first=0; else printf ','; fi
		esc=${line//\\/\\\\}
		esc=${esc//\"/\\\"}
		printf '"%s"' "${esc}"
	done
	printf ']}\n'
else
	echo "margen Windows dist audit: ${EXPORT_DIR}"
	echo "============================================================="
	echo "SANITY"
	for line in "${lines[@]}"; do
		IFS='|' read -r level section msg <<<"${line}"
		[[ "${section}" == sanity ]] && echo "  ${level}: ${msg}"
	done
	echo "HYPOTHESIS"
	for line in "${lines[@]}"; do
		IFS='|' read -r level section msg <<<"${line}"
		[[ "${section}" == hypothesis ]] && echo "  ${level}: ${msg}"
	done
	echo "============================================================="
	echo "PASS=${pass} WARN=${warn} FAIL=${fail}"
fi

if [[ "${STRICT}" -eq 1 ]]; then
	if [[ "${fail}" -gt 0 || "${warn}" -gt 0 ]]; then
		exit 1
	fi
	exit 0
fi

if [[ "${fail}" -gt 0 ]]; then
	exit 1
fi
exit 0
