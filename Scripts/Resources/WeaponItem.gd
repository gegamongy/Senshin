extends Item
class_name WeaponItem

enum WeaponSlot {
	PRIMARY,
	SECONDARY
}

@export var weapon_slot: WeaponSlot = WeaponSlot.PRIMARY
@export var weapon_data: WeaponData  # Reference to combat/gameplay data

func _init():
	item_type = Item.ItemType.WEAPON
	is_equippable = true
	stack_size = 1
