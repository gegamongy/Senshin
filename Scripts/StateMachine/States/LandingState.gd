extends State
class_name LandingState

## State when player lands on the ground after being airborne

var locomotion: PlayerLocomotionComponent
var player: CharacterBody3D
var landing_timer: float = 0.0
const MIN_LANDING_DURATION: float = 0.1  # Minimum time in landing state
var has_movement: bool = false


func enter() -> void:
	print("[LandingState] Entered")
	landing_timer = 0.0
	
	# Check if player has movement input
	has_movement = locomotion.get_input_magnitude() > 0.3
	
	if has_movement:
		# Skip landing animation, go straight to movement
		print("[LandingState] Has movement, skipping land animation")
	else:
		# Play landing animation
		animation_controller.play_jump_land()


func physics_update(delta: float) -> void:
	# Safety check: make sure we're still grounded
	if not player.is_on_floor():
		request_transition("Falling")
		return
	
	landing_timer += delta
	
	# Quick exit if we have movement
	if has_movement and landing_timer >= 0.05:
		request_transition("GroundedMoving")
		return
	
	# Standard landing duration check
	if landing_timer >= MIN_LANDING_DURATION:
		# Check what to do next based on input
		if locomotion.get_input_magnitude() > 0.01:
			request_transition("GroundedMoving")
		else:
			request_transition("GroundedIdle")
		return


func exit() -> void:
	pass
