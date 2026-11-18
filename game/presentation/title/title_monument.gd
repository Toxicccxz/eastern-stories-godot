class_name TitleMonument
extends RefCounted

## The title's stones (DECISIONS「标题画面」): every character of the title (东方故事, or the
## words of Eastern Stories), in a free running hand and each its own size, a giant slab of rock
## cut to its shape and laid in blocks of many sizes, fallen onto the 沙盘 and stuck in it at a
## slant, cracked into a few great fragments whose seams glow; its faces rough,
## its rims worn and chipped, moss on its tops, a few crystals in it that blink; the seal (侠;
## a cut knot where the language has none) a vermilion block fallen last; rubble round their
## feet. Built once per mask (CELL mask pixels a voxel), in voxels: x to the right, y up (the
## ground is 0), z toward the viewer. TitleLogo shows and plays it.

## Mask pixels per voxel, and how many of a voxel's CELL² pixels must be ink.
const CELL: int = 2
const INK_SHARE: int = 2
## Empty columns that part two characters (fewer are a gap inside one).
const CHARACTER_GAP: int = 2
## A character's thickness, in voxels.
const DEPTH: float = 14.0
## A block's side in voxels and how often each is tried (bigger ones only where the stroke has
## room); blocks stand this far apart.
const BLOCK_SIZES: Array[int] = [1, 2, 3, 4, 5, 6]
const BLOCK_WEIGHTS: PackedFloat32Array = [0.06, 0.2, 0.26, 0.22, 0.16, 0.1]
const BLOCK_GAP: float = 0.07
## How many fragments a character breaks into: one per this many voxels of face, within bounds.
const FRAGMENT_AREA: float = 650.0
const FRAGMENTS_MIN: int = 2
const FRAGMENTS_MAX: int = 5
## Of the voxels on the face, how many hold a crystal.
const CRYSTAL_SHARE: float = 0.004
## The seal's side in voxels.
const SEAL_SIDE: float = 24.0
## The most stones (characters and the seal) the shader can tell apart, and fragments.
const MOST_STONES: int = 16
const MOST_FRAGMENTS: int = 64
## Materials.
const ROCK: int = 1
const CRYSTAL: int = 2
const LACQUER: int = 3
const INLAY: int = 4
## Marks on a voxel.
const MOSSY: int = 1
const CRACKED: int = 2
## Next to a crack between fragments: light leaks from its sides.
const SEAM: int = 4
## On the rim of the character: worn.
const RIM: int = 8
## Rock a fragment may be of.
const ROCKS: Array[String] = ["5f6168", "6d675f", "7c6a56", "4b4d53", "5a6658", "6e5446", "77736c"]
const CRYSTALS: Array[String] = ["7fe6ff", "ffd36a", "9dffb0", "c9a2ff"]

## Monuments built in this run, by mask and seal.
static var _built: Dictionary = {}


## One voxel column of a stone (or a piece of the seal, or rubble).
class Block:
	var centre: Vector3
	var size: Vector3 = Vector3.ONE
	var basis: Basis = Basis.IDENTITY
	var colour: Color
	var material: int = ROCK
	var marks: int = 0
	var stone: int = 0
	var fragment: int = 0


## A character or the seal: where it stands, when it lands and how wide it is.
class Stone:
	var pivot: Vector3
	var half_width: float = 1.0
	## When it lands in the arrival (0..1 of it).
	var land: float = 0.0


## A piece of a stone that breaks away on leaving.
class Fragment:
	var centre: Vector3
	## When it breaks away (0..1 of the leaving).
	var leave: float = 0.0


var blocks: Array[Block] = []
var stones: Array[Stone] = []
var fragments: Array[Fragment] = []
## Rubble at the stones' feet: [rest centre, size, basis, colour, stone].
var rubble: Array[Array] = []
## Width and height of the stones, in voxels, and the middle of their width.
var span: float = 1.0
var tall: float = 1.0
var middle_x: float = 0.0


## The stones of `mask_path` (white = ink) and `seal_path` ("" for the knot), built once.
static func of(mask_path: String, seal_path: String) -> TitleMonument:
	var key: String = mask_path + "|" + seal_path
	if not _built.has(key):
		var monument := TitleMonument.new()
		monument._build(_ink(mask_path), _ink(seal_path))
		_built[key] = monument
	return _built[key]


func _build(ink: Array[PackedByteArray], seal: Array[PackedByteArray]) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 23
	var grid: Array[PackedByteArray] = _coarse(ink)
	var h: int = grid.size()
	var w: int = 0 if h == 0 else grid[0].size()
	var runs: Array[Vector2i] = _characters(grid)
	var count: int = runs.size() + 1
	for index: int in runs.size():
		_character(grid, w, h, runs[index], index, count, rng)
	_seal(seal, float(w) + 4.0, h, count - 1, count, rng)
	_rubble(rng)
	var low: float = INF
	var high: float = -INF
	for block: Block in blocks:
		low = minf(low, block.centre.x - block.size.x / 2.0)
		high = maxf(high, block.centre.x + block.size.x / 2.0)
		tall = maxf(tall, block.centre.y + block.size.y / 2.0)
	span = high - low
	middle_x = (low + high) / 2.0


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


## The mask in voxels: a voxel is ink when INK_SHARE of its pixels are.
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


## The characters: runs of columns with ink, parted by at least CHARACTER_GAP empty ones.
static func _characters(grid: Array[PackedByteArray]) -> Array[Vector2i]:
	var runs: Array[Vector2i] = []
	var h: int = grid.size()
	var w: int = 0 if h == 0 else grid[0].size()
	var x: int = 0
	while x < w:
		if not _column_has_ink(grid, x):
			x += 1
			continue
		var end: int = x
		var blank: int = 0
		while end < w and blank < CHARACTER_GAP:
			blank = 0 if _column_has_ink(grid, end) else blank + 1
			end += 1
		runs.append(Vector2i(x, end - blank))
		x = end
	return runs


static func _column_has_ink(grid: Array[PackedByteArray], x: int) -> bool:
	for row: PackedByteArray in grid:
		if row[x] == 1:
			return true
	return false


## One character: its voxels cut from the rock, broken into fragments along glowing seams, set
## in the ground at its own slant.
func _character(grid: Array[PackedByteArray], w: int, h: int, run: Vector2i, index: int, count: int, rng: RandomNumberGenerator) -> void:
	var cells: Array[Vector2i] = []
	var low_row: int = 0
	for y: int in h:
		for x: int in range(run.x, run.y):
			if grid[y][x] == 1:
				cells.append(Vector2i(x, y))
				low_row = maxi(low_row, y)
	if cells.is_empty():
		return
	var stone := Stone.new()
	# The character's foot goes this far into the ground.
	var sink: float = rng.randf_range(1.0, 2.5)
	stone.pivot = Vector3((run.x + run.y) / 2.0, 0.0, 0.0)
	stone.half_width = (run.y - run.x) / 2.0
	stone.land = 0.08 + 0.72 * index / maxf(1.0, count - 1.0)
	var stone_index: int = stones.size()
	stones.append(stone)
	var lean := Basis.from_euler(Vector3(rng.randf_range(-0.05, 0.03), rng.randf_range(-0.08, 0.08), rng.randf_range(-0.05, 0.05)))
	# Fragments: the face parted round a few seeds, the borders wavering.
	var pieces: int = clampi(int(cells.size() / FRAGMENT_AREA) + FRAGMENTS_MIN, FRAGMENTS_MIN, FRAGMENTS_MAX)
	var seeds: Array[Vector2] = []
	for i: int in pieces:
		var pick: Vector2i = cells[rng.randi() % cells.size()]
		seeds.append(Vector2(pick))
	var first_fragment: int = fragments.size()
	var shifts: Array[Vector3] = []
	var turns: Array[Basis] = []
	var rocks: Array[Color] = []
	for i: int in pieces:
		shifts.append(Vector3(rng.randf_range(-0.15, 0.15), rng.randf_range(-0.12, 0.12), rng.randf_range(-0.6, 0.6)))
		turns.append(Basis.from_euler(Vector3(rng.randf_range(-0.02, 0.02), rng.randf_range(-0.02, 0.02), rng.randf_range(-0.012, 0.012))))
		rocks.append(Color(ROCKS[rng.randi() % ROCKS.size()]))
		fragments.append(Fragment.new())
	var centres: Array[Vector3] = []
	var counts: Array[int] = []
	centres.resize(pieces)
	counts.resize(pieces)
	for i: int in pieces:
		centres[i] = Vector3.ZERO
		counts[i] = 0
	var cracked: Array[bool] = []
	for i: int in pieces:
		cracked.append(rng.randf() < 0.4)
	# Which fragment every voxel belongs to (-1: the crack between two, or a chip off a corner),
	# and whether light leaks beside it.
	var owner := PackedInt32Array()
	owner.resize(w * h)
	owner.fill(-1)
	var seam := PackedByteArray()
	seam.resize(w * h)
	for cell: Vector2i in cells:
		var near: int = 0
		var best: float = INF
		var second: float = INF
		var wobble := Vector2(sin(cell.y * 0.7 + index * 3.0) * 1.6, cos(cell.x * 0.6 + index) * 1.6)
		for i: int in pieces:
			var d: float = (Vector2(cell) + wobble).distance_to(seeds[i])
			if d < best:
				second = best
				best = d
				near = i
			elif d < second:
				second = d
		if second - best < 0.7:
			continue
		if _open_sides(grid, w, h, cell) >= 2 and rng.randf() < 0.08:
			continue
		owner[cell.y * w + cell.x] = near
		seam[cell.y * w + cell.x] = 1 if second - best < 2.2 else 0
	# The fragments laid in blocks of many sizes, each block within one fragment.
	var taken := PackedByteArray()
	taken.resize(w * h)
	var order: Array[Vector2i] = cells.duplicate()
	for i: int in range(order.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var swap: Vector2i = order[i]
		order[i] = order[j]
		order[j] = swap
	for cell: Vector2i in order:
		var near: int = owner[cell.y * w + cell.x]
		if near < 0 or taken[cell.y * w + cell.x] == 1:
			continue
		var side: int = BLOCK_SIZES[rng.rand_weighted(BLOCK_WEIGHTS)]
		var anchor := cell
		while side > 1:
			anchor = _fit(owner, taken, w, h, cell, side, near, rng)
			if anchor.x >= 0:
				break
			side -= 1
		if side == 1:
			anchor = cell
		var rim: bool = false
		var leaks: bool = false
		var top: bool = false
		for y: int in range(anchor.y, anchor.y + side):
			for x: int in range(anchor.x, anchor.x + side):
				taken[y * w + x] = 1
				rim = rim or _rim(grid, w, h, Vector2i(x, y))
				leaks = leaks or seam[y * w + x] == 1
				top = top or y == 0 or grid[y - 1][x] == 0
		var block := Block.new()
		block.stone = stone_index
		block.fragment = first_fragment + near
		block.colour = rocks[near].lerp(Color.BLACK, rng.randf() * 0.14).lerp(Color.WHITE, rng.randf() * 0.07)
		if leaks:
			block.marks |= SEAM
		if rim:
			block.marks |= RIM
		if cracked[near]:
			block.marks |= CRACKED
		if top and rng.randf() < 0.55:
			block.marks |= MOSSY
		var front: float = DEPTH / 2.0 + rng.randf_range(-0.15, 0.15) + (side - 1) * rng.randf_range(-0.1, 0.18) - (rng.randf_range(0.1, 0.4) if rim else 0.0)
		var back: float = -DEPTH / 2.0 + (rng.randf_range(0.0, 1.0) if rim else 0.0)
		if not rim and side <= 2 and rng.randf() < CRYSTAL_SHARE * 2.0:
			block.material = CRYSTAL
			block.colour = Color(CRYSTALS[rng.randi() % CRYSTALS.size()])
			front += 0.5
		var local := Vector3(anchor.x + side / 2.0, float(low_row - anchor.y) + 1.0 - side / 2.0 - sink, (front + back) / 2.0)
		var from_pivot: Vector3 = local - stone.pivot
		var piece_turn: Basis = turns[near]
		block.centre = stone.pivot + lean * (piece_turn * from_pivot + shifts[near])
		block.basis = lean * piece_turn
		block.size = Vector3(side - BLOCK_GAP, side - BLOCK_GAP, front - back)
		blocks.append(block)
		centres[near] += block.centre
		counts[near] += 1
	for i: int in pieces:
		var fragment: Fragment = fragments[first_fragment + i]
		fragment.centre = centres[i] / maxf(1.0, counts[i])
		var xn: float = clampf(fragment.centre.x / maxf(1.0, w + SEAL_SIDE), 0.0, 1.0)
		fragment.leave = 0.05 + 0.5 * xn + rng.randf() * 0.12


## Where a `side` block holding `cell` fits: every voxel of it free and of fragment `piece`.
## (-1, -1) if nowhere.
static func _fit(owner: PackedInt32Array, taken: PackedByteArray, w: int, h: int, cell: Vector2i, side: int, piece: int, rng: RandomNumberGenerator) -> Vector2i:
	var start: int = rng.randi_range(0, side * side - 1)
	for k: int in side * side:
		var o: int = (start + k) % (side * side)
		var anchor := Vector2i(cell.x - o % side, cell.y - o / side)
		if anchor.x < 0 or anchor.y < 0 or anchor.x + side > w or anchor.y + side > h:
			continue
		var fits: bool = true
		for y: int in range(anchor.y, anchor.y + side):
			for x: int in range(anchor.x, anchor.x + side):
				if taken[y * w + x] == 1 or owner[y * w + x] != piece:
					fits = false
					break
			if not fits:
				break
		if fits:
			return anchor
	return Vector2i(-1, -1)


## A voxel on the outline (a side open to the air).
static func _rim(grid: Array[PackedByteArray], w: int, h: int, cell: Vector2i) -> bool:
	return _open_sides(grid, w, h, cell) > 0


static func _open_sides(grid: Array[PackedByteArray], w: int, h: int, cell: Vector2i) -> int:
	var open: int = 0
	for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var next: Vector2i = cell + step
		if next.x < 0 or next.y < 0 or next.x >= w or next.y >= h or grid[next.y][next.x] == 0:
			open += 1
	return open


## The seal after the last character: a vermilion lacquered block with 侠 inlaid in its face, or a
## cut knot where the language has no seal; it falls last, a stamp, and stands a little askew.
func _seal(glyph: Array[PackedByteArray], x0: float, h: int, index: int, count: int, rng: RandomNumberGenerator) -> void:
	var stone := Stone.new()
	stone.pivot = Vector3(x0 + SEAL_SIDE / 2.0, 0.0, 0.0)
	stone.half_width = SEAL_SIDE / 2.0
	stone.land = 0.08 + 0.72 * index / maxf(1.0, count - 1.0) + 0.06
	var stone_index: int = stones.size()
	stones.append(stone)
	var fragment := Fragment.new()
	fragment.centre = stone.pivot + Vector3(0.0, SEAL_SIDE / 2.0, 0.0)
	fragment.leave = 0.6
	var fragment_index: int = fragments.size()
	fragments.append(fragment)
	var lean := Basis.from_euler(Vector3(-0.04, rng.randf_range(-0.12, 0.12), rng.randf_range(-0.1, 0.1)))
	var sink: float = 1.2
	var body := Block.new()
	body.stone = stone_index
	body.fragment = fragment_index
	body.material = LACQUER
	body.colour = Color("a8301c")
	body.marks = CRACKED
	body.size = Vector3(SEAL_SIDE, SEAL_SIDE, 5.0)
	body.basis = lean
	body.centre = stone.pivot + lean * Vector3(0.0, SEAL_SIDE / 2.0 - sink, 0.0)
	blocks.append(body)
	var sh: int = glyph.size()
	var sw: int = 0 if sh == 0 else glyph[0].size()
	var side: int = maxi(maxi(sw, sh) + 6, 26)
	var pixel: float = (SEAL_SIDE - 1.6) / side
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
			inlay.stone = stone_index
			inlay.fragment = fragment_index
			inlay.material = INLAY
			inlay.colour = Color("efe0c4").lerp(Color("d8c090"), rng.randf() * 0.3)
			inlay.size = Vector3(pixel * 1.15, pixel * 1.15, 0.3)
			inlay.basis = lean
			var at := Vector3(-(SEAL_SIDE - 1.6) / 2.0 + (gx + 0.5) * pixel, SEAL_SIDE - 0.8 - (y + 0.5) * pixel - sink, 2.6)
			inlay.centre = stone.pivot + lean * at
			blocks.append(inlay)


## Rubble thrown out round each stone's foot when it lands: chunks of its own rock.
func _rubble(rng: RandomNumberGenerator) -> void:
	for index: int in stones.size():
		var stone: Stone = stones[index]
		var colour := Color(ROCKS[rng.randi() % ROCKS.size()])
		for i: int in 14:
			var side: float = rng.randf_range(0.8, 3.0)
			var size := Vector3(side, side * rng.randf_range(0.5, 0.9), side * rng.randf_range(0.7, 1.1))
			var x: float = stone.pivot.x + rng.randf_range(-stone.half_width - 6.0, stone.half_width + 6.0)
			var z: float = (1.0 if rng.randf() < 0.65 else -1.0) * rng.randf_range(DEPTH / 2.0 + 1.5, DEPTH / 2.0 + 14.0)
			var basis := Basis.from_euler(Vector3(rng.randf_range(-0.4, 0.4), rng.randf() * TAU, rng.randf_range(-0.4, 0.4)))
			rubble.append([Vector3(x, size.y * 0.3, z), size, basis, colour.lerp(Color.BLACK, rng.randf() * 0.2), index])
