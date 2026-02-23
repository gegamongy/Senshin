extends Node
class_name StateMachine

## Manages state transitions and delegates behavior to the current state

@export var initial_state: String = "Idle"

var states: Dictionary = {}
var current_state: State = null
var previous_state: State = null


func _ready():
	# Initialize after children are ready
	call_deferred("_initialize_states")


func _initialize_states():
	"""Initialize all child states"""
	for child in get_children():
		if child is State:
			states[child.name] = child
			child.state_machine = self
			child.transition_requested.connect(_on_transition_requested)
	
	# Enter initial state
	if states.has(initial_state):
		change_state(initial_state)
	else:
		push_error("Initial state '" + initial_state + "' not found in state machine!")


func physics_update(delta: float) -> void:
	"""Process current state"""
	if current_state:
		current_state.physics_update(delta)


func handle_input(event: InputEvent) -> void:
	"""Pass input to current state"""
	if current_state:
		current_state.handle_input(event)


func change_state(new_state_name: String) -> void:
	"""Transition to a new state"""
	if not states.has(new_state_name):
		push_error("State '" + new_state_name + "' does not exist!")
		return
	
	# Exit current state
	if current_state:
		current_state.exit()
		previous_state = current_state
	
	# Enter new state
	current_state = states[new_state_name]
	current_state.enter()
	
	print("[StateMachine] Transitioned to: ", new_state_name)


func _on_transition_requested(new_state_name: String) -> void:
	"""Handle transition request from a state"""
	change_state(new_state_name)


func get_current_state_name() -> String:
	"""Get the name of the current state"""
	if current_state:
		return current_state.name
	return ""


func get_previous_state_name() -> String:
	"""Get the name of the previous state"""
	if previous_state:
		return previous_state.name
	return ""
