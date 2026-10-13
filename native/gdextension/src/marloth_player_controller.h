#pragma once

#include "marloth_pawn_controller.h"

#include <godot_cpp/classes/camera3d.hpp>
#include <godot_cpp/classes/input_event.hpp>

namespace godot {

/// Local human controller: WASD + mouse look → CharacterBody3D move_and_slide.
class MarlothPlayerController : public MarlothPawnController {
	GDCLASS(MarlothPlayerController, MarlothPawnController);

	float move_speed = 5.0f;
	float mouse_sensitivity = 0.0025f;
	float pitch = 0.0f;
	bool mouse_captured = false;

protected:
	static void _bind_methods();

public:
	MarlothPlayerController();
	~MarlothPlayerController() override = default;

	void _ready() override;
	void _exit_tree() override;
	void _unhandled_input(const Ref<InputEvent> &event) override;
	void _physics_process(double delta) override;

	void set_move_speed(float p_speed);
	float get_move_speed() const;
	void set_mouse_sensitivity(float p_sensitivity);
	float get_mouse_sensitivity() const;

private:
	Camera3D *find_camera() const;
	void capture_mouse(bool enable);
};

} // namespace godot
