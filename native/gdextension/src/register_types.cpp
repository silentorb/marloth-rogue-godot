#include "register_types.h"

#include "marloth_automation_host.h"
#include "marloth_sim_host.h"

#include <cstdio>

#include <gdextension_interface.h>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/defs.hpp>
#include <godot_cpp/godot.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

using namespace godot;

void initialize_marloth_godot_module(ModuleInitializationLevel p_level) {
	if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
		return;
	}
	GDREGISTER_CLASS(MarlothSimHost);
	GDREGISTER_CLASS(MarlothAutomationHost);
	UtilityFunctions::push_warning("marloth_godot: initialized (MarlothSimHost, MarlothAutomationHost)");
}

void uninitialize_marloth_godot_module(ModuleInitializationLevel p_level) {
	if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
		return;
	}
}

extern "C" {
GDExtensionBool GDE_EXPORT marloth_godot_library_init(
		GDExtensionInterfaceGetProcAddress p_get_proc_address,
		GDExtensionClassLibraryPtr p_library,
		GDExtensionInitialization *r_initialization) {
	fprintf(stderr, "marloth_godot: library_init entered\n");
	fflush(stderr);

	GDExtensionBinding::InitObject init_obj(p_get_proc_address, p_library, r_initialization);
	init_obj.register_initializer(initialize_marloth_godot_module);
	init_obj.register_terminator(uninitialize_marloth_godot_module);
	init_obj.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);
	const GDExtensionBool ok = init_obj.init();
	fprintf(stderr, "marloth_godot: library_init returned %s\n", ok ? "true" : "false");
	fflush(stderr);
	return ok;
}
}
