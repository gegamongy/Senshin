extends Resource
class_name Item

enum ItemType {
	WEAPON,
	HEADGEAR,
	CHESTWEAR,
	LEGWEAR,
	FOOTWEAR,
	CONSUMABLE,
	MATERIAL
}

@export var item_name: String = ""
@export var description: String = ""
@export var icon: Texture2D
@export var item_type: ItemType = ItemType.MATERIAL
@export var stack_size: int = 1
@export var is_equippable: bool = false
