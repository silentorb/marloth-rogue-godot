#pragma once

#include "session_bootstrap.h"

#include <godot_cpp/classes/character_body3d.hpp>
#include <godot_cpp/classes/node.hpp>
#include <godot_cpp/classes/packed_scene.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/object_id.hpp>

struct MarlothSim;

namespace godot {

/// Thin autoload: holds sim/session roots, init/deinit, and minimal session APIs.
class MarlothGlobal : public Node {
	GDCLASS(MarlothGlobal, Node);

	static MarlothGlobal *singleton;

	MarlothSim *sim = nullptr;
	bool session_ready = false;
	bool auto_tick = true;
	Ref<PackedScene> pawn_scene;
	ObjectID pawn_id;
	ObjectID player_controller_id;
	uint32_t local_actor_id = 0;
	ObjectID session_scene_root_id;

protected:
	static void _bind_methods();

public:
	MarlothGlobal();
	~MarlothGlobal() override;

	static MarlothGlobal *get_singleton();

	void _ready() override;
	void _process(double delta) override;
	void _exit_tree() override;

	void start_world_session(Node *scene_root);
	void end_world_session();

	void set_auto_tick(bool p_auto_tick);
	bool get_auto_tick() const;
	bool is_session_ready() const;
	int64_t get_sim_tick() const;

	void tick_once(double dt);

private:
	bool ensure_sim();
	bool ensure_pawn_scene();
	void report_pawn_pose();
	void clear_session_nodes();
	CharacterBody3D *get_live_pawn() const;
	Node *get_live_controller() const;
};

} // namespace godot
