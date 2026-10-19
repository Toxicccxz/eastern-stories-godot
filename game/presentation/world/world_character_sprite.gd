class_name WorldCharacterSprite
extends AnimatedSprite2D
## A body's picture: stands or walks the way the body faces (down, up, right; left is right
## mirrored). It follows the body and decides nothing.

## The sheets are 32 art px drawn at 2x, the feet on art row 30: this puts the feet at the bottom
## of the body's circle.
const ART_SCALE: float = 2.0
const FEET_ABOVE_CENTRE: float = -14.0
## The name sits above the head instead of above the old square.
const NAME_LIFT: float = 18.0
## A walker moved in frame-sized steps can miss a frame; it keeps walking through that gap.
const WALK_HOLD_SECONDS: float = 0.1
## A jump further than this in one frame is a placement, not a step (WorldCharacterBody2D).
const PLACEMENT_SQUARED: float = 48.0 * 48.0
const PLACEHOLDERS: Array[String] = ["Visual", "HumanVisual", "BeastVisual"]

## The appearance it shows (CharacterAppearances), set by WorldCharacterArt.
var look: String = ""
var _body: WorldCharacterBody2D
var _last: Vector2 = Vector2.INF
var _walk_left: float = 0.0


func _ready() -> void:
	_body = get_parent() as WorldCharacterBody2D
	if _body == null:
		set_process(false)
		return
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	scale = Vector2(ART_SCALE, ART_SCALE)
	position = Vector2(0.0, FEET_ABOVE_CENTRE)
	_body.show_facing_notch = false
	var label: Control = _body.get_node_or_null("NameLabel") as Control
	if label != null:
		label.offset_top -= NAME_LIFT
		label.offset_bottom -= NAME_LIFT
	hide_placeholders()
	_last = _body.global_position
	show_pose()


## The body's coloured shape gives way to the picture (a new binding may show it again).
func hide_placeholders() -> void:
	if _body == null:
		return
	for placeholder: String in PLACEHOLDERS:
		var item: CanvasItem = _body.get_node_or_null(placeholder) as CanvasItem
		if item != null and item.visible:
			item.visible = false


func _process(delta: float) -> void:
	var moved: float = _body.global_position.distance_squared_to(_last)
	_last = _body.global_position
	if moved > 0.01 and moved < PLACEMENT_SQUARED:
		_walk_left = WALK_HOLD_SECONDS
	else:
		_walk_left = maxf(0.0, _walk_left - delta)
	show_pose()


## Stands or walks the way the body faces.
func show_pose() -> void:
	if _body == null:
		return
	var facing: Vector2 = _body.facing
	var direction: String = "down"
	if absf(facing.x) > absf(facing.y):
		direction = "right"
	elif facing.y < 0.0:
		direction = "up"
	flip_h = facing.x < 0.0 and direction == "right"
	var wanted: StringName = StringName(("walk_" if _walk_left > 0.0 else "idle_") + direction)
	if animation != wanted and sprite_frames != null and sprite_frames.has_animation(wanted):
		play(wanted)
