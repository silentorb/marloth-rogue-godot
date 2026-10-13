#include "marloth_pawn_controller.h"

using namespace godot;

MarlothPawnController::MarlothPawnController() = default;

void MarlothPawnController::_bind_methods() {
	ClassDB::bind_method(D_METHOD("possess", "pawn"), &MarlothPawnController::possess);
	ClassDB::bind_method(D_METHOD("unpossess"), &MarlothPawnController::unpossess);
	ClassDB::bind_method(D_METHOD("get_possessed_pawn"), &MarlothPawnController::get_possessed_pawn);
	ClassDB::bind_method(D_METHOD("set_actor_id", "actor_id"), &MarlothPawnController::set_actor_id);
	ClassDB::bind_method(D_METHOD("get_actor_id"), &MarlothPawnController::get_actor_id);

	ADD_PROPERTY(PropertyInfo(Variant::INT, "actor_id"), "set_actor_id", "get_actor_id");
}

void MarlothPawnController::possess(CharacterBody3D *pawn) {
	unpossess();
	possessed_pawn = pawn;
}

void MarlothPawnController::unpossess() {
	possessed_pawn = nullptr;
}

CharacterBody3D *MarlothPawnController::get_possessed_pawn() const {
	return possessed_pawn;
}

void MarlothPawnController::set_actor_id(uint32_t p_actor_id) {
	actor_id = p_actor_id;
}

uint32_t MarlothPawnController::get_actor_id() const {
	return actor_id;
}
