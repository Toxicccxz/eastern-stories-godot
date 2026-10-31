class_name BattleNarrationLine
extends RefCounted

## One line of the battle log as the player reads it, plus the damage behind it
## (shown small and grey) when the line reports a blow, in the ES2 colour a command
## printed it in (ColoredLine); and, for a blow's own line, its short form (DECISIONS
## 「战斗界面」: 雪工 · 傲雪冬梅 → 野狗 −17 · 受伤不轻), "" for a line that has none.
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
var _summary: String
var summary: String:
	get: return _summary
var has_summary: bool:
	get: return not _summary.is_empty()


func _init(p_text: String = "", p_damage: int = -1, p_color: StringName = ColoredLine.PLAIN, p_summary: String = "") -> void:
	_text = p_text
	_damage = p_damage
	_color = p_color
	_summary = p_summary


## The full line, coloured, with its damage small and grey.
func rich_text() -> String:
	var escaped: String = _escape(_text)
	if SharedGameplayUI.ES2_COLORS.has(_color):
		escaped = "[color=#%s]%s[/color]" % [SharedGameplayUI.ES2_COLORS[_color].to_html(false), escaped]
	if not has_damage:
		return escaped
	# TRANSLATORS: a battle log line ({line}) and the damage behind it, shown small and grey.
	return TranslationServer.translate("{line} [color=#8b959e][font_size=12]（-{damage}）[/font_size][/color]").format({
		"line": escaped, "damage": _damage,
	})


## The short form, coloured as the line is (its damage is in its own words).
func summary_rich_text() -> String:
	var escaped: String = _escape(_summary)
	if SharedGameplayUI.ES2_COLORS.has(_color):
		escaped = "[color=#%s]%s[/color]" % [SharedGameplayUI.ES2_COLORS[_color].to_html(false), escaped]
	return escaped


## What the battle log panel prints: the short form with the full line small and grey
## under it when there is one, else the full line.
func log_rich_text() -> String:
	if not has_summary:
		return rich_text()
	return "%s\n[color=#8b959e][font_size=12]%s[/font_size][/color]" % [summary_rich_text(), _escape(_text)]


static func _escape(text: String) -> String:
	return text.replace("[", "[lb]")
