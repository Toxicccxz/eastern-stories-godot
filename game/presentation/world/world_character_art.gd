class_name WorldCharacterArt
extends Node
## Dresses the bodies on the active map in their pictures (CharacterAppearances); a body with no
## picture keeps its placeholder shape. Presentation only: it reads who a body is, never moves it.
##
## A map's bodies are made with it and bound to whoever comes later (a spawn, a walker from
## another map), so the active map's bodies are looked over a few times a second, and at once
## when a map becomes active.

const REFRESH_SECONDS: float = 0.2

@export var map_slot: NodePath = ^"../ActiveMapSlot"

var _appearances: CharacterAppearances = CharacterAppearances.load_default()
var _slot: Node
var _since: float = 0.0


func _ready() -> void:
	_slot = get_node_or_null(map_slot)
	if _slot == null:
		set_process(false)
		return
	_slot.child_entered_tree.connect(func(_map: Variant) -> void: refresh(), CONNECT_DEFERRED)
	refresh()


func _process(delta: float) -> void:
	_since += delta
	if _since >= REFRESH_SECONDS:
		refresh()


## Dresses every bound body on the active map (or redresses one now bound to someone else).
func refresh() -> void:
	_since = 0.0
	if _slot == null or _slot.get_child_count() == 0:
		return
	var characters: Node = _slot.get_child(0).get_node_or_null("Characters")
	if characters == null:
		return
	for node: Node in characters.get_children():
		var body: WorldCharacterBody2D = node as WorldCharacterBody2D
		if body != null and not body.character_id.is_empty():
			_dress(body)


func _dress(body: WorldCharacterBody2D) -> void:
	var look: String = _look_of(body)
	var sprite: WorldCharacterSprite = body.get_node_or_null("Sprite") as WorldCharacterSprite
	if look.is_empty():
		return
	if sprite == null:
		sprite = WorldCharacterSprite.new()
		sprite.name = "Sprite"
		body.add_child(sprite)
	if sprite.look != look:
		sprite.look = look
		sprite.sprite_frames = CharacterAppearances.frames(look)
		sprite.show_pose()
	sprite.hide_placeholders()


func _look_of(body: WorldCharacterBody2D) -> String:
	var session: WorldSessionController = get_parent() as WorldSessionController
	var player: WorldPlayerRuntimeState = session.player_runtime() if session != null else null
	if player != null and body.character_id == player.character_id:
		return _appearances.player_id(player.state.gender)
	return _appearances.npc_id(body.npc_definition_id(), body.character_id)
