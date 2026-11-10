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
## 战斗决策层 3 (DECISIONS「战斗演出」): the blow behind a blow's own line, for the cards'
## show — who struck, whom, the move's name, how it ended (CombatAttackResult.Outcome, -1
## for a line that is no blow), the band the one hit reads now (BattleVitalityBar.Band, -1
## for none) — and, on the first line of a perform / spell / exert, its name for the
## attacker's gold title. Set once by the narrator; read by the presentation only.
var _actor_id: StringName = &""
var actor_id: StringName:
	get: return _actor_id
var _target_id: StringName = &""
var target_id: StringName:
	get: return _target_id
var _move: String = ""
var move: String:
	get: return _move
var _outcome: int = -1
var outcome: int:
	get: return _outcome
var _band: int = -1
var band: int:
	get: return _band
var has_blow: bool:
	get: return _outcome >= 0 and not _actor_id.is_empty()
var _special_title: String = ""
var special_title: String:
	get: return _special_title
var is_special: bool:
	get: return not _special_title.is_empty()
## 战斗拍数 B (DECISIONS「战斗拍数」): which beat of its actor's round this line belongs to (1:
## the first; the reader counts them), and, for a line the strip folded (「又出两招 −12 −9」),
## the lines it stands for (empty for any other line).
var _beat_index: int = 1
var beat_index: int:
	get: return _beat_index
var _folded: Array[BattleNarrationLine] = []
var folded: Array[BattleNarrationLine]:
	get: return _folded
var is_folded: bool:
	get: return not _folded.is_empty()
## 战斗拍数 C (DECISIONS「战斗拍数 C」): for the scene's show and the sounds — the blow's move
## tag (快 / 重 / 虚 / 守, &"" for 平), the ring's verdict on it (1 克, -1 被克, 0 相持), whether
## it is one of a special's blows, and a cue a line that is no blow carries (CUE_EARNED: a
## beat won, 「抢得一手」).
const CUE_EARNED: StringName = &"earned"
## 战斗拍数 E: a 重 landed and threw its victim off balance (失衡); a 重 missed and left its
## striker open (露空). The line's actor is the one it befell.
const CUE_STAGGER: StringName = &"stagger"
const CUE_EXPOSED: StringName = &"exposed"
var _tag: StringName = &""
var tag: StringName:
	get: return _tag
var _ring: int = 0
var ring: int:
	get: return _ring
var _in_special: bool = false
var in_special: bool:
	get: return _in_special
var _cue: StringName = &""
var cue: StringName:
	get: return _cue
## 战斗演出 C (DECISIONS「战斗演出 C」): what the blow was struck with — the weapon's skill
## (sword, blade, whip …; &"" bare-handed) — and the wound it deals (刺伤, 瘀伤 …), for the move's
## name over the attacker's head and the blow's sounds.
var _weapon_skill: StringName = &""
var weapon_skill: StringName:
	get: return _weapon_skill
var _damage_type: String = ""
var damage_type: String:
	get: return _damage_type


func _init(p_text: String = "", p_damage: int = -1, p_color: StringName = ColoredLine.PLAIN, p_summary: String = "") -> void:
	_text = p_text
	_damage = p_damage
	_color = p_color
	_summary = p_summary


## The blow this line reports (the narrator, once).
func with_blow(p_actor_id: StringName, p_target_id: StringName, p_move: String, p_outcome: int, p_band: int) -> BattleNarrationLine:
	_actor_id = p_actor_id
	_target_id = p_target_id
	_move = p_move
	_outcome = p_outcome
	_band = p_band
	return self


## The blow's tag and the ring's verdict on it (the narrator, once).
func with_ring(p_tag: StringName, p_ring: int) -> BattleNarrationLine:
	_tag = p_tag
	_ring = p_ring
	return self


## What the blow was struck with and the wound it deals (the narrator, once).
func with_arms(p_weapon_skill: StringName, p_damage_type: String) -> BattleNarrationLine:
	_weapon_skill = p_weapon_skill
	_damage_type = p_damage_type
	return self


## The blow is one of a special's (the narrator, once).
func with_special_blow() -> BattleNarrationLine:
	_in_special = true
	return self


## A cue for the show on a line that is no blow (the narrator, once).
func with_cue(p_cue: StringName) -> BattleNarrationLine:
	_cue = p_cue
	return self


## The special this line opens (the narrator, once): `title` is its name as the player reads it.
func with_special(p_actor_id: StringName, title: String) -> BattleNarrationLine:
	_actor_id = p_actor_id
	_special_title = title
	return self


## The beat this line belongs to (the reader, once), and whose: a line that reports no blow
## (the action's own words, the status line) takes the beat's actor so the strip can fold the
## whole beat; a blow's line keeps its own.
func with_beat(index: int, actor: StringName = &"") -> BattleNarrationLine:
	_beat_index = maxi(1, index)
	if _actor_id.is_empty():
		_actor_id = actor
	return self


## The lines this folded line stands for (the strip, once).
func with_folded(lines: Array[BattleNarrationLine]) -> BattleNarrationLine:
	_folded = lines.duplicate()
	return self


## The full line, coloured, with its damage small and grey.
func rich_text() -> String:
	var escaped: String = _escape(_text)
	if SharedGameplayUI.ES2_COLORS.has(_color):
		escaped = "[color=#%s]%s[/color]" % [SharedGameplayUI.ES2_COLORS[_color].to_html(false), escaped]
	if not has_damage:
		return escaped
	# TRANSLATORS: a battle log line ({line}) and the damage behind it, shown grey.
	return TranslationServer.translate("{line} [color=#8b959e]（-{damage}）[/color]").format({
		"line": escaped, "damage": _damage,
	})


## The short form, coloured as the line is (its damage is in its own words).
func summary_rich_text() -> String:
	var escaped: String = _escape(_summary)
	if SharedGameplayUI.ES2_COLORS.has(_color):
		escaped = "[color=#%s]%s[/color]" % [SharedGameplayUI.ES2_COLORS[_color].to_html(false), escaped]
	return escaped


## What the battle log panel prints: the short form with the full line (its damage at its
## end, as everywhere) grey under it when there is one, else the full line.
func log_rich_text() -> String:
	if not has_summary:
		return rich_text()
	# TRANSLATORS: the full battle line under its short form in the log: {line} and its damage.
	var full: String = _escape(_text) if not has_damage else TranslationServer.translate("{line}（-{damage}）").format({"line": _escape(_text), "damage": _damage})
	return "%s\n[color=#8b959e]%s[/color]" % [summary_rich_text(), full]


static func _escape(text: String) -> String:
	return text.replace("[", "[lb]")
