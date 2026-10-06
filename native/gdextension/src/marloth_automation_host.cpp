#include "marloth_automation_host.h"

#include "marloth.h"

#include <cstdio>
#include <cstdlib>
#include <cstring>

#include <godot_cpp/classes/engine.hpp>
#include <godot_cpp/classes/mesh.hpp>
#include <godot_cpp/classes/mesh_instance3d.hpp>
#include <godot_cpp/classes/node.hpp>
#include <godot_cpp/classes/os.hpp>
#include <godot_cpp/classes/scene_tree.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

using namespace godot;

namespace {

MarlothAutomationHost *g_host = nullptr;

bool env_truthy(const char *name) {
	const char *v = std::getenv(name);
	if (!v || !*v) {
		return false;
	}
	return std::strcmp(v, "1") == 0 || std::strcmp(v, "true") == 0 || std::strcmp(v, "TRUE") == 0 ||
			std::strcmp(v, "yes") == 0 || std::strcmp(v, "YES") == 0;
}

void set_err(MarlothAutomationHost *host, const char *msg) {
	if (host) {
		host->error_slot() = msg ? msg : "";
	}
}

int32_t cb_last_error(void *userdata, char *buf, size_t buf_len) {
	auto *host = static_cast<MarlothAutomationHost *>(userdata);
	if (!host || !buf || buf_len == 0) {
		return -1;
	}
	const std::string &e = host->error_slot();
	std::snprintf(buf, buf_len, "%s", e.c_str());
	return 0;
}

int32_t cb_load_scene(void *userdata, const char *path) {
	auto *host = static_cast<MarlothAutomationHost *>(userdata);
	if (!host || !path) {
		return -1;
	}
	SceneTree *tree = host->get_tree();
	if (!tree) {
		set_err(host, "no SceneTree");
		return -1;
	}
	Error err = tree->change_scene_to_file(String(path));
	if (err != OK) {
		set_err(host, "change_scene_to_file failed");
		return -1;
	}
	set_err(host, "");
	return 0;
}

int32_t cb_wait_frames(void *userdata, int32_t) {
	// Frame waits are handled in Rust across poll ticks; vtable unused.
	(void)userdata;
	return 0;
}

int32_t cb_class_exists(void *userdata, const char *name) {
	auto *host = static_cast<MarlothAutomationHost *>(userdata);
	if (!name) {
		set_err(host, "class name null");
		return -1;
	}
	const bool exists = ClassDB::class_exists(StringName(String(name)));
	set_err(host, "");
	return exists ? 1 : 0;
}

int32_t write_string(MarlothAutomationHost *host, const String &value, char *buf, size_t buf_len) {
	if (!buf || buf_len == 0) {
		set_err(host, "buffer null");
		return -1;
	}
	const CharString utf8 = value.utf8();
	std::snprintf(buf, buf_len, "%s", utf8.get_data());
	set_err(host, "");
	return 0;
}

int32_t cb_scene_path(void *userdata, char *buf, size_t buf_len) {
	auto *host = static_cast<MarlothAutomationHost *>(userdata);
	SceneTree *tree = host ? host->get_tree() : nullptr;
	if (!tree) {
		set_err(host, "no SceneTree");
		return -1;
	}
	Node *scene = tree->get_current_scene();
	if (!scene) {
		return write_string(host, String(), buf, buf_len);
	}
	return write_string(host, scene->get_scene_file_path(), buf, buf_len);
}

int32_t cb_scene_root_name(void *userdata, char *buf, size_t buf_len) {
	auto *host = static_cast<MarlothAutomationHost *>(userdata);
	SceneTree *tree = host ? host->get_tree() : nullptr;
	if (!tree) {
		set_err(host, "no SceneTree");
		return -1;
	}
	Node *scene = tree->get_current_scene();
	if (!scene) {
		return write_string(host, String(), buf, buf_len);
	}
	return write_string(host, scene->get_name(), buf, buf_len);
}

int32_t cb_feature_tags(void *userdata, char *buf, size_t buf_len) {
	auto *host = static_cast<MarlothAutomationHost *>(userdata);
	Dictionary info = Engine::get_singleton()->get_version_info();
	String version = String::num_int64(static_cast<int64_t>(info.get("major", 0))) + "." +
			String::num_int64(static_cast<int64_t>(info.get("minor", 0))) + "." +
			String::num_int64(static_cast<int64_t>(info.get("patch", 0)));
	String tags = String("godot=") + version;
	return write_string(host, tags, buf, buf_len);
}

int32_t cb_mesh_info(
		void *userdata,
		const char *node_path,
		int32_t *out_found,
		int32_t *out_has_mesh,
		int32_t *out_surface_count,
		int32_t *out_vertex_count) {
	auto *host = static_cast<MarlothAutomationHost *>(userdata);
	if (!out_found || !out_has_mesh || !out_surface_count || !out_vertex_count) {
		set_err(host, "mesh out pointers null");
		return -1;
	}
	*out_found = 0;
	*out_has_mesh = 0;
	*out_surface_count = 0;
	*out_vertex_count = 0;
	SceneTree *tree = host ? host->get_tree() : nullptr;
	Node *scene = tree ? tree->get_current_scene() : nullptr;
	if (!scene || !node_path) {
		set_err(host, "no current scene");
		return 0;
	}
	Node *node = scene->get_node_or_null(NodePath(String(node_path)));
	if (!node) {
		set_err(host, "");
		return 0;
	}
	*out_found = 1;
	auto *mi = Object::cast_to<MeshInstance3D>(node);
	if (!mi) {
		set_err(host, "");
		return 0;
	}
	Ref<Mesh> mesh = mi->get_mesh();
	if (mesh.is_null()) {
		set_err(host, "");
		return 0;
	}
	*out_has_mesh = 1;
	const int surfaces = mesh->get_surface_count();
	*out_surface_count = surfaces;
	int verts = 0;
	for (int s = 0; s < surfaces; s++) {
		Array arrays = mesh->surface_get_arrays(s);
		if (arrays.size() > Mesh::ARRAY_VERTEX) {
			PackedVector3Array v = arrays[Mesh::ARRAY_VERTEX];
			verts += static_cast<int>(v.size());
		}
	}
	*out_vertex_count = verts;
	set_err(host, "");
	return 0;
}

int32_t cb_request_shutdown(void *userdata) {
	auto *host = static_cast<MarlothAutomationHost *>(userdata);
	if (!host) {
		return -1;
	}
	host->get_tree()->quit();
	set_err(host, "");
	return 0;
}

} // namespace

void MarlothAutomationHost::_bind_methods() {}

MarlothAutomationHost::~MarlothAutomationHost() {
	if (enabled) {
		marloth_automation_stop();
	}
	if (g_host == this) {
		g_host = nullptr;
	}
}

void MarlothAutomationHost::_ready() {
	if (Engine::get_singleton()->is_editor_hint()) {
		return;
	}
	enabled = env_truthy("MARLOTH_AUTOMATION_ENABLED");
	if (!enabled) {
		return;
	}
	g_host = this;

	const char *host_env = std::getenv("MARLOTH_AUTOMATION_HOST");
	const char *host = (host_env && *host_env) ? host_env : "127.0.0.1";
	uint16_t port = 50061;
	if (const char *port_env = std::getenv("MARLOTH_AUTOMATION_PORT")) {
		int parsed = std::atoi(port_env);
		if (parsed > 0 && parsed < 65536) {
			port = static_cast<uint16_t>(parsed);
		}
	}

	MarlothGodotOpsVtable vt{};
	vt.userdata = this;
	vt.load_scene = cb_load_scene;
	vt.wait_frames = cb_wait_frames;
	vt.class_exists = cb_class_exists;
	vt.scene_path = cb_scene_path;
	vt.scene_root_name = cb_scene_root_name;
	vt.feature_tags = cb_feature_tags;
	vt.mesh_info = cb_mesh_info;
	vt.request_shutdown = cb_request_shutdown;
	vt.last_error = cb_last_error;

	if (marloth_automation_start(host, port, &vt) != MARLOTH_OK) {
		UtilityFunctions::push_error("MarlothAutomationHost: start failed: ", marloth_last_error());
		enabled = false;
		return;
	}
	UtilityFunctions::print("MarlothAutomationHost listening on ", host, ":", port);
}

void MarlothAutomationHost::_process(double) {
	if (!enabled) {
		return;
	}
	marloth_automation_poll();
}

void MarlothAutomationHost::_exit_tree() {
	if (enabled) {
		marloth_automation_stop();
		enabled = false;
	}
}
