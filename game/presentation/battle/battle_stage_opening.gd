class_name BattleStageOpening
extends Node

## 战斗演出 B (DECISIONS「战斗演出 B」): a fight's opening, owner 2026-11-08 — the camera draws in,
## flattens and puts the fighters in the middle, a stepped base of bricks is laid under their
## feet (BattleArena) with its sounds, they step up onto it, then the battle panel slides in: the
## title drops, the cards come down (the player's side first), the panel rises. Any key or click
## while it runs puts everything in place at once. The first opening_full_fights fights of a run
## of the game open in full, the rest short (one drop a step, a quicker camera); 自动 always short;
## the setting 战斗开场动画 can make every one short, or lay the stage at once. A 切磋 that turns
## 死斗 restains the base (not skippable: the fight now kills). At the fight's end the base is
## taken down and the camera given back.
## Presentation only: it holds no rule; while it runs the panel tells no line (they wait).

signal finished

enum Kind { FULL, SHORT, OFF }

## 战斗演出 C: the band keeps this much over the fighters' heads for the move's name.
const TITLE_HEADROOM: float = 1.0

## Fights opened this run of the game (not saved): the first few open in full.
static var fights_opened: int = 0

var arena: BattleArena
var view: WorldVoxelView
var kind: int = Kind.FULL
var _running: bool = false
var _slide: Array = []
var _slide_tween: Tween
var _laid: bool = false
var _scale: float = 1.0
var _lift: Callable
var _fighters: Dictionary[StringName, Vector2] = {}
var _target := Vector3.ZERO
var _height: float = WorldVoxelView.VIEW_HEIGHT
var _zoom: float = 1.0


## Whether the opening is still playing.
func running() -> bool:
	return _running


## The map's voxel world released while the base was being laid (it went with the world): the
## opening goes on without it, so the panel is not left waiting.
func _process(_delta: float) -> void:
	if _running and arena != null and not is_instance_valid(arena):
		arena = null
		if not _laid:
			_on_laid()


## The kind of opening the next fight takes: OFF / SHORT by the setting, SHORT under 自动 or
## after the first opening_full_fights of this run, else FULL.
static func next_kind(auto: bool) -> int:
	if BattlePace.opening == BattlePace.Opening.OFF:
		return Kind.OFF
	if BattlePace.opening == BattlePace.Opening.SHORT or auto:
		return Kind.SHORT
	return Kind.FULL if fights_opened < GameContent.catalog().pacing().feel.opening_full_fights else Kind.SHORT


## Whether the next opening takes no time (关, or a feel with its times off — the suites'):
## it is laid at once, the panel's lines never wait on it.
static func next_instant(auto: bool) -> bool:
	var feel: FeelDefinition = GameContent.catalog().pacing().feel
	return next_kind(auto) == Kind.OFF or (feel.opening_camera_seconds <= 0.0 and feel.arena_build_max_seconds <= 0.0 and feel.opening_slide_seconds <= 0.0)


## Whether this opening took no time.
var instant: bool = false


## The opening of a fight on `map` shown in `p_view`: `fighters` each one's 2D point by id,
## `player_id` among them; `mode` the fight's; `band` the share of the screen's height the
## fighters should stand in (top, bottom: under the cards, over the panel); `slide` the panel's
## parts to slide in, each [Control, from offset Vector2, delay share]; `lift` called with
## (id, height, seconds) for each one standing on the top step once it is laid.
func open(p_view: WorldVoxelView, map: WorldMapController, fighters: Dictionary[StringName, Vector2], player_id: StringName, mode: int, band: Vector2, slide: Array, lift: Callable, auto: bool) -> void:
	close(0.0)
	instant = next_instant(auto)
	kind = next_kind(auto)
	fights_opened += 1
	view = p_view
	_fighters = fighters
	_lift = lift
	_slide = slide
	_laid = false
	var feel: FeelDefinition = GameContent.catalog().pacing().feel
	_scale = BattlePace.real_seconds(1.0) * (0.5 if kind == Kind.SHORT else 1.0)
	if instant:
		_scale = 0.0
	_running = true
	_hide_slide()
	if view == null or view.world == null or view.camera == null or map == null or not fighters.has(player_id):
		_on_laid()
		return
	arena = BattleArena.new()
	arena.name = "BattleArena"
	view.world.add_child(arena)
	arena.laid.connect(_on_laid)
	var points: Array[Vector2] = []
	for id: StringName in fighters:
		points.append(fighters[id])
	arena.lay(map, points, fighters[player_id], mode, _scale, kind == Kind.SHORT)
	_frame(fighters, player_id, band, arena.small())
	view.stage(_target, _height, _zoom, feel.opening_camera_seconds * _scale)


## Where the camera looks, how high over it and how near: on the player and the middle of the
## others, as near as everyone still stands inside the band (the stage's zoom for a duel, back to
## its crowd_zoom for a crowd), the band's middle where the fighters' middle shows. A crowd that
## will not fit even at crowd_zoom: those standing on the stage are framed (the player first;
## the others may stand behind the cards — their cards and 换目标 still reach them).
func _frame(fighters: Dictionary[StringName, Vector2], player_id: StringName, band: Vector2, small: bool) -> void:
	var camera_data: Dictionary = BattleArena.data().get("camera", {})
	var degrees: float = float(camera_data.get("small_pitch_degrees" if small else "pitch_degrees", 26.0))
	_height = WorldVoxelView.VIEW_RADIUS * tan(deg_to_rad(degrees))
	_zoom = float(camera_data.get("zoom", 0.4))
	var everyone: Array[Vector2] = []
	var on_stage: Array[Vector2] = []
	for id: StringName in fighters:
		if id == player_id:
			continue
		everyone.append(fighters[id])
		if arena != null and arena.holds(fighters[id]):
			on_stage.append(fighters[id])
	var fit: Array = _fit(fighters[player_id], everyone, band, camera_data)
	if fit[1] > float(camera_data.get("crowd_zoom", 0.85)) and on_stage.size() < everyone.size():
		fit = _fit(fighters[player_id], on_stage, band, camera_data)
	_target = fit[0]
	_zoom = clampf(fit[1], float(camera_data.get("zoom", 0.4)), float(camera_data.get("crowd_zoom", 0.85)))
	if fit.size() > 2:
		_target = fit[0] + (fit[2] as Vector3) * _shift(fit, band)


## [target, zoom needed, the camera's up, low, high] for the player and `others`: the target
## halfway between the player and the others' middle.
func _fit(player_point: Vector2, others: Array[Vector2], band: Vector2, camera_data: Dictionary) -> Array:
	var player: Vector3 = VoxelMapGeometry.point(player_point, 0.9)
	var middle := Vector3.ZERO
	for point: Vector2 in others:
		middle += VoxelMapGeometry.point(point, 0.9)
	var target: Vector3 = player if others.is_empty() else player.lerp(middle / float(others.size()), 0.5)
	if view == null or view.camera == null:
		return [target, float(camera_data.get("zoom", 0.4))]
	# The camera's axes once staged (its yaw stays the map's; only the height changes).
	var offset := Vector3(view.camera_offset().x, _height, view.camera_offset().z)
	var forward: Vector3 = -offset.normalized()
	var right: Vector3 = forward.cross(Vector3.UP).normalized()
	var up: Vector3 = right.cross(forward).normalized()
	var aspect: float = 16.0 / 9.0
	var visible: Rect2 = view.get_viewport().get_visible_rect() if view.is_inside_tree() else Rect2()
	if visible.size.y > 0.0:
		aspect = visible.size.x / visible.size.y
	var wide: float = 0.0
	var low: float = INF
	var high: float = -INF
	var points: Array[Vector2] = [player_point]
	points.append_array(others)
	for point: Vector2 in points:
		var at: Vector3 = VoxelMapGeometry.point(point, 0.9) - target
		wide = maxf(wide, absf(at.dot(right)))
		low = minf(low, at.dot(up) - 0.9)
		# Room over the head for the move's name (BattleMoveTitles' rise and a line of it).
		high = maxf(high, at.dot(up) + 0.9 + TITLE_HEADROOM)
	var top: float = clampf(band.x, 0.05, 0.9)
	var bottom: float = clampf(band.y, top + 0.1, 0.98)
	var size_needed: float = maxf(wide * 2.0 / (aspect * 0.85), (high - low) / ((bottom - top) * 0.85))
	return [target, size_needed / view.base_size(), up, low, high]


## How far along the camera's up the look-at point moves so that the fighters' middle shows at
## the band's middle (the zoom chosen).
func _shift(fit: Array, band: Vector2) -> float:
	var top: float = clampf(band.x, 0.05, 0.9)
	var bottom: float = clampf(band.y, top + 0.1, 0.98)
	var size: float = view.base_size() * _zoom
	return (float(fit[3]) + float(fit[4])) / 2.0 - size * (0.5 - (top + bottom) / 2.0)


## The camera's frame (tests): [target, height, zoom].
func frame() -> Array:
	return [_target, _height, _zoom]


func _on_laid() -> void:
	_laid = true
	var feel: FeelDefinition = GameContent.catalog().pacing().feel
	if arena != null and is_instance_valid(arena) and _lift.is_valid():
		for id: StringName in _fighters:
			if arena.holds(_fighters[id]):
				_lift.call(id, arena.top_height(), 0.12 * _scale)
	_slide_in(feel.opening_slide_seconds * _scale)


## The panel's parts hidden at their offsets before they slide.
func _hide_slide() -> void:
	for part: Array in _slide:
		var control: Control = part[0]
		if is_instance_valid(control):
			control.modulate.a = 0.0


func _slide_in(seconds: float) -> void:
	if _slide_tween != null and _slide_tween.is_valid():
		_slide_tween.kill()
	if seconds <= 0.0:
		_settle_slide()
		_done()
		return
	_slide_tween = create_tween().set_parallel(true)
	for part: Array in _slide:
		var control: Control = part[0]
		if not is_instance_valid(control):
			continue
		var home: Vector2 = control.position
		var delay: float = float(part[2]) * seconds
		var length: float = seconds * 0.5
		control.position = home + (part[1] as Vector2)
		_slide_tween.tween_property(control, "position", home, length).set_delay(delay).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		_slide_tween.tween_property(control, "modulate:a", 1.0, length).set_delay(delay)
	# Home again by the containers' own sort (one may have re-sorted while the parts slid).
	_slide_tween.chain().tween_callback(func() -> void:
		_settle_slide()
		_done())


func _settle_slide() -> void:
	for part: Array in _slide:
		var control: Control = part[0]
		if is_instance_valid(control):
			control.modulate.a = 1.0
			# The container puts it home on its next sort.
			var parent := control.get_parent() as Container
			if parent != null:
				parent.queue_sort()


func _done() -> void:
	if not _running:
		return
	_running = false
	finished.emit()


## Everything in place at once (a key or a click while the opening runs).
func skip() -> void:
	if not _running:
		return
	if _slide_tween != null and _slide_tween.is_valid():
		_slide_tween.kill()
	if arena != null and is_instance_valid(arena) and arena.laying():
		arena.skip()
	if view != null and is_instance_valid(view) and view.staged:
		view.stage(_target, _height, _zoom, 0.0)
	if not _laid:
		_on_laid()
	_settle_slide()
	_done()


## A key or a click while the opening runs skips it.
func _input(event: InputEvent) -> void:
	if not _running or instant:
		return
	if (event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton) and event.is_pressed() and not event.is_echo():
		skip()
		# Esc and the menu key still open (the opening is put in place first); any other press is
		# only the skip.
		if not event.is_action(&"pause_game") and not event.is_action(&"menu_open"):
			get_viewport().set_input_as_handled()


## The fight turned from 切磋 to 死斗: the base restained (`seconds`; not skipped).
func restyle(mode: int) -> void:
	if arena != null and is_instance_valid(arena):
		arena.restyle(mode, BattlePace.real_seconds(GameContent.catalog().pacing().feel.arena_restyle_seconds))


## The fight is over: the base taken down, the camera given back over `seconds` (0: at once).
func close(seconds: float = -1.0) -> void:
	var feel: FeelDefinition = GameContent.catalog().pacing().feel
	var take_down: float = feel.arena_take_down_seconds if seconds < 0.0 else seconds
	if _slide_tween != null and _slide_tween.is_valid():
		_slide_tween.kill()
	if _running:
		_settle_slide()
	_running = false
	if arena != null and is_instance_valid(arena):
		arena.take_down(take_down)
	arena = null
	if view != null and is_instance_valid(view) and view.staged:
		view.unstage(maxf(feel.battle_zoom_seconds, take_down) if seconds < 0.0 else seconds)
	view = null
