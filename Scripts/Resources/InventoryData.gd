extends Resource
class_name InventoryData

signal inventory_changed
signal equipment_changed

const MAX_INVENTORY_SIZE = 48

# Equipment slots
@export var primary_weapon: WeaponData = null
@export var secondary_weapon: WeaponData = null
@export var headgear: ClothingItem = null
@export var chestwear: ClothingItem = null
@export var legwear: ClothingItem = null
@export var footwear: ClothingItem = null

# Inventory slots
@export var inventory_slots: Array[InventorySlot] = []


func _init():
	# Initialize inventory slots
	inventory_slots.resize(MAX_INVENTORY_SIZE)
	for i in range(MAX_INVENTORY_SIZE):
		inventory_slots[i] = InventorySlot.new()


# Add item to inventory
func add_item(item: Item, quantity: int = 1) -> bool:
	if item == null:
		return false
	
	# Try to stack with existing items first
	if item.stack_size > 1:
		for slot in inventory_slots:
			if slot.can_stack_with(item):
				quantity = slot.add_quantity(quantity)
				if quantity <= 0:
					inventory_changed.emit()
					return true
	
	# Find empty slot
	for slot in inventory_slots:
		if slot.is_empty():
			slot.item = item
			slot.quantity = min(quantity, item.stack_size)
			quantity -= slot.quantity
			inventory_changed.emit()
			if quantity <= 0:
				return true
	
	return quantity <= 0  # False if couldn't fit all items


# Remove item from inventory
func remove_item(item: Item, quantity: int = 1) -> bool:
	var remaining = quantity
	for slot in inventory_slots:
		if slot.item == item:
			var removed = slot.remove_quantity(remaining)
			remaining -= removed
			if remaining <= 0:
				inventory_changed.emit()
				return true
	
	return remaining <= 0


# Get total quantity of an item
func get_item_count(item: Item) -> int:
	var count = 0
	for slot in inventory_slots:
		if slot.item == item:
			count += slot.quantity
	return count


# Check if item is equipped
func is_equipped(item: Item) -> bool:
	if item == null:
		return false
	
	return (item == primary_weapon or 
			item == secondary_weapon or 
			item == headgear or 
			item == chestwear or 
			item == legwear or 
			item == footwear)


# Equip an item
func equip_item(item: Item) -> bool:
	if item == null or not item.is_equippable:
		return false
	
	match item.item_type:
		Item.ItemType.WEAPON:
			var weapon = item as WeaponData
			if weapon.weapon_slot == WeaponData.WeaponSlot.PRIMARY:
				if primary_weapon != null:
					unequip_item(primary_weapon)
				primary_weapon = weapon
			else:
				if secondary_weapon != null:
					unequip_item(secondary_weapon)
				secondary_weapon = weapon
		
		Item.ItemType.HEADGEAR:
			if headgear != null:
				unequip_item(headgear)
			headgear = item as ClothingItem
		
		Item.ItemType.CHESTWEAR:
			if chestwear != null:
				unequip_item(chestwear)
			chestwear = item as ClothingItem
		
		Item.ItemType.LEGWEAR:
			if legwear != null:
				unequip_item(legwear)
			legwear = item as ClothingItem
		
		Item.ItemType.FOOTWEAR:
			if footwear != null:
				unequip_item(footwear)
			footwear = item as ClothingItem
		
		_:
			return false
	
	equipment_changed.emit()
	inventory_changed.emit()
	return true


# Unequip an item
func unequip_item(item: Item) -> bool:
	if item == null:
		return false
	
	var unequipped = false
	
	if item == primary_weapon:
		primary_weapon = null
		unequipped = true
	elif item == secondary_weapon:
		secondary_weapon = null
		unequipped = true
	elif item == headgear:
		headgear = null
		unequipped = true
	elif item == chestwear:
		chestwear = null
		unequipped = true
	elif item == legwear:
		legwear = null
		unequipped = true
	elif item == footwear:
		footwear = null
		unequipped = true
	
	if unequipped:
		equipment_changed.emit()
		inventory_changed.emit()
	
	return unequipped


# Get all equipped items
func get_equipped_items() -> Array[Item]:
	var equipped: Array[Item] = []
	if primary_weapon: equipped.append(primary_weapon)
	if secondary_weapon: equipped.append(secondary_weapon)
	if headgear: equipped.append(headgear)
	if chestwear: equipped.append(chestwear)
	if legwear: equipped.append(legwear)
	if footwear: equipped.append(footwear)
	return equipped
