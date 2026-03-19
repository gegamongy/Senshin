# Developer Console System

## Overview
A Minecraft-style developer console for debugging and testing your game. Press the backtick key (`` ` ``) to toggle the console.

## Built-in Commands

### `help` 
Display list of available commands or help for a specific command.
- Usage: `help` or `help <command>`
- Examples:
  - `help` - Show all commands
  - `help timescale` - Show help for timescale command
  - `timescale help` - Alternative syntax

### `clear`
Clear the console output.
- Usage: `clear`

### `echo`
Print text to console.
- Usage: `echo <text>`
- Example: `echo Hello, World!`

### `quit`
Exit the game.
- Usage: `quit`

### `fps`
Toggle FPS display or set it explicitly.
- Usage: `fps [on|off]`
- Examples:
  - `fps` - Toggle FPS display
  - `fps on` - Enable FPS display
  - `fps off` - Disable FPS display

### `timescale`
Set game time scale for slow motion or fast forward.
- Usage: `timescale <value>`
- Examples:
  - `timescale 0.5` - Slow motion (50% speed)
  - `timescale 2.0` - Fast forward (200% speed)
  - `timescale 1.0` - Normal speed
  - `timescale` - Show current timescale

## Console Controls

- **Backtick (`` ` ``)**: Toggle console
- **Enter**: Execute command
- **Escape**: Close console
- **Up Arrow**: Previous command in history
- **Down Arrow**: Next command in history

## Adding Custom Commands

You can register custom commands from any script in your game:

### Basic Example

```gdscript
func _ready():
    # Register a simple command
    ConsoleManager.register_command(
        "test",                              # Command name
        "Run a test function",               # Description
        "test",                              # Usage string
        _console_test                        # Callback function
    )

func _console_test(args: Array) -> void:
    ConsoleManager.output_success("Test command executed!")
```

### Advanced Example with Arguments

```gdscript
func _ready():
    # Register a command with arguments
    ConsoleManager.register_command(
        "teleport",
        "Teleport player to coordinates",
        "teleport <x> <y> <z>",
        _console_teleport
    )

func _console_teleport(args: Array) -> void:
    if args.size() < 3:
        ConsoleManager.output_warning("Usage: teleport <x> <y> <z>")
        return
    
    var x = args[0].to_float()
    var y = args[1].to_float()
    var z = args[2].to_float()
    
    player.global_position = Vector3(x, y, z)
    ConsoleManager.output_success("Teleported to (%s, %s, %s)" % [x, y, z])
```

### Example: Debug Commands for Your Game

```gdscript
# In PlayerController.gd or a debug script
func _ready():
    _register_debug_commands()

func _register_debug_commands():
    ConsoleManager.register_command(
        "godmode",
        "Toggle invincibility",
        "godmode [on|off]",
        _console_godmode
    )
    
    ConsoleManager.register_command(
        "heal",
        "Restore player health",
        "heal [amount]",
        _console_heal
    )
    
    ConsoleManager.register_command(
        "give",
        "Give player an item",
        "give <item_id> [amount]",
        _console_give_item
    )

func _console_godmode(args: Array):
    if args.size() == 0:
        stats.invincible = !stats.invincible
    else:
        stats.invincible = (args[0].to_lower() == "on")
    
    var status = "enabled" if stats.invincible else "disabled"
    ConsoleManager.output_success("God mode %s" % status)

func _console_heal(args: Array):
    var amount = stats.max_health
    if args.size() > 0:
        amount = args[0].to_float()
    
    stats.heal(amount)
    ConsoleManager.output_success("Healed %s HP" % amount)

func _console_give_item(args: Array):
    if args.size() == 0:
        ConsoleManager.output_warning("Usage: give <item_id> [amount]")
        return
    
    var item_id = args[0]
    var amount = 1
    if args.size() > 1:
        amount = args[1].to_int()
    
    InventoryManager.add_item(item_id, amount)
    ConsoleManager.output_success("Gave %d x %s" % [amount, item_id])
```

## Output Methods

ConsoleManager provides several output methods with color coding:

```gdscript
ConsoleManager.output_text("Normal text")
ConsoleManager.output_success("Success message (green)")
ConsoleManager.output_error("Error message (red)")
ConsoleManager.output_warning("Warning message (yellow)")
```

## Unregistering Commands

```gdscript
ConsoleManager.unregister_command("command_name")
```

## Best Practices

1. **Register commands in `_ready()`**: Ensure commands are available as soon as the game starts
2. **Validate arguments**: Always check argument count and types before using them
3. **Provide helpful usage messages**: Make it easy for users to understand command syntax
4. **Use descriptive names**: Command names should be clear and intuitive
5. **Provide feedback**: Use output methods to confirm command execution

## Debugging Tips

- Use the console to test game mechanics without restarting
- Create commands for common testing scenarios (spawn enemies, complete levels, etc.)
- Add commands to modify player stats during playtesting
- Use the echo command to debug variable values
- Leverage timescale for frame-by-frame analysis

## Example: Complete Debug System

Here's a complete example of a debug manager that adds many useful commands:

```gdscript
# DebugManager.gd (add as autoload)
extends Node

func _ready():
    _register_all_commands()

func _register_all_commands():
    # Player commands
    ConsoleManager.register_command("godmode", "Toggle invincibility", "godmode [on|off]", _cmd_godmode)
    ConsoleManager.register_command("noclip", "Toggle collision", "noclip [on|off]", _cmd_noclip)
    ConsoleManager.register_command("fly", "Toggle flying", "fly [on|off]", _cmd_fly)
    ConsoleManager.register_command("kill", "Kill player", "kill", _cmd_kill)
    ConsoleManager.register_command("heal", "Heal player", "heal [amount]", _cmd_heal)
    
    # World commands
    ConsoleManager.register_command("spawn", "Spawn an enemy", "spawn <enemy_type>", _cmd_spawn)
    ConsoleManager.register_command("clear_enemies", "Remove all enemies", "clear_enemies", _cmd_clear_enemies)
    
    # System commands
    ConsoleManager.register_command("reload", "Reload current scene", "reload", _cmd_reload)
    ConsoleManager.register_command("load", "Load a scene", "load <scene_path>", _cmd_load)

# Implement command functions...
func _cmd_godmode(args: Array): pass
# ... etc
```

## Notes

- The console is rendered on layer 128 (highest priority)
- Command history stores up to 50 commands
- Output is limited to 500 lines to prevent memory issues
- Commands are case-insensitive
- Command execution emits `command_executed` signal for logging
