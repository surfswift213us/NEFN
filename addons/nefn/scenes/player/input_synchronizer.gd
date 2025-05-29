extends Node
class_name InputSynchronizer

signal input_received(input_data: Dictionary)

var input_properties: Array = []
var last_input: Dictionary = {}
var input_sequence: int = 0
var network_manager = null

func _ready() -> void:
	# Try to get NetFox network manager
	if Engine.has_singleton("NetFox"):
		network_manager = Engine.get_singleton("NetFox")
	else:
		push_warning("NetFox singleton not found. Network features will be disabled.")

func set_input_properties(properties: Array) -> void:
	input_properties = properties
	
func send_input(input_data: Dictionary) -> void:
	input_sequence += 1
	last_input = input_data
	
	# Add sequence number to input data
	input_data["sequence"] = input_sequence
	
	# Send input to server using NetFox if available
	if network_manager and network_manager.is_client():
		network_manager.send_input.rpc_id(1, input_data)
	else:
		# Fallback to local input handling
		receive_input(input_data)
		
@rpc("any_peer", "unreliable")
func receive_input(input_data: Dictionary) -> void:
	# Validate input data
	for property in input_properties:
		if not input_data.has(property):
			push_error("Invalid input data received: missing property " + property)
			return
			
	emit_signal("input_received", input_data)
	
func get_last_input() -> Dictionary:
	return last_input
	
func clear_input_buffer() -> void:
	last_input.clear()
	input_sequence = 0 
