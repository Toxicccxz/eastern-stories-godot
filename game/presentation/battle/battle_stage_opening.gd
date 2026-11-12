class_name BattleStageOpening
extends Node

## 战斗演出 B (DECISIONS「战斗演出 B」): a fight's opening, owner 2026-11-08 — the camera draws in,
## flattens and puts the fighters in the middle, a stepped base of bricks is laid (BattleArena)
## with its sounds, then the battle panel slides in: the title drops, the cards come down (the
## player's side first), the panel rises. Any key or click while it runs puts everything in place
## at once. The first opening_full_fights fights of a run of the game open in full, the rest short
## (one drop a step, a quicker camera); 自动 always short; the setting 战斗开场动画 can make every
## one short, or lay the stage at once. A 切磋 that turns 死斗 restains the base (not skippable:
## the fight now kills). At the fight's end the base is taken down and the camera given back.
## 战斗演出 D (DECISIONS「战斗演出 D」), owner 2026-11-08 after playing B: the fighters are taken out
## of the map — while the camera draws in, they and the base being laid rise together off the
## ground to a stage in the air over the fight (its standard size for them, turned to face the
## camera), drawing into their places as they go (the player on the left, their side behind them,
## the other side on the right, a crowd in two or three ranks); the map sinks under a soft, darker,
## faded backdrop tinted by the mode (VoxelBackdrop). At the end they come down to where their
## bodies stand, the base is taken down and the backdrop clears.
## Presentation only: it holds no rule and moves no body (WorldVoxelView.place_actor() draws the
## figures there); while it runs the panel tells no line (they wait).

signal finished
## 战斗演出 E: the panel begins to slide in, over `seconds` (0: at once).
signal sliding(seconds: float)

enum Kind { FULL, SHORT, OFF }

## 战斗演出 C: the band keeps this much over the fighters' heads for the move's name.
const TITLE_HEADROOM: float = 1.0
## 战斗演出 D: the show's space reaches this far (units) past the base's foot all round.
const BACKDROP_MARGIN: float = 0.6
## What stands between the eye and the stage gives way over the base's foot and this high over
## its top (the fighters, a lunge's leap; owner, 2026-11-12: a gorge's walls hid the stage).
const CLEAR_OVER: float = 2.4

## Fights opened this run of the game (not saved): the first few open in full.
static var fights_opened: int = 0

var arena: BattleArena
var view: WorldVoxelView
## 战斗演出 D: the map's backdrop under the raised stage.
var backdrop: VoxelBackdrop
var kind: int = Kind.FULL
var _running: bool = false
var _slide: Array = []
var _slide_tween: Tween
var _laid: bool = false
var _risen: bool = false
var _slid: bool = false
var _scale: float = 1.0
var _target := Vector3.ZERO
var _height: float = WorldVoxelView.VIEW_HEIGHT
var _zoom: float = 1.0
## 战斗演出 D: the stage's foot on the ground (the fight's middle), its turn (the camera's yaw),
## how high it rises, how far it has (0 .. 1), and each fighter's place on it (the stage's own px)
## and in the world; the player's side (the player first) and the other.
var _anchor := Vector3.ZERO
var _yaw: float = 0.0
var _float: float = 2.6
var _rise: float = 0.0
var _rise_tween: Tween
var _local: Dictionary[StringName, Vector2] = {}
var _spots: Dictionary[StringName, Vector3] = {}
var _mine: Array[StringName] = []
var _theirs: Array[StringName] = []
var _player_id: StringName = &""
## The coming down after the fight (its tween; the view and backdrop it lets go of when done).
var _land_tween: Tween
var _landing: Array = []


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
		if not _risen:
			_on_risen()


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
	return next_kind(auto) == Kind.OFF or (feel.opening_camera_seconds <= 0.0 and feel.arena_build_max_seconds <= 0.0 and feel.opening_slide_seconds <= 0.0 and feel.opening_rise_seconds <= 0.0)


## Whether this opening took no time.
var instant: bool = false


## The opening of a fight on `map` shown in `p_view`: `fighters` each one's 2D point by id,
## `player_id` among them, `foes` those on the other side (the one the player faces first);
## `mode` the fight's; `band` the share of the screen the fighters should stand in (战斗演出 E:
## between the side panels, under the head, over the panel); `slide` the panel's parts to slide in, each
## [Control, from offset Vector2, delay share].
func open(p_view: WorldVoxelView, map: WorldMapController, fighters: Dictionary[StringName, Vector2], player_id: StringName, foes: Array[StringName], mode: int, band: Rect2, slide: Array, auto: bool) -> void:
	close(0.0)
	instant = next_instant(auto)
	kind = next_kind(auto)
	fights_opened += 1
	view = p_view
	_slide = slide
	_laid = false
	_risen = false
	_slid = false
	_player_id = player_id
	var feel: FeelDefinition = GameContent.catalog().pacing().feel
	_scale = BattlePace.real_seconds(1.0) * (0.5 if kind == Kind.SHORT else 1.0)
	if instant:
		_scale = 0.0
	_running = true
	_hide_slide()
	if view == null or view.world == null or view.camera == null or map == null or not fighters.has(player_id):
		_on_laid()
		_on_risen()
		return
	_sides(fighters, foes)
	var arena_data: Dictionary = BattleArena.data().get("arena", {})
	_float = float(arena_data.get("float_height", 3.4))
	# A room's walls stay under the stage (a hall's stand taller).
	if view.geometry != null and bool(view.layout.get("indoor", false)):
		_float = maxf(_float, view.geometry.wall_height + 0.2)
	_yaw = -WorldVoxelView.VIEW_SIDE_ANGLE if view.left_view else WorldVoxelView.VIEW_SIDE_ANGLE
	var player: Vector2 = fighters[player_id]
	var middle: Vector2 = player
	if not _theirs.is_empty():
		var sum := Vector2.ZERO
		for id: StringName in _theirs:
			sum += fighters[id]
		middle = player.lerp(sum / float(_theirs.size()), 0.5)
	_anchor = VoxelMapGeometry.point(middle, 0.0)
	arena = BattleArena.new()
	arena.name = "BattleArena"
	arena.position = _anchor
	arena.rotation.y = _yaw
	view.world.add_child(arena)
	arena.laid.connect(_on_laid)
	backdrop = VoxelBackdrop.new()
	view.world.add_child(backdrop)
	backdrop.set_look(_look_of(mode).get("backdrop", {}))
	_local = BattleArena.formation(_mine, _theirs, BattleArena.data().get("formation", {}))
	arena.lay(_points(), _local[player_id], mode, _scale, kind == Kind.SHORT, hash(Vector2i((middle / BattleArena.CELL).floor())))
	_place()
	_frame(band, BattleArena.small_room(map, player))
	view.stage(_target, _height, _zoom, feel.opening_camera_seconds * _scale)
	var rise: float = feel.opening_rise_seconds * _scale
	if rise <= 0.0:
		_set_rise(1.0)
		_on_risen()
	else:
		_set_rise(0.0)
		_rise_tween = create_tween()
		_rise_tween.tween_method(_set_rise, 0.0, 1.0, rise)
		_rise_tween.tween_callback(_on_risen)


## The two sides from `fighters` (their order kept): the player and those not in `foes`, then
## `foes` in their order.
func _sides(fighters: Dictionary[StringName, Vector2], foes: Array[StringName]) -> void:
	_mine = [_player_id]
	_theirs = []
	for id: StringName in foes:
		if fighters.has(id) and id != _player_id:
			_theirs.append(id)
	for id: StringName in fighters:
		if id != _player_id and not _theirs.has(id):
			_mine.append(id)


static func _look_of(mode: int) -> Dictionary:
	return BattleArena.data().get("looks", {}).get(BattleArena.look_for(mode), {})


## Every fighter's place in the world (the stage's place, raised to its top), shown there.
func _place() -> void:
	_spots.clear()
	if view == null or not is_instance_valid(view) or arena == null or not is_instance_valid(arena):
		return
	var turn := Basis(Vector3.UP, _yaw)
	var top: float = _float + arena.top_height()
	var right: Vector3 = turn * Vector3.RIGHT
	for id: StringName in _local:
		var at: Vector2 = _local[id] / VoxelMapGeometry.UNIT
		_spots[id] = _anchor + turn * Vector3(at.x, top, at.y)
		var facing: Vector3 = right if _mine.has(id) else -right
		view.place_actor(id, _spots[id], atan2(facing.x, facing.z))


func _points() -> Array[Vector2]:
	var points: Array[Vector2] = []
	for id: StringName in _local:
		points.append(_local[id])
	return points


## How far the stage has risen (0 on the ground, 1 in the air): the stage, the backdrop under it
## and the figures (eased together).
func _set_rise(progress: float) -> void:
	_rise = clampf(progress, 0.0, 1.0)
	var eased: float = smoothstep(0.0, 1.0, _rise)
	if arena != null and is_instance_valid(arena):
		arena.position.y = _anchor.y + _float * eased
	if backdrop != null and is_instance_valid(backdrop):
		backdrop.amount = eased
		if arena != null and is_instance_valid(arena):
			backdrop.hold(arena.global_transform, arena.footprint(BACKDROP_MARGIN))
	_hold_clear()
	if view != null and is_instance_valid(view):
		view.placed_blend = eased


## The map's occluders give way round the stage where it stands now (VoxelOcclusion.hold_show).
func _hold_clear() -> void:
	if view == null or not is_instance_valid(view) or arena == null or not is_instance_valid(arena) or not arena.is_inside_tree():
		return
	view.occlusion.hold_show(arena.global_transform, arena.footprint(0.1), -0.1, arena.top_height() + CLEAR_OVER)


## Someone joined the fight (summoned, or one more of a gang): a place for them at the back of
## their side, the stage laid wider when they would stand off it. `fighters` / `foes` as open().
func seat(fighters: Dictionary[StringName, Vector2], foes: Array[StringName]) -> void:
	if arena == null or not is_instance_valid(arena) or _local.is_empty():
		return
	# One gone from the fight while still standing on the map (fled, let go) comes down; the
	# fallen stay (their corpse lies on the stage).
	for id: StringName in _local.keys():
		if not fighters.has(id) and id != _player_id and view != null and is_instance_valid(view) and view.actors.has(id):
			_local.erase(id)
			_spots.erase(id)
			_mine.erase(id)
			_theirs.erase(id)
			view.unplace(id)
	var added: bool = false
	for id: StringName in fighters:
		if _local.has(id):
			continue
		added = true
		if foes.has(id):
			_theirs.append(id)
		else:
			_mine.append(id)
	if not added:
		return
	_local = BattleArena.formation(_mine, _theirs, BattleArena.data().get("formation", {}))
	arena.grow_to(_points(), _local[_player_id])
	_place()
	if backdrop != null and is_instance_valid(backdrop):
		backdrop.hold(arena.global_transform, arena.footprint(BACKDROP_MARGIN))
	_hold_clear()


## Where the camera looks, how high over it and how near: on the player and the middle of the
## others on the stage, as near as everyone still stands inside the band (the stage's zoom for a
## duel, back to its crowd_zoom for a crowd), the band's middle where the fighters' middle shows.
func _frame(band: Rect2, small: bool) -> void:
	var camera_data: Dictionary = BattleArena.data().get("camera", {})
	var degrees: float = float(camera_data.get("small_pitch_degrees" if small else "pitch_degrees", 26.0))
	_height = WorldVoxelView.VIEW_RADIUS * tan(deg_to_rad(degrees))
	_zoom = float(camera_data.get("zoom", 0.4))
	var others: Array[Vector3] = []
	for id: StringName in _spots:
		if id != _player_id:
			others.append(_spots[id])
	# The stage's foot, its near edge above the panel (it reads standing in the air).
	var edges: Array[Vector3] = []
	var foot: Rect2 = arena.footprint(0.0) if arena != null and is_instance_valid(arena) else Rect2()
	var turn := Basis(Vector3.UP, _yaw)
	for corner: Vector2 in [foot.position, Vector2(foot.end.x, foot.position.y), Vector2(foot.position.x, foot.end.y), foot.end]:
		edges.append(_anchor + turn * Vector3(corner.x, _float, corner.y))
	var fit: Array = _fit(_spots[_player_id], others, band, camera_data, edges)
	_target = fit[0]
	_zoom = clampf(fit[1], float(camera_data.get("zoom", 0.4)), float(camera_data.get("crowd_zoom", 0.85)))
	if fit.size() > 2:
		_target = fit[0] + (fit[2] as Vector3) * _shift(fit, band) + (fit[5] as Vector3) * _shift_across(band)


## [target, zoom needed, the camera's up, low, high] for the player and `others` (their feet in
## the world), `edges` (the stage's foot) shown too: the target halfway between the player and the
## others' middle.
func _fit(player_foot: Vector3, others: Array[Vector3], band: Rect2, camera_data: Dictionary, edges: Array[Vector3] = []) -> Array:
	var lift := Vector3.UP * 0.9
	var player: Vector3 = player_foot + lift
	var middle := Vector3.ZERO
	for foot: Vector3 in others:
		middle += foot + lift
	var target: Vector3 = player if others.is_empty() else player.lerp(middle / float(others.size()), 0.5)
	if view == null or view.camera == null:
		return [target, float(camera_data.get("zoom", 0.4))]
	# The camera's axes once staged (its yaw stays the map's; only the height changes).
	var offset := Vector3(sin(_yaw) * WorldVoxelView.VIEW_RADIUS, _height, cos(_yaw) * WorldVoxelView.VIEW_RADIUS)
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
	var points: Array[Vector3] = [player_foot]
	points.append_array(others)
	for foot: Vector3 in points:
		var at: Vector3 = foot + lift - target
		wide = maxf(wide, absf(at.dot(right)) + 0.5)
		low = minf(low, at.dot(up) - 0.9)
		# Room over the head for the move's name (BattleMoveTitles' rise and a line of it).
		high = maxf(high, at.dot(up) + 0.9 + TITLE_HEADROOM)
	for edge: Vector3 in edges:
		var at: Vector3 = edge - target
		wide = maxf(wide, absf(at.dot(right)))
		low = minf(low, at.dot(up) - 0.15)
	var top: float = clampf(band.position.y, 0.05, 0.9)
	var bottom: float = clampf(band.end.y, top + 0.1, 0.98)
	var across: float = clampf(band.size.x, 0.3, 1.0)
	var size_needed: float = maxf(wide * 2.0 / (aspect * across * 0.9), (high - low) / ((bottom - top) * 0.85))
	return [target, size_needed / view.base_size(), up, low, high, right]


## How far along the camera's up the look-at point moves so that the fighters' middle shows at
## the band's middle (the zoom chosen).
func _shift(fit: Array, band: Rect2) -> float:
	var top: float = clampf(band.position.y, 0.05, 0.9)
	var bottom: float = clampf(band.end.y, top + 0.1, 0.98)
	var size: float = view.base_size() * _zoom
	return (float(fit[3]) + float(fit[4])) / 2.0 - size * (0.5 - (top + bottom) / 2.0)


## How far along the camera's right the look-at point moves so the fighters' middle shows at the
## band's middle across (the side panels may stand unevenly).
func _shift_across(band: Rect2) -> float:
	var aspect: float = 16.0 / 9.0
	var visible: Rect2 = view.get_viewport().get_visible_rect() if view.is_inside_tree() else Rect2()
	if visible.size.y > 0.0:
		aspect = visible.size.x / visible.size.y
	var width: float = view.base_size() * _zoom * aspect
	return -width * (band.get_center().x - 0.5)


## The camera's frame (tests): [target, height, zoom].
func frame() -> Array:
	return [_target, _height, _zoom]


## Each fighter's place in the world on the raised stage (tests, kits).
func spots() -> Dictionary[StringName, Vector3]:
	return _spots


## 战斗演出 E: whether `id` stands behind another of their side in their column (their name plate
## goes over their head, the front one's under the feet).
func back_rank(id: StringName) -> bool:
	if not _local.has(id):
		return false
	var rows: int = maxi(1, int(BattleArena.data().get("formation", {}).get("rows", 3)))
	for side: Array[StringName] in [_mine, _theirs]:
		var at: int = side.find(id)
		if at < 0:
			continue
		# The columns as formation() lays them: the player alone first on their side, then `rows`.
		var start: int = 0
		var lead: int = 1 if side == _mine else 0
		if at < lead:
			return false
		start = at - (at - lead) % rows
		for other: int in range(start, mini(side.size(), start + rows)):
			if other != at and _local.has(side[other]) and _local[side[other]].y > _local[id].y:
				return true
	return false


## How far the stage has risen now (0 .. 1).
func risen() -> float:
	return _rise


## The share of the panel's own shade to keep now: the backdrop darkens the map in its place
## (battle_stage.json backdrop.shade), as far as it has come in.
func shade_share() -> float:
	if backdrop == null or not is_instance_valid(backdrop):
		return 1.0
	var keep: float = float(BattleArena.data().get("backdrop", {}).get("shade", 0.3))
	return lerpf(1.0, keep, backdrop.amount)


func _on_laid() -> void:
	_laid = true
	_try_slide()


func _on_risen() -> void:
	_risen = true
	_try_slide()


## The panel slides in once the base is laid and up.
func _try_slide() -> void:
	if not _laid or not _risen or _slid:
		return
	_slid = true
	_slide_in(GameContent.catalog().pacing().feel.opening_slide_seconds * _scale)


## The panel's parts hidden at their offsets before they slide.
func _hide_slide() -> void:
	for part: Array in _slide:
		var control: Control = part[0]
		if is_instance_valid(control):
			control.modulate.a = 0.0


func _slide_in(seconds: float) -> void:
	if _slide_tween != null and _slide_tween.is_valid():
		_slide_tween.kill()
	sliding.emit(seconds)
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
	# The banners down at once too.
	sliding.emit(0.0)
	_slid = true
	if _slide_tween != null and _slide_tween.is_valid():
		_slide_tween.kill()
	if _rise_tween != null and _rise_tween.is_valid():
		_rise_tween.kill()
	_set_rise(1.0)
	_risen = true
	if arena != null and is_instance_valid(arena) and arena.laying():
		arena.skip()
	if view != null and is_instance_valid(view) and view.staged:
		view.stage(_target, _height, _zoom, 0.0)
	_laid = true
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


## The fight turned from 切磋 to 死斗: the base and the backdrop restained (`seconds`; not skipped).
func restyle(mode: int) -> void:
	var seconds: float = BattlePace.real_seconds(GameContent.catalog().pacing().feel.arena_restyle_seconds)
	if arena != null and is_instance_valid(arena):
		arena.restyle(mode, seconds)
	if backdrop != null and is_instance_valid(backdrop):
		backdrop.set_look(_look_of(mode).get("backdrop", {}), seconds)


## The fight is over: the fighters come down to their bodies, the base is taken down, the
## backdrop clears and the camera is given back over `seconds` (0: at once).
func close(seconds: float = -1.0) -> void:
	_finish_landing()
	var feel: FeelDefinition = GameContent.catalog().pacing().feel
	var take_down: float = feel.arena_take_down_seconds if seconds < 0.0 else seconds
	var back: float = maxf(feel.battle_zoom_seconds, take_down) if seconds < 0.0 else seconds
	if _slide_tween != null and _slide_tween.is_valid():
		_slide_tween.kill()
	if _rise_tween != null and _rise_tween.is_valid():
		_rise_tween.kill()
	if _running:
		_settle_slide()
	_running = false
	if arena != null and is_instance_valid(arena):
		arena.take_down(take_down)
	arena = null
	var shown: WorldVoxelView = view if view != null and is_instance_valid(view) else null
	var veil: VoxelBackdrop = backdrop if backdrop != null and is_instance_valid(backdrop) else null
	if shown != null and shown.staged:
		shown.unstage(back)
	_landing = [shown, veil]
	if back > 0.0 and (veil != null or (shown != null and shown.placing())):
		var from: float = shown.placed_blend if shown != null else (veil.amount if veil != null else 0.0)
		_land_tween = create_tween()
		_land_tween.tween_method(_set_land, from, 0.0, back).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)
		_land_tween.tween_callback(_finish_landing)
	else:
		_finish_landing()
	view = null
	backdrop = null
	_local.clear()
	_spots.clear()
	_mine.clear()
	_theirs.clear()
	_rise = 0.0


func _set_land(blend: float) -> void:
	var shown: Variant = _landing[0] if _landing.size() > 0 else null
	var veil: Variant = _landing[1] if _landing.size() > 1 else null
	if shown != null and is_instance_valid(shown):
		(shown as WorldVoxelView).placed_blend = blend
	if veil != null and is_instance_valid(veil):
		(veil as VoxelBackdrop).amount = blend


## The coming down done (or cut short by the next opening): every figure on its body again, the
## backdrop gone.
func _finish_landing() -> void:
	if _land_tween != null and _land_tween.is_valid():
		_land_tween.kill()
	_land_tween = null
	if _landing.is_empty():
		return
	var shown: Variant = _landing[0]
	var veil: Variant = _landing[1]
	_landing = []
	if shown != null and is_instance_valid(shown):
		(shown as WorldVoxelView).release_placed()
		(shown as WorldVoxelView).occlusion.clear_show()
	if veil != null and is_instance_valid(veil):
		(veil as Node).queue_free()


## Whether figures are still coming down after a fight (tests).
func landing() -> bool:
	return not _landing.is_empty()
