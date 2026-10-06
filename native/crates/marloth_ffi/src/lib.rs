//! C ABI for marloth_sim and automation bootstrap.

use marloth_automation::{start_automation, stop_automation, GodotOpsVtable};
use marloth_sim::{InputFrame, ServiceReplyBlob, Sim, SnapshotEntity, VERSION};
use std::cell::RefCell;
use std::ffi::{c_char, CStr, CString};
use std::os::raw::c_int;
use std::ptr;
use std::slice;

thread_local! {
	static LAST_ERROR: RefCell<Option<CString>> = const { RefCell::new(None) };
	static SERVICE_REQ_BUF: RefCell<Vec<u8>> = const { RefCell::new(Vec::new()) };
	static SNAPSHOT_BUF: RefCell<Vec<SnapshotEntity>> = const { RefCell::new(Vec::new()) };
}

fn set_last_error(message: &str) {
	LAST_ERROR.with(|slot| {
		*slot.borrow_mut() = Some(CString::new(message).unwrap_or_else(|_| {
			CString::new("invalid error message").expect("static")
		}));
	});
}

fn clear_last_error() {
	LAST_ERROR.with(|slot| {
		*slot.borrow_mut() = None;
	});
}

#[no_mangle]
pub extern "C" fn marloth_version() -> *const c_char {
	static VERSION_C: std::sync::OnceLock<CString> = std::sync::OnceLock::new();
	VERSION_C
		.get_or_init(|| CString::new(VERSION).expect("version"))
		.as_ptr()
}

#[no_mangle]
pub extern "C" fn marloth_last_error() -> *const c_char {
	LAST_ERROR.with(|slot| match slot.borrow().as_ref() {
		Some(s) => s.as_ptr(),
		None => ptr::null(),
	})
}

pub struct MarlothSim {
	inner: Sim,
}

#[no_mangle]
pub unsafe extern "C" fn marloth_sim_create(out_sim: *mut *mut MarlothSim) -> c_int {
	clear_last_error();
	if out_sim.is_null() {
		set_last_error("out_sim is null");
		return 1;
	}
	let boxed = Box::new(MarlothSim {
		inner: Sim::new(),
	});
	*out_sim = Box::into_raw(boxed);
	0
}

#[no_mangle]
pub unsafe extern "C" fn marloth_sim_destroy(sim: *mut MarlothSim) {
	if !sim.is_null() {
		drop(Box::from_raw(sim));
	}
}

#[repr(C)]
pub struct MarlothInputFrame {
	pub tick: u64,
	pub dt_seconds: f32,
	pub axes_x: f32,
	pub axes_y: f32,
	pub buttons: u32,
	pub _pad: u32,
}

#[repr(C)]
pub struct MarlothSnapshotEntity {
	pub entity_id: u32,
	pub pos_x: f32,
	pub pos_y: f32,
	pub pos_z: f32,
	pub yaw: f32,
}

#[no_mangle]
pub unsafe extern "C" fn marloth_sim_apply_service_reply(
	sim: *mut MarlothSim,
	bytes: *const u8,
	len: usize,
) -> c_int {
	clear_last_error();
	if sim.is_null() {
		set_last_error("sim is null");
		return 1;
	}
	let reply = if bytes.is_null() || len == 0 {
		ServiceReplyBlob::default()
	} else {
		ServiceReplyBlob {
			bytes: slice::from_raw_parts(bytes, len).to_vec(),
		}
	};
	(*sim).inner.apply_service_reply(&reply);
	0
}

#[no_mangle]
pub unsafe extern "C" fn marloth_sim_step(
	sim: *mut MarlothSim,
	input: *const MarlothInputFrame,
	out_service_req: *mut *const u8,
	out_service_req_len: *mut usize,
) -> c_int {
	clear_last_error();
	if sim.is_null() || input.is_null() {
		set_last_error("sim or input is null");
		return 1;
	}
	if out_service_req.is_null() || out_service_req_len.is_null() {
		set_last_error("service request out pointers null");
		return 1;
	}
	let inp = &*input;
	let frame = InputFrame {
		tick: inp.tick,
		dt_seconds: inp.dt_seconds,
		axes_x: inp.axes_x,
		axes_y: inp.axes_y,
		buttons: inp.buttons,
		_pad: inp._pad,
	};
	let req = (*sim).inner.step(&frame);
	SERVICE_REQ_BUF.with(|buf| {
		let mut b = buf.borrow_mut();
		*b = req.bytes;
		*out_service_req = b.as_ptr();
		*out_service_req_len = b.len();
	});
	0
}

#[no_mangle]
pub unsafe extern "C" fn marloth_sim_snapshot(
	sim: *mut MarlothSim,
	out_tick: *mut u64,
	out_entities: *mut *const MarlothSnapshotEntity,
	out_entity_count: *mut usize,
) -> c_int {
	clear_last_error();
	if sim.is_null() || out_tick.is_null() || out_entities.is_null() || out_entity_count.is_null()
	{
		set_last_error("null snapshot argument");
		return 1;
	}
	let snap = (*sim).inner.snapshot();
	*out_tick = snap.tick;
	SNAPSHOT_BUF.with(|buf| {
		let mut b = buf.borrow_mut();
		b.clear();
		b.extend(snap.entities);
		*out_entities = b.as_ptr() as *const MarlothSnapshotEntity;
		*out_entity_count = b.len();
	});
	0
}

#[repr(C)]
pub struct MarlothGodotOpsVtable {
	pub userdata: *mut std::ffi::c_void,
	pub load_scene: Option<unsafe extern "C" fn(*mut std::ffi::c_void, *const i8) -> i32>,
	pub wait_frames: Option<unsafe extern "C" fn(*mut std::ffi::c_void, i32) -> i32>,
	pub class_exists: Option<unsafe extern "C" fn(*mut std::ffi::c_void, *const i8) -> i32>,
	pub scene_path: Option<unsafe extern "C" fn(*mut std::ffi::c_void, *mut i8, usize) -> i32>,
	pub scene_root_name: Option<unsafe extern "C" fn(*mut std::ffi::c_void, *mut i8, usize) -> i32>,
	pub feature_tags: Option<unsafe extern "C" fn(*mut std::ffi::c_void, *mut i8, usize) -> i32>,
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

#[no_mangle]
pub unsafe extern "C" fn marloth_automation_start(
	host: *const c_char,
	port: u16,
	vtable: *const MarlothGodotOpsVtable,
) -> c_int {
	clear_last_error();
	if host.is_null() || vtable.is_null() {
		set_last_error("host or vtable null");
		return 1;
	}
	let host = match CStr::from_ptr(host).to_str() {
		Ok(s) => s,
		Err(_) => {
			set_last_error("host not utf-8");
			return 1;
		}
	};
	let vt = &*vtable;
	let gvt = GodotOpsVtable {
		userdata: vt.userdata,
		load_scene: vt.load_scene,
		wait_frames: vt.wait_frames,
		class_exists: vt.class_exists,
		scene_path: vt.scene_path,
		scene_root_name: vt.scene_root_name,
		feature_tags: vt.feature_tags,
		mesh_info: vt.mesh_info,
		request_shutdown: vt.request_shutdown,
		last_error: vt.last_error,
	};
	match start_automation(host, port, gvt) {
		Ok(()) => 0,
		Err(e) => {
			set_last_error(&format!("{e:?}"));
			2
		}
	}
}

#[no_mangle]
pub extern "C" fn marloth_automation_poll() {
	marloth_automation::poll_main_thread();
}

#[no_mangle]
pub extern "C" fn marloth_automation_stop() {
	stop_automation();
}
