class_name BattleBeatChips
extends Control

## 战斗拍数 B (DECISIONS「战斗拍数」), 战斗界面第二轮 (DECISIONS「战斗界面 · 节拍条」): the player's
## beats this round (手, as the player reads them) as wooden slots lying in one groove above
## the moves, in exchange order from the left — a timeline, not a meter. A beat spent takes
## the colour and the one character of what it went on (the move's tag, a perform, an order);
## a move that cost two lies over its two slots as one long slot; one given up by 收势 or paid
## to busy is struck through with one ink stroke and greyed; a beat won slides in from the
## right as a gold-edged slot over feel.beat_chip_ms with where it came from (隙 / 压 / 连)
## written small in its corner. While the school can still win a beat this round a dashed gold slot
## stands after the others with how it is won written inside (set_earnable). The slot the
## player's next beat takes has a gold edge and a small triangle (set_cursor); pointing at a
## move lays its ghost over the slots it would take, red where the beats cannot pay
## (set_preview). Every value is the projection's (CombatRoundBeats) or the panel's; nothing
## here touches a rule.
##
## 节拍填格 (DECISIONS「节拍填格」): a move pressed holds its slots as spent from the press
## (`hold`) — the panel's fill plays over them — and the strip stays as it was until the fill is
## full (`release`): a beat resolved the next frame, or a round that closed with it, shows only
## then. The hold goes once the record has a beat there, a new round comes, or PENDING_SECONDS
## pass.

const CHIP := Vector2(96, 44)
const COMPACT_CHIP := Vector2(56, 28)
const GAP: float = 10.0
const COMPACT_GAP: float = 6.0
const PAD := Vector2(8, 5)
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
const SHORT := Color("c0392b")
## What a spent beat is painted: the four tags, 平, a perform, an order, busy / wait.
const COLORS: Dictionary[StringName, Color] = {
	CombatMoveTags.QUICK: Color("4f8fb8"), CombatMoveTags.HEAVY: Color("a3301f"),
	CombatMoveTags.FEINT: Color("4f8f78"), CombatMoveTags.GUARD: Color("6f7a80"),
	CombatBeatRules.COST_PLAIN: Color("c9b48a"), CombatBeatRules.COST_STANCE: Color("7a6034"),
	CombatBeatRules.COST_EXERT: Color("7a6034"), CombatBeatRules.COST_ITEM: Color("7a6034"),
	CombatBeatRules.COST_FLEE: Color("7a6034"), CombatBeatRules.COST_CAST: Color("7a6034"),
}
const PERFORM_COLOR := Color("d9a441")
## The one character on a spent slot.
const GLYPHS: Dictionary[StringName, String] = {
	CombatBeatRules.COST_STANCE: "势", CombatBeatRules.COST_EXERT: "功", CombatBeatRules.COST_ITEM: "物",
	CombatBeatRules.COST_FLEE: "逃", CombatBeatRules.COST_CAST: "法",
}
const STRUCK_KEYS: Array[StringName] = [&"busy", &"wait", &"yielded"]
## A pressed move's slots wait this long at most for the record to show them spent.
const PENDING_SECONDS: float = 3.0
const FREE: StringName = &""
const YIELDED: StringName = &"yielded"

## The slots as last presented: each a key (what it went on; FREE for one still to spend,
## YIELDED for one given up), and which of them are won beats with their source; `_spans`
## the runs of slots one spending covers ([first, count]).
var _slots: Array[StringName] = []
var _spans: Array[Vector2i] = []
var _earned: Array[StringName] = []
var _base: int = 0
var _remaining: int = 0
## The dashed slot after the others and the words under it ("" none).
var _earnable: bool = false
var _earn_hint: String = ""
var _cursor: bool = false
## The ghost: how many slots, in what colour, whether the beats pay for it (0: none).
var _preview_cost: int = 0
var _preview_color: Color = Color.WHITE
var _preview_ok: bool = true
## The slide of the newest won slots: 1 lying in the groove, 0 off to the right.
var _slide: float = 1.0
var _sliding_from: int = 0
var _slide_tween: Tween
var _font: Font
var _compact: bool = false
## 节拍填格: a pressed move's slots before the record has them — from `_pending_first`,
## `_pending_count` long, on `_pending_key` — and how long they may still wait.
var _pending_first: int = -1
var _pending_count: int = 0
var _pending_key: StringName = FREE
var _pending_left: float = 0.0
## While a fill plays the strip stays as it was; the record's last look waits here ([beats,
## rules, chip_seconds], empty: none).
var _frozen: bool = false
var _latest: Array = []
## The last round's record as last looked at, and as it was at the press (another since: the
## round closed, the hold goes).
var _last_seen: CombatRoundBeats = null
var _hold_last: CombatRoundBeats = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = GameTheme.pixel_font()
	_fit()
	set_process(false)


## 节拍填格: a pressed move takes `cost` slots from the first free one on `key` now, before the
## round's record has them; returns [first, count], or [] when no slot is free or a press waits.
func hold(key: StringName, cost: int) -> Array[int]:
	if _pending_first >= 0:
		return []
	var first: int = _first_free()
	var count: int = mini(maxi(1, cost), _slots.size() - first)
	if count <= 0:
		return []
	_pending_first = first
	_pending_count = count
	_pending_key = key
	_pending_left = PENDING_SECONDS
	_frozen = true
	_hold_last = _last_seen
	set_process(true)
	queue_redraw()
	return [first, count]


## The slots a press holds that the record does not show yet (0: none).
func pending_count() -> int:
	return _pending_count if _pending_first >= 0 else 0


## Slot `index`'s rect (a run `count` long) in this control, as it lies still.
func slot_rect(index: int, count: int = 1) -> Rect2:
	var chip: Vector2 = _chip()
	var n: int = maxi(1, count)
	return Rect2(_slot_at(index, 2.0), Vector2(n * chip.x + (n - 1) * _gap(), chip.y))


## The fill is full: the strip takes the record's last look (a new round, the beat resolved).
func release() -> void:
	if not _frozen:
		return
	_frozen = false
	var latest: Array = _latest
	_latest = []
	if not latest.is_empty():
		present(latest[0], latest[1], latest[2], latest[3])


func frozen() -> bool:
	return _frozen


func _process(delta: float) -> void:
	_pending_left -= delta
	if _pending_left <= 0.0:
		_drop_pending()
		release()


func _drop_pending() -> void:
	_pending_first = -1
	_pending_count = 0
	_pending_key = FREE
	set_process(false)
	queue_redraw()


## A short screen: smaller slots.
func set_compact(on: bool) -> void:
	_compact = on
	_fit()
	queue_redraw()


## The beats as the projection has them (`rules` prices each spent key; a 重 covers two
## slots). `chip_seconds`: feel.beat_chip_ms, the slide of a beat won (0: at once).
## 节拍填格: `last` is the last round's record (a new one since a press: the round closed).
func present(beats: CombatRoundBeats, rules: CombatBeatRules, chip_seconds: float, last: CombatRoundBeats = null) -> void:
	if _frozen:
		_latest = [beats, rules, chip_seconds, last]
		return
	var round_passed: bool = _pending_first >= 0 and last != _hold_last
	_last_seen = last
	var slots: Array[StringName] = []
	var spans: Array[Vector2i] = []
	var earned: Array[StringName] = []
	var base: int = 0
	var remaining: int = 0
	if beats != null:
		base = beats.base
		remaining = beats.remaining
		earned = beats.earned.duplicate()
		var total: int = base + earned.size()
		for key: StringName in beats.spent:
			var first: int = slots.size()
			for _n: int in _chips_of(rules, key):
				if slots.size() < total:
					slots.append(key)
			if slots.size() > first:
				spans.append(Vector2i(first, slots.size() - first))
		for _n: int in beats.yielded:
			if slots.size() < total:
				spans.append(Vector2i(slots.size(), 1))
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
	# 节拍填格: a press's hold goes once the record has a beat where it lies (priced as it ran:
	# a 重 that came to a wait is one slot), or with a new round.
	if _pending_first >= 0 and (fresh_round or round_passed or _spent_count(slots) > _pending_first):
		_drop_pending()
	_slots = slots
	_spans = spans
	_earned = earned
	_base = base
	_remaining = remaining
	_fit()
	queue_redraw()


## The dashed slot after the others while the school can still win a beat this round, with
## how it is won (`hint`, e.g. 对方打空得 1 手); false takes it away.
func set_earnable(on: bool, hint: String = "") -> void:
	if on == _earnable and hint == _earn_hint:
		return
	_earnable = on
	_earn_hint = hint
	_fit()
	queue_redraw()


## Whether the slot the next beat takes shows it (the fight waits for the player).
func set_cursor(on: bool) -> void:
	if on != _cursor:
		_cursor = on
		queue_redraw()


## The ghost of a move pointed at: `cost` slots from the first free one in `key`'s colour
## (a tag or an order's key), red when the beats cannot pay. 0 clears it.
func set_preview(cost: int, key: StringName = FREE, ok: bool = true) -> void:
	_preview_cost = maxi(0, cost)
	_preview_color = _color_of(key)
	_preview_ok = ok
	queue_redraw()


func clear_preview() -> void:
	set_preview(0)


## The slots' keys in order (tests); the dashed slot is not one.
func slots() -> Array[StringName]:
	return _slots.duplicate()


func earnable() -> bool:
	return _earnable


func earn_hint() -> String:
	return _earn_hint if _earnable else ""


## The ghost now: [cost, ok] (tests).
func preview() -> Array:
	return [_preview_cost, _preview_ok]


func sliding() -> bool:
	return _slide < 1.0


func _chip() -> Vector2:
	return COMPACT_CHIP if _compact else CHIP


func _gap() -> float:
	return COMPACT_GAP if _compact else GAP


## How many slots are drawn: the beats and the dashed one (a ghost stays within them).
func _drawn_count() -> int:
	return maxi(2, _slots.size()) + (1 if _earnable else 0)


func _fit() -> void:
	var chip: Vector2 = _chip()
	var count: int = maxi(2, _slots.size()) + (1 if _earnable else 0)
	var width: float = PAD.x * 2 + count * chip.x + maxf(0, count - 1) * _gap()
	custom_minimum_size = Vector2(width, chip.y + PAD.y * 2 + 2)


## How many slots a spent key covers: a tag's price (a 重 lies over two), an order's
## (perform/<id>, stance, exert, item, flee, cast), one for busy and a wait.
static func _chips_of(rules: CombatBeatRules, key: StringName) -> int:
	if rules == null or STRUCK_KEYS.has(key):
		return 1
	if not CombatBeatRules.perform_of(key).is_empty() or GLYPHS.has(key):
		return maxi(1, rules.cost_of_action(key))
	return maxi(1, rules.cost_of_tag(CombatMoveTags.NONE if key == CombatBeatRules.COST_PLAIN else key))


func _first_free() -> int:
	var shown: Array[StringName] = _shown_slots()
	var at: int = shown.find(FREE)
	return shown.size() if at < 0 else at


## How many slots from the left are spent or given up (the free ones follow them).
static func _spent_count(slots: Array[StringName]) -> int:
	var at: int = slots.find(FREE)
	return slots.size() if at < 0 else at


## The slots as drawn: the record's, with a press's hold over them.
func _shown_slots() -> Array[StringName]:
	var slots: Array[StringName] = _slots.duplicate()
	if _pending_first >= 0:
		for index: int in range(_pending_first, mini(_pending_first + _pending_count, slots.size())):
			slots[index] = _pending_key
	return slots


func _shown_spans() -> Array[Vector2i]:
	var spans: Array[Vector2i] = _spans.duplicate()
	if _pending_first >= 0:
		spans.append(Vector2i(_pending_first, mini(_pending_count, _slots.size() - _pending_first)))
	return spans


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


func _slot_at(index: int, top: float) -> Vector2:
	return Vector2(PAD.x + index * (_chip().x + _gap()), top + PAD.y)


func _draw() -> void:
	var chip: Vector2 = _chip()
	var count: int = _drawn_count()
	var groove := Rect2(Vector2(0, 2), Vector2(PAD.x * 2 + count * chip.x + maxf(0, count - 1) * _gap(), chip.y + PAD.y * 2))
	draw_rect(groove, GROOVE)
	draw_rect(groove, GROOVE_EDGE, false, 1.0)
	var size_px: int = 12 if _compact else GameTheme.text_size(18)
	# The free and given-up slots one by one; a spending's run as one long slot (a press's hold too).
	var shown: Array[StringName] = _shown_slots()
	var covered: Dictionary[int, bool] = {}
	for span: Vector2i in _shown_spans():
		var key: StringName = shown[span.x]
		var at: Vector2 = _slot_at(span.x, groove.position.y)
		var width: float = span.y * chip.x + (span.y - 1) * _gap()
		_draw_slot(Rect2(at, Vector2(width, chip.y)), key, span.x, size_px)
		for n: int in span.y:
			covered[span.x + n] = true
	for index: int in shown.size():
		if covered.has(index):
			continue
		_draw_slot(Rect2(_slot_at(index, groove.position.y), chip), shown[index], index, size_px)
	var dashed_at: int = _slots.size()
	if _earnable:
		var rect := Rect2(_slot_at(dashed_at, groove.position.y), chip)
		_draw_dashed(rect, Color(GOLD, 0.8))
		if not _compact and not _earn_hint.is_empty() and _font != null:
			# How it is won, inside the slot in two short lines (对方打空 / 得 1 手).
			var lines: PackedStringArray = hint_lines(_earn_hint)
			var first_y: float = rect.get_center().y - (lines.size() - 1) * 7.0 + 4.0
			for n: int in lines.size():
				_draw_centered(lines[n], Vector2(rect.get_center().x, first_y + n * 14.0), 12, Color(SOURCE_TEXT, 0.9))
	if _cursor:
		var next: int = _first_free()
		if next < _slots.size():
			var rect := Rect2(_slot_at(next, groove.position.y), chip)
			draw_rect(rect.grow(1), GOLD, false, 2.0)
			var tip := Vector2(rect.get_center().x, rect.position.y + 1)
			draw_colored_polygon(PackedVector2Array([tip + Vector2(-6, -7), tip + Vector2(6, -7), tip]), GOLD)
	if _preview_cost > 0:
		var start: int = _first_free()
		var reach: int = clampi(_preview_cost, 1, maxi(1, count - start))
		var rect := Rect2(_slot_at(start, groove.position.y), Vector2(reach * chip.x + (reach - 1) * _gap(), chip.y))
		var fill: Color = Color(_preview_color, 0.5) if _preview_ok else Color(SHORT, 0.55)
		draw_rect(rect, fill)
		draw_rect(rect, Color(fill, 0.95), false, 2.0)


## One slot (or a run of them, `rect` as wide): free, spent, given up, won.
func _draw_slot(rect: Rect2, key: StringName, index: int, size_px: int) -> void:
	var alpha: float = 1.0
	var won: bool = index >= _base
	if won and index >= _sliding_from and _slide < 1.0:
		rect.position.x += (1.0 - _slide) * SLIDE_PX
		alpha = _slide
	var struck: bool = STRUCK_KEYS.has(key)
	var face: Color = WOOD
	var glyph: String = ""
	if struck:
		face = STRUCK
	elif key != FREE:
		face = _color_of(key)
		glyph = _glyph_of(key)
	draw_rect(Rect2(rect.position + Vector2(0, 2), rect.size), Color(WOOD_SIDE, alpha))
	draw_rect(rect, Color(face, alpha))
	if key == FREE:
		draw_rect(Rect2(rect.position + Vector2(3, 3), rect.size - Vector2(6, 6)), Color(FREE_LINE, alpha), false, 1.0)
	if won:
		draw_rect(rect, Color(GOLD, alpha), false, 2.0)
	if struck:
		draw_line(rect.position + Vector2(4, rect.size.y - 4), rect.position + Vector2(rect.size.x - 4, 4), Color(INK, alpha), 2.0)
	if not glyph.is_empty() and _font != null:
		_draw_centered(glyph, Vector2(rect.get_center().x, rect.get_center().y + size_px * 0.35), size_px, Color(UiPalette.BONE, alpha))
	if won and not _compact and _font != null:
		# Where it came from, small in the slot's top corner (隙 / 压 / 连).
		var source: StringName = _earned[index - _base] if index - _base < _earned.size() else &""
		var word: String = CombatSchoolSkeleton.EARN_LABELS.get(source, "")
		if not word.is_empty():
			word = TranslationServer.translate(word)
			var width: float = _font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
			draw_string(_font, Vector2(rect.end.x - width - 4, rect.position.y + 13), word, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(SOURCE_TEXT, alpha))


## The dashed slot's words in two lines: before and from its last 得 (对方打空 / 得 1 手), else
## halved.
static func hint_lines(hint: String) -> PackedStringArray:
	var at: int = hint.rfind(TranslationServer.translate("得"))
	if at <= 0:
		at = hint.length() / 2
	return PackedStringArray([hint.left(at).strip_edges(), hint.substr(at).strip_edges()])


func _draw_dashed(rect: Rect2, color: Color) -> void:
	var dash: float = 5.0
	for side: Array in [[rect.position, Vector2(rect.end.x, rect.position.y)], [Vector2(rect.position.x, rect.end.y), rect.end],
			[rect.position, Vector2(rect.position.x, rect.end.y)], [Vector2(rect.end.x, rect.position.y), rect.end]]:
		var from: Vector2 = side[0]
		var to: Vector2 = side[1]
		var length: float = from.distance_to(to)
		var step: float = 0.0
		while step < length:
			draw_line(from.lerp(to, step / length), from.lerp(to, minf(step + dash, length) / length), color, 1.0)
			step += dash * 2.0


func _draw_centered(text: String, baseline_centre: Vector2, size_px: int, color: Color) -> void:
	var width: float = _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
	draw_string(_font, Vector2(baseline_centre.x - width * 0.5, baseline_centre.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, color)


## A spent key's colour and its one character (the fill carries them).
static func color_of(key: StringName) -> Color:
	return _color_of(key)


static func glyph_of(key: StringName) -> String:
	return _glyph_of(key)


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
