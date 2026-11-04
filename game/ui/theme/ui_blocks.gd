class_name UiBlocks
extends RefCounted

## The interface's materials, drawn in code from UiPalette (no art files), as old and used as
## the maps (界面重做, 像素界面, DECISIONS「界面样式」): a window is an ebony panel of planks in a
## frame, its corners chipped and bound in rusting iron; a plate is a board with a crack or
## two; a button is an iron plate, riveted, rust running down its edge, hacked and scratched;
## a secondary button bronze gone green; a chief one red lacquer worn through to the wood; a
## speech bubble a torn scrap of paper; a key a chipped bone tile. Silhouettes are irregular
## (chips at the corners, dents along the edges); PixelBox scatters each material's marks over
## its face per control. Images are one texel a design pixel and PixelBox draws a texel as
## GRID logical pixels (the pixel font's own pixel). Every material is seeded: the same each
## run.

## Texels a design pixel in the images (PixelBox scales them).
const PX: int = 1
## Logical pixels a design pixel: the 12 px pixel font drawn at 18 logical pixels.
const GRID: float = 1.5

enum Kind { WOOD, IRON, BRONZE, LACQUER, PAPER, BONE }

enum Facing { TOP, LEFT, RIGHT, BOTTOM }

## Lacquer worn through: the wood under it.
const UNDERWOOD := Color("3b2416")
const GILT := Color("d6ab4c")


## What a sheet is made of and how it is built.
class Spec:
	extends RefCounted
	var kind: int = UiBlocks.Kind.WOOD
	var face: Color = UiPalette.EBONY
	var side: Color = UiPalette.EBONY_SIDE
	## Texels of front face under the face (its thickness); a pressed button's is less.
	var depth: int = 3
	## Rows of air above the shape: a pressed button's face sinks by them.
	var sunk: int = 0
	## A window's frame round its planks, in texels (0: a plate or a button).
	var frame: int = 0
	## The face's size and the nine-patch corner, which every chip, rivet and bracket stays in.
	var w: int = 32
	var h: int = 12
	var margin: int = 5
	## Iron on it: brackets at a window's corners, bands at a plate's ends, rivets on a button.
	var fittings: bool = false
	var seed: int = 1

	func copy() -> Spec:
		var other := Spec.new()
		for field: String in ["kind", "face", "side", "depth", "sunk", "frame", "w", "h", "margin", "fittings", "seed"]:
			other.set(field, get(field))
		return other


static func spec(kind: int, face: Color, side: Color, w: int, h: int, margin: int, depth: int, seed: int) -> Spec:
	var made := Spec.new()
	made.kind = kind
	made.face = face
	made.side = side
	made.w = w
	made.h = h
	made.margin = margin
	made.depth = depth
	made.seed = seed
	return made


## Built atlases of marks: hash(kind, face) -> [texture, rects].
static var _marks: Dictionary = {}
## Built sheets: hash(spec) -> ImageTexture.
static var _sheets: Dictionary = {}


## A box of `material` with `content` margins (logical pixels): `variants` versions of its
## image (each control takes one), its marks over it (`marked`).
static func material(made: Spec, content: Vector4, variants: int = 3, marked: bool = true, modulate: Color = Color.WHITE) -> PixelBox:
	var style := PixelBox.new()
	for index: int in variants:
		var version: Spec = made.copy()
		version.seed = made.seed + index * 101
		var key: int = hash([version.kind, version.face.to_html(), version.side.to_html(), version.depth, version.sunk, version.frame, version.w, version.h, version.margin, version.fittings, version.seed])
		if not _sheets.has(key):
			_sheets[key] = ImageTexture.create_from_image(sheet(version))
		var texture: ImageTexture = _sheets[key]
		if index == 0:
			style.texture = texture
		style.variants.append(texture)
	var m: int = made.margin
	style.margins = Vector4i(m, made.sunk + m, m, m + made.depth + 1)
	style.tile = true
	style.scale = GRID
	style.modulate = modulate
	style.content_margin_left = content.x
	style.content_margin_top = content.y
	style.content_margin_right = content.z
	style.content_margin_bottom = content.w
	if marked:
		var atlas: Array = marks_for(made.kind, made.face)
		style.marks = atlas[0]
		style.mark_rects.assign(atlas[1])
		var edge: int = made.frame + 2 if made.frame > 0 else 2
		style.mark_inset = Vector4i(edge, made.sunk + edge, edge, made.depth + 1 + edge)
		style.mark_seed = made.seed
		match made.kind:
			Kind.WOOD:
				if made.frame > 0:
					style.mark_density = 1.0 / 4200.0
					style.mark_range = Vector2i(3, 28)
				else:
					style.mark_density = 1.0 / 700.0
					style.mark_range = Vector2i(0, 3)
			Kind.IRON, Kind.BRONZE:
				style.mark_density = 1.0 / 320.0
				style.mark_range = Vector2i(1, 3)
			Kind.LACQUER:
				style.mark_density = 1.0 / 380.0
				style.mark_range = Vector2i(0, 3)
			Kind.PAPER:
				style.mark_density = 1.0 / 600.0
				style.mark_range = Vector2i(0, 2)
			Kind.BONE:
				style.mark_density = 1.0 / 260.0
				style.mark_range = Vector2i(0, 1)
	return style


# --- the sheet -----------------------------------------------------------------------------

## A sheet's image: `made.w`×`made.h` face over `made.depth` texels of front face, a texel of
## shadow under it, `made.sunk` rows of air over it.
static func sheet(made: Spec) -> Image:
	var rng := RandomNumberGenerator.new()
	rng.seed = made.seed
	var w: int = made.w
	var h: int = made.h
	var sh: int = h + made.depth
	var mask: PackedByteArray = _mask(made, rng)
	var dist: PackedInt32Array = _face_distance(mask, w, h)
	var px: int = maxi(1, w - 2 * made.margin)
	var py: int = maxi(1, h - 2 * made.margin)
	var planks: Array = _planks(made, rng, px, py)
	var image := Image.create_empty(w, made.sunk + sh + 1, false, Image.FORMAT_RGBA8)
	for y: int in sh:
		for x: int in w:
			if mask[y * w + x] == 0:
				continue
			var xx: int = posmod(x - made.margin, px)
			var colour: Color
			if y >= h:
				colour = _front(made, mask, x, y, xx)
			else:
				colour = _face(made, x, y, dist[y * w + x], xx, posmod(y - made.margin, py), planks)
			image.set_pixel(x, made.sunk + y, colour)
	if made.fittings:
		_fit(made, image, mask, dist, rng)
	for x: int in w:
		if mask[(sh - 1) * w + x] == 1:
			image.set_pixel(x, made.sunk + sh, Color(0.03, 0.02, 0.01, 0.42))
	return image


## The silhouette, `w` × (`h` + `depth`): corners cut, chips bitten out near the corners (inside
## the nine-patch corner), dents along the edges (repeating with the tiled edge); paper torn
## ragged all round.
static func _mask(made: Spec, rng: RandomNumberGenerator) -> PackedByteArray:
	var w: int = made.w
	var sh: int = made.h + made.depth
	var m: int = made.margin
	var mask := PackedByteArray()
	mask.resize(w * sh)
	mask.fill(1)
	var radius: int = 1 if made.kind == Kind.PAPER else 2
	for y: int in sh:
		for x: int in w:
			if mini(x, w - 1 - x) + mini(y, sh - 1 - y) < radius:
				mask[y * w + x] = 0
	var chips: int = 0
	var dents: int = 0
	match made.kind:
		Kind.WOOD:
			chips = rng.randi_range(2, 4)
			dents = rng.randi_range(2, 5)
		Kind.IRON, Kind.BRONZE:
			chips = rng.randi_range(0, 2)
			dents = rng.randi_range(0, 1)
		Kind.LACQUER, Kind.BONE:
			chips = rng.randi_range(1, 2)
		Kind.PAPER:
			chips = rng.randi_range(1, 3)
	var reach: int = m - 3
	for chip: int in chips:
		if reach < radius:
			break
		var corner: int = rng.randi_range(0, 3)
		var along: int = rng.randi_range(radius, reach)
		var deep: int = rng.randi_range(1, 2)
		var long: int = rng.randi_range(1, 3)
		var on_side: bool = rng.randf() < 0.5
		for a: int in long:
			for d: int in deep:
				var lx: int = d if on_side else along + a
				var ly: int = along + a if on_side else d
				if lx > reach or ly > reach:
					continue
				var x: int = lx if corner % 2 == 0 else w - 1 - lx
				var y: int = ly if corner < 2 else sh - 1 - ly
				mask[y * w + x] = 0
	for dent: int in dents:
		var long: int = rng.randi_range(1, 3)
		if rng.randf() < 0.6 and w - 2 * m > long + 2:
			var x0: int = rng.randi_range(m + 1, w - m - 1 - long)
			for a: int in long:
				mask[x0 + a] = 0
		elif sh - 2 * m - made.depth > long + 2:
			var y0: int = rng.randi_range(m + 1, sh - m - made.depth - 1 - long)
			var x: int = 0 if rng.randf() < 0.5 else w - 1
			for a: int in long:
				mask[(y0 + a) * w + x] = 0
	if made.kind == Kind.PAPER:
		# Torn all round: one texel bitten here and there, now and then two.
		for x: int in range(radius, w - radius):
			for y_edge: int in [0, sh - 1]:
				if rng.randf() < 0.3:
					mask[y_edge * w + x] = 0
					if rng.randf() < 0.15 and y_edge == 0:
						mask[w + x] = 0
		for y: int in range(radius, sh - radius):
			for x_edge: int in [0, w - 1]:
				if rng.randf() < 0.3:
					mask[y * w + x_edge] = 0
	return mask


## Every face texel's chessboard distance to the outside or the front face (0: on the edge).
static func _face_distance(mask: PackedByteArray, w: int, h: int) -> PackedInt32Array:
	var big: int = 1 << 20
	var dist := PackedInt32Array()
	dist.resize(w * h)
	for i: int in w * h:
		dist[i] = big if mask[i] == 1 else 0
	for y: int in h:
		for x: int in w:
			var i: int = y * w + x
			if dist[i] == 0:
				continue
			var best: int = dist[i]
			best = mini(best, (dist[i - 1] if x > 0 else 0) + 1)
			best = mini(best, (dist[i - w] if y > 0 else 0) + 1)
			best = mini(best, (dist[i - w - 1] if x > 0 and y > 0 else 0) + 1)
			best = mini(best, (dist[i - w + 1] if x < w - 1 and y > 0 else 0) + 1)
			dist[i] = best
	for y: int in range(h - 1, -1, -1):
		for x: int in range(w - 1, -1, -1):
			var i: int = y * w + x
			if dist[i] == 0:
				continue
			var best: int = dist[i]
			best = mini(best, (dist[i + 1] if x < w - 1 else 0) + 1)
			best = mini(best, (dist[i + w] if y < h - 1 else 0) + 1)
			best = mini(best, (dist[i + w + 1] if x < w - 1 and y < h - 1 else 0) + 1)
			best = mini(best, (dist[i + w - 1] if x > 0 and y < h - 1 else 0) + 1)
			dist[i] = best
	for i: int in w * h:
		dist[i] = dist[i] - 1 if mask[i] == 1 else -1
	return dist


## Which edge of the face a texel is nearest; 4 when it is on a corner's diagonal (a mitre).
static func _facing(x: int, y: int, w: int, h: int) -> int:
	var top: int = y
	var bottom: int = h - 1 - y
	var left: int = x
	var right: int = w - 1 - x
	var nearest: int = mini(mini(top, bottom), mini(left, right))
	var vertical: int = mini(top, bottom)
	var horizontal: int = mini(left, right)
	if vertical == horizontal:
		return 4
	if nearest == top:
		return Facing.TOP
	if nearest == bottom:
		return Facing.BOTTOM
	return Facing.LEFT if nearest == left else Facing.RIGHT


## Planks over the face's tile (`py` rows): their first rows, their tones, their joints (one
## or two across the `px` columns), their grain rows.
static func _planks(made: Spec, rng: RandomNumberGenerator, px: int, py: int) -> Array:
	var starts: Array[int] = []
	var tones: Array[float] = []
	var joints: Array = []
	var row: int = 0
	var low: int = 8 if made.frame > 0 else 6
	var high: int = 12 if made.frame > 0 else 9
	while row < py:
		starts.append(row)
		tones.append(rng.randf_range(-0.05, 0.05))
		var here: Array[int] = []
		if rng.randf() < (0.35 if made.frame > 0 else 0.25):
			here.append(rng.randi_range(0, px - 1))
		joints.append(here)
		row += rng.randi_range(low, high)
	if starts.size() > 1 and py - starts[starts.size() - 1] < 4:
		starts.pop_back()
		tones.pop_back()
		joints.pop_back()
	return [starts, tones, joints]


static func _face(made: Spec, x: int, y: int, d: int, xx: int, yy: int, planks: Array) -> Color:
	var face: Color = made.face
	var w: int = made.w
	var h: int = made.h
	var facing: int = _facing(x, y, w, h)
	if d == 0:
		if facing == Facing.BOTTOM:
			return made.side.lightened(0.1)
		if made.kind == Kind.PAPER:
			return face.darkened(0.22)
		return UiPalette.OUTLINE
	if d == 1 and made.kind == Kind.WOOD:
		match facing:
			Facing.TOP, 4:
				return face.lerp(UiPalette.PLANK, 0.42)
			Facing.LEFT:
				return face.lerp(UiPalette.PLANK, 0.25)
			Facing.RIGHT:
				return face.darkened(0.2)
			_:
				return face.darkened(0.3)
	if d == 1 and made.kind != Kind.PAPER:
		match facing:
			Facing.TOP, 4:
				return face.lightened(0.32 if made.kind in [Kind.IRON, Kind.BRONZE] else 0.2)
			Facing.LEFT:
				return face.lightened(0.12)
			Facing.RIGHT:
				return face.darkened(0.14)
			_:
				return face.darkened(0.22)
	match made.kind:
		Kind.WOOD:
			if made.frame > 0 and d < made.frame:
				# The frame: a lighter board along each edge, its grain along it, mitred.
				if facing == 4:
					return face.darkened(0.45)
				var frame_wood: Color = face.lerp(UiPalette.WOOD, 0.3)
				var along: int = xx if facing in [Facing.TOP, Facing.BOTTOM] else posmod(y - made.margin, maxi(1, h - 2 * made.margin))
				if _noise(along / 2, d * 13 + facing) > 0.64:
					frame_wood = frame_wood.darkened(0.16)
				elif _noise(along + 5, d * 7 + facing) > 0.93:
					frame_wood = frame_wood.lerp(UiPalette.PLANK, 0.3)
				return frame_wood
			if made.frame > 0 and d == made.frame:
				return face.darkened(0.55)
			return _plank(face, xx, yy, planks)
		Kind.IRON, Kind.BRONZE:
			var metal: Color = face
			if d == 2 and facing in [Facing.TOP, 4]:
				metal = metal.lightened(0.1)
			if y < h / 3:
				metal = metal.lightened(0.05)
			elif y > h * 2 / 3:
				metal = metal.darkened(0.07)
			var n: float = _noise(xx, y)
			if n > 0.88:
				metal = metal.darkened(0.09)
			elif n < 0.07:
				metal = metal.lightened(0.08)
			if made.kind == Kind.BRONZE and _noise(xx + 5, y + 9) > 0.93:
				metal = metal.lerp(UiPalette.PATINA, 0.55)
			return metal
		Kind.LACQUER:
			var lacquer: Color = face
			if d == 2 and facing in [Facing.TOP, 4]:
				lacquer = lacquer.lightened(0.1)
			if _noise(xx, y * 5 + 1) > 0.965:
				lacquer = lacquer.darkened(0.22)
			return lacquer
		Kind.PAPER:
			var paper: Color = face
			var n: float = _noise(xx, y * 7)
			if n > 0.93:
				paper = paper.darkened(0.06)
			elif n < 0.03:
				paper = paper.lightened(0.04)
			return paper
		_:
			var bone: Color = face
			if _noise(xx, y * 3) > 0.92:
				bone = bone.darkened(0.07)
			return bone


static func _plank(face: Color, xx: int, yy: int, planks: Array) -> Color:
	var starts: Array = planks[0]
	var index: int = 0
	for i: int in starts.size():
		if starts[i] <= yy:
			index = i
	var local: int = yy - int(starts[index])
	var tone: float = planks[1][index]
	var wood: Color = face.lerp(UiPalette.WOOD, 0.07 + tone)
	if local == 0:
		return face.darkened(0.36)
	for joint: int in planks[2][index]:
		if xx == joint:
			return face.darkened(0.3)
		if xx == joint + 1:
			wood = wood.lightened(0.04)
	if local == 1:
		return wood.lightened(0.04)
	# Grain: long broken streaks along the plank.
	if _noise(xx / 3, index * 17 + local) > 0.7 and _noise(xx, index * 5 + local * 3) > 0.2:
		wood = wood.darkened(0.07)
	elif _noise(xx * 3 + 1, yy * 5 + index) > 0.98:
		wood = wood.lerp(UiPalette.PLANK, 0.14)
	return wood


static func _front(made: Spec, mask: PackedByteArray, x: int, y: int, xx: int) -> Color:
	var w: int = made.w
	var sh: int = made.h + made.depth
	var edge: bool = x == 0 or x == w - 1 or y == sh - 1
	if not edge:
		edge = mask[y * w + x - 1] == 0 or mask[y * w + x + 1] == 0 or (y + 1 < sh and mask[(y + 1) * w + x] == 0)
	if edge:
		return made.side.darkened(0.25) if made.kind == Kind.PAPER else UiPalette.OUTLINE
	var colour: Color = made.side
	if y == sh - 2:
		colour = colour.darkened(0.2)
	var down: int = y - made.h
	match made.kind:
		Kind.WOOD:
			if _noise(xx, 3) > 0.8:
				colour = colour.darkened(0.12)
		Kind.IRON, Kind.BRONZE:
			# Rust (verdigris on bronze) running down the edge from the face.
			var drip: int = int(_noise(xx, 21) * 4.0)
			if _noise(xx, 11) > 0.78 and down <= drip:
				var stain: Color = UiPalette.RUST if made.kind == Kind.IRON else UiPalette.PATINA.darkened(0.2)
				colour = stain.darkened(0.15 * down)
		Kind.LACQUER:
			if _noise(xx, 5) > 0.84:
				colour = UNDERWOOD
	return colour


## Iron on the sheet: a window's corner brackets (now and then one gone, its nail holes left),
## a plate's end bands, a button's rivets (gilt studs on lacquer).
static func _fit(made: Spec, image: Image, mask: PackedByteArray, dist: PackedInt32Array, rng: RandomNumberGenerator) -> void:
	var w: int = made.w
	var h: int = made.h
	var top: int = made.sunk
	if made.kind == Kind.WOOD and made.frame > 0:
		var arm: int = made.margin - 1
		for corner: int in 4:
			var kept: bool = rng.randf() < 0.85
			var rusty: float = rng.randf_range(0.6, 0.85)
			for ly: int in arm:
				for lx: int in arm:
					var x: int = lx if corner % 2 == 0 else w - 1 - lx
					var y: int = ly if corner < 2 else h - 1 - ly
					var d: int = dist[y * w + x]
					if d < 1 or d > made.frame:
						continue
					if not kept:
						if (lx == 3 and ly == 2) or (lx == 2 and ly == 3) or (lx == arm - 3 and ly == 2):
							image.set_pixel(x, top + y, made.face.darkened(0.7))
						continue
					var iron: Color = UiPalette.IRON.lightened(0.14)
					if d == 1:
						iron = iron.lightened(0.3)
					elif d == made.frame or lx == arm - 1 or ly == arm - 1:
						iron = UiPalette.IRON_SIDE
					elif _noise(lx + corner * 9, ly) > rusty:
						iron = UiPalette.RUST.darkened(_noise(ly, lx + corner) * 0.3)
					elif _noise(lx, ly + corner * 5) > 0.85:
						iron = iron.darkened(0.14)
					image.set_pixel(x, top + y, iron)
			if kept:
				for rivet: Vector2i in [Vector2i(2, 2), Vector2i(arm - 4, 2), Vector2i(2, arm - 4)]:
					var x: int = rivet.x if corner % 2 == 0 else w - 2 - rivet.x
					var y: int = rivet.y if corner < 2 else h - 2 - rivet.y
					image.set_pixel(x, top + y, UiPalette.IRON.lightened(0.55))
					image.set_pixel(x + 1, top + y, UiPalette.IRON.lightened(0.2))
					image.set_pixel(x, top + y + 1, UiPalette.IRON.lightened(0.2))
					image.set_pixel(x + 1, top + y + 1, UiPalette.OUTLINE)
		return
	if made.kind == Kind.WOOD:
		# Iron bands across both ends of a plate, a rivet at each end of a band.
		for end: int in 2:
			for y: int in range(1, h - 1):
				for lx: int in range(2, 5):
					var x: int = lx if end == 0 else w - 1 - lx
					if mask[y * w + x] == 0 or dist[y * w + x] < 1:
						continue
					var iron: Color = UiPalette.IRON.lightened(0.15) if lx == 2 else UiPalette.IRON
					if lx == 4:
						iron = UiPalette.IRON_SIDE
					if _noise(lx + end * 7, posmod(y - made.margin, maxi(1, h - 2 * made.margin))) > 0.8:
						iron = UiPalette.RUST
					if lx == 3 and (y == 2 or y == h - 3):
						iron = UiPalette.IRON.lightened(0.5)
					image.set_pixel(x, top + y, iron)
		return
	var stud_light: Color = GILT.lightened(0.3) if made.kind == Kind.LACQUER else made.face.lightened(0.45)
	var stud_dark: Color = GILT.darkened(0.45) if made.kind == Kind.LACQUER else made.face.darkened(0.5)
	var stud_mid: Color = GILT if made.kind == Kind.LACQUER else made.face.lightened(0.15)
	for corner: int in 4:
		var x: int = 2 if corner % 2 == 0 else w - 4
		var y: int = 2 if corner < 2 else h - 4
		if mask[y * w + x] == 0 or mask[(y + 1) * w + x + 1] == 0:
			continue
		image.set_pixel(x, top + y, stud_light)
		image.set_pixel(x + 1, top + y, stud_mid)
		image.set_pixel(x, top + y + 1, stud_mid)
		image.set_pixel(x + 1, top + y + 1, stud_dark)


## A fixed speckle in [0, 1) for a pixel (the same every run).
static func _noise(x: int, y: int) -> float:
	var n: int = (x * 73856093) ^ (y * 19349663)
	n = ((n ^ (n >> 13)) * 1274126177) & 0x7FFFFFFF
	return float((n >> 7) & 0xFFFF) / 65536.0


# --- marks ---------------------------------------------------------------------------------

## The wear marks of a material on `face`, packed in one row: [texture, rects].
static func marks_for(kind: int, face: Color) -> Array:
	var key: int = hash([kind, face.to_html()])
	if _marks.has(key):
		return _marks[key]
	# The pieces' shapes by the kind alone (a hovered or pressed button keeps its marks), their
	# colours from the face.
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["marks", kind])
	var pieces: Array[Image] = []
	match kind:
		Kind.WOOD:
			for i: int in 5:
				pieces.append(_crack(rng, face.darkened(0.6), face.lightened(0.1), 7, 16))
			for i: int in 2:
				pieces.append(_knot(rng, face))
			for i: int in 2:
				pieces.append(_nail(rng))
			for i: int in 2:
				pieces.append(_scuff(rng, face.lightened(0.15)))
			pieces.append(_patch(rng, face))
			pieces.append(_blob(rng, 2, 4, [Color(UiPalette.INK.darkened(0.3), 0.55), Color(UiPalette.INK, 0.35)], Color(UiPalette.RUST.darkened(0.4), 0.5)))
		Kind.IRON:
			for i: int in 3:
				pieces.append(_blob(rng, 2, 3, [UiPalette.RUST.darkened(0.2), UiPalette.RUST, UiPalette.RUST.lightened(0.18)], UiPalette.RUST.darkened(0.55)))
			for i: int in 2:
				pieces.append(_hack(rng, face))
			for i: int in 2:
				pieces.append(_scratch(rng, face.lightened(0.3)))
			pieces.append(_dent(face))
		Kind.BRONZE:
			for i: int in 3:
				pieces.append(_blob(rng, 2, 3, [UiPalette.PATINA.darkened(0.2), UiPalette.PATINA, UiPalette.PATINA.lightened(0.25)], UiPalette.PATINA.darkened(0.5)))
			for i: int in 2:
				pieces.append(_scratch(rng, face.lightened(0.35)))
			pieces.append(_hack(rng, face))
		Kind.LACQUER:
			for i: int in 3:
				pieces.append(_chip(rng, face))
			for i: int in 2:
				pieces.append(_crack(rng, face.darkened(0.5), face.lightened(0.12), 4, 9))
			pieces.append(_scratch(rng, face.lightened(0.3)))
		Kind.PAPER:
			for i: int in 3:
				pieces.append(_blob(rng, 3, 5, [Color(face.darkened(0.07), 0.8), Color(face.darkened(0.05), 0.7)], Color(face.darkened(0.14), 0.8)))
		_:
			for i: int in 2:
				pieces.append(_blob(rng, 1, 2, [Color(face.darkened(0.12), 0.8)], Color(face.darkened(0.2), 0.8)))
	var width: int = 0
	var height: int = 1
	for piece: Image in pieces:
		width += piece.get_width() + 1
		height = maxi(height, piece.get_height())
	var atlas := Image.create_empty(maxi(1, width), height, false, Image.FORMAT_RGBA8)
	var rects: Array[Rect2i] = []
	var x: int = 0
	for piece: Image in pieces:
		atlas.blit_rect(piece, Rect2i(Vector2i.ZERO, piece.get_size()), Vector2i(x, 0))
		rects.append(Rect2i(Vector2i(x, 0), piece.get_size()))
		x += piece.get_width() + 1
	var built: Array = [ImageTexture.create_from_image(atlas), rects]
	_marks[key] = built
	return built


## A crack along the grain: a jagged dark line, a lit lip under it, now and then a branch.
static func _crack(rng: RandomNumberGenerator, dark: Color, lip: Color, shortest: int, longest: int) -> Image:
	var length: int = rng.randi_range(shortest, longest)
	var image := Image.create_empty(length, 6, false, Image.FORMAT_RGBA8)
	var y: int = rng.randi_range(1, 3)
	var cells: Array[Vector2i] = []
	for x: int in length:
		if x > 0 and rng.randf() < 0.32:
			y = clampi(y + (1 if rng.randf() < 0.5 else -1), 0, 4)
		cells.append(Vector2i(x, y))
		if x > 1 and x < length - 2 and rng.randf() < 0.14:
			cells.append(Vector2i(x, y + 1))
	if length > 8 and rng.randf() < 0.6:
		var at: Vector2i = cells[rng.randi_range(2, cells.size() - 3)]
		var step: int = 1 if at.y < 2 else -1
		for k: int in rng.randi_range(2, 3):
			at += Vector2i(1, step)
			if at.x < length and at.y >= 0 and at.y < 5:
				cells.append(at)
	for cell: Vector2i in cells:
		var tip: bool = cell.x == 0 or cell.x == length - 1
		image.set_pixelv(cell, dark.lightened(0.25) if tip else dark)
	for cell: Vector2i in cells:
		var under := cell + Vector2i(0, 1)
		if under.y < 6 and image.get_pixelv(under).a == 0.0:
			image.set_pixelv(under, Color(lip, 0.8))
	return image


## A knot in a plank: a dark eye ringed with bent grain.
static func _knot(rng: RandomNumberGenerator, face: Color) -> Image:
	var rows: Array[String] = ["..ooo..", ".o#+#o.", "..ooo.."]
	if rng.randf() < 0.5:
		rows = [".oo.", "o#+o", ".oo."]
	var image := Image.create_empty(rows[0].length(), rows.size(), false, Image.FORMAT_RGBA8)
	for y: int in rows.size():
		for x: int in rows[y].length():
			match rows[y][x]:
				"o":
					image.set_pixel(x, y, face.darkened(0.24))
				"#":
					image.set_pixel(x, y, face.darkened(0.5))
				"+":
					image.set_pixel(x, y, face.darkened(0.12))
	return image


## A short board nailed over a split: lighter wood, its outline, a nail at each end.
static func _patch(rng: RandomNumberGenerator, face: Color) -> Image:
	var w: int = rng.randi_range(12, 18)
	var h: int = rng.randi_range(5, 6)
	var image := Image.create_empty(w, h + 1, false, Image.FORMAT_RGBA8)
	var board: Color = face.lerp(UiPalette.WOOD, 0.22)
	for y: int in h:
		for x: int in w:
			var colour: Color = board
			if x == 0 or y == 0 or x == w - 1 or y == h - 1:
				colour = UiPalette.OUTLINE
			elif y == 1:
				colour = board.lerp(UiPalette.PLANK, 0.3)
			elif _noise(x / 2, y + w) > 0.7:
				colour = board.darkened(0.1)
			image.set_pixel(x, y, colour)
	for x: int in range(1, w - 1):
		image.set_pixel(x, h, Color(0, 0, 0, 0.35))
	for x: int in [2, w - 3]:
		image.set_pixel(x, h / 2, UiPalette.IRON.lightened(0.3))
		image.set_pixel(x, h / 2 + 1, UiPalette.RUST)
	return image


## A nail head, rust bleeding round it.
static func _nail(rng: RandomNumberGenerator) -> Image:
	var image := Image.create_empty(3, 3, false, Image.FORMAT_RGBA8)
	image.set_pixel(1, 1, UiPalette.IRON.lightened(0.3))
	image.set_pixel(2, 1, UiPalette.IRON_SIDE)
	image.set_pixel(1, 2, UiPalette.IRON_SIDE)
	image.set_pixel(2, 2, UiPalette.OUTLINE)
	for at: Vector2i in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, 2), Vector2i(2, 0)]:
		if rng.randf() < 0.45:
			image.set_pixelv(at, Color(UiPalette.RUST, 0.7))
	return image


## A scuff: a short lighter streak, broken.
static func _scuff(rng: RandomNumberGenerator, light: Color) -> Image:
	var length: int = rng.randi_range(4, 8)
	var image := Image.create_empty(length, 1, false, Image.FORMAT_RGBA8)
	for x: int in length:
		if rng.randf() < 0.72:
			image.set_pixel(x, 0, Color(light, 0.7))
	return image


## A rough blob (rust, verdigris, a stain): `colours` inside, `speck` dark specks in it.
static func _blob(rng: RandomNumberGenerator, smallest: int, largest: int, colours: Array, speck: Color) -> Image:
	var rx: int = rng.randi_range(smallest, largest)
	var ry: int = maxi(1, rx - rng.randi_range(0, 1))
	var image := Image.create_empty(rx * 2 + 1, ry * 2 + 1, false, Image.FORMAT_RGBA8)
	for y: int in ry * 2 + 1:
		for x: int in rx * 2 + 1:
			var dx: float = float(x - rx) / float(rx)
			var dy: float = float(y - ry) / float(ry)
			var r: float = dx * dx + dy * dy
			if r > 1.0 - rng.randf() * 0.45:
				continue
			var colour: Color = colours[clampi(int(r * colours.size()), 0, colours.size() - 1)]
			if rng.randf() < 0.12:
				colour = speck
			image.set_pixel(x, y, colour)
	return image


## A hack mark in metal: a bright gouge with its shadow under it.
static func _hack(rng: RandomNumberGenerator, face: Color) -> Image:
	var length: int = rng.randi_range(4, 7)
	var rise: bool = rng.randf() < 0.5
	var height: int = length / 2 + 2
	var image := Image.create_empty(length, height, false, Image.FORMAT_RGBA8)
	for i: int in length:
		var y: int = i / 2
		if rise:
			y = height - 2 - y
		image.set_pixel(i, y, face.lightened(0.5))
		image.set_pixel(i, y + 1, face.darkened(0.55))
	return image


## A thin scratch.
static func _scratch(rng: RandomNumberGenerator, light: Color) -> Image:
	var length: int = rng.randi_range(3, 6)
	var image := Image.create_empty(length, 3, false, Image.FORMAT_RGBA8)
	var y: int = rng.randi_range(0, 2)
	var step: int = 1 if y == 0 else -1
	for i: int in length:
		image.set_pixel(i, y, Color(light, 0.75))
		if i % 2 == 1:
			y = clampi(y + step, 0, 2)
	return image


## A dent: shadowed above, lit below.
static func _dent(face: Color) -> Image:
	var rows: Array[String] = ["##.", "#.+", ".++"]
	var image := Image.create_empty(3, 3, false, Image.FORMAT_RGBA8)
	for y: int in 3:
		for x: int in 3:
			if rows[y][x] == "#":
				image.set_pixel(x, y, face.darkened(0.32))
			elif rows[y][x] == "+":
				image.set_pixel(x, y, face.lightened(0.2))
	return image


## Lacquer chipped off: the wood under it, the broken edge dark above and lit below.
static func _chip(rng: RandomNumberGenerator, face: Color) -> Image:
	var shape: Image = _blob(rng, 1, 3, [UNDERWOOD, UNDERWOOD.lightened(0.08)], UNDERWOOD.darkened(0.3))
	var image := Image.create_empty(shape.get_width() + 2, shape.get_height() + 2, false, Image.FORMAT_RGBA8)
	image.blit_rect(shape, Rect2i(Vector2i.ZERO, shape.get_size()), Vector2i.ONE)
	for y: int in image.get_height():
		for x: int in image.get_width():
			if image.get_pixel(x, y).a > 0.0:
				continue
			var below: bool = y + 1 < image.get_height() and image.get_pixel(x, y + 1).a > 0.0
			var above: bool = y > 0 and image.get_pixel(x, y - 1).a > 0.0 and image.get_pixel(x, y - 1) != face.darkened(0.3)
			if below:
				image.set_pixel(x, y, face.darkened(0.3))
			elif above:
				image.set_pixel(x, y, face.lightened(0.22))
	return image


# --- small pieces --------------------------------------------------------------------------

## A recess cut into the wood: shadow under its top and left edges, a lit bottom and right rim,
## its grain faint.
static func well_image(fill: Color, w: int = 24, h: int = 16) -> Image:
	var image := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	for y: int in h:
		for x: int in w:
			var colour: Color = fill
			if y == 0 or x == 0:
				colour = fill.darkened(0.45)
			elif y == 1:
				colour = fill.darkened(0.22)
			elif y == h - 1 or x == w - 1:
				colour = fill.lightened(0.14)
			elif _noise(x, y) > 0.93:
				colour = fill.lightened(0.025)
			image.set_pixel(x, y, colour)
	return image


## The focus: a rim one design pixel thick with stepped corners.
static func rim_image(colour: Color, w: int = 12, h: int = 12) -> Image:
	var image := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	for y: int in h:
		for x: int in w:
			var cx: int = mini(x, w - 1 - x)
			var cy: int = mini(y, h - 1 - y)
			if cx + cy >= 2 and (cx == 0 or cy == 0 or cx + cy == 2):
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


static func rim(colour: Color = UiPalette.FOCUS) -> PixelBox:
	return box(rim_image(colour), Vector4i(3, 3, 3, 3), Vector4.ZERO)


## An icon image drawn on the grid: one texel GRID logical pixels (its sides even, so whole).
static func icon(image: Image) -> ImageTexture:
	var texture := ImageTexture.create_from_image(image)
	texture.set_size_override(Vector2i(roundi(image.get_width() * GRID), roundi(image.get_height() * GRID)))
	return texture


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
		"......",
	]
	var image := Image.create_empty(6, rows.size(), false, Image.FORMAT_RGBA8)
	for y: int in rows.size():
		for x: int in 6:
			var c: String = rows[y][x]
			if c == "#":
				image.set_pixel(x, y, UiPalette.FOCUS)
			elif c == "%":
				image.set_pixel(x, y, Color("c88a2c"))
	return image


## A switch for CheckButton: an iron slot with a block that sits left (off) or lit right (on).
static func switch_image(on: bool, disabled: bool = false) -> Image:
	var w: int = 18
	var h: int = 10
	var image := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	var slot: Color = UiPalette.IRON_SIDE
	var knob: Color = (UiPalette.LANTERN if on else UiPalette.MUTED)
	if disabled:
		knob = knob.lerp(UiPalette.INK, 0.6)
	for y: int in h:
		for x: int in w:
			var cx: int = mini(x, w - 1 - x)
			var cy: int = mini(y, h - 1 - y)
			if cx + cy < 2:
				continue
			var colour: Color = UiPalette.OUTLINE if cx == 0 or cy == 0 or cx + cy == 2 else (slot.darkened(0.3) if y <= 1 else slot)
			if colour != UiPalette.OUTLINE and _noise(x, y) > 0.86:
				colour = UiPalette.RUST.darkened(0.3)
			var left: int = 10 if on else 1
			if x >= left and x < left + 7 and y >= 1 and y < h - 1 and colour != UiPalette.OUTLINE:
				colour = knob.darkened(0.25) if y >= h - 3 else knob
				if y == 1:
					colour = knob.lightened(0.2)
			image.set_pixel(x, y, colour)
	return image
