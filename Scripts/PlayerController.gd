extends CharacterBody3D

## Main player controller - orchestrates all player components
## Acts as the "brain" coordinating input, locomotion, combat, animation, and camera

@onready var camera_pivot: Node3D = get_node("CameraPivot")
@onready var camera: Camera3D = get_node("CameraPivot/Camera3D")
@onready var animation_tree: AnimationTree = get_node("AnimationTree")

# Components
var input_component: PlayerInputComponent
var locomotion_component: PlayerLocomotionComponent
var combat_component: PlayerCombatComponent
var animation_controller: PlayerAnimationController
var camera_controller: CameraController
var player_state_machine: StateMachine

# Pickup tracking
var nearby_pickups: Array[WeaponBase] = []


func _ready():
	# Add player to group for pickup detection
	add_to_group("player")
	
	# Initialize all components
	setup_components()


func setup_components():
	"""Create and initialize all player components"""
	# Create components
	input_component = PlayerInputComponent.new()
	locomotion_component = PlayerLocomotionComponent.new()
	combat_component = PlayerCombatComponent.new()
	animation_controller = PlayerAnimationController.new()
	camera_controller = CameraController.new()
	
	# Add as children
	add_child(input_component)
	add_child(locomotion_component)
	add_child(combat_component)
	add_child(animation_controller)
	add_child(camera_controller)
	
	# Initialize components with required references
	locomotion_component.initialize(self)
	combat_component.initialize()
	animation_controller.initialize(animation_tree, self, locomotion_component)
	camera_controller.initialize(camera_pivot, camera, self, input_component)
	
	# Setup state machine
	setup_state_machine()
	
	# Connect input signals
	input_component.jump_pressed.connect(_on_jump_pressed)
	input_component.jump_released.connect(_on_jump_released)
	input_component.pickup_pressed.connect(_on_pickup_pressed)
	input_component.inventory_toggled.connect(_on_inventory_toggled)


func setup_state_machine():
	"""Create and configure the player state machine"""
	player_state_machine = StateMachine.new()
	player_state_machine.name = "PlayerStateMachine"
	player_state_machine.initial_state = "GroundedIdle"
	add_child(player_state_machine)
	
	# Create locomotion states
	var grounded_idle = GroundedIdleState.new()
	grounded_idle.name = "GroundedIdle"
	grounded_idle.locomotion = locomotion_component
	grounded_idle.player = self
	grounded_idle.animation_controller = animation_controller
	player_state_machine.add_child(grounded_idle)
	
	var grounded_moving = GroundedMovingState.new()
	grounded_moving.name = "GroundedMoving"
	grounded_moving.locomotion = locomotion_component
	grounded_moving.player = self
	grounded_moving.animation_controller = animation_controller
	player_state_machine.add_child(grounded_moving)
	
	var turning_180 = Turning180State.new()
	turning_180.name = "Turning180"
	turning_180.locomotion = locomotion_component
	turning_180.player = self
	turning_180.animation_controller = animation_controller
	player_state_machine.add_child(turning_180)
	
	var jumping = JumpingState.new()
	jumping.name = "Jumping"
	jumping.locomotion = locomotion_component
	jumping.player = self
	jumping.animation_controller = animation_controller
	player_state_machine.add_child(jumping)
	
	var falling = FallingState.new()
	falling.name = "Falling"
	falling.locomotion = locomotion_component
	falling.player = self
	falling.animation_controller = animation_controller
	player_state_machine.add_child(falling)
	
	var landing = LandingState.new()
	landing.name = "Landing"
	landing.locomotion = locomotion_component
	landing.player = self
	landing.animation_controller = animation_controller
	player_state_machine.add_child(landing)


func _input(event):
	"""Process input events"""
	# Block all player input when inventory is open (except inventory toggle)
	if InventoryManager.is_open:
		if event.is_action_pressed("inventory"):
			InventoryManager.toggle_inventory()
		return
	
	# Pass input to input component
	input_component.process_input(event)
	
	# Pass input to state machine
	player_state_machine.handle_input(event)


func _physics_process(delta):
	"""Main physics loop - coordinates all components"""
	# Update camera yaw for locomotion calculations
	locomotion_component.set_camera_yaw(camera_controller.get_camera_yaw())
	
	# Process gamepad look input
	input_component.process_gamepad_look(delta)
	
	# Process locomotion (movement, gravity, jumping)
	var input_dir = input_component.get_input_direction()
	var crouch_input = input_component.is_crouching()
	locomotion_component.process_locomotion(input_dir, crouch_input, delta)
	
	# Process combat (placeholder for now)
	combat_component.process_combat(delta)
	
	# Process state machine (handles animation state transitions)
	player_state_machine.physics_update(delta)
	
	# Process animations (root motion, blend parameters)
	animation_controller.process_animation(delta)
	
	# Move character body
	move_and_slide()
	
	# Update camera position and rotation
	camera_controller.process_camera(delta)




#region Input Signal Handlers

func _on_jump_pressed():
	"""Handle jump button press"""
	if locomotion_component.get_is_grounded():
		var input_dir = input_component.get_input_direction()
		locomotion_component.apply_jump(input_dir)
		# Transition to jumping state
		player_state_machine.change_state("Jumping")


func _on_jump_released():
	"""Handle jump button release for jump cutting"""
	locomotion_component.cut_jump()


func _on_pickup_pressed():
	"""Handle pickup button press"""
	try_pickup()


func _on_inventory_toggled():
	"""Handle inventory toggle"""
	InventoryManager.toggle_inventory()


#endregion


#region Pickup System

func try_pickup():
	"""Try to pick up the nearest item in range"""
	print("Try pickup called, nearby items: ", nearby_pickups.size())
	if nearby_pickups.size() > 0:
		var nearest_pickup = nearby_pickups[0]
		if nearest_pickup and is_instance_valid(nearest_pickup):
			print("Attempting to pick up item")
			nearest_pickup.pickup()
	else:
		print("No nearby pickups")


func register_pickup(pickup: WeaponBase):
	"""Register a pickup as nearby"""
	if not nearby_pickups.has(pickup):
		nearby_pickups.append(pickup)
		print("Registered pickup: ", pickup.name, " Total nearby: ", nearby_pickups.size())


func unregister_pickup(pickup: WeaponBase):
	"""Unregister a pickup"""
	nearby_pickups.erase(pickup)
	print("Unregistered pickup: ", pickup.name, " Total nearby: ", nearby_pickups.size())


#endregion


#region Player Control Management

func disable_player_control():
	"""Disable player movement and input (e.g., when opening inventory)"""
	velocity = Vector3.ZERO
	input_component.clear_input()


func enable_player_control():
	"""Re-enable player control"""
	# Input will automatically resume on next frame
	pass


#endregion
