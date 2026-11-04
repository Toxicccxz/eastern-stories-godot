extends RefCounted

## Things worn, as the 背包 shows them (owner, 2026-11-04): robes and shirts as if hung on an
## unseen frame facing front, armour, helmets and crowns, capes, shoes in pairs, shields
## and small jewellery. Drawn about the origin; the item view frames and turns them.
## Colours, styles and patterns come from the item's look (game/data/common/item_looks.json).
const Shapes = preload("res://presentation/voxel/props/voxel_shapes.gd")
var s: Shapes
var root: Node3D


func draw(shapes: Shapes, parent: Node3D, data: Dictionary) -> bool:
	s = shapes
	root = parent
	match String(data["kind"]):
		"garment":
			_garment(data)
		"armor_suit":
			_armor_suit(data)
		"helmet":
			_helmet(data)
		"headwear":
			_headwear(data)
		"cape":
			_cape(data)
		"shoes":
			_shoes(data)
		"shield":
			_shield(data)
		"necklace":
			_necklace(data)
		"ring":
			_ring(data)
		"bracelet":
			_bracelet(data)
		"belt":
			_belt(data)
		"skirt":
			_skirt(data)
		"eyepatch":
			_eyepatch(data)
		"earrings":
			_earrings(data)
		_:
			return false
	return true


func _c(data: Dictionary, key: String, fallback: String) -> String:
	return String(data.get(key, fallback))


func _b(at: Vector3, size: Vector3, hex: String) -> void:
	s.box(root, at, size, hex)


func _t(at: Vector3, size: Vector3, hex: String, angles: Vector3) -> void:
	s.tilted_box(root, at, size, hex, angles)


## 衣, 衫, 袍, 裙衫, 袈裟, 马褂: a body and sleeves in a T, the crossed collar, a sash; `style`
## sets its length and cut, `pattern` what is worked on it.
func _garment(data: Dictionary) -> void:
	var cloth: String = _c(data, "cloth", "8a7f6a")
	var trim: String = _c(data, "trim", Color(cloth.get_slice(":", 0)).darkened(0.3).to_html(false))
	var style: String = String(data.get("style", "shirt"))
	var long: float = {"robe": 0.86, "dress": 0.9, "kasaya": 0.86, "shirt": 0.62, "jacket": 0.5, "night": 0.66}.get(style, 0.62)
	var top: float = 0.36
	var bottom: float = top - long
	var body_w: float = 0.42
	# The body, widening a little to the hem; a dress flares out.
	var steps: int = 4
	for i: int in steps:
		var u: float = float(i) / (steps - 1)
		var w: float = body_w + u * (0.24 if style == "dress" else (0.1 if style in ["robe", "kasaya"] else 0.04))
		_b(Vector3(0, top - (i + 0.5) * long / steps, 0), Vector3(w, long / steps + 0.004, 0.14), cloth)
	# Shoulders and sleeves: wide hanging sleeves on a robe, close ones on a jacket.
	var sleeve: float = 0.34 if style in ["robe", "kasaya", "dress"] else 0.26
	var cuff: float = 0.2 if style in ["robe", "kasaya", "dress"] else 0.12
	for side: float in [-1.0, 1.0]:
		_t(Vector3(side * (body_w / 2 + sleeve / 2 - 0.02), top - 0.12, 0), Vector3(sleeve, 0.17, 0.13), cloth, Vector3(0, 0, side * -0.32))
		var end := Vector3(side * (body_w / 2 + sleeve - 0.05), top - 0.24, 0)
		_b(end + Vector3(0, -cuff / 2 + 0.06, 0), Vector3(0.14, cuff, 0.13), cloth)
		_b(end + Vector3(0, -cuff + 0.05, 0), Vector3(0.15, 0.04, 0.14), trim)
	# The crossed collar, right over left, and the hem.
	for i: int in 5:
		_b(Vector3(-0.1 + i * 0.045, top - 0.03 - i * 0.05, 0.072), Vector3(0.06, 0.06, 0.01), trim)
	_b(Vector3(0.09, top - 0.02, 0.072), Vector3(0.06, 0.05, 0.01), trim)
	var hem_w: float = body_w + (0.24 if style == "dress" else (0.1 if style in ["robe", "kasaya"] else 0.04))
	_b(Vector3(0, bottom + 0.02, 0), Vector3(hem_w + 0.01, 0.04, 0.15), trim)
	if style == "jacket":
		for i: int in 4:
			_b(Vector3(0.0, top - 0.12 - i * 0.09, 0.075), Vector3(0.04, 0.025, 0.012), _c(data, "buttons", "d8bf7a"))
	if data.has("sash"):
		_b(Vector3(0, top - 0.3, 0.004), Vector3(body_w + 0.06, 0.06, 0.155), String(data["sash"]))
		_b(Vector3(0.12, top - 0.38, 0.078), Vector3(0.05, 0.14, 0.012), String(data["sash"]))
	if style == "kasaya":
		var patch: String = _c(data, "accent", trim)
		for i: int in 4:
			_b(Vector3(0, top - 0.2 - i * 0.16, 0.072), Vector3(body_w + 0.04, 0.012, 0.008), patch)
		for x: float in [-0.12, 0.12]:
			_b(Vector3(x, bottom + long / 2 - 0.1, 0.072), Vector3(0.012, long - 0.2, 0.008), patch)
		_t(Vector3(-0.02, top - 0.3, 0.078), Vector3(0.12, 0.7, 0.01), _c(data, "drape", "b0452f"), Vector3(0, 0, 0.55))
	_pattern(data, top - long * 0.55, body_w)
	if style == "night":
		_b(Vector3(0, top + 0.08, 0), Vector3(0.24, 0.16, 0.14), cloth)
	if data.get("torn", false):
		for x: float in [-0.16, 0.05, 0.18]:
			_b(Vector3(x, bottom + 0.05, 0.073), Vector3(0.06, 0.09, 0.012), "2a1f19")
	if data.has("fur"):
		_b(Vector3(0, top + 0.01, 0), Vector3(body_w + 0.08, 0.07, 0.17), String(data["fur"]))
		for side: float in [-1.0, 1.0]:
			_b(Vector3(side * (body_w / 2 + sleeve - 0.05), top - 0.24 - cuff + 0.05, 0), Vector3(0.17, 0.06, 0.16), String(data["fur"]))


## What is worked on the front: a 八卦 ring, clouds, scattered flowers, a crane's wings.
func _pattern(data: Dictionary, at_y: float, body_w: float) -> void:
	var accent: String = _c(data, "accent", "d8bf7a")
	match String(data.get("pattern", "")):
		"bagua":
			for i: int in 8:
				var a: float = i * TAU / 8
				_t(Vector3(cos(a) * 0.12, at_y + sin(a) * 0.12, 0.075), Vector3(0.06, 0.018, 0.01), accent, Vector3(0, 0, a + PI / 2))
			_b(Vector3(-0.025, at_y, 0.075), Vector3(0.05, 0.1, 0.01), "1d1612")
			_b(Vector3(0.025, at_y, 0.075), Vector3(0.05, 0.1, 0.01), "efe6d0")
		"cloud":
			for spot: Vector2 in [Vector2(-0.12, 0.1), Vector2(0.1, -0.05), Vector2(-0.05, -0.18)]:
				_b(Vector3(spot.x, at_y + spot.y, 0.075), Vector3(0.14, 0.04, 0.01), accent)
				_b(Vector3(spot.x + 0.03, at_y + spot.y + 0.035, 0.075), Vector3(0.07, 0.04, 0.01), accent)
		"flower":
			var random := RandomNumberGenerator.new()
			random.seed = 5
			for i: int in 9:
				_b(Vector3(random.randf_range(-body_w / 2.4, body_w / 2.4), at_y + random.randf_range(-0.25, 0.2), 0.075), Vector3(0.04, 0.04, 0.01), accent if i % 3 else _c(data, "accent2", accent))
		"stripes":
			for i: int in 4:
				_b(Vector3(0, at_y + 0.15 - i * 0.1, 0.075), Vector3(body_w, 0.025, 0.01), accent)
		"emblem":
			_b(Vector3(0, at_y + 0.12, 0.075), Vector3(0.12, 0.12, 0.01), accent)
			_b(Vector3(0, at_y + 0.12, 0.08), Vector3(0.07, 0.07, 0.01), _c(data, "accent2", "1d1612"))


## 战甲: a cuirass of lamellar rows, shoulder plates, a skirt of plates, a round chest mirror.
func _armor_suit(data: Dictionary) -> void:
	var plate: String = _c(data, "plate", "8a7a56")
	var plate2: String = _c(data, "plate2", Color(plate.get_slice(":", 0)).darkened(0.18).to_html(false))
	var trim: String = _c(data, "trim", "6b1c12")
	for row: int in 6:
		var y: float = 0.3 - row * 0.09
		for col: int in 6:
			_b(Vector3(-0.2 + col * 0.08, y, 0), Vector3(0.075, 0.085, 0.18), plate if (row + col) % 2 == 0 else plate2)
	_b(Vector3(0, 0.36, 0), Vector3(0.5, 0.05, 0.19), trim)
	_b(Vector3(0, -0.2, 0), Vector3(0.52, 0.06, 0.2), trim)
	for side: float in [-1.0, 1.0]:
		for layer: int in 3:
			_t(Vector3(side * (0.3 + layer * 0.02), 0.32 - layer * 0.07, 0), Vector3(0.2, 0.06, 0.2), plate if layer % 2 == 0 else plate2, Vector3(0, 0, side * -0.45))
		for row: int in 3:
			_b(Vector3(side * 0.13, -0.28 - row * 0.08, 0.01), Vector3(0.2, 0.075, 0.16), plate if row % 2 == 0 else plate2)
	if data.has("mirror"):
		_b(Vector3(0, 0.12, 0.1), Vector3(0.16, 0.16, 0.02), String(data["mirror"]))
		_t(Vector3(0, 0.12, 0.1), Vector3(0.16, 0.16, 0.02), String(data["mirror"]), Vector3(0, 0, PI / 4))
	if data.has("cloak"):
		_b(Vector3(0, -0.05, -0.12), Vector3(0.62, 0.8, 0.04), String(data["cloak"]))


## 战盔: a dome in narrowing tiers, a brim, cheek and neck guards, a crest with a plume.
func _helmet(data: Dictionary) -> void:
	var metal: String = _c(data, "metal", "8a6a3a:gloss")
	var trim: String = _c(data, "trim", "5a3a20")
	# A dome: tiers that narrow slowly then fast, each also turned 45° so it rounds.
	var widths: Array[float] = [0.5, 0.48, 0.43, 0.33, 0.18]
	for tier: int in widths.size():
		var w: float = widths[tier]
		_b(Vector3(0, -0.1 + tier * 0.08, 0), Vector3(w, 0.09, w), metal)
		_t(Vector3(0, -0.1 + tier * 0.08, 0), Vector3(w * 0.9, 0.09, w * 0.9), metal, Vector3(0, PI / 4, 0))
	for side: float in [-1.0, 1.0]:
		_b(Vector3(side * 0.05, 0.05, 0.255), Vector3(0.025, 0.3, 0.02), trim)
	_b(Vector3(0, -0.17, 0), Vector3(0.58, 0.04, 0.58), trim)
	for side: float in [-1.0, 1.0]:
		_b(Vector3(side * 0.24, -0.27, 0.05), Vector3(0.05, 0.18, 0.24), metal)
	_b(Vector3(0, -0.27, -0.24), Vector3(0.46, 0.18, 0.05), metal)
	_b(Vector3(0, 0.25, 0), Vector3(0.06, 0.1, 0.06), trim)
	if data.has("plume"):
		for i: int in 5:
			_t(Vector3((i - 2) * 0.02, 0.37, (i - 2) * 0.012), Vector3(0.04, 0.2, 0.04), String(data["plume"]), Vector3((i - 2) * 0.15, 0, (i - 2) * 0.2))
	if data.has("crest"):
		_b(Vector3(0, 0.0, 0.25), Vector3(0.14, 0.12, 0.02), String(data["crest"]))


## Head things: 冠 (a small crown with its pin), a tall 道冠, 巾 (a soft scarf with tails),
## 帽 (a cap), 簪 (a hairpin).
func _headwear(data: Dictionary) -> void:
	var main: String = _c(data, "color", "6b5a45")
	var accent: String = _c(data, "accent", "d8bf7a")
	match String(data.get("style", "crown")):
		"crown":
			_b(Vector3(0, -0.05, 0), Vector3(0.4, 0.16, 0.3), main)
			_b(Vector3(0, 0.08, 0.04), Vector3(0.3, 0.14, 0.22), main)
			_b(Vector3(0, 0.16, 0.08), Vector3(0.16, 0.1, 0.12), main)
			_b(Vector3(0, -0.12, 0), Vector3(0.42, 0.03, 0.32), accent)
			_b(Vector3(0, 0.04, 0), Vector3(0.62, 0.035, 0.035), accent)
			if data.has("gem"):
				_b(Vector3(0, 0.0, 0.16), Vector3(0.07, 0.07, 0.02), String(data["gem"]))
		"tall":
			# A 道冠 like a lotus: a band, a low crown, three petals leaning out (the middle one
			# tallest), their tips worked in the accent.
			_b(Vector3(0, -0.18, 0), Vector3(0.44, 0.1, 0.36), main)
			_b(Vector3(0, -0.22, 0), Vector3(0.46, 0.03, 0.38), accent)
			_dome(Vector3(0, -0.06, 0), 0.32, 0.14, main)
			for i: int in 3:
				var side: float = i - 1.0
				var tall: float = 0.36 if i == 1 else 0.28
				var lean := Vector3(0, 0, -side * 0.38)
				var at := Vector3(side * 0.13, -0.02 + tall / 2, 0.06 + (0.02 if i == 1 else 0.0))
				_t(at, Vector3(0.15, tall, 0.04), main, lean)
				_t(at + Vector3(side * 0.012, -0.01, 0.022), Vector3(0.09, tall * 0.7, 0.01), _c(data, "accent2", accent), lean)
				_t(at + Vector3(-side * tall * 0.18, tall * 0.48, 0), Vector3(0.06, 0.06, 0.05), accent, lean)
			if data.has("gem"):
				_b(Vector3(0, 0.02, 0.105), Vector3(0.06, 0.06, 0.02), String(data["gem"]))
		"scarf":
			# A soft cloth cap (幞头): a rounded crown, its band knotted behind, two long tails.
			_dome(Vector3(0, -0.02, 0), 0.44, 0.26, main)
			_b(Vector3(0, 0.16, -0.06), Vector3(0.22, 0.12, 0.18), main)
			_b(Vector3(0, -0.12, 0), Vector3(0.47, 0.05, 0.47), accent)
			_b(Vector3(0, -0.06, -0.25), Vector3(0.12, 0.1, 0.06), accent)
			for side: float in [-1.0, 1.0]:
				_t(Vector3(side * 0.16, -0.26, -0.24), Vector3(0.08, 0.34, 0.025), main, Vector3(0.35, 0, side * 0.35))
		"cap":
			_dome(Vector3(0, -0.05, 0), 0.44, 0.24, main)
			_b(Vector3(0, 0.12, -0.03), Vector3(0.3, 0.1, 0.26), main)
			_b(Vector3(0, -0.15, 0), Vector3(0.48, 0.05, 0.48), accent)
			_b(Vector3(0, -0.05, 0.235), Vector3(0.1, 0.08, 0.02), accent)
			if data.get("wings", false):
				for side: float in [-1.0, 1.0]:
					_b(Vector3(side * 0.36, 0.05, -0.14), Vector3(0.3, 0.05, 0.02), main)
		"hairpin":
			_t(Vector3(0, 0, 0), Vector3(0.9, 0.025, 0.025), main, Vector3(0, 0, 0.35))
			var head := Vector3(0.38, 0.15, 0)
			_b(head, Vector3(0.11, 0.11, 0.04), accent)
			_t(head, Vector3(0.11, 0.11, 0.04), accent, Vector3(0, 0, PI / 4))
			if data.has("gem"):
				_b(head + Vector3(0, 0, 0.03), Vector3(0.05, 0.05, 0.03), String(data["gem"]))
			if data.has("wings_color"):
				for side: float in [-1.0, 1.0]:
					_t(head + Vector3(side * 0.08, 0.05, 0), Vector3(0.14, 0.04, 0.02), String(data["wings_color"]), Vector3(0, 0, side * 0.5))
			for i: int in 3:
				_b(head + Vector3(-0.02 + i * 0.02, -0.08 - i * 0.04, 0), Vector3(0.02, 0.05, 0.02), accent)


## A rounded crown: a box, the same turned 45°, a smaller cap on it.
func _dome(at: Vector3, width: float, tall: float, hex: String) -> void:
	_b(at, Vector3(width, tall, width), hex)
	_t(at, Vector3(width * 0.88, tall, width * 0.88), hex, Vector3(0, PI / 4, 0))
	_b(at + Vector3(0, tall * 0.5, 0), Vector3(width * 0.7, tall * 0.25, width * 0.7), hex)


## 披风, 蓑衣: a cape falling from a collar, wider at the hem, in folds; fur trim or layers of
## straw.
func _cape(data: Dictionary) -> void:
	var main: String = _c(data, "color", "6b5a45")
	var fold: String = Color(main.get_slice(":", 0)).darkened(0.22).to_html(false)
	var straw: bool = String(data.get("style", "cloak")) == "straw"
	for i: int in 6:
		var w: float = 0.42 + i * 0.07
		var y: float = 0.3 - i * 0.12
		_b(Vector3(0, y, -i * 0.012), Vector3(w, 0.125, 0.07), main if i % 2 == 0 or not straw else _c(data, "color2", main))
		if not straw:
			for x: float in [-0.3, 0.0, 0.3]:
				_b(Vector3(x * w, y, 0.036 - i * 0.012), Vector3(0.03, 0.13, 0.01), fold)
		if straw:
			for j: int in 7:
				_t(Vector3(-w / 2 + (j + 0.5) * w / 7, y - 0.07, 0.04 - i * 0.012), Vector3(0.025, 0.1, 0.02), _c(data, "color2", "8a7a4a"), Vector3(0, 0, (j - 3) * 0.06))
	_b(Vector3(0, 0.38, 0.02), Vector3(0.4, 0.06, 0.12), _c(data, "collar", main))
	if data.has("fur"):
		_b(Vector3(0, 0.38, 0.03), Vector3(0.5, 0.1, 0.16), String(data["fur"]))
		_b(Vector3(0, -0.4, 0.0), Vector3(0.82, 0.06, 0.1), String(data["fur"]))
	if data.has("clasp"):
		_b(Vector3(0, 0.36, 0.1), Vector3(0.07, 0.07, 0.03), String(data["clasp"]))


## A pair of shoes or boots: `style` boots (tall shafts), shoes, embroidered (pointed toes and
## flowers), straw sandals.
func _shoes(data: Dictionary) -> void:
	var main: String = _c(data, "color", "5a4030")
	var sole: String = _c(data, "sole", "2e2119")
	var style: String = String(data.get("style", "boots"))
	for side: float in [-1.0, 1.0]:
		var x: float = side * 0.16
		if style == "straw":
			_b(Vector3(x, -0.2, 0.02), Vector3(0.18, 0.04, 0.42), main)
			for i: int in 3:
				_b(Vector3(x, -0.15, -0.1 + i * 0.12), Vector3(0.2, 0.03, 0.03), _c(data, "straps", "8a6a3e"))
			continue
		_b(Vector3(x, -0.2, 0.04), Vector3(0.18, 0.05, 0.4), sole)
		_b(Vector3(x, -0.12, 0.06), Vector3(0.17, 0.12, 0.34), main)
		if style == "embroidered":
			_b(Vector3(x, -0.13, 0.25), Vector3(0.1, 0.08, 0.06), main)
			_b(Vector3(x, -0.08, 0.14), Vector3(0.05, 0.04, 0.04), _c(data, "accent", "d84a5a"))
		if style == "boots":
			_b(Vector3(x, 0.08, -0.06), Vector3(0.17, 0.32, 0.18), main)
			_b(Vector3(x, 0.24, -0.06), Vector3(0.19, 0.04, 0.2), _c(data, "trim", sole))
		if data.has("fur"):
			_b(Vector3(x, 0.26 if style == "boots" else -0.04, -0.06), Vector3(0.21, 0.07, 0.22), String(data["fur"]))


## 盾: round, with a rim, a boss and studs.
func _shield(data: Dictionary) -> void:
	var face: String = _c(data, "face", "8a5a35")
	for angle: float in [0.0, PI / 4]:
		_t(Vector3.ZERO, Vector3(0.7, 0.7, 0.06), face, Vector3(0, 0, angle))
		_t(Vector3(0, 0, -0.01), Vector3(0.76, 0.76, 0.04), _c(data, "rim", "4b3a2c"), Vector3(0, 0, angle))
	_b(Vector3(0, 0, 0.05), Vector3(0.18, 0.18, 0.06), _c(data, "boss", "a88447:gloss"))
	for i: int in 8:
		var a: float = i * TAU / 8
		_b(Vector3(cos(a) * 0.27, sin(a) * 0.27, 0.035), Vector3(0.04, 0.04, 0.02), _c(data, "studs", "a88447"))


## 项链, 念珠, 护身符, 胸针: beads round a loop, or a cord with one thing on it.
func _necklace(data: Dictionary) -> void:
	var bead: String = _c(data, "bead", "efece4:gloss")
	match String(data.get("style", "beads")):
		"amulet":
			# The cord loops up from the charm's top and back down to it.
			for i: int in 24:
				var a: float = -PI * 0.38 + i * PI * 1.76 / 23
				_b(Vector3(cos(a + PI / 2) * 0.22, -0.02 + sin(a + PI / 2) * 0.26, 0), Vector3(0.03, 0.03, 0.03), _c(data, "cord", "c0392b"))
			_b(Vector3(0, -0.22, 0), Vector3(0.22, 0.28, 0.04), _c(data, "charm", "e6c34a"))
			_b(Vector3(0, -0.22, 0.025), Vector3(0.05, 0.2, 0.01), _c(data, "mark", "c0392b"))
		"brooch":
			_b(Vector3.ZERO, Vector3(0.3, 0.3, 0.06), _c(data, "setting", "d8bf7a:gloss"))
			_t(Vector3(0, 0, 0.04), Vector3(0.2, 0.2, 0.06), bead, Vector3(0, 0, PI / 4))
			_b(Vector3(0, 0, 0.08), Vector3(0.08, 0.08, 0.03), "ffffff:gloss")
		"pendant":
			for i: int in 24:
				var a: float = -PI * 0.38 + i * PI * 1.76 / 23
				_b(Vector3(cos(a + PI / 2) * 0.22, 0.02 + sin(a + PI / 2) * 0.26, 0), Vector3(0.026, 0.026, 0.026), _c(data, "cord", "5a3a28"))
			_b(Vector3(0, -0.15, 0), Vector3(0.2, 0.24, 0.05), bead)
		_:
			var count: int = int(data.get("count", 18))
			for i: int in count:
				var a: float = i * TAU / count
				_b(Vector3(cos(a) * 0.3, sin(a) * 0.3, 0), Vector3(0.06, 0.06, 0.06), bead if i % 6 else _c(data, "bead2", bead))
			if data.has("tassel"):
				_b(Vector3(0, -0.36, 0), Vector3(0.05, 0.06, 0.05), String(data["tassel"]))
				_b(Vector3(0, -0.45, 0), Vector3(0.04, 0.14, 0.04), String(data["tassel"]))


func _ring(data: Dictionary) -> void:
	var band: String = _c(data, "band", "d8bf7a:gloss")
	for i: int in 12:
		var a: float = i * TAU / 12
		_b(Vector3(cos(a) * 0.22, sin(a) * 0.22 - 0.06, 0), Vector3(0.07, 0.07, 0.1), band)
	_b(Vector3(0, 0.2, 0), Vector3(0.18, 0.1, 0.14), band)
	_b(Vector3(0, 0.28, 0), Vector3(0.14, 0.1, 0.12), _c(data, "gem", "b5e3ea:gloss"))


func _bracelet(data: Dictionary) -> void:
	var colour: String = _c(data, "color", "b5473b:gloss")
	for i: int in 16:
		var a: float = i * TAU / 16
		_t(Vector3(cos(a) * 0.3, sin(a) * 0.3, 0), Vector3(0.13, 0.08, 0.12), colour, Vector3(0, 0, a))


## 腰带, 束带: a strap drawn as a loop with its buckle, or a sash with hanging tails.
func _belt(data: Dictionary) -> void:
	var strap: String = _c(data, "color", "6b4a33")
	for i: int in 16:
		var a: float = i * TAU / 16
		_t(Vector3(cos(a) * 0.36, 0, sin(a) * 0.3), Vector3(0.15, 0.09, 0.03), strap, Vector3(0, -a + PI / 2, 0))
	_b(Vector3(0, 0, 0.31), Vector3(0.14, 0.12, 0.04), _c(data, "buckle", "a88447:gloss"))
	if data.has("gem"):
		_b(Vector3(0, 0, 0.34), Vector3(0.06, 0.06, 0.02), String(data["gem"]))
	if data.get("tails", false):
		for side: float in [-1.0, 1.0]:
			_t(Vector3(side * 0.06, -0.2, 0.31), Vector3(0.06, 0.34, 0.02), strap, Vector3(0, 0, side * 0.12))


## 裙: a waistband and a flaring skirt of pleats.
func _skirt(data: Dictionary) -> void:
	var main: String = _c(data, "color", "6f8f6a")
	var pleat: String = _c(data, "color2", Color(main.get_slice(":", 0)).darkened(0.15).to_html(false))
	for tier: int in 4:
		var w: float = 0.42 + tier * 0.1
		var y: float = 0.22 - tier * 0.15
		for i: int in 6:
			_b(Vector3(-w / 2 + (i + 0.5) * w / 6, y, 0), Vector3(w / 6 + 0.003, 0.155, 0.16 + tier * 0.02), main if i % 2 == 0 else pleat)
	_b(Vector3(0, 0.32, 0), Vector3(0.44, 0.06, 0.17), _c(data, "band", "d8bf7a"))
	if data.has("accent"):
		_b(Vector3(0, -0.3, 0.1), Vector3(0.72, 0.03, 0.02), String(data["accent"]))


func _eyepatch(data: Dictionary) -> void:
	var patch: String = _c(data, "color", "1d1612")
	_b(Vector3.ZERO, Vector3(0.26, 0.2, 0.04), patch)
	_t(Vector3(0.05, 0.02, 0.0), Vector3(0.18, 0.12, 0.05), patch, Vector3(0, 0, PI / 4))
	_t(Vector3(-0.3, 0.12, -0.02), Vector3(0.4, 0.03, 0.02), _c(data, "strap", "2e2119"), Vector3(0, 0, -0.35))
	_t(Vector3(0.3, 0.12, -0.02), Vector3(0.4, 0.03, 0.02), _c(data, "strap", "2e2119"), Vector3(0, 0, 0.35))


func _earrings(data: Dictionary) -> void:
	for side: float in [-1.0, 1.0]:
		var x: float = side * 0.16
		_b(Vector3(x, 0.2, 0), Vector3(0.06, 0.06, 0.02), _c(data, "hook", "d8bf7a:gloss"))
		_b(Vector3(x, 0.08, 0), Vector3(0.025, 0.18, 0.025), _c(data, "hook", "d8bf7a:gloss"))
		_b(Vector3(x, -0.08, 0), Vector3(0.12, 0.16, 0.08), _c(data, "drop", "b5e3ea:gloss"))
