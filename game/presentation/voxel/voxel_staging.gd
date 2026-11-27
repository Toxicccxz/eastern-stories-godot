class_name VoxelStaging
extends Node3D

## 过场动作 (过场演出 B; DECISIONS「过场动作」): how the voxel view shows what a scene's steps `do`
## and how its shots frame — read off the map's staging (WorldMapStaging) every frame:
## - a figure's pose (bowing, kneeling, on guard with its weapon, lying, hands out, giving,
##   taking), its shiver and its start; one rising out of the ground, one thinning away, one not
##   yet seen;
## - the small thing handed or tossed, in the air between two hands;
## - the shot: the camera's push-in for near / look / two / wide (where it looks is the map's
##   view_anchor()), never while a fight has the camera;
## - a 主线场面 a step plays by name (the view's VoxelStoryFx), its own trigger kept quiet.
## Presentation only: nobody is moved here, nothing is given and nobody leaves; with the feel's
## scene_action_ms at 0 the staging tells nothing and this does nothing.

const Person = preload("res://presentation/voxel/actors/voxel_person.gd")
const Shapes = preload("res://presentation/voxel/props/voxel_shapes.gd")

## What this changed on each figure and must give back: {y: the model's own height, scale: its
## own scale, guard: it was put on guard here, hops: the starts shown, puff: its dissolve began}.
var _touched: Dictionary[StringName, Dictionary] = {}
## The things in the air, by "from>to:item".
var _flying: Dictionary[String, Node3D] = {}
## The push-in the shot set (0: none: the camera is the map's own).
var _shot_zoom: float = 0.0
## The shot shown last, to tell a new one (a cut goes there at once).
var _shot_key: String = ""
var _rng := RandomNumberGenerator.new()
## The soft light over what a shot looks at (scene_stage.json `light`; null: none made yet).
var _lamp: OmniLight3D
## How many of each were shown (tests, kits): pose / flight / puff / hop / shot / fx.
var begun: Dictionary[String, int] = {}


func sync(view: WorldVoxelView, _delta: float) -> void:
	var stage: WorldMapStaging = view.map.staging
	var live: bool = stage.shows()
	if live or not _touched.is_empty():
		_figures(view, stage)
	if live or not _flying.is_empty():
		_flights(view, stage)
	_shot(view, stage)
	_light(view, stage, _delta)
	_fx(view, stage)


func _figures(view: WorldVoxelView, stage: WorldMapStaging) -> void:
	var depth: float = float(SceneStage.part("emerge").get("depth", 2.0))
	for id: StringName in view.actors:
		var actor: Node3D = view.actors[id]
		if not is_instance_valid(actor) or actor.get_child_count() == 0:
			continue
		var model: Node3D = actor.get_child(0) as Node3D
		var pose: StringName = stage.pose(id)
		var rise: float = stage.emerged(id)
		var thin: float = stage.dissolved(id)
		var shiver: bool = stage.shivers(id)
		var hops: int = stage.hops(id)
		var unseen: bool = stage.unseen(id)
		var staged: bool = not pose.is_empty() or rise < 1.0 or thin > 0.0 or shiver or hops > 0 or unseen
		if not staged and not _touched.has(id):
			continue
		var kept: Dictionary = _touched.get(id, {})
		if kept.is_empty():
			kept = {"y": model.position.y, "scale": model.scale, "guard": false, "hops": 0, "puff": false}
			_touched[id] = kept
		if unseen:
			actor.visible = false
		# Rising out of the ground: the figure comes up from under it.
		model.position.y = float(kept["y"]) - (1.0 - rise) * depth
		# Thinning away: it sinks and narrows to nothing, a puff of smoke rising where it stood.
		var own: Vector3 = kept["scale"]
		model.scale = own if thin <= 0.0 else Vector3(own.x * maxf(0.04, 1.0 - 0.8 * thin), own.y * maxf(0.03, 1.0 - thin), own.z * maxf(0.04, 1.0 - 0.8 * thin))
		if thin > 0.0 and not bool(kept["puff"]):
			kept["puff"] = true
			_puff(actor.position)
		if hops != int(kept["hops"]):
			kept["hops"] = hops
			if hops > 0 and view._touches() != null and view.touches.startle(model, null):
				begun["hop"] = int(begun.get("hop", 0)) + 1
		var person: Person = model as Person
		if person != null and person.stone.is_empty():
			var amount: float = stage.pose_amount(id)
			# On guard: its weapon out, as a fighter stands — unless a fight has the figure already.
			var guard: bool = pose == WorldMapStaging.POSE_GUARD
			if guard and not bool(kept["guard"]) and not person.fighting:
				kept["guard"] = true
				person.take_guard(stage.weapon_of(id), SceneStage.seconds(&"draw"))
				begun["pose"] = int(begun.get("pose", 0)) + 1
			elif not guard and bool(kept["guard"]):
				kept["guard"] = false
				if not _fights(view, id):
					person.stand_down(SceneStage.seconds(&"sheathe"))
			if pose == WorldMapStaging.POSE_FALL:
				person.limp = maxf(person.limp, WorldVoxelView.fall_turn(amount, true))
			var shown: String = String(pose) if Person.STAGED.has(String(pose)) else ""
			if shown != person.staged and not shown.is_empty():
				begun["pose"] = int(begun.get("pose", 0)) + 1
			person.staged = shown
			person.staged_amount = amount if not shown.is_empty() else 0.0
			person.staged_shiver = 0.012 if shiver else 0.0
		if not staged:
			_restore(model, kept, view, id)
			_touched.erase(id)
	# Who is gone took what was kept with it.
	for id: StringName in _touched.keys():
		if not view.actors.has(id):
			_touched.erase(id)


func _restore(model: Node3D, kept: Dictionary, view: WorldVoxelView, id: StringName = &"") -> void:
	if not is_instance_valid(model):
		return
	model.position.y = float(kept["y"])
	model.scale = kept["scale"]
	var person: Person = model as Person
	if person != null:
		person.staged = ""
		person.staged_amount = 0.0
		person.staged_shiver = 0.0
		if bool(kept["guard"]) and not _fights(view, id):
			person.stand_down(0.0)


## Whether a fight has `id`'s figure now (its guard is the fight's, not to be taken off here).
func _fights(view: WorldVoxelView, id: StringName) -> bool:
	if view.placing():
		return true
	var session: WorldSessionController = view.map.session
	if session != null and session.combat_encounter_coordinator().has_active_encounter():
		return true
	var npc: NpcRuntimeState = view.map.find_resident_npc(id)
	return npc != null and npc.relationship.is_fighting()


## The smoke of one thinning away (scene_stage.json `dissolve`).
func _puff(at: Vector3) -> void:
	var look: Dictionary = SceneStage.part("dissolve")
	var art: String = String(look.get("art", "vanish"))
	if not BattleArts.KINDS.has(art) or not is_inside_tree():
		return
	var tween: Tween = create_tween().set_parallel(true)
	var figure: Node3D = BattleArts.play(self, tween, art, Color(String(look.get("colour", "2c2430"))), at, at, maxf(0.2, SceneStage.seconds(&"dissolve")), _rng)
	if figure == null:
		tween.kill()
		return
	figure.scale = Vector3.ONE * maxf(0.1, float(look.get("scale", 1.0)))
	tween.chain().tween_callback(GrowthFx.drop.bind(figure))
	begun["puff"] = int(begun.get("puff", 0)) + 1


## The things handed or tossed: each from the giver's right hand to the other's left, straight or
## in an arc, shown as its item looks on the ground (smaller), else as a small dark thing.
func _flights(view: WorldVoxelView, stage: WorldMapStaging) -> void:
	var look: Dictionary = SceneStage.part("flight")
	var seen: Dictionary[String, bool] = {}
	for flight: Array in stage.flights():
		var key: String = "%s>%s:%s" % [flight[0], flight[1], flight[2]]
		var from: Vector3 = _hand(view, flight[0], 0)
		var to: Vector3 = _hand(view, flight[1], 1)
		if not from.is_finite() or not to.is_finite():
			continue
		seen[key] = true
		if not _flying.has(key) or not is_instance_valid(_flying[key]):
			_flying[key] = _thing(flight[2], float(look.get("size", 0.16)), String(look.get("colour", "2a2622")), String(look.get("glint", "")))
			begun["flight"] = int(begun.get("flight", 0)) + 1
		var t: float = clampf(float(flight[4]), 0.0, 1.0)
		var rise: float = float(look.get("toss_rise" if flight[3] == &"toss" else "hand_rise", 0.0))
		var node: Node3D = _flying[key]
		node.position = from.lerp(to, t) + Vector3.UP * rise * sin(t * PI)
		# A thing tossed turns over as it flies.
		node.rotation = Vector3(t * TAU * 1.5, t * TAU, 0.0) if flight[3] == &"toss" else Vector3.ZERO
	for key: String in _flying.keys():
		if not seen.has(key):
			if is_instance_valid(_flying[key]):
				_flying[key].queue_free()
			_flying.erase(key)


func _hand(view: WorldVoxelView, id: StringName, arm: int) -> Vector3:
	var actor: Node3D = view.actors.get(id)
	if not is_instance_valid(actor) or actor.get_child_count() == 0:
		return Vector3.INF
	var person: Person = actor.get_child(0) as Person
	return to_local(person.hand(arm)) if person != null else actor.position + Vector3.UP


## The thing shown in the air: the item's own look scaled to `size`, else a small box; with it a
## bright chip of `glint` (unshaded: seen whatever the room's light), "" for none.
func _thing(item_id: StringName, size: float, colour: String, glint: String) -> Node3D:
	var node := Node3D.new()
	node.name = "Flying"
	add_child(node)
	if glint.is_valid_html_color():
		var chip := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3.ONE * size * 0.8
		chip.mesh = mesh
		var lit := StandardMaterial3D.new()
		lit.albedo_color = Color(glint)
		lit.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		chip.material_override = lit
		chip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		chip.position = Vector3(0.0, size * 0.6, 0.0)
		node.add_child(chip)
	var data: Dictionary = VoxelItemLook.look(item_id)
	var model := Node3D.new()
	node.add_child(model)
	if not data.is_empty() and VoxelItemLook.build(model, data):
		var box: AABB = VoxelItemLook.bounds(model)
		var longest: float = maxf(box.size.x, maxf(box.size.y, box.size.z))
		if longest > 0.0:
			model.scale = Vector3.ONE * (size * 2.0 / longest)
			model.position = -box.get_center() * model.scale.x
	else:
		for child: Node in model.get_children():
			child.queue_free()
		var shapes := Shapes.new()
		shapes.box(model, Vector3.ZERO, Vector3(size * 0.5, size * 0.5, size * 1.6), colour)
		shapes.flush()
	return node


## The shot's push-in: set when the frame's zoom changes, given back when the shot is over. A
## fight has the camera (its stage, its placed figures): nothing is set and nothing given back.
func _shot(view: WorldVoxelView, stage: WorldMapStaging) -> void:
	var shots: Dictionary = SceneStage.part("shots")
	var frame: StringName = stage.shot_frame()
	var wanted: float = 0.0
	match frame:
		&"near":
			wanted = minf(view.rest_zoom, float(shots.get("near", 0.6)))
		&"look":
			wanted = minf(view.rest_zoom, float(shots.get("look", 0.72)))
		&"wide":
			wanted = maxf(view.rest_zoom, float(shots.get("wide", 1.0)))
		&"two":
			wanted = _two(view, stage.shot_points(), shots)
	if view.staged or view.placing():
		_shot_zoom = 0.0
		_shot_key = ""
		return
	var key: String = stage.shot_key()
	var cut: bool = String(shots.get("move", "pan")) == "cut"
	var fresh: bool = key != _shot_key
	if fresh:
		_shot_key = key
		if not key.is_empty():
			begun["shot"] = int(begun.get("shot", 0)) + 1
			# The shot frames the picture from here: a 主线场面's own push-in gives nothing back over it.
			if is_instance_valid(view.story_fx):
				view.story_fx.forget_zoom()
		if cut:
			view.cut_to_anchor()
	if not fresh and is_equal_approx(wanted, _shot_zoom):
		return
	_shot_zoom = wanted
	var target: float = wanted if wanted > 0.0 else view.rest_zoom
	if is_equal_approx(view.zoom(), target):
		return
	# A new shot eases there (or cuts); the same one following two who move keeps up frame by frame.
	view.set_zoom(target, maxf(0.0, float(shots.get("seconds", 0.7))) if fresh and not cut else 0.0)


## The soft light over what the shot looks at: up while a near, two or look shot is in force and
## no fight has the camera, down otherwise; it follows where the camera looks.
func _light(view: WorldVoxelView, stage: WorldMapStaging, delta: float) -> void:
	var look: Dictionary = SceneStage.part("light")
	var energy: float = float(look.get("energy", 0.0))
	var on: bool = energy > 0.0 and stage.shot_frame() in [&"near", &"two", &"look"] and not view.staged and not view.placing() and GraphicsQuality.stage_lights()
	if not on and not is_instance_valid(_lamp):
		return
	if not is_instance_valid(_lamp):
		_lamp = OmniLight3D.new()
		_lamp.name = "SceneLight"
		_lamp.light_color = Color(String(look.get("colour", "ffe6c4")))
		_lamp.omni_range = float(look.get("range", 7.0))
		_lamp.light_energy = 0.0
		_lamp.shadow_enabled = false
		# Its own energy: the map's lighting leaves it alone.
		_lamp.set_meta(&"own_energy", true)
		add_child(_lamp)
	_lamp.position = to_local(view.looked_at()) + Vector3.UP * float(look.get("height", 3.2))
	var seconds: float = maxf(0.05, float(look.get("seconds", 0.6)))
	_lamp.light_energy = move_toward(_lamp.light_energy, energy if on else 0.0, energy * delta / seconds)
	if not on and is_zero_approx(_lamp.light_energy):
		_lamp.queue_free()
		_lamp = null


## The light's energy now (tests): 0 with none.
func light_energy() -> float:
	return _lamp.light_energy if is_instance_valid(_lamp) else 0.0


## The push-in that keeps both of `points` (two spots of the 2D map) within the shot's share of
## the picture's width.
func _two(view: WorldVoxelView, points: PackedVector2Array, shots: Dictionary) -> float:
	if points.size() != 2 or view.camera == null:
		return 0.0
	var apart: float = VoxelMapGeometry.point(points[0]).distance_to(VoxelMapGeometry.point(points[1]))
	var picture: Vector2 = view.get_viewport().get_visible_rect().size if view.is_inside_tree() else Vector2(16, 9)
	var aspect: float = picture.x / maxf(1.0, picture.y)
	var width: float = view.base_size() * aspect * maxf(0.1, float(shots.get("two_fill", 0.5)))
	# Room for the two figures themselves beside the way between them.
	return clampf((apart + 2.0) / maxf(0.1, width), float(shots.get("two_min", 0.55)), maxf(view.rest_zoom, 1.0))


## The 主线场面 this scene's steps play: their own triggers kept quiet, each played as its step
## comes.
func _fx(view: WorldVoxelView, stage: WorldMapStaging) -> void:
	var claimed: Dictionary[String, bool] = stage.fx_claimed()
	if claimed.is_empty() and not is_instance_valid(view.story_fx):
		return
	var story: VoxelStoryFx = view.story_node()
	if story == null:
		return
	story.claimed = claimed
	if not stage.has_fx():
		return
	for name: String in stage.take_fx():
		var scenes: Dictionary = VoxelStoryFx.data().get("scenes", {})
		# Under a shot the scene's own push-in is left out: the shot frames it.
		if scenes.get(name) is Dictionary and story.play_named(name, scenes[name], view if stage.shot_frame().is_empty() else null):
			begun["fx"] = int(begun.get("fx", 0)) + 1
