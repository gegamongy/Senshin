class_name EnemyData
extends Resource

enum EnemyType { BASIC, SPECIAL, BOSS }

@export var enemy_name: String = "Enemy"
@export var enemy_type: EnemyType = EnemyType.BASIC
@export var max_health: float = 100.0
@export var move_speed: float = 5.0
@export var detection_range: float = 15.0
@export var attack_range: float = 2.0

# Legacy damage (kept for backward compatibility)
@export var damage: float = 10.0

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

# Variants - mesh/skeleton packed scenes
@export var variants: Array[PackedScene] = []

# Loot system
@export var guaranteed_drops: Array[Item] = []
@export var possible_drops: Array[Item] = []
@export var drop_chances: Array[float] = []  # Corresponding chances for possible_drops

# Animation
@export var anim_library: AnimationLibrary


func get_resistance_set() -> DamageTypes.ResistanceSet:
	"""Create a ResistanceSet from this enemy's resistance values"""
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
