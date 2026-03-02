extends Node
class_name PlayerCombatComponent

## Handles all combat-related logic including attacks, blocks, parries, and combos
## Also tracks weapon arming/unarming state

signal attack_started
signal attack_hit
signal attack_ended
signal block_started
signal block_ended
signal weapon_armed(weapon_data: WeaponData)
signal weapon_unarmed

enum AttackPattern {
	SEQUENTIAL,  # 1->2->3->4->5->6, resets on timeout
	RANDOM,      # Completely random attacks
	HYBRID       # Sequential first time, then random
}

# Equipped weapons (data references)
var equipped_primary_weapon: WeaponData = null
var equipped_secondary_weapon: WeaponData = null

# Armed weapon state
var armed_weapon: WeaponData = null
var is_armed: bool = false

# Animation controller reference (set during initialization)
var animation_controller: PlayerAnimationController = null

# Attack pattern system
var attack_pattern: AttackPattern = AttackPattern.SEQUENTIAL
var current_combo_index: int = 0
var max_combo_count: int = 6  # Default for katana
var combo_timeout: float = 1.5  # Seconds before combo resets
var combo_timer: float = 0.0
var has_completed_first_sequence: bool = false  # For hybrid mode
var is_attacking: bool = false


func _ready():
	pass


func initialize(anim_controller: PlayerAnimationController = null):
	"""Initialize combat component"""
	animation_controller = anim_controller


func process_combat(delta: float) -> void:
	"""Main combat processing - called every physics frame"""
	# Update combo timer
	if combo_timer > 0.0:
		combo_timer -= delta
		if combo_timer <= 0.0:
			# Combo timed out - reset
			reset_combo()


func set_attack_pattern(pattern: AttackPattern) -> void:
	"""Change the attack pattern mode"""
	attack_pattern = pattern
	reset_combo()
	print("[CombatComponent] Attack pattern set to: ", AttackPattern.keys()[pattern])


func reset_combo() -> void:
	"""Reset the combo state"""
	current_combo_index = 0
	combo_timer = 0.0
	is_attacking = false
	print("[CombatComponent] Combo reset")


func get_next_light_attack_index() -> int:
	"""Get the next light attack index based on current pattern"""
	var next_index: int = 0
	
	match attack_pattern:
		AttackPattern.SEQUENTIAL:
			# Simple sequential: 0->1->2->3->4->5->0
			next_index = current_combo_index
			
		AttackPattern.RANDOM:
			# Fully random
			next_index = randi() % max_combo_count
			
		AttackPattern.HYBRID:
			# Sequential first time, then random
			if not has_completed_first_sequence:
				next_index = current_combo_index
			else:
				next_index = randi() % max_combo_count
	
	return next_index


func advance_combo() -> void:
	"""Advance to next attack in combo"""
	current_combo_index += 1
	
	# Check if we completed the sequence
	if current_combo_index >= max_combo_count:
		if attack_pattern == AttackPattern.HYBRID and not has_completed_first_sequence:
			has_completed_first_sequence = true
			print("[CombatComponent] First sequence completed - switching to random mode")
		current_combo_index = 0
	
	# Reset combo timer
	combo_timer = combo_timeout
	
	print("[CombatComponent] Combo advanced to index: ", current_combo_index, " | Timer: ", combo_timer)


func equip_weapon(weapon_data: WeaponData, slot: WeaponData.WeaponSlot) -> void:
	"""Equip a weapon to a specific slot (doesn't arm it)"""
	if slot == WeaponData.WeaponSlot.PRIMARY:
		equipped_primary_weapon = weapon_data
		print("[CombatComponent] Equipped primary weapon: ", weapon_data.item_name)
	else:
		equipped_secondary_weapon = weapon_data
		print("[CombatComponent] Equipped secondary weapon: ", weapon_data.item_name)


func unequip_weapon(slot: WeaponData.WeaponSlot) -> void:
	"""Unequip a weapon from a specific slot"""
	if slot == WeaponData.WeaponSlot.PRIMARY:
		# If the armed weapon is being unequipped, unarm it first
		if is_armed and armed_weapon == equipped_primary_weapon:
			unarm_weapon()
		equipped_primary_weapon = null
	else:
		if is_armed and armed_weapon == equipped_secondary_weapon:
			unarm_weapon()
		equipped_secondary_weapon = null


func arm_weapon(slot: WeaponData.WeaponSlot) -> bool:
	"""Arm a weapon from the specified slot (swap animation library and play unsheathe)"""
	var weapon_to_arm = equipped_primary_weapon if slot == WeaponData.WeaponSlot.PRIMARY else equipped_secondary_weapon
	
	if not weapon_to_arm:
		print("[CombatComponent] No weapon equipped in slot to arm")
		return false
	
	if is_armed:
		print("[CombatComponent] Already armed, unarm first")
		return false
	
	armed_weapon = weapon_to_arm
	is_armed = true
	
	# Swap animation library
	print("[CombatComponent] Attempting to swap animation library...")
	print("[CombatComponent]   animation_controller exists: ", animation_controller != null)
	print("[CombatComponent]   armed_weapon.anim_library exists: ", armed_weapon.anim_library != null)
	print("[CombatComponent]   armed_weapon.weapon_type: ", armed_weapon.weapon_type)
	
	if animation_controller and armed_weapon.anim_library:
		print("[CombatComponent]   Calling swap_animation_library()...")
		animation_controller.swap_animation_library(armed_weapon.anim_library, armed_weapon.weapon_type)
	else:
		print("[CombatComponent]   ERROR: Cannot swap - missing animation_controller or anim_library")
	
	weapon_armed.emit(armed_weapon)
	print("[CombatComponent] Armed weapon: ", armed_weapon.item_name)
	return true


func unarm_weapon() -> bool:
	"""Unarm the current weapon (swap back to unarmed animations and play sheathe)"""
	if not is_armed:
		print("[CombatComponent] Not armed")
		return false
	
	# Swap back to unarmed animation library
	if animation_controller:
		animation_controller.restore_unarmed_animations()
	
	armed_weapon = null
	is_armed = false
	
	weapon_unarmed.emit()
	print("[CombatComponent] Unarmed weapon")
	return true


func toggle_weapon_arming() -> bool:
	"""Toggle between armed and unarmed state for primary weapon"""
	if is_armed:
		return unarm_weapon()
	else:
		return arm_weapon(WeaponData.WeaponSlot.PRIMARY)


func can_attack() -> bool:
	"""Check if player can currently attack"""
	# Can only attack when armed
	return is_armed


func can_block() -> bool:
	"""Check if player can currently block"""
	# Can only block when armed
	return is_armed
