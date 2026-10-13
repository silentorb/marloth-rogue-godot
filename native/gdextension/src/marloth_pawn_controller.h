#pragma once

#include <godot_cpp/classes/character_body3d.hpp>
#include <godot_cpp/classes/node.hpp>
#include <godot_cpp/core/class_db.hpp>

namespace godot {

/// Base controller that can possess a CharacterBody3D pawn (human or AI).
class MarlothPawnController : public Node {
	GDCLASS(MarlothPawnController, Node);

	CharacterBody3D *possessed_pawn = nullptr;
	uint32_t actor_id = 0;

protected:
	static void _bind_methods();

public:
	MarlothPawnController();
	~MarlothPawnController() override = default;

	void possess(CharacterBody3D *pawn);
	void unpossess();
	CharacterBody3D *get_possessed_pawn() const;

	void set_actor_id(uint32_t p_actor_id);
	uint32_t get_actor_id() const;
};

} // namespace godot
