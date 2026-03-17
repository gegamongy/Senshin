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
var lock_on_component: PlayerLockOnComponent
var player_state_machine: StateMachine

# Pickup tracking
var nearby_pickups: Array[WeaponBase] = []

# Sheathe/unsheathe state
var is_sheathe_action_in_progress: bool = false
var pending_delayed_operation: bool = false  # Track if there's a delayed unarm/unsheathe in progress


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
	lock_on_component = PlayerLockOnComponent.new()
	
	# Add as children
	add_child(input_component)
	add_child(locomotion_component)
	add_child(combat_component)
	add_child(animation_controller)
	add_child(camera_controller)
	add_child(lock_on_component)
	
	# Initialize components with required references
	locomotion_component.initialize(self)
	animation_controller.initialize(animation_tree, self, locomotion_component)
	combat_component.initialize(animation_controller)
	camera_controller.initialize(camera_pivot, camera, self, input_component)
	lock_on_component.initialize(self, camera)
	
	# Setup state machine
	setup_state_machine()
	
	# Connect input signals
	input_component.jump_pressed.connect(_on_jump_pressed)
	input_component.jump_released.connect(_on_jump_released)
	input_component.pickup_pressed.connect(_on_pickup_pressed)
	input_component.inventory_toggled.connect(_on_inventory_toggled)
	input_component.sheathe_unsheathe_pressed.connect(_on_sheathe_unsheathe_pressed)
	input_component.lock_on_toggled.connect(_on_lock_on_toggled)
	input_component.light_attack_pressed.connect(_on_light_attack_pressed)
	
	# Connect lock-on signals
	lock_on_component.lock_on_acquired.connect(_on_lock_on_acquired)
	lock_on_component.lock_on_lost.connect(_on_lock_on_lost)


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
	
	# Create combat states
	var unsheathe = UnsheatheState.new()
	unsheathe.name = "Unsheathe"
	unsheathe.locomotion = locomotion_component
	unsheathe.player = self
	unsheathe.animation_controller = animation_controller
	unsheathe.combat_component = combat_component
	player_state_machine.add_child(unsheathe)
	
	var sheathe = SheatheState.new()
	sheathe.name = "Sheathe"
	sheathe.locomotion = locomotion_component
	sheathe.player = self
	sheathe.animation_controller = animation_controller
	sheathe.combat_component = combat_component
	player_state_machine.add_child(sheathe)


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
	
	# Update lock-on state
	lock_on_component.update_lock_on(delta)
	
	# Orient character based on strafe direction when strafing
	if lock_on_component.is_target_locked() and locomotion_component.is_strafing:
		var strafe_blend = animation_controller.get_strafe_blend()
		
		if strafe_blend.length() > 0.01:
			# Get camera yaw
			var camera_yaw = camera_controller.get_camera_yaw()
			
			# Calculate target rotation based on strafe direction
			# strafe_blend.x = right/left, strafe_blend.y = forward/back
			# Use atan2 to smoothly handle all directions including diagonals
			var strafe_angle = atan2(-strafe_blend.x, abs(strafe_blend.y))  # Left/right strafing affects angle, forward/back does not
				# Note: we negate strafe_blend.x because right input should rotate character to the right (positive angle)
			
			# Combine camera yaw with strafe angle
			# Camera faces the direction, character rotates based on strafe
			var target_rotation = camera_yaw + strafe_angle
			
			# Smoothly rotate character
			rotation.y = lerp_angle(rotation.y, target_rotation, 15.0 * delta)
	
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


func _on_sheathe_unsheathe_pressed():
	"""Handle sheathe/unsheathe button press"""
	# Prevent spam - don't allow new action if one is already in progress
	if is_sheathe_action_in_progress:
		print("[Sheathe] BLOCKED: Action already in progress")
		return
	
	# Check if player is grounded and not in middle of action
	if not locomotion_component.get_is_grounded():
		return
	
	# Check current state - only allow from idle or moving states
	var current_state = player_state_machine.get_current_state_name()
	if current_state not in ["GroundedIdle", "GroundedMoving"]:
		return
	
	# Check if player is moving RIGHT NOW - this determines our path
	var has_motion = locomotion_component.get_input_magnitude() > 0.1
	print("[Sheathe] has_motion: ", has_motion, " | is_armed: ", combat_component.is_armed)
	
	# Cancel any pending delayed operations from previous toggle
	if pending_delayed_operation:
		print("[Sheathe] Cancelling previous delayed operation")
		pending_delayed_operation = false
	
	is_sheathe_action_in_progress = true
	
	if combat_component.is_armed:
		# === UNARMING ===
		if has_motion:
			# Continue grounded state, fire sheathe oneshot
			print("[Sheathe] → Unarming with motion (oneshot)")
			animation_controller.play_sheathe_moving()
			
			# Start async task to swap animations after oneshot completes
			_delayed_unarm_weapon()
			
			# Clear flag immediately so player can move
			is_sheathe_action_in_progress = false
		else:
			# Stop and travel to Combat->Sheathe state
			print("[Sheathe] → Unarming idle (state transition)")
			player_state_machine.change_state("Sheathe")
			is_sheathe_action_in_progress = false
	else:
		# === ARMING ===
		if combat_component.arm_weapon(WeaponData.WeaponSlot.PRIMARY):
			if has_motion:
				# Continue grounded state, fire unsheathe oneshot
				print("[Sheathe] → Arming with motion (oneshot)")
				
				# Start async task to fire oneshot after AnimationTree updates
				_delayed_unsheathe()
				
				# Clear flag immediately so player can move
				is_sheathe_action_in_progress = false
			else:
				# Stop and travel to Combat->Unsheathe state
				print("[Sheathe] → Arming idle (state transition)")
				player_state_machine.change_state("Unsheathe")
				is_sheathe_action_in_progress = false
		else:
			is_sheathe_action_in_progress = false


func _on_light_attack_pressed():
	"""Handle light attack button press"""
	# Can only attack when armed
	if not combat_component.can_attack():
		print("[Combat] Cannot attack - weapon not armed")
		return
	
	# Prevent attack spam - must wait for combo window or attack to finish
	if animation_controller.is_attacking and not animation_controller.can_buffer_next_attack:
		print("[Combat] Attack blocked - still attacking")
		return
	
	# Get next attack index based on current pattern
	var attack_index = combat_component.get_next_light_attack_index() + 1  # Convert 0-based to 1-based
	
	# Check if airborne or grounded
	if locomotion_component.get_is_grounded():
		# Grounded attack - travel to Combat state
		print("[Combat] Grounded light attack: ", attack_index)
		animation_controller.play_light_attack_grounded(attack_index)
	else:
		# Airborne attack - fire oneshot
		print("[Combat] Airborne light attack: ", attack_index)
		animation_controller.play_light_attack_airborne(attack_index)
	
	# Advance combo
	combat_component.advance_combo()


#endregion


func _delayed_unsheathe() -> void:
	"""Async helper: Wait one frame then fire unsheathe oneshot (doesn't block input)"""
	pending_delayed_operation = true
	
	await get_tree().process_frame
	
	# Check if operation was cancelled (player toggled again)
	if not pending_delayed_operation:
		print("[Sheathe] Delayed unsheathe cancelled")
		return
	
	print("[Sheathe] AnimationTree updated, firing oneshot")
	animation_controller.play_unsheathe_moving()
	pending_delayed_operation = false


func _delayed_unarm_weapon() -> void:
	"""Async helper: Wait for sheathe animation then swap back to unarmed (doesn't block input)"""
	pending_delayed_operation = true
	
	var duration = animation_controller.get_sheathe_duration()
	print("[Sheathe] Waiting ", duration, " seconds for oneshot to complete")
	await get_tree().create_timer(duration * 0.8).timeout  # Wait 80% to blend out smoothly
	
	# Check if operation was cancelled (player toggled again)
	if not pending_delayed_operation:
		print("[Sheathe] Delayed unarm cancelled")
		return
	
	# Unarm the weapon (swap back to unarmed animations)
	combat_component.unarm_weapon()
	print("[Sheathe] → Unarmed")
	pending_delayed_operation = false


#endregion


#region Weapon Management

func equip_weapon_data(weapon_data: WeaponData) -> void:
	"""Called by InventoryManager when a weapon is equipped"""
	combat_component.equip_weapon(weapon_data, weapon_data.weapon_slot)


func unequip_weapon_slot(slot: WeaponData.WeaponSlot) -> void:
	"""Called by InventoryManager when a weapon is unequipped"""
	combat_component.unequip_weapon(slot)


func set_attack_pattern(pattern: PlayerCombatComponent.AttackPattern) -> void:
	"""Change the light attack pattern (Sequential, Random, or Hybrid)"""
	combat_component.set_attack_pattern(pattern)


func set_light_attack_speed(speed: float) -> void:
	"""Set animation speed for light attacks. 1.0 = normal, 0.5 = half speed (for debugging), 2.0 = double speed"""
	animation_controller.set_light_attack_speed_scale(speed)


func set_combo_window(percentage: float) -> void:
	"""Set when combo window opens. 0.8 = last 20% (tight), 0.5 = last 50% (loose), 0.95 = last 5% (very tight)"""
	animation_controller.set_combo_window_percentage(percentage)


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


#region Animation Event Forwarding (for InventoryManager autoload)

func arm_primary_weapon() -> void:
	"""Forward animation event to InventoryManager"""
	InventoryManager.arm_primary_weapon()


func unarm_primary_weapon() -> void:
	"""Forward animation event to InventoryManager"""
	InventoryManager.unarm_primary_weapon()


func arm_secondary_weapon() -> void:
	"""Forward animation event to InventoryManager"""
	InventoryManager.arm_secondary_weapon()


func unarm_secondary_weapon() -> void:
	"""Forward animation event to InventoryManager"""
	InventoryManager.unarm_secondary_weapon()


func complete_sheathe() -> void:
	"""Complete sheathe action - restore unarmed animations.
	Called from animation event at the end of sheathe animations."""
	if combat_component:
		combat_component.unarm_weapon()


#region Lock-On Signal Handlers

func _on_lock_on_toggled() -> void:
	"""Handle lock-on toggle input from input component"""
	if lock_on_component:
		lock_on_component.toggle_lock_on()


func _on_lock_on_acquired(target: Node3D) -> void:
	"""Handle lock-on acquisition - update animation controller and camera"""
	if animation_controller:
		animation_controller.set_lock_on_target(target)
	if camera_controller:
		camera_controller.set_lock_on_target(target)


func _on_lock_on_lost() -> void:
	"""Handle lock-on lost - clear animation controller and camera lock-on state"""
	if animation_controller:
		animation_controller.clear_lock_on()
	if camera_controller:
		camera_controller.clear_lock_on()


func _unhandled_input(event):
	# ... existing code ...
  # Combo window tightness
	if event.is_action_pressed("ui_text_toggle_insert_mode"):  # Page Up
		set_combo_window(25.0)  # Very tight - last 5% only
		print("Combo window: VERY TIGHT (last 5%)")
	elif event.is_action_pressed("ui_home"):  # Home
		set_combo_window(0.8)  # Tight - last 20% (default)
		print("Combo window: TIGHT (last 20%)")
	elif event.is_action_pressed("ui_end"):  # End
		set_combo_window(0.5)  # Loose - last 50%
		print("Combo window: LOOSE (last 50%)")


	# DEBUG: Press F1 to slow attacks, F2 to reset
	if event.is_action_pressed("ui_page_up"):  # F1 key
		set_light_attack_speed(0.25)
		print("Attack speed: 0.25x")
	elif event.is_action_pressed("ui_page_down"):  # F2 key
		set_light_attack_speed(1.0)
		print("Attack speed: 1.0x")

#endregion

#endregion
