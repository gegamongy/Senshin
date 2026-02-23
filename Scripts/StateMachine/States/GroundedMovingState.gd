extends State
class_name GroundedMovingState

## State when player is on the ground and moving

var locomotion: PlayerLocomotionComponent
var player: CharacterBody3D
var turn_check_enabled: bool = true


func enter() -> void:
	print("[GroundedMovingState] Entered")
	turn_check_enabled = true
	# Animation will be handled by blend space based on input magnitude
	animation_controller.play_grounded_movement()


func physics_update(delta: float) -> void:
	# Check if movement stopped
	if locomotion.get_input_magnitude() <= 0.01:
		request_transition("GroundedIdle")
		return
	
	# Check if we've left the ground
	if not player.is_on_floor():
		request_transition("Falling")
		return
	
	# Check for 180 degree turns
	if turn_check_enabled:
		var move_dir = locomotion.get_move_dir()
		if move_dir.length() > 0.01:
			var should_turn = animation_controller.check_for_180_turn(move_dir)
			if should_turn:
				request_transition("Turning180")
				return


func exit() -> void:
	pass
