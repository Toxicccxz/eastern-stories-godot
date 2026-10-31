class_name CombatRoundModifiers
extends RefCounted

## The decision layer's standing modifiers for this round (DECISIONS「战斗决策」): per
## character, the percents the stance and a 守 move put on their attack power, damage,
## dodge and parry power, and the tag of the move they hold this round (the counter ring
## reads the defender's). The scheduler fills it each round; CombatSliceProjectionBuilder
## copies the values into the attack snapshots (inputs), the resolver applies them at
## combatd.c's percent sites. Empty: nothing changes.


class Fighter:
	extends RefCounted
	var attack_percent: int = 0
	var damage_percent: int = 0
	var dodge_percent: int = 0
	var parry_percent: int = 0
	var move_tag: StringName = &""

	func add(p_attack: int, p_damage: int, p_dodge: int, p_parry: int) -> Fighter:
		attack_percent += p_attack
		damage_percent += p_damage
		dodge_percent += p_dodge
		parry_percent += p_parry
		return self


var _sides: Dictionary[StringName, Fighter] = {}


func clear() -> void:
	_sides.clear()


func side(character_id: StringName) -> Fighter:
	if not _sides.has(character_id):
		_sides[character_id] = Fighter.new()
	return _sides[character_id]


## The side as it stands, or an empty one (never stored).
func read(character_id: StringName) -> Fighter:
	return _sides.get(character_id, Fighter.new())


func set_move_tag(character_id: StringName, tag: StringName) -> void:
	side(character_id).move_tag = tag


func is_empty() -> bool:
	return _sides.is_empty()
