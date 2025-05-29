extends Node

signal connection_established
signal connection_failed(error: String)
signal player_joined(player_id: int)
signal player_left(player_id: int)
signal voice_state_changed(enabled: bool)

const NetworkTime = preload("res://addons/netfox/network-time.gd")
const Noray = preload("res://addons/netfox.noray/noray.gd")
const CONFIG_PATH = "res://addons/nefn/config.tres"

# Components
var nakama_client: NEFNNakamaClient
var nakama_session: NakamaSession
var enet_peer: ENetMultiplayerPeer
var network_time: NetworkTime
var noray: Noray

var _config: NEFNConfiguration

var config: NEFNConfiguration:
	get:
		if not _config:
			if ResourceLoader.exists(CONFIG_PATH):
				_config = load(CONFIG_PATH)
			if not _config:
				push_warning("NEFN: Configuration file not found, using defaults.")
				_config = NEFNConfiguration.new()
		return _config

func _ready() -> void:
	# Wait a frame to ensure config is imported
	await get_tree().process_frame
	
	_setup_nakama()
	_setup_networking()
	await _setup_voice()

func _setup_nakama() -> void:
	nakama_client = NEFNNakamaClient.new()
	nakama_client.initialize(
		config.nakama_server_key,
		config.nakama_host,
		config.nakama_port,
		"http" if not config.nakama_use_ssl else "https"
	)

func _setup_networking() -> void:
	enet_peer = ENetMultiplayerPeer.new()
	network_time = NetworkTime.new()
	
	# Configure ENet
	if multiplayer.is_server():
		var error = enet_peer.create_server(config.enet_port, config.enet_max_clients)
		if error != OK:
			push_error("NEFN: Failed to create server: %s" % error)
			return
	
	multiplayer.multiplayer_peer = enet_peer
	add_child(network_time)

func _setup_voice() -> void:
	if not config.noray_enabled:
		return
		
	noray = Noray.new()
	add_child(noray)
	
	# Connect to Noray server
	var err = await noray.connect_to_host("127.0.0.1", config.noray_port)
	if err != OK:
		push_error("NEFN: Failed to connect to Noray server: %s" % err)
		return
	
	# Register as host for voice chat
	err = await noray.register_host()
	if err != OK:
		push_error("NEFN: Failed to register as Noray host: %s" % err)
		return
	
	# Register remote address for NAT traversal
	err = await noray.register_remote()
	if err != OK:
		push_error("NEFN: Failed to register remote address: %s" % err)
		return

# Authentication methods
func authenticate_email(email: String, password: String) -> void:
	if not nakama_client:
		push_error("NEFN: Nakama client not initialized!")
		return
		
	var result = await nakama_client.authenticate_email_async(email, password)
	if result.is_exception():
		emit_signal("connection_failed", result.get_exception().message)
		return
		
	nakama_session = result
	emit_signal("connection_established")

func authenticate_device(device_id: String) -> void:
	if not nakama_client:
		push_error("NEFN: Nakama client not initialized!")
		return
		
	var result = await nakama_client.authenticate_device_async(device_id)
	if result.is_exception():
		emit_signal("connection_failed", result.get_exception().message)
		return
		
	nakama_session = result
	emit_signal("connection_established")

# Networking methods
func host_game(port: int = -1) -> void:
	if port > 0:
		config.enet_port = port
	_setup_networking()

func join_game(address: String, port: int = -1) -> void:
	if port > 0:
		config.enet_port = port
	
	enet_peer = ENetMultiplayerPeer.new()
	var error = enet_peer.create_client(address, config.enet_port)
	if error != OK:
		emit_signal("connection_failed", "Failed to create client: %s" % error)
		return
	
	multiplayer.multiplayer_peer = enet_peer

# Voice methods
func start_voice() -> void:
	if not noray or not config.noray_enabled:
		return
	
	if not noray.is_connected_to_host():
		var err = await noray.connect_to_host("127.0.0.1", config.noray_port)
		if err != OK:
			push_error("NEFN: Failed to connect to Noray server: %s" % err)
			return
			
		# Re-register as host since we reconnected
		err = await noray.register_host()
		if err != OK:
			push_error("NEFN: Failed to register as Noray host: %s" % err)
			return
			
		err = await noray.register_remote()
		if err != OK:
			push_error("NEFN: Failed to register remote address: %s" % err)
			return
	
	emit_signal("voice_state_changed", true)

func stop_voice() -> void:
	if not noray or not config.noray_enabled:
		return
	
	if noray.is_connected_to_host():
		noray.disconnect_from_host()
	
	emit_signal("voice_state_changed", false)

# Cleanup
func _exit_tree() -> void:
	if nakama_session:
		# Close Nakama session
		await nakama_client.session_logout_async(nakama_session)
	
	if enet_peer:
		enet_peer.close()
	
	if noray:
		noray.disconnect_from_host() 
 
