extends State
class_name JumpingState

## State when player has jumped and is in the air

var locomotion: PlayerLocomotionComponent
var player: CharacterBody3D
var jump_start_finished: bool = false
var time_since_start: float = 0.0
var jump_start_duration: float = 0.5  # Will be set based on actual animation length


func enter() -> void:
	print("[JumpingState] Entered")
	jump_start_finished = false
	time_since_start = 0.0
	
	# Start jump animation (forward or backward based on jump direction)
	var jump_dir = locomotion.get_jump_direction()
	animation_controller.play_jump_start(jump_dir)
	
	# Get the actual animation duration based on direction
	jump_start_duration = animation_controller.get_jump_start_duration(jump_dir)
	print("[JumpingState] Playing JumpStart with direction: ", jump_dir, " | Duration: ", jump_start_duration)


func physics_update(delta: float) -> void:
	time_since_start += delta
	
	# After JumpStart duration, transition to midair
	if not jump_start_finished and time_since_start >= jump_start_duration:
		print("[JumpingState] JumpStart duration elapsed, transitioning to midair")
		animation_controller.play_jump_midair()
		jump_start_finished = true
	
	# Check if we've landed - but only after JumpStart has finished
	if jump_start_finished and player.is_on_floor():
		print("[JumpingState] Detected landing, transitioning to Landing state")
		request_transition("Landing")
		return


func exit() -> void:
	pass
