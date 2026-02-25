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
	animation_tree.set("parameters/Grounded/move/blend_position", locomotion.get_input_magnitude())


#region Direct Animation Playback

func play_animation(anim_name: String) -> void:
	"""Directly play an animation state"""
	state_machine.travel(anim_name)


func play_grounded_movement() -> void:
	"""Play the grounded movement blend space"""
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
	# Wait one frame to ensure deferred animation assignments have completed
	await animation_tree.get_tree().process_frame
	
	# Make sure we're in Grounded state
	if state_machine.get_current_node() != "Grounded":
		state_machine.travel("Grounded")
	
	# Check oneshot state and abort if still active
	var oneshot_path = "parameters/Grounded/unsheathe/request"
	var oneshot_active_path = "parameters/Grounded/unsheathe/active"
	var is_active = animation_tree.get(oneshot_active_path)
	
	if is_active:
		animation_tree.set(oneshot_path, AnimationNodeOneShot.ONE_SHOT_REQUEST_ABORT)
		await animation_tree.get_tree().process_frame
	
	# Trigger oneshot in Grounded BlendTree
	animation_tree.set(oneshot_path, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


func play_sheathe_moving() -> void:
	"""Play sheathe animation while moving (oneshot layered over locomotion)"""
	# Make sure we're in Grounded state
	if state_machine.get_current_node() != "Grounded":
		state_machine.travel("Grounded")
	
	# Check oneshot state and abort if still active
	var oneshot_path = "parameters/Grounded/sheathe/request"
	var oneshot_active_path = "parameters/Grounded/sheathe/active"
	var is_active = animation_tree.get(oneshot_active_path)
	
	if is_active:
		animation_tree.set(oneshot_path, AnimationNodeOneShot.ONE_SHOT_REQUEST_ABORT)
		await animation_tree.get_tree().process_frame
	
	# Trigger oneshot in Grounded BlendTree
	animation_tree.set(oneshot_path, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


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


#endregion


#region Root Motion Application

func apply_root_motion(delta: float) -> void:
	"""Apply root motion from animations to the character"""
	if not locomotion.get_is_grounded():
		return
	
	var capped_delta = min(delta, 1.0 / 30.0)
	var root_motion = animation_tree.get_root_motion_position()
	var root_motion_velocity = character_body.global_transform.basis * (root_motion / capped_delta)
	
	# During 180 turns, apply both position and rotation
	if locomotion.get_is_turning_180():
		var root_motion_rotation = animation_tree.get_root_motion_rotation()
		var euler = root_motion_rotation.get_euler(EULER_ORDER_YXZ)
		locomotion.apply_root_motion_rotation(-euler.z)
		character_body.velocity.x = root_motion_velocity.x
		character_body.velocity.z = root_motion_velocity.z
	else:
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


#endregion


#region 180 Turn Detection and Playback

func check_for_180_turn(move_dir: Vector3) -> bool:
	"""Check if player should perform 180 turn and trigger animation. Returns true if turn started."""
	if not locomotion.get_is_grounded() or locomotion.get_is_turning_180():
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
	
	# Get the move BlendSpace1D node
	var move_blend_space = grounded_blend_tree.get_node("move") as AnimationNodeBlendSpace1D
	if not move_blend_space:
		return
	
	# Determine weapon-specific animation names
	var weapon_prefix = _get_weapon_animation_prefix(weapon_type)
	var library_prefix = library_name + "/"
	
	var new_idle = library_prefix + weapon_prefix + "Idle"
	var new_walk = library_prefix + weapon_prefix + "WalkForward"
	var new_run = library_prefix + weapon_prefix + "RunForward"
	
	# Swap each blend point's animation
	_swap_blend_point_animation(move_blend_space, 0, new_idle)   # Idle at position 0.0
	_swap_blend_point_animation(move_blend_space, 1, new_walk)   # Walk at position 0.5
	_swap_blend_point_animation(move_blend_space, 2, new_run)    # Run at position 1.0
	
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
	
	var move_blend_space = grounded_blend_tree.get_node("move") as AnimationNodeBlendSpace1D
	if not move_blend_space:
		return
	
	# Restore original unarmed animations
	var base_lib_prefix = ""
	
	# Check if we need library prefix
	if anim_player:
		if anim_player.has_animation("BaseUnarmedLibrary/" + unarmed_idle_anim):
			base_lib_prefix = "BaseUnarmedLibrary/"
		elif anim_player.has_animation(unarmed_idle_anim):
			base_lib_prefix = ""
	
	_swap_blend_point_animation(move_blend_space, 0, base_lib_prefix + unarmed_idle_anim)
	_swap_blend_point_animation(move_blend_space, 1, base_lib_prefix + unarmed_walk_anim)
	_swap_blend_point_animation(move_blend_space, 2, base_lib_prefix + unarmed_run_anim)
	
	# Clear moving sheathe/unsheathe animations (oneshots in Grounded state)
	_clear_grounded_sheathe_animations(grounded_blend_tree)
	
	is_using_weapon_anims = false


func _swap_blend_point_animation(blend_space: AnimationNodeBlendSpace1D, point_index: int, new_anim_name: StringName) -> void:
	"""Helper to swap the animation at a specific blend point"""
	var anim_node = blend_space.get_blend_point_node(point_index) as AnimationNodeAnimation
	if anim_node:
		anim_node.animation = new_anim_name


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
	
	# Get unsheathe oneshot node - use Running version for moving
	var unsheathe_oneshot = grounded_blend_tree.get_node("unsheathe_anim") as AnimationNodeAnimation
	if unsheathe_oneshot:
		var unsheathe_anim = weapon_prefix + "UnsheatheRunning"
		print("[AnimController]   Found unsheathe_anim node, setting animation to: ", unsheathe_anim)
		# Use set_deferred to ensure AnimationTree processes the change properly
		unsheathe_oneshot.set_deferred("animation", unsheathe_anim)
		print("[AnimController]   Deferred set for unsheathe_anim to: ", unsheathe_anim)
	else:
		print("[AnimController] WARNING: unsheathe_anim oneshot node not found in Grounded BlendTree")
	
	# Get sheathe oneshot node - use Running version for moving
	var sheathe_oneshot = grounded_blend_tree.get_node("sheathe_anim") as AnimationNodeAnimation
	if sheathe_oneshot:
		var sheathe_anim = weapon_prefix + "SheatheRunning"
		print("[AnimController]   Found sheathe_anim node, setting animation to: ", sheathe_anim)
		# Use set_deferred to ensure AnimationTree processes the change properly
		sheathe_oneshot.set_deferred("animation", sheathe_anim)
		print("[AnimController]   Deferred set for sheathe_anim to: ", sheathe_anim)
	else:
		print("[AnimController] WARNING: sheathe_anim oneshot node not found in Grounded BlendTree")
	print("[AnimController] ========= _setup_grounded_sheathe_animations complete =========")


func _clear_grounded_sheathe_animations(grounded_blend_tree: AnimationNodeBlendTree) -> void:
	"""Leave sheathe/unsheathe oneshot animations set - they'll be inactive after library removal.
	Note: We don't clear these to avoid AnimationTree cache issues."""
	pass  # Intentionally empty - animation references stay set


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
