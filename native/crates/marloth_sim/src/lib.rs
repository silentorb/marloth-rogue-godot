//! Authoritative game simulation. Engine-agnostic; no Godot types.
//!
//! Positions and yaw use right-handed Z-up (+X right, +Y forward/north, +Z up).
//! Godot is a client (presentation) plus isolated services; hosts convert at the boundary.

/// Library / protocol version string for smoke tests and FFI.
pub const VERSION: &str = "0.1.0";

/// Packed client → sim input for one tick (bulk; not per-action FFI).
///
/// `axes_x` / `axes_y` are reserved for future sim locomotion. While client
/// `CharacterBody3D` owns movement, axes do not move actors.
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
///
/// `pos_*` and `yaw` are right-handed Z-up (yaw about +Z). Hosts convert for Godot.
/// `entity_id` is the actor id.
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

/// RH Z-up pose (yaw about +Z).
#[derive(Clone, Copy, Debug, Default, PartialEq)]
pub struct Pose {
	pub x: f32,
	pub y: f32,
	pub z: f32,
	pub yaw: f32,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub struct PlayerId(pub u32);

#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub struct CharacterId(pub u32);

#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub struct ActorId(pub u32);

#[derive(Clone, Debug, PartialEq)]
pub struct Player {
	pub id: PlayerId,
	pub character: Option<CharacterId>,
}

#[derive(Clone, Debug, PartialEq)]
pub struct Character {
	pub id: CharacterId,
	pub actor: Option<ActorId>,
}

#[derive(Clone, Debug, PartialEq)]
pub struct Actor {
	pub id: ActorId,
	pub pose: Pose,
}

/// Expected failure for association / bootstrap APIs.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum SimError {
	AlreadyBootstrapped,
	UnknownActor,
}

/// Authoritative world state.
#[derive(Clone, Debug)]
pub struct Sim {
	tick: u64,
	players: Vec<Player>,
	characters: Vec<Character>,
	actors: Vec<Actor>,
	next_player_id: u32,
	next_character_id: u32,
	next_actor_id: u32,
	local_player_bootstrapped: bool,
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
			players: Vec::new(),
			characters: Vec::new(),
			actors: Vec::new(),
			next_player_id: 1,
			next_character_id: 1,
			next_actor_id: 1,
			local_player_bootstrapped: false,
			last_service_request: ServiceRequestBlob::default(),
		}
	}

	pub fn tick(&self) -> u64 {
		self.tick
	}

	pub fn players(&self) -> &[Player] {
		&self.players
	}

	pub fn characters(&self) -> &[Character] {
		&self.characters
	}

	pub fn actors(&self) -> &[Actor] {
		&self.actors
	}

	pub fn local_player_id(&self) -> Option<PlayerId> {
		self.players.first().map(|p| p.id)
	}

	/// Create local player 0 with a linked character and actor at `spawn`.
	pub fn bootstrap_local_player(
		&mut self,
		spawn: Pose,
	) -> Result<(PlayerId, CharacterId, ActorId), SimError> {
		if self.local_player_bootstrapped {
			return Err(SimError::AlreadyBootstrapped);
		}
		let player_id = PlayerId(self.next_player_id);
		self.next_player_id = self.next_player_id.saturating_add(1);
		let character_id = CharacterId(self.next_character_id);
		self.next_character_id = self.next_character_id.saturating_add(1);
		let actor_id = ActorId(self.next_actor_id);
		self.next_actor_id = self.next_actor_id.saturating_add(1);

		self.actors.push(Actor {
			id: actor_id,
			pose: spawn,
		});
		self.characters.push(Character {
			id: character_id,
			actor: Some(actor_id),
		});
		self.players.push(Player {
			id: player_id,
			character: Some(character_id),
		});
		self.local_player_bootstrapped = true;
		Ok((player_id, character_id, actor_id))
	}

	/// Client reports last-known actor pose (interim CharacterBody3D locomotion).
	pub fn set_actor_pose(&mut self, actor_id: ActorId, pose: Pose) -> Result<(), SimError> {
		let actor = self
			.actors
			.iter_mut()
			.find(|a| a.id == actor_id)
			.ok_or(SimError::UnknownActor)?;
		actor.pose = pose;
		Ok(())
	}

	/// Apply a service reply from the previous tick's request (may be empty).
	pub fn apply_service_reply(&mut self, reply: &ServiceReplyBlob) {
		let _ = reply;
		// No services yet; accept empty replies.
	}

	/// Advance one tick from a bulk input frame. Returns service requests for this phase.
	///
	/// Axes do not move actors while client locomotion owns movement.
	pub fn step(&mut self, input: &InputFrame) -> ServiceRequestBlob {
		self.tick = self.tick.saturating_add(1);
		let _ = input;
		// Stub service request: encode tick as 8 little-endian bytes when non-zero.
		let mut bytes = Vec::new();
		if self.tick > 0 {
			bytes.extend_from_slice(&self.tick.to_le_bytes());
		}
		self.last_service_request = ServiceRequestBlob {
			bytes: bytes.clone(),
		};
		ServiceRequestBlob { bytes }
	}

	pub fn snapshot(&self) -> Snapshot {
		Snapshot {
			tick: self.tick,
			entities: self
				.actors
				.iter()
				.map(|a| SnapshotEntity {
					entity_id: a.id.0,
					pos_x: a.pose.x,
					pos_y: a.pose.y,
					pos_z: a.pose.z,
					yaw: a.pose.yaw,
				})
				.collect(),
		}
	}

	pub fn last_service_request(&self) -> &ServiceRequestBlob {
		&self.last_service_request
	}
}

#[cfg(test)]
mod tests {
	use super::*;

	fn spawn_pose() -> Pose {
		Pose {
			x: 1.0,
			y: 2.0,
			z: 0.5,
			yaw: 0.25,
		}
	}

	#[test]
	fn version_is_nonempty() {
		assert!(!VERSION.is_empty());
	}

	#[test]
	fn bootstrap_links_player_character_actor() {
		let mut sim = Sim::new();
		let (player_id, character_id, actor_id) = sim
			.bootstrap_local_player(spawn_pose())
			.expect("bootstrap");
		assert_eq!(player_id, PlayerId(1));
		assert_eq!(character_id, CharacterId(1));
		assert_eq!(actor_id, ActorId(1));
		assert_eq!(sim.players().len(), 1);
		assert_eq!(sim.players()[0].character, Some(character_id));
		assert_eq!(sim.characters()[0].actor, Some(actor_id));
		assert_eq!(sim.actors()[0].pose, spawn_pose());
		let snap = sim.snapshot();
		assert_eq!(snap.entities.len(), 1);
		assert_eq!(snap.entities[0].entity_id, 1);
		assert!((snap.entities[0].pos_x - 1.0).abs() < 1e-4);
		assert!((snap.entities[0].pos_y - 2.0).abs() < 1e-4);
		assert!((snap.entities[0].pos_z - 0.5).abs() < 1e-4);
		assert!((snap.entities[0].yaw - 0.25).abs() < 1e-4);
	}

	#[test]
	fn double_bootstrap_fails() {
		let mut sim = Sim::new();
		sim.bootstrap_local_player(Pose::default())
			.expect("first bootstrap");
		assert_eq!(
			sim.bootstrap_local_player(Pose::default()),
			Err(SimError::AlreadyBootstrapped)
		);
	}

	#[test]
	fn set_actor_pose_updates_snapshot() {
		let mut sim = Sim::new();
		let (_, _, actor_id) = sim
			.bootstrap_local_player(Pose::default())
			.expect("bootstrap");
		let pose = Pose {
			x: 3.0,
			y: -1.0,
			z: 1.5,
			yaw: 1.0,
		};
		sim.set_actor_pose(actor_id, pose).expect("set pose");
		let snap = sim.snapshot();
		assert_eq!(snap.entities.len(), 1);
		assert!((snap.entities[0].pos_x - 3.0).abs() < 1e-4);
		assert!((snap.entities[0].pos_y - -1.0).abs() < 1e-4);
		assert!((snap.entities[0].pos_z - 1.5).abs() < 1e-4);
		assert!((snap.entities[0].yaw - 1.0).abs() < 1e-4);
	}

	#[test]
	fn set_actor_pose_unknown_fails() {
		let mut sim = Sim::new();
		assert_eq!(
			sim.set_actor_pose(ActorId(99), Pose::default()),
			Err(SimError::UnknownActor)
		);
	}

	#[test]
	fn step_advances_tick_without_moving_from_axes() {
		let mut sim = Sim::new();
		let (_, _, _) = sim
			.bootstrap_local_player(spawn_pose())
			.expect("bootstrap");
		let input = InputFrame {
			tick: 0,
			dt_seconds: 1.0,
			axes_x: 1.0,
			axes_y: 1.0,
			buttons: 0,
			_pad: 0,
		};
		let _req = sim.step(&input);
		assert_eq!(sim.tick(), 1);
		let snap = sim.snapshot();
		assert_eq!(snap.tick, 1);
		assert!((snap.entities[0].pos_x - 1.0).abs() < 1e-4);
		assert!((snap.entities[0].pos_y - 2.0).abs() < 1e-4);
	}

	#[test]
	fn service_reply_accepts_empty() {
		let mut sim = Sim::new();
		sim.apply_service_reply(&ServiceReplyBlob::default());
		let _ = sim.step(&InputFrame::default());
		assert!(!sim.last_service_request().bytes.is_empty());
	}

	#[test]
	fn snapshot_empty_before_bootstrap() {
		let sim = Sim::new();
		assert!(sim.snapshot().entities.is_empty());
	}
}
