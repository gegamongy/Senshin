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

# Equipped weapons (data references)
var equipped_primary_weapon: WeaponData = null
var equipped_secondary_weapon: WeaponData = null

# Armed weapon state
var armed_weapon: WeaponData = null
var is_armed: bool = false

# Animation controller reference (set during initialization)
var animation_controller: PlayerAnimationController = null


func _ready():
	pass


func initialize(anim_controller: PlayerAnimationController = null):
	"""Initialize combat component"""
	animation_controller = anim_controller


func process_combat(delta: float) -> void:
	"""Main combat processing - called every physics frame"""
	# TODO: Handle combat state machine
	# - Attack combos
	# - Block/parry
	# - Hit detection
	# - Damage calculation
	pass


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
