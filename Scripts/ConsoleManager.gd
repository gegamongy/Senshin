extends Node
## Developer console system for registering and executing debug commands

signal command_executed(command_name: String, args: Array)
signal output_generated(text: String, type: String)

## Command structure: { "name": { "description": String, "usage": String, "function": Callable } }
var commands: Dictionary = {}

func _ready() -> void:
	_register_default_commands()
	print("[Console] Console system initialized")

## Register a new command
func register_command(command_name: String, description: String, usage: String, callback: Callable) -> void:
	if commands.has(command_name):
		push_warning("[Console] Command '%s' already exists, overwriting" % command_name)
	
	commands[command_name] = {
		"description": description,
		"usage": usage,
		"function": callback
	}
	print("[Console] Registered command: %s" % command_name)

## Unregister a command
func unregister_command(command_name: String) -> void:
	if commands.erase(command_name):
		print("[Console] Unregistered command: %s" % command_name)
	else:
		push_warning("[Console] Attempted to unregister non-existent command: %s" % command_name)

## Execute a command with arguments
func execute_command(input: String) -> void:
	var trimmed = input.strip_edges()
	if trimmed.is_empty():
		return
	
	# Parse command and arguments
	var parts = trimmed.split(" ", false)
	var command_name = parts[0].to_lower()
	var args = parts.slice(1) if parts.size() > 1 else []
	
	# Check if command exists
	if not commands.has(command_name):
		output_error("Unknown command: '%s'. Type 'help' for a list of commands." % command_name)
		return
	
	# Execute command
	var command_data = commands[command_name]
	var callback: Callable = command_data["function"]
	
	callback.call(args)
	command_executed.emit(command_name, args)

## Output text to console
func output_text(text: String) -> void:
	output_generated.emit(text, "normal")

## Output success message
func output_success(text: String) -> void:
	output_generated.emit(text, "success")

## Output error message
func output_error(text: String) -> void:
	output_generated.emit(text, "error")

## Output warning message
func output_warning(text: String) -> void:
	output_generated.emit(text, "warning")

## Get all command names
func get_command_names() -> Array:
	var names = commands.keys()
	names.sort()
	return names

## Get command info
func get_command_info(command_name: String) -> Dictionary:
	if commands.has(command_name):
		return commands[command_name]
	return {}

## Register default commands
func _register_default_commands() -> void:
	# Help command
	register_command(
		"help",
		"Display list of available commands or help for a specific command",
		"help [command]",
		_cmd_help
	)
	
	# Clear command
	register_command(
		"clear",
		"Clear the console output",
		"clear",
		_cmd_clear
	)
	
	# Echo command
	register_command(
		"echo",
		"Print text to console",
		"echo <text>",
		_cmd_echo
	)
	
	# Quit command
	register_command(
		"quit",
		"Exit the game",
		"quit",
		_cmd_quit
	)
	
	# FPS command
	register_command(
		"fps",
		"Toggle FPS display",
		"fps [on|off]",
		_cmd_fps
	)
	
	# Timescale command
	register_command(
		"timescale",
		"Set game time scale (slow motion / fast forward)",
		"timescale <value>",
		_cmd_timescale
	)

## Help command implementation
func _cmd_help(args: Array) -> void:
	if args.size() == 0:
		# List all commands
		output_text("[b]Available Commands:[/b]")
		var command_names = get_command_names()
		for cmd_name in command_names:
			var cmd_data = commands[cmd_name]
			output_text("  [color=cyan]%s[/color] - %s" % [cmd_name, cmd_data["description"]])
		output_text("\nType '[color=cyan]<command> help[/color]' or '[color=cyan]help <command>[/color]' for more information.")
	else:
		# Show help for specific command
		var cmd_name = args[0].to_lower()
		if commands.has(cmd_name):
			var cmd_data = commands[cmd_name]
			output_text("[b]Command:[/b] [color=cyan]%s[/color]" % cmd_name)
			output_text("[b]Description:[/b] %s" % cmd_data["description"])
			output_text("[b]Usage:[/b] %s" % cmd_data["usage"])
		else:
			output_error("Unknown command: '%s'" % cmd_name)

## Clear command implementation
func _cmd_clear(_args: Array) -> void:
	output_generated.emit("", "clear")

## Echo command implementation
func _cmd_echo(args: Array) -> void:
	if args.size() == 0:
		output_warning("Usage: echo <text>")
	else:
		output_text(" ".join(args))

## Quit command implementation
func _cmd_quit(_args: Array) -> void:
	output_text("Quitting game...")
	await get_tree().create_timer(0.5).timeout
	get_tree().quit()

## FPS command implementation
func _cmd_fps(args: Array) -> void:
	if args.size() == 0:
		# Toggle
		Engine.max_fps = 0 if Engine.max_fps > 0 else 60
		output_success("FPS display toggled")
	else:
		var arg = args[0].to_lower()
		if arg == "on":
			Engine.max_fps = 0
			output_success("FPS display enabled")
		elif arg == "off":
			Engine.max_fps = 60
			output_success("FPS display disabled")
		else:
			output_warning("Usage: fps [on|off]")

## Timescale command implementation
func _cmd_timescale(args: Array) -> void:
	if args.size() == 0:
		output_text("Current timescale: %s" % Engine.time_scale)
		output_warning("Usage: timescale <value>")
	else:
		var value = args[0].to_float()
		if value <= 0:
			output_error("Timescale must be greater than 0")
		else:
			Engine.time_scale = value
			output_success("Timescale set to %s" % value)
