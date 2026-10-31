class_name BattleCardStage
extends Control

## 战斗决策层 3 (DECISIONS「战斗演出」): the show over one battle card — the move's name
## slammed onto the attacker's card, the −N (or 闪 / 挡 / 无伤) floating off the one hit's
## bar, the 倒 / 亡 stamp and the dark veil over one who fell. It lies over the whole card,
## takes no input and no room in the layout (the card's minimum size is the labels'), and
## reads nothing but what the card hands it: every duration is pacing.json's feel, 0 = at
## once / not shown. Presentation only: no rule, number or random draw passes through here.

const INK: Color = Color("eee4cb")
const GOLD: Color = Color("efc77b")
const GREY: Color = Color("8b959e")
const STAMP_RED: Color = Color(0.70, 0.23, 0.18, 0.78)
const VEIL: Color = Color(0.02, 0.04, 0.05, 0.45)
const TITLE_SIZE: int = 40
const SPECIAL_SIZE: int = 48
const FLOAT_SIZE: int = 22
const STAMP_SIZE: int = 72
## The slam: from this scale to 1 in SLAM_SECONDS, then the hold, then FADE_SECONDS out.
const SLAM_FROM: float = 1.3
const SLAM_SECONDS: float = 0.08
const FADE_SECONDS: float = 0.15
## The float rises this far (a hit) or slides this far sideways (a dodge, a parry).
const FLOAT_RISE: float = 24.0
const FLOAT_SLIDE: float = 18.0
# TRANSLATORS: the stamp over the card of one who fell unconscious.
const STAMP_UNCONSCIOUS: String = "倒"
# TRANSLATORS: the stamp over the card of one who died.
const STAMP_DEAD: String = "亡"
# TRANSLATORS: the word floating off a card when its fighter dodged a blow.
const FLOAT_DODGE: String = "闪"
# TRANSLATORS: the word floating off a card when its fighter parried a blow.
const FLOAT_PARRY: String = "挡"
# TRANSLATORS: the word floating off a card when a blow landed but drew no 气.
const FLOAT_NOTHING: String = "无伤"

var title: Label
var floater: Label
var stamp: Label
## The veil's alpha now (0: none; the fall tweens it up).
var veil_alpha: float = 0.0:
	set(next):
		veil_alpha = next
		queue_redraw()
var _title_tween: Tween
var _float_tween: Tween
var _veil_tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	clip_contents = true
	title = _label("Title", TITLE_SIZE)
	floater = _label("Floater", FLOAT_SIZE)
	stamp = _label("Stamp", STAMP_SIZE)
	stamp.rotation = deg_to_rad(-8.0)
	stamp.add_theme_color_override("font_color", STAMP_RED)
	stamp.add_theme_constant_override("outline_size", 0)


func _draw() -> void:
	if veil_alpha > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(VEIL.r, VEIL.g, VEIL.b, VEIL.a * veil_alpha))


## The move's name (`gold`: a special's, larger) slammed on and held `hold_seconds`, then
## faded; 0: not shown. A new title takes the old one's place at once.
func show_title(text: String, gold: bool, hold_seconds: float) -> void:
	_stop(_title_tween)
	title.text = text
	if hold_seconds <= 0.0 or text.is_empty():
		title.visible = false
		return
	title.add_theme_font_size_override("font_size", SPECIAL_SIZE if gold else TITLE_SIZE)
	title.add_theme_color_override("font_color", GOLD if gold else INK)
	title.modulate = Color.WHITE
	title.visible = true
	title.reset_size()
	_centre(title, size * 0.5 + Vector2(0, size.y * 0.12))
	title.pivot_offset = title.size * 0.5
	title.scale = Vector2.ONE * SLAM_FROM
	_title_tween = create_tween()
	_title_tween.tween_property(title, "scale", Vector2.ONE, SLAM_SECONDS).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_title_tween.tween_interval(hold_seconds)
	_title_tween.tween_property(title, "modulate:a", 0.0, FADE_SECONDS)
	_title_tween.tween_callback(func() -> void: title.visible = false)


## −N in the band's colour rising off the bar (`from_y`: the bar's y in the card), or a grey
## 闪 / 挡 / 无伤 sliding aside, over `seconds`; 0: not shown.
func show_float(text: String, color: Color, from_y: float, rises: bool, seconds: float) -> void:
	_stop(_float_tween)
	floater.text = text
	if seconds <= 0.0 or text.is_empty():
		floater.visible = false
		return
	floater.add_theme_color_override("font_color", color)
	floater.modulate = Color.WHITE
	floater.visible = true
	floater.reset_size()
	var start := Vector2(size.x * 0.72 - floater.size.x * 0.5, from_y)
	floater.position = start
	var end: Vector2 = start + (Vector2(0, -FLOAT_RISE) if rises else Vector2(FLOAT_SLIDE, 0))
	_float_tween = create_tween().set_parallel(true)
	_float_tween.tween_property(floater, "position", end, seconds).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_float_tween.tween_property(floater, "modulate:a", 0.0, seconds * 0.5).set_delay(seconds * 0.5)
	_float_tween.chain().tween_callback(func() -> void: floater.visible = false)


## The 倒 / 亡 stamp and the veil, settling in over `seconds` (0: at once); `text` empty
## lifts both (the fighter is up, or the card shows someone else).
func show_fallen(text: String, seconds: float) -> void:
	_stop(_veil_tween)
	stamp.text = text
	if text.is_empty():
		stamp.visible = false
		veil_alpha = 0.0
		return
	stamp.visible = true
	stamp.reset_size()
	_centre(stamp, size * 0.5)
	stamp.pivot_offset = stamp.size * 0.5
	if seconds <= 0.0:
		stamp.modulate = Color.WHITE
		stamp.scale = Vector2.ONE
		veil_alpha = 1.0
		return
	stamp.modulate = Color(1, 1, 1, 0)
	stamp.scale = Vector2.ONE * SLAM_FROM
	_veil_tween = create_tween().set_parallel(true)
	_veil_tween.tween_property(self, "veil_alpha", 1.0, seconds)
	_veil_tween.tween_property(stamp, "modulate:a", 1.0, seconds * 0.6)
	_veil_tween.tween_property(stamp, "scale", Vector2.ONE, seconds).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


## Everything off at once (the card shows someone else).
func clear() -> void:
	_stop(_title_tween)
	_stop(_float_tween)
	_stop(_veil_tween)
	title.visible = false
	floater.visible = false
	stamp.visible = false
	veil_alpha = 0.0


func _centre(label: Label, at: Vector2) -> void:
	label.position = at - label.size * 0.5


static func _stop(tween: Tween) -> void:
	if tween != null and tween.is_valid():
		tween.kill()


func _label(node_name: String, font_size: int) -> Label:
	var label := Label.new()
	label.name = node_name
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.visible = false
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_outline_color", Color(0.05, 0.07, 0.08, 0.9))
	label.add_theme_constant_override("outline_size", 6)
	add_child(label)
	return label
