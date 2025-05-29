@tool
extends EditorPlugin

const AUTOLOAD_MANAGER = "res://addons/nefn/autoload/nefn_manager.gd"
const AUTOLOAD_DEBUG = "res://addons/nefn/autoload/nefn_debug.gd"
const CONFIG_PATH = "res://addons/nefn/config.tres"

func _enter_tree() -> void:
	# Add autoload singletons in correct order
	add_autoload_singleton("NEFNManager", AUTOLOAD_MANAGER)  # Must be first
	add_autoload_singleton("NEFNDebug", AUTOLOAD_DEBUG)     # Depends on NEFNManager

	# Create default config if it doesn't exist
	if not FileAccess.file_exists(CONFIG_PATH):
		var config = NEFNConfiguration.new()
		var err = ResourceSaver.save(config, CONFIG_PATH)
		if err != OK:
			push_error("NEFN: Failed to create default configuration file!")

func _exit_tree() -> void:
	# Remove autoload singletons in reverse order
	remove_autoload_singleton("NEFNDebug")
	remove_autoload_singleton("NEFNManager") 