extends CharacterBody3D
class_name NEFNPlayer

# Networking components
@onready var network_synchronizer: MultiplayerSynchronizer = $NetworkSynchronizer
@onready var input_synchronizer: InputSynchronizer = $InputSynchronizer
@onready var state_synchronizer: StateSynchronizer = $StateSynchronizer

# Floor detection
@onready var floor_detector_front: RayCast3D = $Floor/FloorDetectorFront
@onready var floor_detector_left: RayCast3D = $Floor/FloorDetectorLeft
@onready var floor_detector_right: RayCast3D = $Floor/FloorDetectorRight

# Movement variables
var SPEED: float = 5.0
var JUMP_VELOCITY: float = 4.5
var SPRINT_SPEED: float = 8.0
var CROUCH_SPEED: float = 3.0
var WALL_RUN_SPEED: float = 7.0
var SLIDE_SPEED: float = 6.0
var MAX_STEP_HEIGHT: float = 0.3
var MIN_STEP_DEPTH: float = 0.1

# Movement states
enum MovementState {
	IDLE,
	WALKING,
	SPRINTING,
	JUMPING,
	WALL_RUNNING,
	SLIDING,
	CROUCHING,
	FALLING
}

# Current state
var current_state: MovementState = MovementState.IDLE
var previous_state: MovementState = MovementState.IDLE

# State machine variables
var can_wall_run: bool = true
var can_slide: bool = true
var is_grounded: bool = false
var wall_normal: Vector3 = Vector3.ZERO
var on_edge: bool = false
var on_step: bool = false

# Get the gravity from the project settings to be synced with RigidBody nodes
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

# Networking properties
@export var is_multiplayer: bool = true
@export var is_local_player: bool = false

# Input buffer for rollback
var input_buffer: Array[Dictionary] = []
const INPUT_BUFFER_SIZE: int = 10

func _ready() -> void:
	if is_multiplayer:
		# Setup network synchronization
		network_synchronizer.set_synchronized_properties([
			"position",
			"rotation",
			"velocity",
			"current_state"
		])
		
		# Setup input synchronization for rollback
		input_synchronizer.set_input_properties([
			"move_direction",
			"jump_pressed",
			"sprint_pressed",
			"crouch_pressed"
		])
		
		# Setup state synchronization
		state_synchronizer.set_state_properties([
			"current_state",
			"is_grounded",
			"wall_normal"
		])

func _physics_process(delta: float) -> void:
	if not is_local_player and is_multiplayer:
		return
		
	# Update floor detection
	_update_floor_detection()
		
	# Add gravity if not on ground
	if not is_grounded:
		velocity.y -= gravity * delta
		
	# Get input
	var input := _get_input()
	
	# Update state
	_update_state(input)
	
	# Apply movement based on state
	_apply_movement(input, delta)
	
	# Handle step climbing
	if is_grounded and input.move_direction != Vector3.ZERO:
		_handle_step_climbing()
	
	# Move and slide
	move_and_slide()
	
	# Update network state
	if is_multiplayer:
		_update_network_state()

func _update_floor_detection() -> void:
	# Update ground state using both built-in floor detection and raycasts
	is_grounded = is_on_floor() or _check_floor_raycasts()
	
	# Check if we're on an edge
	on_edge = _check_edge()
	
	# Check if we're on a step
	on_step = _check_step()

func _check_floor_raycasts() -> bool:
	return floor_detector_front.is_colliding() or \
		   floor_detector_left.is_colliding() or \
		   floor_detector_right.is_colliding()

func _check_edge() -> bool:
	# We're on an edge if we're grounded but one or more floor detectors aren't hitting
	if not is_grounded:
		return false
		
	var front_hit := floor_detector_front.is_colliding()
	var left_hit := floor_detector_left.is_colliding()
	var right_hit := floor_detector_right.is_colliding()
	
	return not (front_hit and left_hit and right_hit)

func _check_step() -> bool:
	if not is_grounded:
		return false
		
	# Check if we're hitting a vertical surface in front of us
	var space_state := get_world_3d().direct_space_state
	var params := PhysicsRayQueryParameters3D.new()
	
	# Cast a ray forward from our feet
	params.from = global_position + Vector3(0, 0.1, 0)
	params.to = params.from + -transform.basis.z * MIN_STEP_DEPTH
	
	var result := space_state.intersect_ray(params)
	if not result:
		return false
		
	# If we hit something, cast another ray from above max step height
	params.from = global_position + Vector3(0, MAX_STEP_HEIGHT + 0.1, 0)
	params.to = params.from + -transform.basis.z * MIN_STEP_DEPTH
	
	result = space_state.intersect_ray(params)
	return not result # If this ray doesn't hit, we've found a step

func _handle_step_climbing() -> void:
	if not on_step:
		return
		
	# Move up by the step height
	global_position.y += MAX_STEP_HEIGHT
	
	# Move forward slightly
	global_position -= transform.basis.z * MIN_STEP_DEPTH

func _get_input() -> Dictionary:
	var input := {
		"move_direction": Vector3.ZERO,
		"jump_pressed": false,
		"sprint_pressed": false,
		"crouch_pressed": false
	}
	
	if not is_local_player:
		return input
		
	# Get movement input
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	input.move_direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	# Get action input
	input.jump_pressed = Input.is_action_just_pressed("jump")
	input.sprint_pressed = Input.is_action_pressed("sprint")
	input.crouch_pressed = Input.is_action_pressed("crouch")
	
	# Buffer input for rollback
	if is_multiplayer:
		input_buffer.push_front(input)
		if input_buffer.size() > INPUT_BUFFER_SIZE:
			input_buffer.pop_back()
	
	return input

func _update_state(input: Dictionary) -> void:
	previous_state = current_state
	
	# Check grounded state
	is_grounded = is_on_floor()
	
	# Update wall running detection
	_update_wall_detection()
	
	# State machine logic
	match current_state:
		MovementState.IDLE:
			if not is_grounded:
				current_state = MovementState.FALLING
			elif input.move_direction != Vector3.ZERO:
				if input.sprint_pressed:
					current_state = MovementState.SPRINTING
				else:
					current_state = MovementState.WALKING
			elif input.crouch_pressed:
				current_state = MovementState.CROUCHING
				
		MovementState.WALKING:
			if not is_grounded:
				current_state = MovementState.FALLING
			elif input.move_direction == Vector3.ZERO:
				current_state = MovementState.IDLE
			elif input.sprint_pressed:
				current_state = MovementState.SPRINTING
			elif input.crouch_pressed:
				if input.move_direction != Vector3.ZERO:
					current_state = MovementState.SLIDING
				else:
					current_state = MovementState.CROUCHING
					
		MovementState.SPRINTING:
			if not is_grounded:
				current_state = MovementState.FALLING
			elif input.move_direction == Vector3.ZERO:
				current_state = MovementState.IDLE
			elif not input.sprint_pressed:
				current_state = MovementState.WALKING
			elif input.crouch_pressed:
				current_state = MovementState.SLIDING
				
		MovementState.JUMPING:
			if is_grounded:
				current_state = MovementState.IDLE
			elif can_wall_run and _check_wall_run_possible():
				current_state = MovementState.WALL_RUNNING
				
		MovementState.FALLING:
			if is_grounded:
				current_state = MovementState.IDLE
			elif can_wall_run and _check_wall_run_possible():
				current_state = MovementState.WALL_RUNNING
				
		MovementState.WALL_RUNNING:
			if is_grounded:
				current_state = MovementState.IDLE
			elif not _check_wall_run_possible():
				current_state = MovementState.FALLING
				
		MovementState.SLIDING:
			if not is_grounded:
				current_state = MovementState.FALLING
			elif input.move_direction == Vector3.ZERO:
				current_state = MovementState.CROUCHING
			elif not input.crouch_pressed:
				current_state = MovementState.WALKING
				
		MovementState.CROUCHING:
			if not is_grounded:
				current_state = MovementState.FALLING
			elif not input.crouch_pressed:
				current_state = MovementState.IDLE
			elif input.move_direction != Vector3.ZERO:
				current_state = MovementState.SLIDING

func _apply_movement(input: Dictionary, delta: float) -> void:
	var speed: float = SPEED
	
	match current_state:
		MovementState.SPRINTING:
			speed = SPRINT_SPEED
		MovementState.CROUCHING:
			speed = CROUCH_SPEED
		MovementState.WALL_RUNNING:
			speed = WALL_RUN_SPEED
			_apply_wall_run(delta)
		MovementState.SLIDING:
			speed = SLIDE_SPEED
			_apply_slide(delta)
	
	if input.move_direction:
		velocity.x = input.move_direction.x * speed
		velocity.z = input.move_direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)
	
	if input.jump_pressed and is_grounded:
		velocity.y = JUMP_VELOCITY
		current_state = MovementState.JUMPING

func _update_wall_detection() -> void:
	var space_state := get_world_3d().direct_space_state
	var params := PhysicsRayQueryParameters3D.new()
	
	# Cast rays to detect walls
	for angle in [0, 45, -45, 90, -90]:
		var direction := Vector3.FORWARD.rotated(Vector3.UP, deg_to_rad(angle))
		params.from = global_position
		params.to = global_position + direction * 1.0
		
		var result := space_state.intersect_ray(params)
		if result:
			wall_normal = result.normal
			return
			
	wall_normal = Vector3.ZERO

func _check_wall_run_possible() -> bool:
	return wall_normal != Vector3.ZERO and wall_normal.y < 0.1

func _apply_wall_run(delta: float) -> void:
	if wall_normal != Vector3.ZERO:
		# Apply upward force to maintain wall run
		velocity.y = 0
		
		# Calculate wall run direction
		var wall_run_direction := wall_normal.cross(Vector3.UP)
		if velocity.dot(wall_run_direction) < 0:
			wall_run_direction = -wall_run_direction
			
		velocity = wall_run_direction * WALL_RUN_SPEED

func _apply_slide(delta: float) -> void:
	# Apply slide momentum
	var slide_direction := -transform.basis.z
	velocity = slide_direction * SLIDE_SPEED
	
	# Apply slide friction
	velocity *= 0.98

func _update_network_state() -> void:
	if not is_multiplayer:
		return
		
	# Update network synchronizer
	network_synchronizer.update_state({
		"position": global_position,
		"rotation": global_rotation,
		"velocity": velocity,
		"current_state": current_state
	})
	
	# Update state synchronizer
	state_synchronizer.update_state({
		"current_state": current_state,
		"is_grounded": is_grounded,
		"wall_normal": wall_normal
	})

# Network callbacks
func _on_network_state_updated(new_state: Dictionary) -> void:
	if is_local_player:
		return
		
	global_position = new_state.position
	global_rotation = new_state.rotation
	velocity = new_state.velocity
	current_state = new_state.current_state

func _on_state_synchronized(new_state: Dictionary) -> void:
	if is_local_player:
		return
		
	current_state = new_state.current_state
	is_grounded = new_state.is_grounded
	wall_normal = new_state.wall_normal

# Input handling for rollback
func _handle_rollback(from_tick: int) -> void:
	if not is_multiplayer or not is_local_player:
		return
		
	# Replay inputs from the rollback point
	var current_tick := from_tick
	for buffered_input in input_buffer:
		if current_tick >= from_tick:
			_apply_movement(buffered_input, 1.0/60.0) # Assuming 60 FPS
		current_tick += 1 
