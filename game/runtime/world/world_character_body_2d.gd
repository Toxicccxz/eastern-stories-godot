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
## Collision in effect before a death/absence removed it; restored when the
## character comes back to life.
var _suppressed_collision_layer: int = 0
var _suppressed_collision_mask: int = 0
var _collision_suppressed: bool = false

var character_id: StringName:
	get: return _character_id


func bind_player(value: WorldPlayerRuntimeType) -> bool:
	if value == null or not value.is_valid():
		return false
	_player = value
	_npc = null
	_character_id = value.character_id
	_update_label(value.facts.display_name)
	refresh_runtime_state()
	return true


func bind_npc(value: NpcRuntimeState) -> bool:
	if value == null or not value.is_valid():
		return false
	_npc = value
	_player = null
	_character_id = value.character_id
	_update_label(value.definition().display_name)
	refresh_runtime_state()
	return true


func bind_world_simulation_gate(value: WorldSimulationGate) -> bool:
	if value == null:
		return false
	_world_simulation_gate = value
	return true


func quarantine_current_movement_input() -> void:
	_movement_input_quarantined = true
	velocity = Vector2.ZERO


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
	visible = exists and not dead
	input_pickable = (
		not player_controlled
		and exists
		and not dead
	)
	if not exists or dead:
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
var _push_seconds: float = 0.0


func _physics_process(delta: float) -> void:
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
	var direction: Vector2 = Input.get_vector(
		"move_left",
		"move_right",
		"move_up",
		"move_down",
	)
	velocity = direction * movement_speed
	move_and_slide()
	_track_push(direction, delta)


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
	):
		selection_requested.emit(_character_id)


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
