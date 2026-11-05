extends Node3D

## A person on the voxel map: about twenty-six flat-coloured boxes. What they wear and carry
## comes from their look (`configure()`; PersonLooks: a card per person, DECISIONS「人物外观」):
## colours of the coat, trousers, skin and hair, the hair's style, headwear, beard, what is round
## the waist, one thing carried, how tall and how broad. Without a key the figure is the town's
## everyday person (the colours and parts every figure had before the cards).

const Shapes = preload("res://presentation/voxel/props/voxel_shapes.gd")
## Leg, torso and head lengths and the body's width by `height` (child: a smaller head too).
const HEIGHTS: Dictionary = {
	"child": {"legs": 0.7, "torso": 0.72, "head": 0.9, "width": 0.82},
	"short": {"legs": 0.92, "torso": 0.93, "head": 1.0, "width": 1.0},
	"standard": {"legs": 1.0, "torso": 1.0, "head": 1.0, "width": 1.0},
	"tall": {"legs": 1.09, "torso": 1.06, "head": 1.0, "width": 1.0},
}
## The torso's width and depth by `build`.
const BUILDS: Dictionary = {
	"slim": {"width": 0.88, "depth": 0.92},
	"standard": {"width": 1.0, "depth": 1.0},
	"heavy": {"width": 1.2, "depth": 1.18},
}
const HAIR_STYLES: Array[String] = ["topknot", "ponytail", "double_bun", "long", "short", "bald"]
const HEADWEAR: Array[String] = ["none", "straw_hat", "cloth_cap", "headscarf", "crown", "official_cap"]
const BEARDS: Array[String] = ["none", "moustache", "chin_three", "full", "long"]
const WAISTS: Array[String] = ["belt", "sash", "apron", "none"]
const PROPS: Array[String] = ["none", "sword_waist", "sword_back", "blade_back", "staff", "spear", "fan", "teapot", "basket_back", "umbrella", "gourd", "book", "lute", "hammer", "axe", "glaive", "whisk"]
## towel_neck: the waiter's cloth round the neck; bracers (护腕) round the wrists; leg_wraps (绑腿)
## round the shins.
const EXTRAS: Array[String] = ["towel_neck", "bracers", "leg_wraps"]

var walking: bool = false
var pace: float = 0.0
var clock: float = 0.0
var torso: Node3D
var arms: Array[Node3D] = []
var legs: Array[Node3D] = []
var eyes: Node3D
var hat: bool = false
## No head (the 无头黑影 of 逆灵宫 C: 侮天鬼 looking for his, doc/help/history:56–58): the
## neck ends in a cut, nothing above it, no eyes.
var headless: bool = false
var coat: String = "397c87"
## A statue (神像, a figure that never moves): every part in shades of this stone or gilt.
var stone: String = ""
## The look's other keys (configure()); coat, hat and headless have their own fields.
var look: Dictionary = {}
## What was drawn beyond the plain body, by name ("apron", "beard:full", "prop:teapot" …): the
## suites read it.
var drawn: PackedStringArray = []

var _s: Shapes
var _legs_k: float = 1.0
var _torso_k: float = 1.0
var _head_k: float = 1.0
var _wide: float = 1.0
var _deep: float = 1.0


## Takes a look (PersonLooks.resolve()): its colours and parts. Before the figure enters the tree.
func configure(data: Dictionary) -> void:
	look = data
	coat = String(data.get("coat", coat))
	hat = bool(data.get("hat", false))
	headless = bool(data.get("headless", false))


func _ready() -> void:
	clock = float(get_index()) * 1.73
	_s = Shapes.new()
	var tall: Dictionary = HEIGHTS.get(_word("height", "standard"), HEIGHTS["standard"])
	var broad: Dictionary = BUILDS.get(_word("build", "standard"), BUILDS["standard"])
	_legs_k = float(tall["legs"])
	_torso_k = float(tall["torso"])
	_head_k = float(tall["head"])
	_wide = float(broad["width"]) * float(tall["width"])
	_deep = float(broad["depth"]) * float(tall["width"])
	var skin: String = _hex("skin", "d7a36c")
	var pants: String = _hex("pants", "344047")
	var waist: String = _word("waist", "belt")
	torso = Node3D.new()
	add_child(torso)
	_box(torso, Vector3(0, 0.91, 0), Vector3(0.55, 0.58, 0.34), coat)
	_box(torso, Vector3(0, 0.6, 0), Vector3(0.62, 0.22, 0.41), coat)
	if waist == "belt":
		_box(torso, Vector3(0, 0.76, 0.015), Vector3(0.57, 0.12, 0.37), _hex("accent", "a34f3c"))
		if look.get("pouch", true) != false:
			_box(torso, Vector3(0.17, 0.6, 0.23), Vector3(0.1, 0.34, 0.07), _hex("pouch_color", "bc6943"))
	elif waist == "sash":
		_box(torso, Vector3(0, 0.75, 0.015), Vector3(0.58, 0.17, 0.38), _hex("accent", "a34f3c"))
		_box(torso, Vector3(-0.15, 0.58, 0.2), Vector3(0.09, 0.26, 0.04), _hex("accent", "a34f3c"))
		drawn.append("sash")
	elif waist == "apron":
		_apron()
	# `collar` false: none (its colour is `collar_color`).
	if look.get("collar", true) != false:
		_box(torso, Vector3(0, 1.14, 0.15), Vector3(0.23, 0.16, 0.08), _hex("collar_color", "e9cfa0"))
		_box(torso, Vector3(-0.08, 1.04, 0.19), Vector3(0.11, 0.12, 0.06), _hex("collar_shade", "d5c49d"))
	if headless:
		_box(torso, Vector3(0, 1.22, 0), Vector3(0.24, 0.1, 0.22), "3a1a2a")
	else:
		_head(skin)
	eyes = Node3D.new()
	torso.add_child(eyes)
	eyes.position = _at(Vector3(0, 1.45, 0.235))
	for x: float in [-0.09, 0.09]:
		if not headless:
			_s.box(eyes, Vector3(x, 0, 0)*_head_k, Vector3(0.055, 0.06, 0.035)*_head_k, _tone("242d30"))
	var extras: Array = look.get("extras", [])
	for side: float in [-1.0, 1.0]:
		var arm := Node3D.new()
		arm.position = Vector3(side*(0.36 + 0.275*(_wide - 1.0)), _y(1.12), 0)
		torso.add_child(arm)
		arms.append(arm)
		var reach: float = _torso_k
		_s.box(arm, Vector3(0, -0.14*reach, 0), Vector3(0.2, 0.34*reach, 0.29*_deep), _tone(coat))
		_s.box(arm, Vector3(0, -0.37*reach, 0.02), Vector3(0.17, 0.16, 0.19), _tone(skin))
		if extras.has("bracers"):
			# Over the sleeve's end, just above the hand.
			_s.box(arm, Vector3(0, -0.25*reach, 0.005), Vector3(0.22, 0.12*reach, 0.3*_deep + 0.02), _tone(_hex("bracer_color", "4a3628")))
		var leg := Node3D.new()
		var hip: float = 0.57*_legs_k
		leg.position = Vector3(side*0.17*maxf(_wide, 0.9), hip, 0)
		add_child(leg)
		legs.append(leg)
		# The shoe stays on the ground; the leg reaches from its top to the hip.
		_s.box(leg, Vector3(0, (0.17 - hip)/2.0, 0), Vector3(0.2, hip - 0.17, 0.23), _tone(pants))
		_s.box(leg, Vector3(0, 0.14 - hip, 0.06), Vector3(0.23, 0.16, 0.35), _tone(_shoes(pants)))
		if extras.has("leg_wraps"):
			# Round the shin from the shoe's top to below the knee.
			_s.box(leg, Vector3(0, 0.17 - hip + 0.11*_legs_k, 0), Vector3(0.22, 0.22*_legs_k, 0.25), _tone(_hex("wrap_color", "5e4a38")))
	_prop()
	if extras.has("towel_neck"):
		_box(torso, Vector3(0.12, 1.14, 0.12), Vector3(0.12, 0.08, 0.3), _hex("towel", "ece6d6"))
		_box(torso, Vector3(0.14, 0.98, 0.21), Vector3(0.1, 0.26, 0.05), _hex("towel", "ece6d6"))
	for extra: String in EXTRAS:
		if extras.has(extra):
			drawn.append(extra)
	_s.flush()


## The head and what is on it: hair, beard, headwear.
func _head(skin: String) -> void:
	var hair: String = _hex("hair", "30323b")
	_box(torso, Vector3(0, 1.42, 0.035), Vector3(0.43, 0.43, 0.38), skin, true)
	_box(torso, Vector3(0, 1.37, 0.25), Vector3(0.08, 0.08, 0.09), "e5b77d" if not look.has("skin") else Color(skin).lightened(0.1).to_html(false), true)
	var style: String = _word("hair_style", "topknot")
	var headwear: String = _word("headwear", "straw_hat" if hat else "none")
	if style != "bald":
		_box(torso, Vector3(0, 1.59, -0.035), Vector3(0.48, 0.18, 0.43), hair, true)
		_box(torso, Vector3(0, 1.4, -0.19), Vector3(0.45, 0.37, 0.1), hair, true)
		_box(torso, Vector3(-0.17, 1.46, 0.17), Vector3(0.1, 0.2, 0.07), hair, true)
		_box(torso, Vector3(0.12, 1.53, 0.21), Vector3(0.14, 0.12, 0.05), hair, true)
	else:
		_box(torso, Vector3(0, 1.6, 0.0), Vector3(0.44, 0.06, 0.36), Color(skin).darkened(0.04).to_html(false), true)
	var covered: bool = headwear in ["cloth_cap", "official_cap", "straw_hat"]
	match style:
		"topknot":
			if not covered:
				_box(torso, Vector3(0, 1.75, -0.08), Vector3(0.2, 0.19, 0.2), hair, true)
				_box(torso, Vector3(0, 1.67, -0.08), Vector3(0.22, 0.06, 0.22), _hex("hair_tie", _hex("accent", "b5573f")), true)
		"ponytail":
			# Tied high at the back of the crown, the tail down the back of the head.
			if not covered:
				_box(torso, Vector3(0, 1.7, -0.17), Vector3(0.16, 0.14, 0.16), hair, true)
				_box(torso, Vector3(0, 1.62, -0.2), Vector3(0.18, 0.05, 0.18), _hex("hair_tie", _hex("accent", "b5573f")), true)
				drawn.append("ponytail_tie")
			_box(torso, Vector3(0, 1.38, -0.27), Vector3(0.13, 0.46, 0.08), hair, true)
			drawn.append("ponytail")
		"double_bun":
			for x: float in [-0.17, 0.17]:
				_box(torso, Vector3(x, 1.72, -0.04), Vector3(0.17, 0.17, 0.17), hair, true)
				_box(torso, Vector3(x, 1.66, -0.04), Vector3(0.19, 0.05, 0.19), _hex("hair_tie", _hex("accent", "b5573f")), true)
			drawn.append("double_bun")
		"long":
			_box(torso, Vector3(0, 1.12, -0.21), Vector3(0.42, 0.5, 0.08), hair, true)
			drawn.append("long_hair")
		"short":
			drawn.append("short_hair")
	var beard: String = _word("beard", "none")
	if beard != "none":
		drawn.append("beard:" + beard)
	match beard:
		"moustache":
			_box(torso, Vector3(0, 1.315, 0.235), Vector3(0.2, 0.04, 0.04), hair, true)
		"chin_three":
			_box(torso, Vector3(0, 1.2, 0.21), Vector3(0.08, 0.16, 0.06), hair, true)
			for x: float in [-0.13, 0.13]:
				_box(torso, Vector3(x, 1.24, 0.2), Vector3(0.05, 0.12, 0.05), hair, true)
		"full":
			_box(torso, Vector3(0, 1.26, 0.2), Vector3(0.43, 0.14, 0.06), hair, true)
			for x: float in [-0.2, 0.2]:
				_box(torso, Vector3(x, 1.34, 0.12), Vector3(0.05, 0.16, 0.14), hair, true)
		"long":
			_box(torso, Vector3(0, 1.16, 0.22), Vector3(0.18, 0.26, 0.06), hair, true)
			_box(torso, Vector3(0, 1.315, 0.235), Vector3(0.22, 0.04, 0.04), hair, true)
	if headwear != "none":
		drawn.append("headwear:" + headwear)
	match headwear:
		"straw_hat":
			var straw: String = _hex("headwear_color", "")
			for layer: int in 4:
				var shade: String = ["ad8147", "b28d50", "bc985d", "caa76b"][layer] if straw.is_empty() else Color(straw).lightened(layer*0.06).to_html(false)
				_box(torso, Vector3(0, 1.7 + layer*0.08, 0), Vector3(1.0 - layer*0.2, 0.08, 0.9 - layer*0.18), shade, true)
		"cloth_cap":
			var cap: String = _hex("headwear_color", "2c2c30")
			_box(torso, Vector3(0, 1.69, -0.02), Vector3(0.5, 0.16, 0.45), cap, true)
			_box(torso, Vector3(0, 1.62, 0.19), Vector3(0.5, 0.06, 0.06), Color(cap).darkened(0.25).to_html(false), true)
		"headscarf":
			var cloth: String = _hex("headwear_color", _hex("accent", "6a5a8a"))
			_box(torso, Vector3(0, 1.6, -0.01), Vector3(0.5, 0.1, 0.45), cloth, true)
			_box(torso, Vector3(0, 1.66, -0.24), Vector3(0.14, 0.12, 0.08), cloth, true)
			_box(torso, Vector3(0.05, 1.5, -0.27), Vector3(0.06, 0.18, 0.04), cloth, true)
		"crown":
			_box(torso, Vector3(0, 1.75, -0.08), Vector3(0.2, 0.19, 0.2), hair, true)
			_box(torso, Vector3(0, 1.8, -0.08), Vector3(0.16, 0.12, 0.24), _hex("headwear_color", "7fb39a"), true)
			_box(torso, Vector3(0, 1.79, -0.08), Vector3(0.3, 0.03, 0.03), "d8c48a", true)
		"official_cap":
			var black: String = _hex("headwear_color", "1e1e24")
			_box(torso, Vector3(0, 1.71, -0.03), Vector3(0.5, 0.2, 0.46), black, true)
			_box(torso, Vector3(0, 1.79, -0.2), Vector3(0.3, 0.16, 0.12), black, true)
			for x: float in [-0.42, 0.42]:
				_box(torso, Vector3(x, 1.72, -0.12), Vector3(0.36, 0.04, 0.1), black, true)


## Over the coat from the chest to the knees, its strings round the neck and the waist.
func _apron() -> void:
	var cloth: String = _hex("apron_color", "667d84")
	_box(torso, Vector3(0, 0.66, 0.225), Vector3(0.52, 0.56, 0.04), cloth)
	_box(torso, Vector3(0, 0.36, 0.235), Vector3(0.5, 0.06, 0.04), cloth)
	_box(torso, Vector3(0, 0.98, 0.19), Vector3(0.36, 0.14, 0.04), cloth)
	_box(torso, Vector3(0, 0.78, 0.0), Vector3(0.58, 0.05, 0.38), _hex("accent", Color(cloth).darkened(0.3).to_html(false)))
	drawn.append("apron")


## The one thing carried: in the right hand (arms[0], the figure's right), at the left hip or on
## the back.
func _prop() -> void:
	var prop: String = _word("prop", "none")
	if prop == "none":
		return
	drawn.append("prop:" + prop)
	var hand: Node3D = arms[0]
	var grip := Vector3(0, -0.45*_torso_k, 0.04)
	var metal: String = _hex("metal", "b9a26a")
	var wood: String = _hex("wood", "6b4a30")
	var tassel: String = _hex("tassel_color", _hex("accent", "a8322a"))
	match prop:
		"sword_waist":
			# From the belt at the left hip, the hilt forward and up, the tip back and down.
			var sheath: String = _hex("prop_color", "3a2a22")
			var centre := Vector3(0.3, 0.56, 0.1)
			var along := Vector3(0, cos(0.5), sin(0.5))
			_tilted(torso, centre, Vector3(0.06, 0.82, 0.07), sheath, Vector3(0.5, 0, 0))
			_tilted(torso, centre + along*0.43, Vector3(0.14, 0.04, 0.08), metal, Vector3(0.5, 0, 0))
			_tilted(torso, centre + along*0.55, Vector3(0.05, 0.18, 0.05), wood, Vector3(0.5, 0, 0))
			_box(torso, centre + along*0.6 + Vector3(0, -0.1, 0.03), Vector3(0.04, 0.14, 0.04), tassel)
		"sword_back", "blade_back":
			# Across the back, the hilt over the right shoulder.
			var sheath: String = _hex("prop_color", "3a2a22")
			var long: float = 0.86 if prop == "sword_back" else 0.74
			var wide: float = 0.07 if prop == "sword_back" else 0.11
			var centre := Vector3(0, 1.02, -0.22)
			var along := Vector3(-sin(0.72), cos(0.72), 0)
			_tilted(torso, centre, Vector3(wide, long, 0.06), sheath, Vector3(0, 0, 0.72))
			_tilted(torso, centre + along*(long/2.0 + 0.02), Vector3(0.14, 0.04, 0.07), metal, Vector3(0, 0, 0.72))
			_tilted(torso, centre + along*(long/2.0 + 0.12), Vector3(0.05, 0.18, 0.05), wood, Vector3(0, 0, 0.72))
		"staff", "spear":
			_held(hand, grip + Vector3(0, 0.35, 0), Vector3(0.05, 1.7, 0.05), _hex("prop_color", wood))
			if prop == "spear":
				_held(hand, grip + Vector3(0, 1.28, 0), Vector3(0.07, 0.2, 0.04), _hex("metal", "c2c6c8"))
				_held(hand, grip + Vector3(0, 1.16, 0), Vector3(0.09, 0.05, 0.09), tassel)
		"fan":
			_held(hand, grip + Vector3(0, 0.02, 0.1), Vector3(0.05, 0.22, 0.04), _hex("prop_color", "e8dcc0"))
		"teapot":
			var copper: String = _hex("prop_color", "b8663a")
			_held(hand, grip + Vector3(0, -0.13, 0.05), Vector3(0.22, 0.16, 0.2), copper)
			_held(hand, grip + Vector3(0, -0.04, 0.05), Vector3(0.12, 0.04, 0.12), Color(copper).darkened(0.2).to_html(false))
			_held_tilted(hand, grip + Vector3(0, -0.1, 0.19), Vector3(0.04, 0.04, 0.12), copper, Vector3(-0.6, 0, 0))
			_held(hand, grip + Vector3(0, 0.0, 0.05), Vector3(0.03, 0.08, 0.14), Color(copper).darkened(0.35).to_html(false))
		"basket_back":
			_box(torso, Vector3(0, 0.98, -0.3), Vector3(0.42, 0.46, 0.24), _hex("prop_color", "a8834e"))
			_box(torso, Vector3(0, 1.22, -0.3), Vector3(0.44, 0.04, 0.26), Color(_hex("prop_color", "a8834e")).darkened(0.2).to_html(false))
		"umbrella":
			_held(hand, grip + Vector3(0, 0.3, 0.02), Vector3(0.04, 0.7, 0.04), wood)
			_held(hand, grip + Vector3(0, 0.7, 0.02), Vector3(0.12, 0.2, 0.12), _hex("prop_color", "b8a070"))
		"gourd":
			_box(torso, Vector3(-0.32, 0.6, 0.04), Vector3(0.12, 0.14, 0.12), _hex("prop_color", "c89a4a"))
			_box(torso, Vector3(-0.32, 0.72, 0.04), Vector3(0.08, 0.09, 0.08), _hex("prop_color", "c89a4a"))
		"book":
			_held(hand, grip + Vector3(0, 0.0, 0.08), Vector3(0.05, 0.2, 0.15), _hex("prop_color", "4a5a7a"))
		"lute":
			var centre := Vector3(0.02, 0.98, -0.25)
			_tilted(torso, centre, Vector3(0.32, 0.4, 0.06), _hex("prop_color", "8a5a32"), Vector3(0, 0, -0.5))
			_tilted(torso, centre + Vector3(sin(0.5), cos(0.5), 0)*0.38, Vector3(0.05, 0.36, 0.05), wood, Vector3(0, 0, -0.5))
		"hammer":
			# Carried at the side, the head hanging below the hand.
			_held(hand, grip + Vector3(0, -0.14, 0.04), Vector3(0.05, 0.34, 0.05), wood)
			_held(hand, grip + Vector3(0, -0.32, 0.04), Vector3(0.1, 0.1, 0.22), _hex("prop_color", "4a4a50"))
		"glaive":
			# A long-hafted broad blade (常老大's 泼风刀): the pole stood beside him, the blade high.
			_held(hand, grip + Vector3(0, 0.35, 0), Vector3(0.05, 1.7, 0.05), _hex("wood", wood))
			_held(hand, grip + Vector3(0, 1.26, 0.06), Vector3(0.05, 0.36, 0.17), _hex("prop_color", "c2c6c8"))
			_held(hand, grip + Vector3(0, 1.06, 0), Vector3(0.09, 0.05, 0.09), tassel)
		"whisk":
			# A Taoist's horsetail whisk (拂尘): a short handle, the white tail hanging.
			_held(hand, grip + Vector3(0, 0.06, 0.06), Vector3(0.04, 0.2, 0.04), wood)
			_held(hand, grip + Vector3(0, -0.14, 0.1), Vector3(0.08, 0.26, 0.08), _hex("prop_color", "eeeae0"))
		"axe":
			# A woodcutter's axe at the side, the blade below the hand, its edge forward.
			_held(hand, grip + Vector3(0, -0.16, 0.04), Vector3(0.05, 0.4, 0.05), wood)
			_held(hand, grip + Vector3(0, -0.32, 0.13), Vector3(0.04, 0.15, 0.16), _hex("prop_color", "8a8f94"))


## A box of the body at its plain-figure place `at` (torso and head heights follow the height),
## sized `size` (widths follow the build; a head part follows the head only).
func _box(parent: Node3D, at: Vector3, size: Vector3, hex: String, head: bool = false) -> void:
	_s.box(parent, _at(at, head), _size(at, size, head), _tone(hex))


func _tilted(parent: Node3D, at: Vector3, size: Vector3, hex: String, angles: Vector3) -> void:
	_s.tilted_box(parent, _at(at), _size(at, size, false), _tone(hex), angles)


## A box of something held, in the arm's own space (the grip is already where the hand is).
func _held(hand: Node3D, at: Vector3, size: Vector3, hex: String) -> void:
	_s.box(hand, at, size, _tone(hex))


func _held_tilted(hand: Node3D, at: Vector3, size: Vector3, hex: String, angles: Vector3) -> void:
	_s.tilted_box(hand, at, size, _tone(hex), angles)


## Where a plain-figure point goes on this body: the torso's heights stretched between the hips
## and the shoulders, the head moved up with them and sized by its own factor.
func _at(at: Vector3, head: bool = false) -> Vector3:
	if head or at.y > 1.2:
		var neck: float = _y(1.2)
		return Vector3(at.x*_head_k, neck + (at.y - 1.2)*_head_k, (at.z - 0.035)*_head_k + 0.035)
	return Vector3(at.x*_wide, _y(at.y), at.z*_deep)


func _size(at: Vector3, size: Vector3, head: bool) -> Vector3:
	if head or at.y > 1.2:
		return size*_head_k
	return Vector3(size.x*_wide, size.y*(_torso_k if at.y > 0.57 else _legs_k), size.z*_deep)


## A plain-figure height on this body: the legs up to the hip, then the torso.
func _y(y: float) -> float:
	if y <= 0.57:
		return y*_legs_k
	return 0.57*_legs_k + (minf(y, 1.2) - 0.57)*_torso_k + maxf(y - 1.2, 0.0)*_head_k


## The shoes: the trousers a shade darker, or straw or white.
func _shoes(pants: String) -> String:
	match _word("shoes", "dark"):
		"straw":
			return "c9b27a"
		"white":
			return "e6e0d2"
	return _hex("shoe_color", "524737" if not look.has("pants") else Color(pants).darkened(0.35).to_html(false))


func _word(key: String, fallback: String) -> String:
	return String(look.get(key, fallback))


## A colour of the look ("rrggbb", no #), else `fallback`.
func _hex(key: String, fallback: String) -> String:
	var value: String = String(look.get(key, ""))
	return value if value.is_valid_html_color() else fallback


## A part's colour, or for a statue the stone's shade nearest its lightness.
func _tone(hex: String) -> String:
	if stone.is_empty():
		return hex
	var base := Color(stone)
	var shade: float = Color(hex).get_luminance()-0.45
	return (base.lightened(shade*0.5) if shade>0 else base.darkened(-shade*0.6)).to_html(false)

func _process(delta: float) -> void:
	if not stone.is_empty():
		return
	clock += delta
	pace += delta * (10.5 if walking else 1.0)
	var stride: float = sin(pace)*0.55 if walking else 0.0
	legs[0].rotation.x = stride
	legs[1].rotation.x = -stride
	arms[0].rotation.x = -stride*0.75
	arms[1].rotation.x = stride*0.75
	torso.position.y = absf(sin(pace))*0.045 if walking else sin(clock*2.1)*0.012
	eyes.scale.y = 0.12 if fmod(clock,4.3)<0.13 else 1.0
	if not walking and fmod(clock,7.2)>5.8:
		arms[1].rotation.x = -sin((fmod(clock,7.2)-5.8)/1.4*PI)*0.8
