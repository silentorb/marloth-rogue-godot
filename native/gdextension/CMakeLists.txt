cmake_minimum_required(VERSION 3.17)

project(marloth_godot VERSION 0.1.0 LANGUAGES CXX)

if(NOT CMAKE_BUILD_TYPE)
	set(CMAKE_BUILD_TYPE Debug)
endif()

set(MARLOTH_NATIVE_ROOT "${CMAKE_SOURCE_DIR}/.." CACHE PATH "Path to marloth/native")
set(GODOT_CPP_DIR "$ENV{MARGEN_GODOT_ROOT}/godot-cpp" CACHE PATH "Path to godot-cpp")
if(GODOT_CPP_DIR STREQUAL "/godot-cpp" OR GODOT_CPP_DIR STREQUAL "")
	set(GODOT_CPP_DIR "/home/chris/dev/margen-godot/godot-cpp")
endif()
if(DEFINED ENV{MARGEN_GODOT_ROOT} AND NOT "$ENV{MARGEN_GODOT_ROOT}" STREQUAL "")
	set(GODOT_CPP_DIR "$ENV{MARGEN_GODOT_ROOT}/godot-cpp")
endif()

set(MARLOTH_FFI_PROFILE "release" CACHE STRING "marloth_ffi cargo profile")
set(MARLOTH_FFI_TARGET "" CACHE STRING "Optional cargo target triple")

if(CMAKE_BUILD_TYPE STREQUAL "Debug")
	set(MARLOTH_FFI_PROFILE "debug")
endif()

set(_MARLOTH_CARGO_TARGET_ROOT "${MARLOTH_NATIVE_ROOT}/target")
if(DEFINED ENV{CARGO_TARGET_DIR} AND NOT "$ENV{CARGO_TARGET_DIR}" STREQUAL "")
	set(_MARLOTH_CARGO_TARGET_ROOT "$ENV{CARGO_TARGET_DIR}")
endif()

if(MARLOTH_FFI_TARGET STREQUAL "")
	set(MARLOTH_FFI_DIR "${_MARLOTH_CARGO_TARGET_ROOT}/${MARLOTH_FFI_PROFILE}")
else()
	set(MARLOTH_FFI_DIR "${_MARLOTH_CARGO_TARGET_ROOT}/${MARLOTH_FFI_TARGET}/${MARLOTH_FFI_PROFILE}")
endif()

unset(MARLOTH_FFI_LIB CACHE)
find_library(
	MARLOTH_FFI_LIB
	NAMES marloth_ffi.dll marloth_ffi
	PATHS "${MARLOTH_FFI_DIR}"
	REQUIRED
	NO_DEFAULT_PATH
	NO_CMAKE_FIND_ROOT_PATH
)
message(STATUS "Using marloth_ffi from ${MARLOTH_FFI_LIB}")
message(STATUS "Using godot-cpp from ${GODOT_CPP_DIR}")

set(GODOT_CPP_SYSTEM_HEADERS ON CACHE BOOL "" FORCE)
add_subdirectory("${GODOT_CPP_DIR}" "${CMAKE_BINARY_DIR}/godot-cpp")

set(TARGET_NAME "marloth_godot")

add_library(${TARGET_NAME} SHARED
	src/register_types.cpp
	src/marloth_sim_host.cpp
	src/marloth_automation_host.cpp
)

target_include_directories(${TARGET_NAME} PRIVATE
	src
	"${MARLOTH_NATIVE_ROOT}/include"
)

target_link_libraries(${TARGET_NAME} PRIVATE
	godot-cpp
	${MARLOTH_FFI_LIB}
)

if(NOT WIN32)
	target_link_libraries(${TARGET_NAME} PRIVATE dl m pthread)
endif()

get_target_property(GODOTCPP_SUFFIX godot-cpp GODOTCPP_SUFFIX)

set(OUTPUT_DIR "${CMAKE_SOURCE_DIR}/bin/")
file(MAKE_DIRECTORY "${OUTPUT_DIR}")

set_target_properties(
	${TARGET_NAME}
	PROPERTIES
		CXX_STANDARD 17
		CXX_EXTENSIONS OFF
		POSITION_INDEPENDENT_CODE ON
		BUILD_RPATH_USE_ORIGIN ON
		BUILD_RPATH "\$ORIGIN"
		INSTALL_RPATH "\$ORIGIN"
		LIBRARY_OUTPUT_DIRECTORY "${OUTPUT_DIR}"
		RUNTIME_OUTPUT_DIRECTORY "${OUTPUT_DIR}"
		PREFIX "lib"
		OUTPUT_NAME "marloth_godot${GODOTCPP_SUFFIX}"
)

if(WIN32)
	set(_MARLOTH_FFI_RUNTIME "${MARLOTH_FFI_DIR}/marloth_ffi.dll")
	if(NOT EXISTS "${_MARLOTH_FFI_RUNTIME}")
		message(FATAL_ERROR "Expected Windows DLL at ${_MARLOTH_FFI_RUNTIME}")
	endif()
	set(_MARLOTH_FFI_DEST "${OUTPUT_DIR}/marloth_ffi.dll")
else()
	set(_MARLOTH_FFI_RUNTIME "${MARLOTH_FFI_LIB}")
	set(_MARLOTH_FFI_DEST "${OUTPUT_DIR}/libmarloth_ffi.so")
endif()

add_custom_command(
	TARGET ${TARGET_NAME}
	POST_BUILD
	COMMAND ${CMAKE_COMMAND} -E copy_if_different
		"${_MARLOTH_FFI_RUNTIME}"
		"${_MARLOTH_FFI_DEST}"
	COMMENT "Copying marloth_ffi into bin/"
)
