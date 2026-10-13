#pragma once

#include <godot_cpp/classes/node.hpp>
#include <godot_cpp/core/class_db.hpp>

namespace godot {

/// Thin in-scene kickstart for world scenes; defers one frame then starts Global session.
class MarlothWorldScene : public Node {
	GDCLASS(MarlothWorldScene, Node);

	bool kickoff_scheduled = false;

protected:
	static void _bind_methods();

public:
	MarlothWorldScene() = default;
	~MarlothWorldScene() override = default;

	void _ready() override;
	void _process(double delta) override;

private:
	void kickstart_session();
	Node *resolve_scene_root() const;
};

} // namespace godot
