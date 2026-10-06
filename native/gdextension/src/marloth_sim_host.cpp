#include "marloth_sim_host.h"

#include "marloth.h"

#include <godot_cpp/classes/engine.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

using namespace godot;

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
	ClassDB::bind_method(D_METHOD("set_demo_mesh_path", "path"), &MarlothSimHost::set_demo_mesh_path);
	ClassDB::bind_method(D_METHOD("get_demo_mesh_path"), &MarlothSimHost::get_demo_mesh_path);
	ClassDB::bind_method(D_METHOD("tick_once", "dt"), &MarlothSimHost::tick_once);
	ClassDB::bind_method(D_METHOD("get_sim_tick"), &MarlothSimHost::get_sim_tick);

	ADD_PROPERTY(PropertyInfo(Variant::BOOL, "auto_tick"), "set_auto_tick", "get_auto_tick");
	ADD_PROPERTY(PropertyInfo(Variant::NODE_PATH, "demo_mesh_path"), "set_demo_mesh_path", "get_demo_mesh_path");
}

void MarlothSimHost::_ready() {
	if (Engine::get_singleton()->is_editor_hint()) {
		return;
	}
	if (marloth_sim_create(&sim) != MARLOTH_OK || !sim) {
		UtilityFunctions::push_error("MarlothSimHost: marloth_sim_create failed: ", marloth_last_error());
		return;
	}
	if (!demo_mesh_path.is_empty()) {
		demo_mesh = Object::cast_to<MeshInstance3D>(get_node_or_null(demo_mesh_path));
	}
}

void MarlothSimHost::_process(double delta) {
	if (!auto_tick || !sim) {
		return;
	}
	tick_once(delta);
}

void MarlothSimHost::tick_once(double dt) {
	if (!sim) {
		return;
	}
	// Services stub: empty reply each frame.
	marloth_sim_apply_service_reply(sim, nullptr, 0);

	MarlothInputFrame input{};
	input.dt_seconds = static_cast<float>(dt);
	// Client role: axes left empty for now (no gameplay input wiring yet).
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
	if (demo_mesh && entities && count > 0) {
		for (size_t i = 0; i < count; i++) {
			if (entities[i].entity_id == 1) {
				demo_mesh->set_position(Vector3(entities[i].pos_x, entities[i].pos_y, entities[i].pos_z));
				demo_mesh->set_rotation(Vector3(0.0f, entities[i].yaw, 0.0f));
				break;
			}
		}
	}
}

void MarlothSimHost::set_auto_tick(bool p_auto_tick) {
	auto_tick = p_auto_tick;
}

bool MarlothSimHost::get_auto_tick() const {
	return auto_tick;
}

void MarlothSimHost::set_demo_mesh_path(const NodePath &p_path) {
	demo_mesh_path = p_path;
}

NodePath MarlothSimHost::get_demo_mesh_path() const {
	return demo_mesh_path;
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
