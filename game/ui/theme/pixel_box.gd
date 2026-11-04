class_name PixelBox
extends StyleBox

## A nine-patch drawn on the pixel interface's grid (DECISIONS「像素界面」): one texel of its
## image is `scale` logical pixels (GameTheme.GRID, the text's own pixel), so a frame's pixels
## are the size of the letters' and land on whole screen pixels at every snapped scale
## (ApplicationUiScale.pixel_factor). StyleBoxTexture draws a texel as one logical pixel.

@export var texture: Texture2D
## Border widths in texels: left, top, right, bottom.
@export var margins: Vector4i = Vector4i.ZERO
## The middle and the sides repeat rather than stretch (a mottled face stays fine-grained).
@export var tile: bool = false
@export var scale: float = 1.5


func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	if texture == null or scale <= 0.0:
		return
	var mode: RenderingServer.NinePatchAxisMode = RenderingServer.NINE_PATCH_TILE if tile else RenderingServer.NINE_PATCH_STRETCH
	RenderingServer.canvas_item_add_set_transform(to_canvas_item, Transform2D(0.0, Vector2(scale, scale), 0.0, rect.position.round()))
	RenderingServer.canvas_item_add_nine_patch(to_canvas_item, Rect2(Vector2.ZERO, (rect.size / scale).round()), Rect2(Vector2.ZERO, texture.get_size()), texture.get_rid(), Vector2(margins.x, margins.y), Vector2(margins.z, margins.w), mode, mode, true)
	RenderingServer.canvas_item_add_set_transform(to_canvas_item, Transform2D.IDENTITY)
