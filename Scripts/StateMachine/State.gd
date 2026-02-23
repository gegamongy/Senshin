extends Node
class_name State

## Base class for all state machine states
## Each state handles its own logic and determines when to transition

signal transition_requested(new_state_name: String)

var state_machine: StateMachine
var animation_controller: PlayerAnimationController


func _ready():
	pass


func enter() -> void:
	"""Called when entering this state"""
	pass


func exit() -> void:
	"""Called when exiting this state"""
	pass


func physics_update(delta: float) -> void:
	"""Called every physics frame while in this state"""
	pass


func handle_input(event: InputEvent) -> void:
	"""Called for input events while in this state"""
	pass


func request_transition(new_state_name: String) -> void:
	"""Request a transition to another state"""
	transition_requested.emit(new_state_name)
