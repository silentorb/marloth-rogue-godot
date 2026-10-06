//! Godot automation: tonic gRPC host + built-in playbooks.
//!
//! Godot ops are provided by the C++ GDExtension via [`GodotOps`].

mod host;
mod playbooks;

pub use host::{
	poll_main_thread, start_automation, stop_automation, AutomationStartError, GodotOps,
	GodotOpsVtable,
};
pub use playbooks::PLAYBOOK_IDS;
