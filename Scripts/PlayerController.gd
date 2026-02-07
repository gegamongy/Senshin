extends CharacterBody3D

@onready var CameraPivot: Node3D = get_node("CameraPivot")
@onready var Camera: Camera3D = get_node("CameraPivot/Camera3D")
@onready var animation_tree: AnimationTree = get_node("AnimationTree")
@onready var state_machine = animation_tree.get("parameters/playback")

@export var camera_distance: float = 25.0
@export var camera_height: float = 5.0
@export var camera_fov: float = 75.0      
@export var camera_look_sensitivity: float = 0.3  # Sensitivity for look-around mode
@export var gamepad_look_sensitivity: float = 3.0  # Sensitivity for gamepad right stick
@export_range(0.0, 1.0) var air_control: float = 1.0  # How much input affects air speed

const SPEED = 15.0
const JUMP_VELOCITY = 10
const MIN_Y_ROTATION = -80
const MAX_Y_ROTATION = 80
const INPUT_ACCEL_SPEED = 10.0  # How fast input magnitude changes
const ROTATION_SPEED = 8.0  # How fast the character rotates towards movement direction
const SMOOTHED_SPEED_DECAY = 8.0  # How fast smoothed speed decays when slowing down
const RUN_180_THRESHOLD = 8.0  # Speed threshold for run 180 animation
const WALK_180_THRESHOLD = 1.0  # Speed threshold for walk 180 animation


# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

var mouse_captured: bool = false
var crouch_input = false
var input_dir: Vector2 #Input direction, normalized
var move_dir: Vector3 #Actual movement direction in world space. Value between 0-1 is the velocity
var camera_yaw: float = 0.0
var camera_pitch: float = 0.0

var input_magnitude = 0.0
var smoothed_speed = 0.0  # Slowly decaying speed for animation selection
var is_turning_180 = false  # Track if we're in a 180 turn animation
var jump_direction = 1.0  # 1.0 for forward jump, -1.0 for backward jump

var is_grounded = true
var has_movement = false
var was_grounded = true
var landing_velocity = Vector3.ZERO
var landing_frames = 0
var original_root_motion_track: NodePath  # Store original track to restore after backflip
var pending_backflip_root_motion_disable = false  # Flag to disable root motion after blend

var nearby_pickups: Array[WeaponBase] = []  # Track nearby items that can be picked up

func _ready():
	# Make camera pivot top-level so it doesn't rotate with the character
	# Add player to group for pickup detection
	add_to_group("player")
	CameraPivot.set_as_top_level(true)
	
	# Ensure AnimationTree processes in physics mode for consistent timing
	animation_tree.set_process_callback(AnimationTree.ANIMATION_PROCESS_PHYSICS)
	
	# Store original root motion track
	original_root_motion_track = animation_tree.root_motion_track


#region Physics Process

func _physics_process(delta):
	# Update grounded state FIRST - critical for proper state transitions
	is_grounded = is_on_floor()
	animation_tree.set("parameters/conditions/is_grounded", is_grounded)
	animation_tree.set("parameters/conditions/is_airborne", not is_grounded)
	
	# Force jump state if we're airborne but not in a jump state
	if not is_grounded:
		var current_state = state_machine.get_current_node()
		if current_state not in ["JumpStart", "JumpMidair", "JumpLand"]:
			state_machine.travel("JumpMidair")
			print("Force corrected to JumpMidair from: ", current_state)
	
	# Always restore root motion when grounded (prevent it getting stuck off)
	if is_grounded and animation_tree.root_motion_track != original_root_motion_track:
		animation_tree.root_motion_track = original_root_motion_track
		pending_backflip_root_motion_disable = false
	
	update_animation_conditions()
	apply_gravity(delta)
	handle_gamepad_camera(delta)
	
	# Track landing
	if not was_grounded and is_on_floor():
		# Just landed - cache the horizontal velocity
		landing_velocity = Vector3(velocity.x, 0, velocity.z)
		landing_frames = 3  # Blend for 3 frames
		
		# Restore root motion tracking after landing from backflip
		if jump_direction == -1.0:
			animation_tree.root_motion_track = original_root_motion_track
			pending_backflip_root_motion_disable = false
	was_grounded = is_on_floor()
	
	# Disable root motion for backflip only after transition to JumpStart completes
	if pending_backflip_root_motion_disable and state_machine.get_current_node() == "JumpStart":
		animation_tree.root_motion_track = NodePath()
		pending_backflip_root_motion_disable = false
	
	# NOTE: For backward jumps, we DON'T apply root motion rotation to the CharacterBody3D
	# The backflip rotation happens visually on the mesh/skeleton, but the physics body stays upright
	# This prevents rotation issues and keeps the character controller stable
	
	move_dir = calculate_movement_direction()
	var has_movement_input = move_dir.length() > 0.01
	
	# Update smoothed speed (decays slowly for animation selection)
	var current_horizontal_speed = Vector2(velocity.x, velocity.z).length()
	if current_horizontal_speed > smoothed_speed:
		# Accelerating - track immediately
		smoothed_speed = current_horizontal_speed
	else:
		# Decelerating - decay slowly
		smoothed_speed = lerp(smoothed_speed, current_horizontal_speed, SMOOTHED_SPEED_DECAY * delta)
	
	# Check if 180 turn animation completed (regardless of input)
	if is_turning_180:
		var current_state = state_machine.get_current_node()
		if current_state == "Grounded":
			is_turning_180 = false
	
	if has_movement_input:
		move_dir = move_dir.normalized()
		check_turn_angles(move_dir)
	
	update_input_magnitude(delta)
	
	if is_on_floor():
		handle_grounded_movement(has_movement_input, move_dir, delta)
	else:
		handle_air_movement(has_movement_input, move_dir, delta)
	
	move_and_slide()
	update_camera_position()


#endregion


#region Movement & Animation

func update_animation_conditions():
	is_grounded = is_on_floor()
	has_movement = input_dir.length() > 0.01
	


func apply_gravity(delta: float):
	if not is_on_floor():
		velocity.y -= gravity * delta


func calculate_movement_direction() -> Vector3:
	# Get camera-relative movement direction in WORLD space
	var camera_basis = Basis()
	camera_basis = camera_basis.rotated(Vector3.UP, camera_yaw + PI)
	var camera_forward = -camera_basis.z
	var camera_right = camera_basis.x
	
	camera_forward.y = 0
	camera_right.y = 0
	camera_forward = camera_forward.normalized()
	camera_right = camera_right.normalized()
	
	return camera_right * input_dir.x + camera_forward * -input_dir.y


func check_turn_angles(move_dir: Vector3):
	# Only allow 180 turns when grounded
	if not is_on_floor():
		return
	
	# Don't check for new turns while already performing a 180 turn
	if is_turning_180:
		return
		
	var player_forward = global_transform.basis.z
	player_forward.y = 0
	player_forward = player_forward.normalized()
	
	var turn_angle = signed_angle_between(player_forward, move_dir)
	
	# Determine which 180 animation variant to use based on recent speed
	var turn_180_blend = 0.0
	if turn_angle < -(PI/2) and turn_angle >= (-PI):
		# Clockwise turn
		turn_180_blend = -1.0
		print("Turn Angle (radians): ", turn_angle, ", CLOCKWISE, Speed: ", smoothed_speed)
	elif turn_angle > (PI/2) and turn_angle <= PI:
		# Counter-clockwise turn
		turn_180_blend = 1.0
		print("Turn Angle (radians): ", turn_angle, ", COUNTER CLOCKWISE, Speed: ", smoothed_speed)
	
	if turn_180_blend != 0.0:
		# Determine speed tier based on smoothed speed (locked in at start of turn)
		if smoothed_speed >= RUN_180_THRESHOLD:
			animation_tree.set("parameters/Run180/blend_position", turn_180_blend)
			state_machine.travel("Run180")
			is_turning_180 = true
			print("-> Using RUN_180 animation")
			
		elif smoothed_speed >= WALK_180_THRESHOLD:
			animation_tree.set("parameters/Walk180/blend_position", turn_180_blend)
			state_machine.travel("Walk180")
			is_turning_180 = true
			print("-> Using WALK_180 animation")
		
		else:
			# Idle turn variants
			if crouch_input:
				move_dir *= 0.5  # Reduce speed for crouch idle turns
			if move_dir.length() > 0.7:
				animation_tree.set("parameters/IdleRun180/blend_position", turn_180_blend)
				state_machine.travel("IdleRun180")
				is_turning_180 = true
				print("-> Using IDLE_RUN_180 animation")
		
			elif move_dir.length() <= 0.7:
				animation_tree.set("parameters/IdleWalk180/blend_position", turn_180_blend)
				state_machine.travel("IdleWalk180")
				is_turning_180 = true
				print("-> Using IDLE_WALK_180 animation")


func update_input_magnitude(delta: float):
	var target_magnitude = input_dir.length()
	if crouch_input:
		target_magnitude *= 0.5
	
	input_magnitude = lerp(input_magnitude, target_magnitude, INPUT_ACCEL_SPEED * delta)
	animation_tree.set("parameters/Grounded/move/blend_position", input_magnitude)


func handle_grounded_movement(has_movement: bool, move_dir: Vector3, delta: float):
	# Only lerp rotation when not in a 180 turn animation
	if has_movement and not is_turning_180:
		lerp_body_rotation(move_dir, delta)
	
	# Cap effective delta for root motion to prevent huge jumps at low FPS
	var capped_delta = min(delta, 1.0 / 30.0)  # Cap at 30 FPS equivalent
	
	var root_motion = animation_tree.get_root_motion_position()
	var root_motion_velocity = global_transform.basis * (root_motion / capped_delta)
	
	# During 180 turns, use PURE root motion (both position and rotation)
	if is_turning_180:
		var root_motion_rotation = animation_tree.get_root_motion_rotation()
		# Extract rotation (use -euler.z for Blender imports)
		var euler = root_motion_rotation.get_euler(EULER_ORDER_YXZ)
		# Apply rotation directly without scaling - animations should have correct timing
		rotation.y += -euler.z
		
		# Apply root motion position with capped delta for consistency
		velocity.x = root_motion_velocity.x
		velocity.z = root_motion_velocity.z

	# Blend with cached landing velocity to prevent pause when landing
	elif landing_frames > 0 and has_movement:
		var blend_factor = float(landing_frames) / 3.0
		velocity.x = lerp(root_motion_velocity.x, landing_velocity.x, blend_factor)
		velocity.z = lerp(root_motion_velocity.z, landing_velocity.z, blend_factor)
		landing_frames -= 1
	else:
		velocity.x = root_motion_velocity.x
		velocity.z = root_motion_velocity.z


#endregion


#region Air Movement

func handle_air_movement(has_movement: bool, move_dir: Vector3, delta: float):
	if has_movement:
		# Rotate toward input direction
		lerp_body_rotation(move_dir, delta)
		
		# Calculate target velocity based on input
		var target_velocity = move_dir * SPEED
		
		# Lerp between current velocity and target based on air_control
		# air_control = 0: keep current velocity (momentum preservation)
		# air_control = 1: match target velocity (full control)
		velocity.x = lerp(velocity.x, target_velocity.x, air_control)
		velocity.z = lerp(velocity.z, target_velocity.z, air_control)
	else:
		# When no input, slow down based on air_control
		if air_control > 0:
			velocity.x = lerp(velocity.x, 0.0, air_control * 0.1)
			velocity.z = lerp(velocity.z, 0.0, air_control * 0.1)


#endregion


#region Camera

func update_camera_position():
	CameraPivot.global_position = global_position


func handle_gamepad_camera(delta: float):
	# Block camera control when inventory is open
	if InventoryManager.is_open:
		return
	
	# Get right stick input for camera control
	var right_stick = Vector2(
		Input.get_joy_axis(0, JOY_AXIS_RIGHT_X),
		Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
	)
	
	# Apply deadzone
	if right_stick.length() < 0.15:
		right_stick = Vector2.ZERO
	
	if right_stick.length() > 0.01:
		# Update yaw and pitch based on stick input
		camera_yaw -= right_stick.x * gamepad_look_sensitivity * delta
		camera_pitch += right_stick.y * gamepad_look_sensitivity * delta
		
		# Clamp pitch to prevent camera flipping
		camera_pitch = clamp(camera_pitch, deg_to_rad(MIN_Y_ROTATION), deg_to_rad(MAX_Y_ROTATION))
		
		# Apply the rotations directly
		CameraPivot.rotation.y = camera_yaw
		CameraPivot.rotation.x = camera_pitch


#endregion


#region Input Handling

func _input(event):
	# Block all player input when inventory is open
	if InventoryManager.is_open:
		if event.is_action_pressed("inventory"):
			InventoryManager.toggle_inventory()
		return
	
	input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	
	if event is InputEventMouseMotion and mouse_captured:
		handle_mouse_input(event)
	elif event.is_action_pressed("ui_cancel"):
		toggle_mouse_capture()
	
	if event.is_action_pressed("inventory"):
		InventoryManager.toggle_inventory()
	
	if event.is_action_pressed("pickup"):
		try_pickup()
	
	handle_jump_input()
	
	if Input.is_action_just_pressed("crouch"):
		crouch_input = !crouch_input
		print('Toggle crouch: ', crouch_input)
		

func handle_jump_input():
	# Handle jump input and set direction
	if Input.is_action_just_pressed("jump") and is_on_floor():
		# Determine if this is a backward jump (backflip) based on movement vs facing direction
		if should_backflip():
			jump_direction = -1.0  # Backward jump (backflip)
			pending_backflip_root_motion_disable = true
		else:
			jump_direction = 1.0  # Forward jump
		
		velocity.y = JUMP_VELOCITY
		animation_tree.set("parameters/JumpStart/blend_position", jump_direction)
		animation_tree.set("parameters/conditions/jump_pressed", true)
		
		# Force immediate travel to JumpStart to override any other animation
		state_machine.travel("JumpStart")
	else:
		animation_tree.set("parameters/conditions/jump_pressed", false)


func should_backflip() -> bool:
	# Check if player is moving more than 90 degrees opposite to facing direction
	if input_dir.length() <= 0.01:
		return false  # No movement input
	
	var world_move_dir = calculate_movement_direction().normalized()
	var player_forward = global_transform.basis.z
	player_forward.y = 0
	player_forward = player_forward.normalized()
	
	var angle = signed_angle_between(player_forward, world_move_dir)
	return abs(angle) > PI / 2


func try_pickup():
	# Try to pick up the nearest item in range
	print("Try pickup called, nearby items: ", nearby_pickups.size())
	if nearby_pickups.size() > 0:
		var nearest_pickup = nearby_pickups[0]
		if nearest_pickup and is_instance_valid(nearest_pickup):
			print("Attempting to pick up item")
			nearest_pickup.pickup()
	else:
		print("No nearby pickups")


func register_pickup(pickup: WeaponBase):
	if not nearby_pickups.has(pickup):
		nearby_pickups.append(pickup)
		print("Registered pickup: ", pickup.name, " Total nearby: ", nearby_pickups.size())


func unregister_pickup(pickup: WeaponBase):
	nearby_pickups.erase(pickup)
	print("Unregistered pickup: ", pickup.name, " Total nearby: ", nearby_pickups.size())


## Handle mouse input for pitch and yaw
func handle_mouse_input(event: InputEventMouseMotion):
	
	# Update yaw and pitch based on mouse movement
	var mouse_delta = event.relative * camera_look_sensitivity * 0.01
	camera_yaw -= mouse_delta.x
	camera_pitch += mouse_delta.y
	
	# Clamp pitch to prevent camera flipping
	camera_pitch = clamp(camera_pitch, deg_to_rad(MIN_Y_ROTATION), deg_to_rad(MAX_Y_ROTATION))
	
	# Apply the rotations directly
	CameraPivot.rotation.y = camera_yaw
	CameraPivot.rotation.x = camera_pitch
	
func signed_angle_between(forward: Vector3, move_dir: Vector3) -> float:
	# Assume both are normalized and flattened to XZ plane. Radians, Range: (-PI, PI). Positive is counter clockwise, and negative is clockwise.
	var dot = forward.dot(move_dir)
	var cross_y = forward.cross(move_dir).y
	return atan2(cross_y, dot)


func lerp_body_rotation(target_direction: Vector3, delta: float):
	# Calculate target rotation from movement direction
	var target_rotation = atan2(target_direction.x, target_direction.z)
	
	# Lerp the rotation
	var new_rotation = lerp_angle(rotation.y, target_rotation, ROTATION_SPEED * delta)
	
	# Apply rotation
	rotation.y = new_rotation


#region Mouse Capture

func toggle_mouse_capture():
	mouse_captured = !mouse_captured
	if mouse_captured:
		capture_mouse()
	else:
		release_mouse()


func capture_mouse():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	mouse_captured = true


func release_mouse():
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	mouse_captured = false


#endregion
