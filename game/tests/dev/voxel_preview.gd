extends Node

## Dev only: any map's voxel view without walking there. Open voxel_preview.tscn in the editor
## and press F6. A New Game world with world time held: nobody moves or fights, and no save is
## ever written (only the runtime host, absent here, saves). tests/ never reaches a release.
##
## The preview's camera is the game's own: an unseen player body, out of every area and wall,
## stands where the view looks, so the view's lights, cut-aways and plants act as they do in play.
## R reads the map's voxel JSON again without a restart; a changed layout or script needs F6.
## The hour moves along the day's frames, the game's own light blending from one to the next,
## so the shadows sweep across; T lets it run on round the day.

const SESSION_SCENE: String = "res://scenes/world/oldpine/oldpine_world_session.tscn"
const SETTINGS_PATH: String = "user://voxel_preview.cfg"
const HOLD: StringName = &"voxel_preview"
const FRAMES: Dictionary[String, String] = {"day": "白天", "dawn": "黎明", "dusk": "黄昏", "night": "夜晚", "midnight": "深夜"}
## The day's frames in order, round which the hour moves.
const CYCLE: Array[String] = VoxelLighting.FRAMES
## Seconds from one frame to the next.
const LEG_SECONDS: float = 2.5
const MIN_ZOOM: float = 0.4
const MAX_ZOOM: float = 16.0
const ZOOM_STEP: float = 1.12
## Screen heights a held key crosses in a second.
const PAN_SPEED: float = 0.6
## Further out than this the height fog would blacken the map (voxel-pitfalls): it is lifted.
const FOG_ZOOM: float = 1.5
## Where the camera leaves the game's distance: wider than this the near plane cuts the map.
const NEAR_LIMIT_SIZE: float = 40.0
const PANEL_WIDTH: float = 270.0
const SAVE_SECONDS: float = 1.0

signal prepared

## Off for the suite, which must not rewrite the owner's last place.
@export var remember: bool = true
var session: WorldSessionController
var map: WorldMapController
var view: WorldVoxelView
var zoom: float = 1.0
var frame: String = "day"
## The hour runs on by itself.
var flowing: bool = false
var cloud: int = 0
var left_view: bool = false
var focus: Vector2 = Vector2.ZERO
var show_player: bool = false
var _maps: Array[StringName] = []
var _zones: Array[StringName] = []
var _dragging: bool = false
var _fog_lifted: bool = false
## Where the light is on CYCLE (1.5: halfway from its second frame to its third), and where it goes.
var _light_at: float = 1.0
var _light_goal: float = 1.0
var _since_saved: float = 0.0
var _saved_place: Array = []
var _panel: PanelContainer
var _status: Label
var _map_list: OptionButton
var _zone_list: OptionButton
var _frame_list: OptionButton
var _cloud_list: OptionButton
var _side_button: Button
var _flow_button: Button


func _ready() -> void:
	# After the view and the HUD, whose frames this one corrects.
	process_priority = 100
	_build_panel()
	await get_tree().process_frame
	await get_tree().process_frame
	session = (load(SESSION_SCENE) as PackedScene).instantiate() as WorldSessionController
	session.configure_source_entry("预览", CharacterState.GENDER_MALE)
	add_child(session)
	await get_tree().create_timer(0.3).timeout
	session.hold_presentation(HOLD, true)
	for known: WorldMapController in session.world_maps():
		if known.get_node_or_null("MapView") != null:
			_maps.append(known.map_id())
	_maps.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	_fill_map_list()
	var settings: ConfigFile = _load_settings()
	frame = str(settings.get_value("view", "frame", "day"))
	_light_goal = float(CYCLE.find(frame))
	_light_at = _light_goal
	cloud = int(settings.get_value("view", "cloud", 0))
	left_view = bool(settings.get_value("view", "left", false))
	var last: StringName = StringName(str(settings.get_value("view", "map", "")))
	if show_map(last if _maps.has(last) else session.active_map_id()) and map.map_id() == last:
		focus = settings.get_value("view", "focus", focus)
		zoom = float(settings.get_value("view", "zoom", zoom))
	prepared.emit()


## Onto `map_id`, looking where its entry stands. False when the world refuses.
func show_map(map_id: StringName) -> bool:
	if not _maps.has(map_id):
		_status.text = "没有体素视角：%s" % map_id
		return false
	if session.active_map_id() != map_id and not _enter(map_id):
		_status.text = "进不去：%s" % map_id
		return false
	map = session.active_map() as WorldMapController
	view = map.get_node("MapView") as WorldVoxelView
	view.set_process_unhandled_input(false)
	view.set_frame(frame, true)
	view.set_cloud(cloud, true)
	view.set_view_side(left_view, true)
	_light_at = _light_at if flowing else _light_goal
	# Out of every zone, passage and wall: where the camera goes the map does not react.
	map.player_body.collision_layer = 0
	map.player_body.collision_mask = 0
	focus = map.player_body.global_position
	zoom = 1.0
	_fill_zone_list()
	_sync_panel()
	_status.text = String(map_id)
	return true


func show_zone(zone_id: StringName) -> void:
	focus = map.physical_zone(zone_id).global_rect().get_center()


## The whole map on the screen, seen along the view's own axes.
func fit_map() -> void:
	if view == null or view.camera == null:
		return
	var basis: Basis = view.camera.global_transform.basis
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	var whole := Rect2()
	for zone: WorldPhysicalZoneArea2D in map.physical_zones():
		var rect: Rect2 = zone.global_rect()
		whole = rect if whole.size == Vector2.ZERO else whole.merge(rect)
		for corner: Vector2 in [rect.position, rect.position + Vector2(rect.size.x, 0), rect.position + Vector2(0, rect.size.y), rect.end]:
			var at: Vector3 = VoxelMapGeometry.point(corner)
			var seen := Vector2(at.dot(basis.x), at.dot(basis.y))
			low = Vector2(minf(low.x, seen.x), minf(low.y, seen.y))
			high = Vector2(maxf(high.x, seen.x), maxf(high.y, seen.y))
	var span: Vector2 = (high - low) * 1.1
	var screen: Vector2 = get_viewport().get_visible_rect().size
	focus = whole.get_center()
	zoom = clampf(maxf(span.y, span.x * screen.y / screen.x) / _base_size(), MIN_ZOOM, MAX_ZOOM)


## Reads the map's voxel config again: the view builds its world anew on its next frame.
func reload_view() -> void:
	if view == null:
		return
	view.release_world()
	_fog_lifted = false
	_status.text = "已重读：%s" % map.map_id()


## The hour goes to `value` the short way round the day, the light sweeping as it goes.
func set_frame(value: String) -> void:
	frame = value
	flowing = false
	_light_goal = float(CYCLE.find(frame))
	if view != null:
		view.set_frame(frame)
	_sync_panel()


## The hour runs on round the day, or stops at the frame it has come to.
func set_flowing(on: bool) -> void:
	flowing = on
	if not on:
		set_frame(_nearest_frame())
	_sync_panel()


func set_cloud(value: int) -> void:
	cloud = value
	if view != null:
		view.set_cloud(cloud, true)
	_sync_panel()


func set_side(left: bool) -> void:
	left_view = left
	if view != null:
		view.set_view_side(left_view)
	_sync_panel()


func _process(delta: float) -> void:
	if session != null:
		session.shared_ui().visible = false
		session.shared_ui().view_overlay.visible = false
	if map == null or view == null or not view._built:
		return
	_since_saved += delta
	if _since_saved >= SAVE_SECONDS:
		_since_saved = 0.0
		_save_settings()
	var move: Vector2 = Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	var size: float = _base_size() * zoom
	focus += map.player_body.movement_basis.basis_xform(move) * size * VoxelMapGeometry.UNIT * PAN_SPEED * delta
	map.player_body.global_position = focus
	map.player_body.visible = show_player
	if view.quest_marker != null:
		view.quest_marker.visible = false
	_advance_light(delta)
	_place_camera(size)


func _advance_light(delta: float) -> void:
	var count: float = float(CYCLE.size())
	var step: float = delta / LEG_SECONDS
	if flowing:
		_light_at = fposmod(_light_at + step, count)
		if _nearest_frame() != frame:
			frame = _nearest_frame()
			_light_goal = float(CYCLE.find(frame))
			view.set_frame(frame)
			_sync_panel()
	elif _light_at == _light_goal:
		return
	else:
		var way: float = fposmod(_light_goal - _light_at + count / 2.0, count) - count / 2.0
		if absf(way) <= step:
			_light_at = _light_goal
			view.set_frame(frame, true)
			return
		_light_at = fposmod(_light_at + signf(way) * step, count)
	_show_light()


## The game's light at `_light_at`, between two frames as it blends across a phase boundary. The
## view holds the frame it is going to; this frame's blend is put over that.
func _show_light() -> void:
	var lighting: VoxelLighting = view.lighting
	var first: int = int(_light_at) % CYCLE.size()
	var share: float = _light_at - floorf(_light_at)
	for name: String in CYCLE:
		lighting.weights[name] = 0.0
	lighting.weights[CYCLE[first]] = 1.0 - share
	lighting.weights[CYCLE[(first + 1) % CYCLE.size()]] = share
	lighting._apply()


func _nearest_frame() -> String:
	return CYCLE[roundi(_light_at) % CYCLE.size()]


func _place_camera(size: float) -> void:
	var camera: Camera3D = view.camera
	camera.size = size
	var extra: float = maxf(0.0, (size - NEAR_LIMIT_SIZE) * 0.7)
	camera.position += camera.basis.z * extra
	camera.far = 160.0 + extra + size
	var lighting: VoxelLighting = view.lighting
	if lighting.sun != null:
		lighting.sun.directional_shadow_max_distance = 80.0 + extra + size
	var lift: bool = zoom > FOG_ZOOM
	if lift:
		lighting.environment.fog_enabled = false
		lighting.environment.volumetric_fog_enabled = false
	elif _fog_lifted:
		# The lighting puts its own fog back on an immediate frame.
		view.set_frame(frame, true)
	_fog_lifted = lift


func _unhandled_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button != null:
		if button.button_index == MOUSE_BUTTON_RIGHT or button.button_index == MOUSE_BUTTON_MIDDLE:
			_dragging = button.pressed
		elif button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom = maxf(zoom / ZOOM_STEP, MIN_ZOOM)
		elif button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom = minf(zoom * ZOOM_STEP, MAX_ZOOM)
		return
	var motion := event as InputEventMouseMotion
	if motion != null and _dragging and map != null:
		focus -= map.view_ground.affine_inverse().basis_xform(motion.relative)
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_F:
			fit_map()
		KEY_R:
			reload_view()
		KEY_Q:
			set_side(not left_view)
		KEY_T:
			set_flowing(not flowing)
		KEY_H:
			_panel.visible = not _panel.visible
		KEY_P:
			show_player = not show_player


func _enter(map_id: StringName) -> bool:
	var target: WorldMapController = session.resident_map(map_id) as WorldMapController
	var zones: Array[WorldPhysicalZoneArea2D] = target.physical_zones()
	if zones.is_empty():
		return false
	var definition: MapDefinition = GameContent.catalog().map(map_id)
	var entry: String = String(definition.entry_spawn_id)
	for zone: WorldPhysicalZoneArea2D in zones:
		var id: StringName = zone.zone_id
		if entry.begins_with(String(id) + ".") and session.handoff_to(map_id, id, id, definition.entry_spawn_id).succeeded():
			return true
	# A map without a usable entry: the middle of its first room.
	var first: StringName = zones[0].zone_id
	return session.handoff_to_point(map_id, first, first, zones[0].global_rect().get_center()).succeeded()


func _base_size() -> float:
	return float(view.layout.get("camera_size", 24.0))


func _load_settings() -> ConfigFile:
	var settings := ConfigFile.new()
	if remember:
		settings.load(SETTINGS_PATH)
	return settings


## On a clock, not on leaving: the editor's stop button kills the process.
func _save_settings() -> void:
	var place: Array = [map.map_id(), frame, cloud, left_view, focus, zoom]
	if not remember or place == _saved_place:
		return
	_saved_place = place
	var settings := ConfigFile.new()
	settings.set_value("view", "map", String(map.map_id()))
	settings.set_value("view", "frame", frame)
	settings.set_value("view", "cloud", cloud)
	settings.set_value("view", "left", left_view)
	settings.set_value("view", "focus", focus)
	settings.set_value("view", "zoom", zoom)
	settings.save(SETTINGS_PATH)


func _build_panel() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	_panel = PanelContainer.new()
	_panel.position = Vector2(12, 12)
	_panel.custom_minimum_size.x = PANEL_WIDTH
	layer.add_child(_panel)
	var box := VBoxContainer.new()
	_panel.add_child(box)
	_status = Label.new()
	_status.text = "正在搭世界……"
	box.add_child(_status)
	_map_list = _list(box, func(index: int) -> void: show_map(_maps[_map_list.get_item_id(index)]))
	_zone_list = _list(box, func(index: int) -> void: show_zone(_zones[index]))
	_frame_list = _list(box, func(index: int) -> void: set_frame(FRAMES.keys()[index]))
	for key: String in FRAMES:
		_frame_list.add_item(FRAMES[key])
	_cloud_list = _list(box, func(index: int) -> void: set_cloud(index))
	for level: int in 5:
		_cloud_list.add_item("云量 %d" % level)
	_flow_button = _button(box, "", func() -> void: set_flowing(not flowing))
	_side_button = _button(box, "", func() -> void: set_side(not left_view))
	_button(box, "看全图（F）", fit_map)
	_button(box, "重读配置（R）", reload_view)
	var help := Label.new()
	help.text = "WASD / 方向键 / 右键拖：移动\n滚轮：缩放  Q：换边\nP：显示玩家  H：隐藏面板"
	box.add_child(help)


func _list(parent: Control, chosen: Callable) -> OptionButton:
	var list := OptionButton.new()
	list.focus_mode = Control.FOCUS_NONE
	list.fit_to_longest_item = false
	list.clip_text = true
	list.custom_minimum_size.x = PANEL_WIDTH
	list.item_selected.connect(chosen)
	parent.add_child(list)
	return list


func _button(parent: Control, text: String, pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(pressed)
	parent.add_child(button)
	return button


func _fill_map_list() -> void:
	var names: Dictionary[String, String] = {}
	var atlas: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/common/atlas.json"))
	for row: Dictionary in atlas["atlas"]:
		names[str(row["map"])] = str(row.get("name", ""))
	var region: String = ""
	for index: int in _maps.size():
		var id: String = String(_maps[index])
		if id.get_slice(".", 0) != region:
			region = id.get_slice(".", 0)
			_map_list.add_separator(region)
		_map_list.add_item("%s  %s" % [id, names.get(id, "")] if names.has(id) else id, index)


func _fill_zone_list() -> void:
	_zones.clear()
	_zone_list.clear()
	var zones: Array[WorldPhysicalZoneArea2D] = map.physical_zones()
	zones.sort_custom(func(a: WorldPhysicalZoneArea2D, b: WorldPhysicalZoneArea2D) -> bool: return String(a.zone_id) < String(b.zone_id))
	for zone: WorldPhysicalZoneArea2D in zones:
		_zones.append(zone.zone_id)
		var definition: ZoneDefinition = GameContent.catalog().zone(zone.zone_id)
		_zone_list.add_item("%s  %s" % [zone.zone_id, definition.display_name if definition != null else ""])


func _sync_panel() -> void:
	if map == null:
		return
	_map_list.select(_map_list.get_item_index(_maps.find(map.map_id())))
	_zone_list.select(_zones.find(session.player_runtime().world_location().zone_id))
	_frame_list.select(FRAMES.keys().find(frame))
	_cloud_list.select(cloud)
	_side_button.text = "换到%s视角（Q）" % ("右" if left_view else "左")
	_flow_button.text = "停住时间（T）" if flowing else "时间流动（T）"
