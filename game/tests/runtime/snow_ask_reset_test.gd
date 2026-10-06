extends RefCounted

## Snow's NPCs talk and wander (4D): ask.c/inquiryd.c answers from set("inquiry"),
## npc.c chat() lines and random_move() on the heart beat while the player is in
## the NPC's place, within its home zone and the zones next to it on its map
## (owner), the keeper's greeting one second after the player arrives.
const Work := preload("res://tests/runtime/snow_work_income_test.gd")

var _count: int = 0
var _failures: Array[String] = []
## Each room's first reset as scheduled, before any world time passes.
var _scheduled: Dictionary[String, int] = {}


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_data()
	_test_inquiry_rule()
	_test_random_move_rule()
	_test_chat_rule()
	var session: OldPineWorldSessionController = Work.create_session(tree)
	for room: String in session.room_resets().rooms():
		_scheduled[room] = session.room_resets().remaining_ms(room)
	await tree.process_frame
	await _to_square(tree, session)
	await _test_wandering(tree, session)
	await _test_greeting(tree, session)
	await _test_ask_panel(tree, session)
	await _test_reset(tree, session)
	session.free()
	await tree.process_frame
	return {"assertions": _count, "failures": _failures}


func _test_data() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var trainer: NpcTalk = catalog.npc(&"snow.npc.fist_trainer").talk()
	_check(trainer.inquiry_topics() == ["here", "name", "柳家拳法"] and not trainer.has_chat(), "李火狮: here, name, 柳家拳法")
	var teacher: NpcTalk = catalog.npc(&"snow.npc.teacher").talk()
	_check(teacher.answer("学费").size() == 5 and teacher.answer("刘安禄").size() == 3, "魏无极: ask.c says the strings, skips 0 and the function")
	_check(catalog.npc(&"snow.npc.post_officer").talk().inquiry_topics() == ["驿站"], "杜宽: 驿站 only (mail omitted)")
	_check(catalog.npc(&"snow.npc.guard").talk().inquiry_topics().is_empty(), "刘安禄: no topics until the reveal is ported")
	_check(catalog.npc(&"snow.npc.drunk").talk().chat_chance == 10 and catalog.npc(&"snow.npc.drunk").talk().chat_entries()[0] is NpcDrinkAction, "醉汉: do_drink at 10 (4E)")
	var traveller: NpcTalk = catalog.npc(&"snow.npc.traveller").talk()
	_check(traveller.chat_chance == 40 and traveller.chat_entries() == [NpcTalk.RANDOM_MOVE], "旅客: random_move at 40")
	var dog: NpcTalk = catalog.npc(&"snow.npc.dog").talk()
	_check(dog.chat_chance == 6 and dog.chat_entries().size() == 5 and dog.chat_entries()[0] == NpcTalk.RANDOM_MOVE, "野狗: random_move and four lines at 6")
	var greeting: Array[NpcLine] = catalog.npc(&"snow.npc.keeper").talk().greeting_choices()
	_check(greeting.size() == 1 and not greeting[0].emote and greeting[0].text == "这位$RESPECT，捐点香火钱积点阴德吧。", "庙祝 greets")
	_check(catalog.npc(&"oldpine.npc.fat_bandit").talk().chat_chance == 0, "矮胖子土匪: a chance without chat_msg is nothing")


## ask.c on a heroic NPC (李火狮), a peaceful one (魏无极) and an aggressive one.
func _test_inquiry_rule() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var trainer: NpcDefinition = catalog.npc(&"snow.npc.fist_trainer")
	var teacher: NpcDefinition = catalog.npc(&"snow.npc.teacher")
	var asker := NpcInquiry.Asker.new(CharacterState.GENDER_FEMALE, 14, &"")
	var none := ScriptedWorldInteractionRandomSource.new([])
	_check(NpcInquiry.topics(trainer) == ["这里", "名字", "传闻", "柳家拳法"], "listing: 这里/名字/传闻, then his own; here/name answer behind 这里/名字")
	_check(NpcInquiry.ask(trainer, &"男性", 28, true, asker, "这里", "淳风武馆大院", none) == [
		"你向李火狮问道：这位壮士，小女子初到贵宝地，不知这里有些什麽风土人情？",
		"李火狮说道：这里当然是淳风武馆，不然还是哪里？",
	], "这里 asks his `here` (inquiryd.c question first)")
	_check(NpcInquiry.ask(trainer, &"男性", 28, true, asker, "名字", "", none)[1] == "李火狮说道：在下姓李，名字就叫火狮，人称李教头的便是我。", "名字 asks his `name`")
	_check(NpcInquiry.ask(teacher, &"男性", 47, true, asker, "名字", "", none) == [
		"你向魏无极问道：敢问壮士尊姓大名？",
		"魏无极对你作了一揖：这位小姑娘可真会开玩笑，怎么会突然问起在下的名字？",
	], "a peaceful NPC's name (ask.c; the sigh emote prints nothing)")
	_check(NpcInquiry.ask(teacher, &"男性", 47, true, asker, "这里", "书院", none)[1] == "魏无极对你说道：这里是书院，至于其它的，在下不便多说。", "这里 without an answer: the room's title")
	_check(NpcInquiry.ask(teacher, &"男性", 47, true, asker, "学费", "", none).size() == 6, "学费: the question and five lines")
	_check(NpcInquiry.ask(teacher, &"男性", 47, true, asker, "传闻", "", ScriptedWorldInteractionRandomSource.new([1])) == [
		"你向魏无极问道：这位壮士，不知最近有没有听说什麽消息？",
		"魏无极睁大眼睛望著你，显然不知道你在说什麽。",
	], "传闻 nobody answers: msg_dunno[random(5)]")
	_check(NpcInquiry.ask(teacher, &"男性", 47, false, asker, "学费", "", none) == [
		"你向魏无极打听有关『学费』的消息。",
		"但是很显然的，魏无极现在的状况没有办法给你任何答覆。",
	], "an unconscious NPC cannot answer")
	_check(NpcInquiry.ask(trainer, &"男性", 28, true, asker, "传闻", "", ScriptedWorldInteractionRandomSource.new([0]))[1] == "李火狮摇摇头，说道：没听说过。", "a heroic NPC's dunno")
	var bully: NpcDefinition = NpcDefinition.new(&"t.bully", "t.c", "恶霸", [&"bully"], &"human", true, &"男性", true, 30, null, null, 0, 0, NpcDefinition.Attitude.AGGRESSIVE)
	_check(NpcInquiry.ask(bully, &"男性", 30, true, asker, "名字", "", none)[1] == "恶霸对你把眼一瞪：大爷我的名字是可以随便提的吗？！我看你这小贱人是活腻了！", "an aggressive NPC's name: rankd.c rude words")
	var hero: NpcDefinition = NpcDefinition.new(&"t.hero", "t.c", "侠客", [&"hero"], &"human", true, &"男性", true, 60, null, null, 0, 0, NpcDefinition.Attitude.HEROISM)
	_check(NpcInquiry.ask(hero, &"男性", 60, true, asker, "名字", "", none)[1] == "侠客对你哈哈一笑：侠客便是老子！", "a heroic NPC without a `name` answer")
	_check(none.call_count() == 0, "only msg_dunno draws")


## npc.c random_move() -> go.c, kept to the home zone and its neighbours on its map.
func _test_random_move_rule() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var no_door: Callable = func(_from: StringName, _to: StringName) -> bool: return false
	var move: NpcRandomMove.Move = NpcRandomMove.choose(catalog, &"snow.mstreet2", &"snow.mstreet2", ScriptedWorldInteractionRandomSource.new([0]), no_door)
	_check(move != null and move.direction == "north" and move.to_zone_id == &"snow.mstreet3" and move.leave_line("收破烂的") == "收破烂的往北离开。", "mstreet2 north: mstreet3")
	var from_away: NpcRandomMove.Move = NpcRandomMove.choose(catalog, &"snow.mstreet3", &"snow.mstreet2", ScriptedWorldInteractionRandomSource.new([0]), no_door)
	_check(from_away != null and from_away.to_zone_id == &"snow.mstreet2", "back home from a neighbour")
	var directions: Array[String] = []
	directions.assign(catalog.room(&"es2:d/snow/mstreet3").exits().keys())
	var beyond: int = directions.find("north")
	_check(beyond >= 0 and NpcRandomMove.choose(catalog, &"snow.mstreet3", &"snow.mstreet2", ScriptedWorldInteractionRandomSource.new([beyond]), no_door) == null, "not past the zones next to home")
	for index: int in 3:
		_check(NpcRandomMove.choose(catalog, &"snow.inn.main_floor", &"snow.inn.main_floor", ScriptedWorldInteractionRandomSource.new([index]), no_door) == null, "the Inn's exits all leave its map (owner: same map)")
	_check(NpcRandomMove.choose(catalog, &"snow.sroad4", &"snow.sroad4", ScriptedWorldInteractionRandomSource.new([2]), no_door) == null, "sroad4 southwest leads to an unmigrated room")
	var closed: Callable = func(_from: StringName, _to: StringName) -> bool: return true
	_check(NpcRandomMove.choose(catalog, &"snow.mstreet2", &"snow.mstreet2", ScriptedWorldInteractionRandomSource.new([0]), closed) == null, "a closed door: room.c valid_leave()")


## npc.c chat(): random(100) < chat_chance, then random(sizeof(msg)).
func _test_chat_rule() -> void:
	var talk: NpcTalk = GameContent.catalog().npc(&"snow.npc.dog").talk()
	var ambience := NpcAmbience.new(ScriptedWorldInteractionRandomSource.new([5, 2, 6]))
	_check(ambience.due_beats(1.5) == 0 and ambience.due_beats(0.5) == 1 and ambience.due_beats(4.0) == 2, "one beat per 2 s of world time")
	_check(ambience.chat(talk) == "野狗在你的脚边挨挨擦擦的，想讨东西吃。\n", "5 < 6: the second line")
	_check(ambience.chat(talk) == null, "6 is not below 6")
	ambience.start_greeting(&"a")
	_check(ambience.due_greetings(0.6).is_empty() and ambience.due_greetings(0.4) == [&"a"] and ambience.due_greetings(5.0).is_empty(), "call_out(\"greeting\", 1)")
	# MudOS: the next reset TIME_TO_RESET/2 + random(TIME_TO_RESET/2) seconds on.
	var resets := WorldRoomResets.new(["d/snow/a.c"], 1800, ScriptedWorldInteractionRandomSource.new([100, 0]))
	_check(resets.remaining_ms("d/snow/a.c") == 1_000_000, "900 + random(900) seconds")
	_check(resets.advance(999.9).is_empty() and resets.advance(0.2) == ["d/snow/a.c"] and resets.remaining_ms("d/snow/a.c") == 900_000, "due once, then scheduled again")
	var rooms: Array[String] = WorldRoomResets.resetting_rooms()
	_check(rooms.has("d/snow/school2.c") and rooms.has("d/snow/weapon_storage.c") and rooms.has("d/snow/secret_storage.c") and rooms.has("d/oldpine/lake.c") and rooms.has("d/snow/square.c"), "rooms whose reset() does something: spawns (the square's 飞刀 travellers too), items, the shelf")
	_check(GameContent.catalog().pacing().room_reset_seconds == 1800, "pacing.json: config.ES2 time to reset")
	_check(NpcGeneration.of(&"p.character", &"p") == 1 and NpcGeneration.of(&"p.character.3", &"p") == 3 and NpcGeneration.next(&"p.character", &"p") == &"p.character.2", "generations")
	_check(NpcGeneration.of(&"p.character.1", &"p") == 0 and NpcGeneration.of(&"p.character.03", &"p") == 0 and NpcGeneration.of(&"q.character", &"p") == 0, "nothing else is a generation")


func _to_square(tree: SceneTree, session: OldPineWorldSessionController) -> void:
	var walker: RefCounted = Work.new()
	await walker.walk(tree, session, "move_right", 125)
	await walker.walk_to(tree, session, "move_right", 0, 0)
	_check(session.player_runtime().world_location().zone_id == &"snow.square", "out of the Inn")


## The scavenger beside the player: a line, then random_move north and the walk.
func _test_wandering(tree: SceneTree, session: OldPineWorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var hud: SharedGameplayUI = session.shared_ui()
	var street: Vector2 = map.physical_zone(&"snow.mstreet2").global_rect().get_center()
	_check(MapPlacementValidator.is_valid_character_position(map, &"snow.mstreet2", street) and _place(map, session.player_runtime(), &"snow.mstreet2", street), "in the street beside the scavenger")
	var scavenger: NpcRuntimeState = _npc(map, &"snow.mstreet2.scavenger.1")
	var body: WorldCharacterBody2D = map.runtime_body_for_character(scavenger.character_id)
	var home: Vector2 = body.global_position
	# A beat says nothing (20 is not below 20), the next one the first line. The drunk
	# beside it draws first on each beat (spawn order); 99 keeps him quiet.
	session.configure_npc_ambience_random_source(ScriptedWorldInteractionRandomSource.new([99, 20, 99, 0, 0]))
	map.advance_npc_heartbeat(4.0)
	_check(hud.log_lines().back() == "收破烂的吆喝道：收～破～烂～哪～", "chat(): the line as written")
	# random_move: entry 3, exit 0 (north), then where in mstreet3 the walk ends.
	session.configure_npc_ambience_random_source(ScriptedWorldInteractionRandomSource.new([99, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0]))
	map.advance_npc_heartbeat(2.0)
	_check(scavenger.world_location().zone_id == &"snow.mstreet3" and hud.log_lines().back() == "收破烂的往北离开。", "random_move north: go.c's line; the place changes at once")
	_check(map.npc_walker().is_walking(scavenger.character_id), "the body walks there")
	await tree.process_frame
	var shape: CollisionShape2D = body.get_node("CollisionShape2D")
	var presence: CollisionShape2D = body.get_node("AggressionPresence/CollisionShape2D")
	_check(shape.disabled and presence.disabled, "a walking NPC goes through the player and notices nobody on the way")
	var rest: Vector2 = map.npc_rest_position(scavenger.character_id)
	_check(map.physical_zone(&"snow.mstreet3").contains_center(rest) and MapPlacementValidator.is_valid_character_position(map, &"snow.mstreet3", rest), "it ends on a free spot in mstreet3")
	var snapshot: GameSaveSnapshot = Work.capture(session)
	var saved: GameSaveValueTypes.NpcSpawnStateSnapshot = null
	for npc: GameSaveValueTypes.NpcSpawnStateSnapshot in [] if snapshot == null else snapshot.npc_spawn_states:
		if npc.character_id == scavenger.character_id:
			saved = npc
	_check(saved != null and saved.world_location.zone_id == &"snow.mstreet3" and Vector2(saved.map_position.x, saved.map_position.y) == rest, "a save mid-walk keeps where the walk ends")
	# The player is no longer in its place: its beats stop (char.c); the drunk's go on.
	var quiet := ScriptedWorldInteractionRandomSource.new([99, 99, 99, 0, 3, 0, 0])
	session.configure_npc_ambience_random_source(quiet)
	for step: int in 60:
		map.advance_npc_heartbeat(0.1)
	_check(quiet.call_count() == 3, "no beat for an NPC the player is not with (three for the drunk)")
	map.select_npc(scavenger.character_id)
	_check(map.attack_selected().outcome != CombatSliceInitiationResult.Outcome.COMPLETED and session.shared_ui().log_lines().back() == "这里没有这个人。", "kill.c present(): the scavenger walked away")
	_check(not map.npc_walker().is_walking(scavenger.character_id) and body.global_position == rest and body.global_position != home, "the walk takes world time and ends there")
	await tree.process_frame
	_check(not shape.disabled and not presence.disabled, "it stands solid again and notices who is there")


## keeper.c init()/greeting(): one second after the player comes in, if still there.
func _test_greeting(tree: SceneTree, session: OldPineWorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var hud: SharedGameplayUI = session.shared_ui()
	_check(map.relocate_player(&"snow.temple", &"snow.temple.keeper.1"), "into the temple")
	map.advance_npc_heartbeat(0.5)
	_check(not hud.log_lines().back().begins_with("庙祝说道"), "not yet")
	map.advance_npc_heartbeat(0.6)
	_check(hud.log_lines().back() == "庙祝说道：这位小姑娘，捐点香火钱积点阴德吧。", "the greeting, rankd.c respect for the player")
	_check(map.relocate_player(&"snow.mstreet2", &"snow.mstreet2.drunk.1"), "out")
	map.advance_npc_heartbeat(0.1)
	_check(map.relocate_player(&"snow.temple", &"snow.temple.keeper.1"), "back in")
	map.advance_npc_heartbeat(0.5)
	_check(map.relocate_player(&"snow.mstreet2", &"snow.mstreet2.drunk.1"), "and out within the second")
	var before: int = hud.log_lines().size()
	map.advance_npc_heartbeat(1.0)
	_check(hud.log_lines().size() == before, "greeting(): nobody to greet, nothing said")
	await tree.process_frame


## 打听 on the selected NPC: the topic list, then the answer under it and in the log.
func _test_ask_panel(tree: SceneTree, session: OldPineWorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var hud: SharedGameplayUI = session.shared_ui()
	_check(map.relocate_player(&"snow.eroad2", &"snow.eroad2.dog.1"), "beside the dogs")
	map.select_npc(_npc(map, &"snow.eroad2.dog.2").character_id)
	await tree.process_frame
	hud.refresh_live_state()
	_check(not hud.ask_is_enabled(), "a beast is not asked")
	var trainer: NpcRuntimeState = _npc(map, &"snow.school2.fist_trainer.1")
	map.select_npc(trainer.character_id)
	hud.refresh_live_state()
	_check(not hud.ask_is_enabled() and map.ask_selected("这里").is_empty(), "present(): only someone here")
	_check(map.relocate_player(&"snow.school2", &"snow.school2.fist_trainer.1"), "into the practice yard")
	map.select_npc(trainer.character_id)
	hud.refresh_live_state()
	_check(hud.ask_is_enabled(), "打听 李火狮")
	hud.open_ask()
	await tree.process_frame
	_check(hud.ask_topics_shown() == ["这里", "名字", "传闻", "柳家拳法"], "the topics")
	hud._ask_topic("柳家拳法")
	_check(hud.ask_answer_text() == "你向李火狮打听有关『柳家拳法』的消息。\n李火狮说道：哦....说来惭愧，小弟这套拳法还没学得到家, 柳馆主就教我在这里传艺。", "the answer under the list")
	_check(hud.log_lines().back() == "李火狮说道：哦....说来惭愧，小弟这套拳法还没学得到家, 柳馆主就教我在这里传艺。", "and in the log")
	hud.dismiss_current_panel()
	await tree.process_frame


## std/room.c reset(): the wandered scavenger hurries home, a killed trainee is
## made anew beside its corpse, the 竹剑 lies there again only once it is gone,
## the shelf forgets its pushes. Save/Continue keeps all of it.
func _test_reset(tree: SceneTree, session: OldPineWorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var hud: SharedGameplayUI = session.shared_ui()
	var player: WorldPlayerRuntimeState = session.player_runtime()
	session.set_process(false)
	var resets: WorldRoomResets = session.room_resets()
	for room: String in resets.rooms():
		var scheduled: int = _scheduled.get(room, -1)
		_check(scheduled >= 900_000 and scheduled < 1_800_000 and resets.remaining_ms(room) <= scheduled, "%s resets in 15 to 30 minutes (scheduled %d ms)" % [room, scheduled])
	# return_home(): the scavenger left mstreet2 in _test_wandering.
	var scavenger: NpcRuntimeState = _npc(map, &"snow.mstreet2.scavenger.1")
	_check(scavenger.world_location().zone_id == &"snow.mstreet3", "the scavenger is still next door")
	_check(_place(map, player, &"snow.mstreet3", map.npc_rest_position(scavenger.character_id)), "the player follows")
	session.reset_room("d/snow/mstreet2.c")
	_check(scavenger.world_location().zone_id == &"snow.mstreet2" and hud.log_lines().back() == "收破烂的急急忙忙地离开了。", "return_home(): 收破烂的急急忙忙地离开了。")
	for step: int in 60:
		map.advance_npc_heartbeat(0.1)
	var marker: WorldSpawnMarker2D = map.resolve_spawn_marker(&"snow.mstreet2.scavenger.1")
	_check(map.runtime_body_for_character(scavenger.character_id).global_position == marker.global_position, "it walks back to where it stood")
	# block_msg/all: the scavenger still beats beside an unconscious player, unread.
	_check(_place(map, player, &"snow.mstreet2", map.physical_zone(&"snow.mstreet2").global_rect().get_center()), "back beside the scavenger")
	player.set_life_status(CharacterRuntimeLifeStatus.Value.UNCONSCIOUS)
	var unread := ScriptedWorldInteractionRandomSource.new([99, 0, 0])
	session.configure_npc_ambience_random_source(unread)
	var read: int = hud.log_lines().size()
	map.advance_npc_heartbeat(2.0)
	_check(unread.call_count() == 3 and hud.log_lines().size() == read, "an unconscious player reads no chat")
	player.set_life_status(CharacterRuntimeLifeStatus.Value.ACTIVE)
	# A keeper made anew where the player stands greets them (make_inventory()'s init()).
	_check(map.relocate_player(&"snow.temple", &"snow.temple.keeper.1"), "into the temple")
	map.advance_npc_heartbeat(1.5)
	var keeper: NpcRuntimeState = _npc(map, &"snow.temple.keeper.1")
	keeper.set_life_status(CharacterRuntimeLifeStatus.Value.DEAD)
	keeper.set_exists_in_map(false)
	map.runtime_body_for_character(keeper.character_id).refresh_runtime_state()
	session.reset_room("d/snow/temple.c")
	map.advance_npc_heartbeat(1.1)
	_check(_npc(map, &"snow.temple.keeper.1") != keeper and hud.log_lines().back() == "庙祝说道：这位小姑娘，捐点香火钱积点阴德吧。", "a new keeper greets the player already there")
	# A traveller dies in the Inn while the player is outdoors: its map is not loaded.
	var inn: WorldMapController = session.world_map_of(&"snow.inn")
	var traveller: NpcRuntimeState = _npc(inn, &"snow.inn.main_floor.inn.traveller.1")
	_check(inn != null and not inn.is_inside_tree() and traveller != null, "the Inn is another map")
	traveller.set_life_status(CharacterRuntimeLifeStatus.Value.DEAD)
	traveller.set_exists_in_map(false)
	session.reset_room("d/snow/inn.c")
	var replacement: NpcRuntimeState = _npc(inn, &"snow.inn.main_floor.inn.traveller.1")
	var marker_inn: WorldSpawnMarker2D = inn.resolve_spawn_marker(&"snow.inn.main_floor.inn.traveller.1")
	_check(replacement != traveller and replacement.exists_in_map and inn.runtime_body_for_character(replacement.character_id).global_position == marker_inn.global_position, "a reset on a map the player is not on")
	# A trainee killed in the practice yard.
	_check(map.relocate_player(&"snow.school2", &"snow.school2.trainee.1"), "into the practice yard")
	var trainee: NpcRuntimeState = _npc(map, &"snow.school2.trainee.1")
	# Test-only: a new character cannot beat a trainee (0/30); this one can.
	trainee.character_state.vitality.apply_wound(trainee.character_state.vitality.effective - 1)
	player.state.progression.combat_experience = 100000
	map.select_npc(trainee.character_id)
	_check(map.attack_selected().outcome == CombatSliceInitiationResult.Outcome.COMPLETED, "attack the trainee")
	for second: int in 120:
		session.combat_encounter_coordinator().advance_scheduler(1.0)
		if not session.combat_encounter_coordinator().has_active_encounter():
			break
	_check(trainee.life_status == CharacterRuntimeLifeStatus.Value.DEAD and not trainee.exists_in_map and map.corpse_states().size() == 1, "the trainee died; its corpse lies there")
	var others: int = map.npc_runtimes().size()
	var place_in_order: int = map.npc_runtimes().find(trainee)
	var npc_draws: int = session.npc_random_source().capture_random_state().state
	session.reset_room("d/snow/school2.c")
	var fresh: NpcRuntimeState = _npc(map, &"snow.school2.trainee.1")
	_check(fresh != trainee and fresh.character_id == &"snow.school2.trainee.1.character.2" and fresh.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE and fresh.exists_in_map, "make_inventory(): a second trainee where the first died")
	_check(map.npc_runtimes().size() == others and map.npc_runtimes().find(fresh) == place_in_order and map.corpse_states().size() == 1 and map.corpse_states()[0].victim_character_id == trainee.character_id, "same count and order; the old corpse stays")
	_check(session.npc_random_source().capture_random_state().state != npc_draws, "its create() draws from the NPC stream")
	var fresh_body: WorldCharacterBody2D = map.runtime_body_for_character(fresh.character_id)
	_check(fresh_body != null and fresh_body.visible and fresh_body.global_position == map.resolve_spawn_marker(&"snow.school2.trainee.1").global_position, "on its marker")
	var loadout: Array[ItemInstance] = fresh.loadout_items()
	_check(not loadout.is_empty() and String(loadout[0].item_instance_id).contains(".character.2.loadout."), "its own loadout IDs")
	# The 竹剑: carried, it is not replaced; gone, it is.
	_check(map.relocate_player(&"snow.weapon_storage", &"snow.weapon_storage.bamboo_sword.1"), "into the weapon storage")
	var sword: StringName = ItemSpawnDefinition.item_instance_id(session.item_id_allocator().scope, &"snow.weapon_storage.bamboo_sword.1")
	_check(map.select_floor_item(sword) and map.take_selected_floor_item() == FloorItemPickup.Outcome.TAKEN, "picked up")
	session.reset_room("d/snow/weapon_storage.c")
	_check(not map.floor_item_ids().has(sword), "the one the player carries is not replaced")
	var passage: HiddenPassageState = session.hidden_passages().state(&"snow.weapon_storage.landmark.shelf")
	var shelf: WorldLandmarkDefinition = GameContent.catalog().landmark(&"snow.weapon_storage.landmark.shelf")
	session.hidden_passages().push(shelf)
	session.hidden_passages().push(shelf)
	var removal: ItemLifecycleResult = ItemLifecycleService.destroy_item(session.inventory_state(), session.stack_collection(), sword, ItemLifecycleResult.ChildDisposition.REQUIRE_LEAF, ItemLifecycleOwnerContext.new(player.character_id, player.state.equipment, player.armor))
	_check(removal != null and removal.succeeded and not session.inventory_state().is_registered(sword), "the 竹剑 is gone (as when sold)")
	session.item_instance_index().forget_destroyed_snapshots(removal.removed_instance_ids, session.inventory_state())
	session.reset_room("d/snow/weapon_storage.c")
	_check(map.floor_item_ids().has(sword) and session.inventory_state().direct_parent(sword).kind == ContainmentEndpoint.Kind.WORLD, "make_inventory(): the 竹剑 lies there again")
	session.hidden_passages().push(shelf)
	_check(not map.is_portal_open(&"snow.weapon_storage.down"), "weapon_storage.c reset(): two pushes forgotten, one more does not open it")
	var snapshot: GameSaveSnapshot = Work.capture(session)
	var walker: RefCounted = Work.new()
	await walker.round_trip(tree, session, snapshot, "after resets (failures)")
	_check(walker._failures.is_empty(), "Save/Continue keeps the second trainee, the old corpse and the sword: " + str(walker._failures))
	session.set_process(true)


func _place(map: WorldMapController, player: WorldPlayerRuntimeState, zone_id: StringName, at: Vector2) -> bool:
	map.runtime_player_body().global_position = at
	return player.set_world_location(map.location_for_zone(zone_id))


func _npc(map: WorldMapController, point: StringName) -> NpcRuntimeState:
	for npc: NpcRuntimeState in map.npc_runtimes():
		if npc.spawn_point_id == point:
			return npc
	return null


func _check(ok: bool, label: String) -> void:
	_count += 1
	if not ok: _failures.append("4D: " + label)
