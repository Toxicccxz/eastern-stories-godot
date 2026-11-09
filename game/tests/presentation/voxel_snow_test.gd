extends RefCounted

## 雪亭镇's facades in the voxel view (雪亭镇立面细化, voxel_facade.gd): every shop known at a glance by
## a mark of its own — the inn's ebony board and wine flag, the moneychanger's coins, the smithy's
## forge glow and soot, the 药 sign, the 驿 flag, the mill's board hung at its door, the pawnshop's
## one great 当 on its door and no board (mstreet3.c) — every building old and lived in, the boards
## hung where the camera sees them, and what stands before the doors leaves the street, the doors
## and the people's places clear.
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const Still := preload("res://tests/runtime/snow_south_road_test.gd")
const Existing := preload("res://tests/presentation/voxel_gameplay_test.gd")
## Keys of age and use on a building (voxel_facade.gd and the older facade keys).
const AGE: Array[String] = ["damp", "stains", "patches", "cracks", "foot_weeds", "roof_weeds", "soot", "notices", "whitewash", "worn"]
## A porch's front edge out from its doorway, by its make (VoxelArchitecture._signboard).
const PORCH_EDGE: Dictionary = {"tiled": 1.65, "cloth": 1.5, "wood": 1.5}
var assertions: int = 0
var failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary:
	var furnishings := Existing.new()
	furnishings._check_furnishings(load("res://scenes/world/snow/snow_outdoor.tscn") as PackedScene, "snow_outdoor")
	assertions += furnishings.assertions
	failures.append_array(furnishings.failures)
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/snow/voxel/outdoor.json"))
	_check_marks(layout)
	_check_houses(layout)
	var session: WorldSessionController = Work.create_session(tree)
	session.configure_npc_ambience_random_source(Still.Still.new())
	await _frames(tree, 4)
	var map := MapPlaces.enter(session, &"snow.square", &"snow.square.inn_entry") # TEST-ONLY: out on the square
	await _frames(tree, 4)
	_check(map != null and map.projected_view, "雪亭镇 in its voxel view")
	if map == null:
		session.free()
		return {"assertions": assertions, "failures": failures}
	for npc: NpcRuntimeState in map.npc_runtimes(): # TEST-ONLY: nobody starts a fight on the walk
		npc.character_state.attributes.bellicosity = 0
	var view := map.get_node("MapView") as WorldVoxelView
	var waited: int = 0
	while not view._built and waited < 3000:
		await tree.process_frame
		waited += 1
	_check(view._built, "the town is built")
	_check(view.geometry.unknown_kinds.is_empty(), "every prop and wall hanging in 雪亭镇 is drawn: %s" % [view.geometry.unknown_kinds])
	_check_boards(map, view, layout)
	_check_door_looks(view)
	_check_lights(view)
	await _check_ways(tree, map)
	session.free()
	await _frames(tree, 2)
	return {"assertions": assertions, "failures": failures}


func _building(layout: Dictionary, portal: String) -> Dictionary:
	for building: Dictionary in layout["buildings"]:
		if portal in building.get("portals", []):
			return building
	return {}


## Each shop's own mark, from its room's text where the text names one.
func _check_marks(layout: Dictionary) -> void:
	var inn: Dictionary = _building(layout, "snow.square.west")
	_check(inn.get("signboard", {}).get("text", "") == "饮风客栈" and inn.get("signboard", {}).get("mount", "") == "porch", "inn.c: 靠近门口的地方有一块乌木雕成的招牌 — hung at the porch's front")
	_check(inn.get("hanging_flag", {}).get("text", "") == "酒" and inn.has("door_glow"), "饮风客栈: its wine flag, its warm door")
	var bank: Dictionary = _building(layout, "snow.mstreet1.west")
	_check(bank.get("hanging_flag", {}).get("coins", false) and String(bank.get("lattice", "")) == "coin" and bank.has("door_stones"), "安记钱庄: the coin sign, 古钱纹 windows, drum stones at its door")
	_check(not bank.has("stains") and not bank.has("cracks") and not bank.has("patches") and not bank.has("notices"), "bank.c: 里里外外都打扫得乾乾净净 — no stains, cracks, mends or papers")
	var smithy: Dictionary = _building(layout, "snow.mstreet2.west")
	_check(smithy.has("door_glow") and smithy.get("soot", {}).get("door", false), "smithy.c: 火炉中冒出的火光 — the forge's glow at its door, the lintel smoked")
	var herbs: Dictionary = _building(layout, "snow.mstreet3.west")
	_check(herbs.get("blade_sign", {}).get("text", "") == "药" and herbs.get("hanging_flag", {}).get("gourd", false), "桑邻药铺: the 药 sign and the physician's gourd")
	var post: Dictionary = _building(layout, "snow.mstreet4.west")
	_check(post.get("hanging_flag", {}).get("text", "") == "驿" and post.get("signboard", {}).get("mount", "") == "porch", "postoffice.c: 驿站大门口上悬著一块木牌 — and the 驿 flag")
	var mill: Dictionary = _building(layout, "snow.mstreet2.east")
	_check(mill.get("signboard", {}).get("mount", "") == "porch", "workplace.c: 门口挂著一块牌子")
	var pawn: Dictionary = _building(layout, "snow.mstreet3.east")
	var door: Dictionary = layout.get("door_looks", {}).get("snow.hockshop.door", {})
	_check(not pawn.has("signboard") and String(door.get("text", "")) == "当", "mstreet3.c: 并没有任何招牌, 只有一扇门上面写著一个大大的「当」字")
	_check(String(pawn.get("porch", "")) == "none", "no porch roof over the pawnshop's door: the camera sees its 当")
	var school: Dictionary = _building(layout, "snow.school1.east")
	_check(school.get("signboard", {}).get("text", "") == "淳风武馆" and layout.get("door_looks", {}).has("snow.school.gate"), "school1.c: 红漆大门, the 武馆's board where it is seen")
	var temple: Dictionary = _building(layout, "snow.square.east")
	_check(temple.get("soot", {}).get("door", false) and temple.has("roof_weeds"), "temple.c: 十分老旧, 被香火薰成乌黑")
	# Old and lived in (美术规划 §2 item 7): two or more marks of age on every building but the
	# swept bank, which keeps one (the damp at its foot).
	var young: Array[String] = []
	for building: Dictionary in layout["buildings"]:
		var marks: int = 0
		for key: String in AGE:
			marks += 1 if building.has(key) else 0
		if marks < (1 if building == bank else 2):
			young.append(String(building.get("note", building["rect"])).left(24))
	_check(young.is_empty(), "every building is old and lived in: %s" % [young])


## The houses are no two alike (美术规划 §2 item 3): what hangs on their walls and how they are built.
func _check_houses(layout: Dictionary) -> void:
	var seen: Dictionary = {}
	var alike: Array[String] = []
	for building: Dictionary in layout["buildings"]:
		if not building.get("portals", []).is_empty() or not building.has("wall_hangings"):
			continue
		var kinds: Array = []
		for item: Dictionary in building["wall_hangings"]:
			kinds.append("%s:%s" % [item["kind"], item.get("goods", "")])
		var form: String = "%s %s %s %s" % [building.get("construction", ""), building.get("roof_form", ""), ",".join(kinds), building.get("door_paper", {}).get("kind", "")]
		if seen.has(form):
			alike.append(form)
		seen[form] = true
	_check(seen.size() >= 8 and alike.is_empty(), "雪亭镇's eight houses are dressed each its own way: %s" % [alike])


## A board hung at a porch's front (`mount`: "porch") stands out beyond the porch's roof and under
## its eave, where the camera looking down on the street sees it.
func _check_boards(map: WorldMapController, view: WorldVoxelView, layout: Dictionary) -> void:
	var labels: Dictionary = {}
	for node: Node in view.geometry.find_children("*", "Label3D", true, false):
		labels[(node as Label3D).text] = (labels.get((node as Label3D).text, []) as Array)+[node]
	var hidden: Array[String] = []
	var hung: int = 0
	for building: Dictionary in layout["buildings"]:
		var board: Variant = building.get("signboard", null)
		if not (board is Dictionary and String(board.get("mount", "")) == "porch"):
			continue
		hung += 1
		var a: Array = building["rect"]
		var middle: Vector3 = VoxelMapGeometry.point(Vector2((float(a[0])+float(a[2]))/2, (float(a[1])+float(a[3]))/2))
		var seen: bool = false
		for portal: String in building.get("portals", []):
			var door: Vector3 = VoxelMapGeometry.point(MapPlaces.passage(map, StringName(portal)).global_position)
			var reach: Vector3 = door-middle
			var size := Vector2(float(a[2])-float(a[0]), float(a[3])-float(a[1]))
			var out := Vector3(signf(reach.x), 0, 0) if absf(reach.x)/size.x > absf(reach.z)/size.y else Vector3(0, 0, signf(reach.z))
			for label: Label3D in labels.get(tr(String(board["text"])), []):
				var at: Vector3 = label.global_position
				if (at-door).dot(out) > float(PORCH_EDGE.get(String(building.get("porch", "tiled")), 1.5)) and at.y < 2.8 and Vector2(at.x-door.x, at.z-door.z).length() < 2.5:
					seen = true
		if not seen:
			hidden.append(String(board["text"]))
	_check(hung >= 7 and hidden.is_empty(), "each porch-hung board hangs before its porch's roof: %d hung, hidden %s" % [hung, hidden])
	var blade: bool = false
	for label: Label3D in labels.get(tr("药"), []):
		blade = blade or absf(label.global_transform.basis.z.normalized().z) > 0.9
	_check(blade, "the 药 sign hangs square off the wall, read from the street both ways")


## The pawnshop's door carries its 当; the 武馆's gate is red with gilt studs, both seen from the street.
func _check_door_looks(view: WorldVoxelView) -> void:
	var pawn: Node3D = view.shutters.get(&"snow.hockshop.door")
	var lettered: bool = false
	if pawn != null:
		for node: Node in pawn.find_children("*", "Label3D", true, false):
			lettered = lettered or ((node as Label3D).text == tr("当") and (node as Label3D).global_transform.basis.z.normalized().x < -0.9)
	_check(lettered, "the 当 is on the pawnshop's door, facing the street (west)")
	# The door stands open for good (world.json: open, closable false; DECISIONS「街门常开」): its
	# leaves swung back, one 当 turned south to the camera.
	var swung: Node3D = view.opened.get(&"snow.hockshop.door")
	var still_read: bool = false
	if swung != null:
		for node: Node in swung.find_children("*", "Label3D", true, false):
			still_read = still_read or ((node as Label3D).text == tr("当") and (node as Label3D).global_transform.basis.z.normalized().z > 0.9)
	_check(still_read, "the pawnshop's door standing open still shows its 当 to the street")
	_check(view.shutters.has(&"snow.school.gate") and view.opened.has(&"snow.school.gate"), "the 武馆's red gate is drawn, and drawn standing open (DECISIONS「街门常开」)")
	# One arrow on one way: the gate's own gives way while the passage through it shows its arrow.
	var gate_arrow: Node3D = view.arrows.get(&"snow.school.gate")
	_check(gate_arrow != null and (gate_arrow.get_meta("passages", []) as Array).has(&"snow.school1.east"), "the gate knows the passage through it")
	if gate_arrow != null and view.entrances.has(&"snow.school1.east"):
		var entrance: Node3D = view.entrances[&"snow.school1.east"]["node"]
		var shown: bool = entrance.visible
		entrance.visible = true
		view._bob_arrows(0.0)
		_check(not gate_arrow.visible, "no second arrow over the gate while the passage's shows")
		entrance.visible = shown


## The smithy's forge lights its doorway, more by night than by day.
func _check_lights(view: WorldVoxelView) -> void:
	var forge: bool = false
	for node: Node in view.geometry.find_children("*", "OmniLight3D", true, false):
		var light := node as OmniLight3D
		if light.light_color.is_equal_approx(Color("ff6a2a")):
			forge = forge or float(light.get_meta("night_energy", 0.0)) > float(light.get_meta("day_energy", 0.0))
	_check(forge, "smithy.c: 火炉中冒出的火光 — the forge's glow, brighter at night")


## What now stands before the doors (the tub, the coal, the bench, the trough) leaves the doors
## and the street walkable: down the main street and back, and up to each of those doors.
func _check_ways(tree: SceneTree, map: WorldMapController) -> void:
	_check(await MapPlaces.drive_through(tree, map, [&"snow.mstreet1", &"snow.mstreet2", &"snow.mstreet3", &"snow.mstreet4"]), "up 雪亭镇大街 past the shops")
	_check(await MapPlaces.drive_through(tree, map, [&"snow.mstreet3", &"snow.mstreet2", &"snow.mstreet1", &"snow.square"]), "and back down to the square")
	for portal: StringName in [&"snow.square.west", &"snow.mstreet2.west", &"snow.mstreet4.west"]:
		var passage: WorldPassageArea2D = MapPlaces.passage(map, portal)
		var before: Vector2 = passage.global_position+Vector2(56, 0)
		_check(await MapPlaces.drive(tree, map, before), "up to the door of %s" % portal)


func _frames(tree: SceneTree, count: int) -> void:
	for i: int in count:
		await tree.physics_frame
		await tree.process_frame


func _check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok:
		failures.append(label)
