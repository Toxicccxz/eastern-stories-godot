class_name VoxelTouches
extends Node3D

## 世界演出 (DECISIONS「世界演出」): the small motions of things touched on the map — a door's
## leaf swinging on its hinge as it opens or shuts, a thing picked up flying to the hand, one
## who notices the player starting, the splash of one wading (world_fx.json; times are shares of
## the feel's world_fx_ms). The view says what happened (it reads the 2D map); this only moves
## what the view drew. Presentation only: no door is opened here, nothing is taken, nobody moved.

## What a door's leaf carries for its swing (WorldVoxelView._make_shutters()): where it hangs
## shut, its turn there, and half its width along the wall (world units).
const DOOR_AT: StringName = &"door_at"
const DOOR_TURN: StringName = &"door_turn"
const DOOR_SPAN: StringName = &"door_span"

## How many of each were begun (tests, kits): door / pickup / startle / splash.
var begun: Dictionary[String, int] = {}
var _swings: Dictionary[StringName, Tween] = {}
var _drop: BoxMesh
var _wet: StandardMaterial3D
var _rng := RandomNumberGenerator.new()


## Seconds the motion `key` (world_fx.json: door / pickup / startle / wade) takes now; 0: not shown.
static func seconds(key: String) -> float:
	return GameContent.catalog().pacing().feel.world_fx_seconds * float(VoxelWeather.part(key).get("seconds", 1.0))


func swinging(id: StringName) -> bool:
	return _swings.has(id) and _swings[id].is_valid() and _swings[id].is_running()


## The door `id`'s `leaf` swings open (away from `from`, where the one who opened it stands) and
## is gone, or is there again and swings shut. False (nothing shown: the caller shows or hides
## it at once) with no time or a leaf that was not hung for it.
func swing_door(id: StringName, leaf: Node3D, open: bool, from: Vector3) -> bool:
	var lasts: float = seconds("door")
	if lasts <= 0.0 or leaf == null or not leaf.has_meta(DOOR_SPAN) or not is_inside_tree():
		return false
	if _swings.has(id) and _swings[id].is_valid():
		_swings[id].kill()
	var at: Vector3 = leaf.get_meta(DOOR_AT)
	var span: Vector3 = leaf.get_meta(DOOR_SPAN)
	# The free end goes to the far side from the one who opens it.
	var across: Vector3 = span.rotated(Vector3.UP, PI / 2.0).normalized()
	var side: float = -1.0 if (from - at).dot(across) > 0.0 else 1.0
	var far: float = side * float(VoxelWeather.part("door").get("swing", 1.45))
	leaf.visible = true
	# Where the swing begins, now: a door shutting is not seen shut for a frame first.
	_turn_door(0.0 if open else far, leaf)
	var tween: Tween = create_tween()
	_swings[id] = tween
	tween.tween_method(_turn_door.bind(leaf), 0.0 if open else far, far if open else 0.0, lasts).set_ease(Tween.EASE_OUT if open else Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.tween_callback(_rest_door.bind(leaf, open))
	begun["door"] = int(begun.get("door", 0)) + 1
	return true


## The leaf turned `angle` about its hinge (the end of its span it does not swing).
func _turn_door(angle: float, leaf: Variant) -> void:
	if not is_instance_valid(leaf):
		return
	var node := leaf as Node3D
	var at: Vector3 = node.get_meta(DOOR_AT)
	var span: Vector3 = node.get_meta(DOOR_SPAN)
	node.position = at - span + span.rotated(Vector3.UP, angle)
	node.rotation.y = float(node.get_meta(DOOR_TURN)) + angle


## The swing over: the leaf hangs shut where it was hung, seen only while the door is shut.
func _rest_door(leaf: Variant, open: bool) -> void:
	if is_instance_valid(leaf):
		_turn_door(0.0, leaf)
		(leaf as Node3D).visible = not open


## `node` (a thing that lay on the ground, the view's own drawing of it, no longer anyone's)
## flies in an arc to `hand` and is freed. False (the caller frees it) with no time.
func fly_to_hand(node: Node3D, hand: Vector3) -> bool:
	var lasts: float = seconds("pickup")
	if lasts <= 0.0 or node == null or not is_inside_tree():
		return false
	var title := node.get_node_or_null(^"Title") as Node3D
	if title != null:
		title.visible = false
	var from: Vector3 = node.position
	var tween: Tween = create_tween()
	tween.tween_method(_fly.bind(node, from, hand, float(VoxelWeather.part("pickup").get("rise", 0.7))), 0.0, 1.0, lasts)
	tween.tween_callback(_gone.bind(node))
	begun["pickup"] = int(begun.get("pickup", 0)) + 1
	return true


func _fly(t: float, node: Variant, from: Vector3, to: Vector3, rise: float) -> void:
	if is_instance_valid(node):
		(node as Node3D).position = from.lerp(to, t) + Vector3.UP * rise * sin(t * PI)
		(node as Node3D).scale = Vector3.ONE * lerpf(1.0, 0.25, t * t)


func _gone(node: Variant) -> void:
	if is_instance_valid(node):
		(node as Node).queue_free()


## `model` (a figure under its place on the map) starts: a small hop, its `mark` (the alert
## over its head, may be null) popping in. False with no time.
func startle(model: Node3D, mark: Node3D) -> bool:
	var lasts: float = seconds("startle")
	if lasts <= 0.0 or model == null or not is_inside_tree():
		return false
	var look: Dictionary = VoxelWeather.part("startle")
	var hop: Tween = create_tween()
	hop.tween_property(model, "position:y", float(look.get("hop", 0.2)), lasts * 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	hop.tween_property(model, "position:y", 0.0, lasts * 0.6).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	if mark != null:
		mark.scale = Vector3.ONE * float(look.get("pop", 1.8))
		var pop: Tween = create_tween()
		pop.tween_property(mark, "scale", Vector3.ONE, lasts).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	begun["startle"] = int(begun.get("startle", 0)) + 1
	return true


## A splash at `at` (the feet of one wading): a few pale drops flung up and out, falling back.
func splash(at: Vector3) -> bool:
	var lasts: float = seconds("wade")
	if lasts <= 0.0 or not is_inside_tree():
		return false
	var look: Dictionary = VoxelWeather.part("wade")
	if _drop == null:
		_drop = BoxMesh.new()
		_drop.size = Vector3.ONE * 0.07
		_wet = StandardMaterial3D.new()
		_wet.albedo_color = Color(String(look.get("colour", "dceef2")))
		_wet.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var burst := Node3D.new()
	burst.name = "Splash"
	burst.position = at
	add_child(burst)
	var rise: float = float(look.get("rise", 0.5))
	var spread: float = float(look.get("spread", 0.35))
	var tween: Tween = create_tween().set_parallel(true)
	for index: int in maxi(1, int(look.get("drops", 5))):
		var drop := MeshInstance3D.new()
		drop.mesh = _drop
		drop.material_override = _wet
		drop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		burst.add_child(drop)
		var angle: float = _rng.randf_range(0.0, TAU)
		var out := Vector3(cos(angle), 0.0, sin(angle)) * spread * _rng.randf_range(0.4, 1.0)
		tween.tween_method(_fling.bind(drop, out, rise * _rng.randf_range(0.6, 1.0)), 0.0, 1.0, lasts)
	tween.chain().tween_callback(_gone.bind(burst))
	begun["splash"] = int(begun.get("splash", 0)) + 1
	return true


func _fling(t: float, drop: Variant, out: Vector3, rise: float) -> void:
	if is_instance_valid(drop):
		(drop as Node3D).position = out * t + Vector3.UP * (0.05 + rise * sin(t * PI))
