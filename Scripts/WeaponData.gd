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




# Combat stats
@export var damage: float = 10.0
@export var attack_speed: float = 1.0
@export var range: float = 1.0

func _init():
	item_type = Item.ItemType.WEAPON
	is_equippable = true
	stack_size = 1
