class_name BattleNarrationLine
extends RefCounted

## One line of the battle log as the player reads it, plus the damage behind it
## (shown small and grey) when the line reports a blow.
var _text: String
var text: String:
	get: return _text
var _damage: int
var damage: int:
	get: return _damage
var has_damage: bool:
	get: return _damage >= 0


func _init(p_text: String = "", p_damage: int = -1) -> void:
	_text = p_text
	_damage = p_damage


func rich_text() -> String:
	var escaped: String = _text.replace("[", "[lb]")
	if not has_damage:
		return escaped
	# TRANSLATORS: a battle log line ({line}) and the damage behind it, shown small and grey.
	return TranslationServer.translate("{line} [color=#8b959e][font_size=12]（-{damage}）[/font_size][/color]").format({
		"line": escaped, "damage": _damage,
	})
