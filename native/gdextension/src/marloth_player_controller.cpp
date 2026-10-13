#include "marloth_player_controller.h"

#include <algorithm>

#include <godot_cpp/classes/engine.hpp>
#include <godot_cpp/classes/input.hpp>
#include <godot_cpp/classes/input_event_mouse_button.hpp>
#include <godot_cpp/classes/input_event_mouse_motion.hpp>

using namespace godot;

namespace {
constexpr float kPitchLimit = 1.3962634f; // ~80 deg
constexpr float kGravity = 20.0f;
} // namespace

MarlothPlayerController::MarlothPlayerController() = default;

void MarlothPlayerController::_bind_methods() {
	ClassDB::bind_method(D_METHOD("set_move_speed", "speed"), &MarlothPlayerController::set_move_speed);
	ClassDB::bind_method(D_METHOD("get_move_speed"), &MarlothPlayerController::get_move_speed);
	ClassDB::bind_method(
			D_METHOD("set_mouse_sensitivity", "sensitivity"),
			&MarlothPlayerController::set_mouse_sensitivity);
	ClassDB::bind_method(D_METHOD("get_mouse_sensitivity"), &MarlothPlayerController::get_mouse_sensitivity);

	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "move_speed"), "set_move_speed", "get_move_speed");
	ADD_PROPERTY(
			PropertyInfo(Variant::FLOAT, "mouse_sensitivity"),
			"set_mouse_sensitivity",
			"get_mouse_sensitivity");
}

void MarlothPlayerController::_ready() {
	if (Engine::get_singleton()->is_editor_hint()) {
		return;
	}
	set_physics_process(true);
	set_process_unhandled_input(true);
	capture_mouse(true);
}

void MarlothPlayerController::_exit_tree() {
	capture_mouse(false);
}

void MarlothPlayerController::_unhandled_input(const Ref<InputEvent> &event) {
	if (event.is_null()) {
		return;
	}
	if (Object::cast_to<InputEventMouseButton>(*event)) {
		if (!mouse_captured) {
			capture_mouse(true);
		}
		return;
	}
	const InputEventMouseMotion *motion = Object::cast_to<InputEventMouseMotion>(*event);
	if (!motion || !mouse_captured) {
		return;
	}
	CharacterBody3D *pawn = get_possessed_pawn();
	if (!pawn) {
		return;
	}
	const Vector2 relative = motion->get_relative();
	pawn->rotate_y(-relative.x * mouse_sensitivity);
	pitch = std::clamp(pitch - relative.y * mouse_sensitivity, -kPitchLimit, kPitchLimit);
	if (Camera3D *camera = find_camera()) {
		camera->set_rotation(Vector3(pitch, 0.0f, 0.0f));
	}
}

void MarlothPlayerController::_physics_process(double delta) {
	CharacterBody3D *pawn = get_possessed_pawn();
	if (!pawn) {
		return;
	}
	Input *input = Input::get_singleton();
	if (!input) {
		return;
	}

	Vector2 axis;
	axis.x = input->get_axis("move_left", "move_right");
	axis.y = input->get_axis("move_forward", "move_back");
	Vector3 direction = (pawn->get_transform().basis.get_column(0) * axis.x)
			+ (pawn->get_transform().basis.get_column(2) * axis.y);
	if (direction.length_squared() > 1e-6f) {
		direction = direction.normalized();
	}

	Vector3 velocity = pawn->get_velocity();
	velocity.x = direction.x * move_speed;
	velocity.z = direction.z * move_speed;
	if (!pawn->is_on_floor()) {
		velocity.y -= kGravity * static_cast<float>(delta);
	} else if (velocity.y < 0.0f) {
		velocity.y = 0.0f;
	}
	pawn->set_velocity(velocity);
	pawn->move_and_slide();
}

Camera3D *MarlothPlayerController::find_camera() const {
	CharacterBody3D *pawn = get_possessed_pawn();
	if (!pawn) {
		return nullptr;
	}
	return Object::cast_to<Camera3D>(pawn->get_node_or_null(NodePath("Camera3D")));
}

void MarlothPlayerController::capture_mouse(bool enable) {
	Input *input = Input::get_singleton();
	if (!input) {
		return;
	}
	mouse_captured = enable;
	input->set_mouse_mode(
			enable ? Input::MOUSE_MODE_CAPTURED : Input::MOUSE_MODE_VISIBLE);
}

void MarlothPlayerController::set_move_speed(float p_speed) {
	move_speed = p_speed;
}

float MarlothPlayerController::get_move_speed() const {
	return move_speed;
}

void MarlothPlayerController::set_mouse_sensitivity(float p_sensitivity) {
	mouse_sensitivity = p_sensitivity;
}

float MarlothPlayerController::get_mouse_sensitivity() const {
	return mouse_sensitivity;
}
