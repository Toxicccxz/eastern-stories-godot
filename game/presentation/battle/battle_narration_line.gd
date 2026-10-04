class_name BattleNarrationLine
extends RefCounted

## One line of the battle log as the player reads it, plus the damage behind it
## (shown small and grey) when the line reports a blow, in the ES2 colour a command
## printed it in (ColoredLine).
var _text: String
var text: String:
	get: return _text
var _damage: int
var damage: int:
	get: return _damage
var has_damage: bool:
	get: return _damage >= 0
var _color: StringName
var color: StringName:
	get: return _color


func _init(p_text: String = "", p_damage: int = -1, p_color: StringName = ColoredLine.PLAIN) -> void:
	_text = p_text
	_damage = p_damage
	_color = p_color


func rich_text() -> String:
	var escaped: String = _text.replace("[", "[lb]")
	if SharedGameplayUI.ES2_COLORS.has(_color):
		escaped = "[color=#%s]%s[/color]" % [SharedGameplayUI.ES2_COLORS[_color].to_html(false), escaped]
	if not has_damage:
		return escaped
	# TRANSLATORS: a battle log line ({line}) and the damage behind it, shown small and grey.
	return TranslationServer.translate("{line} [color=#8b959e][font_size=12]（-{damage}）[/font_size][/color]").format({
		"line": escaped, "damage": _damage,
	})
