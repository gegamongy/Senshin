class_name BossData
extends EnemyData

@export var boss_title: String = "The Unknown"  # e.g., "The Whisper"
@export var boss_lore: String = ""

# Arena
@export_file("*.tscn") var arena_scene_path: String

# Phase system
@export var phase_count: int = 1
@export var phase_health_thresholds: Array[float] = []  # Health % to trigger phases (e.g., [0.75, 0.5, 0.25])

# Abilities/Attacks
@export var abilities: Array[Resource] = []  # Future: ability resources

# Rewards
@export var spirit_seals: Array[Resource] = []  # Special boss drops
@export var guaranteed_weapon: WeaponData = null
@export var guaranteed_clothing: Array[ClothingItem] = []

func _init():
	enemy_type = EnemyType.BOSS
	max_health = 1000.0  # Bosses have much more health
