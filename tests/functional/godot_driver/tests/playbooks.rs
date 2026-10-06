use marloth_automation_proto::automation_service_client::AutomationServiceClient;
use marloth_automation_proto::{PingRequest, RunPlaybookRequest, ShutdownRequest};
use std::net::TcpListener;
use std::path::{Path, PathBuf};
use std::process::{Child, Command, Stdio};
use std::time::Duration;
use tokio::time::sleep;

struct GodotSession {
	child: Child,
	client: AutomationServiceClient<tonic::transport::Channel>,
}

impl GodotSession {
	async fn start() -> Self {
		let godot = std::env::var("GODOT_BIN").expect("GODOT_BIN must be set");
		let root = find_project_root();
		let port = reserve_port();

		let mut cmd = Command::new(&godot);
		cmd.arg("--path")
			.arg(&root)
			.arg("--headless")
			.env("MARLOTH_AUTOMATION_ENABLED", "1")
			.env("MARLOTH_AUTOMATION_HOST", "127.0.0.1")
			.env("MARLOTH_AUTOMATION_PORT", port.to_string())
			.stdout(Stdio::piped())
			.stderr(Stdio::piped());

		let child = cmd.spawn().expect("spawn GODOT_BIN");
		let endpoint = format!("http://127.0.0.1:{port}");
		let client = wait_for_client(&endpoint).await;
		Self { child, client }
	}

	async fn run_playbook(&mut self, id: &str) {
		let response = self
			.client
			.run_playbook(RunPlaybookRequest {
				playbook_id: id.into(),
				args_json: String::new(),
			})
			.await
			.expect("RunPlaybook RPC")
			.into_inner();
		assert!(
			response.ok,
			"playbook {id} failed: {} ({})",
			response.error, response.diagnostics
		);
	}

	async fn shutdown(mut self) {
		let _ = self.client.shutdown(ShutdownRequest {}).await;
		let _ = self.child.kill();
		let _ = self.child.wait();
	}
}

async fn wait_for_client(endpoint: &str) -> AutomationServiceClient<tonic::transport::Channel> {
	for _ in 0..80 {
		if let Ok(mut client) = AutomationServiceClient::connect(endpoint.to_string()).await {
			if let Ok(resp) = client.ping(PingRequest {}).await {
				if resp.into_inner().ok {
					return client;
				}
			}
		}
		sleep(Duration::from_millis(250)).await;
	}
	panic!("timed out waiting for MarlothAutomationHost on {endpoint}");
}

fn reserve_port() -> u16 {
	let listener = TcpListener::bind("127.0.0.1:0").expect("bind ephemeral");
	listener.local_addr().expect("local_addr").port()
}

fn find_project_root() -> PathBuf {
	let mut dir = PathBuf::from(env!("CARGO_MANIFEST_DIR"));
	for _ in 0..8 {
		if dir.join("project.godot").is_file() {
			return dir;
		}
		if !dir.pop() {
			break;
		}
	}
	panic!("could not find project.godot from {}", env!("CARGO_MANIFEST_DIR"));
}

fn ensure_natives(root: &Path) {
	let margen = root.join("addons/margen/bin");
	let marloth = root.join("addons/marloth/bin");
	assert!(
		margen.exists(),
		"missing margen natives; run scripts/ensure-margen-natives.sh"
	);
	assert!(
		marloth.exists(),
		"missing marloth natives; run scripts/ensure-marloth-natives.sh"
	);
}

#[tokio::test]
async fn main_scene_bootstrap() {
	ensure_natives(&find_project_root());
	let mut session = GodotSession::start().await;
	session.run_playbook("MainSceneBootstrap").await;
	session.shutdown().await;
}

#[tokio::test]
async fn margen_extension_loaded() {
	ensure_natives(&find_project_root());
	let mut session = GodotSession::start().await;
	session.run_playbook("MargenExtensionLoaded").await;
	session.shutdown().await;
}

#[tokio::test]
async fn margen_world_debug() {
	ensure_natives(&find_project_root());
	let mut session = GodotSession::start().await;
	session.run_playbook("MargenWorldDebug").await;
	session.shutdown().await;
}

#[tokio::test]
async fn marloth_sim_host_loaded() {
	ensure_natives(&find_project_root());
	let mut session = GodotSession::start().await;
	session.run_playbook("MarlothSimHostLoaded").await;
	session.shutdown().await;
}
