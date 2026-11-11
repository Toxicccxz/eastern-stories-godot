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
	## 战斗拍数 E: this fighter's beat runs now — its own blow is the beat's (CombatAttackerSnapshot.beat_blow).
	var beat_blow: bool = false

	func add(p_attack: int, p_damage: int, p_dodge: int, p_parry: int) -> Fighter:
		attack_percent += p_attack
		damage_percent += p_damage
		dodge_percent += p_dodge
		parry_percent += p_parry
		return self


var _sides: Dictionary[StringName, Fighter] = {}
## 战斗拍数 D: a lesson's blows (CombatEncounterMode.LESSON) land but draw no blood: the
## resolver takes the damage to 0 and rolls no wound (CombatAttackerSnapshot.harmless).
var harmless: bool = false
## A story trial's blows (NpcTrial.inner_force_percent / lethal, DECISIONS「考验三招」): only
## this percent of the force hook's bonus (and its force wound) counts, and no blow of the
## exchange leaves a wound or a condition: what would have wounded takes kee instead, so the one
## who fails falls and wakes, and a full rest makes them whole.
var inner_force_percent: int = 100
var spare_life: bool = false


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
