class_name BattleBeatChips
extends Control

## 战斗拍数 B (DECISIONS「战斗拍数」): the player's beats this round as wooden chips lying in
## a shallow groove, in exchange order from the left — a timeline, not a meter. A beat spent
## takes the colour of what it went on (the move's tag, a perform, an order); one given up
## by 收势 or paid to busy is struck through with one ink stroke and greyed; a beat won
## slides in from the right as a gold-edged chip over feel.beat_chip_ms with where it came
## from (隙 / 压 / 连) written small beneath. Every value is the projection's
## (CombatRoundBeats); nothing here touches a rule.

const CHIP := Vector2(26, 16)
const GAP: float = 6.0
const PAD := Vector2(8, 5)
## The groove's height holds the chips and the small source word under a won one; closed
## up (a short screen) the word is left out.
const HEIGHT: float = 44.0
const COMPACT_HEIGHT: float = 28.0
const SLIDE_PX: float = 24.0
const GROOVE := Color(0.10, 0.07, 0.05, 0.85)
const GROOVE_EDGE := Color(0.32, 0.22, 0.14)
const WOOD := Color("b07a44")
const WOOD_SIDE := Color("6a4324")
const FREE_LINE := Color(0.95, 0.85, 0.65, 0.35)
const INK := Color("1d1612")
const STRUCK := Color("5e5852")
const GOLD := UiPalette.LANTERN
const SOURCE_TEXT := Color("f2d27a")
## What a spent beat is painted: the four tags, 平, a perform, an order, busy / wait.
const COLORS: Dictionary[StringName, Color] = {
	CombatMoveTags.QUICK: Color("4f8fb8"), CombatMoveTags.HEAVY: Color("a3301f"),
	CombatMoveTags.FEINT: Color("4f8f78"), CombatMoveTags.GUARD: Color("6f7a80"),
	CombatBeatRules.COST_PLAIN: Color("c9b48a"), CombatBeatRules.COST_STANCE: Color("7a6034"),
	CombatBeatRules.COST_EXERT: Color("7a6034"), CombatBeatRules.COST_ITEM: Color("7a6034"),
	CombatBeatRules.COST_FLEE: Color("7a6034"), CombatBeatRules.COST_CAST: Color("7a6034"),
}
const PERFORM_COLOR := Color("d9a441")
## The one character on a spent chip.
const GLYPHS: Dictionary[StringName, String] = {
	CombatBeatRules.COST_STANCE: "势", CombatBeatRules.COST_EXERT: "功", CombatBeatRules.COST_ITEM: "物",
	CombatBeatRules.COST_FLEE: "逃", CombatBeatRules.COST_CAST: "法",
}
const STRUCK_KEYS: Array[StringName] = [&"busy", &"wait", &"yielded"]
const FREE: StringName = &""
const YIELDED: StringName = &"yielded"

## The slots as last presented: each a key (what it went on; FREE for one still to spend,
## YIELDED for one given up), and which of them are won beats with their source.
var _slots: Array[StringName] = []
var _earned: Array[StringName] = []
var _base: int = 0
var _remaining: int = 0
## The slide of the newest won chips: 1 lying in the groove, 0 off to the right.
var _slide: float = 1.0
var _sliding_from: int = 0
var _slide_tween: Tween
var _font: Font
var _compact: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = GameTheme.pixel_font()
	custom_minimum_size = Vector2(PAD.x * 2 + CHIP.x * 2 + GAP, HEIGHT)


## A short screen: no line for the source word under a won chip.
func set_compact(on: bool) -> void:
	_compact = on
	custom_minimum_size.y = COMPACT_HEIGHT if on else HEIGHT
	queue_redraw()


## The beats as the projection has them (`rules` prices each spent key; a 重 covers two
## chips). `round_seconds`: feel.beat_chip_ms, the slide of a beat won (0: at once).
func present(beats: CombatRoundBeats, rules: CombatBeatRules, chip_seconds: float) -> void:
	var slots: Array[StringName] = []
	var earned: Array[StringName] = []
	var base: int = 0
	var remaining: int = 0
	if beats != null:
		base = beats.base
		remaining = beats.remaining
		earned = beats.earned.duplicate()
		var total: int = base + earned.size()
		for key: StringName in beats.spent:
			var cost: int = 1
			if rules != null and not STRUCK_KEYS.has(key):
				cost = rules.cost_of_action(key) if not CombatBeatRules.perform_of(key).is_empty() or COLORS.has(key) and not CombatMoveTags.ALL.has(key) and key != CombatBeatRules.COST_PLAIN else rules.cost_of_tag(CombatMoveTags.NONE if key == CombatBeatRules.COST_PLAIN else key)
			for _n: int in maxi(1, cost):
				if slots.size() < total:
					slots.append(key)
		for _n: int in beats.yielded:
			if slots.size() < total:
				slots.append(YIELDED)
		while slots.size() < total:
			slots.append(FREE)
	# A beat won since the last look slides in; a new round lies still.
	var fresh_round: bool = base != _base or slots.size() < _slots.size() or (not slots.is_empty() and _slots.size() > 0 and slots[0] == FREE and _slots[0] != FREE)
	if not fresh_round and earned.size() > _earned.size():
		_sliding_from = base + _earned.size()
		_start_slide(chip_seconds)
	elif fresh_round:
		_stop_slide()
	_slots = slots
	_earned = earned
	_base = base
	_remaining = remaining
	custom_minimum_size = Vector2(PAD.x * 2 + maxf(2, slots.size()) * CHIP.x + maxf(1, slots.size() - 1) * GAP, COMPACT_HEIGHT if _compact else HEIGHT)
	queue_redraw()


## The chips' keys in order (tests).
func slots() -> Array[StringName]:
	return _slots.duplicate()


func sliding() -> bool:
	return _slide < 1.0


func _start_slide(seconds: float) -> void:
	_stop_slide()
	if seconds <= 0.0:
		return
	_slide = 0.0
	_slide_tween = create_tween()
	_slide_tween.tween_method(func(value: float) -> void:
		_slide = value
		queue_redraw(), 0.0, 1.0, seconds).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)


func _stop_slide() -> void:
	if _slide_tween != null and _slide_tween.is_valid():
		_slide_tween.kill()
	_slide = 1.0
	_sliding_from = 0


func _draw() -> void:
	var groove := Rect2(Vector2(0, 2), Vector2(size.x, CHIP.y + PAD.y * 2))
	draw_rect(groove, GROOVE)
	draw_rect(groove, GROOVE_EDGE, false, 1.0)
	for index: int in _slots.size():
		var key: StringName = _slots[index]
		var at := Vector2(PAD.x + index * (CHIP.x + GAP), groove.position.y + PAD.y)
		var alpha: float = 1.0
		var won: bool = index >= _base
		if won and index >= _sliding_from and _slide < 1.0:
			at.x += (1.0 - _slide) * SLIDE_PX
			alpha = _slide
		var struck: bool = STRUCK_KEYS.has(key)
		var face: Color = WOOD
		var glyph: String = ""
		if struck:
			face = STRUCK
		elif key != FREE:
			face = _color_of(key)
			glyph = _glyph_of(key)
		var chip := Rect2(at, CHIP)
		draw_rect(Rect2(at + Vector2(0, 2), CHIP), Color(WOOD_SIDE, alpha))
		draw_rect(chip, Color(face, alpha))
		if key == FREE:
			draw_rect(Rect2(at + Vector2(3, 3), CHIP - Vector2(6, 6)), Color(FREE_LINE, alpha), false, 1.0)
		if won:
			draw_rect(chip, Color(GOLD, alpha), false, 2.0)
		if struck:
			draw_line(at + Vector2(2, CHIP.y - 2), at + Vector2(CHIP.x - 2, 2), Color(INK, alpha), 2.0)
		if not glyph.is_empty() and _font != null:
			var width: float = _font.get_string_size(glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
			draw_string(_font, at + Vector2((CHIP.x - width) * 0.5, CHIP.y - 3), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(UiPalette.BONE, alpha))
		if won and _font != null and not _compact:
			var source: StringName = _earned[index - _base] if index - _base < _earned.size() else &""
			var word: String = CombatSchoolSkeleton.EARN_LABELS.get(source, "")
			if not word.is_empty():
				word = TranslationServer.translate(word)
				var width: float = _font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
				draw_string(_font, Vector2(at.x + (CHIP.x - width) * 0.5, groove.end.y + 13), word, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(SOURCE_TEXT, alpha))


static func _color_of(key: StringName) -> Color:
	if not CombatBeatRules.perform_of(key).is_empty():
		return PERFORM_COLOR
	return COLORS.get(key, COLORS[CombatBeatRules.COST_PLAIN])


static func _glyph_of(key: StringName) -> String:
	var function_id: StringName = CombatBeatRules.perform_of(key)
	if not function_id.is_empty():
		var perform: PerformFunction = SpecialFunctions.perform(function_id)
		var label: String = "" if perform == null else TranslationServer.translate(perform.label)
		var name: String = CombatActionDefinition.name_in(label)
		return name.left(1) if not name.is_empty() else TranslationServer.translate("绝")
	if GLYPHS.has(key):
		return TranslationServer.translate(GLYPHS[key])
	return CombatMoveTags.label(CombatMoveTags.NONE if key == CombatBeatRules.COST_PLAIN else key)
