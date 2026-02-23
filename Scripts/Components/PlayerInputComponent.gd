extends Node
class_name PlayerInputComponent

## Handles all player input processing and provides clean access to input state

signal jump_pressed
signal jump_released
signal pickup_pressed
signal inventory_toggled

var input_dir: Vector2 = Vector2.ZERO
var mouse_captured: bool = false
var crouch_input: bool = false

# Mouse/gamepad look
var mouse_delta: Vector2 = Vector2.ZERO
var gamepad_look: Vector2 = Vector2.ZERO

@export var camera_look_sensitivity: float = 0.3
@export var gamepad_look_sensitivity: float = 3.0


func _ready():
	# Input is processed in parent's _input and _process
	pass


func process_input(event: InputEvent) -> void:
	"""Process input events from the player controller"""
	# Update movement input
	input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	
	# Mouse look
	if event is InputEventMouseMotion and mouse_captured:
		mouse_delta = event.relative * camera_look_sensitivity * 0.01
	else:
		mouse_delta = Vector2.ZERO
	
	# Toggle mouse capture
	if event.is_action_pressed("ui_cancel"):
		toggle_mouse_capture()
	
	# Inventory toggle
	if event.is_action_pressed("inventory"):
		inventory_toggled.emit()
	
	# Pickup
	if event.is_action_pressed("pickup"):
		pickup_pressed.emit()
	
	# Jump
	if Input.is_action_just_pressed("jump"):
		jump_pressed.emit()
	
	if Input.is_action_just_released("jump"):
		jump_released.emit()
	
	# Crouch toggle
	if Input.is_action_just_pressed("crouch"):
		crouch_input = !crouch_input
		print('Toggle crouch: ', crouch_input)


func process_gamepad_look(delta: float) -> void:
	"""Process gamepad right stick for camera control"""
	var right_stick = Vector2(
		Input.get_joy_axis(0, JOY_AXIS_RIGHT_X),
		Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
	)
	
	# Apply deadzone
	if right_stick.length() < 0.15:
		right_stick = Vector2.ZERO
	
	gamepad_look = right_stick


func toggle_mouse_capture():
	mouse_captured = !mouse_captured
	if mouse_captured:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func get_input_direction() -> Vector2:
	return input_dir


func get_mouse_delta() -> Vector2:
	return mouse_delta


func get_gamepad_look() -> Vector2:
	return gamepad_look


func is_crouching() -> bool:
	return crouch_input


func has_movement_input() -> bool:
	return input_dir.length() > 0.01


func clear_input() -> void:
	"""Clear all input (used when disabling player control)"""
	input_dir = Vector2.ZERO
	mouse_delta = Vector2.ZERO
	gamepad_look = Vector2.ZERO
	crouch_input = false
