class_name VoxelStoryFx
extends Node3D

## 主线场面 (DECISIONS「主线场面」): a short effect of its own over a key moment of the main
## story — the shade taking form at the dark altar, 穿灵 coming out of the seal, 璃虹's feather,
## 旋芒 leaving the whirlwind, 侮天鬼 standing up and going out (story_fx.json). The view asks
## look() a few times a second with what it reads off the player and the map; a scene whose
## trigger came true since the last look, in front of the player, is played once: layers of
## glowing blocks (the fight's arts and school figures, larger), a light, a jolt of the
## picture, a sound, and the camera a little nearer for a moment.
## Presentation only: it asks no act and no rule, holds nothing, and what it shows is gone when
## it is over.

const DATA_PATH: String = "res://data/common/story_fx.json"

static var _data: Dictionary = {}

## Each scene played here, newest last (tests, kits).
var played: Array[String] = []
## 过场演出 B (DECISIONS「过场动作」): the scenes a running 剧情演出 plays by name at a step of its
## own (the view hands them over from the map's staging): their own triggers stay quiet, so the
## moment is shown once, when the step comes.
var claimed: Dictionary[String, bool] = {}
## The scenes shown since the map was last shown (reset()): one is not shown twice.
var _shown: Dictionary[String, bool] = {}
## The view's camera (the jolt moves its picture, not its place).
var camera: Camera3D
## Whether each scene's trigger held at the last look; nothing before the first.
var _held: Dictionary[String, bool] = {}
var _seen: bool = false
var _jolt: float = 0.0
var _jolt_seconds: float = 0.0
var _jolt_left: float = 0.0
## Counts the times what was showing was cleared (reset()): a layer or a push-in still waiting
## from before does nothing.
var _round: int = 0
## The camera's push-in to give back ([view, the zoom before, the zoom set]); empty: none.
var _zoomed: Array = []
var _rng := RandomNumberGenerator.new()


## story_fx.json, read once.
static func data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		_data = parsed if parsed is Dictionary else {}
	return _data


## The scenes that play on the map `map_id`, by name.
static func scenes_for(map_id: StringName) -> Dictionary:
	var out: Dictionary = {}
	var scenes: Dictionary = data().get("scenes", {})
	for name: String in scenes:
		if scenes[name] is Dictionary and String(scenes[name].get("map", "")) == String(map_id):
			out[name] = scenes[name]
	return out


## Whether `scene`'s trigger holds: its `present` against the player's state (as a stage prop's),
## someone of its `npc` definition among `standing`, its `item` among `held`. One with no
## trigger never holds.
static func holds(scene: Dictionary, player: WorldPlayerRuntimeState, held: Dictionary[StringName, bool], worn: Dictionary[StringName, bool], phase_id: StringName, standing: Dictionary[StringName, bool]) -> bool:
	if not (scene.has("present") or scene.has("npc") or scene.has("item")):
		return false
	if scene.has("present") and not WorldStoryPresence.look_on_stage({"present": scene["present"]}, player, held, worn, phase_id):
		return false
	if scene.has("npc") and not standing.has(StringName(String(scene["npc"]))):
		return false
	return not scene.has("item") or held.has(StringName(String(scene["item"])))


## What was seen is forgotten: the next look only takes things in (a map just shown: what is
## true already happened before the player's eyes were here).
func reset() -> void:
	_held.clear()
	_shown.clear()
	_seen = false
	clear()


## What is showing is gone at once (a map left while a scene played and come back to): the
## figures and the light, the jolt, the camera's push-in given back.
func clear() -> void:
	_round += 1
	for child: Node in get_children():
		child.queue_free()
	if _jolt_left > 0.0 and is_instance_valid(camera):
		camera.h_offset = 0.0
		camera.v_offset = 0.0
	_jolt_left = 0.0
	_give_back_zoom(0.0)


## The names of `scenes` whose trigger came true since the last look. The first look tells none.
func look(scenes: Dictionary, player: WorldPlayerRuntimeState, held: Dictionary[StringName, bool], worn: Dictionary[StringName, bool], phase_id: StringName, standing: Dictionary[StringName, bool]) -> Array[String]:
	var came: Array[String] = []
	for name: String in scenes:
		var now: bool = holds(scenes[name], player, held, worn, phase_id, standing)
		# One a running scene plays at a step of its own, or has played, is not played by its trigger.
		if now and _seen and not _held.get(name, false) and not claimed.has(name) and not _shown.has(name):
			came.append(name)
		_held[name] = now
	_seen = true
	return came


## The scene `name` played because a 剧情演出's step names it (过场演出 B). False when it was
## shown already since the map was last shown (its trigger played it), or there is nothing to show.
func play_named(name: String, scene: Dictionary, view: WorldVoxelView = null) -> bool:
	if _shown.has(name):
		return false
	return play(name, scene, view)


## The scene `name` played at its place on the map: its layers, light, jolt and sound; `view`
## the map's view for the camera's push-in (null: none). False with nothing to show.
func play(name: String, scene: Dictionary, view: WorldVoxelView = null) -> bool:
	var layers: Array = scene.get("layers", [])
	if layers.is_empty() or not is_inside_tree():
		return false
	_shown[name] = true
	var at: Array = scene.get("at", [0, 0])
	var centre: Vector3 = VoxelMapGeometry.point(Vector2(float(at[0]), float(at[1])))
	for layer: Variant in layers:
		if layer is Dictionary:
			var begin: Tween = create_tween()
			begin.tween_interval(maxf(0.0, float(layer.get("delay", 0.0))))
			begin.tween_callback(_layer.bind(layer, centre, _round))
	var light: Dictionary = scene.get("light", {})
	# 画质 低 on a phone goes without the fight's lights (GraphicsQuality.stage_lights()): so here.
	if float(light.get("energy", 0.0)) > 0.0 and GraphicsQuality.stage_lights():
		var lamp := OmniLight3D.new()
		lamp.name = "StoryLight"
		lamp.light_color = Color(String(light.get("colour", "ffffff")))
		lamp.omni_range = float(light.get("range", 8.0))
		lamp.light_energy = 0.0
		lamp.shadow_enabled = false
		lamp.position = centre + Vector3.UP * 1.6
		# Its own energy: the map's lighting leaves it alone.
		lamp.set_meta(&"own_energy", true)
		add_child(lamp)
		var glow: Tween = create_tween()
		glow.tween_method(GrowthFx.light_step.bind(lamp, float(light["energy"])), 0.0, 1.0, maxf(0.1, float(light.get("seconds", 2.0))))
		glow.tween_callback(GrowthFx.drop.bind(lamp))
	var shake: Array = scene.get("shake", [])
	if shake.size() == 2:
		_jolt = float(shake[0])
		_jolt_seconds = maxf(0.05, float(shake[1]))
		_jolt_left = _jolt_seconds
	var sound: Array = scene.get("sound", [])
	if sound.size() == 3:
		BattleSounds.cue(StringName(String(sound[0])), float(sound[1]), float(sound[2]))
	var zoom: Array = scene.get("zoom", [])
	if zoom.size() == 3 and view != null and not view.placing() and _zoomed.is_empty():
		var before: float = view.zoom()
		var near: float = minf(before, float(zoom[0]))
		view.set_zoom(near, float(zoom[1]))
		_zoomed = [view, before, near]
		var back: Tween = create_tween()
		back.tween_interval(float(zoom[1]) + float(zoom[2]))
		back.tween_callback(_unzoom.bind(_round, float(zoom[1])))
	played.append(name)
	return true


## One layer begun at `centre`: a figure of the fight's arts or of the schools', at its scale.
func _layer(layer: Dictionary, centre: Vector3, round_begun: int) -> void:
	if round_begun != _round:
		return
	var seconds: float = maxf(0.1, float(layer.get("seconds", 1.5)))
	var colour := Color(String(layer.get("colour", "ffffff")))
	var tween: Tween = create_tween().set_parallel(true)
	var figure: Node3D = null
	if BattleArts.KINDS.has(String(layer.get("art", ""))):
		figure = BattleArts.play(self, tween, String(layer["art"]), colour, centre, centre, seconds, _rng)
	elif BattleSchoolMotifs.KINDS.has(String(layer.get("motif", ""))):
		figure = BattleSchoolMotifs.play(self, tween, String(layer["motif"]), colour, centre, Vector3.FORWARD, seconds, _rng)
	if figure == null:
		tween.kill()
		return
	figure.scale = Vector3.ONE * maxf(0.1, float(layer.get("scale", 1.0)))
	figure.set_meta(&"story", true)
	tween.chain().tween_callback(GrowthFx.drop.bind(figure))


## The push-in of the round `round_begun` is over: the camera goes back.
func _unzoom(round_begun: int, seconds: float) -> void:
	if round_begun == _round:
		_give_back_zoom(seconds)


## The camera back where it stood before the push-in — unless something else has it now (a fight,
## a training run: the zoom is no longer the one set here).
func _give_back_zoom(seconds: float) -> void:
	if _zoomed.is_empty():
		return
	var view: Variant = _zoomed[0]
	if is_instance_valid(view) and not (view as WorldVoxelView).placing() and is_equal_approx((view as WorldVoxelView).zoom(), float(_zoomed[2])):
		(view as WorldVoxelView).set_zoom(float(_zoomed[1]), seconds)
	_zoomed = []


## How many figures and lights are up now (tests).
func showing() -> int:
	return get_child_count()


func _process(delta: float) -> void:
	if _jolt_left <= 0.0 or not is_instance_valid(camera):
		return
	_jolt_left -= delta
	if _jolt_left <= 0.0:
		camera.h_offset = 0.0
		camera.v_offset = 0.0
		return
	# The picture jolts, less and less; its place on the map is the view's own.
	var reach: float = _jolt * _jolt_left / _jolt_seconds
	camera.h_offset = _rng.randf_range(-reach, reach)
	camera.v_offset = _rng.randf_range(-reach, reach)


func _exit_tree() -> void:
	if is_instance_valid(camera) and _jolt_left > 0.0:
		camera.h_offset = 0.0
		camera.v_offset = 0.0
	_jolt_left = 0.0
