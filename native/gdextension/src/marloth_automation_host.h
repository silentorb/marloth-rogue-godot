#pragma once

#include <godot_cpp/classes/node.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <string>

namespace godot {

/// Autoload-capable host: starts Rust tonic automation when MARLOTH_AUTOMATION_ENABLED.
class MarlothAutomationHost : public Node {
	GDCLASS(MarlothAutomationHost, Node);

	bool enabled = false;
	std::string last_error;

protected:
	static void _bind_methods();

public:
	MarlothAutomationHost() = default;
	~MarlothAutomationHost() override;

	void _ready() override;
	void _process(double delta) override;
	void _exit_tree() override;

	std::string &error_slot() { return last_error; }
};

} // namespace godot
