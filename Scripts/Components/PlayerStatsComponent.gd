extends Node
class_name PlayerStatsComponent

## Manages runtime player stats, health, stability, and equipment
## This is where current values are stored and modified during gameplay

signal health_changed(current: float, max: float, delta: float)
signal stability_changed(current: float, max: float, delta: float)
signal player_died
signal stats_initialized

# Data reference
var player_data: PlayerData

# Runtime stat values
var current_health: float
var current_stability: float
var is_dead: bool = false

# Equipped weapons (runtime state)
var equipped_primary_weapon: WeaponData = null
var equipped_secondary_weapon: WeaponData = null

# Stat modifiers (from buffs/status effects)
var damage_modifier: float = 1.0
var defense_modifier: float = 0.0
var speed_modifier: float = 1.0

# Stability regeneration
var stability_regen_timer: float = 0.0


func _ready():
	pass


func _process(delta: float) -> void:
	"""Process stats each frame for regeneration"""
	process_stats(delta)


func initialize(data: PlayerData) -> void:
	"""Initialize with player data"""
	if not data:
		push_error("PlayerStatsComponent: No PlayerData provided!")
		return
	
	player_data = data
	
	# Initialize runtime values from data
	current_health = player_data.max_health
	current_stability = player_data.max_stability
	is_dead = false
	
	print("[PlayerStats] Initialized - HP: ", current_health, "/", player_data.max_health, 
		  " Stability: ", current_stability, "/", player_data.max_stability)
	
	stats_initialized.emit()


func process_stats(delta: float) -> void:
	"""Process regeneration and stat updates"""
	if is_dead:
		return
	
	# Stability regeneration
	if stability_regen_timer > 0.0:
		stability_regen_timer -= delta
	else:
		# Regenerate stability
		if current_stability < player_data.max_stability:
			var regen_amount = 25.0 * delta  # 25 stability per second
			modify_stability(regen_amount)


func take_damage(amount: float) -> void:
	"""Apply simple damage to player (legacy - prefer take_damage_typed)"""
	if is_dead:
		return
	
	# Apply defense modifier
	var actual_damage = max(0.0, amount - defense_modifier)
	
	current_health -= actual_damage
	current_health = max(0.0, current_health)
	
	print("[PlayerStats] Took ", actual_damage, " damage. Health: ", current_health, "/", player_data.max_health)
	health_changed.emit(current_health, player_data.max_health, -actual_damage)
	
	if current_health <= 0.0 and not is_dead:
		die()


func take_damage_typed(damage: DamageTypes.DamageInstance) -> void:
	"""Apply typed damage to player with resistance calculations"""
	if is_dead:
		return
	
	# Get player resistances from PlayerData
	var resistances = player_data.get_resistance_set()
	
	# Apply resistances to incoming damage
	var modified_damage = resistances.apply_to_damage(damage)
	
	# Apply global defense modifier
	var total_damage = modified_damage.get_total_damage()
	var actual_damage = max(0.0, total_damage - defense_modifier) * damage_modifier
	
	current_health -= actual_damage
	current_health = max(0.0, current_health)
	
	# Log detailed damage breakdown
	print("[PlayerStats] Took typed damage:")
	if modified_damage.get_physical_total() > 0:
		print("  Physical: ", modified_damage.get_physical_total(), " (B:", modified_damage.blunt, " S:", modified_damage.slash, " P:", modified_damage.pierce, ")")
	if modified_damage.get_elemental_total() > 0:
		print("  Elemental: ", modified_damage.get_elemental_total(), " (F:", modified_damage.fire, " L:", modified_damage.lightning, " W:", modified_damage.water, " Soul:", modified_damage.soul, ")")
	if modified_damage.get_magic_total() > 0:
		print("  Magic: ", modified_damage.get_magic_total(), " (V:", modified_damage.void_, " A:", modified_damage.astral, ")")
	print("  Total after modifiers: ", actual_damage, " | Health: ", current_health, "/", player_data.max_health)
	
	health_changed.emit(current_health, player_data.max_health, -actual_damage)
	
	if current_health <= 0.0 and not is_dead:
		die()


func heal(amount: float) -> void:
	"""Heal the player"""
	if is_dead:
		return
	
	current_health += amount
	current_health = min(current_health, player_data.max_health)
	
	print("[PlayerStats] Healed ", amount, ". Health: ", current_health, "/", player_data.max_health)
	health_changed.emit(current_health, player_data.max_health, amount)


func spend_stability(amount: float) -> bool:
	"""Attempt to spend stability. Returns true if successful."""
	if is_dead:
		return false
	
	if current_stability >= amount:
		current_stability -= amount
		stability_regen_timer = 1.0  # Reset regen delay
		
		stability_changed.emit(current_stability, player_data.max_stability, -amount)
		return true
	else:
		print("[PlayerStats] Not enough stability! Need: ", amount, " Have: ", current_stability)
		return false


func modify_stability(amount: float) -> void:
	"""Directly modify stability (for regen or external effects)"""
	if is_dead:
		return
	
	current_stability += amount
	current_stability = clamp(current_stability, 0.0, player_data.max_stability)
	
	stability_changed.emit(current_stability, player_data.max_stability, amount)


func die() -> void:
	"""Handle player death"""
	is_dead = true
	current_health = 0.0
	print("[PlayerStats] Player died!")
	player_died.emit()


func revive(health_percent: float = 1.0) -> void:
	"""Revive the player"""
	is_dead = false
	current_health = player_data.max_health * health_percent
	current_stability = player_data.max_stability
	
	print("[PlayerStats] Player revived! Health: ", current_health)
	health_changed.emit(current_health, player_data.max_health, current_health)
	stability_changed.emit(current_stability, player_data.max_stability, current_stability)


func get_total_damage_multiplier() -> float:
	"""Calculate total outgoing damage multiplier from base stats + equipped weapon"""
	var base = player_data.strength / 10.0  # Strength 10 = 1x multiplier
	var total = base * damage_modifier * player_data.base_damage_multiplier
	
	# Add weapon damage if equipped (read from runtime state)
	if equipped_primary_weapon:
		total *= equipped_primary_weapon.damage / 10.0
	
	return total


func get_equipped_primary_weapon() -> WeaponData:
	"""Get currently equipped primary weapon"""
	return equipped_primary_weapon


func get_equipped_secondary_weapon() -> WeaponData:
	"""Get currently equipped secondary weapon"""
	return equipped_secondary_weapon


func get_health_percent() -> float:
	"""Get current health as percentage"""
	if player_data.max_health <= 0:
		return 0.0
	return current_health / player_data.max_health


func get_stability_percent() -> float:
	"""Get current stability as percentage"""
	if player_data.max_stability <= 0:
		return 0.0
	return current_stability / player_data.max_stability
