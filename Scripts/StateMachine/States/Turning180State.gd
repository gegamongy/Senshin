extends State
class_name Turning180State

## State when player is performing a 180 degree turn animation

var locomotion: PlayerLocomotionComponent
var player: CharacterBody3D
var turn_timer: float = 0.0
const MIN_TURN_DURATION: float = 0.3  # Minimum time for a 180 turn


func enter() -> void:
	print("[Turning180State] Entered")
	locomotion.set_is_turning_180(true)
	turn_timer = 0.0


func physics_update(delta: float) -> void:
	turn_timer += delta
	
	# Check if the turn animation has played for minimum duration
	if turn_timer >= MIN_TURN_DURATION:
		# Turn complete, transition back to moving
		request_transition("GroundedMoving")
		return
	
	# Safety check: if we left the ground during turn (shouldn't happen but...)
	if not player.is_on_floor():
		request_transition("Falling")
		return


func exit() -> void:
	locomotion.set_is_turning_180(false)
