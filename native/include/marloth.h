#ifndef MARLOTH_H
#define MARLOTH_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define MARLOTH_OK 0
#define MARLOTH_ERR_INVALID_ARGUMENT 1
#define MARLOTH_ERR_FAILED 2

typedef int32_t MarlothStatus;

typedef struct MarlothInputFrame {
	uint64_t tick;
	float dt_seconds;
	float axes_x;
	float axes_y;
	uint32_t buttons;
	uint32_t _pad;
} MarlothInputFrame;

typedef struct MarlothSnapshotEntity {
	uint32_t entity_id;
	float pos_x;
	float pos_y;
	float pos_z;
	float yaw;
} MarlothSnapshotEntity;

typedef struct MarlothSim MarlothSim;

const char *marloth_version(void);
const char *marloth_last_error(void);

MarlothStatus marloth_sim_create(MarlothSim **out_sim);
void marloth_sim_destroy(MarlothSim *sim);

MarlothStatus marloth_sim_apply_service_reply(
		MarlothSim *sim,
		const uint8_t *bytes,
		size_t len);

MarlothStatus marloth_sim_step(
		MarlothSim *sim,
		const MarlothInputFrame *input,
		const uint8_t **out_service_req,
		size_t *out_service_req_len);

MarlothStatus marloth_sim_snapshot(
		MarlothSim *sim,
		uint64_t *out_tick,
		const MarlothSnapshotEntity **out_entities,
		size_t *out_entity_count);

/* Automation */

typedef struct MarlothGodotOpsVtable {
	void *userdata;
	int32_t (*load_scene)(void *userdata, const char *path);
	int32_t (*wait_frames)(void *userdata, int32_t count);
	int32_t (*class_exists)(void *userdata, const char *name);
	int32_t (*scene_path)(void *userdata, char *buf, size_t buf_len);
	int32_t (*scene_root_name)(void *userdata, char *buf, size_t buf_len);
	int32_t (*feature_tags)(void *userdata, char *buf, size_t buf_len);
	int32_t (*mesh_info)(
			void *userdata,
			const char *node_path,
			int32_t *out_found,
			int32_t *out_has_mesh,
			int32_t *out_surface_count,
			int32_t *out_vertex_count);
	int32_t (*request_shutdown)(void *userdata);
	int32_t (*last_error)(void *userdata, char *buf, size_t buf_len);
} MarlothGodotOpsVtable;

MarlothStatus marloth_automation_start(
		const char *host,
		uint16_t port,
		const MarlothGodotOpsVtable *vtable);

void marloth_automation_poll(void);
void marloth_automation_stop(void);

#ifdef __cplusplus
}
#endif

#endif /* MARLOTH_H */
