extends State
class_name FallingState

## State when player is falling (not from a jump, e.g., walked off a ledge)

var locomotion: PlayerLocomotionComponent
var player: CharacterBody3D


func enter() -> void:
	print("[FallingState] Entered")
	# Play midair animation
	animation_controller.play_jump_midair()


func physics_update(delta: float) -> void:
	# Check if we've landed
	if player.is_on_floor():
		request_transition("Landing")
		return


func exit() -> void:
	pass
