class_name BattlePanelChrome
extends Control

## 战斗演出 E (DECISIONS「战斗演出 E」): what a side panel (a BattleParticipantCard in panel mode)
## is dressed in, drawn behind its rows — owner 2026-11-09: a 阵旗 made of voxels that moves like
## cloth (BattleVoxelBanner), the card's rows on its cloth: the pole over the card's top edge, the
## cloth as wide as the card and as long, its swallowtail and cords hanging below. Let down from
## the pole when the panel opens (let_down()), flapping when its side strikes (gust()).
## Presentation only.

var side: int = 0
var current: bool = false
var side_colour: Color = UiPalette.PATINA
var banner: BattleVoxelBanner
var _drawn: Rect2 = Rect2()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	show_behind_parent = true
	resized.connect(_fit)
	visibility_changed.connect(_fit)


## Dressed as `p_side`'s banner (the banner is made the first time: a card never a panel has none).
func dress(p_side: int, p_current: bool, colour: Color) -> void:
	if banner != null and p_side == side and p_current == current and colour == side_colour and _drawn.has_area():
		return
	side = p_side
	current = p_current
	side_colour = colour
	if banner == null:
		banner = BattleVoxelBanner.new()
		banner.name = "VoxelBanner"
		add_child(banner)
	_fit()


## The banner as big as the card: the cloth's bricks square, as many rows as the card is tall; the
## picture drawn at whole screen pixels.
func _fit() -> void:
	if banner == null:
		return
	banner.render_target_update_mode = SubViewport.UPDATE_ALWAYS if is_visible_in_tree() else SubViewport.UPDATE_DISABLED
	var card := get_parent() as Control
	var box := Rect2(-position, card.size) if card != null else Rect2(Vector2.ZERO, size)
	if box.size.x <= 0.0 or box.size.y <= 0.0:
		return
	var brick: float = box.size.x / float(BattleVoxelBanner.COLUMNS)
	var rows: int = maxi(4, roundi(box.size.y / brick))
	banner.build(rows, side, side_colour, current)
	_drawn = Rect2(box.position - Vector2(BattleVoxelBanner.MARGIN_SIDE, BattleVoxelBanner.MARGIN_TOP) * brick, Vector2(BattleVoxelBanner.bricks_wide(), BattleVoxelBanner.bricks_high(rows)) * brick)
	var screen_scale: float = get_viewport().get_final_transform().get_scale().x if is_inside_tree() else 1.0
	var pixels := Vector2i((_drawn.size * screen_scale).round())
	if pixels.x > 0 and pixels.y > 0 and banner.size != pixels:
		banner.size = pixels
	queue_redraw()


func _draw() -> void:
	if banner != null and _drawn.has_area():
		draw_texture_rect(banner.get_texture(), _drawn, false)


## Let down from the pole over `seconds`.
func let_down(seconds: float, delay: float = 0.0) -> void:
	if banner != null:
		banner.let_down(seconds, delay)


## A flap (0 .. 1).
func gust(amount: float) -> void:
	if banner != null:
		banner.gust(amount)
