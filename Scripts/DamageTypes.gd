extends Node
class_name DamageTypes

## Centralized damage type system for the entire game
## Defines all damage categories and provides utility functions

# Physical Damage Types
enum Physical {
	BLUNT = 0,
	SLASH = 1,
	PIERCE = 2
}

# Elemental Damage Types  
enum Elemental {
	FIRE = 0,
	LIGHTNING = 1,
	WATER = 2,
	SOUL = 3
}

# Magic Damage Types
enum Magic {
	VOID_ = 0,    # Chaos Magic (underscore to avoid 'void' keyword conflict)
	ASTRAL = 1    # Light Magic
}

# Damage category for grouping
enum Category {
	PHYSICAL,
	ELEMENTAL,
	MAGIC
}

# Damage instance structure - contains all damage type amounts
class DamageInstance:
	# Physical damage amounts
	var blunt: float = 0.0
	var slash: float = 0.0
	var pierce: float = 0.0
	
	# Elemental damage amounts
	var fire: float = 0.0
	var lightning: float = 0.0
	var water: float = 0.0
	var soul: float = 0.0
	
	# Magic damage amounts
	var void_: float = 0.0  # Underscore to avoid 'void' keyword conflict
	var astral: float = 0.0
	
	func _init():
		pass
	
	func get_total_damage() -> float:
		"""Calculate total damage across all types"""
		return blunt + slash + pierce + fire + lightning + water + soul + void_ + astral
	
	func get_physical_total() -> float:
		"""Get total physical damage"""
		return blunt + slash + pierce
	
	func get_elemental_total() -> float:
		"""Get total elemental damage"""
		return fire + lightning + water + soul
	
	func get_magic_total() -> float:
		"""Get total magic damage"""
		return void_ + astral
	
	func multiply_all(multiplier: float) -> void:
		"""Multiply all damage types by a value"""
		blunt *= multiplier
		slash *= multiplier
		pierce *= multiplier
		fire *= multiplier
		lightning *= multiplier
		water *= multiplier
		soul *= multiplier
		void_ *= multiplier
		astral *= multiplier
	
	func add_damage(other: DamageInstance) -> void:
		"""Add another damage instance to this one"""
		blunt += other.blunt
		slash += other.slash
		pierce += other.pierce
		fire += other.fire
		lightning += other.lightning
		water += other.water
		soul += other.soul
		void_ += other.void_
		astral += other.astral


# Resistance structure - mirrors DamageInstance but for defensive stats
class ResistanceSet:
	# Physical resistances (0.0 = no resistance, 1.0 = 100% reduction, -1.0 = 100% weakness)
	var blunt: float = 0.0
	var slash: float = 0.0
	var pierce: float = 0.0
	
	# Elemental resistances
	var fire: float = 0.0
	var lightning: float = 0.0
	var water: float = 0.0
	var soul: float = 0.0
	
	# Magic resistances
	var void_: float = 0.0  # Underscore to avoid 'void' keyword conflict
	var astral: float = 0.0
	
	func _init():
		pass
	
	func apply_to_damage(damage: DamageInstance) -> DamageInstance:
		"""Apply these resistances to a damage instance and return modified damage"""
		var result = DamageInstance.new()
		
		# Apply resistance formula: damage * (1 - resistance)
		# Resistance of 0.0 = full damage, 0.5 = half damage, 1.0 = no damage
		# Negative resistance = weakness (more damage taken)
		result.blunt = damage.blunt * (1.0 - blunt)
		result.slash = damage.slash * (1.0 - slash)
		result.pierce = damage.pierce * (1.0 - pierce)
		
		result.fire = damage.fire * (1.0 - fire)
		result.lightning = damage.lightning * (1.0 - lightning)
		result.water = damage.water * (1.0 - water)
		result.soul = damage.soul * (1.0 - soul)
		
		result.void_ = damage.void_ * (1.0 - void_)
		result.astral = damage.astral * (1.0 - astral)
		
		return result
	
	func set_all_physical(value: float) -> void:
		"""Set all physical resistances to the same value"""
		blunt = value
		slash = value
		pierce = value
	
	func set_all_elemental(value: float) -> void:
		"""Set all elemental resistances to the same value"""
		fire = value
		lightning = value
		water = value
		soul = value
	
	func set_all_magic(value: float) -> void:
		"""Set all magic resistances to the same value"""
		void_ = value
		astral = value


# Utility functions
static func get_physical_type_name(type: Physical) -> String:
	"""Get display name for physical damage type"""
	match type:
		Physical.BLUNT: return "Blunt"
		Physical.SLASH: return "Slash"
		Physical.PIERCE: return "Pierce"
		_: return "Unknown"


static func get_elemental_type_name(type: Elemental) -> String:
	"""Get display name for elemental damage type"""
	match type:
		Elemental.FIRE: return "Fire"
		Elemental.LIGHTNING: return "Lightning"
		Elemental.WATER: return "Water"
		Elemental.SOUL: return "Soul"
		_: return "Unknown"


static func get_magic_type_name(type: Magic) -> String:
	"""Get display name for magic damage type"""
	match type:
		Magic.VOID_: return "Void"
		Magic.ASTRAL: return "Astral"
		_: return "Unknown"


static func create_simple_damage(amount: float, physical_type: Physical) -> DamageInstance:
	"""Create a simple physical damage instance"""
	var damage = DamageInstance.new()
	match physical_type:
		Physical.BLUNT: damage.blunt = amount
		Physical.SLASH: damage.slash = amount
		Physical.PIERCE: damage.pierce = amount
	return damage
