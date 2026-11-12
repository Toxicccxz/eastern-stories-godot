extends RefCounted

## No two faces of one voxel form fight in the depth buffer (owner, 2026-11-11: the 兵器房's
## shelf, the belts of the 武馆弟子, the drumstick's crust, the 书院's bookcase flickered while the
## camera moved). Shapes.settle_coplanar() steps the earlier of two coplanar faces back; these
## suites check its rules on a few boxes, then that nothing a figure, an item or a map draws is
## left fighting (CoplanarFaces reads what was drawn).
const Shapes = preload("res://presentation/voxel/props/voxel_shapes.gd")
const Person = preload("res://presentation/voxel/actors/voxel_person.gd")
const Work = preload("res://tests/runtime/snow_work_income_test.gd")
const Still = preload("res://tests/runtime/snow_south_road_test.gd")
## Maps drawn whole: a street, rooms full of shelves and people, a wild gorge.
const MAPS: Array[StringName] = [&"snow.inn.main_floor", &"snow.school2", &"snow.school", &"snow.hockshop", &"snow.square"]
var assertions: int = 0
var failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary:
	_test_shelf()
	_test_drumstick()
	_test_layers_and_exceptions()
	Shapes.keep_flushed = true
	_test_item_looks()
	_test_figures(tree)
	await _test_maps(tree)
	Shapes.keep_flushed = false
	Shapes.flushed.clear()
	return {"assertions": assertions, "failures": failures}


## The 空架子 as voxel_trade_props draws it: posts first, then boards as deep as the posts and
## running to their outer faces. The boards win; each post's face steps back where they meet.
func _test_shelf() -> void:
	var holder := Node3D.new()
	var shapes := Shapes.new()
	var w: float = 2.0
	var d: float = 0.5
	for x: float in [-w / 2 + 0.07, w / 2 - 0.07]:
		shapes.box(holder, Vector3(x, 1.4, 0), Vector3(0.14, 2.8, d), "8a6a48")
	for y: float in [0.18, 1.37, 2.8]:
		shapes.box(holder, Vector3(0, y, 0), Vector3(w, 0.12, d), "9b7851")
	_check(CoplanarFaces.fights(_drawn(shapes)).size() > 0, "drawn as written, the posts and boards fight")
	shapes.settle_coplanar()
	var after: Array[Dictionary] = _drawn(shapes)
	_check(CoplanarFaces.fights(after).is_empty(), "settled, nothing fights: %s" % [CoplanarFaces.fights(after)])
	var post: Transform3D = _box_of(shapes, "8a6a48", 0)
	var board: Transform3D = _box_of(shapes, "9b7851", 0)
	_check(board == Transform3D(Basis.from_scale(Vector3(w, 0.12, d)), Vector3(0, 0.18, 0)), "the board, drawn last, is as drawn")
	var size: Vector3 = post.basis.get_scale()
	_check(is_equal_approx(size.z, d - 2 * Shapes.COPLANAR_STEP) and is_equal_approx(size.x, 0.14 - Shapes.COPLANAR_STEP) and is_equal_approx(size.y, 2.8), "the post steps back its front, back and outer side by %.3f: %s" % [Shapes.COPLANAR_STEP, size])
	_check(is_equal_approx(post.origin.x - size.x / 2, -w / 2 + Shapes.COPLANAR_STEP) and is_equal_approx(post.origin.x + size.x / 2, -w / 2 + 0.14), "its inner side stays where it was")
	_check(shapes.stepped_faces == 6, "two posts, three faces each: %d" % shapes.stepped_faces)
	holder.free()


## The drumstick's crust, turned a quarter, is as high as the meat: its top wins.
func _test_drumstick() -> void:
	var holder := Node3D.new()
	var shapes := Shapes.new()
	shapes.box(holder, Vector3(0, 0.12, 0), Vector3(0.3, 0.38, 0.28), "b0602e")
	shapes.tilted_box(holder, Vector3(0, 0.16, 0), Vector3(0.26, 0.3, 0.3), "7e3c18:gloss", Vector3(0, PI / 4, 0))
	_check(CoplanarFaces.fights(_drawn(shapes)).size() == 1, "the turned crust and the meat share their tops: %s" % [CoplanarFaces.fights(_drawn(shapes))])
	shapes.settle_coplanar()
	var meat: Transform3D = _box_of(shapes, "b0602e", 0)
	_check(is_equal_approx(meat.origin.y + meat.basis.get_scale().y / 2, 0.31 - Shapes.COPLANAR_STEP), "the meat's top steps down under the crust's")
	_check(CoplanarFaces.fights(_drawn(shapes)).is_empty(), "and nothing fights")
	holder.free()


func _test_layers_and_exceptions() -> void:
	var holder := Node3D.new()
	var other := Node3D.new()
	var shapes := Shapes.new()
	# Three flat boards one over another in one plane: each earlier one a step further back.
	shapes.box(holder, Vector3(0, 0.5, 0), Vector3(1, 1, 1), "aa0000")
	shapes.box(holder, Vector3(0, 0.75, 0), Vector3(0.5, 0.5, 0.5), "00aa00")
	shapes.box(holder, Vector3(0, 0.9, 0), Vector3(0.2, 0.2, 0.2), "0000aa")
	# The same colour, touching side by side, another parent, a sheet too thin to step back.
	shapes.box(holder, Vector3(5, 0.5, 0), Vector3(1, 1, 1), "aa0000")
	shapes.box(holder, Vector3(5, 0.75, 0), Vector3(0.5, 0.5, 0.5), "aa0000")
	shapes.box(holder, Vector3(6, 0.5, 0), Vector3(1, 1, 1), "00aa00")
	shapes.box(other, Vector3(0, 0.75, 0), Vector3(0.5, 0.5, 0.5), "0000aa")
	shapes.box(holder, Vector3(8, 0.99925, 0), Vector3(0.5, 0.0015, 0.5), "f0f0f0")
	shapes.box(holder, Vector3(8, 0.5, 0), Vector3(1, 1, 1), "aa0000")
	shapes.settle_coplanar()
	var top := func(hex: String, index: int) -> float:
		var t: Transform3D = _box_of(shapes, hex, index)
		return t.origin.y + t.basis.get_scale().y / 2
	_check(is_equal_approx(top.call("0000aa", 0), 1.0) and is_equal_approx(top.call("00aa00", 0), 1.0 - Shapes.COPLANAR_STEP) and is_equal_approx(top.call("aa0000", 0), 1.0 - 2 * Shapes.COPLANAR_STEP), "three in one plane: the last on top, then one step, then two")
	_check(is_equal_approx(top.call("aa0000", 1), 1.0) and is_equal_approx(top.call("aa0000", 2), 1.0), "one colour over itself is left as it is")
	_check(_box_of(shapes, "00aa00", 1) == Transform3D(Basis.IDENTITY, Vector3(6, 0.5, 0)), "a box touching another side by side is left as it is")
	_check(_box_of(shapes, "0000aa", 1) == Transform3D(Basis.from_scale(Vector3(0.5, 0.5, 0.5)), Vector3(0, 0.75, 0)), "another place's box is never stepped")
	_check(_box_of(shapes, "f0f0f0", 0) == Transform3D(Basis.from_scale(Vector3(0.5, 0.0015, 0.5)), Vector3(8, 0.99925, 0)) and is_equal_approx(top.call("aa0000", 3), 1.0), "a sheet too thin to step back is left as it is")
	# A wall, a board on it and letters on the board in the wall's colour, all flush: the board
	# stays before the wall though the letters' colour is the wall's (the board stepped behind
	# the letters, and the wall must go behind the board, not stop beside it).
	var sign := Shapes.new()
	sign.box(holder, Vector3(20, 1, 0), Vector3(2, 2, 0.2), "aa0000")
	sign.box(holder, Vector3(20, 1, 0.05), Vector3(1, 1, 0.1), "00aa00")
	sign.box(holder, Vector3(20, 1, 0.075), Vector3(0.4, 0.4, 0.05), "aa0000")
	sign.settle_coplanar()
	var front := func(s: Shapes, hex: String, index: int) -> float:
		var t: Transform3D = _box_of(s, hex, index)
		return t.origin.z + t.basis.get_scale().z / 2
	_check(is_equal_approx(front.call(sign, "aa0000", 1), 0.1) and front.call(sign, "00aa00", 0) < 0.1 and front.call(sign, "aa0000", 0) < front.call(sign, "00aa00", 0) - Shapes.COPLANAR_STEP * 0.9, "letters before the board before the wall: %.4f %.4f %.4f" % [front.call(sign, "aa0000", 1), front.call(sign, "00aa00", 0), front.call(sign, "aa0000", 0)])
	# Three tiles in a row, each lapping the next: each later one before the one it laps.
	var row := Shapes.new()
	for i: int in 3:
		row.box(holder, Vector3(30 + i * 0.8, 0.5, 0), Vector3(1, 1, 1), ["aa0000", "00aa00", "0000aa"][i])
	row.settle_coplanar()
	var tile_top := func(hex: String) -> float:
		var t: Transform3D = _box_of(row, hex, 0)
		return t.origin.y + t.basis.get_scale().y / 2
	_check(tile_top.call("0000aa") > tile_top.call("00aa00") + Shapes.COPLANAR_STEP * 0.9 and tile_top.call("00aa00") > tile_top.call("aa0000") + Shapes.COPLANAR_STEP * 0.9, "each tile before the one drawn before it: %.4f %.4f %.4f" % [tile_top.call("aa0000"), tile_top.call("00aa00"), tile_top.call("0000aa")])
	# A turned box steps back too: the meat drawn turned under a square crust.
	var turned := Shapes.new()
	turned.tilted_box(holder, Vector3(40, 0.12, 0), Vector3(0.3, 0.38, 0.28), "b0602e", Vector3(0, PI / 4, 0))
	turned.box(holder, Vector3(40, 0.16, 0), Vector3(0.2, 0.3, 0.2), "7e3c18")
	turned.settle_coplanar()
	var meat: Transform3D = _box_of(turned, "b0602e", 0)
	_check(is_equal_approx(meat.origin.y + meat.basis.get_scale().y / 2, 0.31 - Shapes.COPLANAR_STEP) and CoplanarFaces.fights(_drawn(turned)).is_empty(), "a turned box's top steps down under a square one")
	# Settled on worker threads, a place to a thread: the same as at once.
	var at_once := Shapes.new()
	var threaded := Shapes.new()
	var places: Array[Node3D] = []
	for i: int in 6:
		places.append(Node3D.new())
	for s: Shapes in [at_once, threaded]:
		for i: int in 600:
			s.box(places[i % 6], Vector3(i % 20, 0.5, i / 20), Vector3(1, 1, 1), "aa0000")
			s.box(places[i % 6], Vector3(i % 20, 0.75, i / 20), Vector3(0.5, 0.5, 0.5), "00aa00")
	at_once.settle_coplanar()
	_check(threaded.settle_coplanar_in_background(), "there is something to settle")
	threaded.finish_settling()
	_check(threaded.settling_done() and at_once.stepped_faces == threaded.stepped_faces and at_once.stepped_faces == 600, "on worker threads, the same faces step back: %d / %d" % [at_once.stepped_faces, threaded.stepped_faces])
	var same: bool = true
	for key: Variant in at_once.batches:
		var mine: Dictionary = at_once.batches[key]
		var theirs: Dictionary = threaded.batches.get(key, {})
		same = same and theirs.get("transforms", []) == mine["transforms"]
	_check(same and at_once.batches.size() == threaded.batches.size(), "and every box is where it is when settled at once")
	_check(not Shapes.new().settle_coplanar_in_background(), "nothing drawn, nothing to wait for")
	for place: Node3D in places:
		place.free()
	holder.free()
	other.free()


## Every item's look, as the 背包 draws it.
func _test_item_looks() -> void:
	Shapes.flushed.clear()
	var looks: Dictionary = VoxelItemLook.all_looks()
	for id: String in looks:
		var model := Node3D.new()
		VoxelItemLook.build(model, looks[id])
		var found: PackedStringArray = CoplanarFaces.fights(Shapes.flushed, 3)
		_check(found.is_empty(), "%s's look has no faces that fight: %s" % [id, found])
		Shapes.flushed.clear()
		model.free()


## Every person's card, and every word a card may use.
func _test_figures(tree: SceneTree) -> void:
	var stage := Node3D.new()
	tree.root.add_child(stage)
	var looks: Dictionary = {}
	for region: String in DirAccess.get_directories_at("res://data"):
		if FileAccess.file_exists("res://data/%s/appearances.json" % region):
			var people: Dictionary = PersonLooks.region_cards(region)
			for id: String in people:
				looks[id] = people[id]
	for key: String in ["hair_style", "headwear", "beard", "waist", "prop"]:
		for word: String in {"hair_style": Person.HAIR_STYLES, "headwear": Person.HEADWEAR, "beard": Person.BEARDS, "waist": Person.WAISTS, "prop": Person.PROPS}[key]:
			looks["%s=%s" % [key, word]] = {key: word}
	for extra: String in Person.EXTRAS:
		looks["extra=" + extra] = {"extras": [extra]}
	for height: String in Person.HEIGHTS:
		looks["height=" + height] = {"height": height, "build": "heavy"}
	_check(looks.size() > 100, "many figures: %d" % looks.size())
	var fighting: Array[String] = []
	for id: String in looks:
		Shapes.flushed.clear()
		var figure: Node3D = Person.new()
		figure.configure(looks[id])
		stage.add_child(figure)
		var found: PackedStringArray = CoplanarFaces.fights(Shapes.flushed, 3)
		if not found.is_empty():
			fighting.append("%s: %s" % [id, found])
	_check(fighting.is_empty(), "no figure has faces that fight (%d): %s" % [fighting.size(), fighting.slice(0, 6)])
	Shapes.flushed.clear()
	stage.free()


## Whole maps, as the game draws them.
func _test_maps(tree: SceneTree) -> void:
	Shapes.flushed.clear()
	var session: WorldSessionController = Work.create_session(tree)
	session.configure_npc_ambience_random_source(Still.Still.new())
	await _frames(tree, 4)
	for zone_id: StringName in MAPS:
		var def: MapDefinition = GameContent.catalog().map(MapPlaces.map_of(zone_id))
		var map: WorldMapController = session.active_map() as WorldMapController
		if session.active_map_id() != def.map_id:
			Shapes.flushed.clear()
			map = MapPlaces.enter(session, zone_id, def.entry_spawn_id)
		_check(map != null, "enter %s" % zone_id)
		if map == null:
			continue
		var view := map.get_node("MapView") as WorldVoxelView
		var waited: int = 0
		while not view._built and waited < 2000:
			await tree.process_frame
			waited += 1
		_check(view._built and Shapes.flushed.size() > 50, "%s is drawn: %d batches" % [def.map_id, Shapes.flushed.size()])
		var found: PackedStringArray = CoplanarFaces.fights(Shapes.flushed, 40, true)
		_check(found.is_empty(), "%s has no faces that fight: %s" % [def.map_id, found])
	session.queue_free()
	await _frames(tree, 2)


## The boxes still waiting in `shapes`, as CoplanarFaces reads them.
func _drawn(shapes: Shapes) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for entry: Dictionary in shapes.batches.values():
		entries.append({"parent": entry["parent"], "color": entry["color"], "mesh": entry["mesh"], "transforms": entry["transforms"], "colors": PackedColorArray()})
	return entries


func _box_of(shapes: Shapes, hex: String, index: int) -> Transform3D:
	var seen: int = 0
	for entry: Dictionary in shapes.batches.values():
		if entry["color"] == hex:
			for t: Transform3D in entry["transforms"]:
				if seen == index:
					return t
				seen += 1
	return Transform3D()


func _frames(tree: SceneTree, count: int) -> void:
	for i: int in count:
		await tree.process_frame


func _check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures.append(message)
