extends Node

# Server manager instance
var server_manager: NEFNServerManager

func _ready() -> void:
	# Create server configuration
	var config = NEFNServerConfig.new()
	
	# Configure network settings
	config.server_ip = "0.0.0.0"  # Listen on all interfaces
	config.port = 7350
	config.max_clients = 32
	config.tick_rate = 64
	
	# Enable performance features
	config.enable_multithreading = true
	config.thread_count = 4
	config.enable_dynamic_threading = true
	config.enable_packet_batching = true
	
	# Configure rollback netcode
	config.enable_rollback = true
	config.rollback_frames = 7
	config.input_delay_frames = 2
	config.sync_interval_ms = 100
	
	# Setup anti-cheat
	config.enable_anti_cheat = true
	config.validate_movement = true
	config.enable_speed_hack_detection = true
	config.packet_validation = true
	
	# Create and initialize server manager
	server_manager = NEFNServerManager.new(config)
	add_child(server_manager)
	
	# Connect to signals
	server_manager.player_violation_detected.connect(_on_player_violation)
	server_manager.player_banned.connect(_on_player_banned)
	server_manager.performance_warning.connect(_on_performance_warning)
	server_manager.rollback_occurred.connect(_on_rollback)
	
	# Start the server
	var error = server_manager.start_server()
	if error == OK:
		print("Server started successfully!")
	else:
		push_error("Failed to start server: %s" % error)

# Signal handlers
func _on_player_violation(player_id: int, violation_type: String, details: String) -> void:
	print("Player %d violated anti-cheat: %s - %s" % [player_id, violation_type, details])

func _on_player_banned(player_id: int, reason: String, duration: float) -> void:
	print("Player %d banned for %.1f seconds: %s" % [player_id, duration, reason])

func _on_performance_warning(type: String, details: String) -> void:
	print("Performance warning: %s - %s" % [type, details])

func _on_rollback(from_tick: int, to_tick: int, reason: String) -> void:
	print("Rollback from tick %d to %d: %s" % [from_tick, to_tick, reason])

# Print server stats periodically
func _process(_delta: float) -> void:
	if Engine.get_process_frames() % 600 == 0:  # Every 10 seconds at 60 FPS
		var stats = server_manager.get_server_stats()
		print("Server Stats:")
		print("- Uptime: %.1f seconds" % stats.uptime)
		print("- Players: %d" % stats.player_count)
		print("- Memory: %.1f MB" % stats.memory_usage)
		print("- Threads: %d" % stats.thread_count)
		print("- Banned Players: %d" % stats.banned_players) 
