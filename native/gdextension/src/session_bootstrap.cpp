#include "session_bootstrap.h"

#include "marloth.h"
#include "marloth_player_controller.h"

#include <godot_cpp/classes/camera3d.hpp>
#include <godot_cpp/classes/scene_tree.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

using namespace godot;

namespace marloth {

namespace {

bool is_descendant_of(Node *node, Node *ancestor) {
	while (node != nullptr) {
		if (node == ancestor) {
			return true;
		}
		node = node->get_parent();
	}
	return false;
}

} // namespace

Node3D *find_player_spawn(Node *scene_root) {
	if (scene_root == nullptr) {
		return nullptr;
	}
	SceneTree *tree = scene_root->get_tree();
	if (tree == nullptr) {
		return nullptr;
	}
	TypedArray<Node> nodes = tree->get_nodes_in_group(kPlayerSpawnGroup);
	const int64_t count = nodes.size();
	for (int64_t i = 0; i < count; i++) {
		Node *candidate = Object::cast_to<Node>(nodes[i]);
		if (candidate == nullptr || !is_descendant_of(candidate, scene_root)) {
			continue;
		}
		if (Node3D *spawn = Object::cast_to<Node3D>(candidate)) {
			return spawn;
		}
	}
	return nullptr;
}

void godot_to_sim_pose(
		const Vector3 &origin,
		float godot_yaw_y,
		float &out_x,
		float &out_y,
		float &out_z,
		float &out_yaw) {
	// Inverse of sim (x,y,z) -> Godot (x,z,-y); godot_yaw = -sim_yaw.
	out_x = origin.x;
	out_y = -origin.z;
	out_z = origin.y;
	out_yaw = -godot_yaw_y;
}

bool start_local_player_session(
		MarlothSim *sim,
		Node *scene_root,
		const Ref<PackedScene> &pawn_scene,
		LocalPlayerSession &out_session) {
	out_session = LocalPlayerSession{};
	if (sim == nullptr || scene_root == nullptr) {
		UtilityFunctions::push_error("session_bootstrap: sim or scene_root is null.");
		return false;
	}
	Node3D *spawn = find_player_spawn(scene_root);
	if (spawn == nullptr) {
		UtilityFunctions::push_error(
				"session_bootstrap: no '",
				kPlayerSpawnGroup,
				"' group member under scene root; cannot bootstrap local player.");
		return false;
	}
	if (pawn_scene.is_null()) {
		UtilityFunctions::push_error("session_bootstrap: pawn_scene is null; cannot spawn character pawn.");
		return false;
	}

	const Vector3 origin = spawn->get_global_position();
	const float godot_yaw = spawn->get_global_rotation().y;
	MarlothPose pose{};
	godot_to_sim_pose(origin, godot_yaw, pose.x, pose.y, pose.z, pose.yaw);

	uint32_t player_id = 0;
	uint32_t character_id = 0;
	uint32_t actor_id = 0;
	if (marloth_sim_bootstrap_local_player(sim, &pose, &player_id, &character_id, &actor_id) != MARLOTH_OK) {
		UtilityFunctions::push_error(
				"session_bootstrap: bootstrap_local_player failed: ", marloth_last_error());
		return false;
	}
	(void)player_id;
	(void)character_id;

	Node *instance = pawn_scene->instantiate();
	CharacterBody3D *body = Object::cast_to<CharacterBody3D>(instance);
	if (body == nullptr) {
		UtilityFunctions::push_error(
				"session_bootstrap: pawn_scene root must be CharacterBody3D; aborting possession.");
		if (instance != nullptr) {
			instance->queue_free();
		}
		return false;
	}
	body->set_name(kCharacterPawnName);
	body->add_to_group(kCharacterPawnGroup);
	scene_root->add_child(body);
	body->set_global_position(origin);
	body->set_rotation(Vector3(0.0f, godot_yaw, 0.0f));

	MarlothPlayerController *controller = memnew(MarlothPlayerController);
	controller->set_name("PlayerController");
	controller->set_actor_id(actor_id);
	scene_root->add_child(controller);
	controller->possess(body);

	if (Camera3D *camera = Object::cast_to<Camera3D>(body->get_node_or_null(NodePath("Camera3D")))) {
		camera->make_current();
	}

	out_session.pawn = body;
	out_session.player_controller = controller;
	out_session.actor_id = actor_id;
	return true;
}

} // namespace marloth
