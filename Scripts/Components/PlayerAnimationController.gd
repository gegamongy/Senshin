extends Node
class_name PlayerAnimationController

## Manages direct animation playback and root motion - no automatic transitions

var animation_tree: AnimationTree
var state_machine: AnimationNodeStateMachinePlayback
var character_body: CharacterBody3D
var locomotion: PlayerLocomotionComponent

var original_root_motion_track: NodePath

# Animation library management
var unarmed_idle_anim: StringName = &"Idle"
var unarmed_walk_anim: StringName = &"WalkForward"
var unarmed_run_anim: StringName = &"RunForward"
var is_using_weapon_anims: bool = false

	# Lock-on state
var is_locked_on: bool = false
var lock_on_target: Node3D = null
var current_strafe_blend: Vector2 = Vector2.ZERO  # Track current strafe direction


func _ready():
	pass


func initialize(anim_tree: AnimationTree, body: CharacterBody3D, locomotion_component: PlayerLocomotionComponent):
	"""Initialize with references to animation tree and other components"""
	animation_tree = anim_tree
	character_body = body
	locomotion = locomotion_component
	state_machine = animation_tree.get("parameters/playback")
	
	# Ensure AnimationTree processes in physics mode
	animation_tree.set_process_callback(AnimationTree.ANIMATION_PROCESS_PHYSICS)
	
	# Store original root motion track
	original_root_motion_track = animation_tree.root_motion_track


func process_animation(delta: float) -> void:
	"""Main animation processing - called every physics frame"""
	# Handle root motion restoration when grounded
	if locomotion.get_is_grounded() and animation_tree.root_motion_track != original_root_motion_track:
		animation_tree.root_motion_track = original_root_motion_track
		locomotion.set_pending_backflip_root_motion_disable(false)
	
	# Disable root motion for backflip after transition (check if we're in Airborne state machine)
	if locomotion.get_pending_backflip_root_motion_disable() and state_machine.get_current_node() == "Airborne":
		animation_tree.root_motion_track = NodePath()
		locomotion.set_pending_backflip_root_motion_disable(false)
	
	# Apply root motion to locomotion
	apply_root_motion(delta)
	
	# Update animation blend parameters for Grounded state machine
	update_grounded_blend_parameters()


#region Direct Animation Playback

func play_animation(anim_name: String) -> void:
	"""Directly play an animation state"""
	state_machine.travel(anim_name)


func play_grounded_movement() -> void:
	"""Play the grounded movement blend space"""
	# If we're already in Grounded state, check if a oneshot is active
	if state_machine.get_current_node() == "Grounded":
		# Check if either oneshot is active - don't interrupt them
		var unsheathe_active = animation_tree.get("parameters/Grounded/unsheathe/active")
		var sheathe_active = animation_tree.get("parameters/Grounded/sheathe/active")
		
		if unsheathe_active or sheathe_active:
			print("[AnimController] Skipping grounded movement travel - oneshot is active")
			return
	
	state_machine.travel("Grounded")
	# Explicitly tell Grounded state machine to play move blend space
	var grounded_playback = animation_tree.get("parameters/Grounded/playback") as AnimationNodeStateMachinePlayback
	if grounded_playback:
		grounded_playback.travel("move")


func play_jump_start(direction: float) -> void:
	"""Play jump start animation (direction: 1.0 = forward, -1.0 = backward)"""
	# Navigate to Airborne state machine, then set JumpStart blend position
	animation_tree.set("parameters/Airborne/JumpStart/blend_position", direction)
	state_machine.travel("Airborne")
	# Explicitly tell Airborne state machine to play JumpStart
	var airborne_playback = animation_tree.get("parameters/Airborne/playback") as AnimationNodeStateMachinePlayback
	if airborne_playback:
		airborne_playback.travel("JumpStart")


func play_jump_midair() -> void:
	"""Play midair animation"""
	# Tell Airborne state machine to play JumpMidair
	var airborne_playback = animation_tree.get("parameters/Airborne/playback") as AnimationNodeStateMachinePlayback
	if airborne_playback:
		airborne_playback.travel("JumpMidair")


func play_jump_land() -> void:
	"""Play landing animation"""
	# Tell Airborne state machine to play JumpLand
	var airborne_playback = animation_tree.get("parameters/Airborne/playback") as AnimationNodeStateMachinePlayback
	if airborne_playback:
		airborne_playback.travel("JumpLand")


func is_grounded_animation_playing() -> bool:
	"""Check if currently in the Grounded state machine"""
	return state_machine.get_current_node() == "Grounded"


func is_jump_start_playing() -> bool:
	"""Check if currently in Airborne/JumpStart"""
	var current = state_machine.get_current_node()
	return current == "Airborne"


func is_in_airborne_state() -> bool:
	"""Check if currently in Airborne state machine"""
	return state_machine.get_current_node() == "Airborne"


func get_airborne_playback() -> AnimationNodeStateMachinePlayback:
	"""Get the nested Airborne state machine playback for direct animation control"""
	return animation_tree.get("parameters/Airborne/playback") as AnimationNodeStateMachinePlayback


func get_current_animation() -> String:
	"""Get the name of the currently playing animation state"""
	return state_machine.get_current_node()


func get_jump_start_duration(direction: float) -> float:
	"""Get the duration of the jump start animation based on direction"""
	var anim_player = animation_tree.get_node(animation_tree.anim_player) as AnimationPlayer
	if not anim_player:
		return 0.5  # Fallback duration
	
	# Determine which animation based on direction
	var anim_name_base = "JumpStartFWD" if direction > 0 else "JumpStartBWD"
	
	# Try with library prefix first, then without
	var possible_names = [
		"BaseUnarmedLibrary/" + anim_name_base,
		anim_name_base
	]
	
	for anim_name in possible_names:
		if anim_player.has_animation(anim_name):
			return anim_player.get_animation(anim_name).length
	
	return 0.5  # Fallback


func play_unsheathe() -> void:
	"""Play unsheathe animation"""
	state_machine.travel("Combat")
	var combat_playback = animation_tree.get("parameters/Combat/playback") as AnimationNodeStateMachinePlayback
	if combat_playback:
		combat_playback.travel("SheatheUnsheathe")
		var sheathe_playback = animation_tree.get("parameters/Combat/SheatheUnsheathe/playback") as AnimationNodeStateMachinePlayback
		if sheathe_playback:
			sheathe_playback.travel("Unsheathe")


func play_sheathe() -> void:
	"""Play sheathe animation"""
	state_machine.travel("Combat")
	var combat_playback = animation_tree.get("parameters/Combat/playback") as AnimationNodeStateMachinePlayback
	if combat_playback:
		combat_playback.travel("SheatheUnsheathe")
		var sheathe_playback = animation_tree.get("parameters/Combat/SheatheUnsheathe/playback") as AnimationNodeStateMachinePlayback
		if sheathe_playback:
			sheathe_playback.travel("Sheathe")


func play_unsheathe_moving() -> void:
	"""Play unsheathe animation while moving (oneshot layered over locomotion)"""
	print("[Oneshot] play_unsheathe_moving() called")
	
	# Verify we're in the Grounded state
	var current_state = state_machine.get_current_node()
	print("[Oneshot] Current AnimationTree state: ", current_state)
	
	if current_state != "Grounded":
		print("[Oneshot] ERROR: Not in Grounded state! Oneshot won't work!")
		return
	
	# Check oneshot state and abort if still active
	var oneshot_path = "parameters/Grounded/unsheathe/request"
	var oneshot_active_path = "parameters/Grounded/unsheathe/active"
	var is_active = animation_tree.get(oneshot_active_path)
	
	if is_active:
		print("[Oneshot] Unsheathe oneshot already active - aborting first")
		animation_tree.set(oneshot_path, AnimationNodeOneShot.ONE_SHOT_REQUEST_ABORT)
		await animation_tree.get_tree().process_frame
	
	# Trigger oneshot (will layer over current movement animation)
	print("[Oneshot] FIRING unsheathe oneshot")
	animation_tree.set(oneshot_path, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	
	# Verify it actually fired
	await animation_tree.get_tree().process_frame
	var did_fire = animation_tree.get(oneshot_active_path)
	print("[Oneshot] Unsheathe oneshot active after fire: ", did_fire)


func play_sheathe_moving() -> void:
	"""Play sheathe animation while moving (oneshot layered over locomotion)"""
	print("[Oneshot] play_sheathe_moving() called")
	
	# Verify we're in the Grounded state
	var current_state = state_machine.get_current_node()
	print("[Oneshot] Current AnimationTree state: ", current_state)
	
	if current_state != "Grounded":
		print("[Oneshot] ERROR: Not in Grounded state! Oneshot won't work!")
		return
	
	# Check oneshot state and abort if still active
	var oneshot_path = "parameters/Grounded/sheathe/request"
	var oneshot_active_path = "parameters/Grounded/sheathe/active"
	var is_active = animation_tree.get(oneshot_active_path)
	
	if is_active:
		print("[Oneshot] Sheathe oneshot already active - aborting first")
		animation_tree.set(oneshot_path, AnimationNodeOneShot.ONE_SHOT_REQUEST_ABORT)
		await animation_tree.get_tree().process_frame
	
	# Trigger oneshot (will layer over current movement animation)
	print("[Oneshot] FIRING sheathe oneshot")
	animation_tree.set(oneshot_path, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	
	# Verify it actually fired
	await animation_tree.get_tree().process_frame
	var did_fire = animation_tree.get(oneshot_active_path)
	print("[Oneshot] Sheathe oneshot active after fire: ", did_fire)


func get_unsheathe_duration() -> float:
	"""Get the duration of the unsheathe animation"""
	var anim_player = animation_tree.get_node(animation_tree.anim_player) as AnimationPlayer
	if not anim_player:
		return 1.0
	
	# Get all loaded libraries and try to find the animation
	for lib_name in anim_player.get_animation_library_list():
		if lib_name == "" or lib_name == "BaseUnarmedLibrary":
			continue  # Skip base/empty library
		
		# Try with library prefix
		var possible_names = [
			lib_name + "/Unsheathe",
			lib_name + "/KatanaUnsheathe",
			lib_name + "/GreatswordUnsheathe",
			lib_name + "/SpearUnsheathe"
		]
		
		for anim_name in possible_names:
			if anim_player.has_animation(anim_name):
						return anim_player.get_animation(anim_name).length
	
	return 1.0  # Fallback


func get_sheathe_duration() -> float:
	"""Get the duration of the sheathe animation"""
	var anim_player = animation_tree.get_node(animation_tree.anim_player) as AnimationPlayer
	if not anim_player:
		return 1.0
	
	# Get all loaded libraries and try to find the animation
	for lib_name in anim_player.get_animation_library_list():
		if lib_name == "" or lib_name == "BaseUnarmedLibrary":
			continue  # Skip base/empty library
		
		# Try with library prefix
		var possible_names = [
			lib_name + "/Sheathe",
			lib_name + "/KatanaSheathe",
			lib_name + "/GreatswordSheathe",
			lib_name + "/SpearSheathe"
		]
		
		for anim_name in possible_names:
			if anim_player.has_animation(anim_name):
				return anim_player.get_animation(anim_name).length
	
	return 1.0  # Fallback


func update_grounded_blend_parameters() -> void:
	"""Update blend parameters for grounded movement based on lock-on state"""
	var input_magnitude = locomotion.get_input_magnitude()
	
	# Determine if we should use strafe mode
	# Use strafe when: locked on AND moving slowly (walk speed)
	var use_strafe = is_locked_on and input_magnitude <= 0.5
	
	# Update locomotion strafe state
	locomotion.set_is_strafing(use_strafe)
	
	if use_strafe:
		# Blend to strafe mode (position 1.0 in movement BlendSpace1D)
		animation_tree.set("parameters/Grounded/movement/blend_position", 1.0)
		
		# Get world-space movement direction from locomotion
		var move_dir = locomotion.get_move_dir()
		
		# Transform movement direction to CAMERA-local space
		# This ensures consistent input: W = forward (camera forward), S = back, A/D = strafe
		var camera_yaw = locomotion.camera_yaw
		var camera_forward = Vector3.FORWARD.rotated(Vector3.UP, camera_yaw + PI)
		var camera_right = Vector3.RIGHT.rotated(Vector3.UP, camera_yaw + PI)
		camera_forward.y = 0
		camera_right.y = 0
		camera_forward = camera_forward.normalized()
		camera_right = camera_right.normalized()
		
		# Project world movement onto camera axes
		var forward_amount = move_dir.dot(camera_forward)
		var right_amount = move_dir.dot(camera_right)
		
		# Create 2D blend position in camera space
		var strafe_blend = Vector2(right_amount, forward_amount) * input_magnitude
		animation_tree.set("parameters/Grounded/movement/1/blend_position", strafe_blend)
		
		# Store for rotation calculation
		current_strafe_blend = strafe_blend
		
		# Debug output (uncomment if needed)
		# if input_magnitude > 0.01:
		# 	print("[AnimController] STRAFE mode - magnitude: ", input_magnitude, " blend: ", strafe_blend)
	else:
		# Blend to normal movement mode (position 0.0 in movement BlendSpace1D)
		animation_tree.set("parameters/Grounded/movement/blend_position", 0.0)
		
		# Set normal movement magnitude (blend space at position 0)
		animation_tree.set("parameters/Grounded/movement/0/blend_position", input_magnitude)
		
		# Clear strafe blend when not strafing
		current_strafe_blend = Vector2.ZERO
		
		# Debug output (uncomment if needed)
		# if input_magnitude > 0.01:
		# 	print("[AnimController] NORMAL mode - magnitude: ", input_magnitude)


func set_lock_on_target(target: Node3D) -> void:
	"""Set the lock-on target and enable locked movement"""
	lock_on_target = target
	is_locked_on = target != null
	print("[AnimController] Lock-on ", "enabled" if is_locked_on else "disabled")
	
	# Don't refresh AnimationTree here - it interrupts animations
	# The strafe animations were already swapped when weapon was equipped
	# AnimationTree will naturally pick them up when blend_position changes to strafe mode


func clear_lock_on() -> void:
	"""Clear lock-on target and return to normal movement"""
	lock_on_target = null
	is_locked_on = false
	current_strafe_blend = Vector2.ZERO
	
	# Force reset to normal movement mode
	locomotion.set_is_strafing(false)
	animation_tree.set("parameters/Grounded/movement/blend_position", 0.0)
	
	print("[AnimController] Lock-on cleared")


func get_strafe_blend() -> Vector2:
	"""Get current strafe blend position (X = right/left, Y = forward/back)"""
	return current_strafe_blend


#endregion


#region Root Motion Application

func apply_root_motion(delta: float) -> void:
	"""Apply root motion from animations to the character"""
	if not locomotion.get_is_grounded():
		return
	
	var capped_delta = min(delta, 1.0 / 30.0)
	var root_motion = animation_tree.get_root_motion_position()
	var root_motion_velocity: Vector3
	
	# Apply rotation for 180 turns (strafe uses bone rotation, not root motion rotation)
	if locomotion.get_is_turning_180():
		root_motion_velocity = character_body.global_transform.basis * (root_motion / capped_delta)
		var root_motion_rotation = animation_tree.get_root_motion_rotation()
		var euler = root_motion_rotation.get_euler(EULER_ORDER_YXZ)
		locomotion.apply_root_motion_rotation(-euler.z)
		character_body.velocity.x = root_motion_velocity.x
		character_body.velocity.z = root_motion_velocity.z
	elif locomotion.is_strafing:
		# Strafe mode: apply root motion relative to camera direction, not character direction
		# This keeps movement consistent with input regardless of character orientation
		var camera_basis = Basis()
		camera_basis = camera_basis.rotated(Vector3.UP, locomotion.camera_yaw)
		root_motion_velocity = camera_basis * (root_motion / capped_delta)
		
		character_body.velocity.x = root_motion_velocity.x
		character_body.velocity.z = root_motion_velocity.z
	else:
		root_motion_velocity = character_body.global_transform.basis * (root_motion / capped_delta)
		# Handle landing blend to prevent pause when landing
		if locomotion.landing_frames > 0:
			var blend_factor = float(locomotion.landing_frames) / 3.0
			character_body.velocity.x = lerp(root_motion_velocity.x, locomotion.landing_velocity.x, blend_factor)
			character_body.velocity.z = lerp(root_motion_velocity.z, locomotion.landing_velocity.z, blend_factor)
			locomotion.landing_frames -= 1
		else:
			# Normal movement - only apply position
			character_body.velocity.x = root_motion_velocity.x
			character_body.velocity.z = root_motion_velocity.z
			character_body.velocity.x = root_motion_velocity.x
			character_body.velocity.z = root_motion_velocity.z


#endregion


#region 180 Turn Detection and Playback

func check_for_180_turn(move_dir: Vector3) -> bool:
	"""Check if player should perform 180 turn and trigger animation. Returns true if turn started."""
	if not locomotion.get_is_grounded() or locomotion.get_is_turning_180():
		return false
	
	# Disable 180 turns when in strafe mode
	if locomotion.is_strafing:
		return false
	
	var player_forward = character_body.global_transform.basis.z
	player_forward.y = 0
	player_forward = player_forward.normalized()
	
	var turn_angle = signed_angle_between(player_forward, move_dir)
	var turn_180_blend = 0.0
	var smoothed_speed = locomotion.get_smoothed_speed()
	
	if turn_angle < -(PI/2) and turn_angle >= (-PI):
		# Clockwise turn
		turn_180_blend = -1.0
		print("Turn Angle (radians): ", turn_angle, ", CLOCKWISE, Speed: ", smoothed_speed)
	elif turn_angle > (PI/2) and turn_angle <= PI:
		# Counter-clockwise turn
		turn_180_blend = 1.0
		print("Turn Angle (radians): ", turn_angle, ", COUNTER CLOCKWISE, Speed: ", smoothed_speed)
	
	if turn_180_blend != 0.0:
		trigger_180_turn(turn_180_blend, smoothed_speed, move_dir)
		return true
	
	return false


func trigger_180_turn(blend: float, speed: float, move_dir: Vector3) -> void:
	"""Trigger the appropriate 180 turn animation based on speed"""
	const RUN_180_THRESHOLD = 8.0
	const WALK_180_THRESHOLD = 1.0
	
	# Get the 180States nested state machine playback
	var turn_playback = animation_tree.get("parameters/180States/playback") as AnimationNodeStateMachinePlayback
	
	if speed >= RUN_180_THRESHOLD:
		animation_tree.set("parameters/180States/Run180/blend_position", blend)
		state_machine.travel("180States")
		if turn_playback:
			turn_playback.travel("Run180")
		print("-> Using RUN_180 animation")
	elif speed >= WALK_180_THRESHOLD:
		animation_tree.set("parameters/180States/Walk180/blend_position", blend)
		state_machine.travel("180States")
		if turn_playback:
			turn_playback.travel("Walk180")
		print("-> Using WALK_180 animation")
	else:
		# Idle turn variants
		if move_dir.length() > 0.7:
			animation_tree.set("parameters/180States/IdleRun180/blend_position", blend)
			state_machine.travel("180States")
			if turn_playback:
				turn_playback.travel("IdleRun180")
			print("-> Using IDLE_RUN_180 animation")
		elif move_dir.length() <= 0.7:
			animation_tree.set("parameters/180States/IdleWalk180/blend_position", blend)
			state_machine.travel("180States")
			if turn_playback:
				turn_playback.travel("IdleWalk180")
			print("-> Using IDLE_WALK_180 animation")


#endregion


#region Helper Functions

func signed_angle_between(forward: Vector3, move_dir: Vector3) -> float:
	"""Calculate signed angle between two vectors"""
	var dot = forward.dot(move_dir)
	var cross_y = forward.cross(move_dir).y
	return atan2(cross_y, dot)


#endregion


#region Animation Library Management

func swap_animation_library(anim_library: AnimationLibrary, weapon_type: String) -> void:
	"""Swap grounded movement animations to weapon-specific ones"""
	if is_using_weapon_anims:
		return
	
	# Get AnimationPlayer
	var anim_player = animation_tree.get_node(animation_tree.anim_player) as AnimationPlayer
	if not anim_player:
		return
	
	# Determine library name
	var library_name = _get_library_name_without_slash(weapon_type)
	
	# Add the weapon animation library to the AnimationPlayer
	if anim_player.has_animation_library(library_name):
		anim_player.remove_animation_library(library_name)
	
	anim_player.add_animation_library(library_name, anim_library)
	
	# Get the root state machine
	var root_state_machine = animation_tree.tree_root as AnimationNodeStateMachine
	if not root_state_machine:
		return
	
	# Get the Grounded BlendTree node
	var grounded_blend_tree = root_state_machine.get_node("Grounded") as AnimationNodeBlendTree
	if not grounded_blend_tree:
		return
	
	# Get the movement BlendSpace1D (parent of default_movement and walk_strafe)
	var movement_blend = grounded_blend_tree.get_node("movement") as AnimationNodeBlendSpace1D
	if not movement_blend:
		return
	
	# Get the default_movement BlendSpace1D (nested inside movement at position 0)
	var default_movement = movement_blend.get_blend_point_node(0) as AnimationNodeBlendSpace1D
	if not default_movement:
		return
	
	# Validate blend space setup
	print("[AnimController] Validating blend space setup:")
	print("  Blend point count: ", default_movement.get_blend_point_count())
	for i in range(default_movement.get_blend_point_count()):
		var pos = default_movement.get_blend_point_position(i)
		var node = default_movement.get_blend_point_node(i) as AnimationNodeAnimation
		if node:
			print("  Point ", i, " @ position ", pos, ": ", node.animation)
		else:
			print("  Point ", i, " @ position ", pos, ": NO NODE")
	
	# Warn about unexpected blend points
	if default_movement.get_blend_point_count() != 3:
		print("[AnimController] WARNING: Expected 3 blend points (at 0.0, 0.5, 1.0), found ", default_movement.get_blend_point_count())
		print("[AnimController] WARNING: Please fix your AnimationTree BlendSpace1D to have exactly 3 points!")
	
	# Determine weapon-specific animation names
	var weapon_prefix = _get_weapon_animation_prefix(weapon_type)
	var library_prefix = library_name + "/"
	
	var new_idle = library_prefix + weapon_prefix + "Idle"
	var new_walk = library_prefix + weapon_prefix + "WalkForward"
	var new_run = library_prefix + weapon_prefix + "RunForward"
	
	print("[AnimController] Swapping animations:")
	print("  Idle: ", new_idle)
	print("  Walk: ", new_walk)
	print("  Run: ", new_run)
	
	# List all available animations in the library
	print("[AnimController] Available animations in ", library_name, ":")
	for anim_name in anim_player.get_animation_list():
		if anim_name.begins_with(library_name):
			print("    ", anim_name)
	
	# Verify animations exist before swapping
	if not anim_player.has_animation(new_idle):
		print("[AnimController] WARNING: Animation not found: ", new_idle)
	if not anim_player.has_animation(new_walk):
		print("[AnimController] WARNING: Animation not found: ", new_walk)
	if not anim_player.has_animation(new_run):
		print("[AnimController] WARNING: Animation not found: ", new_run)
	
	# Swap each blend point's animation in default_movement
	# Find the correct blend points by position, not by index
	_swap_animation_by_position(default_movement, 0.0, new_idle)   # Idle at position 0.0
	_swap_animation_by_position(default_movement, 0.5, new_walk)   # Walk at position 0.5
	_swap_animation_by_position(default_movement, 1.0, new_run)    # Run at position 1.0
	
	# Get walk_strafe BlendSpace2D (nested inside movement at position 1)
	var walk_strafe = movement_blend.get_blend_point_node(1) as AnimationNodeBlendSpace2D
	if walk_strafe:
		# Swap strafe animations if weapon has them
		_swap_strafe_animations(walk_strafe, library_prefix + weapon_prefix)
		
		# Verify the animations were actually set
		print("[AnimController] Verifying strafe animations after swap:")
		for i in range(walk_strafe.get_blend_point_count()):
			var pos = walk_strafe.get_blend_point_position(i)
			var node = walk_strafe.get_blend_point_node(i) as AnimationNodeAnimation
			if node:
				print("  Point ", i, " @ ", pos, ": ", node.animation)
	else:
		print("[AnimController] ERROR: Could not get walk_strafe BlendSpace2D!")
	
	# Setup combat animations (sheathe/unsheathe in Combat state machine)
	_setup_combat_animations(root_state_machine, library_prefix + weapon_prefix)
	
	# Setup moving sheathe/unsheathe animations (oneshots in Grounded state for layering)
	_setup_grounded_sheathe_animations(grounded_blend_tree, library_prefix + weapon_prefix)
	
	is_using_weapon_anims = true


func restore_unarmed_animations() -> void:
	"""Restore original unarmed animations"""
	if not is_using_weapon_anims:
		return
	
	# Get AnimationPlayer
	var anim_player = animation_tree.get_node(animation_tree.anim_player) as AnimationPlayer
	if not anim_player:
		return
	
	# Remove all weapon animation libraries
	var libraries_to_remove = []
	for lib_name in anim_player.get_animation_library_list():
		if lib_name != "" and lib_name != "BaseUnarmedLibrary":  # Don't remove base library
			libraries_to_remove.append(lib_name)
	
	for lib_name in libraries_to_remove:
		anim_player.remove_animation_library(lib_name)
	
	# Get nodes (same process as swap_animation_library)
	var root_state_machine = animation_tree.tree_root as AnimationNodeStateMachine
	if not root_state_machine:
		return
	
	var grounded_blend_tree = root_state_machine.get_node("Grounded") as AnimationNodeBlendTree
	if not grounded_blend_tree:
		return
	
	# Get the movement BlendSpace1D
	var movement_blend = grounded_blend_tree.get_node("movement") as AnimationNodeBlendSpace1D
	if not movement_blend:
		return
	
	# Get the default_movement BlendSpace1D (nested inside movement at position 0)
	var default_movement = movement_blend.get_blend_point_node(0) as AnimationNodeBlendSpace1D
	if not default_movement:
		return
	
	# Restore original unarmed animations
	var base_lib_prefix = ""
	
	# Check if we need library prefix
	if anim_player:
		if anim_player.has_animation("BaseUnarmedLibrary/" + unarmed_idle_anim):
			base_lib_prefix = "BaseUnarmedLibrary/"
		elif anim_player.has_animation(unarmed_idle_anim):
			base_lib_prefix = ""
	
	var restore_idle = base_lib_prefix + unarmed_idle_anim
	var restore_walk = base_lib_prefix + unarmed_walk_anim
	var restore_run = base_lib_prefix + unarmed_run_anim
	
	print("[AnimController] Restoring unarmed animations:")
	print("  Idle: ", restore_idle)
	print("  Walk: ", restore_walk)
	print("  Run: ", restore_run)
	
	# Verify animations exist before restoring
	if not anim_player.has_animation(restore_idle):
		print("[AnimController] ERROR: Unarmed animation not found: ", restore_idle)
	if not anim_player.has_animation(restore_walk):
		print("[AnimController] ERROR: Unarmed animation not found: ", restore_walk)
	if not anim_player.has_animation(restore_run):
		print("[AnimController] ERROR: Unarmed animation not found: ", restore_run)
	
	_swap_animation_by_position(default_movement, 0.0, restore_idle)
	_swap_animation_by_position(default_movement, 0.5, restore_walk)
	_swap_animation_by_position(default_movement, 1.0, restore_run)
	
	# Restore unarmed strafe animations
	var walk_strafe = movement_blend.get_blend_point_node(1) as AnimationNodeBlendSpace2D
	if walk_strafe:
		_restore_strafe_animations(walk_strafe, base_lib_prefix)
		
		# Verify the animations were actually restored
		print("[AnimController] Verifying strafe animations after restore:")
		for i in range(walk_strafe.get_blend_point_count()):
			var pos = walk_strafe.get_blend_point_position(i)
			var node = walk_strafe.get_blend_point_node(i) as AnimationNodeAnimation
			if node:
				print("  Point ", i, " @ ", pos, ": ", node.animation)
	
	# Clear moving sheathe/unsheathe animations (oneshots in Grounded state)
	_clear_grounded_sheathe_animations(grounded_blend_tree)
	
	is_using_weapon_anims = false


func _swap_blend_point_animation(blend_space: AnimationNodeBlendSpace1D, point_index: int, new_anim_name: StringName) -> void:
	"""Helper to swap the animation at a specific blend point"""
	var anim_node = blend_space.get_blend_point_node(point_index) as AnimationNodeAnimation
	if anim_node:
		var old_anim = anim_node.animation
		anim_node.animation = new_anim_name
		print("[AnimController] Swapped blend point ", point_index, ": ", old_anim, " -> ", new_anim_name)
	else:
		print("[AnimController] ERROR: Could not get animation node at blend point ", point_index)


func _swap_animation_by_position(blend_space: AnimationNodeBlendSpace1D, target_position: float, new_anim_name: StringName) -> void:
	"""Find and swap animation at a specific blend position"""
	var closest_index = -1
	var closest_distance = 999999.0
	
	# Find the blend point closest to the target position
	for i in range(blend_space.get_blend_point_count()):
		var pos = blend_space.get_blend_point_position(i)
		var distance = abs(pos - target_position)
		if distance < closest_distance:
			closest_distance = distance
			closest_index = i
	
	if closest_index >= 0:
		var anim_node = blend_space.get_blend_point_node(closest_index) as AnimationNodeAnimation
		if anim_node:
			var old_anim = anim_node.animation
			var actual_pos = blend_space.get_blend_point_position(closest_index)
			anim_node.animation = new_anim_name
			print("[AnimController] Swapped blend point ", closest_index, " @ position ", actual_pos, ": ", old_anim, " -> ", new_anim_name)
		else:
			print("[AnimController] ERROR: Could not get animation node at blend point ", closest_index)
	else:
		print("[AnimController] ERROR: Could not find blend point near position ", target_position)


func _setup_combat_animations(root_state_machine: AnimationNodeStateMachine, weapon_prefix: String) -> void:
	"""Setup the sheathe/unsheathe animations in the Combat state machine"""
	# Get the Combat state machine
	var combat_state_machine = root_state_machine.get_node("Combat") as AnimationNodeStateMachine
	if not combat_state_machine:
		return
	
	# Get the SheatheUnsheathe nested state machine
	var sheathe_state_machine = combat_state_machine.get_node("SheatheUnsheathe") as AnimationNodeStateMachine
	if not sheathe_state_machine:
		return
	
	# Get and configure Unsheathe animation node
	var unsheathe_node = sheathe_state_machine.get_node("Unsheathe") as AnimationNodeAnimation
	if unsheathe_node:
		unsheathe_node.animation = weapon_prefix + "Unsheathe"
	
	# Get and configure Sheathe animation node
	var sheathe_node = sheathe_state_machine.get_node("Sheathe") as AnimationNodeAnimation
	if sheathe_node:
		sheathe_node.animation = weapon_prefix + "Sheathe"


func _setup_grounded_sheathe_animations(grounded_blend_tree: AnimationNodeBlendTree, weapon_prefix: String) -> void:
	"""Setup sheathe/unsheathe oneshot animations in Grounded state for moving arming/unarming.
	These are layered over walk/run animations."""
	print("[AnimController] ========= _setup_grounded_sheathe_animations called with weapon_prefix: ", weapon_prefix, " =========")
	
	# Configure unsheathe oneshot blend settings
	var unsheathe_oneshot = grounded_blend_tree.get_node("unsheathe") as AnimationNodeOneShot
	if unsheathe_oneshot:
		unsheathe_oneshot.fadein_time = 0.1  # Quick fade in
		unsheathe_oneshot.fadeout_time = 0.2  # Smooth fade out
		unsheathe_oneshot.autorestart = false
		unsheathe_oneshot.mix_mode = AnimationNodeOneShot.MIX_MODE_BLEND
		unsheathe_oneshot.fadein_curve = null  # Linear blend
		unsheathe_oneshot.fadeout_curve = null  # Linear blend
		
		# DISABLE filter - we want ALL tracks including call tracks to play
		#unsheathe_oneshot.filter_enabled = false
		
		print("[AnimController] Configured unsheathe oneshot: fade_in=0.1, fade_out=0.2, BLEND mode, filter disabled (all tracks enabled)")
	else:
		print("[AnimController] WARNING: unsheathe oneshot node not found")
	
	# Get the animation node for unsheathe (accessed separately from the blend tree)
	var unsheathe_anim = grounded_blend_tree.get_node("unsheathe_anim") as AnimationNodeAnimation
	if unsheathe_anim:
		var unsheathe_anim_name = weapon_prefix + "UnsheatheRunning"
		print("[AnimController]   Setting unsheathe_anim animation to: ", unsheathe_anim_name)
		unsheathe_anim.animation = unsheathe_anim_name
	else:
		print("[AnimController] WARNING: unsheathe_anim animation node not found in Grounded BlendTree")
	
	# Configure sheathe oneshot blend settings
	var sheathe_oneshot = grounded_blend_tree.get_node("sheathe") as AnimationNodeOneShot
	if sheathe_oneshot:
		sheathe_oneshot.fadein_time = 0.1  # Quick fade in
		sheathe_oneshot.fadeout_time = 0.2  # Smooth fade out
		sheathe_oneshot.autorestart = false
		sheathe_oneshot.mix_mode = AnimationNodeOneShot.MIX_MODE_BLEND
		sheathe_oneshot.fadein_curve = null  # Linear blend
		sheathe_oneshot.fadeout_curve = null  # Linear blend
		
		# DISABLE filter - we want ALL tracks including call tracks to play
		#sheathe_oneshot.filter_enabled = false
		
		print("[AnimController] Configured sheathe oneshot: fade_in=0.1, fade_out=0.2, BLEND mode, filter disabled (all tracks enabled)")
	else:
		print("[AnimController] WARNING: sheathe oneshot node not found")
	
	# Get the animation node for sheathe (accessed separately from the blend tree)
	var sheathe_anim = grounded_blend_tree.get_node("sheathe_anim") as AnimationNodeAnimation
	if sheathe_anim:
		var sheathe_anim_name = weapon_prefix + "SheatheRunning"
		print("[AnimController]   Setting sheathe_anim animation to: ", sheathe_anim_name)
		sheathe_anim.animation = sheathe_anim_name
	else:
		print("[AnimController] WARNING: sheathe_anim animation node not found in Grounded BlendTree")
	
	print("[AnimController] ========= _setup_grounded_sheathe_animations complete =========")



func _clear_grounded_sheathe_animations(grounded_blend_tree: AnimationNodeBlendTree) -> void:
	"""Leave sheathe/unsheathe oneshot animations set - they'll be inactive after library removal.
	Note: We don't clear these to avoid AnimationTree cache issues."""
	pass  # Intentionally empty - animation references stay set


func _swap_strafe_animations(walk_strafe: AnimationNodeBlendSpace2D, weapon_prefix: String) -> void:
	"""Swap strafe animations for weapon"""
	print("[AnimController] Swapping strafe animations with weapon_prefix: ", weapon_prefix)
	
	if not walk_strafe:
		print("[AnimController] ERROR: walk_strafe BlendSpace2D is null!")
		return
	
	var blend_point_count = walk_strafe.get_blend_point_count()
	print("[AnimController] BlendSpace2D has ", blend_point_count, " blend points")
	
	# Strafe animations: StrafeLeft, StrafeRight, StrafeBackward, WalkForward
	# Try to find weapon-specific strafe animations, fallback to base if not found
	var strafe_left = weapon_prefix + "StrafeWalkLeft"
	var strafe_right = weapon_prefix + "StrafeWalkRight"
	var strafe_back = weapon_prefix + "StrafeWalkBackward"
	var strafe_forward = weapon_prefix + "WalkForward"  # Use regular walk forward
	var strafe_idle = weapon_prefix + "Idle"  # Center point idle
	
	print("[AnimController] Target strafe animations:")
	print("  Left: ", strafe_left)
	print("  Right: ", strafe_right)
	print("  Back: ", strafe_back)
	print("  Forward: ", strafe_forward)
	print("  Idle: ", strafe_idle)
	
	# Get animation points in BlendSpace2D and swap them
	for i in range(blend_point_count):
		var pos = walk_strafe.get_blend_point_position(i)
		print("[AnimController] Strafe blend point ", i, " position: ", pos)
		
		var node = walk_strafe.get_blend_point_node(i) as AnimationNodeAnimation
		if not node:
			print("[AnimController] ERROR: Strafe blend point ", i, " is not an AnimationNodeAnimation!")
			continue
		
		var old_anim = node.animation
		print("[AnimController] Strafe blend point ", i, " current animation: ", old_anim)
		
		# Determine which strafe animation based on position
		# Check which axis has the larger absolute value to determine direction
		if abs(pos.x) > abs(pos.y):
			# Horizontal movement (left/right)
			if pos.x < 0:  # Left
				node.animation = strafe_left
				print("[AnimController] Strafe point ", i, " @ ", pos, " (LEFT): ", old_anim, " -> ", strafe_left)
			else:  # Right
				node.animation = strafe_right
				print("[AnimController] Strafe point ", i, " @ ", pos, " (RIGHT): ", old_anim, " -> ", strafe_right)
		elif abs(pos.y) > 0.01:
			# Vertical movement (forward/back)
			if pos.y < 0:  # Backward
				node.animation = strafe_back
				print("[AnimController] Strafe point ", i, " @ ", pos, " (BACK): ", old_anim, " -> ", strafe_back)
			else:  # Forward
				node.animation = strafe_forward
				print("[AnimController] Strafe point ", i, " @ ", pos, " (FWD): ", old_anim, " -> ", strafe_forward)
		else:
			# Center point (0, 0) - idle animation during lock-on strafe
			node.animation = strafe_idle
			print("[AnimController] Strafe point ", i, " @ ", pos, " (CENTER/IDLE): ", old_anim, " -> ", strafe_idle)


func _restore_strafe_animations(walk_strafe: AnimationNodeBlendSpace2D, base_prefix: String) -> void:
	"""Restore unarmed strafe animations"""
	print("[AnimController] Restoring unarmed strafe animations with base_prefix: ", base_prefix)
	
	# Restore base unarmed strafe animations
	for i in range(walk_strafe.get_blend_point_count()):
		var pos = walk_strafe.get_blend_point_position(i)
		var node = walk_strafe.get_blend_point_node(i) as AnimationNodeAnimation
		if not node:
			continue
		
		var old_anim = node.animation
		
		# Determine which strafe animation based on position
		# Check which axis has the larger absolute value to determine direction
		if abs(pos.x) > abs(pos.y):
			# Horizontal movement (left/right)
			if pos.x < 0:  # Left
				node.animation = base_prefix + "StrafeWalkLeft"
				print("[AnimController] Strafe point ", i, " @ ", pos, " (LEFT): ", old_anim, " -> ", base_prefix + "StrafeWalkLeft")
			else:  # Right
				node.animation = base_prefix + "StrafeWalkRight"
				print("[AnimController] Strafe point ", i, " @ ", pos, " (RIGHT): ", old_anim, " -> ", base_prefix + "StrafeWalkRight")
		elif abs(pos.y) > 0.01:
			# Vertical movement (forward/back)
			if pos.y < 0:  # Backward
				node.animation = base_prefix + "StrafeWalkBackward"
				print("[AnimController] Strafe point ", i, " @ ", pos, " (BACK): ", old_anim, " -> ", base_prefix + "StrafeWalkBackward")
			else:  # Forward
				node.animation = base_prefix + "WalkForward"
				print("[AnimController] Strafe point ", i, " @ ", pos, " (FWD): ", old_anim, " -> ", base_prefix + "WalkForward")
		else:
			# Center point (0, 0) - idle animation
			node.animation = base_prefix + "Idle"
			print("[AnimController] Strafe point ", i, " @ ", pos, " (CENTER/IDLE): ", old_anim, " -> ", base_prefix + "Idle")


func _get_weapon_animation_prefix(weapon_type: String) -> String:
	"""Get the animation prefix for a weapon type"""
	# Map weapon types to animation prefixes
	match weapon_type.to_lower():
		"katana":
			return "Katana"
		"greatsword":
			return "Greatsword"
		"spear":
			return "Spear"
		_:
			return "Katana"


func _get_library_name(weapon_type: String) -> String:
	"""Get the animation library name for a weapon type (with trailing slash)"""
	# Map weapon types to their animation library names
	match weapon_type.to_lower():
		"katana":
			return "KatanaAnimLibrary/"
		"greatsword":
			return "GreatswordAnimLibrary/"
		"spear":
			return "SpearAnimLibrary/"
		_:
			return "KatanaAnimLibrary/"


func _get_library_name_without_slash(weapon_type: String) -> String:
	"""Get the animation library name for a weapon type (without trailing slash for add_animation_library)"""
	# Map weapon types to their animation library names
	match weapon_type.to_lower():
		"katana":
			return "KatanaAnimLibrary"
		"greatsword":
			return "GreatswordAnimLibrary"
		"spear":
			return "SpearAnimLibrary"
		_:
			return "KatanaAnimLibrary"


func _verify_animations_exist(anim_names: Array) -> bool:
	"""Check if animations exist in the AnimationPlayer"""
	var anim_player = animation_tree.get_node(animation_tree.anim_player) as AnimationPlayer
	if not anim_player:
		return false
	
	for anim_name in anim_names:
		if not anim_player.has_animation(anim_name):
			return false
	
	return true


#endregion
