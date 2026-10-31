class_name BattleVitalityBar
extends Control

## 战斗决策层 2 (DECISIONS「战斗界面」): a card's 气 bar. The fill is coloured by the band
## combatd.c status_msg() / eff_status_msg() word a blow with — over 80 unhurt, over 60
## 轻伤, over 20 重伤, 20 and under 濒死 — and the stretch between the effective 气 and the
## maximum (the wounds taken, eff_kee < max_kee) is drawn as a dark red 裂痕. Presentation
## only: `value` is tweened by the card; nothing here reads or changes a rule.
## 战斗决策层 3 (DECISIONS「战斗演出」): the crack is hatched; a new wound's stretch flares
## bright red and settles into the crack over crack_flash_ms; a healed stretch (the effective
## 气 back up) carries a gold line that fades over mend_ms (裂痕金缮).

enum Band { UNHURT, LIGHT, HEAVY, DYING }

## The bands' thresholds, status_msg()'s own (the 80 / 60 / 20 lines).
const LIGHT_BELOW: int = 80
const HEAVY_BELOW: int = 60
const DYING_BELOW: int = 20

const BAND_COLORS: Dictionary[Band, Color] = {
	Band.UNHURT: Color("a45650"),
	Band.LIGHT: Color("d9b24a"),
	Band.HEAVY: Color("d9772e"),
	Band.DYING: Color("d93a3a"),
}
const BACK_COLOR: Color = Color("2a3a44")
const CRACK_COLOR: Color = Color("5a1d1d")
const CRACK_LINE_COLOR: Color = Color("3a1010")
const CRACK_FLASH_COLOR: Color = Color("d93a3a")
const MEND_COLOR: Color = Color("efc77b")
## The hatching: one dark line every this many px across the crack.
const HATCH_STEP: float = 6.0

## TRANSLATORS: the four bands of a 气 bar and the word a short battle line gives the one hit: unhurt, lightly hurt, badly hurt, near death.
const BAND_WORDS: Dictionary[Band, String] = {
	Band.UNHURT: "无碍",
	Band.LIGHT: "受伤不轻",
	Band.HEAVY: "伤势沉重",
	Band.DYING: "濒死",
}

var value: float = 0.0:
	set(next):
		value = next
		queue_redraw()
var max_value: float = 1.0:
	set(next):
		max_value = maxf(1.0, next)
		queue_redraw()
## The effective 气 (the top the current one can heal to without a wound closing).
var effective: float = 0.0:
	set(next):
		var before: float = effective
		effective = next
		if is_inside_tree() and before > 0.0 and not is_equal_approx(before, next):
			_wound_changed(before, next)
		queue_redraw()
## The new wound (from `_flash_from` to `_flash_to`, as shares of the bar) flaring: 1 bright,
## 0 settled; the healed stretch's gold line: 1 bright, 0 gone.
var _flash_from: float = 1.0
var _flash_to: float = 1.0
var flash_alpha: float = 0.0:
	set(next):
		flash_alpha = next
		queue_redraw()
var _mend_from: float = 1.0
var _mend_to: float = 1.0
var mend_alpha: float = 0.0:
	set(next):
		mend_alpha = next
		queue_redraw()
var _flash_tween: Tween
var _mend_tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size.y = 8


## The band of `current` out of `maximum`, by status_msg()'s percent (kee * 100 / max_kee).
static func band(current: int, maximum: int) -> Band:
	if maximum <= 0:
		return Band.UNHURT
	@warning_ignore("integer_division")
	var ratio: int = current * 100 / maximum
	return band_of_ratio(ratio)


static func band_of_ratio(ratio: int) -> Band:
	if ratio > LIGHT_BELOW:
		return Band.UNHURT
	if ratio > HEAVY_BELOW:
		return Band.LIGHT
	if ratio > DYING_BELOW:
		return Band.HEAVY
	return Band.DYING


static func band_color(current: int, maximum: int) -> Color:
	return BAND_COLORS[band(current, maximum)]


## The one word for the one hit, after a blow whose status_msg() ratio is `ratio`.
static func band_word(ratio: int) -> String:
	return TranslationServer.translate(BAND_WORDS[band_of_ratio(ratio)])


## The fill's colour now (the band of the shown value).
func fill_color() -> Color:
	return BAND_COLORS[band(roundi(value), roundi(max_value))]


## Where the crack starts, as a share of the bar's width; 1.0 when there is no wound.
func crack_from() -> float:
	return clampf(effective / max_value, 0.0, 1.0)


## The effective 气 moved: down is a new wound (its stretch flares), up is a healed one
## (a gold line fades). Shares of the bar; durations from the feel (0: nothing).
func _wound_changed(before: float, after: float) -> void:
	var feel: FeelDefinition = GameContent.catalog().pacing().feel
	var low: float = clampf(minf(before, after) / max_value, 0.0, 1.0)
	var high: float = clampf(maxf(before, after) / max_value, 0.0, 1.0)
	if after < before:
		if feel.crack_flash_seconds <= 0.0:
			return
		_flash_from = low
		_flash_to = high
		_stop(_flash_tween)
		flash_alpha = 1.0
		_flash_tween = create_tween()
		_flash_tween.tween_property(self, "flash_alpha", 0.0, feel.crack_flash_seconds).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	else:
		if feel.mend_seconds <= 0.0:
			return
		_mend_from = low
		_mend_to = high
		_stop(_mend_tween)
		mend_alpha = 1.0
		_mend_tween = create_tween()
		_mend_tween.tween_property(self, "mend_alpha", 0.0, feel.mend_seconds).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)


static func _stop(tween: Tween) -> void:
	if tween != null and tween.is_valid():
		tween.kill()


func _draw() -> void:
	var width: float = size.x
	var height: float = size.y
	draw_rect(Rect2(0, 0, width, height), BACK_COLOR)
	var filled: float = clampf(value / max_value, 0.0, 1.0) * width
	if filled > 0.0:
		draw_rect(Rect2(0, 0, filled, height), fill_color())
	var crack: float = crack_from() * width
	if crack < width:
		draw_rect(Rect2(crack, 0, width - crack, height), CRACK_COLOR)
		# The hatching: slanted dark lines across the crack.
		var x: float = crack + HATCH_STEP * 0.5
		while x < width:
			draw_line(Vector2(x, height), Vector2(minf(x + height * 0.6, width), 0.0), CRACK_LINE_COLOR, 1.0)
			x += HATCH_STEP
	if flash_alpha > 0.0:
		var flash := Color(CRACK_FLASH_COLOR.r, CRACK_FLASH_COLOR.g, CRACK_FLASH_COLOR.b, flash_alpha)
		draw_rect(Rect2(_flash_from * width, 0, (_flash_to - _flash_from) * width, height), flash)
	if mend_alpha > 0.0:
		var mend := Color(MEND_COLOR.r, MEND_COLOR.g, MEND_COLOR.b, mend_alpha)
		draw_rect(Rect2(_mend_from * width, height * 0.25, (_mend_to - _mend_from) * width, height * 0.5), mend)
