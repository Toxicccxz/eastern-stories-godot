class_name SpecialReport
extends RefCounted

## What one special file run in a fight showed and did, for the battle log and the
## fight's lifecycle: its message_vision() lines, the attacks it made (each after
## `line_index` lines), and whom it hurt itself (their last_damage_from is `me_id`).
## Read-only once made.
var me_id: StringName
var _lines: Array[VisionLine] = []
var _attacks: Array[SpecialAttack] = []
var _damaged: Array[StringName] = []


func _init(
	p_me_id: StringName = &"", p_lines: Array[VisionLine] = [], p_attacks: Array[SpecialAttack] = [],
	p_damaged: Array[StringName] = [],
) -> void:
	me_id = p_me_id
	_lines = p_lines.duplicate()
	_attacks = p_attacks.duplicate()
	_damaged = p_damaged.duplicate()


func lines() -> Array[VisionLine]:
	return _lines.duplicate()


func attacks() -> Array[SpecialAttack]:
	return _attacks.duplicate()


func damaged() -> Array[StringName]:
	return _damaged.duplicate()


func is_empty() -> bool:
	return _lines.is_empty() and _attacks.is_empty() and _damaged.is_empty()


## Every attack ran to the end.
func is_complete() -> bool:
	for attack: SpecialAttack in _attacks:
		if not attack.is_complete():
			return false
	return true


## damage.c last_damage_from for `character_id`: the last attack that hit them, else
## the performer when the file hurt them, else empty.
func last_hitter(character_id: StringName) -> StringName:
	for index: int in range(_attacks.size() - 1, -1, -1):
		var hitter: StringName = _attacks[index].last_hitter(character_id)
		if not hitter.is_empty():
			return hitter
	return me_id if _damaged.has(character_id) else &""
