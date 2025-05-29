extends Control

@onready var host_button: Button = $VBoxContainer/HostButton
@onready var join_button: Button = $VBoxContainer/JoinButton
@onready var address_input: LineEdit = $VBoxContainer/Address
@onready var voice_toggle: CheckButton = $VBoxContainer/VoiceToggle
@onready var debug_toggle: CheckButton = $VBoxContainer/DebugToggle
@onready var status_label: Label = $VBoxContainer/Status
@onready var debug_console: Control = $DebugConsole

var nefn = null

func _ready() -> void:
	# Wait for autoload to be ready
	await get_tree().root.ready
	nefn = get_node("/root/NEFNManager")
	
	# Connect signals
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	voice_toggle.toggled.connect(_on_voice_toggled)
	debug_toggle.toggled.connect(_on_debug_toggled)
	
	# Connect NEFN signals
	nefn.connection_established.connect(_on_connection_established)
	nefn.connection_failed.connect(_on_connection_failed)
	nefn.player_joined.connect(_on_player_joined)
	nefn.player_left.connect(_on_player_left)
	nefn.voice_state_changed.connect(_on_voice_state_changed)
	
	# Try to authenticate with device ID
	var device_id = OS.get_unique_id()
	nefn.authenticate_device(device_id)
	_update_status("Authenticating...")

func _on_host_pressed() -> void:
	if not nefn.nakama_session:
		_update_status("Error: Not authenticated!")
		return
	
	nefn.host_game()
	_update_status("Hosting game...")

func _on_join_pressed() -> void:
	if not nefn.nakama_session:
		_update_status("Error: Not authenticated!")
		return
	
	var address = address_input.text
	if address.is_empty():
		_update_status("Error: Please enter server address!")
		return
	
	nefn.join_game(address)
	_update_status("Joining game...")

func _on_voice_toggled(enabled: bool) -> void:
	if enabled:
		nefn.start_voice()
	else:
		nefn.stop_voice()

func _on_debug_toggled(enabled: bool) -> void:
	debug_console.visible = enabled

func _on_connection_established() -> void:
	_update_status("Connected!")

func _on_connection_failed(error: String) -> void:
	_update_status("Connection failed: " + error)

func _on_player_joined(player_id: int) -> void:
	_update_status("Player %d joined" % player_id)

func _on_player_left(player_id: int) -> void:
	_update_status("Player %d left" % player_id)

func _on_voice_state_changed(enabled: bool) -> void:
	voice_toggle.button_pressed = enabled
	_update_status("Voice chat: %s" % ("Enabled" if enabled else "Disabled"))

func _update_status(text: String) -> void:
	status_label.text = "Status: " + text
	print("NEFN: " + text) 
