class_name WeaponBase
extends Node3D

@export var sheathe: MeshInstance3D #The Sheathe or Scabbard for the weapon
@export var weapon_data: WeaponData

signal player_in_range
signal player_out_of_range

var is_equipped: bool = false
var player_in_pickup_range: bool = false
var pickup_indicator: Label3D
var pickup_area: Area3D
var rigid_body: RigidBody3D


func _ready():
	# Get rigid body reference if it exists
	rigid_body = get_node_or_null("RigidBody3D")
	
	# Create pickup area
	pickup_area = Area3D.new()
	add_child(pickup_area)
	
	var collision_shape = CollisionShape3D.new()
	var sphere_shape = SphereShape3D.new()
	sphere_shape.radius = 2.0  # 2 meter pickup range
	collision_shape.shape = sphere_shape
	pickup_area.add_child(collision_shape)
	
	# Set collision layers/masks for player detection
	pickup_area.collision_layer = 0
	pickup_area.collision_mask = 1  # Layer 1 for player
	
	# Connect signals
	pickup_area.body_entered.connect(_on_body_entered)
	pickup_area.body_exited.connect(_on_body_exited)
	
	# Create pickup indicator (hidden by default)
	pickup_indicator = Label3D.new()
	pickup_indicator.text = "[Y] Pickup"
	pickup_indicator.pixel_size = 0.005
	pickup_indicator.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	pickup_indicator.no_depth_test = true
	pickup_indicator.position = Vector3(0, 1.0, 0)  # Position above weapon
	pickup_indicator.visible = false
	add_child(pickup_indicator)


func _on_body_entered(body):
	print("Body entered pickup area: ", body.name, " Is player: ", body.is_in_group("player"))
	if body.is_in_group("player"):
		player_in_pickup_range = true
		pickup_indicator.visible = true
		player_in_range.emit()
		# Register with player
		if body.has_method("register_pickup"):
			print("Registering pickup with player")
			body.register_pickup(self)
		else:
			print("Player doesn't have register_pickup method")


func _on_body_exited(body):
	if body.is_in_group("player"):
		player_in_pickup_range = false
		pickup_indicator.visible = false
		player_out_of_range.emit()
		# Unregister with player
		if body.has_method("unregister_pickup"):
			body.unregister_pickup(self)


func pickup() -> bool:
	print("Pickup called on: ", name)
	print("Weapon data: ", weapon_data)
	print("InventoryManager: ", InventoryManager)
	print("Player inventory: ", InventoryManager.player_inventory)
	
	if weapon_data == null:
		print("ERROR: weapon_data is null! You need to assign a WeaponData resource.")
		return false
	
	# Add to inventory
	var success = InventoryManager.player_inventory.add_item(weapon_data, 1)
	print("Add item result: ", success)
	if success:
		print("Picked up: ", weapon_data.item_name)
		queue_free()  # Remove from world
		return true
	else:
		print("Inventory full!")
		return false


func set_equipped(equipped: bool):
	is_equipped = equipped
	
	if is_equipped:
		# Disable physics and pickup when equipped
		if rigid_body:
			rigid_body.freeze = true
			rigid_body.collision_layer = 0
			rigid_body.collision_mask = 0
		if pickup_area:
			pickup_area.monitoring = false
		if pickup_indicator:
			pickup_indicator.visible = false
		player_in_pickup_range = false
	else:
		# Enable physics and pickup for world state
		if rigid_body:
			rigid_body.freeze = false
			rigid_body.collision_layer = 1
			rigid_body.collision_mask = 1
		if pickup_area:
			pickup_area.monitoring = true


func equip():
	pass
	
