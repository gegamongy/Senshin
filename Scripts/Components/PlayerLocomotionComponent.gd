extends Node
class_name PlayerLocomotionComponent

## Handles all player locomotion physics including movement, jumping, gravity, and turning

@export_range(0.0, 1.0) var air_control: float = 1.0
@export var gravity_multiplier: float = 2.5
@export var jump_cut_multiplier: float = 0.5
@export var terminal_velocity: float = -50.0
@export var jump_velocity: float = 20.0

const AIR_SPEED = 15.0
const INPUT_ACCEL_SPEED = 10.0
const ROTATION_SPEED = 8.0
const SMOOTHED_SPEED_DECAY = 8.0
const RUN_180_THRESHOLD = 8.0
const WALK_180_THRESHOLD = 1.0

var gravity: float
var character_body: CharacterBody3D
var camera_yaw: float = 0.0  # Passed from camera controller

# State tracking
var is_grounded: bool = true
var was_grounded: bool = true
var is_turning_180: bool = false
var jump_direction: float = 1.0  # 1.0 forward, -1.0 backward
var pending_backflip_root_motion_disable: bool = false

# Movement
var input_magnitude: float = 0.0
var smoothed_speed: float = 0.0
var move_dir: Vector3 = Vector3.ZERO
var landing_velocity: Vector3 = Vector3.ZERO
var landing_frames: int = 0


func _ready():
	gravity = ProjectSettings.get_setting("physics/3d/default_gravity")


func initialize(body: CharacterBody3D):
	"""Initialize with reference to the CharacterBody3D"""
	character_body = body


func process_locomotion(input_dir: Vector2, crouch_input: bool, delta: float) -> void:
	"""Main locomotion processing - called every physics frame"""
	# Update grounded state
	is_grounded = character_body.is_on_floor()
	
	# Track landing
	if not was_grounded and character_body.is_on_floor():
		landing_velocity = Vector3(character_body.velocity.x, 0, character_body.velocity.z)
		landing_frames = 3
	was_grounded = character_body.is_on_floor()
	
	# Apply gravity
	apply_gravity(delta)
	
	# Calculate movement direction
	move_dir = calculate_movement_direction(input_dir)
	var has_movement_input = move_dir.length() > 0.01
	
	# Update smoothed speed for animation selection
	update_smoothed_speed(delta)
	
	# Check for 180 turns
	if has_movement_input:
		move_dir = move_dir.normalized()
		check_turn_angles(move_dir)
	
	# Update input magnitude
	update_input_magnitude(input_dir, crouch_input, delta)
	
	# Handle movement
	if character_body.is_on_floor():
		handle_grounded_movement(has_movement_input, move_dir, delta)
	else:
		handle_air_movement(has_movement_input, move_dir, delta)


func apply_gravity(delta: float) -> void:
	if not character_body.is_on_floor():
		character_body.velocity.y -= gravity * gravity_multiplier * delta
		character_body.velocity.y = max(character_body.velocity.y, terminal_velocity)


func calculate_movement_direction(input_dir: Vector2) -> Vector3:
	"""Calculate world-space movement direction from input and camera"""
	var camera_basis = Basis()
	camera_basis = camera_basis.rotated(Vector3.UP, camera_yaw + PI)
	var camera_forward = -camera_basis.z
	var camera_right = camera_basis.x
	
	camera_forward.y = 0
	camera_right.y = 0
	camera_forward = camera_forward.normalized()
	camera_right = camera_right.normalized()
	
	return camera_right * input_dir.x + camera_forward * -input_dir.y


func update_smoothed_speed(delta: float) -> void:
	var current_horizontal_speed = Vector2(character_body.velocity.x, character_body.velocity.z).length()
	if current_horizontal_speed > smoothed_speed:
		smoothed_speed = current_horizontal_speed
	else:
		smoothed_speed = lerp(smoothed_speed, current_horizontal_speed, SMOOTHED_SPEED_DECAY * delta)


func check_turn_angles(move_dir: Vector3) -> void:
	"""Check if player should perform a 180 turn animation"""
	if not character_body.is_on_floor() or is_turning_180:
		return
	
	var player_forward = character_body.global_transform.basis.z
	player_forward.y = 0
	player_forward = player_forward.normalized()
	
	var turn_angle = signed_angle_between(player_forward, move_dir)
	
	# Return turn info if we should turn
	# This will be handled by animation controller
	pass


func update_input_magnitude(input_dir: Vector2, crouch_input: bool, delta: float) -> void:
	var target_magnitude = input_dir.length()
	if crouch_input:
		target_magnitude *= 0.5
	
	input_magnitude = lerp(input_magnitude, target_magnitude, INPUT_ACCEL_SPEED * delta)


func handle_grounded_movement(has_movement: bool, move_dir: Vector3, delta: float) -> void:
	"""Handle movement when on the ground - root motion is applied by animation controller"""
	if has_movement and not is_turning_180:
		lerp_body_rotation(move_dir, delta)


func handle_air_movement(has_movement: bool, move_dir: Vector3, delta: float) -> void:
	"""Handle movement when airborne"""
	if has_movement:
		lerp_body_rotation(move_dir, delta)
		
		var target_velocity = move_dir * AIR_SPEED
		character_body.velocity.x = lerp(character_body.velocity.x, target_velocity.x, air_control)
		character_body.velocity.z = lerp(character_body.velocity.z, target_velocity.z, air_control)
	else:
		if air_control > 0:
			character_body.velocity.x = lerp(character_body.velocity.x, 0.0, air_control * 0.1)
			character_body.velocity.z = lerp(character_body.velocity.z, 0.0, air_control * 0.1)


func apply_jump(input_dir: Vector2) -> void:
	"""Apply jump velocity and determine jump direction"""
	if should_backflip(input_dir):
		jump_direction = -1.0
		pending_backflip_root_motion_disable = true
	else:
		jump_direction = 1.0
	
	character_body.velocity.y = jump_velocity


func cut_jump() -> void:
	"""Reduce upward velocity for responsive jump control"""
	if character_body.velocity.y > 0:
		character_body.velocity.y *= jump_cut_multiplier


func should_backflip(input_dir: Vector2) -> bool:
	"""Check if player is moving backward relative to facing direction"""
	if input_dir.length() <= 0.01:
		return false
	
	var world_move_dir = calculate_movement_direction(input_dir).normalized()
	var player_forward = character_body.global_transform.basis.z
	player_forward.y = 0
	player_forward = player_forward.normalized()
	
	var angle = signed_angle_between(player_forward, world_move_dir)
	return abs(angle) > PI / 2


func lerp_body_rotation(target_direction: Vector3, delta: float) -> void:
	"""Smoothly rotate character body toward movement direction"""
	var target_rotation = atan2(target_direction.x, target_direction.z)
	var new_rotation = lerp_angle(character_body.rotation.y, target_rotation, ROTATION_SPEED * delta)
	character_body.rotation.y = new_rotation


func apply_root_motion_rotation(rot_y: float) -> void:
	"""Apply rotation from root motion (for 180 turns)"""
	character_body.rotation.y += rot_y


func signed_angle_between(forward: Vector3, move_dir: Vector3) -> float:
	"""Calculate signed angle between two vectors"""
	var dot = forward.dot(move_dir)
	var cross_y = forward.cross(move_dir).y
	return atan2(cross_y, dot)


# Getters for state
func get_is_grounded() -> bool:
	return is_grounded


func get_smoothed_speed() -> float:
	return smoothed_speed


func get_input_magnitude() -> float:
	return input_magnitude


func get_jump_direction() -> float:
	return jump_direction


func get_is_turning_180() -> bool:
	return is_turning_180


func set_is_turning_180(value: bool) -> void:
	is_turning_180 = value


func get_pending_backflip_root_motion_disable() -> bool:
	return pending_backflip_root_motion_disable


func set_pending_backflip_root_motion_disable(value: bool) -> void:
	pending_backflip_root_motion_disable = value


func get_move_dir() -> Vector3:
	return move_dir


func set_camera_yaw(yaw: float) -> void:
	camera_yaw = yaw
