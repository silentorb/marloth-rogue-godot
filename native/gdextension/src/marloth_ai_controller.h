#pragma once

#include "marloth_pawn_controller.h"

namespace godot {

/// Stub AI controller; same possession API as PlayerController for later use.
class MarlothAIController : public MarlothPawnController {
	GDCLASS(MarlothAIController, MarlothPawnController);

protected:
	static void _bind_methods();

public:
	MarlothAIController();
	~MarlothAIController() override = default;

	void _physics_process(double delta) override;
};

} // namespace godot
