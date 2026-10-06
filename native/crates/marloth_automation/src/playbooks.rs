//! Built-in playbooks (ids match former C# short names where practical).

use crate::host::{MeshInfo, PlaybookGodotOps};

pub const PLAYBOOK_IDS: &[&str] = &[
	"MainSceneBootstrap",
	"MargenExtensionLoaded",
	"MargenWorldDebug",
	"MarlothSimHostLoaded",
];

pub const MARGEN_CLASS: &str = "MargenWorldMesh";
pub const MARLOTH_SIM_CLASS: &str = "MarlothSimHost";
pub const VERTEX_MIN: i32 = 200;
pub const VERTEX_MAX: i32 = 4000;
pub const MESH_PATH: &str = "MargenWorldMesh/MeshInstance3D";

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
		"MarlothSimHostLoaded" => marloth_sim_host_loaded(ops),
		other => PlaybookOutcome::fail(format!("unknown playbook '{other}'"), ""),
	}
}

fn main_scene_bootstrap(ops: &PlaybookGodotOps) -> PlaybookOutcome {
	if let Err(e) = (ops.load_scene)("res://main.tscn") {
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

fn marloth_sim_host_loaded(ops: &PlaybookGodotOps) -> PlaybookOutcome {
	match (ops.class_exists)(MARLOTH_SIM_CLASS) {
		Ok(true) => PlaybookOutcome::ok(format!("class={MARLOTH_SIM_CLASS}")),
		Ok(false) => PlaybookOutcome::fail(
			format!("ClassDB does not contain '{MARLOTH_SIM_CLASS}'"),
			"",
		),
		Err(e) => PlaybookOutcome::fail(e, ""),
	}
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
	if let Err(e) = (ops.load_scene)("res://scenes/margen_world_debug.tscn") {
		return PlaybookOutcome::fail(e, "");
	}
	if let Err(e) = (ops.wait_frames)(20) {
		return PlaybookOutcome::fail(e, "");
	}
	let path = (ops.scene_path)().unwrap_or_default();
	let root = (ops.scene_root_name)().unwrap_or_default();
	match (ops.mesh_vertex_count)(MESH_PATH) {
		Ok(info) => outcome_from_mesh(path, root, info),
		Err(e) => PlaybookOutcome::fail(e, format!("path={path};root={root}")),
	}
}

fn outcome_from_mesh(path: String, root: String, info: MeshInfo) -> PlaybookOutcome {
	let diagnostics = format!(
		"path={path};root={root};mesh_found={};has_mesh={};surfaces={};vertices={}",
		info.found, info.has_mesh, info.surface_count, info.vertex_count
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
	PlaybookOutcome::ok(diagnostics)
}
