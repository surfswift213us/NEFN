@tool
extends Node

# ✅ Inspector Variables (Auto-Initialize in _ready)
@export var debug_timer: Timer = null
@export var reconnect_timer: Timer = null

# ✅ Nakama Core Components
var session: NakamaSession
var client: NakamaClient
var socket: NakamaSocket
var multiplayerBridge: NakamaMultiplayerBridge

# ✅ Configuration Constants
const DEFAULT_HOST := "127.0.0.1"
const DEFAULT_PORT := 7350
const DEFAULT_TIMEOUT := 3
const DEFAULT_CLIENT_SCHEME := "http"
const DEFAULT_SOCKET_SCHEME := "ws"
const DEFAULT_LOG_LEVEL := NakamaLogger.LOG_LEVEL.DEBUG
const RECONNECT_INTERVAL := 5.0  # Time before attempting reconnection

var _http_adapter = null
var logger = NakamaLogger.new()
var auto_reconnect := true

# ✅ Signals
signal authentication_succeeded(session)
signal authentication_failed(error)
signal connection_status_changed(connected: bool)

### ✅ Ensures Nakama initializes properly ###
func _ready():
	if Engine.is_editor_hint():
		return

	process_mode = Node.PROCESS_MODE_ALWAYS

	# ✅ Ensure Nakama Client is Created
	client = create_client("defaultkey", DEFAULT_HOST, DEFAULT_PORT, DEFAULT_CLIENT_SCHEME)

	# ✅ Ensure Timers Exist (Fix for Null Timers)
	_initialize_timers()

	# ✅ Begin Authentication
	authenticate_device()

### ✅ Initialize Timers (Auto-Fix for Null Values) ###
func _initialize_timers():
	# ✅ Debug Timer (Auto-Starts)
	if debug_timer == null:
		debug_timer = Timer.new()
		debug_timer.name = "DebugTimer"
		debug_timer.wait_time = 30.0  # Adjust as needed
		debug_timer.autostart = true
		debug_timer.timeout.connect(_on_debug_timer_timeout)
		add_child(debug_timer)
		print("✅ Debug Timer initialized!")

	# ✅ Reconnect Timer (Only Starts on Failure)
	if reconnect_timer == null:
		reconnect_timer = Timer.new()
		reconnect_timer.name = "ReconnectTimer"
		reconnect_timer.wait_time = RECONNECT_INTERVAL
		reconnect_timer.autostart = false  # Only starts when reconnecting
		reconnect_timer.timeout.connect(_on_reconnect_timer_timeout)
		add_child(reconnect_timer)
		print("✅ Reconnect Timer initialized!")

### ✅ Debug Timer Logic ###
func _on_debug_timer_timeout():
	var current_time = Time.get_datetime_string_from_system(true)
	var time_parts = current_time.split(" ")

	var date_part = time_parts[0] if time_parts.size() > 0 else "UNKNOWN_DATE"
	var time_part = time_parts[1] if time_parts.size() > 1 else "UNKNOWN_TIME"

	print("[%sT%s] 🔍 Nakama Debug Status:" % [date_part, time_part])

	print("  Client: %s" % ("✅ Initialized" if client else "❌ Not Initialized"))
	print("  Session: %s" % ("✅ Active" if session and !session.is_expired() else "❌ NULL or Expired"))
	print("  Socket: %s" % ("✅ Connected" if socket and socket.is_connected_to_host() else "❌ Disconnected"))
	print("  Multiplayer Bridge: %s" % ("✅ Initialized" if multiplayerBridge else "❌ NULL"))

	if session and !session.is_expired():
		print("  Session User ID:", session.user_id)
		print("  Session Expires At:", Time.get_datetime_string_from_unix_time(session.expire_time))

	print("  Auto-reconnect: %s" % ("Enabled" if auto_reconnect else "Disabled"))
	print("----------------------------------------")

### ✅ Reconnect Timer Logic ###
func _on_reconnect_timer_timeout():
	if !is_connected_and_valid():
		print("Attempting to reconnect...")
		authenticate_device()

func is_connected_and_valid() -> bool:
	return session != null and !session.is_expired() and socket != null and socket.is_connected_to_host()

### ✅ Authentication ###
func authenticate_device() -> void:
	if client == null:
		push_error("❌ Cannot authenticate: Client not initialized!")
		return

	var device_id = OS.get_unique_id()
	if device_id.is_empty():
		device_id = "default_device_id"

	print("🔑 Authenticating with device ID:", device_id)

	var auth_result = await client.authenticate_device_async(device_id)

	if auth_result.is_exception():
		push_error("❌ Authentication failed: %s" % auth_result.get_exception().message)
		authentication_failed.emit(auth_result.get_exception().message)
		_start_reconnect_timer()
		return

	session = auth_result

	if session == null or session.is_expired():
		push_error("❌ Session is NULL or expired after authentication!")
		return

	print("✅ Authentication successful! User ID:", session.user_id)
	print("🔹 Session Token:", session.token)
	print("🔹 Session Expiry:", Time.get_datetime_string_from_unix_time(session.expire_time))

	authentication_succeeded.emit(session)

	# Connect to Nakama socket
	connect_socket()

### ✅ Socket Connection ###
func connect_socket() -> void:
	if session == null or session.is_expired():
		push_error("❌ Cannot connect socket: No valid session!")
		return

	if socket != null:
		socket.close()
		socket = null

	print("🔌 Creating Nakama socket...")
	socket = create_socket_from(client)

	var result = await socket.connect_async(session)

	if result.is_exception():
		push_error("❌ Socket connection failed: %s" % result.get_exception().message)
		_start_reconnect_timer()
		connection_status_changed.emit(false)
		return

	if socket == null or not socket.is_connected_to_host():
		push_error("❌ Socket is NULL or not connected after connection attempt!")
		return

	print("✅ Socket connected successfully!")
	connection_status_changed.emit(true)

	# Initialize multiplayer bridge if missing
	if multiplayerBridge == null:
		print("🔄 Initializing Multiplayer Bridge...")
		multiplayerBridge = NakamaMultiplayerBridge.new(socket)
		print("✅ Multiplayer Bridge Initialized!")

### ✅ Reconnect Handler ###
func _start_reconnect_timer() -> void:
	if auto_reconnect and reconnect_timer:
		reconnect_timer.start()

### ✅ Create Client ###
func create_client(
	p_server_key: String,
	p_host: String = DEFAULT_HOST,
	p_port: int = DEFAULT_PORT,
	p_scheme: String = DEFAULT_CLIENT_SCHEME,
	p_timeout: int = DEFAULT_TIMEOUT,
	p_log_level: int = DEFAULT_LOG_LEVEL
) -> NakamaClient:
	logger._level = p_log_level
	return NakamaClient.new(get_client_adapter(), p_server_key, p_scheme, p_host, p_port, p_timeout)

### ✅ Create WebSocket Adapter ###
func create_socket_adapter() -> NakamaSocketAdapter:
	var adapter = NakamaSocketAdapter.new()
	adapter.name = "NakamaWebSocketAdapter"
	adapter.logger = logger
	add_child(adapter)
	return adapter

### ✅ Create WebSocket ###
func create_socket(p_host: String = DEFAULT_HOST, p_port: int = DEFAULT_PORT, p_scheme: String = DEFAULT_SOCKET_SCHEME) -> NakamaSocket:
	return NakamaSocket.new(create_socket_adapter(), p_host, p_port, p_scheme, true)

### ✅ Create WebSocket from Client ###
func create_socket_from(p_client: NakamaClient) -> NakamaSocket:
	var scheme = "ws"
	if p_client.scheme == "https":
		scheme = "wss"
	return NakamaSocket.new(create_socket_adapter(), p_client.host, p_client.port, scheme, true)

### ✅ Create HTTP Adapter ###
func get_client_adapter() -> NakamaHTTPAdapter:
	if _http_adapter == null:
		_http_adapter = NakamaHTTPAdapter.new()
		_http_adapter.logger = logger
		_http_adapter.name = "NakamaHTTPAdapter"
		add_child(_http_adapter)
	return _http_adapter

### ✅ Cleanup on Exit ###
func _exit_tree():
	if debug_timer:
		debug_timer.stop()
	if reconnect_timer:
		reconnect_timer.stop()
	if socket:
		socket.close()
