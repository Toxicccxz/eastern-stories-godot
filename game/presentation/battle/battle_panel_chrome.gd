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
## owner 2026-11-11 (the words did not move with the cloth): the card turns and stretches about the
## pole as the cloth's middle does (follow()); the picture is drawn through the inverse, so the
## banner itself stays where it hangs.
var _ride: Transform2D = Transform2D.IDENTITY


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
		# The card shows its point p at ride·p; the picture drawn at the inverse stays put.
		draw_set_transform_matrix(Transform2D(0.0, -position) * _ride.affine_inverse() * Transform2D(0.0, position))
		draw_texture_rect(banner.get_texture(), _drawn, false)


## How the cloth's middle has moved from where it hangs at rest, as a turn and a stretch about the
## pole's middle, in the card's coordinates: [pivot, angle, stretch]. At rest (or not drawn yet):
## no turn, no stretch.
func cloth_motion() -> Array:
	if banner == null or not _drawn.has_area() or banner.size.x <= 0 or banner.unfurled() < 1.0:
		return [Vector2.ZERO, 0.0, 1.0]
	var column: float = float(BattleVoxelBanner.COLUMNS) / 2.0
	var row: float = float(banner.cloth_rows) * 0.5
	var pole: Vector2 = _to_card(banner.picture_point(Vector3(column, 0.5, 0.0)))
	var rest: Vector2 = _to_card(banner.picture_point(Vector3(column, -row, 0.0))) - pole
	var now: Vector2 = _to_card(banner.picture_point(banner.cloth_point(column, row))) - pole
	if rest.length() < 1.0:
		return [pole, 0.0, 1.0]
	return [pole, rest.angle_to(now), now.length() / rest.length()]


## The card's own turn and stretch now, in the card's coordinates (the card applies it; the
## picture undoes it).
func ride(motion: Transform2D) -> void:
	if motion.is_equal_approx(_ride):
		return
	_ride = motion
	queue_redraw()


## A pixel of the banner's picture in the card's coordinates.
func _to_card(pixel: Vector2) -> Vector2:
	var picture := Vector2(banner.size)
	return position + _drawn.position + pixel / picture * _drawn.size


## Let down from the pole over `seconds`.
func let_down(seconds: float, delay: float = 0.0) -> void:
	if banner != null:
		banner.let_down(seconds, delay)


## A flap (0 .. 1).
func gust(amount: float) -> void:
	if banner != null:
		banner.gust(amount)
