#pragma once

#include <cstdint>

#include <godot_cpp/classes/character_body3d.hpp>
#include <godot_cpp/classes/node.hpp>
#include <godot_cpp/classes/node3d.hpp>
#include <godot_cpp/classes/packed_scene.hpp>
#include <godot_cpp/classes/ref.hpp>

struct MarlothSim;

namespace marloth {

constexpr const char *kPlayerSpawnGroup = "player_spawn";
constexpr const char *kCharacterPawnGroup = "character_pawn";
constexpr const char *kCharacterPawnName = "CharacterPawn";
constexpr const char *kDefaultPawnScenePath = "res://scenes/entities/character_pawn.tscn";

struct LocalPlayerSession {
	godot::CharacterBody3D *pawn = nullptr;
	godot::Node *player_controller = nullptr;
	uint32_t actor_id = 0;
};

/// First `player_spawn` group member that is a descendant of `scene_root`, or null.
godot::Node3D *find_player_spawn(godot::Node *scene_root);

void godot_to_sim_pose(
		const godot::Vector3 &origin,
		float godot_yaw_y,
		float &out_x,
		float &out_y,
		float &out_z,
		float &out_yaw);

/// Bootstrap sim + instance pawn under scene_root. On failure logs and returns false (no half-init).
bool start_local_player_session(
		MarlothSim *sim,
		godot::Node *scene_root,
		const godot::Ref<godot::PackedScene> &pawn_scene,
		LocalPlayerSession &out_session);

} // namespace marloth
