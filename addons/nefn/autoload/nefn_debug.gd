extends Node

var console_scene: PackedScene = preload("res://addons/nefn/scenes/debug_console.tscn")
var console_instance: Control
var nefn_manager: Node = null

func _enter_tree() -> void:
	# Get NEFNManager reference
	nefn_manager = get_node_or_null("/root/NEFNManager")
	if not nefn_manager:
		push_error("NEFN: NEFNManager autoload not found!")
		return

func _ready() -> void:
	if not nefn_manager or not nefn_manager.config.debug_console_enabled:
		return
	
	console_instance = console_scene.instantiate()
	add_child(console_instance)
	console_instance.command_entered.connect(execute_command)
	
	# Register basic commands
	register_command("help", _cmd_help, "Show available commands")
	register_command("status", _cmd_status, "Show current connection status")
	register_command("players", _cmd_players, "List connected players")
	register_command("voice", _cmd_voice, "Toggle voice chat")

var commands = {}

func register_command(name: String, callback: Callable, description: String = "") -> void:
	commands[name] = {
		"callback": callback,
		"description": description
	}

func execute_command(command: String) -> void:
	var parts = command.split(" ")
	var cmd_name = parts[0]
	var args = parts.slice(1)
	
	if not commands.has(cmd_name):
		log_error("Unknown command: %s" % cmd_name)
		return
	
	commands[cmd_name]["callback"].call(args)

func log_message(message: String) -> void:
	if not console_instance:
		return
	console_instance.log_message(message)

func log_error(message: String) -> void:
	if not console_instance:
		return
	console_instance.log_error(message)

# Built-in commands
func _cmd_help(_args: Array) -> void:
	var help_text = "Available commands:\n"
	for cmd in commands:
		help_text += "  %s - %s\n" % [cmd, commands[cmd]["description"]]
	log_message(help_text)

func _cmd_status(_args: Array) -> void:
	if not nefn_manager:
		log_error("NEFNManager not available!")
		return
		
	var status = "NEFN Status:\n"
	status += "  Nakama: %s\n" % ("Connected" if nefn_manager.nakama_session else "Disconnected")
	status += "  Network: %s\n" % ("Connected" if nefn_manager.enet_peer else "Disconnected")
	status += "  Voice: %s\n" % ("Enabled" if nefn_manager.noray else "Disabled")
	log_message(status)

func _cmd_players(_args: Array) -> void:
	if not nefn_manager or not nefn_manager.enet_peer:
		log_error("Not connected to any game!")
		return
	
	var peers = multiplayer.get_peers()
	log_message("Connected players: %s" % peers)

func _cmd_voice(args: Array) -> void:
	if not nefn_manager:
		log_error("NEFNManager not available!")
		return
		
	if args.size() > 0 and args[0] == "off":
		nefn_manager.stop_voice()
		log_message("Voice chat disabled")
	else:
		nefn_manager.start_voice()
		log_message("Voice chat enabled") 
