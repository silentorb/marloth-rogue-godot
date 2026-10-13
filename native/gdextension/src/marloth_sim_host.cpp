#include "marloth_sim_host.h"

#include "marloth.h"

#include <godot_cpp/classes/camera3d.hpp>
#include <godot_cpp/classes/engine.hpp>
#include <godot_cpp/classes/node.hpp>
#include <godot_cpp/classes/scene_tree.hpp>
#include <godot_cpp/classes/window.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

using namespace godot;

namespace {
constexpr const char *kSpawnPathFromRoot =
		"MargenWorldDebug/MargenWorldMesh/Actors/PlayerSpawnLocation";
constexpr const char *kPawnName = "CharacterPawn";
constexpr const char *kPawnGroup = "character_pawn";
} // namespace

MarlothSimHost::MarlothSimHost() = default;

MarlothSimHost::~MarlothSimHost() {
	if (sim) {
		marloth_sim_destroy(sim);
		sim = nullptr;
	}
}

void MarlothSimHost::_bind_methods() {
	ClassDB::bind_method(D_METHOD("set_auto_tick", "auto_tick"), &MarlothSimHost::set_auto_tick);
	ClassDB::bind_method(D_METHOD("get_auto_tick"), &MarlothSimHost::get_auto_tick);
	ClassDB::bind_method(D_METHOD("set_pawn_scene", "scene"), &MarlothSimHost::set_pawn_scene);
	ClassDB::bind_method(D_METHOD("get_pawn_scene"), &MarlothSimHost::get_pawn_scene);
	ClassDB::bind_method(D_METHOD("tick_once", "dt"), &MarlothSimHost::tick_once);
	ClassDB::bind_method(D_METHOD("get_sim_tick"), &MarlothSimHost::get_sim_tick);
	ClassDB::bind_method(D_METHOD("is_session_ready"), &MarlothSimHost::is_session_ready);

	ADD_PROPERTY(PropertyInfo(Variant::BOOL, "auto_tick"), "set_auto_tick", "get_auto_tick");
	ADD_PROPERTY(
			PropertyInfo(
					Variant::OBJECT,
					"pawn_scene",
					PROPERTY_HINT_RESOURCE_TYPE,
					"PackedScene"),
			"set_pawn_scene",
			"get_pawn_scene");
}

void MarlothSimHost::_ready() {
	if (Engine::get_singleton()->is_editor_hint()) {
		return;
	}
	if (marloth_sim_create(&sim) != MARLOTH_OK || !sim) {
		UtilityFunctions::push_error("MarlothSimHost: marloth_sim_create failed: ", marloth_last_error());
		return;
	}
	if (!try_bootstrap_session()) {
		// Explicit failure already logged; leave session_ready false (no half-init possession).
		return;
	}
}

void MarlothSimHost::_process(double delta) {
	if (!auto_tick || !sim) {
		return;
	}
	tick_once(delta);
}

bool MarlothSimHost::try_bootstrap_session() {
	Node *spawn_node = nullptr;
	if (Node *parent = get_parent()) {
		spawn_node = parent->get_node_or_null(NodePath(kSpawnPathFromRoot));
	}
	if (!spawn_node) {
		spawn_node = get_node_or_null(NodePath(String("../") + kSpawnPathFromRoot));
	}
	if (!spawn_node) {
		if (SceneTree *tree = get_tree()) {
			if (Window *root_window = tree->get_root()) {
				spawn_node = root_window->find_child("PlayerSpawnLocation", true, false);
			}
		}
	}
	Node3D *spawn = Object::cast_to<Node3D>(spawn_node);
	if (!spawn) {
		UtilityFunctions::push_error(
				"MarlothSimHost: PlayerSpawnLocation not found; cannot bootstrap local player.");
		return false;
	}
	if (pawn_scene.is_null()) {
		UtilityFunctions::push_error("MarlothSimHost: pawn_scene is not set; cannot spawn character pawn.");
		return false;
	}

	const Vector3 origin = spawn->get_global_position();
	const float godot_yaw = spawn->get_global_rotation().y;
	float sx = 0.0f;
	float sy = 0.0f;
	float sz = 0.0f;
	float syaw = 0.0f;
	godot_to_sim_pose(origin, godot_yaw, sx, sy, sz, syaw);

	MarlothPose pose{};
	pose.x = sx;
	pose.y = sy;
	pose.z = sz;
	pose.yaw = syaw;

	uint32_t player_id = 0;
	uint32_t character_id = 0;
	uint32_t actor_id = 0;
	if (marloth_sim_bootstrap_local_player(sim, &pose, &player_id, &character_id, &actor_id) != MARLOTH_OK) {
		UtilityFunctions::push_error(
				"MarlothSimHost: bootstrap_local_player failed: ", marloth_last_error());
		return false;
	}
	local_actor_id = actor_id;
	(void)player_id;
	(void)character_id;

	Node *instance = pawn_scene->instantiate();
	CharacterBody3D *body = Object::cast_to<CharacterBody3D>(instance);
	if (!body) {
		UtilityFunctions::push_error(
				"MarlothSimHost: pawn_scene root must be CharacterBody3D; aborting possession.");
		if (instance) {
			instance->queue_free();
		}
		return false;
	}
	body->set_name(kPawnName);
	body->add_to_group(kPawnGroup);
	add_child(body);
	body->set_global_position(origin);
	body->set_rotation(Vector3(0.0f, godot_yaw, 0.0f));
	pawn = body;

	player_controller = memnew(MarlothPlayerController);
	player_controller->set_name("PlayerController");
	player_controller->set_actor_id(local_actor_id);
	add_child(player_controller);
	player_controller->possess(pawn);

	if (Camera3D *camera = Object::cast_to<Camera3D>(pawn->get_node_or_null(NodePath("Camera3D")))) {
		camera->make_current();
	}

	session_ready = true;
	return true;
}

void MarlothSimHost::godot_to_sim_pose(
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

void MarlothSimHost::report_pawn_pose() {
	if (!sim || !pawn || local_actor_id == 0) {
		return;
	}
	const Vector3 origin = pawn->get_global_position();
	const float godot_yaw = pawn->get_global_rotation().y;
	MarlothPose pose{};
	godot_to_sim_pose(origin, godot_yaw, pose.x, pose.y, pose.z, pose.yaw);
	if (marloth_sim_set_actor_pose(sim, local_actor_id, &pose) != MARLOTH_OK) {
		UtilityFunctions::push_error("MarlothSimHost: set_actor_pose failed: ", marloth_last_error());
	}
}

void MarlothSimHost::tick_once(double dt) {
	if (!sim) {
		return;
	}
	report_pawn_pose();

	marloth_sim_apply_service_reply(sim, nullptr, 0);

	MarlothInputFrame input{};
	input.dt_seconds = static_cast<float>(dt);
	const uint8_t *req = nullptr;
	size_t req_len = 0;
	if (marloth_sim_step(sim, &input, &req, &req_len) != MARLOTH_OK) {
		UtilityFunctions::push_error("MarlothSimHost: step failed: ", marloth_last_error());
		return;
	}
	(void)req;
	(void)req_len;

	uint64_t tick = 0;
	const MarlothSnapshotEntity *entities = nullptr;
	size_t count = 0;
	if (marloth_sim_snapshot(sim, &tick, &entities, &count) != MARLOTH_OK) {
		UtilityFunctions::push_error("MarlothSimHost: snapshot failed: ", marloth_last_error());
		return;
	}
	(void)tick;
	(void)entities;
	(void)count;
}

void MarlothSimHost::set_auto_tick(bool p_auto_tick) {
	auto_tick = p_auto_tick;
}

bool MarlothSimHost::get_auto_tick() const {
	return auto_tick;
}

void MarlothSimHost::set_pawn_scene(const Ref<PackedScene> &p_scene) {
	pawn_scene = p_scene;
}

Ref<PackedScene> MarlothSimHost::get_pawn_scene() const {
	return pawn_scene;
}

bool MarlothSimHost::is_session_ready() const {
	return session_ready;
}

int64_t MarlothSimHost::get_sim_tick() const {
	if (!sim) {
		return 0;
	}
	uint64_t tick = 0;
	const MarlothSnapshotEntity *entities = nullptr;
	size_t count = 0;
	if (marloth_sim_snapshot(const_cast<MarlothSim *>(sim), &tick, &entities, &count) != MARLOTH_OK) {
		return 0;
	}
	(void)entities;
	(void)count;
	return static_cast<int64_t>(tick);
}
