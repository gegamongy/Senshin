extends Item
class_name ClothingItem

@export var armor: float = 5.0
@export var weight: float = 1.0

func _init():
	is_equippable = true
	stack_size = 1

# Type is already set via item_type (HEADGEAR, CHESTWEAR, etc.)
