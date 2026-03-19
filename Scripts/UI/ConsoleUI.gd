extends CanvasLayer
## Developer console UI - handles display and input

@onready var panel: Panel = $Panel
@onready var output_label: RichTextLabel = $Panel/VBoxContainer/ScrollContainer/OutputLabel
@onready var input_field: LineEdit = $Panel/VBoxContainer/InputField

var is_visible: bool = false
var command_history: Array[String] = []
var history_index: int = -1
var max_history: int = 50
var max_output_lines: int = 500

func _ready() -> void:
	# Start hidden
	hide_console()
	
	# Connect signals
	input_field.text_submitted.connect(_on_input_submitted)
	ConsoleManager.output_generated.connect(_on_output_generated)
	
	# Setup output label
	output_label.bbcode_enabled = true
	output_label.scroll_following = true
	output_label.fit_content = true
	
	# Welcome message
	_add_output("[color=cyan]═══════════════════════════════════════[/color]", "normal")
	_add_output("[b][color=yellow]Developer Console[/color][/b]", "normal")
	_add_output("[color=cyan]═══════════════════════════════════════[/color]", "normal")
	_add_output("Type [color=cyan]help[/color] for a list of commands", "normal")
	_add_output("", "normal")

func _input(event: InputEvent) -> void:
	# Toggle console with backtick key
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_QUOTELEFT:  # Backtick key
			toggle_console()
			get_viewport().set_input_as_handled()

func toggle_console() -> void:
	if is_visible:
		hide_console()
	else:
		show_console()

func show_console() -> void:
	is_visible = true
	panel.show()
	input_field.grab_focus()
	# Pause game when console is open (optional)
	# get_tree().paused = true

func hide_console() -> void:
	is_visible = false
	panel.hide()
	input_field.clear()
	history_index = -1
	# Unpause game
	# get_tree().paused = false

func _on_input_submitted(text: String) -> void:
	if text.strip_edges().is_empty():
		return
	
	# Add to history
	if command_history.is_empty() or command_history[0] != text:
		command_history.push_front(text)
		if command_history.size() > max_history:
			command_history.resize(max_history)
	history_index = -1
	
	# Display command in output
	_add_output("[color=green]> %s[/color]" % text, "normal")
	
	# Check for command-specific help (e.g., "clear help")
	var parts = text.strip_edges().split(" ", false)
	if parts.size() == 2 and parts[1].to_lower() == "help":
		# Convert "command help" to "help command"
		ConsoleManager.execute_command("help " + parts[0])
	else:
		# Execute command
		ConsoleManager.execute_command(text)
	
	# Clear input
	input_field.clear()

func _on_output_generated(text: String, type: String) -> void:
	match type:
		"clear":
			output_label.clear()
		"normal":
			_add_output(text, type)
		"success":
			_add_output("[color=lime]%s[/color]" % text, type)
		"error":
			_add_output("[color=red]✗ %s[/color]" % text, type)
		"warning":
			_add_output("[color=yellow]⚠ %s[/color]" % text, type)

func _add_output(text: String, _type: String) -> void:
	output_label.append_text(text + "\n")
	
	# Limit output lines to prevent memory issues
	var line_count = output_label.get_line_count()
	if line_count > max_output_lines:
		# Remove oldest lines by clearing and keeping recent ones
		var lines = output_label.text.split("\n")
		var keep_lines = lines.slice(line_count - max_output_lines)
		output_label.clear()
		for line in keep_lines:
			output_label.append_text(line + "\n")

func _unhandled_input(event: InputEvent) -> void:
	if not is_visible:
		return
	
	if event is InputEventKey and event.pressed and not event.echo:
		# Navigate command history with up/down arrows
		if event.keycode == KEY_UP:
			_history_previous()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_DOWN:
			_history_next()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE:
			hide_console()
			get_viewport().set_input_as_handled()

func _history_previous() -> void:
	if command_history.is_empty():
		return
	
	history_index += 1
	if history_index >= command_history.size():
		history_index = command_history.size() - 1
	
	input_field.text = command_history[history_index]
	input_field.caret_column = input_field.text.length()

func _history_next() -> void:
	if command_history.is_empty():
		return
	
	history_index -= 1
	if history_index < 0:
		history_index = -1
		input_field.clear()
	else:
		input_field.text = command_history[history_index]
		input_field.caret_column = input_field.text.length()
