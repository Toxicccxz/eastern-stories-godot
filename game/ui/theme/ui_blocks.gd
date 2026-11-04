class_name UiBlocks
extends RefCounted

## The interface's materials, drawn in code from UiPalette (no art files). 像素界面
## (DECISIONS「像素界面」): a window is a sheet of parchment — a dark outline with stepped
## corners, a lit top edge, a mottled frame band and an inner line round a mottled face, a
## soft shadow under it; a button is a raised parchment pill (its lower edge a few pixels of
## shade), pressed it sinks; a text field is a recess; focus is a rim in the focus colour.
## Images are one texel a design pixel; PixelBox draws a texel as GRID logical pixels (the
## pixel font's own pixel), so frames and letters share one grid.

## Texels a design pixel in the images (PixelBox scales them).
const PX: int = 1
## Logical pixels a design pixel: the 12 px pixel font drawn at 18 logical pixels.
const GRID: float = 1.5


## A raised sheet: a `w`×`h` face, `depth` pixels of shade under it, an outline round both,
## a one-pixel shadow below. `framed`: a window's frame band and inner line inside the
## outline, the face mottled.
static func slab_image(top: Color, side: Color, depth: int, framed: bool, w: int = 24, h: int = 18) -> Image:
	var shape_h: int = h + depth
	var height: int = shape_h + 1
	var radius: int = 3 if framed else 2
	var image := Image.create_empty(w, height, false, Image.FORMAT_RGBA8)
	for y: int in height:
		for x: int in w:
			if y >= shape_h:
				# The shadow under the sheet's bottom edge.
				if _cell(x, shape_h - 1, w, shape_h, radius) >= 0:
					image.set_pixel(x, y, Color(0.08, 0.05, 0.03, 0.32))
				continue
			var cell: int = _cell(x, y, w, shape_h, radius)
			if cell < 0:
				continue
			if cell == 0:
				image.set_pixel(x, y, UiPalette.OUTLINE)
				continue
			var colour: Color
			if y >= h:
				colour = side.darkened(0.18) if y == shape_h - 2 else side
			else:
				var depth_in: int = mini(mini(x, w - 1 - x), y)
				colour = top
				if framed:
					if depth_in == 1:
						colour = top.lightened(0.32)
					elif depth_in <= 3:
						colour = top.darkened(0.07)
						if _noise(x, y) > 0.72:
							colour = top.darkened(0.13)
						elif _noise(x + 7, y + 3) > 0.8:
							colour = top.lightened(0.08)
					elif depth_in == 4:
						colour = top.darkened(0.22)
					else:
						if _noise(x, y) > 0.9:
							colour = top.darkened(0.04)
						elif _noise(x + 11, y + 5) > 0.93:
							colour = top.lightened(0.05)
				else:
					if y == 1:
						colour = top.lightened(0.3)
					elif x == 1:
						colour = top.lightened(0.12)
					elif x == w - 2:
						colour = top.darkened(0.06)
			image.set_pixel(x, y, colour)
	return image


## -1 cut away (a stepped corner), 0 the outline, 1 inside.
static func _cell(x: int, y: int, w: int, h: int, radius: int) -> int:
	var cx: int = mini(x, w - 1 - x)
	var cy: int = mini(y, h - 1 - y)
	if cx + cy < radius:
		return -1
	if cx == 0 or cy == 0 or cx + cy == radius:
		return 0
	return 1


## A fixed speckle in [0, 1) for a pixel (the parchment's mottle; the same every run).
static func _noise(x: int, y: int) -> float:
	var n: int = (x * 73856093) ^ (y * 19349663)
	n = ((n ^ (n >> 13)) * 1274126177) & 0x7FFFFFFF
	return float((n >> 7) & 0xFFFF) / 65536.0


## A recess: shadow under its top and left edges, a lit bottom and right rim.
static func well_image(fill: Color, w: int = 16, h: int = 16) -> Image:
	var image := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	for y: int in h:
		for x: int in w:
			var colour: Color = fill
			if y == 0 or x == 0:
				colour = fill.darkened(0.32)
			elif y == 1:
				colour = fill.darkened(0.14)
			elif y == h - 1 or x == w - 1:
				colour = fill.lightened(0.18)
			image.set_pixel(x, y, colour)
	return image


## The focus: a rim one design pixel thick with stepped corners (it lies on a pill's outline).
static func rim_image(colour: Color, w: int = 12, h: int = 12) -> Image:
	var image := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	for y: int in h:
		for x: int in w:
			if _cell(x, y, w, h, 2) == 0:
				image.set_pixel(x, y, colour)
	return image


## A nine-patch of `image` on the grid; margins in texels, content margins in logical pixels.
static func box(image: Image, margins: Vector4i, content: Vector4, tile: bool = false) -> PixelBox:
	var style := PixelBox.new()
	style.texture = ImageTexture.create_from_image(image)
	style.margins = margins
	style.tile = tile
	style.scale = GRID
	style.content_margin_left = content.x
	style.content_margin_top = content.y
	style.content_margin_right = content.z
	style.content_margin_bottom = content.w
	return style


## A button's pill: `depth` pixels of shade under its face (3 up, 1 pressed down).
static func block(top: Color, side: Color, depth: int, content: Vector4) -> PixelBox:
	return box(slab_image(top, side, depth, false, 12, 10), Vector4i(3, 3, 3, 3 + depth + 1), content)


static func rim(colour: Color = UiPalette.FOCUS) -> PixelBox:
	return box(rim_image(colour), Vector4i(3, 3, 3, 3), Vector4.ZERO)


## An icon image drawn on the grid: one texel GRID logical pixels (its sides even, so whole).
static func icon(image: Image) -> ImageTexture:
	var texture := ImageTexture.create_from_image(image)
	texture.set_size_override(Vector2i(roundi(image.get_width() * GRID), roundi(image.get_height() * GRID)))
	return texture


## The bobbing focus cursor: a wedge pointing right (lit face over a shaded underside), the
## same sign as the arrows over a map's exits.
static func arrow_image() -> Image:
	var rows: Array[String] = [
		"#.....",
		"##....",
		"###...",
		"####..",
		"#####.",
		"%%%%%%",
		"%%%%%.",
		"%%%%..",
		"%%%...",
		"%%....",
		"%.....",
		"......",
	]
	var image := Image.create_empty(6, rows.size(), false, Image.FORMAT_RGBA8)
	for y: int in rows.size():
		for x: int in 6:
			var c: String = rows[y][x]
			if c == "#":
				image.set_pixel(x, y, UiPalette.FOCUS)
			elif c == "%":
				image.set_pixel(x, y, UiPalette.FOCUS.darkened(0.35))
	return image


## A switch for CheckButton: a dark slot with a block that sits left (off) or lit right (on).
static func switch_image(on: bool, disabled: bool = false) -> Image:
	var w: int = 18
	var h: int = 10
	var image := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	var slot: Color = UiPalette.WELL.darkened(0.12)
	var knob: Color = (UiPalette.LACQUER if on else UiPalette.MUTED)
	if disabled:
		knob = knob.lerp(UiPalette.WELL, 0.6)
	for y: int in h:
		for x: int in w:
			var cell: int = _cell(x, y, w, h, 2)
			if cell < 0:
				continue
			var colour: Color = UiPalette.OUTLINE if cell == 0 else (slot.darkened(0.2) if y <= 1 else slot)
			var left: int = 10 if on else 1
			if cell > 0 and x >= left and x < left + 7 and y >= 1 and y < h - 1:
				colour = knob.darkened(0.25) if y >= h - 3 else knob
				if y == 1:
					colour = knob.lightened(0.2)
			image.set_pixel(x, y, colour)
	return image
