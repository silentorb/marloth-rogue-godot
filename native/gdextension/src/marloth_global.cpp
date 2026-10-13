#include "marloth_global.h"

#include "marloth.h"

#include <godot_cpp/classes/engine.hpp>
#include <godot_cpp/classes/resource_loader.hpp>
#include <godot_cpp/core/object.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

using namespace godot;

MarlothGlobal *MarlothGlobal::singleton = nullptr;

MarlothGlobal::MarlothGlobal() {
	singleton = this;
}

MarlothGlobal::~MarlothGlobal() {
	end_world_session();
	if (sim) {
		marloth_sim_destroy(sim);
		sim = nullptr;
	}
	if (singleton == this) {
		singleton = nullptr;
	}
}

MarlothGlobal *MarlothGlobal::get_singleton() {
	return singleton;
}

void MarlothGlobal::_bind_methods() {
	ClassDB::bind_method(D_METHOD("start_world_session", "scene_root"), &MarlothGlobal::start_world_session);
	ClassDB::bind_method(D_METHOD("end_world_session"), &MarlothGlobal::end_world_session);
	ClassDB::bind_method(D_METHOD("set_auto_tick", "auto_tick"), &MarlothGlobal::set_auto_tick);
	ClassDB::bind_method(D_METHOD("get_auto_tick"), &MarlothGlobal::get_auto_tick);
	ClassDB::bind_method(D_METHOD("is_session_ready"), &MarlothGlobal::is_session_ready);
	ClassDB::bind_method(D_METHOD("get_sim_tick"), &MarlothGlobal::get_sim_tick);
	ClassDB::bind_method(D_METHOD("tick_once", "dt"), &MarlothGlobal::tick_once);

	ADD_PROPERTY(PropertyInfo(Variant::BOOL, "auto_tick"), "set_auto_tick", "get_auto_tick");
}

void MarlothGlobal::_ready() {
	if (Engine::get_singleton()->is_editor_hint()) {
		return;
	}
	ensure_pawn_scene();
}

void MarlothGlobal::_exit_tree() {
	end_world_session();
}

void MarlothGlobal::_process(double delta) {
	if (!auto_tick || !session_ready || !sim) {
		return;
	}
	tick_once(delta);
}

bool MarlothGlobal::ensure_sim() {
	if (sim) {
		return true;
	}
	if (marloth_sim_create(&sim) != MARLOTH_OK || !sim) {
		UtilityFunctions::push_error("MarlothGlobal: marloth_sim_create failed: ", marloth_last_error());
		sim = nullptr;
		return false;
	}
	return true;
}

bool MarlothGlobal::ensure_pawn_scene() {
	if (pawn_scene.is_valid()) {
		return true;
	}
	Ref<Resource> res = ResourceLoader::get_singleton()->load(marloth::kDefaultPawnScenePath);
	pawn_scene = res;
	if (pawn_scene.is_null()) {
		UtilityFunctions::push_error(
				"MarlothGlobal: failed to load default pawn scene ", marloth::kDefaultPawnScenePath);
		return false;
	}
	return true;
}

void MarlothGlobal::clear_session_nodes() {
	pawn_id = ObjectID();
	player_controller_id = ObjectID();
	local_actor_id = 0;
	session_scene_root_id = ObjectID();
	session_ready = false;
}

CharacterBody3D *MarlothGlobal::get_live_pawn() const {
	return Object::cast_to<CharacterBody3D>(ObjectDB::get_instance(pawn_id));
}

Node *MarlothGlobal::get_live_controller() const {
	return Object::cast_to<Node>(ObjectDB::get_instance(player_controller_id));
}

void MarlothGlobal::start_world_session(Node *scene_root) {
	if (Engine::get_singleton()->is_editor_hint()) {
		return;
	}
	if (scene_root == nullptr) {
		UtilityFunctions::push_error("MarlothGlobal: start_world_session requires a scene_root.");
		return;
	}
	// Scene reloads free old pawns; always tear down before starting again.
	end_world_session();
	if (!ensure_sim() || !ensure_pawn_scene()) {
		return;
	}

	marloth::LocalPlayerSession session;
	if (!marloth::start_local_player_session(sim, scene_root, pawn_scene, session)) {
		// Library already logged; leave session not ready (no half-init).
		return;
	}
	pawn_id = session.pawn ? session.pawn->get_instance_id() : ObjectID();
	player_controller_id =
			session.player_controller ? session.player_controller->get_instance_id() : ObjectID();
	local_actor_id = session.actor_id;
	session_scene_root_id = scene_root->get_instance_id();
	session_ready = true;
}

void MarlothGlobal::end_world_session() {
	if (Node *controller = get_live_controller()) {
		controller->queue_free();
	}
	if (CharacterBody3D *body = get_live_pawn()) {
		body->queue_free();
	}
	clear_session_nodes();
	if (sim) {
		marloth_sim_destroy(sim);
		sim = nullptr;
	}
}

void MarlothGlobal::report_pawn_pose() {
	if (!sim || local_actor_id == 0) {
		return;
	}
	CharacterBody3D *pawn = get_live_pawn();
	if (pawn == nullptr) {
		session_ready = false;
		return;
	}
	const Vector3 origin = pawn->get_global_position();
	const float godot_yaw = pawn->get_global_rotation().y;
	MarlothPose pose{};
	marloth::godot_to_sim_pose(origin, godot_yaw, pose.x, pose.y, pose.z, pose.yaw);
	if (marloth_sim_set_actor_pose(sim, local_actor_id, &pose) != MARLOTH_OK) {
		UtilityFunctions::push_error("MarlothGlobal: set_actor_pose failed: ", marloth_last_error());
	}
}

void MarlothGlobal::tick_once(double dt) {
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
		UtilityFunctions::push_error("MarlothGlobal: step failed: ", marloth_last_error());
		return;
	}
	(void)req;
	(void)req_len;

	uint64_t tick = 0;
	const MarlothSnapshotEntity *entities = nullptr;
	size_t count = 0;
	if (marloth_sim_snapshot(sim, &tick, &entities, &count) != MARLOTH_OK) {
		UtilityFunctions::push_error("MarlothGlobal: snapshot failed: ", marloth_last_error());
		return;
	}
	(void)tick;
	(void)entities;
	(void)count;
}

void MarlothGlobal::set_auto_tick(bool p_auto_tick) {
	auto_tick = p_auto_tick;
}

bool MarlothGlobal::get_auto_tick() const {
	return auto_tick;
}

bool MarlothGlobal::is_session_ready() const {
	return session_ready;
}

int64_t MarlothGlobal::get_sim_tick() const {
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
