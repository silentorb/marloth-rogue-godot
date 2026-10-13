#include "marloth_ai_controller.h"

using namespace godot;

MarlothAIController::MarlothAIController() = default;

void MarlothAIController::_bind_methods() {
}

void MarlothAIController::_physics_process(double delta) {
	(void)delta;
	// Stub: no motion yet. Possession API matches PlayerController for later AI.
}
