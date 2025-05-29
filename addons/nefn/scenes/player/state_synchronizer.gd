extends Node
class_name NetFoxStateSynchronizer

signal state_updated(state: Dictionary)

var state_properties: Array = []
var current_state: Dictionary = {}
var state_buffer: Array = []
const STATE_BUFFER_SIZE = 10
var network_manager = null

func _ready() -> void:
	# Try to get NetFox network manager
	if Engine.has_singleton("NetFox"):
		network_manager = Engine.get_singleton("NetFox")
	else:
		push_warning("NetFox singleton not found. Network features will be disabled.")

func set_state_properties(properties: Array) -> void:
	state_properties = properties
	
func update_state(state: Dictionary) -> void:
	current_state = state.duplicate()
	
	# Add timestamp
	state["timestamp"] = Time.get_ticks_msec()
	
	# Buffer state for rollback
	state_buffer.push_front(state)
	if state_buffer.size() > STATE_BUFFER_SIZE:
		state_buffer.pop_back()
		
	# Send state to server using NetFox if available
	if network_manager and network_manager.is_client():
		network_manager.send_state.rpc_id(1, state)
	else:
		# Fallback to local state handling
		receive_state(state)
		
@rpc("any_peer", "unreliable")
func receive_state(state: Dictionary) -> void:
	# Validate state data
	for property in state_properties:
		if not state.has(property):
			push_error("Invalid state data received: missing property " + property)
			return
			
	emit_signal("state_updated", state)
	
func get_current_state() -> Dictionary:
	return current_state
	
func get_state_at_time(timestamp: int) -> Dictionary:
	for state in state_buffer:
		if state["timestamp"] <= timestamp:
			return state
	return {}
	
func clear_state_buffer() -> void:
	current_state.clear()
	state_buffer.clear() 
