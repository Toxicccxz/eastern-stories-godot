extends RefCounted

## What lives and lies on a water's bed, seen through its surface (VoxelWater): pebbles, weed
## that sways, fish that swim their own rounds, lotus on a still pond, and now and then a thing
## the water keeps (a rusted sword stood in the mud, a sealed jar, a broken stele, coins, snails,
## a resting turtle, an anchor stone). Layout `water` per kind or area: "life": {"pebbles" (a
## cell's chance), "weed" (a cell's chance of a clump), "weed_colors", "lotus" (a bank cell's
## chance of a pad), "fish": {"kind": koi | red_koi | carp | minnow | silver, "per" (cells a fish),
## "max"}, "finds": {"kinds", "every" (cells a find), "max"}}, over the kind's defaults.
## Presentation only: its own random stream, nothing saved, nothing in the way of a walker.
const Shapes = preload("res://presentation/voxel/props/voxel_shapes.gd")
const DEFAULTS: Dictionary = {
	"water": {"pebbles": 0.3, "weed": 0.05, "lotus": 0.0, "fish": {"kind": "carp", "per": 50, "max": 16},
		"finds": {"kinds": ["jar", "coins", "stele", "sword", "turtle", "snails"], "every": 260, "max": 5}},
	"deep_water": {"pebbles": 0.12, "weed": 0.025, "lotus": 0.0, "fish": {"kind": "silver", "per": 100, "max": 16},
		"finds": {"kinds": ["anchor", "jar", "stele", "shells"], "every": 500, "max": 4}},
	"shallow_water": {"pebbles": 0.5, "weed": 0.02, "lotus": 0.0, "fish": {"kind": "minnow", "per": 40, "max": 10},
		"finds": {"kinds": ["coins", "snails", "turtle"], "every": 200, "max": 3}},
}
const WEED: Array = ["4f7a3c", "5e8a44", "3e6a3a", "6e8e48"]
const LOTUS: Array = ["4e7a3a", "5e8a44", "6a9a4a"]
## Fish by kind: body, back (the koi's patch), fin, and length in units.
const FISH: Dictionary = {
	"koi": [["e8642a", "f2efe6", "f2efe6", 0.42], ["f2efe6", "d8402a", "f2efe6", 0.4], ["e8a32a", "f2efe6", "e8a32a", 0.38], ["2e2a26", "e8642a", "2e2a26", 0.4]],
	"red_koi": [["d8402a", "e8642a", "e87a4a", 0.42], ["e04a2e", "f2efe6", "e8642a", 0.4], ["c8362a", "d8502e", "e06a44", 0.38]],
	"carp": [["c8743a", "a85a2e", "d88a4a", 0.5], ["b8903e", "8e6e34", "c8a050", 0.46], ["8e8c72", "6e6c56", "a8a488", 0.4]],
	"minnow": [["4e5e54", "3e4c44", "5e6e62", 0.18]],
	"silver": [["9aa8ae", "6e7e88", "b4c0c4", 0.26]],
}
## Shoaling kinds swim together, a few on one round.
const SHOALS: Dictionary = {"minnow": 5, "silver": 4}
## No life past this far into open water: the far sea is only colour.
const NEAR_BANK: float = 256.0

var water: VoxelWater
var shapes: Shapes
var ambience: VoxelAmbience
var depth: Dictionary[Vector2i, float]
var cliffs: VoxelCliffs
var rng := RandomNumberGenerator.new()
## The shape drawer's frame as it was given: each thing is placed in front of it, and it is put back.
var _base := Transform3D.IDENTITY

func _init(p_water: VoxelWater, p_shapes: Shapes, p_ambience: VoxelAmbience, p_depth: Dictionary[Vector2i, float], p_cliffs: VoxelCliffs) -> void:
	water = p_water
	shapes = p_shapes
	ambience = p_ambience
	depth = p_depth
	cliffs = p_cliffs

## The life of a look: its own `life` over its kind's defaults (fish and finds merged too).
static func life_of(look: Dictionary) -> Dictionary:
	var life: Dictionary = (DEFAULTS.get(String(look.get("kind", "water")), DEFAULTS["water"]) as Dictionary).duplicate(true)
	var own: Dictionary = look.get("life", {})
	for key: String in own:
		if own[key] is Dictionary and life.get(key) is Dictionary:
			(life[key] as Dictionary).merge(own[key], true)
		else:
			life[key] = own[key]
	return life

func build(seed_value: int, breathe: Callable = Callable()) -> void:
	rng.seed = hash(seed_value) ^ 0x51a7e5
	_base = shapes.frame
	# The water's cells by look (a pond's koi stay in the pond), in a fixed order.
	var groups: Dictionary[String, Array] = {}
	var order: Array = water.levels.keys()
	order.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or a.y == b.y and a.x < b.x)
	var done: int = 0
	for cell: Vector2i in order:
		if depth.get(cell, 0.0) > NEAR_BANK or _pit(cell):
			continue
		var look: Dictionary = water.looks[cell]
		var key: String = "%s:%s" % [look["kind"], look.get("area", -1)]
		if not groups.has(key):
			groups[key] = []
		groups[key].append(cell)
		var life: Dictionary = life_of(look)
		var room: float = water.levels[cell]-water.beds[cell]
		var at := Vector3(cell.x/32.0, water.beds[cell], cell.y/32.0)
		if rng.randf() < float(life.get("pebbles", 0.3)):
			var bed: Array = look.get("bed", VoxelWater.DEFAULT_BED)
			for i: int in rng.randi_range(1, 3):
				var size: float = rng.randf_range(0.06, 0.16)
				shapes.shard(water.root, at+Vector3(rng.randf_range(-0.2, 0.2), size*0.2, rng.randf_range(-0.2, 0.2)), Vector3(size*1.3, size*0.55, size),
					Color(String(bed[rng.randi_range(0, bed.size()-1)])).lightened(rng.randf_range(-0.1, 0.18)).to_html(false), rng.randi(), rng.randf()*TAU)
		if room > 0.3 and rng.randf() < float(life.get("weed", 0.05)):
			_weed(at, room, life.get("weed_colors", WEED))
		if depth.get(cell, 0.0) <= 32.0 and rng.randf() < float(life.get("lotus", 0.0)):
			_lotus(Vector3(at.x, water.levels[cell], at.z))
		done += 1
		if breathe.is_valid() and done % 512 == 0:
			await breathe.call()
	var keys: Array = groups.keys()
	keys.sort()
	for key: String in keys:
		var cells: Array = groups[key]
		var life: Dictionary = life_of(water.looks[cells[0]])
		_school(cells, life.get("fish", {}))
		_finds(cells, life.get("finds", {}))

func _pit(cell: Vector2i) -> bool:
	return cliffs != null and cliffs.heights.get(cell, 0.0) < 0.0

## A clump of weed standing up from the bed toward the light, swaying about its root.
func _weed(at: Vector3, room: float, colors: Array) -> void:
	var clump := Node3D.new()
	clump.position = at+Vector3(rng.randf_range(-0.15, 0.15), 0, rng.randf_range(-0.15, 0.15))
	water.root.add_child(clump)
	for blade: int in rng.randi_range(3, 6):
		var tall: float = rng.randf_range(0.4, 0.85)*(room-0.08)
		var lean := Vector3(rng.randf_range(-0.25, 0.25), 0, rng.randf_range(-0.25, 0.25))
		var foot := Vector3(rng.randf_range(-0.1, 0.1), 0, rng.randf_range(-0.1, 0.1))
		var color: String = String(colors[rng.randi_range(0, colors.size()-1)])
		# A blade in two lengths, the upper one bent further: a ribbon, not a stick.
		shapes.tilted_box(clump, foot+Vector3(lean.z*tall*0.25, tall*0.25, -lean.x*tall*0.25), Vector3(0.05, tall*0.5, 0.025), color, lean)
		var bend: Vector3 = lean*2.0
		var mid: Vector3 = foot+Vector3(lean.z*tall*0.5, tall*0.5, -lean.x*tall*0.5)
		shapes.tilted_box(clump, mid+Vector3(bend.z*tall*0.25, tall*0.22, -bend.x*tall*0.25), Vector3(0.045, tall*0.48, 0.02), Color(color).lightened(0.12).to_html(false), bend)
	if ambience != null:
		ambience.sway(clump, rng.randf()*TAU, 0.12)

## Lotus pads on the still water by the bank, now and then a flower or a bud standing on its stem.
func _lotus(at: Vector3) -> void:
	for pad: int in rng.randi_range(1, 3):
		var spot: Vector3 = at+Vector3(rng.randf_range(-0.2, 0.2), 0.012+pad*0.002, rng.randf_range(-0.2, 0.2))
		var size: float = rng.randf_range(0.24, 0.38)
		var color: String = String(LOTUS[rng.randi_range(0, LOTUS.size()-1)])
		var turn: float = rng.randf()*TAU
		shapes.frame = _base*Transform3D(Basis(Vector3.UP, turn), spot)
		shapes.box(water.root, Vector3.ZERO, Vector3(size, 0.02, size*0.66), color)
		shapes.box(water.root, Vector3(0, 0, -size*0.05), Vector3(size*0.66, 0.02, size*0.86), color)
		# The notch to the middle, where the stem holds it.
		shapes.box(water.root, Vector3(0, 0.004, size*0.3), Vector3(0.04, 0.02, size*0.3), Color(color).darkened(0.25).to_html(false))
		var roll: float = rng.randf()
		if roll < 0.22:
			# A flower open on the water.
			for petal: int in 5:
				var a: float = petal*TAU/5.0
				shapes.tilted_box(water.root, Vector3(cos(a)*0.06, 0.07, sin(a)*0.06), Vector3(0.06, 0.1, 0.03), "e894b0", Vector3(sin(a)*0.5, -a, -cos(a)*0.5))
			shapes.box(water.root, Vector3(0, 0.06, 0), Vector3(0.05, 0.03, 0.05), "e8c84a")
		elif roll < 0.34:
			# A bud on a stem above the pad.
			shapes.box(water.root, Vector3(0.08, 0.12, 0.02), Vector3(0.02, 0.24, 0.02), "5e7a3a")
			shapes.box(water.root, Vector3(0.08, 0.27, 0.02), Vector3(0.06, 0.09, 0.06), "e48aa6")
		shapes.frame = _base

## The look's fish, each on a round of its own that keeps within the water.
func _school(cells: Array, fish: Dictionary) -> void:
	var kind: String = String(fish.get("kind", "carp"))
	if not FISH.has(kind):
		return
	var count: int = mini(int(fish.get("max", 8)), int(cells.size()/float(maxi(1, int(fish.get("per", 80))))))
	var shoal: int = int(SHOALS.get(kind, 1))
	var rounds: int = ceili(count/float(shoal))
	# Their rounds keep near the bank, where the water is clear enough to see them.
	var near: Array = cells.filter(func(cell: Vector2i) -> bool: return depth.get(cell, 0.0) >= 32.0 and depth.get(cell, 0.0) <= 128.0)
	if near.is_empty():
		near = cells
	for lap: int in rounds:
		for attempt: int in 16:
			var centre: Vector2i = near[rng.randi_range(0, near.size()-1)]
			var room: float = depth.get(centre, 0.0)
			if room < 32.0:
				continue
			var rx: float = rng.randf_range(0.5, minf(2.4, (room-8.0)/32.0+0.5))
			var rz: float = rx*rng.randf_range(0.45, 1.0)
			if not _round_in_water(centre, rx, rz):
				continue
			var swim: float = water.levels[centre]-clampf((water.levels[centre]-water.beds[centre])*0.45, 0.12, 0.5)
			var looks: Array = FISH[kind]
			var look: Array = looks[rng.randi_range(0, looks.size()-1)]
			var rate: float = rng.randf_range(0.18, 0.36)/maxf(rx, 0.6)
			var way: float = 1.0 if rng.randf() < 0.5 else -1.0
			var phase: float = rng.randf()*TAU
			for member: int in mini(shoal, count-lap*shoal):
				var body: Array = look if shoal == 1 else looks[rng.randi_range(0, looks.size()-1)]
				var node: Array = _fish(body, kind)
				if ambience != null:
					var spread: float = 0.0 if member == 0 else rng.randf_range(-0.12, 0.12)
					ambience.swim(node[0], node[1], Vector3(centre.x/32.0, swim+rng.randf_range(-0.04, 0.04), centre.y/32.0),
						Vector2(rx+spread, rz+spread), rate*way, phase-member*0.22*way)
				else:
					(node[0] as Node3D).position = Vector3(centre.x/32.0+rx, swim, centre.y/32.0)
			break

## Whether a fish's round about `centre` (rx, rz units) stays over the water's cells, clear of its banks.
func _round_in_water(centre: Vector2i, rx: float, rz: float) -> bool:
	for step: int in 16:
		var a: float = step*TAU/16.0
		var px := Vector2(centre)+Vector2(cos(a)*rx, sin(a)*rz)*32.0
		var cell := Vector2i(floori(px.x/16.0)*16+8, floori(px.y/16.0)*16+8)
		if not water.levels.has(cell) or depth.get(cell, 0.0) < 12.0 or water.looks[cell] != water.looks[centre]:
			return false
	return true

## One fish: [the node that swims, its tail that beats], facing +z.
func _fish(body: Array, kind: String) -> Array:
	var fish := Node3D.new()
	water.root.add_child(fish)
	var length: float = float(body[3])
	fish.scale = Vector3.ONE*length
	shapes.box(fish, Vector3(0, 0, 0.04), Vector3(0.3, 0.3, 0.66), String(body[0]))
	shapes.box(fish, Vector3(0, -0.02, 0.42), Vector3(0.24, 0.24, 0.16), String(body[0]))
	shapes.box(fish, Vector3(0, 0.16, 0.08), Vector3(0.22, 0.04, 0.42), String(body[1]))
	shapes.box(fish, Vector3(0, 0.22, -0.02), Vector3(0.03, 0.12, 0.3), String(body[2]))
	if kind == "koi" or kind == "carp":
		# Barbels at the mouth, and the side fins.
		shapes.box(fish, Vector3(0, -0.08, 0.52), Vector3(0.16, 0.02, 0.06), String(body[2]))
		for side: float in [-1.0, 1.0]:
			shapes.tilted_box(fish, Vector3(side*0.18, -0.1, 0.2), Vector3(0.14, 0.02, 0.1), String(body[2]), Vector3(0, 0, side*0.5))
	var tail := Node3D.new()
	tail.position = Vector3(0, 0, -0.29)
	fish.add_child(tail)
	shapes.box(tail, Vector3(0, 0, -0.04), Vector3(0.16, 0.18, 0.1), String(body[0]))
	shapes.box(tail, Vector3(0, 0, -0.17), Vector3(0.03, 0.38, 0.18), String(body[2]))
	return [fish, tail]

## A few things the water keeps, apart from each other, where they can be made out.
func _finds(cells: Array, finds: Dictionary) -> void:
	var kinds: Array = finds.get("kinds", [])
	if kinds.is_empty():
		return
	var every: float = maxf(1.0, float(finds.get("every", 300)))
	var count: int = mini(int(finds.get("max", 4)), roundi(cells.size()/every))
	var placed: Array[Vector2i] = []
	var order: Array = kinds.duplicate()
	for i: int in order.size():
		var j: int = rng.randi_range(i, order.size()-1)
		var swap: Variant = order[i]
		order[i] = order[j]
		order[j] = swap
	for n: int in count:
		var kind: String = String(order[n % order.size()])
		for attempt: int in 24:
			var cell: Vector2i = cells[rng.randi_range(0, cells.size()-1)]
			var room: float = water.levels[cell]-water.beds[cell]
			if depth.get(cell, 0.0) < 16.0 or room < (0.7 if kind == "sword" else 0.25) or room > 1.3:
				continue
			var apart: bool = true
			for other: Vector2i in placed:
				apart = apart and other.distance_to(cell) >= 160.0
			if not apart:
				continue
			placed.append(cell)
			shapes.frame = _base*Transform3D(Basis(Vector3.UP, rng.randf()*TAU), Vector3(cell.x/32.0, water.beds[cell], cell.y/32.0))
			call("_find_"+kind, room)
			shapes.frame = _base
			break

## 沉剑: an old sword stood slantwise in the mud, rusted, its red tassel still there.
func _find_sword(room: float) -> void:
	var tilt := Basis(Vector3.FORWARD, 0.42)*Basis(Vector3.RIGHT, 0.12)
	var held: Transform3D = shapes.frame
	shapes.frame = held*Transform3D(tilt, Vector3.ZERO)
	var blade: float = minf(0.75, room-0.28)
	shapes.box(water.root, Vector3(0, blade/2.0-0.1, 0), Vector3(0.06, blade+0.2, 0.016), "8a7c66")
	shapes.box(water.root, Vector3(0.012, blade/2.0-0.1, 0.01), Vector3(0.012, blade+0.2, 0.004), "6e5a44")
	shapes.box(water.root, Vector3(0, blade, 0), Vector3(0.2, 0.04, 0.06), "6a5a38")
	shapes.box(water.root, Vector3(0, blade+0.1, 0), Vector3(0.04, 0.16, 0.04), "3a2a22")
	shapes.box(water.root, Vector3(0, blade+0.2, 0), Vector3(0.06, 0.05, 0.06), "6a5a38")
	shapes.tilted_box(water.root, Vector3(0.05, blade+0.12, 0), Vector3(0.03, 0.16, 0.03), "a8342a", Vector3(0, 0, -0.6))
	shapes.frame = held
	# Silt heaped where it went in.
	shapes.box(water.root, Vector3(0, 0.02, 0), Vector3(0.22, 0.04, 0.2), "6b6450")

## 沉坛: a wine jar on its side, half in the mud, its mouth still sealed with red cloth.
func _find_jar(_room: float) -> void:
	shapes.box(water.root, Vector3(0, 0.1, 0), Vector3(0.34, 0.28, 0.42), "5a3e28")
	shapes.box(water.root, Vector3(0, 0.1, 0), Vector3(0.38, 0.22, 0.32), "5a3e28")
	shapes.box(water.root, Vector3(0, 0.1, 0.26), Vector3(0.18, 0.16, 0.1), "4e3422")
	shapes.box(water.root, Vector3(0, 0.1, 0.33), Vector3(0.22, 0.2, 0.05), "9a2e24")
	shapes.box(water.root, Vector3(0, 0.1, 0.3), Vector3(0.24, 0.03, 0.02), "c8b48a")
	shapes.box(water.root, Vector3(0.04, 0.24, -0.06), Vector3(0.2, 0.03, 0.18), "4e6a3a")
	# A sherd of another, broken beside it.
	shapes.tilted_box(water.root, Vector3(0.34, 0.03, -0.18), Vector3(0.16, 0.03, 0.12), "6a4a30", Vector3(0.3, 0.6, 0))

## 残碑: a broken stele lying in the water, its carving worn, moss on it.
func _find_stele(_room: float) -> void:
	shapes.box(water.root, Vector3(0, 0.04, 0), Vector3(0.66, 0.1, 0.38), "8a877a")
	for line: int in 3:
		shapes.box(water.root, Vector3(-0.08, 0.095, -0.1+line*0.1), Vector3(0.38, 0.012, 0.03), "5e5c52")
	shapes.box(water.root, Vector3(0.22, 0.1, 0.1), Vector3(0.18, 0.02, 0.14), "557a45")
	shapes.tilted_box(water.root, Vector3(0.46, 0.08, 0.04), Vector3(0.28, 0.09, 0.34), "7e7b6e", Vector3(0, 0, 0.42))

## 铜钱: coins thrown in for luck, gone green, scattered on the bed.
func _find_coins(_room: float) -> void:
	for coin: int in rng.randi_range(8, 13):
		var a: float = rng.randf()*TAU
		var r: float = sqrt(rng.randf())*0.36
		var at := Vector3(cos(a)*r, 0.008+coin*0.0004, sin(a)*r)
		var tone: String = ["a8923e", "8e9a5a", "b49c4a", "7e8e5a"][rng.randi_range(0, 3)]
		shapes.tilted_box(water.root, at, Vector3(0.075, 0.012, 0.075), tone, Vector3(0, rng.randf()*TAU, 0))
		shapes.box(water.root, at+Vector3(0, 0.004, 0), Vector3(0.022, 0.012, 0.022), "3a3a2a")

## 螺: snail shells on the bed, jade-green (玉螺湖's own).
func _find_snails(_room: float) -> void:
	for shell: int in rng.randi_range(5, 9):
		var a: float = rng.randf()*TAU
		var r: float = sqrt(rng.randf())*0.4
		var at := Vector3(cos(a)*r, 0.03, sin(a)*r)
		var tone: String = ["7ab49a", "8ec4a6", "5e9a80", "a8c8a0"][rng.randi_range(0, 3)]
		var turn := Vector3(0, rng.randf()*TAU, 0)
		shapes.tilted_box(water.root, at, Vector3(0.07, 0.06, 0.09), tone, turn)
		shapes.tilted_box(water.root, at+Vector3(0, 0.045, 0), Vector3(0.045, 0.04, 0.05), Color(tone).lightened(0.15).to_html(false), turn)
		shapes.tilted_box(water.root, at+Vector3(0, 0.075, 0), Vector3(0.02, 0.03, 0.02), Color(tone).lightened(0.3).to_html(false), turn)

## 龟: a turtle resting on the bed, its head out.
func _find_turtle(_room: float) -> void:
	shapes.box(water.root, Vector3(0, 0.05, 0), Vector3(0.36, 0.08, 0.42), "5a5a3a")
	shapes.box(water.root, Vector3(0, 0.12, 0), Vector3(0.28, 0.08, 0.32), "4a5232")
	shapes.box(water.root, Vector3(0, 0.17, 0), Vector3(0.14, 0.03, 0.16), "3e4428")
	shapes.box(water.root, Vector3(0, 0.06, 0.27), Vector3(0.09, 0.07, 0.12), "7a7a52")
	shapes.box(water.root, Vector3(0.025, 0.09, 0.31), Vector3(0.015, 0.015, 0.015), "1e1e16")
	shapes.box(water.root, Vector3(-0.025, 0.09, 0.31), Vector3(0.015, 0.015, 0.015), "1e1e16")
	for x: float in [-1.0, 1.0]:
		for z: float in [-1.0, 1.0]:
			shapes.tilted_box(water.root, Vector3(x*0.2, 0.03, z*0.14), Vector3(0.12, 0.03, 0.08), "6e6e48", Vector3(0, x*z*0.5, 0))
	shapes.box(water.root, Vector3(0, 0.03, -0.24), Vector3(0.04, 0.03, 0.08), "6e6e48")

## 碇石: a stone anchor gone down with its rope.
func _find_anchor(_room: float) -> void:
	shapes.box(water.root, Vector3(0, 0.07, 0), Vector3(0.18, 0.16, 0.72), "6e6a60")
	shapes.box(water.root, Vector3(0, 0.155, 0), Vector3(0.2, 0.03, 0.08), "5a564c")
	shapes.box(water.root, Vector3(0, 0.12, 0.38), Vector3(0.12, 0.08, 0.06), "5a564c")
	shapes.tilted_box(water.root, Vector3(0, 0.3, 0.06), Vector3(0.03, 0.36, 0.03), "8a7650", Vector3(0.5, 0, 0.2))
	shapes.box(water.root, Vector3(0.1, 0.17, -0.2), Vector3(0.16, 0.02, 0.12), "4e6a3a")

## 贝: shells and a starfish on the sea's floor.
func _find_shells(_room: float) -> void:
	for shell: int in rng.randi_range(4, 7):
		var a: float = rng.randf()*TAU
		var r: float = sqrt(rng.randf())*0.4
		shapes.tilted_box(water.root, Vector3(cos(a)*r, 0.02, sin(a)*r), Vector3(0.1, 0.03, 0.08), ["d8cfc0", "c4b8a4", "e0c8b8"][rng.randi_range(0, 2)], Vector3(0, rng.randf()*TAU, 0.2))
	for arm: int in 5:
		var a: float = arm*TAU/5.0
		shapes.tilted_box(water.root, Vector3(cos(a)*0.08, 0.015, sin(a)*0.08), Vector3(0.14, 0.025, 0.05), "d8763a", Vector3(0, -a, 0))
	shapes.box(water.root, Vector3(0, 0.02, 0), Vector3(0.07, 0.03, 0.07), "c8662e")
