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

# Damage Resistances (0.0 = normal damage, 0.5 = half damage, 1.0 = immune, -0.5 = 50% more damage)
@export_group("Physical Resistances")
@export_range(-1.0, 1.0, 0.05) var blunt_resistance: float = 0.0
@export_range(-1.0, 1.0, 0.05) var slash_resistance: float = 0.0
@export_range(-1.0, 1.0, 0.05) var pierce_resistance: float = 0.0

@export_group("Elemental Resistances")
@export_range(-1.0, 1.0, 0.05) var fire_resistance: float = 0.0
@export_range(-1.0, 1.0, 0.05) var lightning_resistance: float = 0.0
@export_range(-1.0, 1.0, 0.05) var water_resistance: float = 0.0
@export_range(-1.0, 1.0, 0.05) var soul_resistance: float = 0.0

@export_group("Magic Resistances")
@export_range(-1.0, 1.0, 0.05) var void_resistance: float = 0.0  # Void/Chaos magic resistance
@export_range(-1.0, 1.0, 0.05) var astral_resistance: float = 0.0  # Astral/Light magic resistance

func get_resistance_set() -> DamageTypes.ResistanceSet:
	"""Create a ResistanceSet from this player's resistance values"""
	var resistances = DamageTypes.ResistanceSet.new()
	
	# Physical
	resistances.blunt = blunt_resistance
	resistances.slash = slash_resistance
	resistances.pierce = pierce_resistance
	
	# Elemental
	resistances.fire = fire_resistance
	resistances.lightning = lightning_resistance
	resistances.water = water_resistance
	resistances.soul = soul_resistance
	
	# Magic
	resistances.void = void_resistance
	resistances.astral = astral_resistance
	
	return resistances
