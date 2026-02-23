extends Node
class_name PlayerAnimationController

## Manages direct animation playback and root motion - no automatic transitions

var animation_tree: AnimationTree
var state_machine: AnimationNodeStateMachinePlayback
var character_body: CharacterBody3D
var locomotion: PlayerLocomotionComponent

var original_root_motion_track: NodePath


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
	var anim_name = "JumpStartFWD" if direction > 0 else "JumpStartBWD"
	
	if anim_player.has_animation(anim_name):
		return anim_player.get_animation(anim_name).length
	
	return 0.5  # Fallback


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
