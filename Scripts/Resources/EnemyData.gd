class_name EnemyData
extends Resource

enum EnemyType { BASIC, SPECIAL, BOSS }

@export var enemy_name: String = "Enemy"
@export var enemy_type: EnemyType = EnemyType.BASIC
@export var max_health: float = 100.0
@export var damage: float = 10.0
@export var move_speed: float = 5.0
@export var detection_range: float = 15.0
@export var attack_range: float = 2.0

# Variants - mesh/skeleton packed scenes
@export var variants: Array[PackedScene] = []

# Loot system
@export var guaranteed_drops: Array[Item] = []
@export var possible_drops: Array[Item] = []
@export var drop_chances: Array[float] = []  # Corresponding chances for possible_drops

# Animation
@export var anim_library: AnimationLibrary
