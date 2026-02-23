extends State
class_name SheatheState

## State when player is sheathing/unarming their weapon

var locomotion: PlayerLocomotionComponent
var player: CharacterBody3D
var combat_component: PlayerCombatComponent
var time_elapsed: float = 0.0
var animation_duration: float = 1.0  # Will be set based on actual animation


func enter() -> void:
	print("[SheatheState] Entered - playing sheathe animation")
	time_elapsed = 0.0
	
	# Get the actual animation duration
	animation_duration = animation_controller.get_sheathe_duration()
	
	# Play sheathe animation
	animation_controller.play_sheathe()


func physics_update(delta: float) -> void:
	time_elapsed += delta
	
	# Wait for animation to complete
	if time_elapsed >= animation_duration:
		print("[SheatheState] Sheathe complete")
		
		# Unarm the weapon (this restores unarmed animations)
		if combat_component:
			combat_component.unarm_weapon()
		
		# Transition to grounded state
		if locomotion.get_input_magnitude() > 0.1:
			request_transition("GroundedMoving")
		else:
			request_transition("GroundedIdle")


func exit() -> void:
	pass
