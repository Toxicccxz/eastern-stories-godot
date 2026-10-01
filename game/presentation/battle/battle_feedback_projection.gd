class_name BattleFeedbackProjection
extends RefCounted

## Read-only value snapshot; retains no mutable gameplay authority.
var _progression_order: int
var progression_order: int:
	get: return _progression_order
var _lines: Array[BattleNarrationLine]
## The lines as the player reads them, without damage numbers.
var text: String:
	get:
		var texts := PackedStringArray()
		for line: BattleNarrationLine in _lines:
			texts.append(line.text)
		return "\n".join(texts)


func _init(
	p_progression_order: int = 0,
	p_lines: Array[BattleNarrationLine] = [],
) -> void:
	_progression_order = p_progression_order
	_lines = p_lines.duplicate()


func lines() -> Array[BattleNarrationLine]:
	return _lines.duplicate()
