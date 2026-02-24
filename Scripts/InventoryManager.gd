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

# Store original weapon mesh transforms (relative to weapon base)
var primary_weapon_mesh_original_transform: Transform3D = Transform3D.IDENTITY
var secondary_weapon_mesh_original_transform: Transform3D = Transform3D.IDENTITY

# Visual/positioning
var sheathe_offset: float = 0.0
var hand_offset: Vector3 = Vector3.ZERO  # Adjust as needed for hand grip position


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
				# Store original weapon mesh transform for later restoration
				if weapon_instance is WeaponBase and weapon_instance.weapon_mesh:
					primary_weapon_mesh_original_transform = weapon_instance.weapon_mesh.transform
			else:
				if equipped_secondary_weapon:
					equipped_secondary_weapon.queue_free()
				equipped_secondary_weapon = weapon_instance
				# Store original weapon mesh transform for later restoration
				if weapon_instance is WeaponBase and weapon_instance.weapon_mesh:
					secondary_weapon_mesh_original_transform = weapon_instance.weapon_mesh.transform
			
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


func set_weapon_armed_state(is_armed: bool, slot: WeaponData.WeaponSlot = WeaponData.WeaponSlot.PRIMARY) -> void:
	"""Switch weapon between sheathe bone (unarmed) and hand bone (armed).
	This method is intended to be called from animation events."""
	
	# Get the weapon instance
	var weapon_instance = equipped_primary_weapon if slot == WeaponData.WeaponSlot.PRIMARY else equipped_secondary_weapon
	if not weapon_instance:
		print("[InventoryManager] No weapon equipped in slot to move")
		return
	
	# Ensure it's a WeaponBase with weapon_mesh reference
	if not weapon_instance is WeaponBase:
		print("[InventoryManager] Error: Weapon instance is not a WeaponBase")
		return
	
	var weapon_base = weapon_instance as WeaponBase
	if not weapon_base.weapon_mesh:
		print("[InventoryManager] Error: WeaponBase has no weapon_mesh assigned")
		return
	
	# Get player and skeleton
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		print("[InventoryManager] Error: Player not found")
		return
	
	var skeleton = player.find_child("Skeleton3D", true, false)
	if not skeleton:
		print("[InventoryManager] Error: Skeleton not found")
		return
	
	if is_armed:
		# Armed state - move weapon mesh to hand bone
		var hand_bone_name = "Katana Hand Bone"
		
		# Verify hand bone exists
		var bone_idx = skeleton.find_bone(hand_bone_name)
		if bone_idx == -1:
			print("[InventoryManager] Error: '", hand_bone_name, "' not found in skeleton")
			return
		
		# Create BoneAttachment3D for hand bone
		var hand_attachment = BoneAttachment3D.new()
		hand_attachment.bone_name = hand_bone_name
		skeleton.add_child(hand_attachment)
		
		# Reparent weapon mesh to hand
		weapon_base.weapon_mesh.reparent(hand_attachment)
		
		# Reset transform and apply grip position
		weapon_base.weapon_mesh.transform = Transform3D.IDENTITY
		weapon_base.weapon_mesh.rotation_degrees = Vector3(90, 0, 0)
		weapon_base.weapon_mesh.position = hand_offset
		
		print("[InventoryManager] Moved weapon mesh to hand (armed)")
	else:
		# Unarmed state - move weapon mesh back to weapon base (with sheathe)
		
		# Get the hand attachment (current parent) to clean it up
		var hand_attachment = weapon_base.weapon_mesh.get_parent()
		
		# Reparent weapon mesh back to weapon base
		weapon_base.weapon_mesh.reparent(weapon_base)
		
		# Restore original transform (how it was when first equipped)
		if slot == WeaponData.WeaponSlot.PRIMARY:
			weapon_base.weapon_mesh.transform = primary_weapon_mesh_original_transform
		else:
			weapon_base.weapon_mesh.transform = secondary_weapon_mesh_original_transform
		
		# Clean up hand attachment
		if hand_attachment and hand_attachment is BoneAttachment3D:
			hand_attachment.queue_free()
		
		print("[InventoryManager] Moved weapon mesh to sheathe (unarmed)")


# Convenience methods for animation events (they can only call methods with no required parameters)
func arm_primary_weapon() -> void:
	"""Move primary weapon to hand - called by animation event"""
	set_weapon_armed_state(true, WeaponData.WeaponSlot.PRIMARY)


func unarm_primary_weapon() -> void:
	"""Move primary weapon to sheathe - called by animation event"""
	set_weapon_armed_state(false, WeaponData.WeaponSlot.PRIMARY)


func arm_secondary_weapon() -> void:
	"""Move secondary weapon to hand - called by animation event"""
	set_weapon_armed_state(true, WeaponData.WeaponSlot.SECONDARY)


func unarm_secondary_weapon() -> void:
	"""Move secondary weapon to sheathe - called by animation event"""
	set_weapon_armed_state(false, WeaponData.WeaponSlot.SECONDARY)
