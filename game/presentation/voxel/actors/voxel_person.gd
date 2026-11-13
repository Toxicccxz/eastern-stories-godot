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
const HEADWEAR: Array[String] = ["none", "straw_hat", "cloth_cap", "headscarf", "crown", "official_cap", "helmet"]
const BEARDS: Array[String] = ["none", "moustache", "chin_three", "full", "long"]
const WAISTS: Array[String] = ["belt", "sash", "apron", "none"]
const PROPS: Array[String] = ["none", "sword_waist", "sword_back", "blade_back", "staff", "spear", "fan", "teapot", "basket_back", "umbrella", "gourd", "book", "lute", "hammer", "axe", "glaive", "whisk", "cleaver", "blade_waist", "blade_sword_waist", "bundle_back", "haw_pole", "hoe", "pick", "broom", "rod"]
## The tool a gesture (NpcLifeBook.GESTURES, DECISIONS「街上的人会动」) puts in a hand that holds
## nothing by its look.
const GESTURE_TOOLS: Dictionary[String, String] = {
	"hoe": "hoe", "pick": "pick", "chop": "axe", "hammer": "hammer", "sweep": "broom", "fish": "rod",
}
## What the look carries in its hand (the rest hang at the waist or ride on the back, leaving the
## hand free for a gesture's tool).
const IN_HAND: Array[String] = ["staff", "spear", "fan", "teapot", "umbrella", "book", "hammer", "glaive", "whisk", "axe", "cleaver", "haw_pole", "hoe", "pick", "broom", "rod"]
## Seconds one round of a gesture takes.
const GESTURE_SECONDS: Dictionary[String, float] = {
	"hoe": 1.9, "pick": 1.7, "chop": 1.4, "hammer": 1.0, "sweep": 1.6, "fish": 5.0, "drill": 1.3,
	"wipe": 1.8, "teach": 3.6, "count": 0.9,
}
## A pose's leg angle (forward, radians): on a low stool, cross-legged on the ground.
const POSE_LEGS: Dictionary[String, float] = {"sit": -1.2, "sit_ground": -1.5}
## The step of the breath's rise (the torso goes up and down 0.012 at rest).
const BREATH_STEP: float = 0.004
## towel_neck: the waiter's cloth round the neck; bracers (护腕) round the wrists; leg_wraps (绑腿)
## round the shins; armor (甲): a plate on each shoulder and one on the chest; shield (圆盾, 铁盾会):
## strapped to the left forearm; lantern (灯笼, 巡夜禁军): hung from the left hand.
const EXTRAS: Array[String] = ["towel_neck", "bracers", "leg_wraps", "armor", "shield", "lantern"]

## 战斗肢体 (DECISIONS「战斗肢体」): how a fighter stands and strikes. A pose is nine angles
## (radians): the striking arm forward (negative: forward and up) and outward, the other arm
## forward and outward, the body's lean forward and its turn toward the striking side, the
## weapon's tip over the level (0 straight ahead, PI/2 straight up), the front leg and the rear.
const GUARD: Array[float] = [-0.85, -0.15, -0.55, -0.25, 0.0, 0.2, 0.7, -0.24, 0.22]
## A strike by its motion (battle_stage.json moves.weapons: the weapon's skill → its motion):
## where the body winds up to and where the blow ends. `swing` goes from the guard (0) back to the
## windup (-1) and through the guard to the blow's end (1).
const STRIKES: Dictionary[String, Array] = {
	"slam": [[-2.5, 0.1, -0.3, -0.1, -0.06, 0.4, 2.4, -0.2, 0.25], [-0.95, -0.25, 0.3, 0.3, 0.14, -0.15, -0.15, -0.5, 0.42]],
	"slash": [[-2.1, 0.7, -0.35, -0.1, -0.04, 0.45, 2.0, -0.2, 0.25], [-0.8, -0.9, 0.2, 0.4, 0.1, -0.25, 0.0, -0.5, 0.42]],
	"heavy": [[-2.9, 0.0, -2.7, 0.0, -0.1, 0.2, 2.6, -0.15, 0.2], [-0.6, -0.1, -0.5, -0.1, 0.2, -0.05, -0.3, -0.6, 0.5]],
	"rise": [[0.0, 0.2, -0.3, -0.1, 0.1, 0.4, -0.5, -0.2, 0.25], [-1.9, -0.1, -0.2, 0.2, -0.08, -0.1, 1.2, -0.45, 0.4]],
	"quick": [[0.35, 0.15, -0.9, -0.2, 0.0, 0.4, 0.1, -0.2, 0.25], [-1.5, -0.15, 0.2, 0.3, 0.1, -0.2, 0.0, -0.55, 0.45]],
	"whip": [[-1.6, 1.1, -0.4, -0.1, 0.0, 0.45, 1.2, -0.2, 0.25], [-1.2, -0.7, 0.1, 0.4, 0.08, -0.25, 0.0, -0.45, 0.4]],
	"thrown": [[-2.5, 0.2, -0.8, -0.2, -0.06, 0.4, 1.5, -0.2, 0.25], [-1.25, -0.2, 0.2, 0.3, 0.1, -0.15, 0.0, -0.45, 0.4]],
	"fist": [[0.3, 0.2, -1.0, -0.25, 0.0, 0.4, 0.7, -0.2, 0.25], [-1.5, -0.1, 0.1, 0.1, 0.08, -0.2, 0.7, -0.5, 0.42]],
}
## How the one struck at answers (`react`, by `react_amount` 0..1): thrown open by a hit, leaning
## out of a blow's way, the weapon (or both forearms) across the chest. The same nine angles,
## then the body's lean to the side and the weapon's turn across the body.
const REACTIONS: Dictionary[String, Array] = {
	"hit": [-0.3, 0.5, -0.2, 0.5, -0.15, 0.4, 1.1, -0.2, 0.4, 0.0, 0.0],
	"dodge": [-0.4, 0.3, -0.9, 0.8, 0.1, 0.1, 0.9, -0.6, 0.5, 0.18, 0.0],
	"parry": [-1.35, -0.35, -1.2, -0.3, -0.04, 0.15, 0.9, -0.36, 0.34, 0.0, 1.1],
}
## One lying senseless: the arms fallen outward, the legs a little apart.
const LIMP: Array[float] = [0.0, 0.35, 0.0, 0.35, 0.0, 0.0, 0.7, -0.15, 0.15]
## What a fighter's hand may hold, by the weapon's skill ("" bare-handed: nothing).
const ARMS: Array[String] = ["sword", "blade", "dagger", "axe", "hammer", "staff", "fork", "whip", "throwing"]
## What a look carries in its hand that is a weapon already: nothing more is drawn there.
const OWN_ARMS: Array[String] = ["staff", "spear", "glaive", "hammer", "axe", "cleaver", "whisk", "fan"]

var walking: bool = false
## Whether the person is in a fight (take_guard(), stand_down()): it stands on guard, its weapon
## in its hand.
var fighting: bool = false
## Where its blow is: -1 wound up, 0 on guard, 1 struck through (BattleSceneShow moves it).
var swing: float = 0.0
## The blow's motion (STRIKES) and how far it reaches past the plain one (a 重: more).
var motion: String = "fist"
var power: float = 1.0
## How it answers a blow struck at it (REACTIONS, "" none) and how far (0..1).
var react: String = ""
var react_amount: float = 0.0
## How far over it lies, fallen senseless (0 upright .. 1 flat on its back; the view moves it):
## the whole body turns back about its heels and its limbs go slack.
var limp: float = 0.0
## One lying on its back is raised this far (half its depth would be under the ground).
const LIE_LIFT: float = 0.2
## The body (torso, legs, a seat) under the figure's own node, which the view and the fight's
## show turn and move: lying down turns this.
var frame: Node3D
## The weapon drawn in its hand ("" none) and the node that holds it.
var armed: String = ""
var _weapon: Node3D
## How far into the guard it is (0 at ease .. 1 on guard) and how long the change takes.
var _guard: float = 0.0
var _guard_seconds: float = 0.0
## The arm that holds the weapon (0 the figure's right) and the one striking now (bare hands
## strike in turn).
var _lead: int = 0
var _striker: int = 0
## What the hands do while the person stands at work ("" none; NpcLifeBook.GESTURES) and how it
## stays put ("stand", "sit", "sit_ground"); set before it is added (activity()).
var gesture: String = ""
var pose: String = "stand"
## Whether the gesture plays now: the view clears it while the person attends to the player.
var working: bool = true
## Whether the person is up and about (the view clears it while it fights or lies senseless): only
## then does it sit or work.
var at_ease: bool = true
## The gesture's tool in a free hand ("" none).
var _tool: String = ""
## How far the pose lowers the body.
var _sink: float = 0.0
var _seat: Node3D
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


## The person's work and pose (NpcLifeBook's entry), before it is added: a gesture's tool goes in
## a hand the look leaves empty.
func activity(work: String, how: String) -> void:
	gesture = work
	pose = how if POSE_LEGS.has(how) else "stand"
	if GESTURE_TOOLS.has(work) and not IN_HAND.has(_word("prop", "none")):
		_tool = GESTURE_TOOLS[work]


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
	frame = Node3D.new()
	frame.name = "Frame"
	add_child(frame)
	torso = Node3D.new()
	frame.add_child(torso)
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
		if extras.has("armor"):
			# A plate over the shoulder, wider than the sleeve.
			_s.box(arm, Vector3(side*0.02, -0.03*reach, 0), Vector3(0.26, 0.14*reach, 0.33*_deep + 0.04), _tone(_hex("armor_color", "6a6458")))
		if extras.has("bracers"):
			# Over the sleeve's end, just above the hand.
			_s.box(arm, Vector3(0, -0.25*reach, 0.005), Vector3(0.22, 0.12*reach, 0.3*_deep + 0.02), _tone(_hex("bracer_color", "4a3628")))
		if extras.has("shield") and side > 0.0:
			# A round shield on the left forearm, held before the body with its face forward and a
			# little out: two crossed plates for the round edge, a metal boss in the middle.
			var face: String = _hex("shield_color", "7a6a58")
			var turn := Vector3(0, 0.35, 0)
			var centre := Vector3(0.05, -0.27*reach, 0.2)
			_held_tilted(arm, centre, Vector3(0.44, 0.32, 0.05), face, turn)
			_held_tilted(arm, centre, Vector3(0.32, 0.44, 0.05), face, turn)
			_held_tilted(arm, centre + Vector3(sin(0.35), 0, cos(0.35))*0.035, Vector3(0.1, 0.1, 0.04), _hex("metal", "b9a26a"), turn)
		if extras.has("lantern") and side > 0.0:
			# A paper lantern hung from the left hand on a short cord, a little forward of the hip:
			# the body, a dark cap above and below.
			var paper: String = _hex("lantern_color", "c8402a")
			var cap: String = Color(paper).darkened(0.55).to_html(false)
			var hang := Vector3(0, -0.62*reach, 0.08)
			_held(arm, Vector3(0, -0.47*reach, 0.05), Vector3(0.03, 0.12*reach, 0.03), cap)
			_held(arm, hang, Vector3(0.2, 0.24, 0.2), paper)
			_held(arm, hang + Vector3(0, 0.135, 0), Vector3(0.14, 0.03, 0.14), cap)
			_held(arm, hang - Vector3(0, 0.135, 0), Vector3(0.14, 0.03, 0.14), cap)
		var leg := Node3D.new()
		var hip: float = 0.57*_legs_k
		leg.position = Vector3(side*0.17*maxf(_wide, 0.9), hip, 0)
		frame.add_child(leg)
		legs.append(leg)
		# The shoe stays on the ground; the leg reaches from its top to the hip.
		_s.box(leg, Vector3(0, (0.17 - hip)/2.0, 0), Vector3(0.2, hip - 0.17, 0.23), _tone(pants))
		_s.box(leg, Vector3(0, 0.14 - hip, 0.06), Vector3(0.23, 0.16, 0.35), _tone(_shoes(pants)))
		if extras.has("leg_wraps"):
			# Round the shin from the shoe's top to below the knee.
			_s.box(leg, Vector3(0, 0.17 - hip + 0.11*_legs_k, 0), Vector3(0.22, 0.22*_legs_k, 0.25), _tone(_hex("wrap_color", "5e4a38")))
	if extras.has("armor"):
		# Over the chest, below the collar; a darker band along its foot.
		var plate: String = _hex("armor_color", "6a6458")
		_box(torso, Vector3(0, 0.94, 0.185), Vector3(0.46, 0.3, 0.04), plate)
		_box(torso, Vector3(0, 0.8, 0.19), Vector3(0.48, 0.04, 0.04), Color(plate).darkened(0.25).to_html(false))
	_prop()
	_pose()
	if extras.has("towel_neck"):
		_box(torso, Vector3(0.12, 1.14, 0.12), Vector3(0.12, 0.08, 0.3), _hex("towel", "ece6d6"))
		_box(torso, Vector3(0.14, 0.98, 0.21), Vector3(0.1, 0.26, 0.05), _hex("towel", "ece6d6"))
	for extra: String in EXTRAS:
		if extras.has(extra):
			drawn.append(extra)
	# A limb's plain colours are one batch (DECISIONS「搭建开销」): a figure was some twenty
	# draws, a street of forty people a thousand.
	_s.pool_plain_colours()
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
	var covered: bool = headwear in ["cloth_cap", "official_cap", "straw_hat", "helmet"]
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
		"helmet":
			# A soldier's bronze or iron helmet (军盔): the bowl over the hair, a rim at the brow,
			# the knob on top (缨钮) in the tassel's colour.
			var bronze: String = _hex("headwear_color", "8a6a3a")
			_box(torso, Vector3(0, 1.66, -0.02), Vector3(0.5, 0.14, 0.45), bronze, true)
			_box(torso, Vector3(0, 1.75, -0.02), Vector3(0.34, 0.05, 0.31), Color(bronze).lightened(0.08).to_html(false), true)
			_box(torso, Vector3(0, 1.6, 0.2), Vector3(0.5, 0.04, 0.06), Color(bronze).darkened(0.25).to_html(false), true)
			_box(torso, Vector3(0, 1.81, -0.02), Vector3(0.07, 0.08, 0.07), _hex("tassel_color", _hex("accent", "a8322a")), true)


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
	_draw_prop(_word("prop", "none"))
	if not _tool.is_empty():
		_draw_prop(_tool)


## One thing carried (PROPS) on this body.
func _draw_prop(prop: String) -> void:
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
			_at_hip(0.3, 0.82, 0.06, metal, wood, tassel)
		"blade_waist":
			# A broad, shorter sheath at the left hip (腰刀).
			_at_hip(0.3, 0.7, 0.11, metal, wood, "")
		"blade_sword_waist":
			# 左佩刀，右佩剑 (严廷殷): the sabre at the left hip, the sword at the right.
			_at_hip(0.3, 0.7, 0.11, metal, wood, "")
			_at_hip(-0.3, 0.82, 0.06, metal, wood, tassel)
		"bundle_back":
			# A long cloth-wrapped bundle across the back, tied near each end.
			var cloth: String = _hex("bundle_color", "8a7a5a")
			var centre := Vector3(0, 1.0, -0.23)
			var along := Vector3(-sin(0.72), cos(0.72), 0)
			_tilted(torso, centre, Vector3(0.13, 0.9, 0.1), cloth, Vector3(0, 0, 0.72))
			for end: float in [-0.3, 0.3]:
				_tilted(torso, centre + along*end, Vector3(0.15, 0.04, 0.12), Color(cloth).darkened(0.3).to_html(false), Vector3(0, 0, 0.72))
		"haw_pole":
			# A candied-haw seller's pole (糖葫芦草靶): held upright, a straw bundle at the top
			# bristling with red skewers.
			var straw: String = _hex("prop_color", "c9a35a")
			_held(hand, grip + Vector3(0, 0.45, 0), Vector3(0.05, 1.5, 0.05), wood)
			_held(hand, grip + Vector3(0, 1.12, 0), Vector3(0.2, 0.34, 0.2), straw)
			for spike: Vector3 in [Vector3(0.14, 1.2, 0), Vector3(-0.14, 1.06, 0.03), Vector3(0, 1.16, 0.14), Vector3(0.03, 1.02, -0.14), Vector3(0.1, 0.98, 0.1), Vector3(-0.1, 1.24, -0.08)]:
				_held(hand, grip + spike, Vector3(0.07, 0.07, 0.07), _hex("tassel_color", "c8282a"))
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
		"hoe", "pick", "broom":
			# A long-handled tool hanging from the hand to the ground: its head forward (锄头, 镐)
			# or a brush of twigs across (扫帚).
			var reach: float = 0.95*_legs_k
			_held(hand, grip + Vector3(0, -reach/2.0, 0.04), Vector3(0.05, reach, 0.05), wood)
			var head: Vector3 = grip + Vector3(0, -reach, 0.04)
			match prop:
				"hoe":
					_held(hand, head + Vector3(0, 0.04, 0.12), Vector3(0.16, 0.05, 0.22), _hex("prop_color", "7a7e82"))
				"pick":
					_held(hand, head + Vector3(0, 0.02, 0.0), Vector3(0.06, 0.07, 0.5), _hex("prop_color", "6a6e72"))
				"broom":
					_held(hand, head + Vector3(0, -0.06, 0.02), Vector3(0.3, 0.16, 0.08), _hex("prop_color", "b89a5a"))
		"rod":
			# A bamboo fishing rod held out forward and a little down, its line hanging from the tip.
			var bamboo: String = _hex("prop_color", "b8a868")
			var lean := Vector3(0, -0.29, 0.96)
			_held_tilted(hand, grip + lean*0.7, Vector3(0.03, 1.4, 0.03), bamboo, Vector3(1.865, 0, 0))
			_held(hand, grip + lean*1.4 + Vector3(0, -0.3, 0), Vector3(0.01, 0.6, 0.01), "d8d4c8")
		"cleaver":
			# A butcher's broad knife (郑屠夫's 解牛刀) hanging from the hand, the wide blade forward.
			_held(hand, grip + Vector3(0, -0.06, 0.04), Vector3(0.05, 0.14, 0.05), wood)
			_held(hand, grip + Vector3(0, -0.22, 0.09), Vector3(0.03, 0.2, 0.18), _hex("prop_color", "c2c6c8"))


## A pose (POSE_LEGS): the legs reach forward from the hips and the body sinks until the feet
## touch the ground; on a stool ("sit") a low one is drawn under the hips.
func _pose() -> void:
	if not POSE_LEGS.has(pose):
		return
	var hip: float = 0.57*_legs_k
	_sink = hip*(1.0 - cos(absf(POSE_LEGS[pose]))) if pose == "sit" else hip - 0.12
	drawn.append("pose:" + pose)
	if pose == "sit":
		_seat = Node3D.new()
		frame.add_child(_seat)
		var height: float = hip - _sink
		_s.box(_seat, Vector3(0, height/2.0 - 0.02, -0.06), Vector3(0.42, height - 0.04, 0.36), _hex("seat_color", "7a5a3a"))


## A sheathed weapon hung from the belt at the hip `x` (0.3 the left, -0.3 the right): the hilt
## forward and up, the tip back and down; `wide` 0.06 a sword, 0.11 a sabre; a tassel if given.
func _at_hip(x: float, long: float, wide: float, metal: String, wood: String, tassel: String) -> void:
	var sheath: String = _hex("prop_color", "3a2a22")
	var centre := Vector3(x, 0.56, 0.1)
	var along := Vector3(0, cos(0.5), sin(0.5))
	_tilted(torso, centre, Vector3(wide, long, 0.07), sheath, Vector3(0.5, 0, 0))
	_tilted(torso, centre + along*(long/2.0 + 0.02), Vector3(0.14, 0.04, 0.08), metal, Vector3(0.5, 0, 0))
	_tilted(torso, centre + along*(long/2.0 + 0.14), Vector3(0.05, 0.18, 0.05), wood, Vector3(0.5, 0, 0))
	if not tassel.is_empty():
		_box(torso, centre + along*(long/2.0 + 0.19) + Vector3(0, -0.1, 0.03), Vector3(0.04, 0.14, 0.04), tassel)


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
	# The frame's pose first, then only what differs from the one shown is written: a part
	# set to the place it has is still sent to the renderer with everything on it, every
	# frame, and redraws the shadows of the lamps about it. One standing still costs nothing.
	var stride: float = sin(pace)*0.55 if walking else 0.0
	var posed: bool = not walking and at_ease and POSE_LEGS.has(pose)
	var sink: float = _sink if posed else 0.0
	if _seat != null:
		_seat.visible = posed
	# 战斗肢体: on guard (or fallen) the fight's pose is the whole body's.
	_guard = move_toward(_guard, 1.0 if fighting else 0.0, delta/_guard_seconds if _guard_seconds > 0.0 else 1.0)
	if _weapon != null and _weapon.visible != (_guard > 0.5 and limp < 0.5):
		_weapon.visible = not _weapon.visible
	var stance: float = 0.0 if walking or posed else _guard
	var lying := Vector3(-PI/2.0*limp, 0.0, 0.0)
	if not frame.rotation.is_equal_approx(lying):
		frame.rotation = lying
		frame.position.y = LIE_LIFT*limp
	if stance > 0.0 or limp > 0.0:
		_fight_pose(stance)
		_blink()
		return
	var leg_y: float = 0.57*_legs_k - sink
	_place(legs[0], Vector3(POSE_LEGS[pose] if posed else stride, 0.0, 0.0), leg_y)
	_place(legs[1], Vector3(POSE_LEGS[pose] if posed else -stride, 0.0, 0.0), leg_y)
	var gesturing: bool = not walking and working and at_ease and GESTURE_SECONDS.has(gesture)
	if gesturing:
		# The gesture writes the arms and the lean itself, from this rest.
		arms[0].rotation = Vector3(-stride*0.75, 0.0, 0.0)
		arms[1].rotation = Vector3(stride*0.75, 0.0, 0.0)
		torso.rotation = Vector3.ZERO
	else:
		var lift: float = -sin((fmod(clock,7.2)-5.8)/1.4*PI)*0.8 if not walking and fmod(clock,7.2)>5.8 else stride*0.75
		_turn(arms[0], Vector3(-stride*0.75, 0.0, 0.0))
		_turn(arms[1], Vector3(lift, 0.0, 0.0))
		_turn(torso, Vector3.ZERO)
	# The breath is a hundredth of the figure's height: in steps, a few a second.
	var rise: float = absf(sin(pace))*0.045 if walking else snappedf(sin(clock*2.1)*0.012, BREATH_STEP)
	if not is_equal_approx(torso.position.y, rise - sink):
		torso.position.y = rise - sink
	_blink()
	if gesturing:
		_gesture(fmod(clock, GESTURE_SECONDS[gesture])/GESTURE_SECONDS[gesture])


func _blink() -> void:
	var lids: float = 0.12 if fmod(clock,4.3)<0.13 else 1.0
	if not is_equal_approx(eyes.scale.y, lids):
		eyes.scale.y = lids


## A part turned to `angles`, written only when it is not there already.
static func _turn(part: Node3D, angles: Vector3) -> void:
	if not part.rotation.is_equal_approx(angles):
		part.rotation = angles


## A leg turned to `angles` at the height `y`, written only when it is not there already.
static func _place(part: Node3D, angles: Vector3, y: float) -> void:
	_turn(part, angles)
	if not is_equal_approx(part.position.y, y):
		part.position.y = y


## One moment `t` (0..1) of the gesture's round: arms (0 holds the tool) and the lean of the body.
## Arms turn forward and up with a negative x.
func _gesture(t: float) -> void:
	match gesture:
		"hoe", "pick", "chop":
			# Up slowly over the head, down hard, a rest with the tool in the ground.
			var swing: float = -0.35
			if t < 0.55:
				swing = lerpf(-0.35, -2.5, smoothstep(0.0, 1.0, t/0.55))
			elif t < 0.68:
				swing = lerpf(-2.5, -0.35, (t - 0.55)/0.13)
			arms[0].rotation.x = swing
			arms[1].rotation.x = swing*0.9
			torso.rotation.x = 0.14 if t >= 0.6 else 0.03
		"hammer":
			# One arm up and down on the anvil, the other steadying the work.
			var strike: float = lerpf(-2.0, -0.5, smoothstep(0.55, 0.7, t)) if t < 0.7 else lerpf(-0.5, -2.0, smoothstep(0.7, 1.0, t))
			arms[0].rotation.x = strike
			arms[1].rotation.x = -0.75
		"sweep":
			# Both hands low on the broom, swept side to side.
			var side: float = sin(t*TAU)*0.35
			arms[0].rotation.x = -0.45
			arms[1].rotation.x = -0.55
			arms[0].rotation.z = side
			arms[1].rotation.z = side
			torso.rotation.y = side*0.4
		"fish":
			# The rod held out; now and then a small jerk of the line.
			var jerk: float = sin(clampf((t - 0.8)/0.08, 0.0, 1.0)*PI)*0.25
			arms[0].rotation.x = -0.95 - jerk
			arms[1].rotation.x = -0.8 - jerk
		"drill":
			# Punches, one hand and the other, with a pause to breathe.
			var left: float = sin(clampf(t/0.2, 0.0, 1.0)*PI)
			var right: float = sin(clampf((t - 0.3)/0.2, 0.0, 1.0)*PI)
			arms[0].rotation.x = -0.3 - 1.25*left
			arms[1].rotation.x = -0.3 - 1.25*right
			torso.rotation.y = (left - right)*0.18
		"wipe":
			# A cloth round and round on the table in front.
			arms[1].rotation.x = -1.1 + sin(t*TAU)*0.15
			arms[1].rotation.z = cos(t*TAU)*0.3
		"teach":
			# One hand raised, turning as the words go.
			arms[1].rotation.x = -1.2 + sin(t*TAU)*0.25
			arms[1].rotation.z = sin(t*TAU*2.0)*0.15
		"count":
			# Both hands before the chest, the fingers at the beads.
			arms[0].rotation.x = -0.9 + sin(t*TAU)*0.06
			arms[1].rotation.x = -0.9 - sin(t*TAU)*0.06


# --- 战斗肢体 -----------------------------------------------------------------------------------


## The fight begins for this one: on guard within `seconds` (0: at once), the weapon of `weapon`'s
## skill (ARMS; "" bare-handed) in its hand. A look that carries a weapon in its hand already
## (OWN_ARMS) fights with that; a hand full of something else leaves the weapon to the other.
func take_guard(weapon: String, seconds: float = 0.0) -> void:
	fighting = true
	_guard_seconds = seconds
	var held: String = _word("prop", "none")
	var own: bool = OWN_ARMS.has(held)
	_lead = 1 if not own and (IN_HAND.has(held) or not _tool.is_empty()) else 0
	_striker = _lead
	var wanted: String = "" if own or not ARMS.has(weapon) else weapon
	if wanted == armed and (_weapon != null or wanted.is_empty()):
		return
	armed = wanted
	if _weapon != null:
		_weapon.queue_free()
		_weapon = null
	if wanted.is_empty() or arms.size() < 2:
		return
	_weapon = Node3D.new()
	_weapon.name = "Weapon"
	_weapon.position = Vector3(0, -0.45*_torso_k, 0.04)
	_weapon.visible = false
	arms[_lead].add_child(_weapon)
	_draw_weapon(wanted)


## The fight is over for this one: at ease within `seconds`, the weapon put away.
func stand_down(seconds: float = 0.0) -> void:
	fighting = false
	_guard_seconds = seconds
	swing = 0.0
	react = ""
	react_amount = 0.0


## A blow begins: its motion (STRIKES) and reach. Bare hands strike in turn; `same_hand`: the
## blow the hand is raised for already (its windup came first).
func begin_strike(p_motion: String, p_power: float = 1.0, same_hand: bool = false) -> void:
	motion = p_motion if STRIKES.has(p_motion) else "fist"
	power = p_power
	react = ""
	react_amount = 0.0
	if same_hand:
		return
	if motion == "fist" and armed.is_empty() and not OWN_ARMS.has(_word("prop", "none")):
		_striker = 1 - _striker
	else:
		_striker = _lead


## The fight's pose now, `stance` far into the guard (0 at ease .. 1): the guard, the blow by
## `swing`, the answer by `react_amount`, and all of it gone slack by `limp`. Written only where
## it differs from what is shown.
func _fight_pose(stance: float) -> void:
	var p: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
	for i: int in 9:
		p[i] = GUARD[i]
	if not is_zero_approx(swing):
		var strike: Array = STRIKES.get(motion, STRIKES["fist"])
		var to: Array = strike[0] if swing < 0.0 else strike[1]
		var amount: float = absf(swing)*(power if swing > 0.0 else 1.0)
		var swapped: bool = _striker != _lead
		for i: int in 9:
			var change: float = (float(to[i]) - GUARD[i])*amount
			# The other hand's blow: the arms change parts, the body turns the other way (about
			# straight ahead, not about the guard).
			var at: int = i
			if swapped and i < 4:
				at = (i + 2) % 4
			elif swapped and i == 5:
				change = (-float(to[i]) - GUARD[i])*amount
			p[at] += change
	if react_amount > 0.0 and REACTIONS.has(react):
		var answer: Array = REACTIONS[react]
		for i: int in 11:
			p[i] = lerpf(p[i], float(answer[i]), react_amount)
	var slack: float = clampf(limp, 0.0, 1.0)
	for i: int in 11:
		p[i] = lerpf(p[i]*stance, LIMP[i] if i < 9 else 0.0, slack)
	# The lead arm's outward is the figure's right (arms[0], at -x) or its left.
	var out: float = -1.0 if _lead == 0 else 1.0
	_turn(arms[_lead], Vector3(p[0], 0.0, out*p[1]))
	_turn(arms[1 - _lead], Vector3(p[2], 0.0, -out*p[3]))
	_turn(torso, Vector3(p[4], out*p[5], out*p[9]))
	if _weapon != null:
		_turn(_weapon, Vector3(-p[0] - p[6], -out*p[10], 0.0))
	var hip: float = 0.57*_legs_k
	var sink: float = 0.0
	if not has_meta("mounted"):
		sink = hip*(1.0 - cos(maxf(absf(p[7]), absf(p[8]))))
		_place(legs[1 - _lead], Vector3(p[7], 0.0, 0.0), hip - sink)
		_place(legs[_lead], Vector3(p[8], 0.0, 0.0), hip - sink)
	var rise: float = snappedf(sin(clock*2.1)*0.012, BREATH_STEP)*(1.0 - slack) - sink
	if not is_equal_approx(torso.position.y, rise):
		torso.position.y = rise


## The weapon in the hand, in its own node at the grip: it lies along +z from the hand (the
## pose turns it), `kind` one of ARMS.
func _draw_weapon(kind: String) -> void:
	var s := Shapes.new()
	var steel: String = _hex("blade_color", "c9ced2")
	var edge: String = Color(steel).darkened(0.25).to_html(false)
	var metal: String = _hex("metal", "b9a26a")
	var wood: String = _hex("wood", "6b4a30")
	var tassel: String = _hex("tassel_color", _hex("accent", "a8322a"))
	match kind:
		"sword":
			s.box(_weapon, Vector3(0, 0, -0.03), Vector3(0.05, 0.05, 0.2), wood)
			s.box(_weapon, Vector3(0, 0, 0.08), Vector3(0.17, 0.05, 0.04), metal)
			s.box(_weapon, Vector3(0, 0, 0.52), Vector3(0.05, 0.025, 0.84), steel)
			s.box(_weapon, Vector3(0, 0, 0.96), Vector3(0.03, 0.02, 0.06), steel)
			s.box(_weapon, Vector3(0, -0.08, -0.14), Vector3(0.04, 0.14, 0.04), tassel)
		"blade":
			s.box(_weapon, Vector3(0, 0, -0.03), Vector3(0.05, 0.05, 0.2), wood)
			s.box(_weapon, Vector3(0, 0, 0.08), Vector3(0.1, 0.12, 0.04), metal)
			s.box(_weapon, Vector3(0, -0.02, 0.46), Vector3(0.03, 0.12, 0.72), steel)
			s.box(_weapon, Vector3(0, 0.045, 0.46), Vector3(0.035, 0.03, 0.72), edge)
			s.box(_weapon, Vector3(0, -0.045, 0.85), Vector3(0.03, 0.07, 0.08), steel)
		"dagger":
			s.box(_weapon, Vector3(0, 0, -0.02), Vector3(0.05, 0.05, 0.14), wood)
			s.box(_weapon, Vector3(0, 0, 0.06), Vector3(0.11, 0.04, 0.03), metal)
			s.box(_weapon, Vector3(0, 0, 0.24), Vector3(0.04, 0.02, 0.34), steel)
		"axe":
			s.box(_weapon, Vector3(0, 0, 0.22), Vector3(0.05, 0.05, 0.7), wood)
			s.box(_weapon, Vector3(0, -0.08, 0.5), Vector3(0.04, 0.24, 0.17), steel)
			s.box(_weapon, Vector3(0, -0.2, 0.5), Vector3(0.03, 0.03, 0.2), edge)
		"hammer":
			s.box(_weapon, Vector3(0, 0, 0.22), Vector3(0.05, 0.05, 0.7), wood)
			s.box(_weapon, Vector3(0, 0, 0.56), Vector3(0.17, 0.26, 0.17), _hex("prop_color", "4a4a50"))
		"staff":
			s.box(_weapon, Vector3(0, 0, 0.25), Vector3(0.05, 0.05, 1.7), wood)
			for end: float in [-0.56, 1.06]:
				s.box(_weapon, Vector3(0, 0, end), Vector3(0.065, 0.065, 0.08), metal)
		"fork":
			s.box(_weapon, Vector3(0, 0, 0.2), Vector3(0.05, 0.05, 1.6), wood)
			s.box(_weapon, Vector3(0, 0, 1.02), Vector3(0.24, 0.035, 0.04), steel)
			for prong: float in [-0.1, 0.0, 0.1]:
				s.box(_weapon, Vector3(prong, 0, 1.15), Vector3(0.03, 0.03, 0.24 if is_zero_approx(prong) else 0.2), steel)
			s.box(_weapon, Vector3(0, 0, 0.96), Vector3(0.08, 0.08, 0.05), tassel)
		"whip":
			# A handle and the lash trailing from it, each length thinner and hanging lower.
			s.box(_weapon, Vector3(0, 0, 0.0), Vector3(0.05, 0.05, 0.2), wood)
			var lash: String = _hex("prop_color", "3a2a22")
			for link: int in 5:
				s.tilted_box(_weapon, Vector3(0, -0.02*link*link, 0.2 + 0.2*link), Vector3(0.04 - 0.005*link, 0.04 - 0.005*link, 0.22), lash, Vector3(0.1*link, 0, 0))
		"throwing":
			s.box(_weapon, Vector3(0, 0, 0.07), Vector3(0.025, 0.025, 0.16), steel)
			s.box(_weapon, Vector3(0, 0, -0.03), Vector3(0.05, 0.05, 0.04), tassel)
	s.flush()
