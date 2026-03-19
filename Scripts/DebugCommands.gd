extends Node
## Example debug commands for game testing
## This demonstrates how to add custom console commands for your game

func _ready() -> void:
	_register_debug_commands()
	print("[DebugCommands] Debug commands registered")

func _register_debug_commands() -> void:
	# Player debug commands
	ConsoleManager.register_command(
		"player_pos",
		"Show or set player position",
		"player_pos [x] [y] [z]",
		_cmd_player_pos
	)
	
	# Scene debug commands
	ConsoleManager.register_command(
		"spawn_enemy",
		"Spawn an enemy at player position",
		"spawn_enemy <enemy_type>",
		_cmd_spawn_enemy
	)
	
	# Stats debug commands
	ConsoleManager.register_command(
		"list_items",
		"List all items in inventory",
		"list_items",
		_cmd_list_items
	)

## Show or set player position
func _cmd_player_pos(args: Array) -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		ConsoleManager.output_error("Player not found")
		return
	
	if args.size() == 0:
		# Show current position
		var pos = player.global_position
		ConsoleManager.output_text("Player position: (%.2f, %.2f, %.2f)" % [pos.x, pos.y, pos.z])
	elif args.size() >= 3:
		# Set position
		var x = args[0].to_float()
		var y = args[1].to_float()
		var z = args[2].to_float()
		player.global_position = Vector3(x, y, z)
		ConsoleManager.output_success("Teleported player to (%.2f, %.2f, %.2f)" % [x, y, z])
	else:
		ConsoleManager.output_warning("Usage: player_pos [x] [y] [z]")

## Spawn an enemy at player position
func _cmd_spawn_enemy(args: Array) -> void:
	if args.size() == 0:
		ConsoleManager.output_warning("Usage: spawn_enemy <enemy_type>")
		ConsoleManager.output_text("Available enemy types: psychopomp")
		return
	
	var enemy_type = args[0].to_lower()
	ConsoleManager.output_warning("Enemy spawning not yet implemented for type: %s" % enemy_type)
	
	# TODO: Implement enemy spawning
	# var player = get_tree().get_first_node_in_group("player")
	# var enemy_scene = load("res://Enemies/%s.tscn" % enemy_type)
	# var enemy = enemy_scene.instantiate()
	# enemy.global_position = player.global_position + Vector3(2, 0, 2)
	# get_tree().current_scene.add_child(enemy)
	# ConsoleManager.output_success("Spawned %s" % enemy_type)

## List all items in inventory
func _cmd_list_items(_args: Array) -> void:
	if not InventoryManager:
		ConsoleManager.output_error("InventoryManager not found")
		return
	
	# This is an example - adjust based on your actual inventory system
	ConsoleManager.output_text("Listing inventory items...")
	ConsoleManager.output_warning("Inventory listing not yet implemented")
	
	# TODO: Implement based on your inventory system
	# var items = InventoryManager.get_all_items()
	# if items.is_empty():
	#     ConsoleManager.output_text("Inventory is empty")
	# else:
	#     for item in items:
	#         ConsoleManager.output_text("- %s x%d" % [item.name, item.count])
