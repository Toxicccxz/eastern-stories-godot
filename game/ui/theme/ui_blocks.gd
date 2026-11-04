class_name UiBlocks
extends RefCounted

## The interface's block materials, drawn in code from UiPalette (no art files): a window is a
## slab seen a little from above — a top face (plain or planked), a front face a few pixels
## deep below it, a lit top edge, shaded sides, cut corners; a text field is a recess; focus is
## a lantern-yellow rim. One design pixel is PX logical pixels, drawn nearest, so the blocks
## stay crisp at any whole stretch.

const PX: int = 2


## A slab: `w`×`h` top face, `depth` pixels of front face under it.
static func slab_image(top: Color, side: Color, depth: int, planks: bool, w: int = 24, h: int = 18) -> Image:
	var height: int = h + depth
	var image := Image.create_empty(w, height, false, Image.FORMAT_RGBA8)
	for y: int in height:
		for x: int in w:
			if (x == 0 or x == w - 1) and (y == 0 or y == height - 1):
				continue
			var colour: Color
			if y >= h:
				colour = side.darkened(0.15) if y == height - 1 else side
				if x == 0 or x == w - 1:
					colour = colour.darkened(0.12)
			else:
				colour = top
				if planks:
					if (y / 6) % 2 == 1:
						colour = colour.darkened(0.035)
					if y % 6 == 5:
						colour = colour.darkened(0.09)
				if y == 0:
					colour = colour.lightened(0.18)
				elif x == 0:
					colour = colour.lightened(0.07)
				elif x == w - 1:
					colour = colour.darkened(0.1)
			image.set_pixel(x, y, colour)
	image.resize(w * PX, height * PX, Image.INTERPOLATE_NEAREST)
	return image


## A recess: shadow under its top and left edges, a lit bottom and right rim.
static func well_image(fill: Color, w: int = 16, h: int = 16) -> Image:
	var image := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	for y: int in h:
		for x: int in w:
			var colour: Color = fill
			if y == 0 or x == 0:
				colour = fill.darkened(0.45)
			elif y == 1:
				colour = fill.darkened(0.22)
			elif y == h - 1 or x == w - 1:
				colour = fill.lightened(0.12)
			image.set_pixel(x, y, colour)
	image.resize(w * PX, h * PX, Image.INTERPOLATE_NEAREST)
	return image


## The focus: a rim one design pixel thick with cut corners.
static func rim_image(colour: Color, w: int = 12, h: int = 12) -> Image:
	var image := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	for y: int in h:
		for x: int in w:
			var edge: bool = x < 1 or y < 1 or x >= w - 1 or y >= h - 1
			var corner: bool = (x == 0 or x == w - 1) and (y == 0 or y == h - 1)
			if edge and not corner:
				image.set_pixel(x, y, colour)
	image.resize(w * PX, h * PX, Image.INTERPOLATE_NEAREST)
	return image


## A nine-patch of `image`; margins in design pixels, content margins in logical pixels.
static func box(image: Image, margins: Vector4i, content: Vector4, tile: bool = false) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = ImageTexture.create_from_image(image)
	style.texture_margin_left = margins.x * PX
	style.texture_margin_top = margins.y * PX
	style.texture_margin_right = margins.z * PX
	style.texture_margin_bottom = margins.w * PX
	style.content_margin_left = content.x
	style.content_margin_top = content.y
	style.content_margin_right = content.z
	style.content_margin_bottom = content.w
	if tile:
		style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
		style.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	return style


## A block button's face: `depth` pixels of front face (3 up, 1 pressed down).
static func block(top: Color, side: Color, depth: int, content: Vector4) -> StyleBoxTexture:
	return box(slab_image(top, side, depth, false, 12, 10), Vector4i(2, 2, 2, 2 + depth), content)


static func rim(colour: Color = UiPalette.LANTERN) -> StyleBoxTexture:
	return box(rim_image(colour), Vector4i(2, 2, 2, 2), Vector4.ZERO)


## The bobbing focus cursor: a voxel wedge pointing right (lit face over a shaded underside),
## the same sign as the arrows over a map's exits.
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
	]
	var image := Image.create_empty(6, rows.size(), false, Image.FORMAT_RGBA8)
	for y: int in rows.size():
		for x: int in 6:
			var c: String = rows[y][x]
			if c == "#":
				image.set_pixel(x, y, UiPalette.LANTERN)
			elif c == "%":
				image.set_pixel(x, y, Color("c88a2c"))
	image.resize(6 * PX, rows.size() * PX, Image.INTERPOLATE_NEAREST)
	return image


## A switch for CheckButton: a dark slot with a block that sits left (off) or lit right (on).
static func switch_image(on: bool, disabled: bool = false) -> Image:
	var w: int = 18
	var h: int = 10
	var image := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	var slot: Color = UiPalette.INK.lerp(UiPalette.EBONY, 0.3)
	var knob: Color = (UiPalette.LANTERN if on else UiPalette.MUTED)
	if disabled:
		knob = knob.lerp(UiPalette.INK, 0.6)
	for y: int in h:
		for x: int in w:
			if (x == 0 or x == w - 1) and (y == 0 or y == h - 1):
				continue
			var colour: Color = slot.darkened(0.3) if y <= 1 else slot
			var left: int = 10 if on else 1
			if x >= left and x < left + 7 and y >= 1 and y < h - 1:
				colour = knob.darkened(0.25) if y >= h - 3 else knob
				if y == 1:
					colour = knob.lightened(0.2)
			image.set_pixel(x, y, colour)
	image.resize(w * PX, h * PX, Image.INTERPOLATE_NEAREST)
	return image
