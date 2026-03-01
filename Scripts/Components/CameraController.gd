extends Node
class_name CameraController

## Handles all camera positioning, rotation, and look controls

@export var camera_distance: float = 25.0
@export var camera_height: float = 5.0
@export var camera_fov: float = 75.0

const MIN_Y_ROTATION = -80
const MAX_Y_ROTATION = 80

var camera_pivot: Node3D
var camera: Camera3D
var player_body: CharacterBody3D
var input_component: PlayerInputComponent

var camera_yaw: float = 0.0
var camera_pitch: float = 0.0

# Lock-on state
var lock_on_target: Node3D = null
var is_locked_on: bool = false
@export var lock_on_smoothness: float = 15.0


func _ready():
	pass


func initialize(pivot: Node3D, cam: Camera3D, body: CharacterBody3D, input: PlayerInputComponent):
	"""Initialize camera controller with required references"""
	camera_pivot = pivot
	camera = cam
	player_body = body
	input_component = input
	
	# Make camera pivot top-level so it doesn't rotate with character
	camera_pivot.set_as_top_level(true)


func process_camera(delta: float) -> void:
	"""Main camera processing - handles look input and positioning"""
	# Block camera control when inventory is open
	if InventoryManager.is_open:
		return
	
	if is_locked_on and lock_on_target:
		# Lock-on mode: camera tracks target
		process_lock_on_camera(delta)
	else:
		# Free camera mode: player controls rotation
		# Handle mouse look
		var mouse_delta = input_component.get_mouse_delta()
		if mouse_delta.length() > 0.001:
			camera_yaw -= mouse_delta.x
			camera_pitch += mouse_delta.y
			apply_camera_rotation()
		
		# Handle gamepad look
		var gamepad_look = input_component.get_gamepad_look()
		if gamepad_look.length() > 0.01:
			camera_yaw -= gamepad_look.x * input_component.gamepad_look_sensitivity * delta
			camera_pitch += gamepad_look.y * input_component.gamepad_look_sensitivity * delta
			apply_camera_rotation()
	
	# Update camera position to follow player
	update_camera_position()


func apply_camera_rotation() -> void:
	"""Apply rotation constraints and update camera pivot"""
	# Clamp pitch to prevent camera flipping
	camera_pitch = clamp(camera_pitch, deg_to_rad(MIN_Y_ROTATION), deg_to_rad(MAX_Y_ROTATION))
	
	# Apply rotations to camera pivot
	camera_pivot.rotation.y = camera_yaw
	camera_pivot.rotation.x = camera_pitch


func update_camera_position() -> void:
	"""Update camera pivot to follow player position"""
	camera_pivot.global_position = player_body.global_position


func get_camera_yaw() -> float:
	"""Get current camera yaw for movement calculations"""
	return camera_yaw


func get_camera_pitch() -> float:
	"""Get current camera pitch"""
	return camera_pitch


func process_lock_on_camera(delta: float) -> void:
	"""Process camera when locked onto a target"""
	if not lock_on_target:
		return
	
	# Calculate direction from player to target
	var to_target = lock_on_target.global_position - player_body.global_position
	var distance = to_target.length()
	
	if distance < 0.1:
		return
	
	# Calculate target yaw and pitch to look at enemy
	var target_yaw = atan2(to_target.x, to_target.z)
	var horizontal_distance = Vector2(to_target.x, to_target.z).length()
	var target_pitch = -atan2(to_target.y, horizontal_distance)
	
	# Smoothly interpolate camera to face target
	camera_yaw = lerp_angle(camera_yaw, target_yaw, lock_on_smoothness * delta)
	camera_pitch = lerp_angle(camera_pitch, target_pitch, lock_on_smoothness * delta)
	
	apply_camera_rotation()


func set_lock_on_target(target: Node3D) -> void:
	"""Enable lock-on mode with the specified target"""
	lock_on_target = target
	is_locked_on = target != null
	print("[CameraController] Lock-on ", "enabled" if is_locked_on else "disabled")


func clear_lock_on() -> void:
	"""Disable lock-on mode"""
	lock_on_target = null
	is_locked_on = false
	print("[CameraController] Lock-on cleared")
