#pragma once

#include "marloth_player_controller.h"

#include <godot_cpp/classes/character_body3d.hpp>
#include <godot_cpp/classes/node3d.hpp>
#include <godot_cpp/classes/packed_scene.hpp>
#include <godot_cpp/core/class_db.hpp>

struct MarlothSim;

namespace godot {

/// Client-role bridge: boots local player pawn, ticks Rust sim, reports actor pose.
class MarlothSimHost : public Node3D {
	GDCLASS(MarlothSimHost, Node3D);

	MarlothSim *sim = nullptr;
	bool auto_tick = true;
	Ref<PackedScene> pawn_scene;
	CharacterBody3D *pawn = nullptr;
	MarlothPlayerController *player_controller = nullptr;
	uint32_t local_actor_id = 0;
	bool session_ready = false;

protected:
	static void _bind_methods();

public:
	MarlothSimHost();
	~MarlothSimHost() override;

	void _ready() override;
	void _process(double delta) override;

	void set_auto_tick(bool p_auto_tick);
	bool get_auto_tick() const;

	void set_pawn_scene(const Ref<PackedScene> &p_scene);
	Ref<PackedScene> get_pawn_scene() const;

	void tick_once(double dt);
	int64_t get_sim_tick() const;
	bool is_session_ready() const;

private:
	bool try_bootstrap_session();
	void report_pawn_pose();
	static void godot_to_sim_pose(const Vector3 &origin, float godot_yaw_y, float &out_x, float &out_y, float &out_z, float &out_yaw);
};

} // namespace godot
