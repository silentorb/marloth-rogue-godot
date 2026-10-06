//! Tonic automation server with main-thread marshaling for Godot ops.

use crate::playbooks;
use marloth_automation_proto::automation_service_server::{AutomationService, AutomationServiceServer};
use marloth_automation_proto::{
	CommandResponse, ListPlaybooksRequest, ListPlaybooksResponse, PingRequest, PingResponse,
	PlaybookResultResponse, RunPlaybookRequest, ShutdownRequest,
};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex};
use std::time::Duration;
use tokio::sync::{mpsc, oneshot};
use tonic::{transport::Server, Request, Response, Status};

/// Result of mesh inspect for playbooks.
#[derive(Clone, Debug, Default)]
pub struct MeshInfo {
	pub found: bool,
	pub has_mesh: bool,
	pub surface_count: i32,
	pub vertex_count: i32,
}

/// Godot operations invoked on the main thread via [`poll_main_thread`].
#[derive(Clone)]
pub struct GodotOps {
	job_tx: mpsc::UnboundedSender<MainThreadJob>,
}

enum MainThreadJob {
	LoadScene {
		path: String,
		reply: oneshot::Sender<Result<(), String>>,
	},
	WaitFrames {
		count: i32,
		reply: oneshot::Sender<Result<(), String>>,
	},
	ClassExists {
		name: String,
		reply: oneshot::Sender<Result<bool, String>>,
	},
	ScenePath {
		reply: oneshot::Sender<Result<String, String>>,
	},
	SceneRootName {
		reply: oneshot::Sender<Result<String, String>>,
	},
	FeatureTags {
		reply: oneshot::Sender<Result<String, String>>,
	},
	MeshVertexCount {
		node_path: String,
		reply: oneshot::Sender<Result<MeshInfo, String>>,
	},
	ShutdownGodot {
		reply: oneshot::Sender<Result<(), String>>,
	},
}

/// C-facing callbacks filled by the GDExtension (called only on Godot main thread).
#[repr(C)]
#[derive(Clone, Copy)]
pub struct GodotOpsVtable {
	pub userdata: *mut std::ffi::c_void,
	pub load_scene: Option<unsafe extern "C" fn(*mut std::ffi::c_void, *const i8) -> i32>,
	pub wait_frames: Option<unsafe extern "C" fn(*mut std::ffi::c_void, i32) -> i32>,
	pub class_exists: Option<unsafe extern "C" fn(*mut std::ffi::c_void, *const i8) -> i32>,
	pub scene_path:
		Option<unsafe extern "C" fn(*mut std::ffi::c_void, *mut i8, usize) -> i32>,
	pub scene_root_name:
		Option<unsafe extern "C" fn(*mut std::ffi::c_void, *mut i8, usize) -> i32>,
	pub feature_tags:
		Option<unsafe extern "C" fn(*mut std::ffi::c_void, *mut i8, usize) -> i32>,
	pub mesh_info: Option<
		unsafe extern "C" fn(
			*mut std::ffi::c_void,
			*const i8,
			*mut i32,
			*mut i32,
			*mut i32,
			*mut i32,
		) -> i32,
	>,
	pub request_shutdown: Option<unsafe extern "C" fn(*mut std::ffi::c_void) -> i32>,
	pub last_error: Option<unsafe extern "C" fn(*mut std::ffi::c_void, *mut i8, usize) -> i32>,
}

// SAFETY: userdata lifetime is owned by the C++ host for the automation session.
unsafe impl Send for GodotOpsVtable {}
unsafe impl Sync for GodotOpsVtable {}

struct PendingWait {
	remaining: i32,
	reply: oneshot::Sender<Result<(), String>>,
}

struct HostState {
	vtable: GodotOpsVtable,
	job_rx: Mutex<Option<mpsc::UnboundedReceiver<MainThreadJob>>>,
	pending_waits: Mutex<Vec<PendingWait>>,
	shutdown_flag: Arc<AtomicBool>,
	server_join: Mutex<Option<std::thread::JoinHandle<()>>>,
}

static HOST: Mutex<Option<HostState>> = Mutex::new(None);

impl GodotOps {
	fn call<T>(
		&self,
		make: impl FnOnce(oneshot::Sender<Result<T, String>>) -> MainThreadJob,
	) -> Result<T, String>
	where
		T: Send + 'static,
	{
		let (tx, rx) = oneshot::channel();
		self.job_tx
			.send(make(tx))
			.map_err(|_| "automation main-thread queue closed".to_string())?;
		rx.blocking_recv()
			.map_err(|_| "automation main-thread reply dropped".to_string())?
	}

	pub fn load_scene(&self, path: &str) -> Result<(), String> {
		let path = path.to_string();
		self.call(|reply| MainThreadJob::LoadScene { path, reply })
	}

	pub fn wait_frames(&self, count: i32) -> Result<(), String> {
		self.call(|reply| MainThreadJob::WaitFrames { count, reply })
	}

	pub fn class_exists(&self, name: &str) -> Result<bool, String> {
		let name = name.to_string();
		self.call(|reply| MainThreadJob::ClassExists { name, reply })
	}

	pub fn scene_path(&self) -> Result<String, String> {
		self.call(|reply| MainThreadJob::ScenePath { reply })
	}

	pub fn scene_root_name(&self) -> Result<String, String> {
		self.call(|reply| MainThreadJob::SceneRootName { reply })
	}

	pub fn feature_tags(&self) -> Result<String, String> {
		self.call(|reply| MainThreadJob::FeatureTags { reply })
	}

	pub fn mesh_vertex_count(&self, node_path: &str) -> Result<MeshInfo, String> {
		let node_path = node_path.to_string();
		self.call(|reply| MainThreadJob::MeshVertexCount { node_path, reply })
	}

	pub fn as_playbook_ops(self: &Arc<Self>) -> PlaybookGodotOps {
		let ops = Arc::clone(self);
		PlaybookGodotOps {
			load_scene: {
				let ops = Arc::clone(&ops);
				Arc::new(move |path: &str| ops.load_scene(path))
			},
			wait_frames: {
				let ops = Arc::clone(&ops);
				Arc::new(move |n: i32| ops.wait_frames(n))
			},
			class_exists: {
				let ops = Arc::clone(&ops);
				Arc::new(move |name: &str| ops.class_exists(name))
			},
			scene_path: {
				let ops = Arc::clone(&ops);
				Arc::new(move || ops.scene_path())
			},
			scene_root_name: {
				let ops = Arc::clone(&ops);
				Arc::new(move || ops.scene_root_name())
			},
			feature_tags: {
				let ops = Arc::clone(&ops);
				Arc::new(move || ops.feature_tags())
			},
			mesh_vertex_count: {
				let ops = Arc::clone(&ops);
				Arc::new(move |path: &str| ops.mesh_vertex_count(path))
			},
		}
	}
}

/// Erased ops used by playbooks.
pub struct PlaybookGodotOps {
	pub load_scene: Arc<dyn Fn(&str) -> Result<(), String> + Send + Sync>,
	pub wait_frames: Arc<dyn Fn(i32) -> Result<(), String> + Send + Sync>,
	pub class_exists: Arc<dyn Fn(&str) -> Result<bool, String> + Send + Sync>,
	pub scene_path: Arc<dyn Fn() -> Result<String, String> + Send + Sync>,
	pub scene_root_name: Arc<dyn Fn() -> Result<String, String> + Send + Sync>,
	pub feature_tags: Arc<dyn Fn() -> Result<String, String> + Send + Sync>,
	pub mesh_vertex_count: Arc<dyn Fn(&str) -> Result<MeshInfo, String> + Send + Sync>,
}

#[derive(Debug)]
pub enum AutomationStartError {
	AlreadyRunning,
	Bind(String),
}

struct AutomationSvc {
	ops: Arc<GodotOps>,
	shutdown_flag: Arc<AtomicBool>,
}

#[tonic::async_trait]
impl AutomationService for AutomationSvc {
	async fn ping(&self, _request: Request<PingRequest>) -> Result<Response<PingResponse>, Status> {
		Ok(Response::new(PingResponse {
			ok: true,
			message: "marloth-automation".into(),
		}))
	}

	async fn list_playbooks(
		&self,
		_request: Request<ListPlaybooksRequest>,
	) -> Result<Response<ListPlaybooksResponse>, Status> {
		Ok(Response::new(ListPlaybooksResponse {
			ok: true,
			error: String::new(),
			playbook_ids: playbooks::PLAYBOOK_IDS
				.iter()
				.map(|s| (*s).to_string())
				.collect(),
		}))
	}

	async fn run_playbook(
		&self,
		request: Request<RunPlaybookRequest>,
	) -> Result<Response<PlaybookResultResponse>, Status> {
		let ops = Arc::clone(&self.ops);
		let req = request.into_inner();
		let id = req.playbook_id;
		let args = req.args_json;
		let outcome = tokio::task::spawn_blocking(move || {
			let pb = ops.as_playbook_ops();
			playbooks::run_playbook_with(&pb, &id, &args)
		})
		.await
		.map_err(|e| Status::internal(e.to_string()))?;
		Ok(Response::new(PlaybookResultResponse {
			ok: outcome.ok,
			error: outcome.error,
			diagnostics: outcome.diagnostics,
		}))
	}

	async fn shutdown(
		&self,
		_request: Request<ShutdownRequest>,
	) -> Result<Response<CommandResponse>, Status> {
		let ops = Arc::clone(&self.ops);
		let flag = Arc::clone(&self.shutdown_flag);
		flag.store(true, Ordering::SeqCst);
		let _ = tokio::task::spawn_blocking(move || {
			ops.call(|reply| MainThreadJob::ShutdownGodot { reply })
		})
		.await;
		Ok(Response::new(CommandResponse {
			ok: true,
			error: String::new(),
		}))
	}
}

fn c_err(vtable: &GodotOpsVtable) -> String {
	let mut buf = vec![0i8; 512];
	if let Some(f) = vtable.last_error {
		unsafe {
			f(vtable.userdata, buf.as_mut_ptr(), buf.len());
		}
	}
	c_string_from_buf(&buf)
}

fn c_string_from_buf(buf: &[i8]) -> String {
	let len = buf.iter().position(|&c| c == 0).unwrap_or(buf.len());
	let bytes: Vec<u8> = buf[..len].iter().map(|&c| c as u8).collect();
	String::from_utf8_lossy(&bytes).into_owned()
}

fn execute_job(vtable: &GodotOpsVtable, job: MainThreadJob) {
	match job {
		MainThreadJob::LoadScene { path, reply } => {
			let result = match vtable.load_scene {
				Some(f) => {
					let c = std::ffi::CString::new(path).unwrap_or_default();
					let rc = unsafe { f(vtable.userdata, c.as_ptr()) };
					if rc == 0 {
						Ok(())
					} else {
						Err(c_err(vtable))
					}
				}
				None => Err("load_scene vtable missing".into()),
			};
			let _ = reply.send(result);
		}
		MainThreadJob::WaitFrames { count, reply } => {
			let _ = (count, vtable);
			let _ = reply.send(Err("WaitFrames reached execute_job".into()));
		}
		MainThreadJob::ClassExists { name, reply } => {
			let result = match vtable.class_exists {
				Some(f) => {
					let c = std::ffi::CString::new(name).unwrap_or_default();
					let rc = unsafe { f(vtable.userdata, c.as_ptr()) };
					if rc < 0 {
						Err(c_err(vtable))
					} else {
						Ok(rc != 0)
					}
				}
				None => Err("class_exists vtable missing".into()),
			};
			let _ = reply.send(result);
		}
		MainThreadJob::ScenePath { reply } => {
			let _ = reply.send(read_string_op(vtable, vtable.scene_path));
		}
		MainThreadJob::SceneRootName { reply } => {
			let _ = reply.send(read_string_op(vtable, vtable.scene_root_name));
		}
		MainThreadJob::FeatureTags { reply } => {
			let _ = reply.send(read_string_op(vtable, vtable.feature_tags));
		}
		MainThreadJob::MeshVertexCount { node_path, reply } => {
			let result = match vtable.mesh_info {
				Some(f) => {
					let c = std::ffi::CString::new(node_path).unwrap_or_default();
					let mut found = 0;
					let mut has_mesh = 0;
					let mut surfaces = 0;
					let mut verts = 0;
					let rc = unsafe {
						f(
							vtable.userdata,
							c.as_ptr(),
							&mut found,
							&mut has_mesh,
							&mut surfaces,
							&mut verts,
						)
					};
					if rc != 0 {
						Err(c_err(vtable))
					} else {
						Ok(MeshInfo {
							found: found != 0,
							has_mesh: has_mesh != 0,
							surface_count: surfaces,
							vertex_count: verts,
						})
					}
				}
				None => Err("mesh_info vtable missing".into()),
			};
			let _ = reply.send(result);
		}
		MainThreadJob::ShutdownGodot { reply } => {
			let result = match vtable.request_shutdown {
				Some(f) => {
					let rc = unsafe { f(vtable.userdata) };
					if rc == 0 {
						Ok(())
					} else {
						Err(c_err(vtable))
					}
				}
				None => Ok(()),
			};
			let _ = reply.send(result);
		}
	}
}

fn read_string_op(
	vtable: &GodotOpsVtable,
	f: Option<unsafe extern "C" fn(*mut std::ffi::c_void, *mut i8, usize) -> i32>,
) -> Result<String, String> {
	match f {
		Some(func) => {
			let mut buf = vec![0i8; 1024];
			let rc = unsafe { func(vtable.userdata, buf.as_mut_ptr(), buf.len()) };
			if rc != 0 {
				Err(c_err(vtable))
			} else {
				Ok(c_string_from_buf(&buf))
			}
		}
		None => Err("string op vtable missing".into()),
	}
}

/// Start the automation gRPC server on a background thread.
pub fn start_automation(
	host: &str,
	port: u16,
	vtable: GodotOpsVtable,
) -> Result<(), AutomationStartError> {
	let mut guard = HOST.lock().expect("HOST lock");
	if guard.is_some() {
		return Err(AutomationStartError::AlreadyRunning);
	}

	let (job_tx, job_rx) = mpsc::unbounded_channel();
	let ops = Arc::new(GodotOps { job_tx });
	let shutdown_flag = Arc::new(AtomicBool::new(false));
	let shutdown_flag_server = Arc::clone(&shutdown_flag);

	let addr: std::net::SocketAddr = format!("{host}:{port}")
		.parse()
		.map_err(|e: std::net::AddrParseError| AutomationStartError::Bind(e.to_string()))?;

	let svc = AutomationSvc {
		ops,
		shutdown_flag: Arc::clone(&shutdown_flag),
	};

	let join = std::thread::Builder::new()
		.name("marloth-automation-server".into())
		.spawn(move || {
			let runtime = match tokio::runtime::Builder::new_multi_thread()
				.enable_all()
				.worker_threads(2)
				.thread_name("marloth-automation")
				.build()
			{
				Ok(rt) => rt,
				Err(e) => {
					eprintln!("marloth automation: runtime build failed: {e}");
					return;
				}
			};
			runtime.block_on(async move {
				let result = Server::builder()
					.add_service(AutomationServiceServer::new(svc))
					.serve_with_shutdown(addr, async move {
						loop {
							if shutdown_flag_server.load(Ordering::SeqCst) {
								break;
							}
							tokio::time::sleep(Duration::from_millis(50)).await;
						}
					})
					.await;
				if let Err(e) = result {
					eprintln!("marloth automation: server error: {e}");
				}
			});
		})
		.map_err(|e| AutomationStartError::Bind(e.to_string()))?;

	*guard = Some(HostState {
		vtable,
		job_rx: Mutex::new(Some(job_rx)),
		pending_waits: Mutex::new(Vec::new()),
		shutdown_flag,
		server_join: Mutex::new(Some(join)),
	});
	Ok(())
}

/// Drain and execute pending main-thread jobs. Call from Godot `_process` once per frame.
pub fn poll_main_thread() {
	let guard = HOST.lock().expect("HOST lock");
	let Some(state) = guard.as_ref() else {
		return;
	};
	{
		let mut rx_guard = state.job_rx.lock().expect("job_rx");
		let Some(rx) = rx_guard.as_mut() else {
			return;
		};
		while let Ok(job) = rx.try_recv() {
			if let MainThreadJob::WaitFrames { count, reply } = job {
				let remaining = count.max(0);
				if remaining == 0 {
					let _ = reply.send(Ok(()));
				} else {
					state
						.pending_waits
						.lock()
						.expect("pending_waits")
						.push(PendingWait { remaining, reply });
				}
				continue;
			}
			execute_job(&state.vtable, job);
		}
	}
	// Advance frame waits once per poll (= once per Godot process frame).
	let mut waits = state.pending_waits.lock().expect("pending_waits");
	let mut i = 0;
	while i < waits.len() {
		waits[i].remaining -= 1;
		if waits[i].remaining <= 0 {
			let PendingWait { reply, .. } = waits.remove(i);
			let _ = reply.send(Ok(()));
		} else {
			i += 1;
		}
	}
}

/// Stop the automation server.
pub fn stop_automation() {
	let mut guard = HOST.lock().expect("HOST lock");
	if let Some(state) = guard.take() {
		state.shutdown_flag.store(true, Ordering::SeqCst);
		if let Some(join) = state.server_join.lock().expect("join").take() {
			let _ = join.join();
		}
	}
}

