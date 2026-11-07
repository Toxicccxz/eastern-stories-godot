extends RefCounted

## Everything else the 背包 shows (owner, 2026-11-04): food and drink, coins and ingots,
## books, letters, tokens, seals, keys, boxes and pouches, medicine, plants and odds and
## ends. Drawn about the origin; the item view frames and turns them. Colours and styles
## come from the item's look (game/data/common/item_looks.json).
const Shapes = preload("res://presentation/voxel/props/voxel_shapes.gd")
var s: Shapes
var root: Node3D


func draw(shapes: Shapes, parent: Node3D, data: Dictionary) -> bool:
	s = shapes
	root = parent
	match String(data["kind"]):
		"bun":
			_bun(data)
		"flatbread":
			_flatbread(data)
		"skewer":
			_skewer(data)
		"cake":
			_cake(data)
		"tuber":
			_tuber(data)
		"fish":
			_fish(data)
		"dish":
			_dish(data)
		"dumplings":
			_dumplings(data)
		"duck":
			_duck(data)
		"melon":
			_melon(data)
		"wineskin":
			_wineskin(data)
		"jar":
			_jar(data)
		"teapot":
			_teapot(data)
		"cup":
			_cup(data)
		"bell":
			_bell(data)
		"gourd":
			_gourd(data)
		"coins":
			_coins(data)
		"ingot":
			_ingot(data)
		"book":
			_book(data)
		"scroll":
			_scroll(data)
		"letter":
			_letter(data)
		"token":
			_token(data)
		"seal":
			_seal(data)
		"key":
			_key(data)
		"box":
			_box(data)
		"pouch":
			_pouch(data)
		"pill":
			_pill(data)
		"bottle":
			_bottle(data)
		"packet":
			_packet(data)
		"plant":
			_plant(data)
		"flower":
			_flower(data)
		"rope":
			_rope(data)
		"cloth_strip":
			_cloth_strip(data)
		"paper":
			_paper(data)
		"pipe":
			_pipe(data)
		"dragonfly":
			_dragonfly(data)
		"jade":
			_jade(data)
		"tube":
			_tube(data)
		"bamboo":
			_bamboo(data)
		"parcel":
			_parcel(data)
		_:
			return false
	return true


func _c(data: Dictionary, key: String, fallback: String) -> String:
	return String(data.get(key, fallback))


func _b(at: Vector3, size: Vector3, hex: String) -> void:
	s.box(root, at, size, hex)


func _t(at: Vector3, size: Vector3, hex: String, angles: Vector3) -> void:
	s.tilted_box(root, at, size, hex, angles)


## A round-ish lump: a box and the same turned 45°, a smaller one on top.
func _lump(at: Vector3, size: Vector3, hex: String, top: String = "") -> void:
	_b(at, size, hex)
	_t(at, Vector3(size.x * 0.86, size.y * 0.94, size.z * 0.86), hex, Vector3(0, PI / 4, 0))
	_b(at + Vector3(0, size.y * 0.42, 0), Vector3(size.x * 0.62, size.y * 0.3, size.z * 0.62), hex if top.is_empty() else top)


## 包子, 馒头, 红龟: a few round buns on a little plate or leaf.
func _bun(data: Dictionary) -> void:
	var dough: String = _c(data, "dough", "f1e6cc")
	var count: int = int(data.get("count", 3))
	_b(Vector3(0, -0.2, 0), Vector3(0.7, 0.04, 0.6), _c(data, "under", "6f8f4a"))
	for i: int in count:
		var a: float = i * TAU / count + 0.4
		var at := Vector3(cos(a) * 0.15, -0.08, sin(a) * 0.13) if count > 1 else Vector3(0, -0.08, 0)
		_lump(at, Vector3(0.24, 0.18, 0.24), dough, _c(data, "top", dough))
		if data.has("mark"):
			_b(at + Vector3(0, 0.11, 0), Vector3(0.05, 0.02, 0.05), String(data["mark"]))


## 饼: a round flatbread, a wedge cut out, sesame on top.
func _flatbread(data: Dictionary) -> void:
	var crust: String = _c(data, "crust", "c98f45")
	for angle: float in [0.0, PI / 4]:
		_t(Vector3(0, -0.05, 0), Vector3(0.7, 0.1, 0.7), crust, Vector3(0, angle, 0))
	_b(Vector3(0, 0.005, 0), Vector3(0.5, 0.03, 0.5), _c(data, "top", "dba95e"))
	for i: int in 9:
		_b(Vector3(-0.2 + (i % 3) * 0.2, 0.03, -0.2 + floori(i / 3.0) * 0.2), Vector3(0.025, 0.015, 0.04), "f4ecd6")


## 糖葫芦: a stick of glazed red fruits.
func _skewer(data: Dictionary) -> void:
	_b(Vector3(0, -0.05, 0), Vector3(0.025, 1.0, 0.025), _c(data, "stick", "c9a35e"))
	var count: int = int(data.get("count", 5))
	for i: int in count:
		_lump(Vector3(0, 0.38 - i * 0.15, 0), Vector3(0.15, 0.13, 0.15), _c(data, "fruit", "c22a2a:gloss"))


## 糕: a stack of square cakes, a little decoration on top.
func _cake(data: Dictionary) -> void:
	var main: String = _c(data, "color", "f2efe6")
	for i: int in int(data.get("count", 3)):
		var at := Vector3(-0.12 + (i % 2) * 0.24, -0.15 + floori(i / 2.0) * 0.16, (i % 2) * 0.05)
		_b(at, Vector3(0.24, 0.14, 0.24), main)
		_b(at + Vector3(0, 0.075, 0), Vector3(0.1, 0.02, 0.1), _c(data, "top", "e8a0b4"))
	_b(Vector3(0, -0.24, 0.02), Vector3(0.66, 0.03, 0.5), _c(data, "under", "b9a27a"))


## 山药蛋: a couple of knobbly tubers.
func _tuber(data: Dictionary) -> void:
	var skin: String = _c(data, "skin", "a07a4c")
	_lump(Vector3(-0.1, -0.1, 0), Vector3(0.3, 0.22, 0.24), skin)
	_lump(Vector3(0.16, -0.14, 0.08), Vector3(0.22, 0.16, 0.2), skin)
	for spot: Vector3 in [Vector3(-0.15, 0.0, 0.12), Vector3(0.05, -0.05, 0.1), Vector3(0.2, -0.08, 0.17)]:
		_b(spot, Vector3(0.03, 0.03, 0.02), "6e5233")


## 鱼: a fish on a plate, sauce over it.
func _fish(data: Dictionary) -> void:
	_t(Vector3(0, -0.22, 0), Vector3(0.9, 0.04, 0.5), _c(data, "plate", "e6e9ea"), Vector3(0, 0, 0))
	_t(Vector3(0, -0.21, 0), Vector3(0.8, 0.03, 0.4), _c(data, "plate_rim", "4f7fa0"), Vector3(0, 0, 0))
	var body: String = _c(data, "body", "b88a52")
	_b(Vector3(-0.04, -0.13, 0), Vector3(0.5, 0.13, 0.18), body)
	_b(Vector3(0.24, -0.13, 0), Vector3(0.12, 0.1, 0.14), body)
	_t(Vector3(-0.34, -0.13, 0), Vector3(0.14, 0.16, 0.04), body, Vector3(0, 0, PI / 4))
	_b(Vector3(0.0, -0.06, 0), Vector3(0.4, 0.03, 0.16), _c(data, "sauce", "7a2f1a:gloss"))
	_b(Vector3(0.27, -0.1, 0.07), Vector3(0.03, 0.03, 0.02), "1d1612")


## A dish in a bowl or on a plate: chunks of the food, a garnish.
func _dish(data: Dictionary) -> void:
	var vessel: String = _c(data, "vessel", "e6e2d6")
	if String(data.get("style", "bowl")) == "plate":
		_b(Vector3(0, -0.2, 0), Vector3(0.8, 0.04, 0.8), vessel)
		_b(Vector3(0, -0.19, 0), Vector3(0.66, 0.03, 0.66), _c(data, "rim", "4f7fa0"))
	else:
		_b(Vector3(0, -0.2, 0), Vector3(0.36, 0.06, 0.36), vessel)
		_b(Vector3(0, -0.1, 0), Vector3(0.56, 0.16, 0.56), vessel)
		_b(Vector3(0, -0.01, 0), Vector3(0.62, 0.04, 0.62), _c(data, "rim", "4f7fa0"))
	var random := RandomNumberGenerator.new()
	random.seed = int(data.get("seed", 3))
	var food: String = _c(data, "food", "9c5530")
	var food2: String = _c(data, "food2", food)
	for i: int in 12:
		_t(Vector3(random.randf_range(-0.2, 0.2), -0.02 + random.randf_range(0, 0.1), random.randf_range(-0.2, 0.2)), Vector3(0.1, 0.07, 0.09), food if i % 3 else food2, Vector3(0, random.randf_range(0, TAU), 0))
	if data.has("garnish"):
		for i: int in 5:
			_b(Vector3(random.randf_range(-0.18, 0.18), 0.08, random.randf_range(-0.18, 0.18)), Vector3(0.04, 0.03, 0.04), String(data["garnish"]))


## 水饺: dumplings on a plate.
func _dumplings(data: Dictionary) -> void:
	_b(Vector3(0, -0.2, 0), Vector3(0.8, 0.04, 0.8), _c(data, "plate", "e6e9ea"))
	var skin: String = _c(data, "skin", "f4ecd6")
	for i: int in 6:
		var a: float = i * TAU / 6
		var at := Vector3(cos(a) * 0.22, -0.13, sin(a) * 0.22)
		_t(at, Vector3(0.2, 0.1, 0.12), skin, Vector3(0, -a, 0))
		_t(at + Vector3(0, 0.05, 0), Vector3(0.16, 0.04, 0.05), skin, Vector3(0, -a, 0))


## 烤鸭: a glazed roast duck.
func _duck(data: Dictionary) -> void:
	var skin: String = _c(data, "skin", "a14a1e:gloss")
	_b(Vector3(0, -0.22, 0), Vector3(0.9, 0.04, 0.6), _c(data, "plate", "e6e9ea"))
	_b(Vector3(0, -0.06, 0), Vector3(0.5, 0.26, 0.34), skin)
	_b(Vector3(0, 0.08, 0), Vector3(0.38, 0.08, 0.26), skin)
	_b(Vector3(0.32, -0.02, 0), Vector3(0.16, 0.12, 0.12), skin)
	_b(Vector3(0.43, 0.02, 0), Vector3(0.08, 0.06, 0.06), "e3a23b")
	for side: float in [-1.0, 1.0]:
		_b(Vector3(-0.22, -0.14, side * 0.16), Vector3(0.14, 0.08, 0.08), skin)


## 西瓜: a whole melon with a slice beside it.
func _melon(data: Dictionary) -> void:
	var rind: String = _c(data, "rind", "3f7a3a")
	_lump(Vector3(-0.1, -0.08, 0), Vector3(0.46, 0.38, 0.4), rind)
	for i: int in 5:
		_b(Vector3(-0.1, -0.08, -0.16 + i * 0.08), Vector3(0.47, 0.3, 0.025), _c(data, "stripe", "2a5a28"))
	_t(Vector3(0.28, -0.18, 0.12), Vector3(0.28, 0.16, 0.06), _c(data, "flesh", "e0443a"), Vector3(0, 0.4, 0))
	_t(Vector3(0.28, -0.25, 0.12), Vector3(0.3, 0.03, 0.07), rind, Vector3(0, 0.4, 0))


## 酒袋: a soft leather bag with a neck and stopper, a strap round it.
func _wineskin(data: Dictionary) -> void:
	var leather: String = _c(data, "leather", "8a5a35")
	_lump(Vector3(0, -0.1, 0), Vector3(0.44, 0.42, 0.24), leather)
	_b(Vector3(0, 0.18, 0), Vector3(0.12, 0.14, 0.12), leather)
	_b(Vector3(0, 0.28, 0), Vector3(0.1, 0.06, 0.1), _c(data, "stopper", "c9a35e"))
	_t(Vector3(0.0, 0.05, 0.13), Vector3(0.5, 0.03, 0.02), _c(data, "strap", "4b3a2c"), Vector3(0, 0, 0.5))
	if data.has("mark"):
		_b(Vector3(0, -0.1, 0.13), Vector3(0.12, 0.12, 0.01), String(data["mark"]))


## 酒坛: a glazed jar, its mouth tied over with cloth, a red paper label.
func _jar(data: Dictionary) -> void:
	var clay: String = _c(data, "clay", "6b4030:gloss")
	_b(Vector3(0, -0.28, 0), Vector3(0.3, 0.06, 0.3), clay)
	_lump(Vector3(0, -0.08, 0), Vector3(0.48, 0.4, 0.48), clay)
	_b(Vector3(0, 0.17, 0), Vector3(0.22, 0.08, 0.22), clay)
	_b(Vector3(0, 0.24, 0), Vector3(0.3, 0.07, 0.3), _c(data, "cloth", "b0452f"))
	_b(Vector3(0, 0.28, 0), Vector3(0.18, 0.04, 0.18), _c(data, "cloth", "b0452f"))
	_b(Vector3(0, -0.05, 0.26), Vector3(0.16, 0.2, 0.01), _c(data, "label", "d63a2c"))
	_b(Vector3(0, -0.05, 0.265), Vector3(0.05, 0.13, 0.01), "1d1612")


## 壶: a squat teapot with spout and handle.
func _teapot(data: Dictionary) -> void:
	var clay: String = _c(data, "clay", "8a4a30")
	_lump(Vector3(0, -0.1, 0), Vector3(0.42, 0.3, 0.42), clay)
	_b(Vector3(0, 0.09, 0), Vector3(0.2, 0.05, 0.2), clay)
	_b(Vector3(0, 0.13, 0), Vector3(0.06, 0.05, 0.06), _c(data, "knob", clay))
	_t(Vector3(0.28, -0.04, 0), Vector3(0.18, 0.06, 0.06), clay, Vector3(0, 0, 0.6))
	for y: float in [0.02, -0.18]:
		_b(Vector3(-0.27, y, 0), Vector3(0.06, 0.05, 0.05), clay)
	_b(Vector3(-0.31, -0.08, 0), Vector3(0.05, 0.22, 0.05), clay)


## 杯: a cup, maybe on a saucer.
func _cup(data: Dictionary) -> void:
	var glaze: String = _c(data, "glaze", "dfe8e0:gloss")
	_b(Vector3(0, -0.24, 0), Vector3(0.5, 0.03, 0.5), _c(data, "saucer", glaze))
	_b(Vector3(0, -0.2, 0), Vector3(0.18, 0.05, 0.18), glaze)
	_b(Vector3(0, -0.06, 0), Vector3(0.3, 0.24, 0.3), glaze)
	_b(Vector3(0, 0.07, 0), Vector3(0.34, 0.03, 0.34), _c(data, "rim", "4f7fa0"))
	_b(Vector3(0, 0.0, 0.155), Vector3(0.1, 0.06, 0.01), _c(data, "pattern", "4f7fa0"))


## 铃: a small hand bell (第十章 A: 萧辟尘's wind bell) — a flared bronze body, its tongue below,
## a knotted cord above.
func _bell(data: Dictionary) -> void:
	var metal: String = _c(data, "metal", "6a8a6a:gloss")
	_b(Vector3(0, -0.2, 0), Vector3(0.36, 0.06, 0.36), metal)
	_b(Vector3(0, -0.08, 0), Vector3(0.3, 0.18, 0.3), metal)
	_b(Vector3(0, 0.05, 0), Vector3(0.2, 0.1, 0.2), metal)
	_b(Vector3(0, 0.12, 0), Vector3(0.08, 0.05, 0.08), _c(data, "crown", metal))
	_b(Vector3(0, -0.27, 0), Vector3(0.06, 0.08, 0.06), _c(data, "tongue", "c8b070:gloss"))
	_b(Vector3(0, 0.22, 0), Vector3(0.04, 0.16, 0.04), _c(data, "cord", "d8907a"))
	_b(Vector3(0, 0.31, 0), Vector3(0.1, 0.05, 0.05), _c(data, "cord", "d8907a"))


## 葫芦: a double gourd with a stopper and a cord.
func _gourd(data: Dictionary) -> void:
	var skin: String = _c(data, "skin", "c99a4a")
	_lump(Vector3(0, -0.18, 0), Vector3(0.36, 0.3, 0.36), skin)
	_lump(Vector3(0, 0.1, 0), Vector3(0.24, 0.2, 0.24), skin)
	_b(Vector3(0, 0.25, 0), Vector3(0.06, 0.08, 0.06), _c(data, "stopper", "6b4a2e"))
	_b(Vector3(0, -0.02, 0), Vector3(0.18, 0.04, 0.18), _c(data, "cord", "b0452f"))


## 钱: strings of copper cash and a few loose coins, each with its square hole.
func _coins(data: Dictionary) -> void:
	var copper: String = _c(data, "metal", "b07a3a:gloss")
	for stack: int in 3:
		var at := Vector3(-0.2 + stack * 0.2, -0.24, (stack % 2) * 0.1)
		for i: int in 3 + stack:
			_coin(at + Vector3(0, i * 0.045, 0), copper)
	_t(Vector3(0.05, -0.05, 0.2), Vector3(0.6, 0.02, 0.02), _c(data, "string", "b0452f"), Vector3(0, 0, 0.3))


func _coin(at: Vector3, metal: String) -> void:
	for angle: float in [0.0, PI / 4]:
		_t(at, Vector3(0.17, 0.04, 0.17), metal, Vector3(0, angle, 0))
	_b(at + Vector3(0, 0.021, 0), Vector3(0.05, 0.004, 0.05), "2e2119")


## 银锭, 金锭: boat-shaped ingots, raised ends and a round middle.
func _ingot(data: Dictionary) -> void:
	var metal: String = _c(data, "metal", "d6dcdf:gloss")
	var count: int = int(data.get("count", 2))
	for i: int in count:
		var at := Vector3(-0.16 + i * 0.32, -0.15 + (i % 2) * 0.02, (i % 2) * 0.12) if count > 1 else Vector3(0, -0.1, 0)
		_b(at, Vector3(0.34, 0.1, 0.2), metal)
		for side: float in [-1.0, 1.0]:
			_t(at + Vector3(side * 0.15, 0.08, 0), Vector3(0.1, 0.12, 0.2), metal, Vector3(0, 0, side * 0.45))
		_lump(at + Vector3(0, 0.08, 0), Vector3(0.14, 0.12, 0.13), metal)


## 书: a thread-bound book, its title strip, the stitching down the spine; `thick` stacks it.
func _book(data: Dictionary) -> void:
	var cover: String = _c(data, "cover", "4e6967")
	var thick: float = float(data.get("thick", 0.1))
	_t(Vector3.ZERO, Vector3(0.52, 0.7, thick), cover, Vector3(0, 0, 0))
	_b(Vector3(0.0, 0.0, 0), Vector3(0.5, 0.68, thick + 0.012), _c(data, "pages", "e9dfc4"))
	_b(Vector3(0.012, 0.0, 0), Vector3(0.5, 0.7, thick), cover)
	_b(Vector3(0.12, 0.12, thick / 2 + 0.005), Vector3(0.12, 0.4, 0.01), _c(data, "label", "efe6d0"))
	for i: int in 3:
		_b(Vector3(0.13, 0.22 - i * 0.1, thick / 2 + 0.011), Vector3(0.06, 0.02, 0.004), "2e2119")
	for i: int in 4:
		_b(Vector3(-0.22, -0.27 + i * 0.18, 0), Vector3(0.025, 0.025, thick + 0.02), _c(data, "thread", "d8bf7a"))
	if data.has("stack"):
		_t(Vector3(-0.03, -0.02, -thick), Vector3(0.5, 0.68, thick), String(data["stack"]), Vector3(0, 0, 0.06))


## 卷轴, 残卷: a rolled scroll on its rod, a ribbon round it; `open` shows a length unrolled.
func _scroll(data: Dictionary) -> void:
	var paper: String = _c(data, "paper", "e6d6ae")
	var rod: String = _c(data, "rod", "5a3a28")
	if data.get("open", false):
		_b(Vector3(0, 0, 0), Vector3(0.7, 0.5, 0.02), paper)
		for i: int in 5:
			_b(Vector3(0.24 - i * 0.12, 0.02, 0.012), Vector3(0.025, 0.36, 0.004), _c(data, "ink", "2e2119"))
		_b(Vector3(-0.38, 0, 0), Vector3(0.1, 0.56, 0.1), paper)
		_b(Vector3(-0.38, 0, 0), Vector3(0.05, 0.66, 0.05), rod)
		return
	_t(Vector3.ZERO, Vector3(0.16, 0.8, 0.16), paper, Vector3(0, 0, 0))
	_t(Vector3.ZERO, Vector3(0.14, 0.82, 0.14), paper, Vector3(0, PI / 4, 0))
	for end: float in [-1.0, 1.0]:
		_b(Vector3(0, end * 0.44, 0), Vector3(0.07, 0.08, 0.07), rod)
	_b(Vector3(0, 0.0, 0), Vector3(0.18, 0.05, 0.18), _c(data, "ribbon", "b0452f"))
	if data.has("torn"):
		_b(Vector3(0.0, -0.36, 0.08), Vector3(0.14, 0.08, 0.02), String(data["torn"]))


## 信: a folded letter in its envelope, sealed with wax; `bundle` lays papers under it.
func _letter(data: Dictionary) -> void:
	var paper: String = _c(data, "paper", "e9dcb8")
	if data.has("bundle"):
		for i: int in 3:
			_t(Vector3(0.02 * i, -0.02 * i, -0.03 - i * 0.02), Vector3(0.66, 0.42, 0.015), String(data["bundle"]), Vector3(0, 0, -0.08 + i * 0.07))
	_b(Vector3.ZERO, Vector3(0.66, 0.4, 0.03), paper)
	_t(Vector3(-0.14, 0.08, 0.018), Vector3(0.42, 0.012, 0.004), _c(data, "fold", "c9b88e"), Vector3(0, 0, -0.42))
	_t(Vector3(0.14, 0.08, 0.018), Vector3(0.42, 0.012, 0.004), _c(data, "fold", "c9b88e"), Vector3(0, 0, 0.42))
	_b(Vector3(0, -0.02, 0.025), Vector3(0.1, 0.1, 0.02), _c(data, "seal", "a3301f:gloss"))
	_b(Vector3(0.18, -0.08, 0.017), Vector3(0.04, 0.2, 0.004), _c(data, "ink", "2e2119"))


## 令牌, 腰牌: a plaque with a rounded top, an emblem and a cord with its tassel.
func _token(data: Dictionary) -> void:
	var main: String = _c(data, "color", "3a2a20")
	_b(Vector3(0, -0.05, 0), Vector3(0.36, 0.5, 0.06), main)
	_b(Vector3(0, 0.22, 0), Vector3(0.28, 0.06, 0.06), main)
	_b(Vector3(0, 0.26, 0), Vector3(0.16, 0.04, 0.06), main)
	_b(Vector3(0, -0.05, 0.035), Vector3(0.26, 0.4, 0.01), _c(data, "border", "a88447"))
	_b(Vector3(0, -0.05, 0.04), Vector3(0.22, 0.36, 0.01), main)
	_b(Vector3(0, -0.02, 0.046), Vector3(0.12, 0.12, 0.01), _c(data, "emblem", "c0392b"))
	_b(Vector3(0, 0.33, 0), Vector3(0.025, 0.08, 0.025), _c(data, "cord", "c0392b"))
	if data.has("tassel"):
		_b(Vector3(0, -0.34, 0), Vector3(0.05, 0.06, 0.05), String(data["tassel"]))
		_b(Vector3(0, -0.42, 0), Vector3(0.04, 0.12, 0.04), String(data["tassel"]))


## 印: a square seal with its carved knob, red paste on the face; `mould` makes it a flat
## clay block with the face pressed in.
func _seal(data: Dictionary) -> void:
	var stone: String = _c(data, "stone", "c9a35e:gloss")
	if data.get("mould", false):
		_b(Vector3(0, -0.05, 0), Vector3(0.5, 0.16, 0.42), stone)
		_b(Vector3(0, 0.035, 0), Vector3(0.32, 0.01, 0.3), _c(data, "face", "b0452f"))
		for i: int in 5:
			_b(Vector3(-0.1 + i * 0.05, 0.042, 0.0), Vector3(0.02, 0.006, 0.18), "6b1c12")
		return
	_b(Vector3(0, -0.15, 0), Vector3(0.34, 0.3, 0.34), stone)
	_b(Vector3(0, -0.31, 0), Vector3(0.35, 0.03, 0.35), _c(data, "face", "b0452f"))
	_lump(Vector3(0, 0.08, 0), Vector3(0.2, 0.16, 0.2), _c(data, "knob", stone))
	if data.has("cord"):
		_t(Vector3(0.12, 0.05, 0.1), Vector3(0.03, 0.3, 0.03), String(data["cord"]), Vector3(0.3, 0, 0.6))


## 钥匙: a long iron key, its bit and a cloth tied to the bow.
func _key(data: Dictionary) -> void:
	var iron: String = _c(data, "metal", "3d3f42:gloss")
	_b(Vector3(0, -0.05, 0), Vector3(0.05, 0.7, 0.05), iron)
	for corner: Vector2 in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
		_b(Vector3(corner.x * 0.08, 0.38 + corner.y * 0.08, 0), Vector3(0.04 if corner.x != 0 else 0.2, 0.2 if corner.x != 0 else 0.04, 0.05), iron)
	_b(Vector3(0.07, -0.34, 0), Vector3(0.1, 0.05, 0.05), iron)
	_b(Vector3(0.07, -0.26, 0), Vector3(0.08, 0.04, 0.05), iron)
	if data.has("tag"):
		_t(Vector3(0.12, 0.42, 0.02), Vector3(0.06, 0.24, 0.02), String(data["tag"]), Vector3(0, 0, 0.5))


## 箱, 匣: a box with its lid, bands and a lock plate; `style` stone (carved), case (books).
func _box(data: Dictionary) -> void:
	var main: String = _c(data, "color", "8a5a35")
	var trim: String = _c(data, "trim", "a88447")
	match String(data.get("style", "chest")):
		"stone":
			_b(Vector3(0, -0.08, 0), Vector3(0.62, 0.32, 0.36), main)
			_b(Vector3(0, 0.1, 0), Vector3(0.64, 0.04, 0.38), _c(data, "color2", main))
			for i: int in 5:
				_t(Vector3(-0.22 + i * 0.11, -0.08, 0.185), Vector3(0.08, 0.025, 0.01), trim, Vector3(0, 0, 0.6 * (1 if i % 2 else -1)))
		"case":
			_b(Vector3(0, -0.05, 0), Vector3(0.44, 0.56, 0.22), main)
			_b(Vector3(0, 0.25, 0), Vector3(0.46, 0.04, 0.24), trim)
			_b(Vector3(0, -0.05, 0.115), Vector3(0.1, 0.12, 0.01), trim)
		_:
			_b(Vector3(0, -0.12, 0), Vector3(0.62, 0.3, 0.4), main)
			_b(Vector3(0, 0.08, 0), Vector3(0.64, 0.12, 0.42), _c(data, "lid", main))
			for x: float in [-0.22, 0.22]:
				_b(Vector3(x, -0.04, 0), Vector3(0.04, 0.42, 0.43), trim)
			_b(Vector3(0, -0.02, 0.215), Vector3(0.1, 0.12, 0.01), trim)
			if data.has("carving"):
				_b(Vector3(0, -0.14, 0.205), Vector3(0.3, 0.12, 0.01), String(data["carving"]))


## 荷包, 布袋: a soft bag gathered at the neck by a cord; `embroidery` a pair of birds on it.
func _pouch(data: Dictionary) -> void:
	var cloth: String = _c(data, "cloth", "8a7f6a")
	_lump(Vector3(0, -0.12, 0), Vector3(0.44, 0.34, 0.3), cloth)
	_b(Vector3(0, 0.11, 0), Vector3(0.2, 0.08, 0.16), cloth)
	_b(Vector3(0, 0.16, 0), Vector3(0.28, 0.06, 0.2), _c(data, "frill", cloth))
	_b(Vector3(0, 0.09, 0), Vector3(0.24, 0.03, 0.2), _c(data, "cord", "c0392b"))
	_t(Vector3(0.12, 0.0, 0.1), Vector3(0.025, 0.24, 0.025), _c(data, "cord", "c0392b"), Vector3(0, 0, 0.3))
	if data.has("embroidery"):
		for side: float in [-1.0, 1.0]:
			_b(Vector3(side * 0.07, -0.12, 0.17), Vector3(0.08, 0.05, 0.01), String(data["embroidery"]))
			_b(Vector3(side * 0.1, -0.09, 0.17), Vector3(0.03, 0.03, 0.01), String(data["embroidery"]))


## 丹, 药丸: a few glossy pills in a little dish or box.
func _pill(data: Dictionary) -> void:
	_b(Vector3(0, -0.2, 0), Vector3(0.6, 0.06, 0.6), _c(data, "dish", "c9a35e"))
	_b(Vector3(0, -0.15, 0), Vector3(0.5, 0.05, 0.5), _c(data, "dish_in", "8a5a35"))
	var pill: String = _c(data, "pill", "e8b84a:gloss")
	for i: int in int(data.get("count", 3)):
		var a: float = i * 2.1
		_lump(Vector3(cos(a) * 0.1, -0.06, sin(a) * 0.1), Vector3(0.12, 0.1, 0.12), pill)
	if data.has("glow"):
		_b(Vector3(0, 0.02, 0), Vector3(0.06, 0.06, 0.06), String(data["glow"]))


## 药瓶: a small glazed bottle with a cloth-wrapped stopper and a paper label.
func _bottle(data: Dictionary) -> void:
	var glaze: String = _c(data, "glaze", "dfe8e0:gloss")
	_lump(Vector3(0, -0.12, 0), Vector3(0.34, 0.34, 0.34), glaze)
	_b(Vector3(0, 0.12, 0), Vector3(0.12, 0.14, 0.12), glaze)
	_b(Vector3(0, 0.22, 0), Vector3(0.16, 0.08, 0.16), _c(data, "stopper", "b0452f"))
	_b(Vector3(0, -0.1, 0.17), Vector3(0.14, 0.16, 0.01), _c(data, "label", "e6c34a"))


## 药粉, 包: a folded paper packet tied with string.
func _packet(data: Dictionary) -> void:
	var paper: String = _c(data, "paper", "d9c9a0")
	_b(Vector3(0, -0.12, 0), Vector3(0.5, 0.16, 0.4), paper)
	_t(Vector3(0, -0.02, 0), Vector3(0.36, 0.1, 0.42), paper, Vector3(0, 0, PI / 4))
	_b(Vector3(0, -0.04, 0), Vector3(0.52, 0.03, 0.03), _c(data, "string", "8a5a35"))
	_b(Vector3(0, -0.04, 0), Vector3(0.03, 0.2, 0.42), _c(data, "string", "8a5a35"))
	if data.has("label"):
		_b(Vector3(0, -0.12, 0.205), Vector3(0.18, 0.1, 0.01), String(data["label"]))


## 草, 兰: a little plant with its leaves, roots and maybe a bloom; `glow` makes it shine.
func _plant(data: Dictionary) -> void:
	var leaf: String = _c(data, "leaf", "4f8a4a")
	for i: int in 7:
		var a: float = i * TAU / 7
		_t(Vector3(cos(a) * 0.08, 0.0, sin(a) * 0.08), Vector3(0.05, 0.5, 0.02), leaf if i % 2 else _c(data, "leaf2", leaf), Vector3(sin(a) * 0.35, a, cos(a) * 0.35))
	_b(Vector3(0, -0.28, 0), Vector3(0.12, 0.08, 0.12), _c(data, "root", "8a6a3e"))
	for i: int in 3:
		_t(Vector3(-0.04 + i * 0.04, -0.36, 0), Vector3(0.02, 0.14, 0.02), _c(data, "root", "8a6a3e"), Vector3(0, 0, (i - 1) * 0.4))
	if data.has("bloom"):
		for i: int in 3:
			var at := Vector3(-0.08 + i * 0.08, 0.26 + (i % 2) * 0.06, 0.02)
			_b(at, Vector3(0.08, 0.06, 0.08), String(data["bloom"]))
			_b(at + Vector3(0, 0.03, 0), Vector3(0.03, 0.03, 0.03), _c(data, "heart", "f2dc8e"))
	if data.has("glow"):
		_b(Vector3(0, 0.1, 0), Vector3(0.05, 0.05, 0.05), String(data["glow"]))


## 花: one flower on its stem, petals round a heart, two leaves.
func _flower(data: Dictionary) -> void:
	var petal: String = _c(data, "petal", "d84a5a")
	_b(Vector3(0, -0.12, 0), Vector3(0.03, 0.6, 0.03), _c(data, "stem", "3f6a3a"))
	for side: float in [-1.0, 1.0]:
		_t(Vector3(side * 0.08, -0.18 + side * 0.06, 0), Vector3(0.16, 0.05, 0.02), _c(data, "leaf", "4f8a4a"), Vector3(0, 0, side * 0.5))
	var count: int = int(data.get("petals", 6))
	for i: int in count:
		var a: float = i * TAU / count
		_t(Vector3(cos(a) * 0.09, 0.24, sin(a) * 0.09), Vector3(0.12, 0.08, 0.06), petal if i % 2 == 0 else _c(data, "petal2", petal), Vector3(sin(a) * 0.5, -a, cos(a) * 0.5))
	_b(Vector3(0, 0.26, 0), Vector3(0.08, 0.08, 0.08), _c(data, "heart", "f2dc8e"))
	if data.get("bud", false):
		_b(Vector3(0, 0.32, 0), Vector3(0.1, 0.1, 0.1), petal)


## 绳: a coil of rope, an end hanging out.
func _rope(data: Dictionary) -> void:
	var colour: String = _c(data, "color", "a88a5a")
	for turn: int in 3:
		for i: int in 14:
			var a: float = i * TAU / 14
			var r: float = 0.3 - turn * 0.03
			_t(Vector3(cos(a) * r, -0.15 + turn * 0.07, sin(a) * r), Vector3(0.15, 0.07, 0.07), colour if (i + turn) % 2 else _c(data, "color2", colour), Vector3(0, -a + PI / 2, 0))
	_t(Vector3(0.32, -0.3, 0.1), Vector3(0.07, 0.3, 0.07), colour, Vector3(0, 0, 0.3))


## 布条: a torn strip of cloth with a mark scratched on it.
func _cloth_strip(data: Dictionary) -> void:
	var cloth: String = _c(data, "cloth", "b8a07a")
	for i: int in 5:
		_t(Vector3(-0.3 + i * 0.15, 0.02 * sin(i * 1.4), 0), Vector3(0.16, 0.16 - (i % 2) * 0.02, 0.02), cloth, Vector3(0, 0, 0.08 * sin(i * 2.0)))
	if data.has("mark"):
		_b(Vector3(-0.05, 0.0, 0.015), Vector3(0.025, 0.1, 0.006), String(data["mark"]))
		for i: int in 3:
			_b(Vector3(0.05, 0.035 - i * 0.035, 0.015), Vector3(0.08, 0.012, 0.006), String(data["mark"]))
	if data.has("writing"):
		for i: int in 6:
			_b(Vector3(-0.25 + i * 0.1, 0.0, 0.015), Vector3(0.05, 0.08, 0.004), String(data["writing"]))


## 纸, 符纸: a few loose sheets, the top one written on.
func _paper(data: Dictionary) -> void:
	var paper: String = _c(data, "paper", "e6c34a")
	for i: int in 3:
		_t(Vector3(i * 0.02, -0.02 * i, -0.02 * i), Vector3(0.3, 0.7, 0.012), paper, Vector3(0, 0, -0.1 + i * 0.08))
	if data.has("ink"):
		_b(Vector3(0, 0.0, 0.01), Vector3(0.04, 0.5, 0.004), String(data["ink"]))
		_b(Vector3(0, 0.1, 0.01), Vector3(0.16, 0.03, 0.004), String(data["ink"]))


## 竹管, 笛: a length of bamboo with its finger holes and nodes.
func _pipe(data: Dictionary) -> void:
	var bamboo: String = _c(data, "color", "a8a25a")
	_b(Vector3.ZERO, Vector3(0.08, 0.8, 0.08), bamboo)
	for y: float in [-0.3, 0.1]:
		_b(Vector3(0, y, 0), Vector3(0.095, 0.03, 0.095), _c(data, "node", "7a7a3a"))
	for i: int in int(data.get("holes", 3)):
		_b(Vector3(0, 0.18 + i * 0.07, 0.04), Vector3(0.03, 0.03, 0.01), "2e2119")


## 竹蜻蜓: a little propeller on a stick.
func _dragonfly(data: Dictionary) -> void:
	var wood: String = _c(data, "color", "c9a35e")
	_b(Vector3(0, -0.15, 0), Vector3(0.04, 0.6, 0.04), wood)
	for side: float in [-1.0, 1.0]:
		_t(Vector3(side * 0.24, 0.16, 0), Vector3(0.44, 0.03, 0.1), wood, Vector3(side * 0.3, 0, 0))
	_b(Vector3(0, 0.16, 0), Vector3(0.08, 0.06, 0.08), _c(data, "hub", "b0452f"))


## 玉佩: a round jade disc with its hole, carved, on a knotted cord.
func _jade(data: Dictionary) -> void:
	var jade: String = _c(data, "jade", "7fbf9a:gloss")
	for i: int in 12:
		var a: float = i * TAU / 12
		_t(Vector3(cos(a) * 0.17, -0.08 + sin(a) * 0.17, 0), Vector3(0.12, 0.08, 0.05), jade, Vector3(0, 0, a + PI / 2))
	_b(Vector3(0, 0.15, 0), Vector3(0.03, 0.12, 0.03), _c(data, "cord", "c0392b"))
	_b(Vector3(0, 0.23, 0), Vector3(0.07, 0.05, 0.04), _c(data, "cord", "c0392b"))
	_b(Vector3(0, -0.34, 0), Vector3(0.05, 0.08, 0.04), _c(data, "cord", "c0392b"))
	_b(Vector3(0, -0.42, 0), Vector3(0.035, 0.1, 0.03), _c(data, "cord", "c0392b"))
	if data.has("carving"):
		for i: int in 4:
			var a: float = i * TAU / 4 + PI / 4
			_b(Vector3(cos(a) * 0.17, -0.08 + sin(a) * 0.17, 0.03), Vector3(0.03, 0.03, 0.01), String(data["carving"]))


## 火摺: a bamboo tube with its cap, a glowing ember at the open end.
func _tube(data: Dictionary) -> void:
	_b(Vector3.ZERO, Vector3(0.1, 0.6, 0.1), _c(data, "color", "8a6a3e"))
	_b(Vector3(0, -0.22, 0), Vector3(0.11, 0.04, 0.11), _c(data, "band", "4b3a2c"))
	_b(Vector3(0.0, 0.33, 0.0), Vector3(0.12, 0.08, 0.12), _c(data, "cap", "4b3a2c"))
	if data.has("ember"):
		_b(Vector3(0, 0.39, 0), Vector3(0.05, 0.04, 0.05), String(data["ember"]))


## 竹子: a cut length of bamboo, nodes and a few leaves.
func _bamboo(data: Dictionary) -> void:
	var green: String = _c(data, "color", "6f9a4a")
	_b(Vector3.ZERO, Vector3(0.08, 0.95, 0.08), green)
	for y: float in [-0.3, 0.0, 0.3]:
		_b(Vector3(0, y, 0), Vector3(0.095, 0.03, 0.095), _c(data, "node", "4f7a3a"))
	for i: int in 3:
		_t(Vector3(0.1 + i * 0.03, 0.35 - i * 0.08, 0), Vector3(0.22, 0.05, 0.02), _c(data, "leaf", "5f8a3a"), Vector3(0, 0, -0.4 - i * 0.2))


## Anything without a form of its own: a cloth-wrapped parcel tied with string.
func _parcel(data: Dictionary) -> void:
	var cloth: String = _c(data, "color", "a08a6a")
	_b(Vector3(0, -0.1, 0), Vector3(0.5, 0.3, 0.4), cloth)
	_b(Vector3(0, 0.08, 0), Vector3(0.12, 0.1, 0.1), cloth)
	_b(Vector3(0, -0.1, 0), Vector3(0.52, 0.03, 0.03), _c(data, "string", "6b4a33"))
	_b(Vector3(0, -0.1, 0), Vector3(0.03, 0.32, 0.42), _c(data, "string", "6b4a33"))
