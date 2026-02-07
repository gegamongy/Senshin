extends CanvasLayer

@onready var inventory_grid = $Panel/MarginContainer/HBoxContainer/RightPanel/TabContainer/Inventory/MarginContainer/InventoryGrid
@onready var primary_weapon_slot = $Panel/MarginContainer/HBoxContainer/RightPanel/TabContainer/Equipment/VBoxContainer/WeaponSlots/PrimaryWeapon
@onready var secondary_weapon_slot = $Panel/MarginContainer/HBoxContainer/RightPanel/TabContainer/Equipment/VBoxContainer/WeaponSlots/SecondaryWeapon
@onready var headgear_slot = $Panel/MarginContainer/HBoxContainer/RightPanel/TabContainer/Equipment/VBoxContainer/ClothingSlots/Headgear
@onready var chestwear_slot = $Panel/MarginContainer/HBoxContainer/RightPanel/TabContainer/Equipment/VBoxContainer/ClothingSlots/Chestwear
@onready var legwear_slot = $Panel/MarginContainer/HBoxContainer/RightPanel/TabContainer/Equipment/VBoxContainer/ClothingSlots/Legwear
@onready var footwear_slot = $Panel/MarginContainer/HBoxContainer/RightPanel/TabContainer/Equipment/VBoxContainer/ClothingSlots/Footwear
@onready var tab_container = $Panel/MarginContainer/HBoxContainer/RightPanel/TabContainer

var inventory_slot_nodes: Array = []
var all_slots: Array = []  # All selectable slots in order
var selected_slot_index: int = 0
var navigation_mode: String = "mouse"  # "mouse", "cursor", "grid"

# UI Cursor for controller right stick mode
var ui_cursor: TextureRect
var cursor_position: Vector2
const CURSOR_SPEED = 800.0
const STICK_DEADZONE = 0.15

# Hover/selection styling
var hover_style: StyleBoxFlat
var selected_style: StyleBoxFlat
var equipped_style: StyleBoxFlat
var normal_style: StyleBoxFlat

# Item info popup
var info_popup: PanelContainer
var info_label: RichTextLabel

# Confirmation dialog
var confirmation_dialog: AcceptDialog
var pending_action: Callable


func _ready():
	# Collect all inventory slot nodes
	for child in inventory_grid.get_children():
		inventory_slot_nodes.append(child)
	
	# Build all selectable slots array (equipment + inventory)
	all_slots = [
		primary_weapon_slot, secondary_weapon_slot,
		headgear_slot, chestwear_slot, legwear_slot, footwear_slot
	]
	all_slots.append_array(inventory_slot_nodes)
	
	# Create styles
	setup_styles()
	
	# Create UI cursor
	setup_cursor()
	
	# Create info popup
	setup_info_popup()
	
	# Create confirmation dialog
	setup_confirmation_dialog()
	
	# Disable tab container and close button focus
	tab_container.focus_mode = Control.FOCUS_NONE
	var close_button = get_node_or_null("Panel/CloseButton")
	if close_button:
		close_button.focus_mode = Control.FOCUS_NONE
	
	# Connect to inventory signals
	if InventoryManager.player_inventory:
		InventoryManager.player_inventory.inventory_changed.connect(_on_inventory_changed)
		InventoryManager.player_inventory.equipment_changed.connect(_on_equipment_changed)
	
	# Scale equipment slots based on screen size
	scale_equipment_slots()
	scale_inventory_slots()
	
	# Initial refresh
	refresh_inventory()
	refresh_equipment()
	
	# Setup mouse detection for all slots
	setup_slot_mouse_detection()


func setup_styles():
	# Hover style (yellow border)
	hover_style = StyleBoxFlat.new()
	hover_style.bg_color = Color(0.2, 0.2, 0.2, 0.5)
	hover_style.border_width_left = 3
	hover_style.border_width_right = 3
	hover_style.border_width_top = 3
	hover_style.border_width_bottom = 3
	hover_style.border_color = Color.YELLOW
	
	# Selected style (bright yellow border)
	selected_style = StyleBoxFlat.new()
	selected_style.bg_color = Color(0.3, 0.3, 0.2, 0.5)
	selected_style.border_width_left = 4
	selected_style.border_width_right = 4
	selected_style.border_width_top = 4
	selected_style.border_width_bottom = 4
	selected_style.border_color = Color(1, 1, 0, 1)
	
	# Equipped style (green border)
	equipped_style = StyleBoxFlat.new()
	equipped_style.bg_color = Color(0.2, 0.3, 0.2, 0.5)
	equipped_style.border_width_left = 3
	equipped_style.border_width_right = 3
	equipped_style.border_width_top = 3
	equipped_style.border_width_bottom = 3
	equipped_style.border_color = Color(0, 1, 0, 1)
	
	# Normal style
	normal_style = StyleBoxFlat.new()
	normal_style.bg_color = Color(0.2, 0.2, 0.2, 0.3)


func setup_cursor():
	# Create cursor for controller right stick mode
	ui_cursor = TextureRect.new()
	ui_cursor.custom_minimum_size = Vector2(32, 32)
	ui_cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Don't block clicks
	
	# Create a simple circle cursor visual
	var cursor_image = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	cursor_image.fill(Color.TRANSPARENT)
	for x in range(32):
		for y in range(32):
			var dist = Vector2(x - 16, y - 16).length()
			if dist < 12 and dist > 8:
				cursor_image.set_pixel(x, y, Color.YELLOW)
			elif dist < 4:
				cursor_image.set_pixel(x, y, Color.YELLOW)
	
	ui_cursor.texture = ImageTexture.create_from_image(cursor_image)
	ui_cursor.z_index = 100
	ui_cursor.visible = true  # Always visible, follows mouse or stick
	add_child(ui_cursor)
	
	# Center cursor on screen initially
	cursor_position = get_viewport().get_visible_rect().size / 2


func setup_info_popup():
	# Create info popup panel
	info_popup = PanelContainer.new()
	info_popup.custom_minimum_size = Vector2(300, 200)
	info_popup.visible = false
	info_popup.z_index = 99
	add_child(info_popup)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	info_popup.add_child(margin)
	
	info_label = RichTextLabel.new()
	info_label.bbcode_enabled = true
	info_label.fit_content = true
	margin.add_child(info_label)


func setup_confirmation_dialog():
	confirmation_dialog = AcceptDialog.new()
	confirmation_dialog.title = "Confirm Action"
	confirmation_dialog.dialog_hide_on_ok = true
	confirmation_dialog.confirmed.connect(_on_confirmation_accepted)
	add_child(confirmation_dialog)


func setup_slot_mouse_detection():
	for slot in all_slots:
		# Ensure slots can receive mouse input
		slot.mouse_filter = Control.MOUSE_FILTER_PASS
		slot.mouse_entered.connect(_on_slot_mouse_entered.bind(slot))
		slot.mouse_exited.connect(_on_slot_mouse_exited.bind(slot))
		slot.gui_input.connect(_on_slot_gui_input.bind(slot))


func scale_equipment_slots():
	var viewport_size = get_viewport().get_visible_rect().size
	var scale_factor = viewport_size.y / 720.0  # Base on 720p
	var min_size = Vector2(120, 120) * scale_factor
	
	primary_weapon_slot.custom_minimum_size = min_size
	secondary_weapon_slot.custom_minimum_size = min_size
	headgear_slot.custom_minimum_size = min_size
	chestwear_slot.custom_minimum_size = min_size
	legwear_slot.custom_minimum_size = min_size
	footwear_slot.custom_minimum_size = min_size


func scale_inventory_slots():
	var viewport_size = get_viewport().get_visible_rect().size
	var scale_factor = viewport_size.y / 720.0  # Base on 720p
	var slot_size = Vector2(80, 80) * scale_factor
	
	for slot in inventory_slot_nodes:
		slot.custom_minimum_size = slot_size


func _process(delta):
	handle_navigation_input(delta)
	update_slot_highlighting()


func handle_navigation_input(delta):
	# Handle tab switching with bumpers
	if Input.is_action_just_pressed("ui_tab_left"):
		tab_container.current_tab = max(0, tab_container.current_tab - 1)
	elif Input.is_action_just_pressed("ui_tab_right"):
		tab_container.current_tab = min(tab_container.get_tab_count() - 1, tab_container.current_tab + 1)
	
	# Detect input type and switch modes
	var mouse_motion = Input.get_last_mouse_velocity().length() > 1.0
	var stick_input = Vector2(
		Input.get_joy_axis(0, JOY_AXIS_RIGHT_X),
		Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
	)
	var dpad_input = Input.is_action_just_pressed("ui_navigate_up") or \
					 Input.is_action_just_pressed("ui_navigate_down") or \
					 Input.is_action_just_pressed("ui_navigate_left") or \
					 Input.is_action_just_pressed("ui_navigate_right")
	
	# Switch to mouse mode if mouse moved
	if mouse_motion:
		if navigation_mode != "mouse":
			navigation_mode = "mouse"
		# Update cursor to follow mouse
		cursor_position = get_viewport().get_mouse_position()
		ui_cursor.global_position = cursor_position - Vector2(16, 16)
	
	# Switch to cursor mode if right stick moved
	elif stick_input.length() > STICK_DEADZONE:
		if navigation_mode != "cursor":
			navigation_mode = "cursor"
		
		# Move cursor with right stick
		cursor_position += stick_input * CURSOR_SPEED * delta
		cursor_position = cursor_position.clamp(Vector2.ZERO, get_viewport().get_visible_rect().size)
		ui_cursor.global_position = cursor_position - Vector2(16, 16)
	
	# Switch to grid mode if d-pad pressed
	elif dpad_input:
		if navigation_mode != "grid":
			navigation_mode = "grid"
			# Hide cursor in grid mode
			ui_cursor.modulate.a = 0.0
		else:
			ui_cursor.modulate.a = 1.0
		
		handle_grid_navigation()
	else:
		# Show cursor when not in grid mode
		if navigation_mode != "grid":
			ui_cursor.modulate.a = 1.0
	
	# Handle accept input
	if Input.is_action_just_pressed("ui_accept"):
		interact_with_selected_slot()


func check_cursor_slot_collision():
	# Find which slot the cursor is over
	for i in range(all_slots.size()):
		var slot = all_slots[i]
		var slot_rect = slot.get_global_rect()
		if slot_rect.has_point(cursor_position):
			selected_slot_index = i
			# Show info for the hovered slot in cursor mode
			if navigation_mode == "cursor":
				show_item_info(slot)
			return
	
	# No slot hovered, hide info
	if navigation_mode == "cursor":
		hide_item_info()


func handle_grid_navigation():
	var current_tab = tab_container.current_tab
	var columns = 8 if current_tab == 1 else 2  # Inventory has 8 columns, equipment has 2
	var rows_in_current_view = 6 if current_tab == 1 else 4  # Approximate
	
	if Input.is_action_just_pressed("ui_navigate_up"):
		selected_slot_index = max(0, selected_slot_index - columns)
	elif Input.is_action_just_pressed("ui_navigate_down"):
		selected_slot_index = min(all_slots.size() - 1, selected_slot_index + columns)
	elif Input.is_action_just_pressed("ui_navigate_left"):
		if selected_slot_index > 0:
			selected_slot_index -= 1
	elif Input.is_action_just_pressed("ui_navigate_right"):
		if selected_slot_index < all_slots.size() - 1:
			selected_slot_index += 1


func interact_with_selected_slot():
	if selected_slot_index < 0 or selected_slot_index >= all_slots.size():
		return
	
	var slot = all_slots[selected_slot_index]
	var slot_data = get_slot_data(slot)
	
	if slot_data == null or slot_data.is_empty():
		return
	
	var item = slot_data.item
	
	# Check if item is equippable
	if item.is_equippable:
		if InventoryManager.player_inventory.is_equipped(item):
			# Ask to unequip
			confirmation_dialog.dialog_text = "Unequip %s?" % item.item_name
			pending_action = func(): _do_unequip(item)
			confirmation_dialog.popup_centered()
		else:
			# Ask to equip
			confirmation_dialog.dialog_text = "Equip %s?" % item.item_name
			pending_action = func(): _do_equip(item)
			confirmation_dialog.popup_centered()


func _on_confirmation_accepted():
	if pending_action:
		pending_action.call()
		pending_action = Callable()


func _do_equip(item: Item):
	InventoryManager.equip_item(item)


func _do_unequip(item: Item):
	InventoryManager.unequip_item(item)


func get_slot_data(slot: PanelContainer) -> InventorySlot:
	# Check if it's an inventory slot
	var slot_index = inventory_slot_nodes.find(slot)
	if slot_index >= 0 and slot_index < InventoryManager.player_inventory.inventory_slots.size():
		return InventoryManager.player_inventory.inventory_slots[slot_index]
	
	# For equipment slots, create a temporary slot data
	var inventory = InventoryManager.player_inventory
	var item: Item = null
	
	if slot == primary_weapon_slot:
		item = inventory.primary_weapon
	elif slot == secondary_weapon_slot:
		item = inventory.secondary_weapon
	elif slot == headgear_slot:
		item = inventory.headgear
	elif slot == chestwear_slot:
		item = inventory.chestwear
	elif slot == legwear_slot:
		item = inventory.legwear
	elif slot == footwear_slot:
		item = inventory.footwear
	
	if item:
		var temp_slot = InventorySlot.new()
		temp_slot.item = item
		temp_slot.quantity = 1
		return temp_slot
	
	return null


func _on_slot_mouse_entered(slot: PanelContainer):
	# Only respond to actual mouse movement, not when cursor is over a slot
	if navigation_mode == "mouse" and Input.get_last_mouse_velocity().length() > 1.0:
		selected_slot_index = all_slots.find(slot)
		show_item_info(slot)


func _on_slot_mouse_exited(slot: PanelContainer):
	if navigation_mode == "mouse":
		hide_item_info()


func _on_slot_gui_input(event: InputEvent, slot: PanelContainer):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			selected_slot_index = all_slots.find(slot)
			interact_with_selected_slot()


func show_item_info(slot: PanelContainer):
	var slot_data = get_slot_data(slot)
	
	if slot_data == null or slot_data.is_empty():
		hide_item_info()
		return
	
	var item = slot_data.item
	var info_text = "[b]%s[/b]\n\n%s\n\n" % [item.item_name, item.description]
	
	# Add weapon stats if weapon
	if item is WeaponData:
		var weapon = item as WeaponData
		info_text += "[color=yellow]Weapon Stats:[/color]\n"
		info_text += "Type: %s\n" % weapon.weapon_type
		info_text += "Damage: %.1f\n" % weapon.damage
		info_text += "Attack Speed: %.1f\n" % weapon.attack_speed
		info_text += "Range: %.1f\n" % weapon.range
	
	# Add clothing stats if clothing
	elif item is ClothingItem:
		var clothing = item as ClothingItem
		info_text += "[color=cyan]Armor Stats:[/color]\n"
		info_text += "Armor: %.1f\n" % clothing.armor
		info_text += "Weight: %.1f\n" % clothing.weight
	
	# Add equipped status
	if InventoryManager.player_inventory.is_equipped(item):
		info_text += "\n[color=green][EQUIPPED][/color]"
	elif item.is_equippable:
		info_text += "\n[color=gray]Press [A] to equip[/color]"
	
	info_label.text = info_text
	info_popup.visible = true
	
	# Position popup near cursor
	info_popup.global_position = cursor_position + Vector2(20, 20)


func hide_item_info():
	info_popup.visible = false


func update_slot_highlighting():
	var any_slot_hovered_cursor = false
	
	for i in range(all_slots.size()):
		var slot = all_slots[i]
		var slot_data = get_slot_data(slot)
		var is_equipped = false
		
		if slot_data and not slot_data.is_empty():
			is_equipped = InventoryManager.player_inventory.is_equipped(slot_data.item)
		
		# Check if this slot is being hovered/selected
		var is_hovered_mouse = navigation_mode == "mouse" and slot.get_global_rect().has_point(get_viewport().get_mouse_position())
		var is_hovered_cursor = navigation_mode == "cursor" and slot.get_global_rect().has_point(cursor_position)
		var is_selected_grid = navigation_mode == "grid" and i == selected_slot_index
		
		if is_hovered_cursor:
			any_slot_hovered_cursor = true
		
		# Update selected_slot_index when hovering in cursor or mouse mode
		if (is_hovered_mouse or is_hovered_cursor) and selected_slot_index != i:
			selected_slot_index = i
			if is_hovered_cursor:
				show_item_info(slot)
		
		# Apply styling priority: hovered/selected > equipped > normal
		if is_hovered_mouse or is_hovered_cursor:
			slot.add_theme_stylebox_override("panel", hover_style)
		elif is_selected_grid:
			slot.add_theme_stylebox_override("panel", selected_style)
		elif is_equipped:
			slot.add_theme_stylebox_override("panel", equipped_style)
		else:
			slot.remove_theme_stylebox_override("panel")
	
	# Hide info popup if not hovering any slot in cursor mode
	if navigation_mode == "cursor" and not any_slot_hovered_cursor:
		hide_item_info()


func _on_inventory_changed():
	refresh_inventory()


func _on_equipment_changed():
	refresh_equipment()


func refresh_inventory():
	if not InventoryManager.player_inventory:
		return
	
	var inventory = InventoryManager.player_inventory
	
	# Update all inventory slots
	for i in range(inventory_slot_nodes.size()):
		var slot_node = inventory_slot_nodes[i]
		var slot_data = inventory.inventory_slots[i] if i < inventory.inventory_slots.size() else null
		
		update_slot_display(slot_node, slot_data)


func refresh_equipment():
	if not InventoryManager.player_inventory:
		return
	
	var inventory = InventoryManager.player_inventory
	
	# Update equipment slots
	update_equipment_slot_display(primary_weapon_slot, inventory.primary_weapon)
	update_equipment_slot_display(secondary_weapon_slot, inventory.secondary_weapon)
	update_equipment_slot_display(headgear_slot, inventory.headgear)
	update_equipment_slot_display(chestwear_slot, inventory.chestwear)
	update_equipment_slot_display(legwear_slot, inventory.legwear)
	update_equipment_slot_display(footwear_slot, inventory.footwear)


func update_slot_display(slot_node: PanelContainer, slot_data: InventorySlot):
	# Clear existing children (except the label if it exists)
	for child in slot_node.get_children():
		if child is Label and child.text in ["Primary", "Secondary", "Headgear", "Chestwear", "Legwear", "Footwear"]:
			continue
		child.queue_free()
	
	if slot_data == null or slot_data.is_empty():
		return
	
	# Create item display
	var item_container = VBoxContainer.new()
	item_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	slot_node.add_child(item_container)
	
	# Icon
	if slot_data.item.icon:
		var texture_rect = TextureRect.new()
		texture_rect.texture = slot_data.item.icon
		texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		texture_rect.custom_minimum_size = Vector2(64, 64)
		item_container.add_child(texture_rect)
	
	# Quantity (if more than 1)
	if slot_data.quantity > 1:
		var quantity_label = Label.new()
		quantity_label.text = "x%d" % slot_data.quantity
		quantity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		item_container.add_child(quantity_label)
	
	# Highlight if equipped
	if InventoryManager.player_inventory.is_equipped(slot_data.item):
		var equipped_label = Label.new()
		equipped_label.text = "[E]"
		equipped_label.add_theme_color_override("font_color", Color.YELLOW)
		equipped_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		item_container.add_child(equipped_label)


func update_equipment_slot_display(slot_node: PanelContainer, item: Item):
	# Clear existing children except static label
	for child in slot_node.get_children():
		if child is Label and child.text in ["Primary", "Secondary", "Headgear", "Chestwear", "Legwear", "Footwear"]:
			continue
		child.queue_free()
	
	if item == null:
		return
	
	# Create equipment card
	var card = VBoxContainer.new()
	card.set_anchors_preset(Control.PRESET_FULL_RECT)
	slot_node.add_child(card)
	
	# Icon
	if item.icon:
		var texture_rect = TextureRect.new()
		texture_rect.texture = item.icon
		texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		texture_rect.custom_minimum_size = Vector2(64, 64)
		card.add_child(texture_rect)
	
	# Item name
	var name_label = Label.new()
	name_label.text = item.item_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.add_theme_font_size_override("font_size", 14)
	card.add_child(name_label)
	
	# Stats display
	var stats_label = Label.new()
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_label.add_theme_font_size_override("font_size", 12)
	
	if item is WeaponData:
		var weapon = item as WeaponData
		stats_label.text = "DMG: %.0f | SPD: %.1f" % [weapon.damage, weapon.attack_speed]
	elif item is ClothingItem:
		var clothing = item as ClothingItem
		stats_label.text = "ARM: %.0f | WGT: %.1f" % [clothing.armor, clothing.weight]
	
	card.add_child(stats_label)
	
	# Unequip button
	var unequip_btn = Button.new()
	unequip_btn.text = "Unequip"
	unequip_btn.custom_minimum_size = Vector2(0, 30)
	unequip_btn.pressed.connect(_on_unequip_button_pressed.bind(item))
	card.add_child(unequip_btn)


func _on_unequip_button_pressed(item: Item):
	confirmation_dialog.dialog_text = "Unequip %s?" % item.item_name
	pending_action = func(): _do_unequip(item)
	confirmation_dialog.popup_centered()
