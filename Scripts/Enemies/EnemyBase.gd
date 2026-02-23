class_name EnemyBase
extends CharacterBody3D

@export var enemy_data: EnemyData
@export var variant_index: int = 0  # Which variant to use (if variants exist)

# State
var current_health: float
var is_dead: bool = false
var target_player: CharacterBody3D = null

# Components (will be found or created)
var navigation_agent: NavigationAgent3D
var detection_area: Area3D
var skeleton: Skeleton3D
var animation_tree: AnimationTree
var mesh_instance: Node3D

# Gravity
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")


func _ready():
	if not enemy_data:
		push_error("EnemyBase: No enemy_data assigned!")
		return
	
	# Initialize health
	current_health = enemy_data.max_health
	
	# Setup variant or find existing mesh
	setup_mesh_variant()
	
	# Find or create components
	setup_components()
	
	# Add to enemy group
	add_to_group("enemies")
	
	print("Enemy initialized: ", enemy_data.enemy_name, " Health: ", current_health)


func setup_mesh_variant():
	# If variants are defined, instantiate the selected variant
	if enemy_data.variants.size() > 0:
		if variant_index >= 0 and variant_index < enemy_data.variants.size():
			var variant_scene = enemy_data.variants[variant_index]
			mesh_instance = variant_scene.instantiate()
			add_child(mesh_instance)
			print("Loaded variant ", variant_index, " for ", enemy_data.enemy_name)
		else:
			push_error("Invalid variant_index: ", variant_index)
	else:
		# No variants - assume mesh is already in scene as child
		# Find the mesh (usually first child that's a Node3D)
		for child in get_children():
			if child is Node3D and child is not CollisionShape3D:
				mesh_instance = child
				print("Using existing mesh child: ", mesh_instance.name)
				break
	
	# Find skeleton if it exists
	if mesh_instance:
		skeleton = mesh_instance.find_child("Skeleton3D", true, false)
		if skeleton:
			print("Found skeleton: ", skeleton.name)


func setup_components():
	# Find or create NavigationAgent3D
	navigation_agent = get_node_or_null("NavigationAgent3D")
	if not navigation_agent:
		navigation_agent = NavigationAgent3D.new()
		navigation_agent.name = "NavigationAgent3D"
		add_child(navigation_agent)
	
	# Find or create detection Area3D
	detection_area = get_node_or_null("DetectionArea")
	if not detection_area:
		detection_area = Area3D.new()
		detection_area.name = "DetectionArea"
		add_child(detection_area)
		
		var sphere = SphereShape3D.new()
		sphere.radius = enemy_data.detection_range
		var collision = CollisionShape3D.new()
		collision.shape = sphere
		detection_area.add_child(collision)
		
		# Connect signals
		detection_area.body_entered.connect(_on_detection_body_entered)
		detection_area.body_exited.connect(_on_detection_body_exited)
	
	# Find AnimationTree if it exists
	animation_tree = find_child("AnimationTree", true, false)


func _physics_process(delta):
	if is_dead:
		return
	
	apply_gravity(delta)
	
	if target_player:
		pursue_target(delta)
	
	move_and_slide()


func apply_gravity(delta: float):
	if not is_on_floor():
		velocity.y -= gravity * delta


func pursue_target(delta: float):
	if not target_player or not is_instance_valid(target_player):
		target_player = null
		return
	
	var distance_to_player = global_position.distance_to(target_player.global_position)
	
	# Check if in attack range
	if distance_to_player <= enemy_data.attack_range:
		# Stop and attack
		velocity.x = 0
		velocity.z = 0
		# TODO: Trigger attack animation/logic
		return
	
	# Move toward player
	if navigation_agent and navigation_agent.is_navigation_finished():
		return
	
	# Simple direct movement for now (can be replaced with NavigationAgent pathfinding)
	var direction = (target_player.global_position - global_position).normalized()
	direction.y = 0  # Keep on XZ plane
	
	velocity.x = direction.x * enemy_data.move_speed
	velocity.z = direction.z * enemy_data.move_speed
	
	# Rotate to face target
	if direction.length() > 0.01:
		var target_rotation = atan2(direction.x, direction.z)
		rotation.y = lerp_angle(rotation.y, target_rotation, 5.0 * delta)


func take_damage(amount: float, attacker: Node = null):
	if is_dead:
		return
	
	current_health -= amount
	print(enemy_data.enemy_name, " took ", amount, " damage. Health: ", current_health, "/", enemy_data.max_health)
	
	if current_health <= 0:
		die()
	else:
		# TODO: Play hit animation
		pass


func die():
	if is_dead:
		return
	
	is_dead = true
	print(enemy_data.enemy_name, " died!")
	
	# Spawn loot
	spawn_loot()
	
	# TODO: Play death animation
	
	# Remove after delay
	await get_tree().create_timer(3.0).timeout
	queue_free()


func spawn_loot():
	# Spawn guaranteed drops
	for item in enemy_data.guaranteed_drops:
		spawn_item(item)
	
	# Roll for possible drops
	for i in range(enemy_data.possible_drops.size()):
		if i < enemy_data.drop_chances.size():
			var chance = enemy_data.drop_chances[i]
			if randf() <= chance:
				spawn_item(enemy_data.possible_drops[i])


func spawn_item(item: Item):
	# TODO: Instantiate item pickup in world
	print("Dropped: ", item.item_name)


func _on_detection_body_entered(body: Node3D):
	if body.is_in_group("player"):
		target_player = body as CharacterBody3D
		print(enemy_data.enemy_name, " detected player!")


func _on_detection_body_exited(body: Node3D):
	if body == target_player:
		target_player = null
		print(enemy_data.enemy_name, " lost player!")
