class_name SpaceshipController
extends Node3D

var galactic_position: Vector3i = Vector3i.ZERO #For development we start with only one system at galactic coord (0, 0, 0)
var system_position: Vector3i #Position in System Units 
var local_position: Vector3 #Local Position offset for realistic orbits and planet position precision

@export var mouse_sensitivity: float = 1.5   # Increased for better responsiveness
@export var engine_power: float = 50000.0
@export var engine_max_speed: float = 50000000 #m/s

@export var roll_speed: float = 0.5
@export var pitch_speed: float = 2.0
@export var yaw_speed: float = 2.0
@export var rotation_damping: float = 0.9  # How quickly rotation slows down (0-1)
@export var boost_multiplier: float = 20.0

# Camera configuration - Exported variables
@export var camera_distance: float = 25.0
@export var camera_height: float = 5.0
@export var camera_fov: float = 75.0           # Field of view in degrees
@export var camera_look_sensitivity: float = 0.3  # Sensitivity for look-around mode
@export var camera_follow_speed: float = 5  # How quickly camera distance adjusts to speed
@export var camera_max_distance: float = 100.0  # Maximum camera distance at top speed

@onready var CameraPivot: Node3D = get_node("CameraPivot")
@onready var Camera: Camera3D = get_node("CameraPivot/Camera3D")

var mouse_captured: bool = false
var camera_look_mode: bool = false  # Toggle between flight control and look-around
var target_camera_position: Vector3 = Vector3.ZERO
var current_camera_distance: float = 15.0  # Current smooth camera distance

# Movement state
var thrust_input: Vector3 = Vector3.ZERO
var rotation_input: Vector3 = Vector3.ZERO
var boost_active: bool = false
var velocity: Vector3 = Vector3.ZERO
var angular_velocity: Vector3 = Vector3.ZERO
var current_speed: float = 0.0

# Called when the node enters the scene tree for the first time.
func _ready():
	# Capture mouse for flight controls
	capture_mouse()
	current_camera_distance = camera_distance
	
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	handle_input()
	apply_thrust(delta)
	apply_rotation(delta)
	position += velocity * delta
	
	# Update space coordinates
	local_position = position
	
	# Update camera position with interpolation
	#update_camera_position(delta)
	
	# Update current speed for UI/debugging
	current_speed = velocity.length()

## Handle input processing
func _input(event):
	if event is InputEventMouseMotion and mouse_captured:
		handle_mouse_input(event)
	elif event.is_action_pressed("ui_cancel"):
		toggle_mouse_capture()
	elif event.is_action_pressed("ui_focus_next"):  # Tab key
		toggle_camera_mode()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_QUOTELEFT:  # Backtick key
		print("Backtick key pressed!")
		toggle_wireframe_mode()


## Handle all input processing
func handle_input():
	# Reset thrust input each frame
	thrust_input = Vector3.ZERO
	
	# Thrust inputs (WASD + Space/Shift)
	if Input.is_action_pressed("thrust_forward"):
		thrust_input.z -= 1.0
	if Input.is_action_pressed("thrust_backward"):
		thrust_input.z += 1.0
	if Input.is_action_pressed("thrust_left"):
		thrust_input.x -= 1.0
	if Input.is_action_pressed("thrust_right"):
		thrust_input.x += 1.0
	if Input.is_action_pressed("thrust_up"):
		thrust_input.y += 1.0
	if Input.is_action_pressed("thrust_down"):
		thrust_input.y -= 1.0
	
	# Roll inputs (Q/E)
	rotation_input.z = 0.0  # Reset roll
	if Input.is_action_pressed("roll_left"):
		rotation_input.z += 1.0
	if Input.is_action_pressed("roll_right"):
		rotation_input.z -= 1.0
	
	# Boost
	boost_active = Input.is_action_pressed("ui_accept")  # Left Shift

## Toggle mouse capture for flight controls
func toggle_mouse_capture():
	mouse_captured = !mouse_captured
	if mouse_captured:
		capture_mouse()
	else:
		release_mouse()

## Toggle camera look-around mode
func toggle_camera_mode():
	camera_look_mode = !camera_look_mode
	if not camera_look_mode:
		# Reset camera pivot rotation when exiting look mode
		CameraPivot.rotation = Vector3.ZERO

## Toggle wireframe rendering for all planets
func toggle_wireframe_mode():
	print("toggle_wireframe_mode called")
	var viewport = get_viewport()
	if viewport:
		if viewport.debug_draw == Viewport.DEBUG_DRAW_DISABLED:
			viewport.debug_draw = Viewport.DEBUG_DRAW_WIREFRAME
			print("Wireframe mode ENABLED")
		else:
			viewport.debug_draw = Viewport.DEBUG_DRAW_DISABLED
			print("Wireframe mode DISABLED")
	else:
		print("Could not get viewport!")
		
## Capture mouse for flight controls
func capture_mouse():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	mouse_captured = true

## Release mouse
func release_mouse():
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	mouse_captured = false
	
## Handle mouse input for pitch and yaw
func handle_mouse_input(event: InputEventMouseMotion):
	if camera_look_mode:
		# Look-around mode: rotate camera pivot
		var mouse_delta = event.relative * camera_look_sensitivity * 0.01
		CameraPivot.rotate_y(-mouse_delta.x)  # Horizontal rotation
		CameraPivot.rotate_object_local(Vector3.RIGHT, -mouse_delta.y)  # Vertical rotation
		
		# Clamp vertical rotation to prevent flipping
		var current_rotation = CameraPivot.rotation.x
		CameraPivot.rotation.x = clamp(current_rotation, -PI/2, PI/2)
	else:
		# Flight control mode: rotate ship
		var mouse_delta = event.relative * mouse_sensitivity * 0.001
		
		# Add to angular velocity for smooth, physics-based rotation
		rotation_input.x += -mouse_delta.y  # Pitch (up/down)
		rotation_input.y += -mouse_delta.x  # Yaw (left/right)
	
	
func setup_camera():
	#Set camera position to 0 first
	Camera.position = Vector3.ZERO
	Camera.position.y += camera_height
	Camera.position.z += camera_distance
	
	# Set camera far clip distance to maximum
	#Camera.far = 1000000.0  # 1 million units for space visibility
	
	# Initialize camera pivot position
	target_camera_position = Vector3.ZERO
	CameraPivot.position = Vector3.ZERO

## Update camera pivot position with smooth interpolation
func update_camera_position(delta: float):
	# Calculate target distance based on current speed
	var speed_ratio = current_speed / engine_max_speed  # 0 to 1 (or more with boost)
	var target_distance = lerp(camera_distance, camera_max_distance, speed_ratio)
	
	# Smoothly interpolate current distance to target
	current_camera_distance = lerp(current_camera_distance, target_distance, camera_follow_speed)
	
	# Update camera position based on current distance (maintain height)
	Camera.position.y = camera_height
	Camera.position.z = current_camera_distance
	# Keep camera pivot centered
	CameraPivot.position = Vector3.ZERO

	


## Apply physics-based rotation from input
func apply_rotation(delta: float):
	# Apply rotation input to angular velocity
	angular_velocity.x += rotation_input.x * pitch_speed
	angular_velocity.y += rotation_input.y * yaw_speed
	angular_velocity.z += rotation_input.z * roll_speed
	
	# Apply damping to angular velocity
	angular_velocity.x *= rotation_damping
	angular_velocity.y *= rotation_damping
	angular_velocity.z *= rotation_damping
	
	# Create rotation from angular velocity (properly combined)
	var rotation_amount = angular_velocity * delta
	
	# Apply rotation using basis - this maintains proper local axes
	var rotation_basis = Basis()
	rotation_basis = rotation_basis.rotated(Vector3(1, 0, 0), rotation_amount.x)  # Pitch
	rotation_basis = rotation_basis.rotated(Vector3(0, 1, 0), rotation_amount.y)  # Yaw  
	rotation_basis = rotation_basis.rotated(Vector3(0, 0, 1), rotation_amount.z)  # Roll
	
	# Apply to ship's transform
	transform.basis = transform.basis * rotation_basis
	
	# Reset rotation input for next frame (it accumulates from mouse)
	rotation_input.x = 0.0
	rotation_input.y = 0.0

## Apply thrust based on input, respecting max speed
func apply_thrust(delta: float):
	if thrust_input.length() > 0:
		# Normalize input to prevent faster diagonal movement
		var input_direction = thrust_input.normalized()
		
		# Transform input to world space based on ship orientation
		var thrust_direction = global_transform.basis * input_direction
		
		# Calculate effective power (with boost)
		var effective_power = engine_power
		if boost_active:
			effective_power *= boost_multiplier
		
		# Apply acceleration
		velocity += thrust_direction * effective_power * delta
		
		# Limit to max speed
		var effective_max_speed = engine_max_speed
		if boost_active:
			effective_max_speed *= boost_multiplier
		
		if velocity.length() > effective_max_speed:
			velocity = velocity.normalized() * effective_max_speed
	else:
		# Optional: Add drag/dampening when no thrust
		velocity *= 0.98  # Slight decay for more arcade feel (remove for pure Newtonian physics)
