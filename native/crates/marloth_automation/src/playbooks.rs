//! Built-in playbooks (ids match former C# short names where practical).

use crate::host::{MeshInfo, PlaybookGodotOps};

pub const PLAYBOOK_IDS: &[&str] = &[
	"MainSceneBootstrap",
	"MargenExtensionLoaded",
	"MargenWorldDebug",
	"MarlothGlobalLoaded",
	"LocalPlayerPawnSpawned",
];

pub const MARGEN_CLASS: &str = "MargenWorldMesh";
pub const MARLOTH_GLOBAL_CLASS: &str = "MarlothGlobal";
pub const MARLOTH_WORLD_SCENE_CLASS: &str = "MarlothWorldScene";
pub const PLAYER_CONTROLLER_CLASS: &str = "MarlothPlayerController";
pub const AI_CONTROLLER_CLASS: &str = "MarlothAIController";
pub const VERTEX_MIN: i32 = 200;
pub const VERTEX_MAX: i32 = 4000;
pub const DEBUG_WORLD_SCENE: &str = "res://scenes/margen_world_debug.tscn";
pub const MESH_PATH: &str = "MargenWorldMesh/MeshInstance3D";
pub const WORLD_COLLISION_PATH: &str = "MargenWorldMesh/WorldCollision";
pub const PLAYER_SPAWN_PATH: &str = "MargenWorldMesh/Actors/PlayerSpawnLocation";
pub const CHARACTER_PAWN_PATH: &str = "CharacterPawn";

#[derive(Debug)]
pub struct PlaybookOutcome {
	pub ok: bool,
	pub error: String,
	pub diagnostics: String,
}

impl PlaybookOutcome {
	fn ok(diagnostics: impl Into<String>) -> Self {
		Self {
			ok: true,
			error: String::new(),
			diagnostics: diagnostics.into(),
		}
	}

	fn fail(error: impl Into<String>, diagnostics: impl Into<String>) -> Self {
		Self {
			ok: false,
			error: error.into(),
			diagnostics: diagnostics.into(),
		}
	}
}

pub fn run_playbook_with(ops: &PlaybookGodotOps, id: &str, _args_json: &str) -> PlaybookOutcome {
	match id {
		"MainSceneBootstrap" => main_scene_bootstrap(ops),
		"MargenExtensionLoaded" => margen_extension_loaded(ops),
		"MargenWorldDebug" => margen_world_debug(ops),
		"MarlothGlobalLoaded" => marloth_global_loaded(ops),
		"LocalPlayerPawnSpawned" => local_player_pawn_spawned(ops),
		other => PlaybookOutcome::fail(format!("unknown playbook '{other}'"), ""),
	}
}

fn main_scene_bootstrap(ops: &PlaybookGodotOps) -> PlaybookOutcome {
	if let Err(e) = (ops.load_scene)(DEBUG_WORLD_SCENE) {
		return PlaybookOutcome::fail(e, "");
	}
	if let Err(e) = (ops.wait_frames)(10) {
		return PlaybookOutcome::fail(e, "");
	}
	match (ops.scene_root_name)() {
		Ok(name) if !name.is_empty() => {
			let path = (ops.scene_path)().unwrap_or_default();
			PlaybookOutcome::ok(format!("path={path};root={name}"))
		}
		Ok(_) => PlaybookOutcome::fail("main scene root name empty", ""),
		Err(e) => PlaybookOutcome::fail(e, ""),
	}
}

fn margen_extension_loaded(ops: &PlaybookGodotOps) -> PlaybookOutcome {
	match (ops.class_exists)(MARGEN_CLASS) {
		Ok(true) => PlaybookOutcome::ok(format!("class={MARGEN_CLASS}")),
		Ok(false) => {
			let tags = (ops.feature_tags)().unwrap_or_default();
			PlaybookOutcome::fail(
				format!("ClassDB does not contain '{MARGEN_CLASS}'"),
				tags,
			)
		}
		Err(e) => PlaybookOutcome::fail(e, ""),
	}
}

fn marloth_global_loaded(ops: &PlaybookGodotOps) -> PlaybookOutcome {
	match (ops.class_exists)(MARLOTH_GLOBAL_CLASS) {
		Ok(true) => PlaybookOutcome::ok(format!("class={MARLOTH_GLOBAL_CLASS}")),
		Ok(false) => PlaybookOutcome::fail(
			format!("ClassDB does not contain '{MARLOTH_GLOBAL_CLASS}'"),
			"",
		),
		Err(e) => PlaybookOutcome::fail(e, ""),
	}
}

fn local_player_pawn_spawned(ops: &PlaybookGodotOps) -> PlaybookOutcome {
	for class_name in [
		PLAYER_CONTROLLER_CLASS,
		AI_CONTROLLER_CLASS,
		MARLOTH_GLOBAL_CLASS,
		MARLOTH_WORLD_SCENE_CLASS,
	] {
		match (ops.class_exists)(class_name) {
			Ok(true) => {}
			Ok(false) => {
				return PlaybookOutcome::fail(
					format!("ClassDB does not contain '{class_name}'"),
					"",
				);
			}
			Err(e) => return PlaybookOutcome::fail(e, ""),
		}
	}
	if let Err(e) = (ops.load_scene)(DEBUG_WORLD_SCENE) {
		return PlaybookOutcome::fail(e, "");
	}
	if let Err(e) = (ops.wait_frames)(30) {
		return PlaybookOutcome::fail(e, "");
	}
	let path = (ops.scene_path)().unwrap_or_default();
	let root = (ops.scene_root_name)().unwrap_or_default();
	let pawn_info = match (ops.mesh_vertex_count)(CHARACTER_PAWN_PATH) {
		Ok(info) => info,
		Err(e) => return PlaybookOutcome::fail(e, format!("path={path};root={root}")),
	};
	let diagnostics = format!(
		"path={path};root={root};pawn_found={};classes=ok",
		pawn_info.found
	);
	if !pawn_info.found {
		return PlaybookOutcome::fail(
			format!("Character pawn '{CHARACTER_PAWN_PATH}' not found after bootstrap."),
			diagnostics,
		);
	}
	PlaybookOutcome::ok(diagnostics)
}

fn margen_world_debug(ops: &PlaybookGodotOps) -> PlaybookOutcome {
	match (ops.class_exists)(MARGEN_CLASS) {
		Ok(true) => {}
		Ok(false) => {
			return PlaybookOutcome::fail(
				format!("ClassDB does not contain '{MARGEN_CLASS}' before loading debug scene."),
				(ops.feature_tags)().unwrap_or_default(),
			);
		}
		Err(e) => return PlaybookOutcome::fail(e, ""),
	}
	if let Err(e) = (ops.load_scene)(DEBUG_WORLD_SCENE) {
		return PlaybookOutcome::fail(e, "");
	}
	if let Err(e) = (ops.wait_frames)(20) {
		return PlaybookOutcome::fail(e, "");
	}
	let path = (ops.scene_path)().unwrap_or_default();
	let root = (ops.scene_root_name)().unwrap_or_default();
	let mesh_info = match (ops.mesh_vertex_count)(MESH_PATH) {
		Ok(info) => info,
		Err(e) => return PlaybookOutcome::fail(e, format!("path={path};root={root}")),
	};
	let collision_info = match (ops.mesh_vertex_count)(WORLD_COLLISION_PATH) {
		Ok(info) => info,
		Err(e) => {
			return PlaybookOutcome::fail(e, format!("path={path};root={root};mesh_ok=pending"));
		}
	};
	let spawn_info = match (ops.mesh_vertex_count)(PLAYER_SPAWN_PATH) {
		Ok(info) => info,
		Err(e) => {
			return PlaybookOutcome::fail(
				e,
				format!("path={path};root={root};mesh_ok=pending;collision_ok=pending"),
			);
		}
	};
	outcome_from_mesh_collision_and_spawn(path, root, mesh_info, collision_info, spawn_info)
}

fn outcome_from_mesh_collision_and_spawn(
	path: String,
	root: String,
	info: MeshInfo,
	collision: MeshInfo,
	spawn: MeshInfo,
) -> PlaybookOutcome {
	let diagnostics = format!(
		"path={path};root={root};mesh_found={};has_mesh={};surfaces={};vertices={};collision_found={};spawn_found={}",
		info.found,
		info.has_mesh,
		info.surface_count,
		info.vertex_count,
		collision.found,
		spawn.found
	);
	if !info.found {
		return PlaybookOutcome::fail(format!("Node '{MESH_PATH}' not found."), diagnostics);
	}
	if !info.has_mesh {
		return PlaybookOutcome::fail(
			"MeshInstance3D has no mesh after auto_generate.",
			diagnostics,
		);
	}
	if info.surface_count <= 0 {
		return PlaybookOutcome::fail("Mesh has zero surfaces after auto_generate.", diagnostics);
	}
	if info.vertex_count < VERTEX_MIN || info.vertex_count > VERTEX_MAX {
		return PlaybookOutcome::fail(
			format!(
				"Vertex count {} outside documented band [{VERTEX_MIN}, {VERTEX_MAX}].",
				info.vertex_count
			),
			diagnostics,
		);
	}
	if !collision.found {
		return PlaybookOutcome::fail(
			format!("World collision '{WORLD_COLLISION_PATH}' not found after generate."),
			diagnostics,
		);
	}
	if !spawn.found {
		return PlaybookOutcome::fail(
			format!("Player spawn actor '{PLAYER_SPAWN_PATH}' not found after generate."),
			diagnostics,
		);
	}
	PlaybookOutcome::ok(diagnostics)
}
