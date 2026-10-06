#pragma once

#include <godot_cpp/classes/mesh_instance3d.hpp>
#include <godot_cpp/classes/node3d.hpp>
#include <godot_cpp/core/class_db.hpp>

struct MarlothSim;

namespace godot {

/// Client-role bridge: packs input, ticks Rust sim, applies bulk snapshots.
class MarlothSimHost : public Node3D {
	GDCLASS(MarlothSimHost, Node3D);

	MarlothSim *sim = nullptr;
	bool auto_tick = true;
	NodePath demo_mesh_path;
	MeshInstance3D *demo_mesh = nullptr;

protected:
	static void _bind_methods();

public:
	MarlothSimHost();
	~MarlothSimHost() override;

	void _ready() override;
	void _process(double delta) override;

	void set_auto_tick(bool p_auto_tick);
	bool get_auto_tick() const;

	void set_demo_mesh_path(const NodePath &p_path);
	NodePath get_demo_mesh_path() const;

	void tick_once(double dt);
	int64_t get_sim_tick() const;
};

} // namespace godot
