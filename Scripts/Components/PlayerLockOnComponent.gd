extends Node
class_name PlayerLockOnComponent

## Manages enemy lock-on system for player

signal lock_on_acquired(target: Node3D)
signal lock_on_lost()

@export var lock_on_range: float = 20.0  # Max distance to lock onto enemies
@export var lock_on_angle: float = 60.0  # Max angle from camera forward (degrees)
@export var auto_break_distance: float = 30.0  # Distance at which lock breaks automatically

var player: CharacterBody3D
var camera: Camera3D
var current_target: Node3D = null
var is_locked_on: bool = false


func initialize(player_body: CharacterBody3D, player_camera: Camera3D) -> void:
	"""Initialize with references to player and camera"""
	player = player_body
	camera = player_camera


func toggle_lock_on() -> void:
	"""Toggle lock-on state"""
	if is_locked_on:
		release_lock()
	else:
		acquire_lock()


func acquire_lock() -> Node3D:
	"""Find and lock onto the nearest valid enemy"""
	var best_target = find_best_target()
	
	if best_target:
		current_target = best_target
		is_locked_on = true
		print("[LockOn] Acquired target: ", current_target.name)
		lock_on_acquired.emit(current_target)
		return current_target
	else:
		print("[LockOn] No valid targets found")
		return null


func release_lock() -> void:
	"""Release current lock-on"""
	if current_target:
		print("[LockOn] Released target: ", current_target.name)
	
	current_target = null
	is_locked_on = false
	lock_on_lost.emit()


func update_lock_on(delta: float) -> void:
	"""Update lock-on state - call this every frame when locked on"""
	if not is_locked_on or not current_target:
		return
	
	# Check if target is still valid
	if not is_instance_valid(current_target):
		print("[LockOn] Target invalid, releasing")
		release_lock()
		return
	
	# Check if target is an enemy and is dead
	if current_target.has_method("is_dead") and current_target.is_dead:
		print("[LockOn] Target is dead, releasing")
		release_lock()
		return
	
	# Check if target is too far
	var distance = player.global_position.distance_to(current_target.global_position)
	if distance > auto_break_distance:
		print("[LockOn] Target too far (", distance, "m), releasing")
		release_lock()
		return


func find_best_target() -> Node3D:
	"""Find the best enemy to lock onto based on distance and camera angle"""
	var enemies = get_tree().get_nodes_in_group("enemies")
	if enemies.size() == 0:
		return null
	
	var best_target: Node3D = null
	var best_score: float = INF
	
	var player_pos = player.global_position
	var camera_forward = -camera.global_transform.basis.z
	
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		
		# Skip if enemy is dead
		if enemy.has_method("is_dead") and enemy.is_dead:
			continue
		
		var enemy_pos = enemy.global_position
		var distance = player_pos.distance_to(enemy_pos)
		
		# Skip if out of range
		if distance > lock_on_range:
			continue
		
		# Check angle from camera forward
		var to_enemy = (enemy_pos - player_pos).normalized()
		var angle = rad_to_deg(camera_forward.angle_to(to_enemy))
		
		# Skip if outside lock-on cone
		if angle > lock_on_angle:
			continue
		
		# Score based on distance and angle (lower is better)
		# Weigh distance more heavily than angle
		var score = distance * 2.0 + angle
		
		if score < best_score:
			best_score = score
			best_target = enemy
	
	return best_target


func cycle_target(direction: int) -> Node3D:
	"""Cycle to next/previous target. Direction: 1 = next, -1 = previous"""
	if not is_locked_on:
		return acquire_lock()
	
	var enemies = get_tree().get_nodes_in_group("enemies")
	if enemies.size() <= 1:
		return current_target  # No other targets to cycle to
	
	# Filter to valid enemies within range
	var valid_enemies = []
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if enemy.has_method("is_dead") and enemy.is_dead:
			continue
		var distance = player.global_position.distance_to(enemy.global_position)
		if distance <= lock_on_range:
			valid_enemies.append(enemy)
	
	if valid_enemies.size() <= 1:
		return current_target
	
	# Find current target index
	var current_index = valid_enemies.find(current_target)
	if current_index == -1:
		# Current target not in list, find new one
		return acquire_lock()
	
	# Cycle to next/previous
	var new_index = (current_index + direction) % valid_enemies.size()
	if new_index < 0:
		new_index = valid_enemies.size() - 1
	
	current_target = valid_enemies[new_index]
	print("[LockOn] Cycled to target: ", current_target.name)
	lock_on_acquired.emit(current_target)
	return current_target


func get_target() -> Node3D:
	"""Get the current locked target"""
	return current_target if is_locked_on else null


func is_target_locked() -> bool:
	"""Check if currently locked onto a target"""
	return is_locked_on and is_instance_valid(current_target)
