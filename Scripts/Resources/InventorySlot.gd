extends Resource
class_name InventorySlot

@export var item: Item = null
@export var quantity: int = 0

func is_empty() -> bool:
	return item == null or quantity <= 0

func can_stack_with(other_item: Item) -> bool:
	if item == null or other_item == null:
		return false
	return item == other_item and quantity < item.stack_size

func add_quantity(amount: int) -> int:
	if item == null:
		return amount
	var space_left = item.stack_size - quantity
	var added = min(amount, space_left)
	quantity += added
	return amount - added  # Return overflow

func remove_quantity(amount: int) -> int:
	var removed = min(amount, quantity)
	quantity -= removed
	if quantity <= 0:
		item = null
		quantity = 0
	return removed
