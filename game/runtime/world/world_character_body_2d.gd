class_name WorldCharacterBody2D
extends CharacterBody2D

const WorldPlayerRuntimeType := preload(
	"res://runtime/characters/world_player_runtime_state.gd"
)

signal selection_requested(character_id: StringName)

@export var player_controlled: bool = false
@export var movement_speed: float = 220.0

var _player: WorldPlayerRuntimeType
var _npc: NpcRuntimeState
var _character_id: StringName = &""
var _world_simulation_gate: WorldSimulationGate
var _movement_input_quarantined: bool = false
## The player is in custody (WorldMapPatrols): their own walking does nothing; a walk the
## world makes for them (being led) still moves the body. That walk moves it frame by frame
## (WorldNpcWalker), so it is drawn where it is rather than between physics steps.
var held: bool = false:
	set(value):
		if held == value:
			return
		held = value
		_interpolate(_player != null and not value)
		if not value:
			reset_physics_interpolation()
## The view is fading around a map change (WorldSessionController._hold_view()): the
## player stands while it does.
var walk_paused: bool = false
## Maps with a fixed angled view rotate screen input onto the existing walking plane.
## Positions, speed, collisions and saved locations keep their original units.
var movement_basis: Transform2D = Transform2D.IDENTITY
## Collision in effect before a death/absence removed it; restored when the
## character comes back to life.
var _suppressed_collision_layer: int = 0
var _suppressed_collision_mask: int = 0
var _collision_suppressed: bool = false
## A ghost (NpcDefinition.is_ghost()): the player, no ghost, does not see it (char.c
## visible()): not drawn, not picked, walked through. Its presence still meets the player.
## A player who is a ghost too sees it (set_ghost_sight()).
var _unseen: bool = false
var _ghost: bool = false

var character_id: StringName:
	get: return _character_id

## The way the body last moved, one of eight (DECISIONS「手感」): a notch on its edge.
var facing: Vector2 = Vector2.DOWN
var _last_position: Vector2 = Vector2.INF
const FACING_NOTCH_COLOR: Color = Color(1.0, 1.0, 1.0, 0.85)
## A jump further than this in one physics step is a placement, not a step.
const FACING_MAX_STEP: float = 48.0


## Top-down walking (DECISIONS「手感」): a body slides along whatever it walks into, and
## its square becomes the circle the square holds, so it rounds corners and passes
## between two others instead of catching on their edges. The same width: any gap it
## could not pass before, it still cannot.
func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var shape_node: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D
	var square: RectangleShape2D = shape_node.shape as RectangleShape2D if shape_node != null else null
	if square != null:
		var circle: CircleShape2D = CircleShape2D.new()
		circle.radius = minf(square.size.x, square.size.y) / 2.0
		shape_node.shape = circle


## The body was put somewhere rather than walked there: drawn there at once, no glide
## from where it was, and its camera (the player's) is there too.
func placed() -> void:
	velocity = Vector2.ZERO
	_last_position = Vector2.INF
	reset_physics_interpolation()
	var camera: Camera2D = get_node_or_null("Camera2D") as Camera2D
	if camera != null and camera.enabled:
		camera.reset_smoothing()


func _draw() -> void:
	var tip: Vector2 = facing * 31.0
	var base: Vector2 = facing * 22.0
	var side: Vector2 = facing.orthogonal() * 6.0
	draw_colored_polygon(PackedVector2Array([tip, base + side, base - side]), FACING_NOTCH_COLOR)


func _turn_to(direction: Vector2) -> void:
	if direction == Vector2.ZERO:
		return
	var turned: Vector2 = Vector2.from_angle(snappedf(direction.angle(), PI / 4.0))
	if not turned.is_equal_approx(facing):
		facing = turned
		queue_redraw()


## A body the world moves (an NPC walking, the player led) turns the way it went.
func _track_facing() -> void:
	var moved: Vector2 = global_position - _last_position if _last_position.is_finite() else Vector2.ZERO
	_last_position = global_position
	if moved.length_squared() > 0.25 and moved.length() <= FACING_MAX_STEP:
		_turn_to(moved)


func bind_player(value: WorldPlayerRuntimeType) -> bool:
	if value == null or not value.is_valid():
		return false
	_player = value
	_npc = null
	_character_id = value.character_id
	_update_label(value.facts.display_name)
	_interpolate(not held)
	refresh_runtime_state()
	return true


## The player's walk (move_and_slide() in physics steps) is drawn between those steps on a
## faster screen, and its camera with it (DECISIONS「手感」); NPCs, moved frame by frame,
## are not.
func _interpolate(on: bool) -> void:
	# An interpolated camera follows in physics steps (Godot would switch it and warn).
	var camera: Camera2D = get_node_or_null("Camera2D") as Camera2D
	if camera != null:
		camera.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS if on else Camera2D.CAMERA2D_PROCESS_IDLE
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON if on else Node.PHYSICS_INTERPOLATION_MODE_OFF


func bind_npc(value: NpcRuntimeState) -> bool:
	if value == null or not value.is_valid():
		return false
	_npc = value
	_player = null
	_character_id = value.character_id
	_ghost = value.definition().is_ghost()
	_unseen = _ghost
	_update_label(value.definition().display_name)
	refresh_runtime_state()
	return true


## char.c visible(): whether the player sees ghosts now (they are one).
func set_ghost_sight(sees_ghosts: bool) -> void:
	if _npc == null:
		return
	_unseen = _ghost and not sees_ghosts
	refresh_runtime_state()


func bind_world_simulation_gate(value: WorldSimulationGate) -> bool:
	if value == null:
		return false
	_world_simulation_gate = value
	return true


func quarantine_current_movement_input() -> void:
	_movement_input_quarantined = true
	velocity = Vector2.ZERO


## The player walks with the key that left the HUD's list (WASD) without lifting it first.
func release_movement_quarantine() -> void:
	_movement_input_quarantined = false


func movement_input_quarantined() -> bool:
	return _movement_input_quarantined


func set_world_location(value: WorldLocationState) -> bool:
	if _player != null:
		return _player.set_world_location(value)
	if _npc != null:
		return _npc.set_world_location(value)
	return false


func refresh_runtime_state() -> void:
	var exists: bool = _exists()
	var dead: bool = _life_status() == CharacterRuntimeLifeStatus.Value.DEAD
	visible = exists and not dead and not _unseen
	input_pickable = (
		not player_controlled
		and exists
		and not dead
		and not _unseen
	)
	if not exists or dead or _unseen:
		velocity = Vector2.ZERO
		if not _collision_suppressed:
			_suppressed_collision_layer = collision_layer
			_suppressed_collision_mask = collision_mask
			_collision_suppressed = true
		collision_layer = 0
		collision_mask = 0
	elif _collision_suppressed:
		collision_layer = _suppressed_collision_layer
		collision_mask = _suppressed_collision_mask
		_collision_suppressed = false


## The player kept pushing into this standing body for PUSH_SECONDS (owner, polish, A5).
signal pushed_against(other: WorldCharacterBody2D)
const PUSH_SECONDS: float = 1.0
var _push_target: WorldCharacterBody2D
## Reused by the corner slide's sideways look (_slid_velocity).
var _probe := KinematicCollision2D.new()
var _push_seconds: float = 0.0


func _physics_process(delta: float) -> void:
	_track_facing()
	if (
		not player_controlled
		or not _exists()
		or _life_status() != CharacterRuntimeLifeStatus.Value.ACTIVE
		or (_world_simulation_gate != null and _world_simulation_gate.is_frozen())
	):
		if _world_simulation_gate != null and _world_simulation_gate.is_frozen():
			_movement_input_quarantined = true
		velocity = Vector2.ZERO
		_push_target = null
		_push_seconds = 0.0
		return
	if _movement_input_quarantined:
		velocity = Vector2.ZERO
		if not _movement_input_is_pressed():
			_movement_input_quarantined = false
		return
	if held or walk_paused:
		velocity = Vector2.ZERO
		_push_target = null
		_push_seconds = 0.0
		return
	var direction: Vector2 = Input.get_vector(
		"move_left",
		"move_right",
		"move_up",
		"move_down",
	)
	direction = movement_basis.basis_xform(direction)
	_turn_to(direction)
	var wanted: Vector2 = direction * movement_speed
	var corner: float = GameContent.catalog().pacing().feel.corner_slide_px
	if corner > 0.0 and direction != Vector2.ZERO:
		# The way the walk turns along a wall is what it eases toward, so it keeps full speed.
		wanted = _slid_velocity(wanted, delta, corner)
	velocity = _eased_velocity(wanted, delta)
	move_and_slide()
	_last_position = global_position
	_track_push(direction, delta)


## Into a wall, the walk goes on along it at the same speed instead of the part of it that
## move_and_slide() keeps; nearly head-on into an edge (a rock's corner, a narrow pass's
## step), it slips toward the side within `corner` pixels where the way is clear. Only how
## the player's own walking turns: the body, its collision and the gaps it fits stay.
func _slid_velocity(wanted: Vector2, delta: float, corner: float) -> Vector2:
	var motion: Vector2 = wanted * delta
	var hit: KinematicCollision2D = move_and_collide(motion, true)
	# Another body is not an edge: pushing into someone still asks them to step aside (A5).
	if hit == null or hit.get_collider() is WorldCharacterBody2D:
		return wanted
	var normal: Vector2 = hit.get_normal()
	var tangent := Vector2(-normal.y, normal.x)
	var along: float = wanted.dot(tangent)
	var speed: float = wanted.length()
	if absf(along) >= speed * 0.35:
		return tangent * signf(along) * speed
	# Nearly head-on: the nearer side where, that much further along, the push would meet
	# the edge (and round it) or nothing, the way the push leans tried first.
	var first: float = signf(along) if along != 0.0 else 1.0
	var offset: float = 2.0
	while offset <= corner:
		for side: float in [first, -first]:
			var aside: Vector2 = tangent * side * offset
			if test_move(global_transform, aside):
				continue
			if not test_move(global_transform.translated(aside), motion, _probe) or absf(_probe.get_normal().dot(tangent)) >= 0.35:
				return tangent * side * speed
		offset += 2.0
	return wanted


## The walk's speed eases toward `wanted` (DECISIONS「手感」: move_accel_ms to full speed,
## move_stop_ms to a stop); 0 is at once. Only how it starts and stops: full speed is the same.
func _eased_velocity(wanted: Vector2, delta: float) -> Vector2:
	var feel: FeelDefinition = GameContent.catalog().pacing().feel
	var seconds: float = feel.move_accel_seconds if wanted != Vector2.ZERO else feel.move_stop_seconds
	if seconds <= 0.0:
		return wanted
	return velocity.move_toward(wanted, movement_speed / seconds * delta)


## Counts how long the player has pushed into the same standing NPC body; any frame
## without that push starts over.
func _track_push(direction: Vector2, delta: float) -> void:
	var against: WorldCharacterBody2D = null
	if direction != Vector2.ZERO:
		for index: int in get_slide_collision_count():
			var collision: KinematicCollision2D = get_slide_collision(index)
			var other: WorldCharacterBody2D = collision.get_collider() as WorldCharacterBody2D
			if other != null and not other.player_controlled and direction.normalized().dot(-collision.get_normal()) > 0.3:
				against = other
				break
	if against == null or against != _push_target:
		_push_target = against
		_push_seconds = 0.0
		return
	_push_seconds += delta
	if _push_seconds >= PUSH_SECONDS:
		_push_seconds = 0.0
		pushed_against.emit(against)


func _input_event(
	_viewport: Viewport,
	event: InputEvent,
	_shape_idx: int,
) -> void:
	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	if (
		mouse_event != null
		and mouse_event.pressed
		and mouse_event.button_index == MOUSE_BUTTON_LEFT
		and not player_controlled
		and (_world_simulation_gate == null or _world_simulation_gate.is_open())
		and _exists()
		and _life_status() != CharacterRuntimeLifeStatus.Value.DEAD
		and not _unseen
	):
		selection_requested.emit(_character_id)


func movement_input_is_pressed() -> bool:
	return _movement_input_is_pressed()


func _movement_input_is_pressed() -> bool:
	return (
		Input.is_action_pressed("move_left")
		or Input.is_action_pressed("move_right")
		or Input.is_action_pressed("move_up")
		or Input.is_action_pressed("move_down")
	)


func _exists() -> bool:
	if _player != null:
		return _player.exists_in_world
	return _npc != null and _npc.exists_in_map


func _life_status() -> int:
	if _player != null:
		return _player.life_status
	if _npc != null:
		return _npc.life_status
	return CharacterRuntimeLifeStatus.Value.DEAD


## The name over the player's body again (their 法名 after 剃度).
func refresh_label() -> void:
	if _player != null:
		_update_label(_player.facts.display_name)


func _update_label(value: String) -> void:
	var label: Label = get_node_or_null("NameLabel") as Label
	if label != null:
		label.text = value


## The name over the body in red while it is about to attack the player (a toll-taker
## waiting out its greeting: DECISIONS「响应性」), plain otherwise. The HUD's alert red.
const ALERT_NAME_COLOR: Color = Color(1.0, 0.38, 0.38)


## A red ！ over the name: the gang's first to notice the player, in its alert beat
## (DECISIONS「进门一起上」). Made the first time it shows.
func set_alert_mark(on: bool) -> void:
	var mark: Label = get_node_or_null("AlertMark") as Label
	if mark == null:
		if not on:
			return
		var name_label: Label = get_node_or_null("NameLabel") as Label
		mark = Label.new()
		mark.name = "AlertMark"
		mark.text = "！"
		mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mark.add_theme_font_size_override("font_size", 22)
		mark.add_theme_color_override("font_color", ALERT_NAME_COLOR)
		mark.add_theme_color_override("font_outline_color", Color.BLACK)
		mark.add_theme_constant_override("outline_size", 4)
		# Left of the name, on its line: a speech bubble shows above the name.
		var left: float = -58.0 if name_label == null else name_label.offset_left
		var top: float = -48.0 if name_label == null else name_label.offset_top
		mark.position = Vector2(left - 24.0, top - 5.0)
		mark.size = Vector2(22.0, 30.0)
		add_child(mark)
	mark.visible = on


## Whether its ! shows.
func alert_mark_shown() -> bool:
	var mark: Label = get_node_or_null("AlertMark") as Label
	return mark != null and mark.visible


## Turns to look at `point` (the gang turning to the player): presentation only.
func face_toward(point: Vector2) -> void:
	_turn_to(point - global_position)


func set_name_alert(on: bool) -> void:
	var label: Label = get_node_or_null("NameLabel") as Label
	if label == null or label.has_theme_color_override("font_color") == on:
		return
	if on:
		label.add_theme_color_override("font_color", ALERT_NAME_COLOR)
	else:
		label.remove_theme_color_override("font_color")
