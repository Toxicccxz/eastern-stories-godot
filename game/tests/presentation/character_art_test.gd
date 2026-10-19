extends RefCounted

## Who wears which picture (CharacterAppearances): the player by gender, an NPC by its
## definition, two of one kind by their spawn points, the same look in every generation. Then a
## Snow session: on 饮风客栈's floor every body is dressed (WorldCharacterArt), the placeholder
## and the facing notch give way to the picture, and the picture walks the way the body goes.
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const ANIMATIONS: Array[StringName] = [&"idle_down", &"walk_down", &"idle_up", &"walk_up", &"idle_right", &"walk_right"]

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_rules()
	await _test_inn(tree)
	return {"assertions": _count, "failures": _failures}


func _test_rules() -> void:
	var looks := CharacterAppearances.load_default()
	_check(looks.player_id(CharacterState.GENDER_MALE) == "player_male", "a man wears player_male")
	_check(looks.player_id(CharacterState.GENDER_FEMALE) == "player_female", "a woman wears player_female")
	_check(looks.player_id(&"") == "player_male", "an unresolved gender the default")
	var one: String = looks.npc_id(&"snow.npc.traveller", &"snow.inn.main_floor.inn.traveller.1.character")
	var two: String = looks.npc_id(&"snow.npc.traveller", &"snow.inn.main_floor.inn.traveller.2.character")
	_check(one == "traveller_a" and two == "traveller_b", "the two travellers differ by spawn point: %s, %s" % [one, two])
	_check(looks.npc_id(&"snow.npc.traveller", &"snow.inn.main_floor.inn.traveller.1.character.3") == one, "a later generation keeps its point's look")
	_check(looks.npc_id(&"snow.npc.waiter", &"snow.inn.main_floor.inn.waiter.1.character") == "waiter", "the waiter is the waiter")
	_check(looks.npc_id(&"snow.npc.no_such", &"x.1.character").is_empty(), "an NPC named nowhere keeps its placeholder")
	_check(CharacterAppearances.variant(&"plain", 2) == 0, "an id with no number wears the first look")
	for id: String in ["player_male", "player_female", "waiter", "traveller_a", "traveller_b"]:
		var frames: SpriteFrames = CharacterAppearances.frames(id)
		_check(frames != null, "%s's sheet loads" % id)
		if frames == null:
			continue
		for animation: StringName in ANIMATIONS:
			var wanted: int = 4 if String(animation).begins_with("walk") else 1
			_check(frames.has_animation(animation) and frames.get_frame_count(animation) == wanted, "%s has %s (%d frames)" % [id, animation, wanted])


func _test_inn(tree: SceneTree) -> void:
	var session: WorldSessionController = Work.create_session(tree)
	for frame: int in 8:
		await tree.process_frame
	var map: WorldMapController = session.active_map() as WorldMapController
	_check(map != null and map.map_id() == SnowWorldDefinitions.INN_MAP_ID, "the session starts in 饮风客栈")
	if map == null:
		session.queue_free()
		return
	var player: WorldCharacterBody2D = map.runtime_player_body()
	_check(_frames_of(player) == CharacterAppearances.frames("player_female"), "the player (a woman) wears player_female")
	var looks: Dictionary[String, int] = {}
	for npc: NpcRuntimeState in map.npc_runtimes():
		var body: WorldCharacterBody2D = map.runtime_body_for_character(npc.character_id)
		if body == null or not npc.exists_in_map:
			continue
		var frames: SpriteFrames = _frames_of(body)
		_check(frames != null, "%s is dressed" % npc.character_id)
		if frames != null:
			looks[frames.resource_path.get_file()] = looks.get(frames.resource_path.get_file(), 0) + 1
		_check(not (body.get_node("HumanVisual") as CanvasItem).visible, "%s's placeholder square is hidden" % npc.character_id)
		_check(not body.show_facing_notch, "%s shows its facing in the picture, not the notch" % npc.character_id)
	_check(looks == {"waiter.tres": 1, "traveller_a.tres": 1, "traveller_b.tres": 1}, "the waiter and two different travellers: %s" % looks)
	var sprite: WorldCharacterSprite = player.get_node("Sprite") as WorldCharacterSprite
	_check(sprite.animation == &"idle_down", "standing, the player faces down: %s" % sprite.animation)
	player.facing = Vector2.LEFT
	player.global_position += Vector2(-4, 0)
	sprite._process(0.016)
	_check(sprite.animation == &"walk_right" and sprite.flip_h, "walking left plays the right walk mirrored")
	player.facing = Vector2.UP
	sprite._process(0.016)
	sprite._process(WorldCharacterSprite.WALK_HOLD_SECONDS)
	_check(sprite.animation == &"idle_up" and not sprite.flip_h, "standing still facing up: idle_up")
	session.queue_free()
	await tree.process_frame


func _frames_of(body: WorldCharacterBody2D) -> SpriteFrames:
	var sprite: AnimatedSprite2D = body.get_node_or_null("Sprite") as AnimatedSprite2D if body != null else null
	return null if sprite == null else sprite.sprite_frames


func _check(condition: bool, label: String) -> void:
	_count += 1
	if not condition:
		_failures.append(label)
