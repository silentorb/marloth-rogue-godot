#include "marloth_world_scene.h"

#include "marloth_global.h"

#include <godot_cpp/classes/engine.hpp>
#include <godot_cpp/classes/scene_tree.hpp>
#include <godot_cpp/classes/window.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

using namespace godot;

void MarlothWorldScene::_bind_methods() {
}

void MarlothWorldScene::_ready() {
	if (Engine::get_singleton()->is_editor_hint()) {
		return;
	}
	// Delay one frame so MargenWorldMesh generation and player_spawn markers exist.
	kickoff_scheduled = true;
	set_process(true);
}

void MarlothWorldScene::_process(double delta) {
	(void)delta;
	if (!kickoff_scheduled) {
		return;
	}
	kickoff_scheduled = false;
	set_process(false);
	kickstart_session();
}

Node *MarlothWorldScene::resolve_scene_root() const {
	// WorldScene is a direct child of the world scene root.
	if (Node *parent = get_parent()) {
		return parent;
	}
	if (SceneTree *tree = get_tree()) {
		return tree->get_current_scene();
	}
	return nullptr;
}

void MarlothWorldScene::kickstart_session() {
	MarlothGlobal *global = MarlothGlobal::get_singleton();
	if (global == nullptr) {
		UtilityFunctions::push_error("MarlothWorldScene: MarlothGlobal autoload is not available.");
		return;
	}
	Node *scene_root = resolve_scene_root();
	if (scene_root == nullptr) {
		UtilityFunctions::push_error("MarlothWorldScene: could not resolve scene root for session start.");
		return;
	}
	global->start_world_session(scene_root);
}
