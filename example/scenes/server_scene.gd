extends Control

@onready var server_manager: NEFNServerManager = $ServerManager
@onready var status_label: Label = $UI/Header/MarginContainer/VBoxContainer/Status
@onready var start_button: Button = $UI/Controls/MarginContainer/VBoxContainer/Buttons/StartButton
@onready var stop_button: Button = $UI/Controls/MarginContainer/VBoxContainer/Buttons/StopButton
@onready var log_text: RichTextLabel = $UI/Log/MarginContainer/VBoxContainer/LogText

# UI References
@onready var ip_input: LineEdit = $UI/Controls/MarginContainer/VBoxContainer/GridContainer/IPInput
@onready var port_input: SpinBox = $UI/Controls/MarginContainer/VBoxContainer/GridContainer/PortInput
@onready var max_clients_input: SpinBox = $UI/Controls/MarginContainer/VBoxContainer/GridContainer/MaxClientsInput
@onready var tick_rate_input: SpinBox = $UI/Controls/MarginContainer/VBoxContainer/GridContainer/TickRateInput

@onready var multithreading_toggle: CheckButton = $UI/Controls/MarginContainer/VBoxContainer/Features/MultithreadingToggle
@onready var packet_batching_toggle: CheckButton = $UI/Controls/MarginContainer/VBoxContainer/Features/PacketBatchingToggle
@onready var rollback_toggle: CheckButton = $UI/Controls/MarginContainer/VBoxContainer/Features/RollbackToggle
@onready var anti_cheat_toggle: CheckButton = $UI/Controls/MarginContainer/VBoxContainer/Features/AntiCheatToggle

# Stats Labels
@onready var uptime_label: Label = $UI/Stats/MarginContainer/VBoxContainer/StatsContainer/UptimeLabel
@onready var players_label: Label = $UI/Stats/MarginContainer/VBoxContainer/StatsContainer/PlayersLabel
@onready var memory_label: Label = $UI/Stats/MarginContainer/VBoxContainer/StatsContainer/MemoryLabel
@onready var threads_label: Label = $UI/Stats/MarginContainer/VBoxContainer/StatsContainer/ThreadsLabel
@onready var banned_label: Label = $UI/Stats/MarginContainer/VBoxContainer/StatsContainer/BannedLabel

var start_time: int = 0
var stats_timer: Timer

var is_shutting_down: bool = false
var shutdown_timer: Timer

func _ready() -> void:
	# Connect signals
	start_button.pressed.connect(_on_start_button_pressed)
	stop_button.pressed.connect(_on_stop_button_pressed)
	
	# Setup stats timer
	stats_timer = Timer.new()
	stats_timer.wait_time = 1.0
	stats_timer.timeout.connect(_update_stats)
	add_child(stats_timer)
	
	# Setup shutdown timer
	shutdown_timer = Timer.new()
	shutdown_timer.wait_time = 0.1  # Check every 100ms
	shutdown_timer.timeout.connect(_check_shutdown_complete)
	add_child(shutdown_timer)
	
	# Connect server signals
	server_manager.server_started.connect(_on_server_started)
	server_manager.server_stopped.connect(_on_server_stopped)
	server_manager.player_connected.connect(_on_player_connected)
	server_manager.player_disconnected.connect(_on_player_disconnected)
	server_manager.player_violation.connect(_on_player_violation)
	server_manager.log_message.connect(_on_log_message)

func _on_start_button_pressed() -> void:
	var config = NEFNServerConfig.new()
	
	# Network settings
	config.server_ip = ip_input.text
	config.port = int(port_input.value)
	config.max_clients = int(max_clients_input.value)
	config.tick_rate = int(tick_rate_input.value)
	
	# Feature toggles
	config.enable_multithreading = multithreading_toggle.button_pressed
	config.enable_packet_batching = packet_batching_toggle.button_pressed
	config.enable_rollback = rollback_toggle.button_pressed
	config.enable_anti_cheat = anti_cheat_toggle.button_pressed
	
	# Start server
	var error = server_manager.start_server(config)
	if error == OK:
		_disable_controls()
		start_time = Time.get_unix_time_from_system()
		stats_timer.start()
		log_message("[color=green]Server starting...[/color]")
	else:
		log_message("[color=red]Failed to start server! Error: " + str(error) + "[/color]")

# Replace your existing _on_stop_button_pressed function with this:
func _on_stop_button_pressed() -> void:
	if is_shutting_down:
		return
	
	is_shutting_down = true
	stop_button.disabled = true
	stop_button.text = "Stopping..."
	
	log_message("[color=yellow]Initiating graceful server shutdown...[/color]")
	
	# Start the graceful shutdown process
	_start_graceful_shutdown()

func _start_graceful_shutdown() -> void:
	# Step 1: Notify all connected players
	log_message("[color=yellow]Notifying players of server shutdown...[/color]")
	_notify_players_of_shutdown()
	
	# Step 2: Wait a bit for players to receive the message
	await get_tree().create_timer(2.0).timeout
	
	# Step 3: Save any important data
	log_message("[color=yellow]Saving server data...[/color]")
	_save_server_data()
	
	# Step 4: Start monitoring for complete shutdown
	shutdown_timer.start()
	
	# Step 5: Begin actual server shutdown
	server_manager.stop_server()

func _notify_players_of_shutdown() -> void:
	# Send shutdown notification to all connected players
	if server_manager.multiplayer and server_manager.multiplayer.multiplayer_peer:
		for peer_id in server_manager._player_states.keys():
			server_manager.rpc_id(peer_id, "notify_server_shutdown", 5.0)  # 5 second warning

func _save_server_data() -> void:
	# Force create a backup if backup system is enabled
	if server_manager.backup_enabled:
		server_manager._create_backup()
	
	# Save any other critical data here
	log_message("[color=green]Server data saved successfully.[/color]")

func _check_shutdown_complete() -> void:
	# Check if server has actually stopped
	if not server_manager.is_server_running():
		shutdown_timer.stop()
		_on_shutdown_complete()
	else:
		# If taking too long, force shutdown after 10 seconds
		if shutdown_timer.wait_time > 10.0:
			log_message("[color=red]Force stopping server after timeout...[/color]")
			server_manager._force_stop_server()
			shutdown_timer.stop()
			_on_shutdown_complete()

func _on_shutdown_complete() -> void:
	is_shutting_down = false
	stop_button.text = "Stop Server"
	stats_timer.stop()
	log_message("[color=green]Server shutdown completed successfully.[/color]")

func _on_server_stopped() -> void:
	status_label.text = "Status: Stopped"
	_enable_controls()
	if not is_shutting_down:  # Only log if not part of graceful shutdown
		log_message("[color=yellow]Server stopped.[/color]")

# Update your _enable_controls function to handle shutdown state
func _enable_controls() -> void:
	if is_shutting_down:
		return  # Don't enable controls while shutting down
		
	ip_input.editable = true
	port_input.editable = true
	max_clients_input.editable = true
	tick_rate_input.editable = true
	multithreading_toggle.disabled = false
	packet_batching_toggle.disabled = false
	rollback_toggle.disabled = false
	anti_cheat_toggle.disabled = false
	start_button.disabled = false
	stop_button.disabled = true
	
func _on_server_started() -> void:
	status_label.text = "Status: Running"
	log_message("[color=green]Server started successfully![/color]")


func _on_player_connected(peer_id: int) -> void:
	log_message("[color=green]Player " + str(peer_id) + " connected.[/color]")
	_update_player_count()

func _on_player_disconnected(peer_id: int) -> void:
	log_message("[color=yellow]Player " + str(peer_id) + " disconnected.[/color]")
	_update_player_count()

func _on_player_violation(peer_id: int, violation: String, count: int) -> void:
	log_message("[color=red]Player " + str(peer_id) + " violation: " + violation + " (Count: " + str(count) + ")[/color]")

func _on_log_message(message: String) -> void:
	log_message(message)

func log_message(message: String) -> void:
	var timestamp = Time.get_datetime_string_from_system()
	log_text.append_text("\n[" + timestamp + "] " + message)

func _update_stats() -> void:
	if server_manager.is_server_running():
		var uptime = Time.get_unix_time_from_system() - start_time
		uptime_label.text = "Uptime: " + str(int(uptime)) + "s"
		
		var memory = Performance.get_monitor(Performance.MEMORY_STATIC)
		memory_label.text = "Memory: " + str(snappedf(memory / 1024.0 / 1024.0, 0.1)) + " MB"
		
		threads_label.text = "Active Threads: " + str(server_manager.get_active_thread_count())
		banned_label.text = "Banned Players: " + str(server_manager.get_banned_player_count())

func _update_player_count() -> void:
	var current = server_manager.get_connected_peer_count()
	var max_players = server_manager.get_max_players()
	players_label.text = "Players: " + str(current) + "/" + str(max_players)

func _disable_controls() -> void:
	ip_input.editable = false
	port_input.editable = false
	max_clients_input.editable = false
	tick_rate_input.editable = false
	multithreading_toggle.disabled = true
	packet_batching_toggle.disabled = true
	rollback_toggle.disabled = true
	anti_cheat_toggle.disabled = true
	start_button.disabled = true
	stop_button.disabled = false
