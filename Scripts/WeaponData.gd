class_name WeaponData
extends Item

enum WeaponSlot {
	PRIMARY,
	SECONDARY
}

@export_file("*.tscn") var weapon_scene_path: String  # Path to weapon scene
@export var weapon_type: String   # "katana", "greatsword", etc
@export var weapon_slot: WeaponSlot = WeaponSlot.PRIMARY
@export var anim_library: AnimationLibrary
@export var attack_defs: Array
@export var stamina_costs: Dictionary
@export var movement_modifiers: Dictionary


# Legacy damage (for backward compatibility - use damage types below instead)
@export var damage: float = 10.0

# Damage Type Composition (new system)
@export_group("Physical Damage")
@export var blunt_damage: float = 0.0
@export var slash_damage: float = 10.0  # Katana default
@export var pierce_damage: float = 0.0

@export_group("Elemental Damage")
@export var fire_damage: float = 0.0
@export var lightning_damage: float = 0.0
@export var water_damage: float = 0.0
@export var soul_damage: float = 0.0

@export_group("Magic Damage")
@export var void_damage: float = 0.0  # Void/Chaos magic
@export var astral_damage: float = 0.0  # Astral/Light magic

@export var attack_speed: float = 1.0
@export var range: float = 1.0

func _init():
	item_type = Item.ItemType.WEAPON
	is_equippable = true
	stack_size = 1


func get_damage_instance() -> DamageTypes.DamageInstance:
	"""Create a DamageInstance from this weapon's damage values"""
	var damage_inst = DamageTypes.DamageInstance.new()
	
	# Physical damage
	damage_inst.blunt = blunt_damage
	damage_inst.slash = slash_damage
	damage_inst.pierce = pierce_damage
	
	# Elemental damage
	damage_inst.fire = fire_damage
	damage_inst.lightning = lightning_damage
	damage_inst.water = water_damage
	damage_inst.soul = soul_damage
	
	# Magic damage
	damage_inst.void_ = void_damage
	damage_inst.astral = astral_damage
	
	return damage_inst


func get_total_damage() -> float:
	"""Get total damage across all types (for quick comparisons)"""
	return get_damage_instance().get_total_damage()
