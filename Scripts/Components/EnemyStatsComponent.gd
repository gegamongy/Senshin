extends Node
class_name EnemyStatsComponent

## Manages runtime enemy stats, health, stability, and status effects
## Mirrors PlayerStatsComponent structure for consistency

signal health_changed(current: float, max: float, delta: float)
signal stability_changed(current: float, max: float, delta: float)
signal enemy_died
signal damage_taken(amount: float, damage_type: String)

# Enemy data reference
var enemy_data: EnemyData

# Current runtime values
var current_health: float
var current_stability: float = 100.0  # Enemies can have posture/stability too
var is_dead: bool = false

# Stat modifiers (from buffs, debuffs, etc.)
var damage_modifier: float = 1.0  # Multiplier for outgoing damage
var defense_modifier: float = 0.0  # Flat damage reduction
var speed_modifier: float = 1.0  # Movement speed multiplier

# Poise/stagger system
var max_poise: float = 100.0  # How much damage before stagger
var current_poise: float = 100.0
var poise_regen_rate: float = 20.0  # Poise per second


func _ready():
	pass


func initialize(data: EnemyData) -> void:
	"""Initialize with EnemyData resource"""
	enemy_data = data
	
	if not enemy_data:
		push_error("EnemyStatsComponent: No EnemyData provided!")
		return
	
	# Initialize current values from data
	current_health = enemy_data.max_health
	current_stability = 100.0
	current_poise = max_poise
	is_dead = false
	
	print("[EnemyStats] Initialized - ", enemy_data.enemy_name, 
		  " Health: ", current_health, "/", enemy_data.max_health)


func _process(delta: float) -> void:
	"""Handle regeneration"""
	if is_dead:
		return
	
	# Regenerate poise
	if current_poise < max_poise:
		current_poise = min(max_poise, current_poise + poise_regen_rate * delta)


func take_damage(amount: float, damage_type: String = "physical") -> float:
	"""Apply simple damage to enemy (legacy - prefer take_damage_typed). Returns actual damage dealt."""
	if is_dead:
		return 0.0
	
	# Apply defense modifier
	var actual_damage = max(0.0, amount - defense_modifier)
	
	# Reduce health
	var old_health = current_health
	current_health = max(0.0, current_health - actual_damage)
	
	print("[EnemyStats] ", enemy_data.enemy_name, " took ", actual_damage, 
		  " damage. Health: ", current_health, "/", enemy_data.max_health)
	
	# Emit signals
	health_changed.emit(current_health, enemy_data.max_health, -(actual_damage))
	damage_taken.emit(actual_damage, damage_type)
	
	# Reduce poise
	current_poise = max(0.0, current_poise - actual_damage * 0.5)
	
	# Check for death
	if current_health <= 0.0 and not is_dead:
		die()
	
	return actual_damage


func take_damage_typed(damage: DamageTypes.DamageInstance) -> float:
	"""Apply typed damage to enemy with resistance calculations. Returns actual damage dealt."""
	if is_dead:
		return 0.0
	
	# Get enemy resistances from EnemyData
	var resistances = enemy_data.get_resistance_set()
	
	# Apply resistances to incoming damage
	var modified_damage = resistances.apply_to_damage(damage)
	
	# Apply global defense modifier
	var total_damage = modified_damage.get_total_damage()
	var actual_damage = max(0.0, total_damage - defense_modifier)
	
	# Reduce health
	current_health = max(0.0, current_health - actual_damage)
	
	# Log detailed damage breakdown
	print("[EnemyStats] ", enemy_data.enemy_name, " took typed damage:")
	if modified_damage.get_physical_total() > 0:
		print("  Physical: ", modified_damage.get_physical_total(), " (B:", modified_damage.blunt, " S:", modified_damage.slash, " P:", modified_damage.pierce, ")")
	if modified_damage.get_elemental_total() > 0:
		print("  Elemental: ", modified_damage.get_elemental_total(), " (F:", modified_damage.fire, " L:", modified_damage.lightning, " W:", modified_damage.water, " Soul:", modified_damage.soul, ")")
	if modified_damage.get_magic_total() > 0:
		print("  Magic: ", modified_damage.get_magic_total(), " (V:", modified_damage.void_, " A:", modified_damage.astral, ")")
	print("  Total after modifiers: ", actual_damage, " | Health: ", current_health, "/", enemy_data.max_health)
	
	# Emit signals
	health_changed.emit(current_health, enemy_data.max_health, -actual_damage)
	damage_taken.emit(actual_damage, "typed")
	
	# Reduce poise based on damage dealt
	current_poise = max(0.0, current_poise - actual_damage * 0.5)
	
	# Check for death
	if current_health <= 0.0 and not is_dead:
		die()
	
	return actual_damage


func take_poise_damage(amount: float) -> bool:
	"""Take poise damage. Returns true if staggered (poise broken)"""
	if is_dead:
		return false
	
	current_poise = max(0.0, current_poise - amount)
	
	if current_poise <= 0.0:
		# Staggered - reset poise
		current_poise = max_poise
		return true
	
	return false


func die() -> void:
	"""Handle enemy death"""
	if is_dead:
		return
	
	is_dead = true
	print("[EnemyStats] ", enemy_data.enemy_name, " died")
	enemy_died.emit()


func get_total_damage() -> float:
	"""Get total damage output from base stats + modifiers"""
	return enemy_data.damage * damage_modifier


func get_current_health_percent() -> float:
	"""Get current health as percentage (0.0 to 1.0)"""
	if enemy_data.max_health <= 0:
		return 0.0
	return current_health / enemy_data.max_health


func get_current_poise_percent() -> float:
	"""Get current poise as percentage (0.0 to 1.0)"""
	if max_poise <= 0:
		return 0.0
	return current_poise / max_poise
