class_name TitleMonument
extends RefCounted

## The title's monument (DECISIONS「标题画面」): the title's characters as a giant statue of big
## blocks of many sizes and materials, standing on a stepped stone plinth on a grassy rise whose
## foot is lost in cloud, the seal (侠; a cut knot where the language has none) a vermilion block
## at its right end, a few fallen stones in the grass. Built once per mask from the baked ink
## mask (one cell = CELL mask pixels), in cells: x to the right, y up (the plinth's top is 0),
## z toward the viewer. TitleLogo shows it and plays it: every block falls into place in turn
## (`land`), and on leaving tumbles away in turn (`fall`).

## Mask pixels per cell, and how many of a cell's CELL² pixels must be ink for it to be ink.
const CELL: int = 3
const INK_SHARE: int = 3
## Empty columns that part two characters (fewer are a gap inside one).
const CHARACTER_GAP: int = 3
## The characters' thickness, in cells.
const DEPTH: float = 8.0
## A character block's side in cells and how often each is tried (bigger ones only where the
## stroke has room).
const BLOCK_SIZES: Array[int] = [1, 2, 3, 4, 5]
const BLOCK_WEIGHTS: PackedFloat32Array = [0.04, 0.16, 0.34, 0.28, 0.18]
## How much of a block must lie on the stroke: big ones stand out past its edge a little.
const ON_STROKE: float = 0.92
## Materials come in patches this many cells across, PATCH_KEEP of the blocks in one being its
## material; the rest are strays.
const PATCH: int = 7
const PATCH_KEEP: float = 0.8
## The seal's side in cells and the size of one of its glyph's pixels.
const SEAL_SIDE: float = 11.0
## Materials (the shader draws each its own way).
const STONE: int = 1
const WOOD: int = 2
const IRON: int = 3
const BRONZE: int = 4
const GLASS: int = 5
const GOLD: int = 6
const LAMP: int = 7
const GRASS: int = 8
const EARTH: int = 9
const LACQUER: int = 10
## What time did to a block.
const LOOSE: int = 1
const RUSTED: int = 2
const MOSSY: int = 4
const CRACKED: int = 8
const HANGING: int = 16
## A piece of a character not joined to its foot: it hovers, bobbing.
const FLOATING: int = 32
## How far the plinth's two tiers and the rise reach past the characters (cells): x on each
## side, z behind, z in front.
const UPPER_TIER := Vector3(3.0, 3.0, 5.0)
const LOWER_TIER := Vector3(7.0, 6.0, 10.0)
const RISE := Vector3(14.0, 10.0, 20.0)
## Which part a block is of.
enum Part { LETTER, SEAL, PLINTH, GROUND, DETAIL }
## The characters' materials: how often each is picked, whether it makes up patches or only
## strays (glass, gold and the lamp-stones are accents), its colours, how likely each state is.
const MATERIALS: Dictionary = {
	STONE: {"weight": 42, "patch": true, "colours": ["6b6a6e", "7a756c", "5d6066", "837a6c", "565a60"], MOSSY: 0.2, CRACKED: 0.35, LOOSE: 0.06},
	WOOD: {"weight": 17, "patch": true, "colours": ["6a4428", "7a5030", "5a3a22", "845a36"], MOSSY: 0.15, CRACKED: 0.25, LOOSE: 0.07},
	IRON: {"weight": 15, "patch": true, "colours": ["5e636b", "535860", "686c72"], RUSTED: 0.4, LOOSE: 0.05},
	BRONZE: {"weight": 10, "patch": true, "colours": ["8a6230", "9a7038", "7a5428"], RUSTED: 0.4, LOOSE: 0.05},
	GLASS: {"weight": 10, "patch": false, "colours": ["3f9a78", "2f7f8f", "5a9ac0", "b07a2a"], CRACKED: 0.25, LOOSE: 0.04},
	GOLD: {"weight": 7, "patch": false, "colours": ["d8a640", "c8943a"], LOOSE: 0.05},
	LAMP: {"weight": 13, "patch": false, "colours": ["ffc85a", "7fe6ff", "ff8a3a", "c8ff8a"], LOOSE: 0.03},
}
const PLINTH_COLOURS: Array[String] = ["8a857c", "7a766e", "948c80", "6e6a64", "857d70"]
const ROCK_COLOURS: Array[String] = ["77736b", "666259", "5e5a52"]
const EARTH_COLOURS: Array[String] = ["6b5236", "5a4530", "4e3c2a"]
const GRASS_COLOURS: Array[String] = ["6a8a3c", "5f7a36", "77944a", "566e30"]

## Monuments built in this run, by mask and seal.
static var _built: Dictionary = {}


class Block:
	var centre: Vector3
	var size: Vector3 = Vector3.ONE
	var tilt: Vector3 = Vector3.ZERO
	var colour: Color
	var material: int = STONE
	var state: int = 0
	## When it lands in the arrival (0..1); below 0 it stands from the start.
	var land: float = -1.0
	## When it tumbles away on leaving (0..1).
	var fall: float = 0.5
	var part: int = Part.LETTER


var blocks: Array[Block] = []
## Width and height of everything, in cells, and where its middle is.
var span: float = 1.0
var tall: float = 1.0
var middle: Vector3 = Vector3.ZERO
## The characters' extent (x from, x to, top), in cells.
var letters_from: float = 0.0
var letters_to: float = 0.0
var letters_top: float = 0.0


## The monument of `mask_path` (white = ink) and `seal_path` ("" for the knot), built once.
static func of(mask_path: String, seal_path: String) -> TitleMonument:
	var key: String = mask_path + "|" + seal_path
	if not _built.has(key):
		var monument := TitleMonument.new()
		monument._build(_ink(mask_path), _ink(seal_path))
		_built[key] = monument
	return _built[key]


func _build(ink: Array[PackedByteArray], seal: Array[PackedByteArray]) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var grid: Array[PackedByteArray] = _grounded(_coarse(ink))
	var h: int = grid.size()
	var w: int = 0 if h == 0 else grid[0].size()
	letters_from = -w / 2.0 - (SEAL_SIDE + 3.0) / 2.0
	letters_to = letters_from + w + SEAL_SIDE + 3.0
	letters_top = h
	_letters(grid, w, h, rng)
	_seal(seal, rng)
	_plinth(rng)
	_ground(rng)
	var low := Vector3(INF, INF, INF)
	var high := Vector3(-INF, -INF, -INF)
	for block: Block in blocks:
		low = low.min(block.centre - block.size / 2.0)
		high = high.max(block.centre + block.size / 2.0)
	span = high.x - low.x
	tall = high.y - low.y
	middle = (low + high) / 2.0


## The mask as rows of ink (1) and paper; empty when there is none.
static func _ink(path: String) -> Array[PackedByteArray]:
	var rows: Array[PackedByteArray] = []
	if path.is_empty() or not ResourceLoader.exists(path):
		return rows
	var texture: Texture2D = load(path) as Texture2D
	var image: Image = null if texture == null else texture.get_image()
	if image == null:
		return rows
	for y: int in image.get_height():
		var row := PackedByteArray()
		row.resize(image.get_width())
		for x: int in image.get_width():
			row[x] = 1 if image.get_pixel(x, y).r > 0.5 else 0
		rows.append(row)
	return rows


## The mask in cells: a cell is ink when INK_SHARE of its pixels are.
static func _coarse(ink: Array[PackedByteArray]) -> Array[PackedByteArray]:
	var rows: Array[PackedByteArray] = []
	var h: int = ink.size()
	var w: int = 0 if h == 0 else ink[0].size()
	for cy: int in ceili(h / float(CELL)):
		var row := PackedByteArray()
		row.resize(ceili(w / float(CELL)))
		for cx: int in row.size():
			var count: int = 0
			for y: int in range(cy * CELL, mini(h, cy * CELL + CELL)):
				for x: int in range(cx * CELL, mini(w, cx * CELL + CELL)):
					count += ink[y][x]
			row[cx] = 1 if count >= INK_SHARE else 0
		rows.append(row)
	return rows


## Every character (a run of columns with ink, between at least CHARACTER_GAP empty ones)
## dropped so its lowest cell stands on the plinth.
static func _grounded(grid: Array[PackedByteArray]) -> Array[PackedByteArray]:
	var h: int = grid.size()
	var w: int = 0 if h == 0 else grid[0].size()
	var out: Array[PackedByteArray] = []
	for y: int in h:
		var row := PackedByteArray()
		row.resize(w)
		out.append(row)
	var x: int = 0
	while x < w:
		if _column_low(grid, x) < 0:
			x += 1
			continue
		var end: int = x
		var low: int = -1
		var blank: int = 0
		while end < w and blank < CHARACTER_GAP:
			var column: int = _column_low(grid, end)
			blank = blank + 1 if column < 0 else 0
			low = maxi(low, column)
			end += 1
		var drop: int = h - 1 - low
		for cx: int in range(x, end):
			for y: int in h:
				if grid[y][cx] == 1:
					out[y + drop][cx] = 1
		x = end
	return out


## The lowest ink row of a column, -1 when it has none.
static func _column_low(grid: Array[PackedByteArray], x: int) -> int:
	for y: int in range(grid.size() - 1, -1, -1):
		if grid[y][x] == 1:
			return y
	return -1


## The characters laid in blocks of every size (bigger mid-stroke), patches of one material
## with strays, each with what time has done to it; pieces not joined to their foot hover.
func _letters(grid: Array[PackedByteArray], w: int, h: int, rng: RandomNumberGenerator) -> void:
	var depth: PackedFloat32Array = _distance(grid, w, h)
	var footed: PackedByteArray = _footed(grid, w, h)
	var taken := PackedByteArray()
	taken.resize(w * h)
	var cells: Array[Vector2i] = []
	for y: int in h:
		for x: int in w:
			if grid[y][x] == 1:
				cells.append(Vector2i(x, y))
	for i: int in range(cells.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var swap: Vector2i = cells[i]
		cells[i] = cells[j]
		cells[j] = swap
	var patches: Dictionary = {}
	var x0: float = letters_from
	for cell: Vector2i in cells:
		if taken[cell.y * w + cell.x] == 1:
			continue
		var room: int = clampi(int(depth[cell.y * w + cell.x] * 2.0 + 2.0), 1, BLOCK_SIZES[-1])
		var size: int = mini(BLOCK_SIZES[rng.rand_weighted(BLOCK_WEIGHTS)], room)
		var anchor := Vector2i(-1, -1)
		while size >= 2:
			anchor = _fit(grid, taken, w, h, cell, size, rng)
			if anchor.x >= 0:
				break
			size -= 1
		if anchor.x < 0:
			anchor = cell
			size = 1
		var hovering: bool = false
		for y: int in range(anchor.y, anchor.y + size):
			for x: int in range(anchor.x, anchor.x + size):
				taken[y * w + x] = 1
				hovering = hovering or footed[y * w + x] == 0
		var free_below: bool = anchor.y + size < h
		if free_below:
			for x: int in range(anchor.x, anchor.x + size):
				free_below = free_below and grid[anchor.y + size][x] == 0
		var where := Vector2i(floori((anchor.x + rng.randi_range(-1, 1)) / float(PATCH)), floori((anchor.y + rng.randi_range(-1, 1)) / float(PATCH)))
		if not patches.has(where):
			patches[where] = _pick(rng, true)
		var kind: int = patches[where] if rng.randf() < PATCH_KEEP else _pick(rng, false)
		var block: Block = _letter_block(anchor, size, kind, free_below, w, h, rng)
		if hovering:
			block.state |= FLOATING
		block.centre.x += x0 + w / 2.0
		var xn: float = clampf((block.centre.x - x0) / (w + SEAL_SIDE + 3.0), 0.0, 1.0)
		var yn: float = clampf(block.centre.y / h, 0.0, 1.0)
		block.land = 0.3 + 0.5 * xn + 0.1 * yn + rng.randf() * 0.05
		block.fall = 0.05 + 0.35 * xn + 0.2 * (1.0 - yn) + rng.randf() * 0.06
		blocks.append(block)


## A character block: its material's colour, its relief, a small skew and its age.
func _letter_block(anchor: Vector2i, s: int, kind: int, free_below: bool, w: int, h: int, rng: RandomNumberGenerator) -> Block:
	var look: Dictionary = MATERIALS[kind]
	var colours: Array = look["colours"]
	var block := Block.new()
	block.part = Part.LETTER
	block.material = kind
	block.colour = Color(colours[rng.randi() % colours.size()]).lerp(Color.BLACK, rng.randf() * 0.15)
	for flag: int in [RUSTED, MOSSY, CRACKED, LOOSE]:
		if rng.randf() < float(look.get(flag, 0.0)):
			block.state |= flag
	var gap: float = rng.randf_range(0.05, 0.14)
	var front: float = DEPTH / 2.0 + rng.randf_range(-0.3, 0.5) + (0.3 if s >= 3 else 0.0)
	var back: float = -DEPTH / 2.0 - rng.randf() * 0.4
	block.size = Vector3(s - gap, s - gap, front - back)
	block.centre = Vector3(anchor.x + s / 2.0 - w / 2.0, h - anchor.y - s / 2.0, (front + back) / 2.0)
	block.tilt = Vector3(rng.randf_range(-0.015, 0.015), rng.randf_range(-0.015, 0.015), rng.randf_range(-0.025, 0.025))
	if block.state & LOOSE:
		block.tilt.x += rng.randf_range(0.05, 0.12)
		block.centre.z += rng.randf_range(0.3, 0.9)
		if free_below and s <= 3 and rng.randf() < 0.5:
			block.state = (block.state & ~LOOSE) | HANGING
			block.tilt.z = rng.randf_range(0.2, 0.45) * (1.0 if rng.randf() < 0.5 else -1.0)
			block.centre.y -= s * 0.35
	return block


## The cells joined (side by side) to a cell on the bottom row: the rest hover.
static func _footed(grid: Array[PackedByteArray], w: int, h: int) -> PackedByteArray:
	var seen := PackedByteArray()
	seen.resize(w * h)
	var open: Array[Vector2i] = []
	for x: int in w:
		if grid[h - 1][x] == 1:
			seen[(h - 1) * w + x] = 1
			open.append(Vector2i(x, h - 1))
	while not open.is_empty():
		var at: Vector2i = open.pop_back()
		for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = at + step
			if next.x < 0 or next.y < 0 or next.x >= w or next.y >= h:
				continue
			if grid[next.y][next.x] == 1 and seen[next.y * w + next.x] == 0:
				seen[next.y * w + next.x] = 1
				open.append(next)
	return seen


## Where an s-block holding `cell` fits: all of it free, ON_STROKE of it ink. (-1, -1) if
## nowhere.
static func _fit(grid: Array[PackedByteArray], taken: PackedByteArray, w: int, h: int, cell: Vector2i, s: int, rng: RandomNumberGenerator) -> Vector2i:
	var start: int = rng.randi_range(0, s * s - 1)
	for k: int in s * s:
		var o: int = (start + k) % (s * s)
		var anchor := Vector2i(cell.x - o % s, cell.y - o / s)
		if anchor.x < 0 or anchor.y < 0 or anchor.x + s > w or anchor.y + s > h:
			continue
		var fits: bool = true
		var inked: int = 0
		for y: int in range(anchor.y, anchor.y + s):
			for x: int in range(anchor.x, anchor.x + s):
				if taken[y * w + x] == 1:
					fits = false
					break
				inked += grid[y][x]
			if not fits:
				break
		if fits and inked >= ceili(s * s * ON_STROKE):
			return anchor
	return Vector2i(-1, -1)


## A material by weight: of those that make up patches, or of all of them.
static func _pick(rng: RandomNumberGenerator, patch: bool) -> int:
	var kinds: Array[int] = []
	var weights := PackedFloat32Array()
	for kind: int in MATERIALS:
		if MATERIALS[kind]["patch"] or not patch:
			kinds.append(kind)
			weights.append(float(MATERIALS[kind]["weight"]))
	return kinds[rng.rand_weighted(weights)]


## The seal at the right end, standing on the plinth: a vermilion lacquered block with 侠 inlaid
## in its face, or a cut knot where the language has no seal. It lands last, a stamp.
func _seal(glyph: Array[PackedByteArray], rng: RandomNumberGenerator) -> void:
	var x: float = letters_to - SEAL_SIDE / 2.0
	var body := Block.new()
	body.part = Part.SEAL
	body.material = LACQUER
	body.colour = Color("a8301c")
	body.size = Vector3(SEAL_SIDE, SEAL_SIDE, 4.0)
	body.centre = Vector3(x, SEAL_SIDE / 2.0, 0.0)
	body.state = CRACKED
	body.land = 0.93
	body.fall = 0.42
	blocks.append(body)
	var sh: int = glyph.size()
	var sw: int = 0 if sh == 0 else glyph[0].size()
	var side: int = maxi(maxi(sw, sh) + 6, 26)
	var pixel: float = (SEAL_SIDE - 1.0) / side
	for y: int in side:
		for gx: int in side:
			var cut: bool
			if sh > 0:
				var px: int = gx - (side - sw) / 2
				var py: int = y - (side - sh) / 2
				cut = px >= 0 and py >= 0 and px < sw and py < sh and glyph[py][px] == 1
			else:
				var ring: int = mini(mini(gx, y), mini(side - 1 - gx, side - 1 - y))
				cut = ring == 3 or (ring >= 7 and ring <= 8) or (gx == side / 2 and ring >= 7) or (y == side / 2 and ring >= 7)
			if not cut:
				continue
			var inlay := Block.new()
			inlay.part = Part.SEAL
			inlay.material = STONE
			inlay.colour = Color("e9d6b8").lerp(Color("d8c090"), rng.randf() * 0.3)
			inlay.size = Vector3(pixel * 1.2, pixel * 1.2, 0.3)
			inlay.centre = Vector3(x - (SEAL_SIDE - 1.0) / 2.0 + (gx + 0.5) * pixel, SEAL_SIDE - 0.5 - (y + 0.5) * pixel, 2.1)
			inlay.land = 0.93
			inlay.fall = 0.42
			blocks.append(inlay)


## Two stepped tiers of worn stone courses under the characters: big dressed stones of many
## lengths, the top paved; mossy and cracked, a few edge stones worn low.
func _plinth(rng: RandomNumberGenerator) -> void:
	var half: float = (letters_to - letters_from) / 2.0
	var mid: float = (letters_to + letters_from) / 2.0
	var tiers: Array = [
		# x half-width, z from, z to, y from, course heights, when they land
		[half + LOWER_TIER.x, -DEPTH / 2.0 - LOWER_TIER.y, DEPTH / 2.0 + LOWER_TIER.z, -7.0, [3.0], 0.02],
		[half + UPPER_TIER.x, -DEPTH / 2.0 - UPPER_TIER.y, DEPTH / 2.0 + UPPER_TIER.z, -4.0, [2.0, 2.0], 0.12],
	]
	for tier: Array in tiers:
		var y: float = tier[3]
		var courses: Array = tier[4]
		for c: int in courses.size():
			var tall_c: float = courses[c]
			var z: float = tier[1]
			while z < tier[2] - 0.01:
				var depth_c: float = minf(rng.randf_range(3.0, 6.0), tier[2] - z)
				var x: float = mid - tier[0]
				var shift: float = rng.randf_range(0.0, 3.0) if c % 2 == 1 else 0.0
				var first: bool = true
				while x < mid + tier[0] - 0.01:
					var length: float = minf(rng.randf_range(3.0, 7.5) - (shift if first else 0.0), mid + tier[0] - x)
					length = maxf(length, minf(1.5, mid + tier[0] - x))
					first = false
					var stone := Block.new()
					stone.part = Part.PLINTH
					stone.material = STONE
					stone.colour = Color(PLINTH_COLOURS[rng.randi() % PLINTH_COLOURS.size()]).lerp(Color.BLACK, rng.randf() * 0.1)
					var worn: float = rng.randf() * 0.35 if z + depth_c >= tier[2] - 0.01 or c == courses.size() - 1 else 0.0
					stone.size = Vector3(length - 0.12, tall_c - 0.1 - worn, depth_c - 0.12)
					stone.centre = Vector3(x + length / 2.0, y + (tall_c - worn) / 2.0, z + depth_c / 2.0)
					stone.tilt = Vector3(rng.randf_range(-0.01, 0.01), rng.randf_range(-0.02, 0.02), rng.randf_range(-0.01, 0.01))
					if rng.randf() < (0.35 if c == courses.size() - 1 else 0.15):
						stone.state |= MOSSY
					if rng.randf() < 0.3:
						stone.state |= CRACKED
					var xn: float = (x - (mid - tier[0])) / (tier[0] * 2.0)
					stone.land = float(tier[5]) + 0.08 * c / maxf(1.0, courses.size()) + 0.06 * xn + rng.randf() * 0.04
					stone.fall = 0.55 + 0.25 * xn + rng.randf() * 0.1
					blocks.append(stone)
					x += length
				z += depth_c
			y += tall_c


## The grassy rise the plinth stands on, its edges falling away into the cloud; grass tufts,
## rocks and a few stones fallen from the monument in the grass. It is there from the start.
func _ground(rng: RandomNumberGenerator) -> void:
	var half: float = (letters_to - letters_from) / 2.0 + RISE.x
	var mid: float = (letters_to + letters_from) / 2.0
	var z_back: float = -DEPTH / 2.0 - RISE.y
	var z_front: float = DEPTH / 2.0 + RISE.z
	var zc: float = (z_back + z_front) / 2.0
	var zr: float = (z_front - z_back) / 2.0
	var plinth_half: float = (letters_to - letters_from) / 2.0 + LOWER_TIER.x
	var step: float = 2.0
	var x: float = mid - half
	while x < mid + half:
		var z: float = z_back
		while z < z_front:
			var r: float = Vector2((x + step / 2.0 - mid) / half, (z + step / 2.0 - zc) / zr).length()
			r += (rng.randf() - 0.5) * 0.08
			if r >= 1.0:
				z += step
				continue
			var swell: float = sin(x * 0.21 + z * 0.13) * 0.5 + sin(x * 0.07 - z * 0.31) * 0.4
			var top: float = -7.0 + (1.0 - r) * 0.6 + swell * 0.6 + rng.randf() * 0.15 - maxf(0.0, r - 0.7) * 12.0
			var bottom: float = -11.0 - (1.0 - r) * 5.0
			var under_plinth: bool = absf(x + step / 2.0 - mid) < plinth_half and z + step > -DEPTH / 2.0 - LOWER_TIER.y and z < DEPTH / 2.0 + LOWER_TIER.z
			var rock := Block.new()
			rock.part = Part.GROUND
			rock.material = EARTH if r < 0.8 else STONE
			rock.colour = Color(EARTH_COLOURS[rng.randi() % EARTH_COLOURS.size()] if r < 0.8 else ROCK_COLOURS[rng.randi() % ROCK_COLOURS.size()])
			rock.size = Vector3(step, top - bottom, step)
			rock.centre = Vector3(x + step / 2.0, (top + bottom) / 2.0, z + step / 2.0)
			rock.fall = 2.0
			blocks.append(rock)
			if not under_plinth and r < 0.9:
				var grass := Block.new()
				grass.part = Part.GROUND
				grass.material = GRASS
				grass.colour = Color(GRASS_COLOURS[0]).lerp(Color(GRASS_COLOURS[2]), swell * 0.5 + 0.5).lerp(Color(GRASS_COLOURS[3]), rng.randf() * 0.25)
				grass.size = Vector3(step, 0.5, step)
				grass.centre = Vector3(x + step / 2.0, top + 0.25, z + step / 2.0)
				grass.fall = 2.0
				blocks.append(grass)
				if rng.randf() < 0.18:
					_tuft(Vector3(x + rng.randf() * step, top + 0.5, z + rng.randf() * step), rng)
			z += step
		x += step
	# Stones fallen from the monument, half sunk in the grass in front of it.
	for i: int in 7:
		var fallen := Block.new()
		fallen.part = Part.DETAIL
		fallen.material = STONE
		fallen.colour = Color(PLINTH_COLOURS[rng.randi() % PLINTH_COLOURS.size()])
		var s: float = rng.randf_range(1.2, 3.0)
		fallen.size = Vector3(s, s * rng.randf_range(0.6, 1.0), s * rng.randf_range(0.7, 1.1))
		var side: float = -1.0 if i % 2 == 0 else 1.0
		fallen.centre = Vector3(mid + side * rng.randf_range(plinth_half + 1.0, half - 3.0), -6.6 + s * 0.3, rng.randf_range(DEPTH / 2.0 + 6.0, z_front - 5.0))
		fallen.tilt = Vector3(rng.randf_range(-0.4, 0.4), rng.randf_range(-0.6, 0.6), rng.randf_range(-0.4, 0.4))
		fallen.state = MOSSY | (CRACKED if rng.randf() < 0.5 else 0)
		fallen.fall = 2.0
		blocks.append(fallen)


func _tuft(at: Vector3, rng: RandomNumberGenerator) -> void:
	for blade: int in rng.randi_range(2, 4):
		var leaf := Block.new()
		leaf.part = Part.DETAIL
		leaf.material = GRASS
		leaf.colour = Color(GRASS_COLOURS[rng.randi() % GRASS_COLOURS.size()]).lightened(0.1)
		var height: float = rng.randf_range(0.6, 1.4)
		leaf.size = Vector3(0.3, height, 0.3)
		leaf.centre = at + Vector3(rng.randf_range(-0.5, 0.5), height / 2.0, rng.randf_range(-0.5, 0.5))
		leaf.tilt = Vector3(rng.randf_range(-0.3, 0.3), 0.0, rng.randf_range(-0.3, 0.3))
		leaf.fall = 2.0
		blocks.append(leaf)


## Chamfer distance from the edge of the ink (1 at the edge): strokes are widest mid-stroke.
static func _distance(ink: Array[PackedByteArray], w: int, h: int) -> PackedFloat32Array:
	var d := PackedFloat32Array()
	d.resize(w * h)
	for y: int in h:
		for x: int in w:
			d[y * w + x] = 999.0 if ink[y][x] == 1 else 0.0
	for pass_index: int in 2:
		var ys: Array = range(h) if pass_index == 0 else range(h - 1, -1, -1)
		var xs: Array = range(w) if pass_index == 0 else range(w - 1, -1, -1)
		var step: int = 1 if pass_index == 0 else -1
		for y: int in ys:
			for x: int in xs:
				var i: int = y * w + x
				if d[i] == 0.0:
					continue
				var best: float = d[i]
				var px: int = x - step
				var py: int = y - step
				best = minf(best, d[y * w + px] + 1.0 if px >= 0 and px < w else 1.0)
				best = minf(best, d[py * w + x] + 1.0 if py >= 0 and py < h else 1.0)
				if px >= 0 and px < w and py >= 0 and py < h:
					best = minf(best, d[py * w + px] + 1.4)
				var qx: int = x + step
				if qx >= 0 and qx < w and py >= 0 and py < h:
					best = minf(best, d[py * w + qx] + 1.4)
				d[i] = best
	return d
