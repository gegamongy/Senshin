class_name PlayerData
extends Resource

## Player base stats configuration - this is the data template, not runtime state

# Core Stats
@export var max_health: float = 100.0
@export var max_stability: float = 100.0  # Stamina/poise system
@export var strength: float = 10.0  # Base damage modifier

# Movement speeds
@export var base_walk_speed: float = 5.0
@export var base_run_speed: float = 10.0
@export var base_sprint_speed: float = 15.0

# Combat parameters
@export var light_attack_speed_scale: float = 1.0  # Animation speed multiplier
@export var combo_window_percentage: float = 0.8  # When combo window opens (0.8 = last 20%)

# Regeneration
@export var stability_regen_rate: float = 25.0  # Per second
@export var stability_regen_delay: float = 1.0  # Delay after spending stability
