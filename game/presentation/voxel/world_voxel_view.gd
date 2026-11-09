class_name WorldVoxelView
extends Node

## A 3D presentation of an existing physical map. It never moves actors, takes exits,
## grants items or changes a rule. Runtime bodies remain the single position authority.
const Person = preload("res://presentation/voxel/actors/voxel_person.gd")
const Crawler = preload("res://presentation/voxel/actors/voxel_crawler.gd")
const Snake = preload("res://presentation/voxel/actors/voxel_snake.gd")
const Flyer = preload("res://presentation/voxel/actors/voxel_flyer.gd")
const Town = preload("res://presentation/voxel/props/voxel_town.gd")
const Shapes = preload("res://presentation/voxel/props/voxel_shapes.gd")
const VIEW_ROTATION_SECONDS: float = 0.6
const VIEW_SIDE_ANGLE: float = PI/4.0
const VIEW_RADIUS: float = 30.0
## The camera's height over what it looks at (with VIEW_RADIUS, the map's own pitch, about 41°).
const VIEW_HEIGHT: float = 26.0
## The exits' amber: the arrow over each way out and the frame round it on the ground.
const EXIT_GLOW: String = "f2a43a:glow"
## The exit arrows' size against the arrow as built (owner, 2026-11-09: smaller).
const ARROW_SCALE: float = 0.6
## The quest marker's arrow over a way out, against an exit arrow: a little larger, it stands in its place.
const QUEST_ARROW_SCALE: float = 1.25
## The quest marker over a person: a small red arrow turning over their head (radians a second).
const QUEST_SPIN: float = 2.4
@export_file("*.json") var layout_path: String
var map: WorldMapController
## 第十章 A: the guiding wind as shown, easing toward the rule's (WorldMapWinds.vector()).
var _wind_shown: Vector2 = Vector2.ZERO
var camera: Camera3D
var world: Node3D
var geometry: VoxelMapGeometry
var occlusion := VoxelOcclusion.new()
var layout: Dictionary
var lighting := VoxelLighting.new()
## A frame held for a suite or a kit (set_frame()); "" follows the 昼夜 setting and the DayClock.
var held_frame: String = ""
## A cloud level held for a kit (set_cloud()); -1 follows the session's SkyState.
var held_cloud: int = -1
var left_view: bool = false
var actors: Dictionary[StringName, Node3D] = {}
var labels: Dictionary[StringName, Label3D] = {}
## 战斗拍数 C (DECISIONS「战斗拍数 C」): the camera's size as the layout set it, and the fight's
## push-in over it (set_zoom(); 1.0: the layout's). The picture only: nothing of the map moves.
var _camera_base_size: float = 24.0
var _zoom: float = 1.0
var _zoom_tween: Tween
## 战斗演出 B (DECISIONS「战斗演出 B」): the view staged for a show (a fight's opening) — the camera
## eased onto `_stage_target` instead of the player (_stage_blend 0 → 1), lower over it
## (_view_height under VIEW_HEIGHT: a flatter pitch), the exit arrows and the quest marker away.
## The picture only: the 2D map, the bodies and every rule stay as they are; unstage() gives the
## camera back. While staged the player stands (a fight holds them).
var staged: bool = false
var _stage_target: Vector3 = Vector3.ZERO
var _stage_blend: float = 0.0
var _view_height: float = VIEW_HEIGHT
var _stage_tween: Tween
## 战斗演出 D (DECISIONS「战斗演出 D」): figures shown somewhere other than their bodies (on a stage
## raised over the map): id -> [where Vector3, facing yaw]. Each is drawn between its body's point
## and that place by `placed_blend` (0 at its body, 1 there), facing that way while placed; while any
## is placed, no name over a head (战斗演出 E: the battle's name plates stand for the placed ones) and
## nothing on the floor is named (the map is the backdrop then). The body, its collision and
## everything saved stay where they are.
var _placed: Dictionary[StringName, Array] = {}
var placed_blend: float = 0.0
## The red marks over the heads of NPCs whose 2D body shows its AlertMark (进门一起上).
var alert_marks: Dictionary[StringName, Label3D] = {}
var objects: Dictionary[StringName, Node3D] = {}
var entrances: Dictionary[StringName, Dictionary] = {}
var shutters: Dictionary[StringName, Node3D] = {}
## A door look's `open` look, shown instead of the shut one while its door is open (the
## pawnshop's leaves swung back with their 当 still read from the street).
var opened: Dictionary[StringName, Node3D] = {}
## The bobbing triangle over every exit (owner's map rule 2): a passage's points out of
## its room, a door's away from the side the player stands on.
var arrows: Dictionary[StringName, Node3D] = {}
var _arrow_clock: float = 0.0
## The quest marker (任务系统; DECISIONS「任务系统」「箭头」): a vermilion arrow with a 「目标」
## label in place of the amber one over the way out that leads towards the tracked quest's
## target map (WorldRoute), or, on that map, a small red arrow turning over the head of the one
## the step is about (else over the target zone). Presentation only: it reads the quest state and
## the 2D map and changes nothing.
const QUEST_GLOW: String = "d9452c"
var quest_marker: Node3D
## What the marker was placed for ("" none): the target and the quest ledger's size.
var _quest_key: String = ""
var _built: bool = false
## _build() is going on over several frames behind the loading screen (DECISIONS「加载画面」).
var _building: bool = false
var _active: bool = false
var _old_modulate: Color = Color.WHITE
var _old_msaa: Viewport.MSAA = Viewport.MSAA_DISABLED
var _target: Vector3
var _offset := Vector3(21.213203,26,21.213203)
var _view_yaw: float = VIEW_SIDE_ANGLE
var _turn_from: float = VIEW_SIDE_ANGLE
var _turn_elapsed: float = VIEW_ROTATION_SECONDS
var _cutaway_left: bool = false
var _last_player: Vector2 = Vector2.INF
## A scene's camera pans (DECISIONS「剧情演出」) and pans back to the player after it.
var _panning: bool = false
var _context_names: bool = false

func _ready() -> void:
	map = get_parent() as WorldMapController
	process_priority = -20

func _exit_tree() -> void:
	_deactivate()
	if _building:
		release_world()

func _process(delta: float) -> void:
	if map == null or map.player_body == null or not map.player_body.player_controlled:
		_deactivate()
		return
	if not _built:
		if _building:
			geometry.next_slice.emit()
		else:
			_build()
		if not _built:
			return
	if not _active:
		_activate()
	_advance_view_rotation(delta)
	_follow(delta)
	_sync_actors(delta)
	_sync_objects()
	geometry.sync_passages(map)
	_reveal_entrances()
	_bob_arrows(delta)
	_sync_quest_marker()
	_update_occlusion()
	_sync_light()
	lighting.advance(delta,VoxelMapGeometry.point(map.player_body.global_position))
	geometry.water.set_dusk(lighting.weights["dusk"])
	_sync_wind(delta)
	if geometry.foliage != null:
		geometry.foliage.advance(delta, _plant_contacts())
	geometry.ambience.night = lighting.amount
	geometry.ambience.advance(delta)

## 第十章 A (DECISIONS「风」): a map's guiding wind (WorldMapWinds) shown: the long grass leans along
## it, hard in a gust, upright in the calm, wild when it veers; the dust that follows it drifts. The
## direction eases round (presentation only; the rule is the 2D map's).
func _sync_wind(delta: float) -> void:
	if map.winds.wind() == null:
		return
	var target: Vector2 = map.winds.vector()
	if map.winds.gusty():
		target = target.rotated(sin(Time.get_ticks_msec()/180.0)*1.2)
	_wind_shown = _wind_shown.lerp(target, clampf(delta*1.6, 0.0, 1.0))
	geometry.ambience.guiding_wind = _wind_shown
	if geometry.foliage != null and geometry.foliage.material != null:
		var strength: float = _wind_shown.length()
		geometry.foliage.material.set_shader_parameter("gust", 0.05 + strength*(1.3 if map.winds.gusty() else 0.9))
		if strength > 0.05:
			geometry.foliage.material.set_shader_parameter("gust_dir", _wind_shown.normalized())


## With the feel's map_loading_slice_ms this goes on over several frames, the session held and
## the loading screen over it; otherwise it is over when it returns. Either way the same world.
func _build() -> void:
	var slice: float = GameContent.catalog().pacing().feel.map_loading_slice_seconds
	var covered: bool = slice > 0.0 and map.session != null
	_building = covered
	if covered:
		map.session.set_world_building(true)
	layout = JSON.parse_string(FileAccess.get_file_as_string(layout_path))
	layout["flora"] = VoxelMapGeometry.merge_flora(_region_file("flora.json"),layout.get("flora",{}))
	_judge_config_props()
	world = Node3D.new()
	world.name = "VoxelWorld"
	add_child(world)
	geometry = VoxelMapGeometry.new()
	geometry.slice_usec = roundi(slice*1000000.0) if covered else 0
	world.add_child(geometry)
	# The screen goes dark first: the first long piece of work comes after a frame of it.
	await geometry.breathe(true)
	await geometry.make(map,layout)
	geometry.set_view_side(_cutaway_left)
	camera = Camera3D.new()
	# This camera is already smoothed in _process; engine physics interpolation would
	# interpolate its first projection from a stale transform during map handoff.
	camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera_base_size = float(layout.get("camera_size",24.0))
	camera.size = _camera_base_size*_zoom
	camera.near = 0.1
	camera.far = 160.0
	world.add_child(camera)
	camera.position = _offset
	camera.look_at(Vector3.ZERO,Vector3.UP)
	_make_entrances()
	_make_shutters()
	await geometry.breathe()
	for entry: Dictionary in geometry.occluders:
		occlusion.register(entry["node"])
		await geometry.breathe()
	for shutter: Node3D in shutters.values()+opened.values():
		occlusion.register(shutter)
	await geometry.breathe()
	var indoor: bool = layout.get("indoor",false)
	lighting.build(world,occlusion,indoor,VoxelLighting.merge_profile(_region_light(indoor),layout.get("light",{})))
	_sync_light(true)
	_built = true
	_building = false
	if covered:
		map.session.set_world_building(false)

## Frees the built world (the session keeps only the last `voxel_worlds_kept` maps' worlds,
## DECISIONS「固定俯视体素地图」): every 3D node, the occlusion materials and the lights go;
## the chosen side, the held frame and the camera's yaw stay. Nothing of the 2D map, its
## bodies or the save changes. The next _process() on this map builds it again as at first.
## A build under way stops with it (the map left the tree meanwhile): it waits on the geometry,
## which goes too, and the next _process() here begins again.
## The config's own staged props (DECISIONS「舞台道具」) judged against the player before the build.
func _judge_config_props() -> void:
	if map == null or map.session == null or map.session.player_runtime() == null:
		return
	var session: WorldSessionController = map.session
	var player: WorldPlayerRuntimeState = session.player_runtime() as WorldPlayerRuntimeState
	for prop: Dictionary in layout.get("props",[]):
		if WorldStoryPresence.is_staged_look(prop):
			prop["staged_off"] = not WorldStoryPresence.look_on_stage(prop,player,session.player_held_item_ids(),session.player_worn_item_ids(),session.day_phase_id())

## The stage judged again (WorldStoryPresence.stage()): each staged prop shown or hidden as it now stands.
func restage() -> void:
	if not _built or geometry == null or map == null or map.session == null or map.session.player_runtime() == null:
		return
	var session: WorldSessionController = map.session
	var player: WorldPlayerRuntimeState = session.player_runtime() as WorldPlayerRuntimeState
	for entry: Dictionary in geometry.staged_props:
		(entry["node"] as Node3D).visible = WorldStoryPresence.look_on_stage(entry["look"],player,session.player_held_item_ids(),session.player_worn_item_ids(),session.day_phase_id())

func release_world() -> void:
	if not _built and not _building:
		return
	if _building:
		_building = false
		map.session.set_world_building(false)
	_deactivate()
	actors.clear()
	labels.clear()
	alert_marks.clear()
	objects.clear()
	entrances.clear()
	shutters.clear()
	opened.clear()
	arrows.clear()
	if quest_marker != null:
		quest_marker.queue_free()
	quest_marker = null
	_quest_key = ""
	occlusion = VoxelOcclusion.new()
	lighting.release()
	geometry = null
	camera = null
	if _zoom_tween != null and _zoom_tween.is_valid():
		_zoom_tween.kill()
	_zoom = 1.0
	if _stage_tween != null and _stage_tween.is_valid():
		_stage_tween.kill()
	staged = false
	_stage_blend = 0.0
	_view_height = VIEW_HEIGHT
	release_placed()
	remove_child(world)
	world.queue_free()
	world = null
	layout = {}
	_last_player = Vector2.INF
	_built = false

## A region-wide default beside the map's config (data/<region>/voxel/<name>); {} without one.
func _region_file(name: String) -> Dictionary:
	var path: String = layout_path.get_base_dir().path_join(name)
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}

## The region's default light (data/<region>/voxel/light.json, DECISIONS「昼夜」): its
## "outdoor" or "indoor" section, under the layout's own `light`.
func _region_light(indoor: bool) -> Dictionary:
	var section: Variant = _region_file("light.json").get("indoor" if indoor else "outdoor",{})
	return section if section is Dictionary else {}

## Where the light comes from: a held frame, else the 昼夜 setting (一直白天 / 一直夜晚),
## else the session's DayClock.
func _sync_light(immediate: bool = false) -> void:
	var hold: Dictionary = layout.get("hold",{})
	var frame: String = held_frame if not held_frame.is_empty() else String(hold.get("frame",""))
	if not frame.is_empty():
		lighting.set_frame(frame,immediate)
	elif DayNightPreference.mode == DayNightPreference.Value.DAY:
		lighting.set_frame("day",immediate)
	elif DayNightPreference.mode == DayNightPreference.Value.NIGHT:
		lighting.set_frame("night",immediate)
	elif map != null and map.session != null:
		lighting.set_time(map.session.day_clock().day_minutes(),immediate)
	else:
		lighting.set_frame("day",immediate)
	# The cloud (DECISIONS「天气」) is the world's whatever the setting holds the hour at.
	var cloud: int = held_cloud if held_cloud >= 0 else int(hold.get("cloud",-1))
	if cloud >= 0:
		lighting.set_cloud_level(cloud,immediate)
	elif map != null and map.session != null:
		lighting.set_cloud_level(map.session.sky_level(),immediate)
	else:
		lighting.set_cloud_level(0,immediate)

func _activate() -> void:
	_old_modulate = map.modulate
	map.modulate.a = 0.0
	_old_msaa = get_viewport().msaa_3d
	get_viewport().msaa_3d = Viewport.MSAA_4X
	(map.player_body.get_node("Camera2D") as Camera2D).enabled = false
	world.visible = true
	camera.current = true
	_target = VoxelMapGeometry.point(map.player_body.global_position,0.7)
	_active = true
	map.projected_view = true
	set_view_side(left_view,true)

func _update_movement_basis() -> void:
	var right := Vector2(camera.basis.x.x,camera.basis.x.z).normalized()
	var down := Vector2(camera.basis.z.x,camera.basis.z.z).normalized()
	map.player_body.movement_basis = Transform2D(right,down,Vector2.ZERO)

func _deactivate() -> void:
	if not _active:
		return
	_active = false
	map.projected_view = false
	map.modulate = _old_modulate
	map.player_body.movement_basis = Transform2D.IDENTITY
	world.visible = false
	# Leaving by a passage removes the map: its camera has left the tree before this
	# view's _exit_tree, so restore unless another map's 3D view already took over.
	var viewport: Viewport = get_viewport()
	var other: Camera3D = null if viewport == null else viewport.get_camera_3d()
	if viewport != null and (other == null or other == camera):
		if camera.is_inside_tree():
			camera.current = false
		viewport.canvas_transform = Transform2D.IDENTITY
		viewport.msaa_3d = _old_msaa

## Holds `frame` (DayPhaseDefinition.FRAMES) whatever the clock and setting say; "" lets go.
## For suites and kits: the game's own light follows the 昼夜 setting.
func set_frame(frame: String, immediate: bool = false) -> void:
	held_frame = frame
	if _built:
		_sync_light(immediate)

## Day or night held (the older two-frame call).
func set_night(enabled: bool, immediate: bool = false) -> void:
	set_frame("night" if enabled else "day",immediate)

## Holds the cloud at `level` (SkyState's 0 .. 4) whatever the session's sky says; -1 lets go.
## For kits: the game's own cloud follows the session.
func set_cloud(level: int, immediate: bool = false) -> void:
	held_cloud = level
	if _built:
		_sync_light(immediate)

## Orbit between two fixed angles, sharing the same height and distance to the player.
## Nothing in the map, reach, collision or saved location rotates with the camera.
func set_view_side(left: bool, immediate: bool = false) -> void:
	left_view = left
	_turn_from = _view_yaw
	_turn_elapsed = 0.0
	# A new/reactivated map inherits the chosen side without replaying a stale turn.
	if immediate or not _active:
		_advance_view_rotation(VIEW_ROTATION_SECONDS)
		if _active:
			_follow(0.0)
			_update_occlusion()

func _advance_view_rotation(delta: float) -> void:
	if _turn_elapsed>=VIEW_ROTATION_SECONDS:
		return
	_turn_elapsed = minf(_turn_elapsed+delta,VIEW_ROTATION_SECONDS)
	var progress: float = smoothstep(0.0,1.0,_turn_elapsed/VIEW_ROTATION_SECONDS)
	_view_yaw = lerpf(_turn_from,-VIEW_SIDE_ANGLE if left_view else VIEW_SIDE_ANGLE,progress)
	_offset = Vector3(sin(_view_yaw)*VIEW_RADIUS,_view_height,cos(_view_yaw)*VIEW_RADIUS)
	# Swap the cutaway when the camera crosses the centre, not when the button is hit.
	var near_left: bool = _view_yaw<0.0
	if near_left!=_cutaway_left:
		_cutaway_left = near_left
		if _built:
			geometry.set_view_side(near_left)

func _follow(delta: float) -> void:
	# Large changes are placements/arrivals; never pan across the whole map after restore.
	# A scene's camera pans to whoever speaks and back to the player once it is over.
	var at: Vector2 = map.view_anchor()
	var wanted: Vector3 = VoxelMapGeometry.point(at,0.7)
	if map.scene_running():
		_panning = true
	if _panning:
		_target = _target.lerp(wanted,1.0-exp(-delta*5.0))
		if not map.scene_running() and _target.distance_to(wanted)<0.3:
			_panning = false
	elif not _last_player.is_finite() or at.distance_to(_last_player)>96:
		_target = wanted
	else:
		_target = _target.lerp(wanted,1.0-exp(-delta*8.0))
	_last_player = at
	_offset.y = _view_height
	var looked: Vector3 = _target.lerp(_stage_target,_stage_blend) if _stage_blend > 0.0 else _target
	camera.position = looked+_offset
	camera.look_at(looked,Vector3.UP)
	_update_movement_basis()
	# Reproject on resize; orientation stays fixed between explicit side switches.
	var zero: Vector2 = camera.unproject_position(Vector3.ZERO)
	var projection := Transform2D(
		camera.unproject_position(Vector3.RIGHT/VoxelMapGeometry.UNIT)-zero,
		camera.unproject_position(Vector3.BACK/VoxelMapGeometry.UNIT)-zero,zero)
	# A minimized/new viewport can briefly have no projectable area. Keep the last
	# valid transform rather than hand the UI an uninvertible canvas for that frame.
	if absf(projection.determinant())<0.000001:
		return
	map.view_ground = projection
	map.view_up = camera.unproject_position(Vector3.UP/VoxelMapGeometry.UNIT)-zero
	get_viewport().canvas_transform = map.view_ground

## 战斗拍数 C: the camera pushes in to `factor` of the layout's size (below 1: nearer) over
## `seconds` (0: at once); 1.0 brings it back. The ground's projection follows in _follow().
func set_zoom(factor: float, seconds: float = 0.0) -> void:
	_zoom = clampf(factor,0.3,1.0)
	if _zoom_tween != null and _zoom_tween.is_valid():
		_zoom_tween.kill()
	if camera == null:
		return
	if seconds <= 0.0:
		camera.size = _camera_base_size*_zoom
		return
	_zoom_tween = create_tween()
	_zoom_tween.tween_property(camera,"size",_camera_base_size*_zoom,seconds).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

## The camera's push-in now (1.0: the layout's size).
func zoom() -> float:
	return _zoom

## 战斗演出 B: the camera eases onto `target` (a point in the world), `height` over it (the pitch:
## atan(height / VIEW_RADIUS)) and pushed in to `zoom_factor`, over `seconds` (0: at once).
func stage(target: Vector3, height: float, zoom_factor: float, seconds: float) -> void:
	staged = true
	_stage_target = target
	_ease_stage(1.0, height, seconds)
	set_zoom(zoom_factor, seconds)

## The camera back on the player at the map's own pitch and size over `seconds`.
func unstage(seconds: float) -> void:
	staged = false
	if quest_marker != null:
		quest_marker.visible = true
	_ease_stage(0.0, VIEW_HEIGHT, seconds)
	set_zoom(1.0, seconds)

func _ease_stage(blend: float, height: float, seconds: float) -> void:
	if _stage_tween != null and _stage_tween.is_valid():
		_stage_tween.kill()
	if seconds <= 0.0:
		_stage_blend = blend
		_view_height = height
		return
	_stage_tween = create_tween().set_parallel(true)
	_stage_tween.tween_property(self,"_stage_blend",blend,seconds).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)
	_stage_tween.tween_property(self,"_view_height",height,seconds).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)

## The camera's height over what it looks at now (VIEW_HEIGHT: the map's own pitch).
func view_height() -> float:
	return _view_height

## The camera's offset from what it looks at (its yaw is the chosen side's), and the size its
## layout gives it before any push-in.
func camera_offset() -> Vector3:
	return _offset

func base_size() -> float:
	return _camera_base_size

## Whether the stage's move is done (the camera on its target at its height).
func stage_settled() -> bool:
	return _stage_tween == null or not _stage_tween.is_valid() or not _stage_tween.is_running()

## 战斗演出 D: `id`'s figure shown at `at` (a point in the world) facing `yaw`, as far as
## placed_blend takes it from its body.
func place_actor(id: StringName, at: Vector3, yaw: float) -> void:
	_placed[id] = [at, yaw]

## `id`'s figure back on its body (it left the show).
func unplace(id: StringName) -> void:
	_placed.erase(id)

## Every figure back on its body.
func release_placed() -> void:
	_placed.clear()
	placed_blend = 0.0

## Where `id`'s figure is shown placed, or null when it is not (tests).
func placed_at(id: StringName) -> Variant:
	return _placed[id][0] if _placed.has(id) else null

func placing() -> bool:
	return not _placed.is_empty() and placed_blend > 0.0

func _label(parent: Node3D, text: String, height: float = 2.2) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.position.y = height
	label.font_size = 36
	label.pixel_size = 0.012
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.outline_size = 6
	label.modulate = Color("f0e6ce")
	# 战斗演出 D: a name over a head on a raised stage shows over the map's backdrop.
	label.render_priority = VoxelBackdrop.OVER_BACKDROP
	label.outline_render_priority = VoxelBackdrop.OVER_BACKDROP - 1
	parent.add_child(label)
	return label

func _sync_actors(delta: float) -> void:
	var hovered: StringName = pick_at(get_viewport().get_mouse_position()) if _context_names else &""
	var bodies: Array[WorldCharacterBody2D] = [map.player_body]
	for npc: NpcRuntimeState in map.npc_runtimes():
		var body: WorldCharacterBody2D = map.runtime_body_for_character(npc.character_id)
		if body != null:
			bodies.append(body)
	var seen: Dictionary[StringName,bool] = {}
	for body: WorldCharacterBody2D in bodies:
		var id: StringName = body.character_id
		seen[id] = true
		if not actors.has(id):
			_make_actor(body)
		var actor: Node3D = actors[id]
		actor.visible = body.visible and body.is_visible_in_tree()
		var at: Vector2 = body.global_position
		var next: Vector3 = VoxelMapGeometry.point(at,0.02)
		# 战斗演出 D: a placed figure is drawn toward its place (it stands there, not walking).
		var place: Array = _placed.get(id,[]) if placed_blend > 0.0 else []
		if not place.is_empty():
			next = next.lerp(place[0],placed_blend)
		var step: float = actor.position.distance_to(next)
		# On a stage already up, one coming or moving to a place there goes, not jumps.
		if not place.is_empty() and placed_blend >= 1.0 and step > 0.01:
			next = actor.position.lerp(next,minf(1.0,delta*10.0))
		actor.position = next
		var model: Node3D = actor.get_child(0) as Node3D
		if model is Person or model is Crawler or model is Snake or model is Flyer:
			# Render frames may outnumber physics steps: a held direction must not flicker
			# between the walk and idle poses on the intervening frames.
			model.walking = (body.velocity.length_squared()>1.0 if body == map.player_body else step>0.003) and step<1.5 and place.is_empty()
		if model is Person:
			# One attending to the player puts its work down (WorldMapNpcIdle); one fighting or lying
			# senseless neither works nor sits.
			(model as Person).working = not bool(body.get_meta(WorldMapNpcIdle.ATTENDING, false))
			var resident: NpcRuntimeState = map.npcs.find_resident_npc(id) if body != map.player_body else null
			(model as Person).at_ease = resident == null or (resident.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE and not resident.relationship.is_fighting())
		# A statue (神像) never turns or falls: its plinth and wings stay with it.
		if not (model is Person and not (model as Person).stone.is_empty()):
			var direction: float = atan2(body.facing.x,body.facing.y) if place.is_empty() else float(place[1])
			model.rotation.y = lerp_angle(model.rotation.y,direction,minf(1.0,delta*17))
			var npc: NpcRuntimeState = map.npcs.find_resident_npc(id) if body != map.player_body else null
			var life: CharacterRuntimeLifeStatus.Value = map.player_runtime().life_status if body == map.player_body else (npc.life_status if npc != null else CharacterRuntimeLifeStatus.Value.ACTIVE)
			var unconscious: bool = life == CharacterRuntimeLifeStatus.Value.UNCONSCIOUS
			model.rotation.z = PI/2 if unconscious else 0.0
		var name_label := body.get_node_or_null("NameLabel") as Label
		if name_label != null:
			var label: Label3D = labels[id]
			label.text = name_label.text
			var color: Color = name_label.get_theme_color("font_color")
			color.a *= float(label.get_meta("name_alpha",1.0))
			label.modulate = color
			var reveal_distance: float = float(label.get_meta("name_distance",-1.0))
			label.visible = (reveal_distance<0 or at.distance_squared_to(map.player_body.global_position)<=reveal_distance*reveal_distance or id==hovered or id==map.selected_character_id()) and not placing()
		var mark := body.get_node_or_null("AlertMark") as Label
		var marked: bool = mark != null and mark.visible
		if marked and not alert_marks.has(id):
			# Over the name, whatever the body's size (a beast's name sits lower or higher).
			var alert: Label3D = _label(actor, mark.text, (labels[id].position.y if labels.has(id) else 2.2) + 0.55)
			alert.font_size = 60
			alert.modulate = mark.get_theme_color("font_color")
			alert_marks[id] = alert
		if alert_marks.has(id):
			alert_marks[id].visible = marked and (not placing() or _placed.has(id))
			alert_marks[id].text = mark.text if mark != null else alert_marks[id].text
		_sync_watch_cone(actor, body)
	for id: StringName in actors.keys():
		if not seen.has(id):
			actors[id].queue_free()
			actors.erase(id)
			labels.erase(id)
			alert_marks.erase(id)

## 第九章 B (DECISIONS「禁军夜巡」): a watcher's cone of sight on the ground (meta `watch_cone` the
## runtime sets: radius px, degrees, alarmed), faint, turned with the body; only at night, when
## it matters; gone when it stops watching (the meta cleared).
func _sync_watch_cone(actor: Node3D, body: WorldCharacterBody2D) -> void:
	var cone: MeshInstance3D = actor.get_node_or_null("WatchCone") as MeshInstance3D
	var data: Dictionary = body.get_meta("watch_cone", {}) if body.has_meta("watch_cone") else {}
	if data.is_empty() or not body.visible or (placing() and _placed.has(body.character_id)):
		if cone != null:
			cone.visible = false
		return
	if cone == null or float(cone.get_meta("radius", 0.0)) != float(data["radius"]) or int(cone.get_meta("degrees", 0)) != int(data["degrees"]):
		if cone != null:
			cone.queue_free()
		cone = _cone_mesh(float(data["radius"]), int(data["degrees"]))
		cone.name = "WatchCone"
		actor.add_child(cone)
	cone.visible = true
	cone.rotation.y = atan2(body.facing.x, body.facing.y)
	var material: StandardMaterial3D = cone.material_override as StandardMaterial3D
	material.albedo_color = Color(1.0, 0.35, 0.25, 0.22) if data.get("alarmed", false) else Color(1.0, 0.92, 0.7, 0.1)


func _cone_mesh(radius_px: float, degrees: int) -> MeshInstance3D:
	var radius: float = VoxelMapGeometry.point(Vector2(radius_px, 0), 0).x - VoxelMapGeometry.point(Vector2.ZERO, 0).x
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps: int = maxi(6, degrees / 10)
	var half: float = deg_to_rad(float(degrees)) / 2.0
	for i: int in steps:
		var a: float = -half + (2.0 * half) * float(i) / float(steps)
		var b: float = -half + (2.0 * half) * float(i + 1) / float(steps)
		tool.add_vertex(Vector3(0, 0.03, 0))
		tool.add_vertex(Vector3(sin(a) * radius, 0.03, cos(a) * radius))
		tool.add_vertex(Vector3(sin(b) * radius, 0.03, cos(b) * radius))
	var mesh := MeshInstance3D.new()
	mesh.mesh = tool.commit()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.no_depth_test = false
	mesh.material_override = material
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh.set_meta("radius", radius_px)
	mesh.set_meta("degrees", degrees)
	return mesh


func _make_actor(body: WorldCharacterBody2D) -> void:
	var actor := Node3D.new()
	world.add_child(actor)
	actors[body.character_id] = actor
	# The person's card (PersonLooks, DECISIONS「人物外观」) with the map's own entry for them over
	# it; without a card that entry, else the map's default (a card does not take the default's
	# keys); a role whose gender is drawn (旅客) by the one it drew; the player's card by their gender.
	var actors_config: Dictionary = layout.get("actors",{})
	var look: Dictionary = actors_config.get("default",{})
	if body != map.player_body:
		var npc: NpcRuntimeState = map.npcs.find_resident_npc(body.character_id)
		if npc != null:
			var drawn: String = String(npc.character_state.gender) if npc.character_state != null else ""
			look = PersonLooks.resolve(actors_config,String(NpcDefinition.unnamed_id(npc.definition().definition_id)),{},drawn)
	else:
		var gender: String = String(map.player_runtime().state.gender) if map.player_runtime() != null else ""
		look = PersonLooks.resolve({},"",PersonLooks.player(gender))
		if look.is_empty():
			look = {"coat":"397c87"}
	var model: Node3D
	var size: float = float(look.get("scale",1.0))
	var body_kind: String = String(look.get("body",""))
	var crawler: bool = body_kind in ["crawler","snake","flyer"]
	if body_kind=="crawler":
		model = Crawler.new()
		model.scale = Vector3.ONE*size
		model.colors = look.get("colors",model.colors)
		model.spots = String(look.get("spots",model.spots))
		actor.add_child(model)
	elif body_kind=="snake":
		model = Snake.new()
		model.scale = Vector3.ONE*size
		model.colors = look.get("colors",model.colors)
		model.belly = String(look.get("belly",model.belly))
		model.bands = String(look.get("bands",""))
		model.crest = String(look.get("crest",""))
		model.rear = look.get("rear",false)
		actor.add_child(model)
	elif body_kind=="flyer":
		model = Flyer.new()
		model.scale = Vector3.ONE*size
		model.wings = look.get("wings",model.wings)
		model.hover = float(look.get("hover",model.hover))
		actor.add_child(model)
	elif look.get("animal",false):
		model = Node3D.new()
		model.scale = Vector3.ONE*size
		actor.add_child(model)
		var fur: Array = look.get("fur",["a88a60","846747","725638"])
		var s := Shapes.new()
		s.box(model,Vector3(0,0.45,0),Vector3(0.5,0.45,0.95),fur[0])
		s.box(model,Vector3(0,0.72,0.5),Vector3(0.4,0.4,0.42),fur[1])
		for x: float in [-0.18,0.18]:
			for z: float in [-0.3,0.3]:
				s.box(model,Vector3(x,0.18,z),Vector3(0.12,0.36,0.13),fur[2])
		if look.get("tail",false):
			s.tilted_box(model,Vector3(0,0.34,-0.82),Vector3(0.08,0.08,0.78),fur[1],Vector3(-0.35,0,0))
		s.flush()
	elif body_kind=="statue":
		# 神像 (an NPC that is a statue: 晚月庄's 区冥, its 火神凤凰): the figure in one stone or
		# gilt (`stone`), never stirring, on a plinth (`plinth` high, `base`), wings spread
		# behind it (`wings`: their colours).
		var plinth: float = float(look.get("plinth",0.5))
		model = Person.new()
		model.stone = String(look.get("stone","e8e4d8"))
		model.coat = model.stone
		model.position.y = plinth
		actor.add_child(model)
		var s := Shapes.new()
		s.box(actor,Vector3(0,plinth/2,0),Vector3(0.95,plinth,0.8),String(look.get("base","8a7a6a")))
		s.box(actor,Vector3(0,plinth+0.03,0),Vector3(1.0,0.06,0.85),String(look.get("rim","c9a24a")))
		var wings: Array = look.get("wings",[])
		for i: int in wings.size()*3:
			for side: float in [-1.0,1.0]:
				var at := Vector3(side*(0.4+i*0.12),plinth+1.2+i*0.12,-0.25)
				s.tilted_box(actor,at,Vector3(0.12,0.9-i*0.07,0.05),String(wings[i%wings.size()]),Vector3(0,0,-side*(0.4+i*0.12)))
		if not wings.is_empty():
			for t: int in 5:
				s.tilted_box(actor,Vector3((t-2)*0.1,plinth+0.5,-0.45),Vector3(0.07,0.05,0.9),String(wings[t%wings.size()]),Vector3(0.9,0,0))
		s.flush()
	else:
		model = Person.new()
		model.coat = look.get("coat","817755")
		model.configure(look)
		# What the person does while it stands (DECISIONS「街上的人会动」): its work's gesture and tool,
		# a stool or the ground it sits on.
		var npc_life: NpcRuntimeState = map.npcs.find_resident_npc(body.character_id) if body != map.player_body else null
		var life: NpcLifeBook.Entry = null if npc_life == null else NpcLifeBook.entry(NpcDefinition.unnamed_id(npc_life.definition().definition_id))
		if life != null:
			(model as Person).activity(life.gesture, life.pose)
		actor.add_child(model)
		# `mount` (关北 C; owner Q3: the 王府's riders sit a horse in the view only — the 2D rule
		# knows no mounts): a steppe pony under the figure, the rider up on its back, facing +z.
		if look.has("mount"):
			var mount: Dictionary = look.get("mount",{}) if look.get("mount") is Dictionary else {}
			var horse := Node3D.new()
			horse.position = Vector3(0,0,-0.1)
			actor.add_child(horse)
			var town := Town.new()
			var s := Shapes.new()
			town.s = s
			town.root = actor
			town.data = mount
			var coat: String = String(mount.get("coat","5a3a2a"))
			var mane: String = String(mount.get("mane","2a2420"))
			var body_h: float = town._horse_body(horse,1.8,coat,mane)
			town._horse_tail(horse,body_h,1.8,mane)
			s.box(horse,Vector3(0,body_h+0.28,-0.05),Vector3(0.56,0.06,0.5),String(mount.get("cloth","8a3a2a")))
			s.flush()
			model.position.y = body_h+0.2
			model.scale = Vector3.ONE*0.92
			for leg: Node3D in model.legs:
				leg.rotation.x = 0.0
			model.set_meta("mounted",true)
	var low: bool = crawler or look.get("animal",false)
	var label_height: float = (0.55*size+0.35 if crawler else 0.4+0.9*size) if low else 2.2+float(look.get("plinth",0.5) if body_kind=="statue" else 0.0)
	if body_kind=="flyer":
		label_height = float(look.get("hover",1.1))*size+0.5
	labels[body.character_id] = _label(actor,"",label_height)
	var label: Label3D = labels[body.character_id]
	label.font_size = int(look.get("name_font_size",36))
	label.set_meta("name_alpha",float(look.get("name_alpha",1.0)))
	label.set_meta("name_distance",float(look.get("name_distance",-1.0)))
	_context_names = _context_names or float(look.get("name_distance",-1.0))>=0
	actor.set_meta("pick_height",(0.5*size if crawler else 1.15*size) if low else 1.85)
	actor.set_meta("pick_width",maxf(10,20*size) if low else 20.0)

func _sync_objects() -> void:
	var seen: Dictionary[StringName,bool] = {}
	for id: StringName in map.floor_items.floor_item_ids():
		var item: WorldFloorItemView = map.floor_items.floor_item_view(id)
		if item != null:
			_object(id,item.global_position,item.display_name,false)
			seen[id] = true
	for corpse: CorpseState in map.corpses.corpse_states():
		var view: CombatSliceCorpseView = map.corpses.corpse_view_for(corpse.corpse_item_instance_id)
		if view != null and map.corpses.corpse_is_live_in_world(corpse):
			_object(corpse.corpse_item_instance_id,view.global_position,map.corpses.corpse_name(corpse),true)
			seen[corpse.corpse_item_instance_id] = true
			# 战斗演出 D: one felled on a raised stage lies there until the stage comes down.
			var place: Array = _placed.get(corpse.victim_character_id,[]) if placed_blend > 0.0 else []
			if not place.is_empty():
				var node: Node3D = objects[corpse.corpse_item_instance_id]
				node.position = node.position.lerp(place[0],placed_blend)
	for id: StringName in objects.keys():
		if not seen.has(id):
			objects[id].queue_free()
			objects.erase(id)
	for id: StringName in shutters:
		shutters[id].visible = not map.doors_by_id[id].is_open()
		if opened.has(id):
			opened[id].visible = not shutters[id].visible

func _object(id: StringName, at: Vector2, title: String, corpse: bool) -> void:
	if not objects.has(id):
		var node := Node3D.new()
		world.add_child(node)
		var s := Shapes.new()
		# A floor item may have a look of its own on this map (layout `items`: item definition
		# -> look), drawn by the props files; it goes when the item goes (a buried skeleton).
		# Any other thing that can be carried lies as its 背包 picture shows it, laid down
		# and sized for the world, each turned its own way (VoxelItemLook.lay()).
		var content: ItemContentDefinition = null if corpse else map.floor_items.floor_item_content(map.floor_items.floor_item_view(id))
		var look: Dictionary = {} if content == null else layout.get("items",{}).get(String(content.item_definition_id),{})
		var carried: Dictionary = {} if content == null or not look.is_empty() else VoxelItemLook.look(content.item_definition_id)
		if not carried.is_empty():
			var model := Node3D.new()
			model.name = "Look"
			node.add_child(model)
			VoxelItemLook.build(model,carried)
			VoxelItemLook.lay(model,carried,float(absi(String(id).hash())%360)*TAU/360.0)
		elif look.is_empty() or not geometry.draw_look(s,node,look):
			s.box(node,Vector3(0,0.15,0),Vector3(0.75,0.3,1.45) if corpse else Vector3(0.4,0.3,0.35),"6b6860" if corpse else "b5a079")
		s.flush()
		_label(node,title,0.7).name = "Title"
		objects[id] = node
	objects[id].position = VoxelMapGeometry.point(at)
	# A corpse's name changes as it decays (obj/corpse.c).
	var label := objects[id].get_node_or_null("Title") as Label3D
	if label != null and label.text != title:
		label.text = title
	if label != null:
		label.visible = not placing()

func _make_entrances() -> void:
	for node: Node in geometry.areas:
		var passage := node as WorldPassageArea2D
		if passage == null:
			continue
		var portal: PortalDefinition = GameContent.catalog().portal(passage.portal_id)
		var zone: ZoneDefinition = null if portal == null else GameContent.catalog().zone(portal.destination_zone_id)
		if zone == null:
			continue
		var settings: Dictionary = layout.get("entrances",{}).get(String(passage.portal_id),{})
		var title: String = tr(String(settings.get("title",zone.display_name)))
		var marker := Node3D.new()
		marker.position = VoxelMapGeometry.point(passage.global_position)
		world.add_child(marker)
		var label: Label3D = _label(marker,title+"  ›",float(settings.get("label_height",1.6)))
		label.modulate = Color("f6d98e")
		label.font_size = 36
		label.outline_size = 9
		label.outline_modulate = Color("2a1c10")
		var s := Shapes.new()
		if settings.get("floor_guides",true):
			# A glowing frame on the ground round the way out, so it reads from across the map.
			var size := _passage_size(passage)
			for side: float in [-1.0,1.0]:
				s.box(marker,Vector3(side*size.x/2,0.04,0),Vector3(0.1,0.05,size.y),EXIT_GLOW)
				s.box(marker,Vector3(0,0.04,side*size.y/2),Vector3(size.x+0.1,0.05,0.1),EXIT_GLOW)
		s.flush()
		entrances[passage.portal_id] = {"passage":passage,"node":marker,"label":label}
		var arrow: Node3D = _arrow(marker,_outward(passage,portal))
		arrows[passage.portal_id] = arrow
	for id: StringName in map.doors_by_id:
		var door: WorldDoor = map.doors_by_id[id]
		var holder := Node3D.new()
		holder.position = VoxelMapGeometry.point(door.wall_shape().global_position)
		world.add_child(holder)
		arrows[id] = _arrow(holder,Vector2.ZERO)
		arrows[id].set_meta("door",true)
		# A building's door over the passage into it (one door, two maps): while the passage's own
		# arrow shows (the door open), the door's would stand over it, a second arrow on one way.
		var through: Array[StringName] = []
		var definition: DoorDefinition = GameContent.catalog().door(id)
		for portal_id: StringName in entrances:
			var portal: PortalDefinition = GameContent.catalog().portal(portal_id)
			if definition != null and definition.zone_ids().has(portal.source_zone_id) and definition.zone_ids().has(portal.destination_zone_id):
				through.append(portal_id)
		arrows[id].set_meta("passages",through)

## The way the exit leads: its original command's compass direction (diagonals too);
## for a verb without one (stairs, `enter`), across the passage's thin side, away from
## the middle of the room it belongs to.
func _outward(passage: WorldPassageArea2D, portal: PortalDefinition) -> Vector2:
	var shaped: Vector2 = _shape_outward(passage)
	var compass: Vector2 = VoxelMapGeometry.compass(portal.legacy_command)
	var settings: Dictionary = layout.get("entrances",{}).get(String(portal.portal_id),{})
	if settings.has("arrow"):
		var fixed: Array = settings["arrow"]
		return Vector2(float(fixed[0]),float(fixed[1])).normalized()
	# The command's compass unless the painted way out goes off another way (an "east"
	# exit drawn at the top of a north-south road): then the way the player walks out.
	return compass if compass != Vector2.ZERO and compass.dot(shaped) > 0.0 else shaped

func _shape_outward(passage: WorldPassageArea2D) -> Vector2:
	var at: Vector2 = passage.global_position
	var shape := passage.get_node_or_null("CollisionShape2D") as CollisionShape2D
	var across: Vector2 = Vector2.DOWN
	if shape != null and shape.shape is RectangleShape2D:
		var size: Vector2 = (shape.shape as RectangleShape2D).size
		across = Vector2.RIGHT if size.x < size.y else Vector2.DOWN
	var room: Vector2 = at
	var nearest: float = INF
	for node: Node in geometry.areas:
		var zone := node as WorldPhysicalZoneArea2D
		if zone == null:
			continue
		var rect: Rect2 = zone.global_rect()
		var gap: float = 0.0 if rect.has_point(at) else rect.get_center().distance_to(at)
		if gap < nearest:
			nearest = gap
			room = rect.get_center()
	var side: float = signf((at-room).dot(across))
	return across*(side if side != 0.0 else 1.0)

## The size (units) of a passage's area on the ground.
func _passage_size(passage: WorldPassageArea2D) -> Vector2:
	var shape := passage.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape != null and shape.shape is RectangleShape2D:
		return (shape.shape as RectangleShape2D).size/VoxelMapGeometry.UNIT
	return Vector2(2.0,1.0)

func _arrow(parent: Node3D, direction: Vector2) -> Node3D:
	var arrow := Node3D.new()
	arrow.set_meta("direction",direction)
	parent.add_child(arrow)
	var s := Shapes.new()
	# Flat, so it reads the same from either fixed angle; the wide row trails, the tip leads. A dark
	# rim under it keeps it readable on pale ground.
	var rim := Node3D.new()
	arrow.add_child(rim)
	for row: int in 5:
		s.box(rim,Vector3(0,-0.04,-0.6+row*0.3),Vector3((0.95-row*0.21)*1.5+0.16,0.08,0.32),"3a2414")
	for row: int in 5:
		s.box(arrow,Vector3(0,0,-0.6+row*0.3),Vector3((0.95-row*0.21)*1.5,0.14,0.3),"f2a43a")
	s.flush()
	# A warm amber of its own: readable on pale ground by day and glowing by night.
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color("f2a43a")
	glow.emission_enabled = true
	glow.emission = Color("e8902a")
	glow.emission_energy_multiplier = 0.55
	for mesh: Node in arrow.find_children("*","GeometryInstance3D",true,false):
		var instance := mesh as GeometryInstance3D
		if instance.get_parent() == arrow:
			instance.material_override = glow
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	arrow.scale = Vector3.ONE*ARROW_SCALE
	return arrow

func _bob_arrows(delta: float) -> void:
	_arrow_clock += delta
	var player: Vector2 = map.player_body.global_position
	for id: StringName in arrows:
		var arrow: Node3D = arrows[id]
		var direction: Vector2 = arrow.get_meta("direction")
		var near: bool
		if direction == Vector2.ZERO:
			var door: WorldDoor = map.doors_by_id[id]
			var wall: CollisionShape2D = door.wall_shape()
			var size: Vector2 = (wall.shape as RectangleShape2D).size
			var across: Vector2 = Vector2.RIGHT if size.x < size.y else Vector2.DOWN
			var side: float = signf((wall.global_position-player).dot(across))
			direction = across*(side if side != 0.0 else 1.0)
			near = wall.global_position.distance_to(player) < 600.0
			# A way found by a clue (DoorDefinition.found_by) shows no arrow until it is found.
			var definition: DoorDefinition = GameContent.catalog().door(id)
			if definition != null and not definition.found_by.is_empty() and not door.is_open():
				near = false
			for portal_id: StringName in arrow.get_meta("passages",[]):
				if (entrances[portal_id]["node"] as Node3D).visible:
					near = false
		else:
			near = (arrow.get_parent() as Node3D).visible
		# The way the quest marker leads by (or a door on it): its red arrow stands there instead.
		var way: StringName = &"" if quest_marker == null else quest_marker.get_meta("way",&"")
		if not way.is_empty() and (way == id or (arrow.get_meta("passages",[]) as Array).has(way)):
			near = false
		arrow.visible = near and not staged
		arrow.rotation.y = atan2(direction.x,direction.y)
		# A door's floats over its lintel, clear of the shut leaf; a passage's over the floor.
		arrow.position.y = (2.85 if arrow.get_meta("door",false) else 1.0)+sin(_arrow_clock*3.2)*0.2

## The quest marker follows the player's 指路, else the tracked quest (MapAtlas.goal): placed
## anew when the goal or the ledger changes, bobbing with the exit arrows meanwhile; over a
## person it follows them. It stands beside the world (a child of the view, in the world's
## coordinates), not in it: the world is the map's portrait and is rebuilt the same whether a
## quest is on or not.
func _sync_quest_marker() -> void:
	var player: WorldPlayerRuntimeState = map.player_runtime()
	var state: CharacterState = null if player == null else player.state
	var goal: MapAtlas.Goal = null if state == null else MapAtlas.goal(GameContent.catalog(), state)
	var key: String = "" if goal == null else "%s/%s/%s/%s/%d/%d" % [goal.map_id, goal.zone_id, goal.waypoint, goal.npc_ids, state.quests.size(), state.visited_maps.size()]
	if key != _quest_key:
		_quest_key = key
		_place_quest_marker(goal, state)
	if quest_marker == null:
		return
	if staged:
		quest_marker.visible = false
	var bob: float = sin(_arrow_clock * 3.2) * 0.2
	if quest_marker.has_meta("npc_ids"):
		_follow_quest_person(bob)
	else:
		quest_marker.position.y = float(quest_marker.get_meta("height", 0.0)) + bob
	var spinner: Node3D = quest_marker.get_node_or_null("Spinner") as Node3D
	if spinner != null:
		spinner.rotation.y = _arrow_clock * QUEST_SPIN


## The quest marker over the nearest standing one of the people the step is about, else over its
## zone: one who walks off is followed, one who falls or leaves hands it back to the zone.
func _follow_quest_person(bob: float) -> void:
	var ids: Array = quest_marker.get_meta("npc_ids")
	var player: Vector2 = map.player_body.global_position
	var best: StringName = &""
	var nearest: float = INF
	for npc: NpcRuntimeState in map.npc_runtimes():
		if npc.life_status == CharacterRuntimeLifeStatus.Value.DEAD or not actors.has(npc.character_id):
			continue
		var definition_id: StringName = npc.definition().definition_id
		if not ids.has(definition_id) and not ids.has(NpcDefinition.unnamed_id(definition_id)):
			continue
		var body: WorldCharacterBody2D = map.runtime_body_for_character(npc.character_id)
		if body == null or not actors[npc.character_id].visible:
			continue
		var distance: float = body.global_position.distance_squared_to(player)
		if distance < nearest:
			nearest = distance
			best = npc.character_id
	quest_marker.set_meta("over", best)
	# Over a person the arrow says it all; over an empty zone it is named.
	var label := quest_marker.get_node_or_null("Label") as Label3D
	if label != null:
		label.visible = best.is_empty()
	if best.is_empty():
		var point: Vector3 = quest_marker.get_meta("zone_point")
		quest_marker.position = point + Vector3(0, float(quest_marker.get_meta("height", 0.0)) + bob, 0)
		return
	# Over the name over the head, whatever the body's size.
	var head: float = (labels[best].position.y if labels.has(best) else 2.2) + 0.45
	quest_marker.position = actors[best].position + Vector3(0, head + bob, 0)


## The way out towards `goal`'s map, or its zone (the person the step is about) on this map;
## nothing when there is no goal or no way. A 指路 keeps to the roads the player has walked.
func _place_quest_marker(goal: MapAtlas.Goal, state: CharacterState) -> void:
	if quest_marker != null:
		quest_marker.queue_free()
		quest_marker = null
	if goal == null or world == null:
		return
	if goal.map_id == map.map_id():
		_place_quest_spinner(goal.zone_id, goal.waypoint, goal.npc_ids)
		return
	var known: Dictionary[String, int] = {}
	if goal.waypoint:
		known = state.visited_maps
	var steps: Array[WorldRoute.Step] = WorldRoute.guided(GameContent.catalog(), map.map_id(), goal.map_id, known)
	if steps.is_empty():
		return
	var step: WorldRoute.Step = steps[0]
	if step.portal != null and not entrances.has(step.portal.portal_id):
		# A way a landmark opens has no entrance to stand over: the room it is taken from.
		_place_quest_spinner(step.portal.source_zone_id, goal.waypoint, [])
		return
	if step.portal == null:
		# A room command that moves the player (the 铁索 down a cliff): over its service point.
		var point: WorldServicePoint = map.service_point(step.service.service_id)
		if point == null:
			return
		_quest_spinner_at(VoxelMapGeometry.point(point.global_position), goal.waypoint)
		quest_marker.set_meta("way", step.service.service_id)
		return
	# The exit's own amber arrow gives way to this one (_bob_arrows): one red arrow, in its place.
	var entrance: Dictionary = entrances[step.portal.portal_id]
	var direction: Vector2 = _outward(entrance["passage"], step.portal)
	quest_marker = Node3D.new()
	quest_marker.name = "QuestMarker"
	quest_marker.position = (entrance["node"] as Node3D).position + Vector3(0, 1.0, 0)
	quest_marker.set_meta("height", 1.0)
	quest_marker.set_meta("way", step.portal.portal_id)
	add_child(quest_marker)
	var arrow: Node3D = _arrow(quest_marker, direction)
	arrow.scale = Vector3.ONE * ARROW_SCALE * QUEST_ARROW_SCALE
	arrow.rotation.y = atan2(direction.x, direction.y)
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(QUEST_GLOW)
	glow.emission_enabled = true
	glow.emission = Color(QUEST_GLOW)
	glow.emission_energy_multiplier = 0.8
	for mesh: Node in arrow.find_children("*", "GeometryInstance3D", true, false):
		var instance := mesh as GeometryInstance3D
		if instance.get_parent() == arrow:
			instance.material_override = glow
	# Over the exit's own name (its label at 1.6 over the floor), clear of it.
	_quest_label(quest_marker, 1.55, goal.waypoint)


## On the target's map: the turning arrow over the person the step is about (`npc_ids`, followed
## by _follow_quest_person), else over the middle of the zone at a head's height.
func _place_quest_spinner(zone_id: StringName, waypoint: bool, npc_ids: Array) -> void:
	var zone: WorldPhysicalZoneArea2D = map.physical_zone(zone_id)
	if zone == null:
		return
	var point: Vector3 = VoxelMapGeometry.point(zone.global_rect().get_center())
	_quest_spinner_at(point, waypoint)
	quest_marker.set_meta("target_zone", zone_id)
	if not npc_ids.is_empty():
		quest_marker.set_meta("npc_ids", npc_ids)
		quest_marker.set_meta("zone_point", point)
		_follow_quest_person(0.0)


## A small red arrow pointing down, solid (it has a thickness, so it reads as a thing as it
## turns), over `at` at a head's height.
func _quest_spinner_at(at: Vector3, waypoint: bool) -> void:
	quest_marker = Node3D.new()
	quest_marker.name = "QuestMarker"
	quest_marker.position = at + Vector3(0, 2.4, 0)
	quest_marker.set_meta("height", 2.4)
	add_child(quest_marker)
	var spinner := Node3D.new()
	spinner.name = "Spinner"
	quest_marker.add_child(spinner)
	var s := Shapes.new()
	# The head, its rows widening from the tip at the bottom; the shaft over it.
	for row: int in 5:
		s.box(spinner, Vector3(0, 0.07 + row * 0.13, 0), Vector3(0.16 + row * 0.16, 0.13, 0.22), QUEST_GLOW)
	s.box(spinner, Vector3(0, 0.9, 0), Vector3(0.3, 0.5, 0.22), QUEST_GLOW)
	s.flush()
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(QUEST_GLOW)
	glow.emission_enabled = true
	glow.emission = Color(QUEST_GLOW)
	glow.emission_energy_multiplier = 0.6
	for mesh: Node in spinner.find_children("*", "GeometryInstance3D", true, false):
		var instance := mesh as GeometryInstance3D
		instance.material_override = glow
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	spinner.scale = Vector3.ONE * 0.8
	_quest_label(quest_marker, 1.35, waypoint)


func _quest_label(parent: Node3D, height: float, waypoint: bool) -> void:
	# TRANSLATORS: the marker's label in the voxel view: where the player chose on the 地图 page (指路), or where the tracked quest leads (目标).
	var label: Label3D = _label(parent, tr("指路") if waypoint else tr("目标"), height)
	label.name = "Label"
	label.modulate = Color("ffd9c2")
	label.outline_modulate = Color("5a1a10")
	label.outline_size = 9


func _make_shutters() -> void:
	for id: StringName in map.doors_by_id:
		var door: WorldDoor = map.doors_by_id[id]
		var collision: CollisionShape2D = door.wall_shape()
		var rect := collision.shape as RectangleShape2D
		var node := Node3D.new()
		node.position = VoxelMapGeometry.point(collision.global_position)
		world.add_child(node)
		var s := Shapes.new()
		var size := Vector3(rect.size.x/VoxelMapGeometry.UNIT,2.2,rect.size.y/VoxelMapGeometry.UNIT)
		var look: Dictionary = layout.get("door_looks",{}).get(String(id),{})
		if not look.is_empty():
			look = look.duplicate()
			look["size"] = look.get("size",[rect.size.x,rect.size.y])
			# A look is drawn across its own x: a door in a north-south wall (its shape taller
			# than wide) is turned a quarter, or it would lie across the doorway.
			if rect.size.y > rect.size.x and not look.has("rotation"):
				look["rotation"] = 90
				look["size"] = [rect.size.y,rect.size.x]
			var open_keys: Variant = look.get("open",null)
			look.erase("open")
			geometry.draw_look(s,node,look)
			if open_keys is Dictionary or open_keys == true:
				# `open`: the look again, for the door standing open (true: the kind's own `open`;
				# a dictionary: keys over the shut look's), in the same place and turned the same way.
				var open: Dictionary = look.duplicate()
				open.merge(open_keys if open_keys is Dictionary else {"open":true},true)
				var swung := Node3D.new()
				swung.position = node.position
				swung.visible = false
				world.add_child(swung)
				var drawn := Shapes.new()
				geometry.draw_look(drawn,swung,open)
				drawn.flush()
				opened[id] = swung
		elif geometry.indoor:
			_room_door(node,s,size)
		else:
			s.box(node,Vector3(0,1.1,0),size,"9d4d39")
		s.flush()
		shutters[id] = node

## An indoor 房门: a frame that always stands in the doorway, even in a cut-away wall,
## and a panelled leaf (the shutter node) that shows only while the door is shut.
func _room_door(leaf: Node3D, s: Shapes, size: Vector3) -> void:
	var across: bool = size.x>=size.z
	var width: float = size.x if across else size.z
	var frame := Node3D.new()
	frame.position = leaf.position
	frame.rotation.y = 0.0 if across else PI/2
	world.add_child(frame)
	leaf.rotation.y = frame.rotation.y
	for x: float in [-width/2+0.07,width/2-0.07]:
		s.box(frame,Vector3(x,1.2,0),Vector3(0.14,2.4,0.42),"5c3f2b")
	s.box(frame,Vector3(0,2.44,0),Vector3(width,0.16,0.46),"6e4d37")
	s.box(frame,Vector3(0,0.02,0),Vector3(width-0.14,0.04,0.44),"7a573c")
	s.box(leaf,Vector3(0,1.1,0),Vector3(width-0.18,2.2,0.16),"8f5a3a")
	for y: float in [0.62,1.52]:
		s.box(leaf,Vector3(0,y,0),Vector3(width-0.42,0.66,0.2),"a46a44")
	s.box(leaf,Vector3(width*0.28,1.1,0),Vector3(0.07,0.18,0.24),"c9a35e")

func _reveal_entrances() -> void:
	for id: StringName in entrances:
		var entry: Dictionary = entrances[id]
		var passage: WorldPassageArea2D = entry["passage"]
		var distance: float = passage.global_position.distance_to(map.player_body.global_position)
		# 战斗演出 D: the map is the backdrop while figures stand on a raised stage.
		(entry["node"] as Node3D).visible = passage.is_open() and distance<900.0 and not placing()

func _plant_contacts() -> PackedVector3Array:
	var contacts := PackedVector3Array()
	var player: Vector3 = VoxelMapGeometry.point(map.player_body.global_position)
	contacts.append(player)
	for id: StringName in actors:
		if id != map.player_body.character_id and actors[id].visible and actors[id].position.distance_squared_to(player)<400:
			contacts.append(actors[id].position)
	return contacts

func _update_occlusion() -> void:
	var targets := PackedVector4Array()
	var visible: Rect2 = get_viewport().get_visible_rect().grow(64)
	var player: Vector3 = VoxelMapGeometry.point(map.player_body.global_position)
	var nearby: Array[Node3D] = []
	for actor: Node3D in actors.values():
		if actor.visible and actor.position.distance_squared_to(player)<=196:
			nearby.append(actor)
	nearby.sort_custom(func(a: Node3D,b: Node3D) -> bool: return a.position.distance_squared_to(player)<b.position.distance_squared_to(player))
	for actor: Node3D in nearby:
		if targets.size() >= VoxelOcclusion.LIMIT:
			break
		var model := actor.get_child(0) as Node3D
		# Follow the body's middle even when it is lying unconscious; animals are lower.
		var centre: Vector3 = model.to_global(Vector3.UP*(1.0 if model is Person else 0.5))
		if visible.has_point(camera.unproject_position(centre)):
			targets.append(Vector4(centre.x, centre.y, centre.z, 1.75))
	# The player's opening reveals an approached door too. An empty threshold must
	# not punch an independent ghost patch into a roof without a person behind it.
	occlusion.update(camera, targets)

## A projected click uses the same reach and permission checks as E and the old sprites.
func _unhandled_input(event: InputEvent) -> void:
	if not _active:
		return
	var mouse := event as InputEventMouseButton
	var touch := event as InputEventScreenTouch
	if (mouse == null or mouse.button_index != MOUSE_BUTTON_LEFT or not mouse.pressed) and (touch == null or not touch.pressed):
		return
	var at: Vector2 = mouse.position if mouse != null else touch.position
	var selected: StringName = pick_at(at)
	if not selected.is_empty():
		map.selection.on_thing_clicked(selected)
	# Do not pick the hidden flat sprite underneath a projected figure.
	get_viewport().set_input_as_handled()

func pick_at(at: Vector2) -> StringName:
	var nearest: float = INF
	var picked: StringName = &""
	for id: StringName in actors:
		var actor: Node3D = actors[id]
		if id == map.player_body.character_id or not actor.visible:
			continue
		var feet: Vector2 = camera.unproject_position(actor.position)
		var head: Vector2 = camera.unproject_position(actor.position+Vector3.UP*float(actor.get_meta("pick_height",1.85)))
		var width: float = float(actor.get_meta("pick_width",20.0))
		var bounds := Rect2(head-Vector2(width,8),Vector2(width*2,feet.y-head.y+16))
		if bounds.has_point(at) and at.distance_to(head)<nearest:
			nearest = at.distance_to(head)
			picked = id
	if not picked.is_empty():
		return picked
	for thing: WorldNearbyThing in map.selection.nearby():
		var focus: WorldFocus = map.selection.focus_of(thing,"")
		if focus != null and map.screen_position(focus.at()).distance_to(at)<30:
			return thing.id
	return &""
