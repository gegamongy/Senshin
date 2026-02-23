extends Node

var inventory_ui_scene = preload("res://Scenes/UI/InventoryUI.tscn")
var character_visual_scene = preload("res://Scenes/CharacterVisual.tscn")
var inventory_ui: CanvasLayer = null
var character_visual: Node3D = null
var is_open: bool = false
var was_mouse_captured: bool = false

# Inventory data
var player_inventory: InventoryData = null

# Equipped weapon instances
var equipped_primary_weapon: Node3D = null
var equipped_secondary_weapon: Node3D = null


# Visual/positioning
var sheathe_offset: float = 0.15


func _ready():
	# Initialize player inventory
	player_inventory = InventoryData.new()


func toggle_inventory():
	if is_open:
		close_inventory()
	else:
		open_inventory()


func open_inventory():
	if is_open:
		return
	
	# Stop player movement
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.disable_player_control()
	
	# Store mouse capture state
	was_mouse_captured = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	
	# Release mouse for UI
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	# Create and add inventory UI
	inventory_ui = inventory_ui_scene.instantiate()
	get_tree().root.add_child(inventory_ui)
	
	# Load character visual into SubViewport (isolated from game world)
	var subviewport = inventory_ui.get_node("Panel/MarginContainer/HBoxContainer/LeftPanel/SubViewportContainer/SubViewport")
	if subviewport:
		character_visual = character_visual_scene.instantiate()
		subviewport.add_child(character_visual)
		
		# Ensure camera only sees layer 20
		var camera = character_visual.get_node_or_null("Camera3D")
		if camera:
			camera.cull_mask = 1 << 19  # Only layer 20 (bit 19 for layer 20)
	
	# Connect close button
	var close_button = inventory_ui.get_node("Panel/CloseButton")
	if close_button:
		close_button.pressed.connect(close_inventory)
	
	is_open = true
	print("Inventory opened")


func close_inventory():
	if not is_open:
		return
	
	# Remove inventory UI
	if inventory_ui:
		inventory_ui.queue_free()
		inventory_ui = null
		character_visual = null
	
	# Restore mouse capture state
	if was_mouse_captured:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	is_open = false
	print("Inventory closed")


func _input(event):
	# Handle ESC to close inventory
	if is_open and event.is_action_pressed("ui_cancel"):
		close_inventory()
		get_viewport().set_input_as_handled()


func equip_item(item: Item) -> bool:
	if not player_inventory.equip_item(item):
		return false
	
	# If it's a weapon, instantiate and attach to player
	if item is WeaponData:
		var weapon = item as WeaponData
		if weapon.weapon_scene_path and weapon.weapon_scene_path != "":
			# Load weapon scene from path
			var weapon_scene = load(weapon.weapon_scene_path)
			if not weapon_scene:
				print("Error: Could not load weapon scene: ", weapon.weapon_scene_path)
				return false
			
			# Get player and skeleton
			var player = get_tree().get_first_node_in_group("player")
			if not player:
				print("Error: Player not found")
				return false
			
			# Find skeleton recursively
			var skeleton = player.find_child("Skeleton3D", true, false)
			if not skeleton:
				print("Error: Skeleton not found under player node: ", player.name)
				print("Player children: ", player.get_children())
				return false
			
			# Instantiate weapon
			var weapon_instance = weapon_scene.instantiate()
			skeleton.add_child(weapon_instance)
			
			# Verify bone exists
			var bone_idx = skeleton.find_bone("Sheathe Bone")
			if bone_idx == -1:
				print("Error: 'Sheathe Bone' not found in skeleton")
				print("Available bones:")
				for i in skeleton.get_bone_count():
					print("  - ", skeleton.get_bone_name(i))
				weapon_instance.queue_free()
				return false

			# Attach to bone
			if weapon_instance is WeaponBase:
				weapon_instance.set_equipped(true)

			var bone_attachment = BoneAttachment3D.new()
			bone_attachment.bone_name = "Sheathe Bone"
			skeleton.add_child(bone_attachment)
			weapon_instance.reparent(bone_attachment)

			# Reset transform to match bone exactly
			weapon_instance.transform = Transform3D.IDENTITY
		
			# Apply rotation correction for Blender to Godot axis conversion
			weapon_instance.rotation_degrees = Vector3(90, 0, 0)
			
			# Apply sheathe offset along local Z axis
			weapon_instance.position.y = sheathe_offset

			# Store reference based on slot
			if weapon.weapon_slot == WeaponData.WeaponSlot.PRIMARY:
				if equipped_primary_weapon:
					equipped_primary_weapon.queue_free()
				equipped_primary_weapon = weapon_instance
			else:
				if equipped_secondary_weapon:
					equipped_secondary_weapon.queue_free()
				equipped_secondary_weapon = weapon_instance
			
			# Notify player's combat component through player controller
			if player.has_method("equip_weapon_data"):
				player.equip_weapon_data(weapon)
			
			print("Equipped weapon: ", weapon.item_name)
			return true
	
	# For other item types, just mark as equipped (no visual yet)
	print("Equipped: ", item.item_name)
	return true


func unequip_item(item: Item) -> bool:
	if not player_inventory.unequip_item(item):
		return false
	
	# If it's a weapon, remove the instance
	if item is WeaponData:
		var weapon = item as WeaponData
		
		# Get player reference
		var player = get_tree().get_first_node_in_group("player")
		
		# Notify player's combat component through player controller
		if player and player.has_method("unequip_weapon_slot"):
			player.unequip_weapon_slot(weapon.weapon_slot)
		
		# Remove visual instance
		if weapon.weapon_slot == WeaponData.WeaponSlot.PRIMARY:
			if equipped_primary_weapon:
				equipped_primary_weapon.queue_free()
				equipped_primary_weapon = null
		else:
			if equipped_secondary_weapon:
				equipped_secondary_weapon.queue_free()
				equipped_secondary_weapon = null
		
		print("Unequipped weapon: ", weapon.item_name)
		return true
	
	print("Unequipped: ", item.item_name)
	return true
