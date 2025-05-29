extends Node
class_name NEFNServerManager

# Configuration
var config: NEFNServerConfig
var server_state: Dictionary = {
	"running": false,
	"start_time": 0,
	"player_count": 0,
	"tick_count": 0
}

# Performance monitoring
var _performance_monitor: Timer
var _thread_pool: Array[Thread] = []
var _thread_tasks: Array = []
var _thread_mutex: Mutex = Mutex.new()
var _thread_semaphore: Semaphore = Semaphore.new()

# Rollback netcode
var _game_state_history: Array = []
var _input_history: Dictionary = {}
var _current_tick: int = 0
var _last_confirmed_tick: int = 0

# Anti-cheat
var _player_states: Dictionary = {}
var _violation_counts: Dictionary = {}
var _banned_players: Dictionary = {}

# Server modes
const MODE_NORMAL := 0
const MODE_HEADLESS := 1
const MODE_DEDICATED := 2

# Additional server features
var server_mode: int = MODE_NORMAL
var auto_restart: bool = false
var auto_restart_interval: int = 24 * 3600  # 24 hours in seconds
var last_restart_time: int = 0
var server_stats: Dictionary = {}
var command_history: Array = []
var server_regions: Array = ["NA", "EU", "AS", "SA", "AF", "OC"]  # Available regions

# Server status tracking
var server_metrics: Dictionary = {
	"start_time": 0,
	"uptime": 0,
	"total_connections": 0,
	"peak_players": 0,
	"total_bytes_sent": 0,
	"total_bytes_received": 0,
	"average_ping": 0.0,
	"cpu_usage": 0.0,
	"memory_usage": 0.0,
	"network_loss": 0.0
}

# Backup system
var backup_enabled: bool = true
var backup_interval: int = 3600  # 1 hour in seconds
var last_backup_time: int = 0
var max_backups: int = 5
var backup_path: String = "user://server_backups/"

# Command system
var registered_commands: Dictionary = {}

# Signals
signal player_violation_detected(player_id: int, violation_type: String, details: String)
signal player_banned(player_id: int, reason: String, duration: float)
signal performance_warning(type: String, details: String)
signal rollback_occurred(from_tick: int, to_tick: int, reason: String)
signal server_started
signal server_stopped
signal player_connected(peer_id: int)
signal player_disconnected(peer_id: int)
signal player_violation(peer_id: int, violation: String, count: int)
signal log_message(message: String)

func _init(server_config: NEFNServerConfig = null) -> void:
	if server_config:
		config = server_config
	else:
		config = NEFNServerConfig.new()
	
	# Initialize systems
	_init_performance_monitoring()
	_init_rollback_system()
	_init_anti_cheat()
	_init_backup_system()
	_init_command_system()
	
	# Check if running in headless mode
	if OS.has_feature("server"):
		server_mode = MODE_HEADLESS
		print("Starting in headless mode...")

func _ready() -> void:
	# Connect to network signals
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

# Server Management
func start_server(server_config: NEFNServerConfig = null) -> Error:
	if server_state.running:
		return ERR_ALREADY_IN_USE
		
	# Update config if provided
	if server_config:
		config = server_config
	
	# Create server
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(config.port, config.max_clients)
	if error != OK:
		return error
		
	# Configure server
	peer.set_bind_ip(config.server_ip)
	multiplayer.multiplayer_peer = peer
	
	# Start systems
	_start_performance_monitoring()
	_start_rollback_system()
	_start_anti_cheat()
	
	server_state.running = true
	server_state.start_time = Time.get_unix_time_from_system()
	emit_signal("server_started")
	return OK

# Modify your existing stop_server method to be more graceful
func stop_server() -> void:
	if not server_state.running:
		return
	
	print("Starting graceful server shutdown...")
	
	# First, disconnect all clients gracefully
	_disconnect_all_clients_gracefully()
	
	# Wait a moment for disconnections to process
	await get_tree().create_timer(1.0).timeout
	
	# Stop systems
	_stop_performance_monitoring()
	_stop_rollback_system()
	_stop_anti_cheat()
	
	# Stop ping system
	if _ping_timer:
		_ping_timer.stop()
	
	# Clear multiplayer peer
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer = null
	
	server_state.running = false
	emit_signal("server_stopped")
	print("Server shutdown completed.")

# Performance Monitoring System
func _init_performance_monitoring() -> void:
	if not config.enable_multithreading:
		return
		
	# Setup performance monitor
	_performance_monitor = Timer.new()
	_performance_monitor.wait_time = config.metrics_interval
	_performance_monitor.timeout.connect(_check_performance)
	add_child(_performance_monitor)
	
	# Initialize thread pool
	for i in range(config.thread_count):
		var thread = Thread.new()
		_thread_pool.append(thread)
		thread.start(_thread_worker)

func _start_performance_monitoring() -> void:
	if _performance_monitor:
		_performance_monitor.start()

func _stop_performance_monitoring() -> void:
	if _performance_monitor:
		_performance_monitor.stop()
	
	# Stop all threads
	for thread in _thread_pool:
		if thread.is_started():
			thread.wait_to_finish()
	_thread_pool.clear()

func _check_performance() -> void:
	# Check CPU usage
	var cpu_usage = Performance.get_monitor(Performance.TIME_PROCESS) * 100
	if cpu_usage > config.cpu_threshold_high:
		_adjust_thread_count(-1)
		performance_warning.emit("high_cpu", "CPU usage: %d%%" % cpu_usage)
	elif cpu_usage < config.cpu_threshold_low:
		_adjust_thread_count(1)
	
	# Check memory usage
	var memory_mb = Performance.get_monitor(Performance.MEMORY_STATIC) / 1024 / 1024
	if memory_mb > config.max_memory_mb:
		performance_warning.emit("high_memory", "Memory usage: %.1f MB" % memory_mb)

func _adjust_thread_count(delta: int) -> void:
	var new_count = clamp(
		_thread_pool.size() + delta,
		config.min_threads,
		config.max_threads
	)
	
	if new_count == _thread_pool.size():
		return
	
	if delta > 0:
		# Add threads
		for i in range(delta):
			var thread = Thread.new()
			_thread_pool.append(thread)
			thread.start(_thread_worker)
	else:
		# Remove threads
		for i in range(-delta):
			if _thread_pool.size() > 0:
				var thread = _thread_pool.pop_back()
				if thread.is_started():
					thread.wait_to_finish()

func _thread_worker() -> void:
	while server_state.running:
		_thread_semaphore.wait()
		
		_thread_mutex.lock()
		var task = _thread_tasks.pop_front() if _thread_tasks.size() > 0 else null
		_thread_mutex.unlock()
		
		if task:
			_execute_task(task)

func _execute_task(task: Dictionary) -> void:
	if task.has("func") and task.has("args"):
		callv(task.func, task.args)

# Rollback Netcode System
func _init_rollback_system() -> void:
	if not config.enable_rollback:
		return
	
	_game_state_history.clear()
	_input_history.clear()
	_current_tick = 0
	_last_confirmed_tick = 0

func _start_rollback_system() -> void:
	if not config.enable_rollback:
		return
	
	# Start tick processing
	set_physics_process(true)

func _stop_rollback_system() -> void:
	set_physics_process(false)
	_game_state_history.clear()
	_input_history.clear()

func _physics_process(delta: float) -> void:
	if not config.enable_rollback or not server_state.running:
		return
	
	_current_tick += 1
	
	# Process inputs and update game state
	var current_state = _process_tick(_current_tick)
	
	# Store state in history
	_store_game_state(current_state, _current_tick)
	
	# Clean up old history
	_cleanup_old_states()

func _process_tick(tick: int) -> Dictionary:
	var state = {}
	
	# Get inputs for this tick
	var inputs = _get_inputs_for_tick(tick)
	
	# Apply inputs and get new state
	state = _apply_inputs(inputs)
	
	# Validate state
	if _validate_state(state):
		return state
	else:
		# State invalid, trigger rollback
		return _trigger_rollback(tick)

func _store_game_state(state: Dictionary, tick: int) -> void:
	_game_state_history.append({"tick": tick, "state": state})
	
	# Keep only necessary history
	while _game_state_history.size() > config.max_rollback_frames:
		_game_state_history.pop_front()

func _trigger_rollback(from_tick: int) -> Dictionary:
	# Find last valid state
	var valid_state = null
	var valid_tick = from_tick
	
	for i in range(_game_state_history.size() - 1, -1, -1):
		var history = _game_state_history[i]
		if _validate_state(history.state):
			valid_state = history.state
			valid_tick = history.tick
			break
	
	if valid_state:
		rollback_occurred.emit(from_tick, valid_tick, "State validation failed")
		return valid_state
	
	return {}

# Anti-Cheat System
func _init_anti_cheat() -> void:
	if not config.enable_anti_cheat:
		return
	
	_player_states.clear()
	_violation_counts.clear()
	_banned_players.clear()

func _start_anti_cheat() -> void:
	if not config.enable_anti_cheat:
		return
	
	# Start monitoring
	set_process(true)

func _stop_anti_cheat() -> void:
	set_process(false)
	_player_states.clear()
	_violation_counts.clear()

func _process(delta: float) -> void:
	if !server_state.running:
		return
	
	# Update server metrics
	_update_server_metrics(delta)
	
	# Check for auto-restart
	if auto_restart and Time.get_unix_time_from_system() - last_restart_time >= auto_restart_interval:
		_auto_restart_server()
	
	# Check for auto-backup
	if backup_enabled and Time.get_unix_time_from_system() - last_backup_time >= backup_interval:
		_create_backup()
	
	# Anti-cheat checks
	if config.enable_anti_cheat:
		# Check for speed hacks
		if config.enable_speed_hack_detection:
			_check_speed_hacks()
		
		# Check for position hacks
		if config.validate_movement:
			_check_position_hacks()
		
		# Check packet rates
		if config.packet_validation:
			_check_packet_rates()

func _check_speed_hacks() -> void:
	for player_id in _player_states:
		var state = _player_states[player_id]
		if not state.has("velocity"):
			continue
		
		var speed = state.velocity.length()
		if speed > config.max_player_speed:
			_record_violation(player_id, "speed_hack", 
				"Speed %.1f exceeds maximum %.1f" % [speed, config.max_player_speed])

func _check_position_hacks() -> void:
	for player_id in _player_states:
		var state = _player_states[player_id]
		if not state.has("position") or not state.has("last_position"):
			continue
		
		var delta = state.position.distance_to(state.last_position)
		if delta > config.position_error_threshold:
			_record_violation(player_id, "position_hack",
				"Position delta %.1f exceeds threshold %.1f" % [delta, config.position_error_threshold])

func _check_packet_rates() -> void:
	for player_id in _player_states:
		var state = _player_states[player_id]
		if not state.has("packet_count") or not state.has("last_packet_time"):
			continue
		
		var now = Time.get_unix_time_from_system()
		var time_diff = now - state.last_packet_time
		if time_diff >= 1.0:
			if state.packet_count > config.max_packets_per_second:
				_record_violation(player_id, "packet_flood",
					"Packet rate %d exceeds maximum %d" % [state.packet_count, config.max_packets_per_second])
			state.packet_count = 0
			state.last_packet_time = now

func _record_violation(player_id: int, type: String, details: String) -> void:
	if not _violation_counts.has(player_id):
		_violation_counts[player_id] = {}
	
	if not _violation_counts[player_id].has(type):
		_violation_counts[player_id][type] = 0
	
	_violation_counts[player_id][type] += 1
	
	# Emit signal for logging/monitoring
	player_violation_detected.emit(player_id, type, details)
	
	# Check for ban threshold
	var total_violations = 0
	for vtype in _violation_counts[player_id]:
		total_violations += _violation_counts[player_id][vtype]
	
	if total_violations >= 5:  # Configure threshold as needed
		_ban_player(player_id, "Multiple violations: " + type)

func _ban_player(player_id: int, reason: String) -> void:
	if _banned_players.has(player_id):
		return
	
	var duration = 3600.0  # 1 hour ban by default
	_banned_players[player_id] = {
		"reason": reason,
		"timestamp": Time.get_unix_time_from_system(),
		"duration": duration
	}
	
	# Emit signal and kick player
	player_banned.emit(player_id, reason, duration)
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.disconnect_peer(player_id)

# Network Event Handlers
func _on_peer_connected(peer_id: int) -> void:
	if _banned_players.has(peer_id):
		var ban_info = _banned_players[peer_id]
		var current_time = Time.get_unix_time_from_system()
		if current_time - ban_info.timestamp < ban_info.duration:
			multiplayer.multiplayer_peer.disconnect_peer(peer_id)
			return
		_banned_players.erase(peer_id)
	
	server_state.player_count += 1
	
	# Initialize player state
	_player_states[peer_id] = {
		"position": Vector3.ZERO,
		"last_position": Vector3.ZERO,
		"velocity": Vector3.ZERO,
		"packet_count": 0,
		"last_packet_time": Time.get_unix_time_from_system(),
		"join_time": Time.get_unix_time_from_system(),
		"last_input_time": 0,
		"input_count": 0
	}
	
	# Send current game state
	_send_game_state_to_player(peer_id)
	emit_signal("player_connected", peer_id)

func _on_peer_disconnected(peer_id: int) -> void:
	server_state.player_count -= 1
	
	# Cleanup player data
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.disconnect_peer(peer_id)
	_player_states.erase(peer_id)
	_violation_counts.erase(peer_id)
	_input_history.erase(peer_id)
	emit_signal("player_disconnected", peer_id)

# RPC Methods
@rpc("any_peer")
func receive_player_input(input_data: Dictionary) -> void:
	var peer_id = multiplayer.get_remote_sender_id()
	
	# Store input for rollback
	if not _input_history.has(peer_id):
		_input_history[peer_id] = []
	_input_history[peer_id].append({"tick": _current_tick, "data": input_data})
	
	# Update packet count for anti-cheat
	if _player_states.has(peer_id):
		_player_states[peer_id].packet_count += 1

@rpc("authority")
func send_game_state(state: Dictionary, tick: int) -> void:
	# Server sends authoritative state to clients
	pass

func _send_game_state_to_player(peer_id: int) -> void:
	if _game_state_history.size() > 0:
		var current_state = _game_state_history[-1].state
		send_game_state.rpc_id(peer_id, current_state, _current_tick)

# Utility Methods
func get_server_stats() -> Dictionary:
	return {
		"uptime": Time.get_unix_time_from_system() - server_state.start_time,
		"player_count": server_state.player_count,
		"tick_rate": Engine.physics_ticks_per_second,
		"memory_usage": Performance.get_monitor(Performance.MEMORY_STATIC) / 1024 / 1024,
		"thread_count": _thread_pool.size(),
		"banned_players": _banned_players.size()
	}

func _cleanup_old_states() -> void:
	var min_tick = _current_tick - config.max_rollback_frames
	
	# Remove old states
	_game_state_history = _game_state_history.filter(func(state): return state.tick >= min_tick)
	
	# Remove old inputs
	for peer_id in _input_history.keys():
		var peer_inputs = _input_history[peer_id] as Array
		_input_history[peer_id] = peer_inputs.filter(func(input): return input.tick >= min_tick)

func _get_inputs_for_tick(tick: int) -> Dictionary:
	var inputs = {}
	for peer_id in _input_history.keys():
		var peer_inputs = _input_history[peer_id] as Array
		for input in peer_inputs:
			if input.tick == tick:
				inputs[peer_id] = input.data
				break
	return inputs

func _apply_inputs(inputs: Dictionary) -> Dictionary:
	var new_state = {}
	
	# Apply each player's input to the state
	for peer_id in inputs.keys():
		var input = inputs[peer_id]
		if peer_id in _player_states:
			var player_state = _player_states[peer_id]
			_apply_player_input(player_state, input)
	
	return new_state

func _apply_player_input(player_state: Dictionary, input: Dictionary) -> void:
	# Apply movement
	if "movement" in input:
		var movement = input.movement
		player_state.position += movement * config.tick_rate
	
	# Apply actions
	if "actions" in input:
		for action in input.actions:
			_validate_and_apply_action(player_state, action)

func _validate_and_apply_action(player_state: Dictionary, action: Dictionary) -> void:
	# First validate the action
	if !_validate_action(action):
		return
		
	# Apply different types of actions
	match action.type:
		"attack":
			_apply_attack_action(player_state, action)
		"interact":
			_apply_interact_action(player_state, action)
		"ability":
			_apply_ability_action(player_state, action)
		"item":
			_apply_item_action(player_state, action)

func _validate_action(action: Dictionary) -> bool:
	if !action.has("type"):
		return false
		
	# Validate based on action type
	match action.type:
		"attack":
			return _validate_attack_action(action)
		"interact":
			return _validate_interact_action(action)
		"ability":
			return _validate_ability_action(action)
		"item":
			return _validate_item_action(action)
	
	return false

func _validate_attack_action(action: Dictionary) -> bool:
	if !action.has("damage") or !action.has("range"):
		return false
	
	# Validate damage is within acceptable range
	if action.damage < 0 or action.damage > config.max_damage_per_hit:
		return false
	
	# Validate attack range
	if action.range < 0 or action.range > config.max_attack_range:
		return false
	
	return true

func _validate_interact_action(action: Dictionary) -> bool:
	if !action.has("target_id") or !action.has("interaction_type"):
		return false
	
	# Validate interaction type is valid
	var valid_interactions = ["pickup", "use", "talk", "trade"]
	if !valid_interactions.has(action.interaction_type):
		return false
	
	return true

func _validate_ability_action(action: Dictionary) -> bool:
	if !action.has("ability_id") or !action.has("target_position"):
		return false
	
	# Validate ability exists and player has access to it
	if !_validate_ability_access(action.ability_id):
		return false
	
	return true

func _validate_item_action(action: Dictionary) -> bool:
	if !action.has("item_id") or !action.has("use_type"):
		return false
	
	# Validate item exists in player inventory
	if !_validate_item_ownership(action.item_id):
		return false
	
	return true

func _apply_attack_action(player_state: Dictionary, action: Dictionary) -> void:
	# Update player's attack state
	player_state.last_attack_time = Time.get_ticks_msec()
	player_state.is_attacking = true
	player_state.attack_data = {
		"damage": action.damage,
		"range": action.range,
		"direction": action.direction if action.has("direction") else Vector2.ZERO
	}

func _apply_interact_action(player_state: Dictionary, action: Dictionary) -> void:
	# Update player's interaction state
	player_state.is_interacting = true
	player_state.interaction_data = {
		"target_id": action.target_id,
		"type": action.interaction_type,
		"start_time": Time.get_ticks_msec()
	}

func _apply_ability_action(player_state: Dictionary, action: Dictionary) -> void:
	# Update player's ability state
	player_state.current_ability = {
		"id": action.ability_id,
		"target_position": action.target_position,
		"start_time": Time.get_ticks_msec(),
		"duration": _get_ability_duration(action.ability_id)
	}

func _apply_item_action(player_state: Dictionary, action: Dictionary) -> void:
	# Update player's item use state
	player_state.using_item = {
		"id": action.item_id,
		"use_type": action.use_type,
		"start_time": Time.get_ticks_msec()
	}

func _validate_ability_access(ability_id: int) -> bool:
	# This would typically check against a player's unlocked abilities
	# For now, return true as a placeholder
	return true

func _validate_item_ownership(item_id: int) -> bool:
	# This would typically check against a player's inventory
	# For now, return true as a placeholder
	return true

func _get_ability_duration(ability_id: int) -> float:
	# This would typically look up the ability duration from a data table
	# For now, return a default duration
	return 1.0

# Public utility functions
func is_server_running() -> bool:
	return server_state.running

func get_connected_peer_count() -> int:
	return server_state.player_count

func get_max_players() -> int:
	return config.max_clients if config else 0

func get_active_thread_count() -> int:
	return _thread_pool.size()

func get_banned_player_count() -> int:
	return _banned_players.size()

func _validate_state(state: Dictionary) -> bool:
	if !config.enable_anti_cheat:
		return true
	
	for peer_id in state.keys():
		var player = state[peer_id]
		
		# Validate position
		if config.position_validation:
			if !_validate_position(player.position, peer_id):
				return false
		
		# Validate speed
		if config.speed_hack_detection:
			if !_validate_speed(player, peer_id):
				return false
				
		# Validate actions
		if "current_action" in player:
			if !_validate_action(player.current_action):
				return false
	
	return true

func _validate_position(position: Vector2, peer_id: int) -> bool:
	# Check if position is within valid bounds
	var max_pos = config.max_position_delta
	if abs(position.x) > max_pos or abs(position.y) > max_pos:
		_report_violation(peer_id, "position_out_of_bounds")
		return false
	return true

func _validate_speed(player: Dictionary, peer_id: int) -> bool:
	if "last_position" in player and "last_update_time" in player:
		var time_delta = Time.get_ticks_msec() - player.last_update_time
		var distance = player.position.distance_to(player.last_position)
		var speed = distance / (time_delta / 1000.0)
		
		if speed > config.max_player_speed:
			_report_violation(peer_id, "speed_hack")
			return false
	
	player.last_position = player.position
	player.last_update_time = Time.get_ticks_msec()
	return true

func _report_violation(peer_id: int, violation: String) -> void:
	if !_violation_counts.has(peer_id):
		_violation_counts[peer_id] = {}
	
	if !_violation_counts[peer_id].has(violation):
		_violation_counts[peer_id][violation] = 0
	
	_violation_counts[peer_id][violation] += 1
	var count = _violation_counts[peer_id][violation]
	
	emit_signal("player_violation", peer_id, violation, count)
	
	# Check if should ban
	if count >= config.max_violations_before_ban:
		_ban_player(peer_id, "Multiple violations: " + violation) 

func _init_backup_system() -> void:
	if !backup_enabled:
		return
	
	# Create backup directory if it doesn't exist
	var dir = DirAccess.open("user://")
	if !dir.dir_exists(backup_path):
		dir.make_dir(backup_path)

func _init_command_system() -> void:
	# Register default commands
	register_command("help", _cmd_help, "Show available commands")
	register_command("status", _cmd_status, "Show server status")
	register_command("players", _cmd_players, "List connected players")
	register_command("kick", _cmd_kick, "Kick a player by ID")
	register_command("ban", _cmd_ban, "Ban a player by ID")
	register_command("backup", _cmd_backup, "Create a manual backup")
	register_command("restart", _cmd_restart, "Restart the server")

# ADD these new variables to your class (at the top with other variables)
var _bytes_sent_counter: int = 0
var _bytes_received_counter: int = 0
var _ping_timer: Timer

# ADD these new helper methods
func _track_network_usage(data: Variant, is_outgoing: bool = true) -> void:
	var estimated_size = _estimate_data_size(data)
	
	if is_outgoing:
		_bytes_sent_counter += estimated_size
	else:
		_bytes_received_counter += estimated_size

func _estimate_data_size(data: Variant) -> int:
	match typeof(data):
		TYPE_BOOL:
			return 1
		TYPE_INT:
			return 8
		TYPE_FLOAT:
			return 8
		TYPE_STRING:
			return (data as String).length() * 4
		TYPE_VECTOR2:
			return 16
		TYPE_VECTOR3:
			return 24
		TYPE_DICTIONARY:
			var size = 0
			for key in (data as Dictionary):
				size += _estimate_data_size(key)
				size += _estimate_data_size((data as Dictionary)[key])
			return size
		TYPE_ARRAY:
			var size = 0
			for item in (data as Array):
				size += _estimate_data_size(item)
			return size
		_:
			return 64

func _init_network_tracking() -> void:
	_bytes_sent_counter = 0
	_bytes_received_counter = 0
	_init_ping_system()

func _init_ping_system() -> void:
	_ping_timer = Timer.new()
	_ping_timer.wait_time = 2.0
	_ping_timer.timeout.connect(_send_ping_requests)
	_ping_timer.autostart = false
	add_child(_ping_timer)

func _send_ping_requests() -> void:
	if not server_state.running:
		return
		
	var current_time = Time.get_ticks_msec()
	for peer_id in _player_states.keys():
		_track_network_usage(current_time, true)
		rpc_id(peer_id, "ping_request", current_time)

# ADD these new RPC methods for ping
@rpc("any_peer")
func ping_request(timestamp: int) -> void:
	var peer_id = multiplayer.get_remote_sender_id()
	_track_network_usage(timestamp, false)
	rpc_id(peer_id, "ping_response", timestamp)

@rpc("any_peer")
func ping_response(timestamp: int) -> void:
	var peer_id = multiplayer.get_remote_sender_id()
	_track_network_usage(timestamp, false)
	
	var current_time = Time.get_ticks_msec()
	var ping = current_time - timestamp
	
	if _player_states.has(peer_id):
		_player_states[peer_id]["ping"] = ping

# REPLACE your existing _update_server_metrics function with this:
func _update_server_metrics(delta: float) -> void:
	server_metrics.uptime = Time.get_unix_time_from_system() - server_metrics.start_time
	server_metrics.cpu_usage = Performance.get_monitor(Performance.TIME_PROCESS) * 100
	server_metrics.memory_usage = Performance.get_monitor(Performance.MEMORY_STATIC) / 1024 / 1024
	
	# Update our manual network counters
	server_metrics.total_bytes_sent = _bytes_sent_counter
	server_metrics.total_bytes_received = _bytes_received_counter
	
	# Calculate average ping
	var total_ping = 0.0
	var player_count = 0
	
	for peer_id in _player_states.keys():
		if _player_states[peer_id].has("ping"):
			total_ping += _player_states[peer_id]["ping"]
			player_count += 1
	
	if player_count > 0:
		server_metrics.average_ping = total_ping / player_count
	else:
		server_metrics.average_ping = 0.0
	
	# Update peak player count
	if server_state.player_count > server_metrics.peak_players:
		server_metrics.peak_players = server_state.player_count
		
func _create_backup() -> void:
	if !backup_enabled:
		return
	
	var timestamp = Time.get_datetime_string_from_system().replace(":", "-")
	var backup_file = backup_path + "server_backup_" + timestamp + ".json"
	
	# Create backup data
	var backup_data = {
		"timestamp": Time.get_unix_time_from_system(),
		"server_state": server_state,
		"player_states": _player_states,
		"banned_players": _banned_players,
		"metrics": server_metrics
	}
	
	# Save backup
	var file = FileAccess.open(backup_file, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(backup_data))
		last_backup_time = Time.get_unix_time_from_system()
		
		# Clean up old backups
		_cleanup_old_backups()

func _cleanup_old_backups() -> void:
	var dir = DirAccess.open(backup_path)
	if !dir:
		return
	
	var files = []
	dir.list_dir_begin()
	var file = dir.get_next()
	while file != "":
		if !dir.current_is_dir() and file.ends_with(".json"):
			files.append({"name": file, "time": FileAccess.get_modified_time(backup_path + file)})
		file = dir.get_next()
	
	# Sort by time and remove oldest if exceeding max_backups
	files.sort_custom(func(a, b): return a.time > b.time)
	while files.size() > max_backups:
		var old_file = files.pop_back()
		dir.remove(backup_path + old_file.name)

func _auto_restart_server() -> void:
	_log_message("[color=yellow]Auto-restart initiated...[/color]")
	
	# Save current state
	_create_backup()
	
	# Notify players
	for peer_id in _player_states.keys():
		rpc_id(peer_id, "notify_server_restart")
	
	# Wait a few seconds before restarting
	await get_tree().create_timer(5.0).timeout
	
	# Stop and restart
	stop_server()
	await get_tree().create_timer(1.0).timeout
	start_server(config)
	
	last_restart_time = Time.get_unix_time_from_system()

# Command system functions
func register_command(name: String, callback: Callable, description: String) -> void:
	registered_commands[name] = {
		"callback": callback,
		"description": description
	}

func execute_command(command: String) -> String:
	var parts = command.split(" ")
	var cmd_name = parts[0].to_lower()
	var args = parts.slice(1)
	
	if registered_commands.has(cmd_name):
		return registered_commands[cmd_name].callback.call(args)
	
	return "Unknown command: " + cmd_name

# Default commands
func _cmd_help(_args: Array) -> String:
	var help_text = "Available commands:\n"
	for cmd in registered_commands:
		help_text += "  " + cmd + " - " + registered_commands[cmd].description + "\n"
	return help_text

func _cmd_status(_args: Array) -> String:
	return """Server Status:
	Mode: %s
	Uptime: %d seconds
	Players: %d/%d
	CPU Usage: %.1f%%
	Memory: %.1f MB
	Average Ping: %.1f ms""" % [
		["Normal", "Headless", "Dedicated"][server_mode],
		server_metrics.uptime,
		server_state.player_count,
		config.max_clients,
		server_metrics.cpu_usage,
		server_metrics.memory_usage,
		server_metrics.average_ping
	]

func _cmd_players(_args: Array) -> String:
	if _player_states.is_empty():
		return "No players connected"
	
	var player_list = "Connected players:\n"
	for peer_id in _player_states:
		var player = _player_states[peer_id]
		player_list += "  ID: %d, Connected: %d seconds\n" % [
			peer_id,
			Time.get_unix_time_from_system() - player.join_time
		]
	return player_list

func _cmd_kick(args: Array) -> String:
	if args.is_empty():
		return "Usage: kick <player_id>"
	
	var peer_id = args[0].to_int()
	if !_player_states.has(peer_id):
		return "Player not found: " + str(peer_id)
	
	multiplayer.multiplayer_peer.disconnect_peer(peer_id)
	return "Kicked player: " + str(peer_id)

func _cmd_ban(args: Array) -> String:
	if args.size() < 1:
		return "Usage: ban <player_id> [reason]"
	
	var peer_id = args[0].to_int()
	var reason = ""
	
	# Combine remaining arguments into reason
	if args.size() > 1:
		var reason_args = args.slice(1)
		for i in range(reason_args.size()):
			reason += reason_args[i]
			if i < reason_args.size() - 1:
				reason += " "
	else:
		reason = "No reason provided"
	
	_ban_player(peer_id, reason)
	return "Banned player: " + str(peer_id) + " (" + reason + ")"

func _cmd_backup(_args: Array) -> String:
	_create_backup()
	return "Manual backup created"

func _cmd_restart(_args: Array) -> String:
	_auto_restart_server()
	return "Server restart initiated"

@rpc("any_peer")
func notify_server_restart() -> void:
	# Clients would implement their response to this notification
	pass 

# Helper function for logging
func _log_message(message: String) -> void:
	emit_signal("log_message", message) 
# Add this RPC method to notify clients of shutdown
@rpc("authority")
func notify_server_shutdown(countdown: float) -> void:
	# Clients can implement their response to this
	pass

# Add this method for force stopping if graceful shutdown fails
func _force_stop_server() -> void:
	print("Force stopping server...")
	
	# Force disconnect all clients immediately
	if multiplayer.multiplayer_peer:
		var peer_ids = _player_states.keys()
		for peer_id in peer_ids:
			multiplayer.multiplayer_peer.disconnect_peer(peer_id, true)  # Force disconnect
	
	# Stop all timers and threads immediately
	_force_stop_all_systems()
	
	# Clear multiplayer peer
	multiplayer.multiplayer_peer = null
	
	# Reset server state
	server_state.running = false
	server_state.player_count = 0
	
	emit_signal("server_stopped")

func _force_stop_all_systems() -> void:
	# Force stop performance monitoring
	if _performance_monitor:
		_performance_monitor.stop()
	
	# Force stop ping timer
	if _ping_timer:
		_ping_timer.stop()
	
	# Force stop all threads
	for thread in _thread_pool:
		if thread.is_started():
			thread.wait_to_finish()
	_thread_pool.clear()
	
	# Clear all data structures
	_player_states.clear()
	_input_history.clear()
	_game_state_history.clear()



func _disconnect_all_clients_gracefully() -> void:
	if not multiplayer.multiplayer_peer:
		return
	
	var peer_ids = _player_states.keys()
	for peer_id in peer_ids:
		print("Disconnecting player: ", peer_id)
		# Send a final message before disconnecting
		rpc_id(peer_id, "notify_server_shutdown", 0.0)
		# Wait a tiny bit then disconnect
		await get_tree().create_timer(0.1).timeout
		multiplayer.multiplayer_peer.disconnect_peer(peer_id)
	
	# Clear player data
	_player_states.clear()
	_violation_counts.clear()
	_input_history.clear()
