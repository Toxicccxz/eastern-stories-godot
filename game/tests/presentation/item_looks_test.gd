extends RefCounted

## Every thing the player can carry has a voxel look (owner, 2026-11-04: a picture on its
## 背包 row and a turning one beside the list): a kind the item props files draw, colours that
## parse, and no look for an item that does not exist. A new item fails here until its look is
## written in game/data/common/item_looks.json.
var assertions: int = 0
var failures: Array[String] = []

## Keys that name a form, not a colour (the others with text values are colours).
const WORD_KEYS: Array[String] = ["kind", "style", "shape", "head", "pattern"]


func run_all(_tree: SceneTree) -> Dictionary:
	_test_every_carried_item_has_a_look()
	_test_no_look_without_its_item()
	_test_colours_parse()
	_test_derived_forms()
	_test_framing()
	_test_views()
	return {"assertions": assertions, "failures": failures}


func _test_every_carried_item_has_a_look() -> void:
	var missing: Array[String] = []
	var undrawn: Array[String] = []
	for content: ItemContentDefinition in GameContent.catalog().items():
		if content.no_get:
			continue
		var id: String = String(content.item_definition_id)
		# A form the catalog makes of another item (`<id>#broken`) looks like that item.
		var look: Dictionary = VoxelItemLook.look(content.item_definition_id)
		if look.is_empty():
			missing.append(id)
			continue
		var model := Node3D.new()
		if not VoxelItemLook.build(model, look):
			undrawn.append("%s (%s)" % [id, look.get("kind", "no kind")])
		model.free()
	_check(missing.is_empty(), "every carried item has a look in item_looks.json; missing: %s" % [missing])
	_check(undrawn.is_empty(), "every look's kind is drawn by an item props file: %s" % [undrawn])


func _test_no_look_without_its_item() -> void:
	var strays: Array[String] = []
	for id: String in VoxelItemLook.all_looks():
		if GameContent.catalog().item(StringName(id)) == null:
			strays.append(id)
	_check(strays.is_empty(), "every look names an item: %s" % [strays])


func _test_colours_parse() -> void:
	var bad: Array[String] = []
	for id: String in VoxelItemLook.all_looks():
		var look: Dictionary = VoxelItemLook.all_looks()[id]
		for key: String in look:
			var value: Variant = look[key]
			if key in WORD_KEYS or not value is String:
				continue
			var hex: String = String(value).get_slice(":", 0)
			var suffix: String = String(value).get_slice(":", 1) if String(value).contains(":") else ""
			if not hex.is_valid_html_color() or hex.length() != 6 or not suffix in ["", "gloss", "glow"]:
				bad.append("%s.%s=%s" % [id, key, value])
	_check(bad.is_empty(), "colours are 6-digit hex with an optional :gloss or :glow: %s" % [bad])


## A 断掉的 blade looks like its blade, snapped; other catalog-made forms like their item.
func _test_derived_forms() -> void:
	var sword: String = ""
	for id: String in VoxelItemLook.all_looks():
		if VoxelItemLook.all_looks()[id].get("kind", "") == "sword":
			sword = id
			break
	if not _check(not sword.is_empty(), "a sword to break"):
		return
	var broken: Dictionary = VoxelItemLook.look(StringName(sword + ItemContentDefinition.BROKEN_SUFFIX))
	_check(broken.get("kind", "") == "sword" and broken.get("broken", false), "a broken form keeps its kind and snaps: %s" % [broken])
	_check(not VoxelItemLook.look(StringName(sword)).has("broken"), "the whole one is not broken")
	var whole := Node3D.new()
	var snapped := Node3D.new()
	VoxelItemLook.build(whole, VoxelItemLook.look(StringName(sword)))
	VoxelItemLook.build(snapped, broken)
	_check(VoxelItemLook.bounds(snapped).size.y < VoxelItemLook.bounds(whole).size.y * 0.8, "the snapped blade is shorter")
	whole.free()
	snapped.free()
	_check(VoxelItemLook.look(&"es2:no/such/item").is_empty(), "no look for an unknown item")


## The picture's camera takes in the whole thing, still or turning, and a long thing leans.
func _test_framing() -> void:
	var viewport := SubViewport.new()
	var pivot: Node3D = VoxelItemLook.furnish(viewport)
	var camera := viewport.get_node("Stage/Camera") as Camera3D
	var model := Node3D.new()
	pivot.add_child(model)
	VoxelItemLook.build(model, {"kind": "sword"})
	VoxelItemLook.frame(pivot, model, camera, false)
	_check(is_equal_approx(model.rotation.z, -PI / 4) and camera.size > 0.5 and camera.size < 1.4, "a still sword leans and fills the picture: size %.2f" % camera.size)
	VoxelItemLook.frame(pivot, model, camera, true)
	_check(is_zero_approx(model.rotation.z) and camera.size >= VoxelItemLook.bounds(model).size.y * VoxelItemLook.MARGIN * cos(VoxelItemLook.PITCH) * 0.99, "a turning sword stands and stays in the picture: size %.2f" % camera.size)
	viewport.free()


## The 背包's turning picture builds the look it is given and keeps one model; without a
## renderer there are no row pictures, and asking for one queues nothing.
func _test_views() -> void:
	var view := ItemModelView.new(120)
	view.show_item(&"es2:obj/money/silver")
	var stage: Node = view.get_child(0).get_node("Stage")
	var pivot: Node3D = stage.get_node("Pivot") as Node3D
	var camera := stage.get_node("Camera") as Camera3D
	_check(view.shown == &"es2:obj/money/silver" and pivot.get_child_count() == 1 and camera.size > 0.0, "the turning picture holds the silver, framed")
	view.show_item(&"es2:obj/money/gold")
	_check(pivot.get_child_count() == 1 or (pivot.get_child_count() == 2 and pivot.get_child(0).is_queued_for_deletion()), "another thing replaces it")
	view.show_item(&"")
	_check(view.shown.is_empty(), "nothing read: no picture")
	view.free()
	var icons := ItemIcons.new()
	_check(ItemIcons.drawing() or icons.icon(&"es2:obj/money/coin") == null, "no renderer: no row picture")
	icons.free()


func _check(ok: bool, label: String) -> bool:
	assertions += 1
	if not ok:
		failures.append("item looks: " + label)
	return ok
