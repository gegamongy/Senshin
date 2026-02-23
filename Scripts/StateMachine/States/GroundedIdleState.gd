extends State
class_name GroundedIdleState

## State when player is on the ground with no movement input

var locomotion: PlayerLocomotionComponent
var player: CharacterBody3D


func enter() -> void:
	print("[GroundedIdleState] Entered")
	# Play grounded movement (idle will show at blend position 0)
	animation_controller.play_grounded_movement()


func physics_update(delta: float) -> void:
	# Check for movement input
	if locomotion.get_input_magnitude() > 0.01:
		request_transition("GroundedMoving")
		return
	
	# Check if we've left the ground
	if not player.is_on_floor():
		request_transition("Falling")
		return


func exit() -> void:
	pass
