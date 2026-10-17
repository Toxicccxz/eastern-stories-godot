extends RefCounted

## NPCs speak to a player near them (DECISIONS「说话和交互」), with the feel on: a greeting
## waits until the player comes near and starts its wait from then (a harmful one's second
## to step aside too); a chat line far off says nothing, near it shows in a bubble; what is
## said goes into 消息, not the toasts; a room's text shows at the top, not as a toast. With
## the feel off (the suites' default) all of it is as ES2: greetings on coming into the room.

var assertions: int = 0
var failures: Array[String] = []

const WAITER_POINT: StringName = &"snow.inn.main_floor.inn.waiter.1"


func check(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures.append(message)


func run_all(tree: SceneTree) -> Dictionary:
	TestFeel.use()
	var feel: FeelDefinition = GameContent.catalog().pacing().feel
	check(feel.speech_reach == 136.0 and feel.shows_bubbles() and feel.room_text_seconds("短") == 4.0, "pacing.json: 136 px (4 body widths), bubbles, 4 s of room text")
	check(is_equal_approx(feel.room_text_seconds("长".repeat(50)), 4.4), "a long room text stays 40 ms a character longer")
	var session: WorldSessionController = load("res://scenes/world/oldpine/oldpine_world_session.tscn").instantiate()
	check(session.configure_source_entry("Speech", CharacterState.GENDER_FEMALE), "source setup")
	tree.root.add_child(session)
	for frame: int in 4:
		await tree.process_frame
	session.set_process(false) # TEST-ONLY: the test advances the NPCs itself
	var hud: SharedGameplayUI = session.shared_ui()
	var map: WorldMapController = session.active_map() as WorldMapController
	var life: WorldMapNpcLife = map.npc_life
	var waiter: NpcRuntimeState = null
	for npc: NpcRuntimeState in map.npc_runtimes():
		if npc.spawn_point_id == WAITER_POINT:
			waiter = npc
	check(waiter != null and waiter.definition().talk().has_greeting(), "the waiter, who greets")
	if waiter == null:
		return await _done(session, tree)
	var waiter_body: Node2D = map.runtime_body_for_character(waiter.character_id)
	var zone: StringName = waiter.world_location().zone_id

	# The room's text at the top, in 消息, not a toast.
	hud.toasts().clear()
	hud.describe_again()
	await tree.process_frame
	check(hud.view_overlay.room_text().begins_with(GameContent.catalog().zone(zone).display_name), "the room's title and text at the top: %s" % hud.view_overlay.room_text().left(20))
	check(hud.log_lines().back().begins_with("【"), "and in 消息")
	check(not hud.toasts().shown_texts().any(func(text: String) -> bool: return text.begins_with("【")), "not as a toast: %s" % [hud.toasts().shown_texts()])

	# Far off in the room (and the waiter on the screen or not): his greeting waits.
	var far: Vector2 = MapPlaces.spot(map, zone, waiter_body.global_position + Vector2(0, 260), 80.0)
	await _stand(tree, map, far)
	check(waiter_body.global_position.distance_to(far) > feel.speech_reach, "TEST-ONLY: standing %.0f px from him" % waiter_body.global_position.distance_to(far))
	life.arrival_zone_id = &"" # TEST-ONLY: the player comes into the room anew
	var said: int = hud.log_lines().size()
	life._advance_ambience(0.0)
	check(life.approach_greetings.has(waiter.character_id), "coming in far from him: his greeting waits")
	life._advance_ambience(3.0)
	check(not _said_by(hud, said, waiter) and hud.speech_bubbles.text_of(waiter.character_id).is_empty(), "far off, he says nothing: %s" % [hud.log_lines().slice(said)])

	# Near him: the greeting starts now, its wait counted from here.
	await _stand(tree, map, MapPlaces.spot(map, zone, waiter_body.global_position + Vector2(0, 52), 40.0))
	hud.toasts().clear()
	life._advance_ambience(0.0)
	check(not life.approach_greetings.has(waiter.character_id), "near him: it starts")
	check(not _said_by(hud, said, waiter), "not said yet: its wait runs from here")
	life._advance_ambience(1.0)
	check(_said_by(hud, said, waiter) and not hud.speech_bubbles.text_of(waiter.character_id).is_empty(), "then said, over his head: %s" % hud.speech_bubbles.text_of(waiter.character_id))
	check(not hud.toasts().shown_texts().any(func(text: String) -> bool: return text.contains(waiter.definition().display_name)), "and no toast: %s" % [hud.toasts().shown_texts()])
	said = hud.log_lines().size()
	life._advance_ambience(3.0)
	check(not _said_by(hud, said, waiter), "once for this visit to the room")

	# A harmful greeting's second to step aside starts as the player comes near too.
	var harms: bool = waiter.definition().talk().greeting_harms()
	life.arrival_zone_id = &""
	await _stand(tree, map, far)
	life._advance_ambience(0.0)
	check(life.approach_greetings.get(waiter.character_id, not harms) == harms, "it waits with its harm noted")
	life.approach_greetings[waiter.character_id] = true # TEST-ONLY: as a greeting that harms
	await _stand(tree, map, MapPlaces.spot(map, zone, waiter_body.global_position + Vector2(0, 52), 40.0))
	life._advance_ambience(0.0)
	var left: float = float(life.npc_ambience()._greetings.get(waiter.character_id, -1.0))
	check(is_equal_approx(left, NpcAmbience.GREETING_DELAY_SECONDS), "a harmful greeting: the full second from coming near: %s" % left)
	life.npc_ambience().cancel_greeting(waiter.character_id)

	# A chat line (npc.c chat()): far off it says nothing, near him a bubble and 消息, no toast.
	const CHAT: String = "店小二说道：客官里边请。"
	await _stand(tree, map, far)
	said = hud.log_lines().size()
	life._act(waiter, CHAT) # TEST-ONLY: the line his chat drew
	check(not hud.log_lines().slice(said).has(CHAT) and hud.speech_bubbles.text_of(waiter.character_id) != "客官里边请。", "far off, his chat says nothing to the player")
	await _stand(tree, map, MapPlaces.spot(map, zone, waiter_body.global_position + Vector2(0, 52), 40.0))
	hud.toasts().clear()
	life._act(waiter, CHAT)
	check(hud.log_lines().back() == CHAT and hud.speech_bubbles.text_of(waiter.character_id) == "客官里边请。", "near him: in 消息 and over his head")
	check(not hud.toasts().shown_texts().has(CHAT), "not as a toast: %s" % [hud.toasts().shown_texts()])

	# The feel off: as ES2, the greeting starts on coming into the room, wherever he stands.
	TestFeel.restore()
	await _stand(tree, map, far)
	life.arrival_zone_id = &""
	life._advance_ambience(0.0)
	check(not life.approach_greetings.has(waiter.character_id) and life.npc_ambience()._greetings.has(waiter.character_id), "the feel off: it starts on coming in")
	return await _done(session, tree)


## Something `npc` said came into 消息 since line `since` (his lines name him).
func _said_by(hud: SharedGameplayUI, since: int, npc: NpcRuntimeState) -> bool:
	return hud.log_lines().slice(since).any(func(line: String) -> bool: return line.contains(npc.definition().display_name) and not line.contains("离开"))


func _done(session: WorldSessionController, tree: SceneTree) -> Dictionary:
	TestFeel.restore()
	session.queue_free()
	await tree.process_frame
	return {"assertions": assertions, "failures": failures}


func _stand(tree: SceneTree, map: WorldMapController, at: Vector2) -> void:
	map.runtime_player_body().global_position = at
	(map.runtime_player_body().get_node("Camera2D") as Camera2D).reset_smoothing()
	await tree.physics_frame
	await tree.physics_frame
