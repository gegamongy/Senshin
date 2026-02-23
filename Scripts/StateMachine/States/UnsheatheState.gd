extends State
class_name UnsheatheState

## State when player is unsheathing/arming their weapon

var locomotion: PlayerLocomotionComponent
var player: CharacterBody3D
var combat_component: PlayerCombatComponent
var time_elapsed: float = 0.0
var animation_duration: float = 1.0  # Will be set based on actual animation


func enter() -> void:
	print("[UnsheatheState] Entered - playing unsheathe animation")
	time_elapsed = 0.0
	
	# Get the actual animation duration
	animation_duration = animation_controller.get_unsheathe_duration()
	
	# Play unsheathe animation
	animation_controller.play_unsheathe()


func physics_update(delta: float) -> void:
	time_elapsed += delta
	
	# Wait for animation to complete
	if time_elapsed >= animation_duration:
		print("[UnsheatheState] Unsheathe complete, transitioning to grounded state")
		
		# Check if player has movement input to decide next state
		if locomotion.get_input_magnitude() > 0.1:
			request_transition("GroundedMoving")
		else:
			request_transition("GroundedIdle")


func exit() -> void:
	pass
