class_name BattleVitalityBar
extends Control

## 战斗决策层 2 (DECISIONS「战斗界面」): a card's 气 bar. The fill is coloured by the band
## combatd.c status_msg() / eff_status_msg() word a blow with — over 80 unhurt, over 60
## 轻伤, over 20 重伤, 20 and under 濒死 — and the stretch between the effective 气 and the
## maximum (the wounds taken, eff_kee < max_kee) is drawn as a dark red 裂痕. Presentation
## only: `value` is tweened by the card; nothing here reads or changes a rule.

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
		effective = next
		queue_redraw()


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
