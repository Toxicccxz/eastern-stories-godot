extends RefCounted

## DECISIONS「主线卡死点」 (owner 2026-11-10「只能击倒」), each from the player's own hand to where the
## story used to stop:
## - 陈显祖 attacked in the 福林酒楼 while the fifth chapter still hangs on him: he falls and lives
##   (keeps), comes to, and admits the deserter all the same; 朱鸿雪 never draws the 武官 meanwhile and
##   calls off a task to kill him without a penalty (WorldQuestTargets).
## - an ES2 room's own people the story takes off one day (`until` only: the 渔夫 at the lakeside) are
##   made anew by their room's reset while they are on the stage.
## - one led into the 大堂 by the 捕快 sees no 堂审 (it would end two seconds later and never play again);
##   free, they do; a 堂审 cut short is finished by asking 程不平 of the 供词.
## - 白道长's scene at the pass cut short before the strip fell: he hands it over when asked 「布条」.
## - 商玦's scene cut short before the 鬼卒 came: they stand at the altar at the next coming.
## - 郭承 on the 借兵 line falls and lives; 吕隼's scene cut short before 拿下: the fight comes once the
##   player stands there again.
const MapPlaces := preload("res://tests/support/map_places.gd")
const SouthRoad := preload("res://tests/runtime/snow_south_road_test.gd")
const Chapter6 := preload("res://tests/runtime/story_chapter6_test.gd")
const PAPERS: StringName = &"native:niling/war_ministry_papers"
const COPY: StringName = &"native:choyin/decree_copy"
const LETTER: StringName = &"native:choyin/magistrate_letter"
const STRIP: StringName = &"native:oldpine/cloth_strip"
const CROWN: StringName = &"native:niling/black_crown"
const SERGEANT: StringName = &"choyin.npc.sergeant"
const GUO: StringName = &"native.npc.guo_cheng"

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_data()
	var witness: WorldSessionController = await _session(tree, "人证")
	await _test_witness_kept(tree, witness)
	await _test_resident(tree, witness)
	await _test_custody(tree, witness)
	witness.free()
	await tree.process_frame
	var prologue: WorldSessionController = await _session(tree, "寻剑")
	await _test_strip(tree, prologue)
	prologue.free()
	await tree.process_frame
	var niling: WorldSessionController = await _session(tree, "逆灵宫")
	await _test_ghosts(tree, niling)
	niling.free()
	await tree.process_frame
	var guanbei: WorldSessionController = await _session(tree, "关北")
	await _test_raid(tree, guanbei)
	guanbei.free()
	await tree.process_frame
	return {"assertions": _count, "failures": _failures}


func _test_data() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var choice: StoryQuestDefinition.Step = catalog.story_quest(&"main.chapter5").step(&"choice")
	_check(choice != null and choice.keeps == [SERGEANT], "the fifth chapter's choice keeps 陈显祖")
	var fisher: NpcSpawnDefinition = catalog.spawn(&"village.main.lakeside.fishers")
	_check(fisher != null and fisher.resident and fisher.remade_by_reset(), "the 渔夫: a resident, remade by the reset")
	var feng: NpcSpawnDefinition = catalog.spawn(&"fanfang.shield_yard.feng_lu")
	_check(feng != null and not feng.resident and not feng.remade_by_reset() and feng.cleared_mark == "冯禄倒了", "冯禄 at the gate: staged native, never remade; 冯禄倒了")
	var ghosts: NpcSpawnDefinition = catalog.spawn(&"niling.altar.hell_runners")
	_check(ghosts != null and ghosts.summoned and ghosts.staged and ghosts.present.key == "见过唤首", "the altar's 鬼卒: summoned by the scene, on the stage after it")


## 陈显祖 struck down in the 福林酒楼 while the chapter still needs him: no death.
func _test_witness_kept(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var ui: SharedGameplayUI = session.shared_ui()
	var quests: Array[StoryQuestDefinition] = GameContent.catalog().story_quests()
	StoryFixtures.chapter4_kept(session)
	session.record_journal()
	for key: String in ["main.chapter5/drum", "main.chapter5/hear"]:
		state.quests[key] = state.quests.size() + 1
	for mark: String in ["击了鼓", "程不平要人证"]:
		state.marks[mark] = 1
	session.record_journal()
	_check(StoryQuestLog.current_step(state, GameContent.catalog().story_quest(&"main.chapter5")).step_id == &"chen", "at the 武官 step")
	_check(not WorldQuestTargets.at_hand(session, "武官"), "朱鸿雪 cannot send the player after the 武官 while the chapter keeps him")
	var hotel: WorldMapController = MapPlaces.enter(session, &"choyin.hotel1", &"choyin.hotel1.s_street2_entry")
	await _settle(tree)
	var chen: NpcRuntimeState = MapPlaces.npc_at(session, &"choyin.hotel1.sergeant.1")
	_check(hotel != null and chen != null and chen.exists_in_map, "陈显祖 in the 福林酒楼")
	if chen == null:
		return
	_full(session.player_runtime())
	chen.character_state.vitality.current = 1 # TEST-ONLY: one blow is past him
	chen.character_state.vitality.effective = 1
	_check(hotel.relocate_player(chen.world_location().zone_id, chen.spawn_point_id), "beside him")
	await _settle(tree)
	hotel.select_npc(chen.character_id)
	_check(hotel.attack_selected().outcome == CombatSliceInitiationResult.Outcome.COMPLETED, "the player attacks the 武官 (击倒后 直接了结 in the suites)")
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	var rounds: int = _fight_out(session)
	await _settle(tree)
	_check(not coordinator.has_active_encounter() and chen.life_status == CharacterRuntimeLifeStatus.Value.UNCONSCIOUS, "the fight over in %d rounds: he lies unconscious, not dead (%s)" % [rounds, CharacterRuntimeLifeStatus.Value.find_key(chen.life_status)])
	_check(ui.log_lines().any(func(line: String) -> bool: return line.contains("还有用")), "the battle says why the player stopped: %s" % [ui.log_lines().slice(-6)])
	for second: int in 240:
		if chen.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE:
			break
		session.advance_npc_heartbeat(1.0)
	await _settle(tree)
	_check(chen.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE, "he comes to")
	hotel.give_new_item_to_player(PAPERS) # TEST-ONLY: the 兵部文书 (逆灵宫's 账房)
	_check(hotel.place_player(chen.world_location().zone_id, hotel.runtime_body_for_character(chen.character_id).global_position + Vector2(0, 56)), "beside him again")
	await _settle(tree)
	var said: Array[String] = []
	if hotel.select_npc(chen.character_id):
		said = hotel.ask_selected("兵部")
	session.record_journal()
	_check(state.marks.get("陈显祖认了", 0) == 1 and state.quests.has("main.chapter5/chen") and StoryQuestLog.objective(state, quests).begins_with("寻剑令的抄本在陈显祖的桃木箱里"), "he admits the deserter all the same: %s" % [said])
	# 朱鸿雪: a task to kill the 武官 (TEST-ONLY: held from before) is called off, with no penalty.
	var tiers: Array[QuestTier] = GameContent.catalog().quest_tiers()
	var task: QuestDefinition = null
	for tier: QuestTier in tiers:
		for quest: QuestDefinition in tier.quests:
			if quest.target == "武官" and quest.type == QuestDefinition.KILL:
				task = quest
	_check(task != null, "god.c's qlist names the 武官")
	if task == null:
		return
	state.progression.combat_experience = maxi(state.progression.combat_experience, 100000)
	state.quest.assign(task, 10)
	state.quest.finished = 2
	var kee: int = state.vitality.current
	var available: Callable = func(target: String) -> bool: return WorldQuestTargets.at_hand(session, target)
	var result: QuestGiver.Result = QuestGiver.give(state, tiers, available, hotel.world_interaction_random_source().legacy_random)
	_check(result.outcome == QuestGiver.Outcome.GIVEN and ColoredLine.texts(result.lines).any(func(line: String) -> bool: return line.contains("不必办了")) and state.quest.current.target != "武官" and state.quest.finished == 2 and state.vitality.current == kee, "the 武官 task called off (不必办了), a new one drawn, no 真没用 and no kee lost: %s" % [ColoredLine.texts(result.lines)])
	for draw: int in 40:
		state.quest.clear_task()
		result = QuestGiver.give(state, tiers, available, func(n: int) -> int: return draw % maxi(n, 1))
		_check(result.quest == null or result.quest.target != "武官", "draw %d: never the 武官" % draw)


## The 渔夫 at the lakeside (`until` 拔了穿灵 only): killed, the room's reset makes him anew while the
## story has him on its stage — as ES2's reset() does.
func _test_resident(tree: SceneTree, session: WorldSessionController) -> void:
	var spawn: NpcSpawnDefinition = GameContent.catalog().spawn(&"village.main.lakeside.fishers")
	var point: StringName = spawn.spawn_point_ids()[0]
	var lake: WorldMapController = MapPlaces.enter(session, &"village.lakeside", &"village.lakeside.boat_return")
	await _settle(tree)
	var fisher: NpcRuntimeState = MapPlaces.npc_at(session, point)
	_check(lake != null and fisher != null and fisher.exists_in_map, "the 渔夫 by the lake")
	if fisher == null:
		return
	_full(session.player_runtime())
	fisher.character_state.vitality.current = 1 # TEST-ONLY
	fisher.character_state.vitality.effective = 1
	_check(lake.relocate_player(fisher.world_location().zone_id, fisher.spawn_point_id), "beside him")
	await _settle(tree)
	lake.select_npc(fisher.character_id)
	_check(lake.attack_selected().outcome == CombatSliceInitiationResult.Outcome.COMPLETED, "the player attacks the 渔夫")
	_fight_out(session)
	await _settle(tree)
	var dead: NpcRuntimeState = MapPlaces.npc_at(session, point)
	_check(dead != null and dead.life_status == CharacterRuntimeLifeStatus.Value.DEAD, "the 渔夫 dead")
	lake.npcs.reset_room(spawn.legacy_source_room_path)
	var fresh: NpcRuntimeState = MapPlaces.npc_at(session, point)
	_check(fresh != null and fresh != dead and fresh.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE and fresh.exists_in_map, "the lakeside's reset makes a new 渔夫")


## One led into the 大堂 under arrest (the 抄本 carried, 陈显祖 let go) sees no 堂审; free, they do. A
## 堂审 cut short is finished by asking 程不平.
func _test_custody(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var player: WorldPlayerRuntimeState = session.player_runtime()
	for key: String in ["main.chapter5/copy", "main.chapter5/guard", "main.chapter5/choice/release"]:
		state.quests[key] = state.quests.size() + 1
	for mark: String in ["放走了陈显祖", "侍卫说了拒令"]:
		state.marks[mark] = 1
	var yamen: WorldMapController = MapPlaces.enter(session, &"choyin.yamen_yard", &"choyin.yamen_yard.gate_arrival")
	await _settle(tree)
	var judge: NpcRuntimeState = MapPlaces.npc_at(session, &"choyin.yamen.judgeman.1")
	_check(yamen != null and judge != null, "in the 县衙内院, 程不平 in the 大堂")
	if yamen == null or judge == null:
		return
	yamen.give_new_item_to_player(COPY) # TEST-ONLY: the 抄本
	var before_judge: Vector2 = yamen.runtime_body_for_character(judge.character_id).global_position + Vector2(0, 56)
	player.awaiting_sentence = true # TEST-ONLY: brought in by the 捕快 (WorldMapPatrols._deliver)
	_check(yamen.place_player(&"choyin.yamen", before_judge), "led into the 大堂")
	await _settle(tree)
	session.advance_npc_heartbeat(0.5)
	await _settle(tree)
	_check(not session.scene_held() and not state.marks.has("堂审过"), "brought in under arrest: no 堂审 begins")
	player.awaiting_sentence = false # TEST-ONLY: the sentence passed, out at the gate
	MapPlaces.enter(session, &"choyin.court1", &"choyin.court1.yamen_return")
	await _settle(tree)
	yamen = MapPlaces.enter(session, &"choyin.yamen_yard", &"choyin.yamen_yard.gate_arrival")
	await _settle(tree)
	_check(yamen.place_player(&"choyin.yamen", before_judge), "back into the 大堂, free")
	await _settle(tree)
	session.advance_npc_heartbeat(0.5)
	await _settle(tree)
	_check(session.scene_held() and state.marks.get("堂审过", 0) == 1, "free, the 堂审 begins")
	# Cut short before the letter (TEST-ONLY: carried out of the hall at once), then asked of the 供词.
	MapPlaces.enter(session, &"choyin.court1", &"choyin.court1.yamen_return")
	await _settle(tree)
	yamen = MapPlaces.enter(session, &"choyin.yamen_yard", &"choyin.yamen_yard.gate_arrival")
	await _settle(tree)
	_check(yamen.place_player(&"choyin.yamen", before_judge), "back into the 大堂 once more")
	await _settle(tree)
	session.advance_npc_heartbeat(0.5)
	await _settle(tree)
	_check(not session.scene_held() and not state.marks.has("程不平写了信") and _carried(session, LETTER).is_empty(), "not played again: no letter")
	var said: Array[String] = []
	if yamen.select_npc(judge.character_id):
		said = yamen.ask_selected("供词")
	session.record_journal()
	_check(state.marks.get("程不平写了信", 0) == 1 and state.marks.get("只留了文书", 0) == 1 and not _carried(session, LETTER).is_empty() and state.quests.has("main.chapter5/trial"), "供词: the letter in hand, the trial step done: %s" % [said])
	said = yamen.ask_selected("供词")
	_check(_carried_count(session, LETTER) == 1 and said.any(func(line: String) -> bool: return line.contains("没有供词")), "asked again: no second letter: %s" % [said])


## 白道长's scene cut short before the strip fell: asked 「布条」, he hands it over.
func _test_strip(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var quests: Array[StoryQuestDefinition] = GameContent.catalog().story_quests()
	for key: String in ["main.prologue#started", "main.prologue/waiter", "main.prologue/square/official"]:
		state.quests[key] = state.quests.size() + 1
	var pass_map: WorldMapController = MapPlaces.enter(session, &"canyon.canyon1", &"canyon.canyon1.chain_arrival")
	await _settle(tree)
	session.advance_npc_heartbeat(0.5)
	_check(pass_map != null and session.scene_held() and state.marks.get("隘口的道士", 0) == 1, "白道长's scene begins")
	for second: int in 6:
		session.advance_npc_heartbeat(1.0)
	# TEST-ONLY: carried off the map before the 黑衣道士 comes (as a death would).
	MapPlaces.enter(session, &"snow.square", &"snow.square.inn_entry")
	await _settle(tree)
	pass_map = MapPlaces.enter(session, &"canyon.canyon1", &"canyon.canyon1.chain_arrival")
	await _settle(tree)
	session.advance_npc_heartbeat(0.5)
	await _settle(tree)
	_check(pass_map != null and not session.scene_held() and pass_map.floor_item_of(STRIP, &"canyon.canyon1").is_empty() and not state.marks.has("布条落了地"), "back at the pass_map: not played again, no strip on the ground")
	var bai: NpcRuntimeState = null
	for npc: NpcRuntimeState in pass_map.npc_runtimes():
		if npc.definition().definition_id == &"native.npc.bai_daozhang" and npc.exists_in_map:
			bai = npc
	_check(bai != null and pass_map.place_player(bai.world_location().zone_id, pass_map.runtime_body_for_character(bai.character_id).global_position + Vector2(0, 56)), "beside 白道长")
	await _settle(tree)
	var said: Array[String] = []
	if bai != null and pass_map.select_npc(bai.character_id):
		said = pass_map.ask_selected("布条")
	session.record_journal()
	_check(not _carried(session, STRIP).is_empty() and state.quests.has("main.prologue/strip") and state.quests.has("main.chapter1#started"), "布条: he hands it over; the prologue done, 伪墓 begun: %s" % [said])
	said = pass_map.ask_selected("布条")
	_check(_carried_count(session, STRIP) == 1 and said.any(func(line: String) -> bool: return line.contains("手里那块")), "asked again: no second strip: %s" % [said])
	_check(StoryQuestLog.objective(state, quests) != "拾起黑衣道士掉下的布条。", "the strip step no longer the objective")


## 商玦's scene cut short before its last beat: the two 鬼卒 stand at the altar at the next coming.
func _test_ghosts(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	StoryFixtures.chapter3_dungeon_done(session)
	session.record_journal()
	_check(session.handoff_to(&"niling.slope", &"niling.goods_path", &"niling.goods_path", &"niling.goods_path.gate_return").succeeded(), "on the goods road")
	var slope: WorldMapController = session.active_map() as WorldMapController
	await _settle(tree)
	var crown: StringName = slope.give_new_item_to_player(CROWN)
	_check(not crown.is_empty() and session.wear_player_item(crown).succeeded, "the 黑冠 on (TEST-ONLY: given)")
	var gate: WorldMapController = await MapPlaces.go_to(tree, session, &"niling.yard")
	_check(gate != null and await MapPlaces.drive(tree, gate, MapPlaces.door_spot(gate, &"niling.front.door", &"niling.yard")) and gate.open_door(&"niling.front.door") and await MapPlaces.take_passage(tree, gate, &"niling.yard.north"), "through the 山门 and the 殿门")
	var hall: WorldMapController = session.active_map() as WorldMapController
	await _settle(tree)
	_check(hall != null and await MapPlaces.drive(tree, hall, MapPlaces.door_spot(hall, &"niling.altar.door", &"niling.front")) and hall.open_door(&"niling.altar.door") and await MapPlaces.take_passage(tree, hall, &"niling.front.north"), "through the 北门 into the 后殿")
	var rear: WorldMapController = session.active_map() as WorldMapController
	await _settle(tree)
	session.advance_npc_heartbeat(0.5)
	await _settle(tree)
	_check(rear != null and session.scene_held() and state.marks.get("见过唤首", 0) == 1, "the 唤首 scene begins")
	for second: int in 10:
		session.advance_npc_heartbeat(1.0)
	_check(_count_in(session, &"niling.altar", &"native.npc.hell_runner") == 0, "no 鬼卒 yet")
	# TEST-ONLY: carried off the map before its last beat (as a death would).
	_check(session.handoff_to(&"niling.slope", &"niling.goods_path", &"niling.goods_path", &"niling.goods_path.gate_return").succeeded(), "off the map mid-scene")
	await _settle(tree)
	_check(not session.scene_held(), "the scene is over for good")
	gate = await MapPlaces.go_to(tree, session, &"niling.yard")
	_check(gate != null and await MapPlaces.take_passage(tree, gate, &"niling.yard.north"), "back through the 殿门")
	hall = session.active_map() as WorldMapController
	await _settle(tree)
	_check(hall != null and await MapPlaces.drive(tree, hall, MapPlaces.door_spot(hall, &"niling.altar.door", &"niling.front")) and await MapPlaces.take_passage(tree, hall, &"niling.front.north"), "back into the 后殿")
	await _settle(tree)
	_check(_count_in(session, &"niling.altar", &"native.npc.hell_runner") == 2, "the two 鬼卒 stand at the altar: the ghosts step can be done")


## The 借兵 line: 郭承 falls and lives; 吕隼's scene cut short before 拿下 — the fight comes all the same.
func _test_raid(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var walk: Chapter6 = Chapter6.new()
	StoryFixtures.chapter6_planned(session, true)
	session.record_journal()
	var court: WorldMapController = MapPlaces.enter(session, &"guanbei.palace_yard", &"guanbei.palace_yard.hall_return")
	_check(court != null and await MapPlaces.drive_to_zone(tree, court, &"guanbei.drill"), "out to the drill yard")
	for second: int in 3:
		session.advance_npc_heartbeat(1.0)
		await _settle(tree)
	var guo: NpcRuntimeState = MapPlaces.npc_at(session, &"guanbei.drill.guo_cheng.1")
	_check(guo != null and state.marks.get("郭承跟上了", 0) == 1 and guo.has_flag(NpcDefinition.FLAG_FOLLOWS_PLAYER), "郭承 follows")
	if guo == null:
		return
	# 郭承 struck down by the player's own hand: he lives, and still follows once he comes to.
	_full(session.player_runtime())
	guo.character_state.vitality.current = 1 # TEST-ONLY
	guo.character_state.vitality.effective = 1
	court.select_npc(guo.character_id)
	_check(court.attack_selected().outcome == CombatSliceInitiationResult.Outcome.COMPLETED, "the player attacks 郭承")
	_fight_out(session)
	await _settle(tree)
	_check(guo.life_status == CharacterRuntimeLifeStatus.Value.UNCONSCIOUS, "郭承 lies unconscious, not dead (%s)" % [CharacterRuntimeLifeStatus.Value.find_key(guo.life_status)])
	for second: int in 240:
		if guo.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE:
			break
		session.advance_npc_heartbeat(1.0)
	await _settle(tree)
	_check(guo.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE and guo.has_flag(NpcDefinition.FLAG_FOLLOWS_PLAYER), "he comes to and follows still")
	var site: WorldMapController = await walk._go_with(tree, session, &"guanbei.fence_gate")
	_check(site != null and site.map_id() == &"guanbei.worksite" and _count_in(session, &"guanbei.fence_gate", GUO) == 1, "into the 工地's gate with 郭承")
	for beat: int in 8:
		if session.scene_held():
			break
		session.advance_npc_heartbeat(0.1)
		await tree.physics_frame
	_check(session.scene_held() and state.marks.get("工地动过手", 0) == 1 and not state.marks.has("工地打起来了"), "吕隼's scene begins")
	# TEST-ONLY: carried off the map before 拿下 (as a death would), then back in with 郭承.
	var away: OldPineMapHandoffResult = session.handoff_to(&"guanbei.steppe", &"guanbei.steppe_road", &"guanbei.steppe_road", &"guanbei.steppe_road.worksite_return")
	await _settle(tree)
	_check(away.succeeded() and not session.scene_held() and not state.marks.has("工地打起来了"), "cut short before 拿下")
	await walk._wait_for_guo(tree, session, &"guanbei.steppe_road")
	site = await walk._go_with(tree, session, &"guanbei.fence_gate")
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	for second: int in 10:
		if coordinator.has_active_encounter():
			break
		session.advance_npc_heartbeat(1.0)
		await _settle(tree)
	_check(state.marks.get("工地打起来了", 0) == 1 and coordinator.has_active_encounter() and _count_in(session, &"guanbei.fence_gate", &"native.npc.site_officer_fighting") == 6, "back with 郭承: 拿下 — the fight is on")
	_fight_out(session)


func _session(tree: SceneTree, entry: String) -> WorldSessionController:
	var session: WorldSessionController = (load("res://scenes/world/oldpine/oldpine_world_session.tscn") as PackedScene).instantiate()
	session.configure_source_entry(entry, CharacterState.GENDER_MALE)
	session.deterministic_combat_seed = true
	session.deterministic_npc_seed = true
	session.deterministic_world_interaction_seed = true
	tree.root.add_child(session)
	for frame: int in 4:
		await tree.process_frame
	session.set_process(false)
	session.configure_npc_ambience_random_source(SouthRoad.Still.new()) # TEST-ONLY: nobody chats or wanders
	return session


## TEST-ONLY: the fight runs on without the player's hand until it is over.
func _fight_out(session: WorldSessionController) -> int:
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	var rounds: int = 0
	while coordinator.has_active_encounter() and rounds < 1500:
		coordinator.advance_scheduler(1.0)
		rounds += 1
	session.shared_ui().dismiss_current_panel()
	return rounds


func _full(player: WorldPlayerRuntimeState) -> void:
	player.state.vitality = CharacterResourceState.new(1000000, 1000000, 1000000) # TEST-ONLY: nobody dies here
	player.state.essence = CharacterResourceState.new(1000000, 1000000, 1000000) # TEST-ONLY
	player.state.progression.combat_experience = maxi(player.state.progression.combat_experience, 10000000) # TEST-ONLY: the blows land


func _carried(session: WorldSessionController, definition_id: StringName) -> StringName:
	var map: WorldMapController = session.active_map() as WorldMapController
	if map == null:
		return &""
	var holder := ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, session.player_runtime().character_id)
	for item_id: StringName in map.inventory_state().direct_children(holder):
		var item: ItemInstance = map.item_instance_index().resolve(item_id)
		if item != null and item.item_definition_id == definition_id:
			return item_id
	return &""


func _carried_count(session: WorldSessionController, definition_id: StringName) -> int:
	var map: WorldMapController = session.active_map() as WorldMapController
	var found: int = 0
	if map == null:
		return found
	var holder := ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, session.player_runtime().character_id)
	for item_id: StringName in map.inventory_state().direct_children(holder):
		var item: ItemInstance = map.item_instance_index().resolve(item_id)
		if item != null and item.item_definition_id == definition_id:
			found += 1
	return found


func _count_in(session: WorldSessionController, zone_id: StringName, definition_id: StringName) -> int:
	var found: int = 0
	for map: WorldMapController in session.world_maps():
		for npc: NpcRuntimeState in map.npc_runtimes():
			if npc.definition().definition_id == definition_id and npc.world_location().zone_id == zone_id and npc.exists_in_map and not npc.has_flag(NpcDefinition.FLAG_GONE):
				found += 1
	return found


func _settle(tree: SceneTree) -> void:
	for frame: int in 4:
		await tree.physics_frame
	await tree.process_frame


func _check(ok: bool, label: String) -> void:
	_count += 1
	if not ok:
		_failures.append(label)
