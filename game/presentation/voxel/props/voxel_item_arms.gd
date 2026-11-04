extends RefCounted

## Carried weapons as the 背包 shows them (owner, 2026-11-04): swords, sabres, staves, whips
## and the odd things ES2 throws or swings (a feather, chess pieces, a roast leg). Drawn
## about the origin, long things standing up (tip at the top), the longest side about one
## unit; the item view frames and turns them. Colours and sizes come from the item's look
## (game/data/common/item_looks.json); no item or region logic here.
const Shapes = preload("res://presentation/voxel/props/voxel_shapes.gd")
const STEEL := "c9d1d6:gloss"
var s: Shapes
var root: Node3D


func draw(shapes: Shapes, parent: Node3D, data: Dictionary) -> bool:
	s = shapes
	root = parent
	match String(data["kind"]):
		"sword":
			_sword(data)
		"saber":
			_saber(data)
		"dagger":
			_dagger(data)
		"cleaver":
			_cleaver(data)
		"axe":
			_axe(data)
		"hammer":
			_hammer(data)
		"staff":
			_staff(data)
		"fork":
			_fork(data)
		"whip":
			_whip(data)
		"whisk":
			_whisk(data)
		"broom":
			_broom(data)
		"fan":
			_fan(data)
		"scissors":
			_scissors(data)
		"ruler":
			_ruler(data)
		"knives":
			_knives(data)
		"darts":
			_darts(data)
		"needles":
			_needles(data)
		"petals":
			_petals(data)
		"feather":
			_feather(data)
		"leaves":
			_leaves(data)
		"chess":
			_chess(data)
		"meat":
			_meat(data)
		_:
			return false
	return true


func _c(data: Dictionary, key: String, fallback: String) -> String:
	return String(data.get(key, fallback))


func _f(data: Dictionary, key: String, fallback: float) -> float:
	return float(data.get(key, fallback))


func _b(at: Vector3, size: Vector3, hex: String) -> void:
	s.box(root, at, size, hex)


func _t(at: Vector3, size: Vector3, hex: String, angles: Vector3) -> void:
	s.tilted_box(root, at, size, hex, angles)


## A grip from `bottom` up `length`, wrapped in bands, with a pommel under it.
func _grip(bottom: float, length: float, thick: float, grip: String, wrap: String, pommel: String) -> void:
	_b(Vector3(0, bottom + length / 2, 0), Vector3(thick, length, thick), grip)
	var bands: int = maxi(2, roundi(length / 0.06))
	for i: int in bands:
		_b(Vector3(0, bottom + (i + 0.5) * length / bands, 0), Vector3(thick + 0.012, 0.014, thick + 0.012), wrap)
	_b(Vector3(0, bottom - 0.025, 0), Vector3(thick + 0.035, 0.05, thick + 0.035), pommel)


## A tassel (剑穗) hanging from `at`: a knot and its strands.
func _tassel(at: Vector3, colour: String) -> void:
	_b(at, Vector3(0.05, 0.05, 0.05), colour)
	for i: int in 4:
		var x: float = (i - 1.5) * 0.016
		_t(at + Vector3(0.02 + x, -0.1, 0.0), Vector3(0.012, 0.16, 0.012), colour, Vector3(0, 0, 0.18 + x))


## A blade snapped off at `at`: a jagged edge of uneven teeth.
func _snapped(at: Vector3, width: float, blade: String) -> void:
	for i: int in 3:
		var tall: float = [0.05, 0.02, 0.035][i]
		_b(at + Vector3((i - 1) * width / 3, tall / 2, 0), Vector3(width / 3, tall, 0.02), blade)


## 剑: a straight two-edged blade with a ridge, a guard, a wrapped grip, a tassel if any.
func _sword(data: Dictionary) -> void:
	var length: float = _f(data, "length", 1.0)
	var width: float = _f(data, "width", 0.075)
	var blade: String = _c(data, "blade", STEEL)
	var bottom: float = -length / 2
	var grip_length: float = length * 0.2
	_grip(bottom + 0.03, grip_length, 0.045, _c(data, "grip", "4a3426"), _c(data, "wrap", "2e2119"), _c(data, "pommel", _c(data, "guard", "a88447")))
	var guard_at: float = bottom + 0.03 + grip_length
	_b(Vector3(0, guard_at + 0.025, 0), Vector3(width * 2.6, 0.05, 0.08), _c(data, "guard", "a88447"))
	_b(Vector3(0, guard_at + 0.06, 0), Vector3(width * 1.4, 0.03, 0.06), _c(data, "guard", "a88447"))
	var start: float = guard_at + 0.075
	var reach: float = length / 2 - start - 0.06
	if data.get("broken", false):
		reach *= 0.42
	_b(Vector3(0, start + reach / 2, 0), Vector3(width, reach, 0.02), blade)
	_b(Vector3(0, start + reach / 2, 0.011), Vector3(width * 0.18, reach * 0.95, 0.008), _c(data, "ridge", "8e979d:gloss"))
	if data.get("broken", false):
		_snapped(Vector3(0, start + reach, 0), width, blade)
	else:
		_b(Vector3(0, start + reach + 0.02, 0), Vector3(width * 0.62, 0.04, 0.02), blade)
		_b(Vector3(0, start + reach + 0.05, 0), Vector3(width * 0.28, 0.03, 0.02), blade)
	if data.has("tassel"):
		_tassel(Vector3(0.02, bottom - 0.03, 0), String(data["tassel"]))
	if data.has("inlay"):
		_b(Vector3(0, start + 0.08, 0.012), Vector3(width * 0.5, 0.07, 0.008), String(data["inlay"]))


## 刀: one edge, a heavier back, the blade sweeping forward near the point; a round guard and a
## long grip, a ring at the end if it has one (环首刀).
func _saber(data: Dictionary) -> void:
	var length: float = _f(data, "length", 1.0)
	var width: float = _f(data, "width", 0.11)
	var curve: float = _f(data, "curve", 0.05)
	var blade: String = _c(data, "blade", STEEL)
	var back: String = _c(data, "back", "8e979d:gloss")
	var bottom: float = -length / 2
	var grip_length: float = length * 0.24
	_grip(bottom + 0.03, grip_length, 0.05, _c(data, "grip", "3d2a1e"), _c(data, "wrap", "7a2a20"), _c(data, "pommel", "a88447"))
	if data.get("ring", false):
		for side: float in [-1.0, 1.0]:
			_b(Vector3(side * 0.045, bottom - 0.02, 0), Vector3(0.016, 0.09, 0.02), _c(data, "pommel", "a88447"))
		_b(Vector3(0, bottom - 0.065, 0), Vector3(0.1, 0.016, 0.02), _c(data, "pommel", "a88447"))
	var guard_at: float = bottom + 0.03 + grip_length
	_b(Vector3(0, guard_at + 0.02, 0), Vector3(0.17, 0.04, 0.15), _c(data, "guard", "a88447"))
	_t(Vector3(0, guard_at + 0.02, 0), Vector3(0.17, 0.04, 0.15), _c(data, "guard", "a88447"), Vector3(0, PI / 4, 0))
	var start: float = guard_at + 0.04
	var reach: float = length / 2 - start
	var parts: int = 6
	if data.get("broken", false):
		reach *= 0.45
		parts = 3
	for i: int in parts:
		var u: float = float(i) / parts
		var y: float = start + (i + 0.5) * reach / parts
		var bend: float = curve * u * u
		var w: float = width * (1.0 - 0.45 * pow(u, 3))
		_b(Vector3(bend + w / 2 - width / 2, y, 0), Vector3(w, reach / parts + 0.004, 0.02), blade)
		_b(Vector3(bend - width / 2 + 0.01, y, 0), Vector3(0.022, reach / parts + 0.004, 0.028), back)
	if data.get("broken", false):
		_snapped(Vector3(curve * 0.25, start + reach, 0), width, blade)
	else:
		_t(Vector3(curve + width * 0.15, length / 2 - 0.01, 0), Vector3(width * 0.5, 0.05, 0.02), blade, Vector3(0, 0, -0.6))
	if data.has("notch"):
		_b(Vector3(-width / 2 + 0.02, start + reach * 0.6, 0), Vector3(0.03, 0.05, 0.03), String(data["notch"]))
	if data.has("tassel"):
		_tassel(Vector3(0.03, bottom - 0.04, 0), String(data["tassel"]))


## 匕首 and short knives: a short blade, a small guard, a plain grip.
func _dagger(data: Dictionary) -> void:
	var length: float = _f(data, "length", 0.7)
	var width: float = _f(data, "width", 0.08)
	var bottom: float = -length / 2
	_grip(bottom + 0.03, length * 0.36, 0.05, _c(data, "grip", "5a3a28"), _c(data, "wrap", "3a2618"), _c(data, "pommel", "8b6b3d"))
	var guard_at: float = bottom + 0.03 + length * 0.36
	_b(Vector3(0, guard_at + 0.02, 0), Vector3(width * 2.0, 0.04, 0.07), _c(data, "guard", "8b6b3d"))
	var start: float = guard_at + 0.04
	var reach: float = length / 2 - start
	var blade: String = _c(data, "blade", STEEL)
	_b(Vector3(0, start + reach * 0.4, 0), Vector3(width, reach * 0.8, 0.02), blade)
	_b(Vector3(0, start + reach * 0.88, 0), Vector3(width * 0.55, reach * 0.16, 0.02), blade)
	_b(Vector3(0, start + reach * 0.98, 0), Vector3(width * 0.22, reach * 0.06, 0.02), blade)


## 菜刀: a broad square blade straight off a short wooden handle, no guard.
func _cleaver(data: Dictionary) -> void:
	var blade: String = _c(data, "blade", "a9b0b3:gloss")
	_b(Vector3(0, -0.24, 0), Vector3(0.07, 0.36, 0.06), _c(data, "grip", "7a5634"))
	_b(Vector3(0, -0.05, 0), Vector3(0.08, 0.04, 0.07), _c(data, "band", "4b3a2c"))
	_b(Vector3(0.06, 0.2, 0), Vector3(0.3, 0.46, 0.025), blade)
	_b(Vector3(-0.08, 0.2, 0), Vector3(0.03, 0.46, 0.04), _c(data, "back", "6f777b:gloss"))
	_b(Vector3(0.2, 0.2, 0.0), Vector3(0.02, 0.44, 0.02), _c(data, "edge", "dfe5e8:gloss"))
	if data.has("hole"):
		_b(Vector3(0.12, 0.38, 0), Vector3(0.05, 0.05, 0.03), String(data["hole"]))


## 斧: a haft with a head near the top, one bit or two.
func _axe(data: Dictionary) -> void:
	var length: float = _f(data, "length", 0.9)
	var haft: String = _c(data, "haft", "7a5634")
	_b(Vector3(0, 0, 0), Vector3(0.05, length, 0.05), haft)
	_b(Vector3(0, -length / 2 + 0.03, 0), Vector3(0.065, 0.06, 0.065), _c(data, "cap", "4b3a2c"))
	var top: float = length / 2 - 0.12
	var head: String = _c(data, "head", "8f979b:gloss")
	var edge: String = _c(data, "edge", "d4dadd:gloss")
	_b(Vector3(0, top, 0), Vector3(0.1, 0.16, 0.08), head)
	var sides: Array[float] = [1.0]
	if data.get("double", false):
		sides.append(-1.0)
	for side: float in sides:
		_b(Vector3(side * 0.11, top, 0), Vector3(0.14, 0.13, 0.05), head)
		_b(Vector3(side * 0.2, top, 0), Vector3(0.06, 0.26, 0.04), edge)
	if sides.size() == 1:
		_b(Vector3(-0.08, top, 0), Vector3(0.07, 0.07, 0.07), head)


## 锤 and 槌: a haft and a heavy head, round (two crossed blocks), eight-sided or square.
func _hammer(data: Dictionary) -> void:
	var length: float = _f(data, "length", 0.9)
	var size: float = _f(data, "size", 0.24)
	var head: String = _c(data, "head", "6f777b:gloss")
	_b(Vector3(0, -0.08, 0), Vector3(0.05, length - 0.16, 0.05), _c(data, "haft", "6b4a2e"))
	_b(Vector3(0, -length / 2 + 0.02, 0), Vector3(0.07, 0.05, 0.07), _c(data, "cap", "4b3a2c"))
	var top: float = length / 2 - size / 2
	match String(data.get("shape", "round")):
		"square":
			_b(Vector3(0, top, 0), Vector3(size * 1.3, size, size), head)
			_b(Vector3(0, top, 0), Vector3(size * 1.42, size * 0.8, size * 0.8), _c(data, "band", head))
		"octagon":
			_b(Vector3(0, top, 0), Vector3(size, size * 1.2, size), head)
			_t(Vector3(0, top, 0), Vector3(size, size * 1.2, size), head, Vector3(0, PI / 4, 0))
			for y: float in [-0.5, 0.5]:
				_b(Vector3(0, top + y * size * 1.2, 0), Vector3(size * 0.8, 0.03, size * 0.8), _c(data, "band", "4c5356"))
		_:
			_b(Vector3(0, top, 0), Vector3(size, size * 0.86, size), head)
			_t(Vector3(0, top, 0), Vector3(size * 0.86, size, size * 0.86), head, Vector3(0, PI / 4, PI / 4))
			_b(Vector3(0, top, 0), Vector3(size * 0.7, size * 1.1, size * 0.7), head)
	_b(Vector3(0, top - size * 0.6, 0), Vector3(0.08, 0.04, 0.08), _c(data, "band", "4c5356"))


## 棍, 杖, 杵: a long pole capped at both ends; `head` puts a 禅杖's ring of jingles, a
## vajra's prongs or a dragon knob on top.
func _staff(data: Dictionary) -> void:
	var length: float = _f(data, "length", 1.0)
	var shaft: String = _c(data, "shaft", "8a6a3e")
	var cap: String = _c(data, "cap", "a88447")
	var thick: float = _f(data, "thick", 0.05)
	_b(Vector3.ZERO, Vector3(thick, length, thick), shaft)
	for end: float in [-1.0, 1.0]:
		_b(Vector3(0, end * (length / 2 - 0.04), 0), Vector3(thick + 0.02, 0.08, thick + 0.02), cap)
	if data.has("bands"):
		for i: int in 3:
			_b(Vector3(0, -0.2 + i * 0.2, 0), Vector3(thick + 0.012, 0.02, thick + 0.012), String(data["bands"]))
	var top: float = length / 2
	match String(data.get("head", "")):
		"rings":
			for side: float in [-1.0, 1.0]:
				_t(Vector3(side * 0.07, top + 0.06, 0), Vector3(0.025, 0.16, 0.025), cap, Vector3(0, 0, side * -0.5))
			_b(Vector3(0, top + 0.14, 0), Vector3(0.1, 0.025, 0.025), cap)
			for i: int in 4:
				_b(Vector3((i - 1.5) * 0.06, top + 0.03 - (i % 2) * 0.02, 0.02), Vector3(0.035, 0.035, 0.015), _c(data, "jingle", "d8bf7a:gloss"))
		"vajra":
			for end: float in [-1.0, 1.0]:
				for side: float in [-1.0, 0.0, 1.0]:
					_t(Vector3(side * 0.035, end * (length / 2 + 0.05), 0), Vector3(0.022, 0.12, 0.022), cap, Vector3(0, 0, -side * end * 0.35))
		"knob":
			_b(Vector3(0, top + 0.04, 0), Vector3(0.09, 0.08, 0.09), cap)
			_t(Vector3(0, top + 0.04, 0), Vector3(0.09, 0.08, 0.09), cap, Vector3(0, PI / 4, 0))


## 叉: a pole with a crossbar and its prongs.
func _fork(data: Dictionary) -> void:
	var length: float = _f(data, "length", 1.0)
	var metal: String = _c(data, "head", "9aa2a6:gloss")
	_b(Vector3(0, -0.06, 0), Vector3(0.05, length - 0.12, 0.05), _c(data, "shaft", "7a5634"))
	var prongs: int = int(data.get("prongs", 5))
	var top: float = length / 2 - 0.12
	_b(Vector3(0, top - 0.06, 0), Vector3(0.05 * prongs, 0.04, 0.04), metal)
	for i: int in prongs:
		var x: float = (i - (prongs - 1) / 2.0) * 0.05
		var tall: float = 0.18 if i * 2 + 1 == prongs else 0.14
		_b(Vector3(x, top - 0.04 + tall / 2, 0), Vector3(0.018, tall, 0.018), metal)
		_b(Vector3(x, top - 0.04 + tall + 0.012, 0), Vector3(0.01, 0.025, 0.01), metal)


## 鞭: a handle and a coiled lash (`style` soft), a jointed steel rod (segmented), or a tail
## with its tuft (牛尾).
func _whip(data: Dictionary) -> void:
	var colour: String = _c(data, "lash", "6b4a33")
	var handle: String = _c(data, "handle", "4a3426")
	match String(data.get("style", "soft")):
		"segmented":
			_b(Vector3(0, -0.4, 0), Vector3(0.05, 0.2, 0.05), handle)
			for i: int in 8:
				_b(Vector3(0, -0.27 + i * 0.09, 0), Vector3(0.06 - i * 0.003, 0.07, 0.06 - i * 0.003), colour)
		"tail":
			for i: int in 7:
				var w: float = 0.11 - i * 0.012
				_b(Vector3(sin(i * 0.5) * 0.03, -0.35 + i * 0.09, 0), Vector3(w, 0.1, w), colour)
			for i: int in 5:
				_t(Vector3((i - 2) * 0.02, 0.32, 0), Vector3(0.025, 0.2, 0.025), _c(data, "tuft", "2e2119"), Vector3(0, 0, (i - 2) * 0.2))
		_:
			# The handle stands up out of the coiled lash: three loops, each a little smaller.
			_b(Vector3(0, 0.16, 0), Vector3(0.055, 0.4, 0.055), handle)
			_b(Vector3(0, 0.37, 0), Vector3(0.07, 0.04, 0.07), _c(data, "cap", "a88447"))
			_b(Vector3(0, -0.05, 0), Vector3(0.07, 0.05, 0.07), _c(data, "cap", "a88447"))
			for i: int in 54:
				var a: float = i * TAU / 18
				var r: float = 0.3 - i * 0.003
				_t(Vector3(cos(a) * r, -0.12 - i * 0.0045, sin(a) * r), Vector3(0.12, 0.04, 0.045), colour, Vector3(0, -a, 0))
			_t(Vector3(0.33, -0.33, 0.06), Vector3(0.04, 0.16, 0.04), colour, Vector3(0, 0, 0.5))


## 拂尘: a short handle and a fall of white hair.
func _whisk(data: Dictionary) -> void:
	_b(Vector3(0, 0.2, 0), Vector3(0.04, 0.5, 0.04), _c(data, "handle", "8a5a35"))
	_b(Vector3(0, -0.06, 0), Vector3(0.07, 0.05, 0.07), _c(data, "cap", "a88447"))
	var hair: String = _c(data, "hair", "eee8dc")
	for i: int in 9:
		var a: float = i * TAU / 9
		_t(Vector3(cos(a) * 0.03, -0.27, sin(a) * 0.03), Vector3(0.03, 0.42, 0.03), hair, Vector3(sin(a) * 0.12, 0, cos(a) * 0.12))


## 扫把: a long handle and a fan of bristles.
func _broom(data: Dictionary) -> void:
	_b(Vector3(0, 0.12, 0), Vector3(0.04, 0.76, 0.04), _c(data, "handle", "b39257"))
	var bristle: String = _c(data, "bristle", "c9a95e")
	for i: int in 7:
		_t(Vector3((i - 3) * 0.035, -0.36, 0), Vector3(0.03, 0.3, 0.05), bristle, Vector3(0, 0, (i - 3) * 0.1))
	_b(Vector3(0, -0.23, 0), Vector3(0.14, 0.04, 0.07), _c(data, "tie", "7a5634"))


## 扇: an open folding fan, its ribs spread over a half circle, the guard ribs heavier.
func _fan(data: Dictionary) -> void:
	var rib: String = _c(data, "ribs", "6f777b:gloss")
	var leaf: String = _c(data, "leaf", "e6dcc2")
	for i: int in 11:
		var a: float = -PI / 2.4 + i * (PI / 1.2) / 10
		var dir := Vector3(sin(a), cos(a), 0)
		_t(dir * 0.32 + Vector3(0, -0.25, 0), Vector3(0.11, 0.34, 0.012), leaf if i % 2 == 0 else _c(data, "leaf2", leaf), Vector3(0, 0, -a))
		_t(dir * 0.24 + Vector3(0, -0.25, 0.01), Vector3(0.016 if i in [0, 10] else 0.01, 0.48, 0.012), rib, Vector3(0, 0, -a))
	_b(Vector3(0, -0.26, 0.012), Vector3(0.05, 0.05, 0.03), _c(data, "pin", "a88447"))
	if data.has("tassel"):
		_tassel(Vector3(0, -0.33, 0.01), String(data["tassel"]))


## 剪: two crossed blades and their handles, round loops (tailor's) or long arms (garden).
func _scissors(data: Dictionary) -> void:
	var blade: String = _c(data, "blade", STEEL)
	var handle: String = _c(data, "handle", "3d3530")
	var long_arms: bool = String(data.get("style", "loops")) == "long"
	for side: float in [-1.0, 1.0]:
		_t(Vector3(side * 0.04, 0.2, side * 0.01), Vector3(0.05, 0.5, 0.015), blade, Vector3(0, 0, side * 0.16))
		if long_arms:
			_t(Vector3(side * 0.07, -0.25, side * 0.01), Vector3(0.05, 0.42, 0.04), handle, Vector3(0, 0, -side * 0.18))
		else:
			var at := Vector3(-side * 0.08, -0.2, side * 0.01)
			for corner: Vector2 in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
				_b(at + Vector3(corner.x * 0.05, corner.y * 0.05, 0), Vector3(0.03 if corner.x != 0 else 0.1, 0.1 if corner.x != 0 else 0.03, 0.02), handle)
	_b(Vector3(0, -0.02, 0.02), Vector3(0.035, 0.035, 0.03), _c(data, "pin", "a88447"))


## 尺: a long flat strip with its marks.
func _ruler(data: Dictionary) -> void:
	_b(Vector3.ZERO, Vector3(0.09, 1.0, 0.02), _c(data, "wood", "c9a35e"))
	for i: int in 20:
		_b(Vector3(-0.03 + (0.015 if i % 5 == 0 else 0.0), -0.475 + i * 0.05, 0.011), Vector3(0.03 if i % 5 == 0 else 0.018, 0.008, 0.004), _c(data, "marks", "3a2618"))


## 飞刀: a few small knives fanned out.
func _knives(data: Dictionary) -> void:
	var count: int = int(data.get("count", 3))
	for i: int in count:
		var a: float = (i - (count - 1) / 2.0) * 0.35
		var dir := Vector3(sin(a), cos(a), 0)
		_t(dir * 0.18, Vector3(0.07, 0.34, 0.015), _c(data, "blade", STEEL), Vector3(0, 0, -a))
		_t(dir * -0.08, Vector3(0.045, 0.16, 0.03), _c(data, "grip", "5a3a28"), Vector3(0, 0, -a))
		if data.has("tassel"):
			_t(dir * -0.2, Vector3(0.03, 0.08, 0.03), String(data["tassel"]), Vector3(0, 0, -a))


## 飞镖: diamond heads on short shafts, red tassels behind.
func _darts(data: Dictionary) -> void:
	var count: int = int(data.get("count", 3))
	for i: int in count:
		var a: float = (i - (count - 1) / 2.0) * 0.4
		var dir := Vector3(sin(a), cos(a), 0)
		_t(dir * 0.24, Vector3(0.09, 0.09, 0.02), _c(data, "blade", STEEL), Vector3(0, 0, PI / 4 - a))
		_t(dir * 0.1, Vector3(0.025, 0.2, 0.025), _c(data, "shaft", "6f777b"), Vector3(0, 0, -a))
		_t(dir * -0.05, Vector3(0.05, 0.12, 0.05), _c(data, "tassel", "c0392b"), Vector3(0, 0, -a))


## 针: a cushion stuck with long thin needles, a thread off one.
func _needles(data: Dictionary) -> void:
	_b(Vector3(0, -0.25, 0), Vector3(0.3, 0.12, 0.3), _c(data, "cushion", "b3473f"))
	_b(Vector3(0, -0.18, 0), Vector3(0.24, 0.04, 0.24), _c(data, "cushion_top", "c9584f"))
	var count: int = int(data.get("count", 5))
	for i: int in count:
		var a: float = i * TAU / count
		_t(Vector3(cos(a) * 0.06, 0.05, sin(a) * 0.06), Vector3(0.012, 0.5, 0.012), _c(data, "needle", "dfe5e8:gloss"), Vector3(sin(a) * 0.15, 0, cos(a) * 0.15))
	if data.has("thread"):
		_t(Vector3(0.12, 0.1, 0), Vector3(0.008, 0.4, 0.008), String(data["thread"]), Vector3(0, 0, 0.5))


## 花瓣, 花: a small scatter of petals or tiny blossoms, drifting.
func _petals(data: Dictionary) -> void:
	var colour: String = _c(data, "petal", "b15fb3")
	var deep: String = _c(data, "petal2", colour)
	var count: int = int(data.get("count", 7))
	var random := RandomNumberGenerator.new()
	random.seed = 77
	for i: int in count:
		var at := Vector3(random.randf_range(-0.3, 0.3), random.randf_range(-0.3, 0.3), random.randf_range(-0.2, 0.2))
		_t(at, Vector3(0.14, 0.03, 0.09), colour if i % 2 == 0 else deep, Vector3(random.randf_range(-0.8, 0.8), random.randf_range(0, TAU), random.randf_range(-0.8, 0.8)))
		if data.has("heart"):
			_b(at + Vector3(0, 0.02, 0), Vector3(0.03, 0.03, 0.03), String(data["heart"]))


## 鸡毛: a quill with its vane.
func _feather(data: Dictionary) -> void:
	var vane: String = _c(data, "vane", "c9874a")
	var tip: String = _c(data, "tip", "3a2a20")
	_t(Vector3.ZERO, Vector3(0.016, 0.95, 0.016), _c(data, "quill", "efe6d0"), Vector3(0, 0, 0.12))
	for i: int in 9:
		var y: float = -0.25 + i * 0.075
		var w: float = 0.16 * sin(PI * (i + 1) / 10.0) + 0.04
		for side: float in [-1.0, 1.0]:
			_t(Vector3(side * w / 2 - y * 0.12, y, 0), Vector3(w, 0.07, 0.012), tip if i >= 7 else vane, Vector3(0, 0, 0.12 + side * 0.35))


## 茶叶 and such: a little heap of curled leaves.
func _leaves(data: Dictionary) -> void:
	var colour: String = _c(data, "leaf", "5d6b3a")
	var dark: String = _c(data, "leaf2", "3f4a28")
	var random := RandomNumberGenerator.new()
	random.seed = 31
	for i: int in 26:
		var r: float = random.randf_range(0, 0.3)
		var a: float = random.randf_range(0, TAU)
		var at := Vector3(cos(a) * r, -0.22 + (0.3 - r) * 0.5 + random.randf_range(0, 0.04), sin(a) * r)
		_t(at, Vector3(0.1, 0.025, 0.04), colour if i % 3 else dark, Vector3(random.randf_range(-0.6, 0.6), random.randf_range(0, TAU), random.randf_range(-0.6, 0.6)))
	if data.has("paper"):
		_b(Vector3(0, -0.27, 0), Vector3(0.7, 0.02, 0.7), String(data["paper"]))


## 棋子: two small stacks of round stones, black and white, a few loose.
func _chess(data: Dictionary) -> void:
	var colours: Array[String] = [_c(data, "black", "2a2a2e:gloss"), _c(data, "white", "efece4:gloss")]
	for stack: int in 2:
		for i: int in 5:
			var at := Vector3(-0.14 + stack * 0.28, -0.25 + i * 0.05, 0)
			_b(at, Vector3(0.2, 0.045, 0.2), colours[stack])
			_t(at, Vector3(0.2, 0.045, 0.2), colours[stack], Vector3(0, PI / 4, 0))
	for i: int in 3:
		_t(Vector3(-0.1 + i * 0.12, -0.27, 0.22), Vector3(0.18, 0.04, 0.18), colours[i % 2], Vector3(0, i * 0.4, 0))


## 肉: a roast drumstick, a leg on the bone or a slab of roast.
func _meat(data: Dictionary) -> void:
	var meat: String = _c(data, "meat", "9c5530")
	var crust: String = _c(data, "crust", "6e3518")
	var bone: String = _c(data, "bone", "ece2c8")
	match String(data.get("style", "drumstick")):
		"leg":
			_b(Vector3(0, 0.12, 0), Vector3(0.36, 0.46, 0.3), meat)
			_b(Vector3(0, 0.18, 0), Vector3(0.3, 0.32, 0.34), crust)
			_b(Vector3(0, -0.2, 0), Vector3(0.24, 0.2, 0.22), meat)
			_b(Vector3(0, -0.38, 0), Vector3(0.08, 0.2, 0.08), bone)
			_b(Vector3(0, -0.48, 0), Vector3(0.14, 0.06, 0.12), bone)
		"roast":
			_b(Vector3(0, -0.05, 0), Vector3(0.62, 0.3, 0.42), meat)
			_b(Vector3(0, 0.06, 0), Vector3(0.58, 0.12, 0.38), crust)
			for i: int in 3:
				_b(Vector3(-0.18 + i * 0.18, 0.13, 0), Vector3(0.04, 0.03, 0.4), _c(data, "score", "3e1d0c"))
			_b(Vector3(0.36, -0.05, 0), Vector3(0.12, 0.08, 0.08), bone)
		_:
			_b(Vector3(0, 0.12, 0), Vector3(0.3, 0.38, 0.28), meat)
			_t(Vector3(0, 0.16, 0), Vector3(0.26, 0.3, 0.3), crust, Vector3(0, PI / 4, 0))
			_b(Vector3(0, -0.2, 0), Vector3(0.07, 0.3, 0.07), bone)
			_b(Vector3(0, -0.37, 0), Vector3(0.13, 0.06, 0.1), bone)
