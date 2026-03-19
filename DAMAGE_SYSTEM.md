# Damage Type System - Usage Guide

## Overview
The damage type system provides typed damage calculations with resistances across three categories:
- **Physical**: Blunt, Slash, Pierce
- **Elemental**: Fire, Lightning, Water, Soul
- **Magic**: Void (Chaos), Astral (Light)

**Note**: Due to GDScript's reserved `void` keyword, internal variables use `void_` with an underscore. In weapon/player data exports, it's named `void_damage` and `void_resistance` respectively.

## File Locations
- **Core System**: `Scripts/DamageTypes.gd`
- **Weapon Data**: `Scripts/WeaponData.gd`
- **Player/Enemy Data**: `Scripts/Resources/PlayerData.gd`, `Scripts/Resources/EnemyData.gd`
- **Stats Components**: `Scripts/Components/PlayerStatsComponent.gd`, `Scripts/Components/EnemyStatsComponent.gd`

## How to Use

### 1. Setting Up Weapon Damage
In your weapon resource (e.g., Starting Katana):
```gdscript
# Physical Damage section
slash_damage = 15.0  # Katanas do slash damage
blunt_damage = 0.0
pierce_damage = 0.0

# Elemental Damage (optional)
fire_damage = 5.0  # Flaming katana!

# Magic Damage (optional)
void_damage = 0.0
```

### 2. Setting Up Resistances
In PlayerData or EnemyData resources:
```gdscript
# Example: Tank character resistant to physical but weak to magic
blunt_resistance = 0.3    # 30% reduction to blunt damage
slash_resistance = 0.2    # 20% reduction to slash damage
pierce_resistance = 0.25  # 25% reduction to pierce damage

void_resistance = -0.5    # 50% MORE damage from void (weakness)
```

Resistance values:
- `0.0` = Normal damage
- `0.5` = 50% damage reduction (half damage)
- `1.0` = Immune (no damage)
- `-0.5` = 50% more damage (weakness)

### 3. Dealing Damage (Simple Method - Legacy)
```gdscript
# Still works - uses old damage system
enemy.stats_component.take_damage(25.0)
```

### 4. Dealing Damage (Typed - Recommended)
```gdscript
# Create damage instance from weapon
var weapon_damage = weapon_data.get_damage_instance()

# Apply strength/damage multipliers
weapon_damage.multiply_all(strength_multiplier)

# Deal typed damage with resistance calculations
enemy.stats_component.take_damage_typed(weapon_damage)
```

### 5. Custom Damage Creation
```gdscript
# Create custom damage
var damage = DamageTypes.DamageInstance.new()
damage.slash = 20.0
damage.fire = 10.0
damage.void_ = 5.0  # Note: underscore to avoid 'void' keyword conflict

# Or use helper for simple physical damage
var simple_damage = DamageTypes.create_simple_damage(25.0, DamageTypes.Physical.BLUNT)

# Apply to target
target.stats_component.take_damage_typed(damage)
```

### 6. Querying Damage Totals
```gdscript
var damage = weapon.get_damage_instance()

var total = damage.get_total_damage()      # All damage types combined
var physical = damage.get_physical_total()  # Blunt + Slash + Pierce
var elemental = damage.get_elemental_total() # Fire + Lightning + Water + Soul
var magic = damage.get_magic_total()       # Void + Astral
```

## Example Combat Flow

```gdscript
# In PlayerCombatComponent when landing an attack:

func deal_weapon_damage_to_enemy(enemy: EnemyBase) -> void:
	# Get weapon damage instance
	var base_damage = equipped_weapon.get_damage_instance()
	
	# Apply player's strength modifier
	var strength_mult = player_stats.get_total_damage_multiplier()
	base_damage.multiply_all(strength_mult)
	
	# Deal typed damage (resistances applied automatically)
	var actual_damage = enemy.stats_component.take_damage_typed(base_damage)
	
	print("Dealt ", actual_damage, " damage to ", enemy.enemy_name)
```

## Benefits of This System

1. **Modular**: Easy to add new damage types by extending the enums
2. **Balanced**: Resistances work consistently across all damage types
3. **Flexible**: Supports mixed damage (e.g., fire sword with slash + fire)
4. **Detailed**: Comprehensive damage logging for debugging
5. **Backward Compatible**: Old `take_damage(float)` still works

## Future Enhancements

- Status effects (burning, frozen, etc.)
- Damage over time (DOT) tracking per type
- Critical hits with type-specific multipliers
- Buff/debuff system that modifies resistances
- Elemental reactions (e.g., water + lightning = extra damage)
