//! Authoritative game simulation. Engine-agnostic; no Godot types.
//!
//! Godot is a client (presentation) plus isolated services. This crate owns game state.

/// Library / protocol version string for smoke tests and FFI.
pub const VERSION: &str = "0.1.0";

/// Packed client → sim input for one tick (bulk; not per-action FFI).
#[repr(C)]
#[derive(Clone, Copy, Debug, Default, PartialEq)]
pub struct InputFrame {
	pub tick: u64,
	pub dt_seconds: f32,
	pub axes_x: f32,
	pub axes_y: f32,
	pub buttons: u32,
	pub _pad: u32,
}

/// One entity transform intent in a snapshot (sim → client).
#[repr(C)]
#[derive(Clone, Copy, Debug, Default, PartialEq)]
pub struct SnapshotEntity {
	pub entity_id: u32,
	pub pos_x: f32,
	pub pos_y: f32,
	pub pos_z: f32,
	pub yaw: f32,
}

/// Contiguous snapshot produced each tick for the client role.
#[derive(Clone, Debug, Default, PartialEq)]
pub struct Snapshot {
	pub tick: u64,
	pub entities: Vec<SnapshotEntity>,
}

/// Opaque service request blob (sim → Godot services). Empty until real services exist.
#[derive(Clone, Debug, Default, PartialEq)]
pub struct ServiceRequestBlob {
	pub bytes: Vec<u8>,
}

/// Opaque service reply blob (Godot services → sim).
#[derive(Clone, Debug, Default, PartialEq)]
pub struct ServiceReplyBlob {
	pub bytes: Vec<u8>,
}

/// Authoritative world state.
#[derive(Clone, Debug)]
pub struct Sim {
	tick: u64,
	/// Demo entity used to prove bulk snapshot sync (id 1).
	demo_x: f32,
	demo_y: f32,
	demo_z: f32,
	demo_yaw: f32,
	last_service_request: ServiceRequestBlob,
}

impl Default for Sim {
	fn default() -> Self {
		Self::new()
	}
}

impl Sim {
	pub fn new() -> Self {
		Self {
			tick: 0,
			demo_x: 0.0,
			demo_y: 0.5,
			demo_z: 0.0,
			demo_yaw: 0.0,
			last_service_request: ServiceRequestBlob::default(),
		}
	}

	pub fn tick(&self) -> u64 {
		self.tick
	}

	/// Apply a service reply from the previous tick's request (may be empty).
	pub fn apply_service_reply(&mut self, reply: &ServiceReplyBlob) {
		let _ = reply;
		// No services yet; accept empty replies.
	}

	/// Advance one tick from a bulk input frame. Returns service requests for this phase.
	pub fn step(&mut self, input: &InputFrame) -> ServiceRequestBlob {
		self.tick = self.tick.saturating_add(1);
		let dt = if input.dt_seconds > 0.0 {
			input.dt_seconds
		} else {
			1.0 / 60.0
		};
		self.demo_x += input.axes_x * dt * 3.0;
		self.demo_z += input.axes_y * dt * 3.0;
		if input.buttons & 1 != 0 {
			self.demo_yaw += dt * 2.0;
		}
		// Stub service request: encode tick as 8 little-endian bytes when non-zero.
		let mut bytes = Vec::new();
		if self.tick > 0 {
			bytes.extend_from_slice(&self.tick.to_le_bytes());
		}
		self.last_service_request = ServiceRequestBlob { bytes: bytes.clone() };
		ServiceRequestBlob { bytes }
	}

	pub fn snapshot(&self) -> Snapshot {
		Snapshot {
			tick: self.tick,
			entities: vec![SnapshotEntity {
				entity_id: 1,
				pos_x: self.demo_x,
				pos_y: self.demo_y,
				pos_z: self.demo_z,
				yaw: self.demo_yaw,
			}],
		}
	}

	pub fn last_service_request(&self) -> &ServiceRequestBlob {
		&self.last_service_request
	}
}

#[cfg(test)]
mod tests {
	use super::*;

	#[test]
	fn version_is_nonempty() {
		assert!(!VERSION.is_empty());
	}

	#[test]
	fn step_advances_tick_and_moves_demo_entity() {
		let mut sim = Sim::new();
		assert_eq!(sim.tick(), 0);
		let input = InputFrame {
			tick: 0,
			dt_seconds: 1.0,
			axes_x: 1.0,
			axes_y: 0.0,
			buttons: 0,
			_pad: 0,
		};
		let _req = sim.step(&input);
		assert_eq!(sim.tick(), 1);
		let snap = sim.snapshot();
		assert_eq!(snap.tick, 1);
		assert_eq!(snap.entities.len(), 1);
		assert!((snap.entities[0].pos_x - 3.0).abs() < 1e-4);
	}

	#[test]
	fn service_reply_accepts_empty() {
		let mut sim = Sim::new();
		sim.apply_service_reply(&ServiceReplyBlob::default());
		let _ = sim.step(&InputFrame::default());
		assert!(!sim.last_service_request().bytes.is_empty());
	}
}
