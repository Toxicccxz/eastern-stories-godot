class_name PixelBox
extends StyleBox

## A nine-patch drawn on the pixel interface's grid (DECISIONS「像素界面」): one texel of its
## image is `scale` logical pixels (GameTheme.GRID, the text's own pixel), so a frame's pixels
## are the size of the letters' and land on whole screen pixels at every snapped scale
## (ApplicationUiScale.pixel_factor). StyleBoxTexture draws a texel as one logical pixel.
##
## Old and used like the maps: a control picks one of the material's `variants` (its corners
## chipped and fitted differently), and wear `marks` (cracks, knots, nails, rust, hack marks,
## stains) are scattered over its face, laid out by the control and its size, so no two
## windows or buttons look stamped; the same control keeps its marks in every state.

@export var texture: Texture2D
## Same-sized versions of `texture`; a control takes one by its canvas item.
@export var variants: Array[Texture2D] = []
## Border widths in texels: left, top, right, bottom.
@export var margins: Vector4i = Vector4i.ZERO
## The middle and the sides repeat rather than stretch (planks and grain stay fine-grained).
@export var tile: bool = false
@export var scale: float = 1.5
@export var modulate: Color = Color.WHITE
## The wear marks: one atlas, its pieces' regions.
@export var marks: Texture2D
@export var mark_rects: Array[Rect2i] = []
## Marks a texel² of the box, and never fewer than x nor more than y.
@export var mark_density: float = 0.0
@export var mark_range: Vector2i = Vector2i.ZERO
## Where marks may lie, in texels in from the box's sides (left, top, right, bottom).
@export var mark_inset: Vector4i = Vector4i.ZERO
@export var mark_seed: int = 0

## hash(control, size bucket) -> [[piece, x 0..1, y 0..1], ...]
var _layouts: Dictionary = {}


func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	var id: int = to_canvas_item.get_id()
	var shown: Texture2D = texture
	if not variants.is_empty():
		shown = variants[posmod(hash(id), variants.size())]
	if shown == null or scale <= 0.0:
		return
	var size: Vector2 = (rect.size / scale).round()
	var mode: RenderingServer.NinePatchAxisMode = RenderingServer.NINE_PATCH_TILE if tile else RenderingServer.NINE_PATCH_STRETCH
	RenderingServer.canvas_item_add_set_transform(to_canvas_item, Transform2D(0.0, Vector2(scale, scale), 0.0, rect.position.round()))
	RenderingServer.canvas_item_add_nine_patch(to_canvas_item, Rect2(Vector2.ZERO, size), Rect2(Vector2.ZERO, shown.get_size()), shown.get_rid(), Vector2(margins.x, margins.y), Vector2(margins.z, margins.w), mode, mode, true, modulate)
	if marks != null and not mark_rects.is_empty() and mark_range.y > 0:
		var inner := Rect2i(mark_inset.x, mark_inset.y, int(size.x) - mark_inset.x - mark_inset.z, int(size.y) - mark_inset.y - mark_inset.w)
		if inner.size.x > 2 and inner.size.y > 2:
			for mark: Array in _layout(id, Vector2i(size)):
				var region: Rect2i = mark_rects[int(mark[0])]
				var room: Vector2i = inner.size - region.size
				if room.x < 0 or room.y < 0:
					continue
				var at: Vector2i = inner.position + Vector2i(int(float(mark[1]) * room.x), int(float(mark[2]) * room.y))
				RenderingServer.canvas_item_add_texture_rect_region(to_canvas_item, Rect2(at, region.size), marks.get_rid(), Rect2(region), modulate)
	RenderingServer.canvas_item_add_set_transform(to_canvas_item, Transform2D.IDENTITY)


## The marks of the control `id` at `size` texels: seeded by both (bucketed, so a box that
## grows a little keeps its marks; they lie at fractions of its face and move with it).
func _layout(id: int, size: Vector2i) -> Array:
	var bucket := Vector2i(size.x / 12, size.y / 12)
	var key: int = hash([id, bucket.x, bucket.y])
	if _layouts.has(key):
		return _layouts[key]
	if _layouts.size() > 512:
		_layouts.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([mark_seed, id, bucket.x, bucket.y])
	var inner := Vector2i(maxi(1, size.x - mark_inset.x - mark_inset.z), maxi(1, size.y - mark_inset.y - mark_inset.w))
	var count: int = clampi(int(float(inner.x * inner.y) * mark_density + rng.randf()), mark_range.x, mark_range.y)
	var placed: Array[Rect2i] = []
	var layout: Array = []
	for index: int in count:
		for attempt: int in 6:
			var piece: int = rng.randi_range(0, mark_rects.size() - 1)
			var region: Rect2i = mark_rects[piece]
			var fx: float = rng.randf()
			var fy: float = rng.randf()
			var at := Rect2i(Vector2i(int(fx * maxi(0, inner.x - region.size.x)), int(fy * maxi(0, inner.y - region.size.y))), region.size).grow(1)
			var clear: bool = true
			for other: Rect2i in placed:
				if other.intersects(at):
					clear = false
					break
			if clear:
				placed.append(at)
				layout.append([piece, fx, fy])
				break
	_layouts[key] = layout
	return layout
