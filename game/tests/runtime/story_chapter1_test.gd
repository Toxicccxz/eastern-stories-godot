extends RefCounted

## 主线 A (owner, 2026-10-29; DECISIONS「老松寨的三条路」「安葬必得书」「剧情演出」): 伪墓 end to
## end from 寻剑令's end (StoryFixtures) — the trail's mark, the keep's gate taken by paying
## (the toll, the trap that does not fall, 常老大 who talks), the 黑衣道士 waiting in cave5
## once 常老大 was asked, the fight and 放过, the wall's clues, the burial with the 腰牌 and
## the book that always falls, the quest's end; and the other ways at the gate as the
## definitions answer them.

const Finance := preload("res://tests/runtime/snow_finance_test.gd")
const CAVES: StringName = &"oldpine.caves"
const MOUTH: StringName = &"oldpine.caves.mouth"
const WALL: StringName = &"oldpine.caves.landmark.wall"
const SKELETON: StringName = &"es2:d/oldpine/npc/skeleton"
const PARRYBOOK: StringName = &"es2:d/oldpine/npc/obj/parrybook"
const TOKEN: StringName = &"native:waterfog/guild_token"
const BOX: StringName = &"native:oldpine/stone_box"

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	# 放过 is a choice only under 询问 (the suites run 直接了结: DECISIONS「了结 / 放过」).
	var knockout_before: int = BattlePace.after_knockout
	BattlePace.after_knockout = BattlePace.AfterKnockout.ASK
	var session: WorldSessionController = await _session(tree)
	await _test_chapter(tree, session)
	session.free()
	await tree.process_frame
	BattlePace.after_knockout = knockout_before
	return {"assertions": _count, "failures": _failures.duplicate()}


func _test_chapter(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var ui: SharedGameplayUI = session.shared_ui()
	var quests: Array[StoryQuestDefinition] = GameContent.catalog().story_quests()
	var quest: StoryQuestDefinition = GameContent.catalog().story_quest(&"main.chapter1")
	StoryFixtures.prologue_done(session)
	session.record_journal()
	_check(StoryQuestLog.is_active(state, quest) and StoryQuestLog.objective(state, quests) == "顺着布条上的记号去老松岭，沿松树上的刀痕找老松寨。", "伪墓 begins from 寻剑令's end: %s" % [state.quests])
	# The trail: the knife marks' mark does the first step.
	var outdoor: WorldMapController = MapPlaces.enter(session, &"oldpine.outdoor.central_clearing", &"oldpine.outdoor.central_clearing.player_start")
	_check(outdoor != null and outdoor.map_id() == &"oldpine.outdoor", "in 老松林")
	await _settle(tree)
	_check(outdoor.place_player(&"oldpine.outdoor.pine_entrance", Vector2(2500, 480)), "by the thicket")
	await _settle(tree)
	_check(outdoor.select_landmark(&"oldpine.outdoor.landmark.pine_knife_marks"), "the knife marks")
	var found: FindWayLandmarkPolicy.Result = outdoor.traverse_selected_portal() as FindWayLandmarkPolicy.Result
	_check(found != null and found.found and state.marks.get("老松寨的小径", 0) == 1, "the path found")
	session.record_journal()
	_check(state.quests.has("main.chapter1/trail") and StoryQuestLog.objective(state, quests) == "过老松寨的寨门：留下买路钱、叫阵，或者打进去。", "the trail recorded; the gate is next: %s" % [state.quests])
	# The gate: the guards take a toll (parley on), the leaders and 常老大 hold for either mark.
	var guard: NpcDefinition = GameContent.catalog().npc(&"oldpine.npc.bandit_guard")
	var leader: NpcDefinition = GameContent.catalog().npc(&"oldpine.npc.bandit_leader")
	var commander: NpcDefinition = GameContent.catalog().npc(&"oldpine.npc.bandit_commander")
	var parley: bool = GameContent.catalog().pacing().story_parley
	_check(parley and guard.attacks_on_sight({}, state, parley) and guard.toll_attack_delay_ms({}, state, parley) == 8000 and commander.attacks_on_sight({}, state, parley), "no mark: the keep attacks, the gate after its shout")
	_check(not Berserk.applies_to(guard) and not Berserk.applies_to(leader) and not Berserk.applies_to(commander), "none of them goes berserk on its own")
	state.marks["叫阵老松寨"] = 1 # TEST-ONLY: the challenger's way, as the definitions answer it
	_check(not guard.attacks_on_sight({}, state, parley) and not leader.attacks_on_sight({}, state, parley) and commander.attacks_on_sight({}, state, parley), "叫阵: the guards and leaders stand aside, 常老大 fights")
	_check(guard.attacks_on_sight({}, state, false) and commander.toll_attack_delay_ms({}, state, false) == 0, "经典 (the parley off): all of them attack as ES2's did")
	state.marks.erase("叫阵老松寨")
	_check(outdoor.place_player(&"oldpine.outdoor.keep_gate", Vector2(2660, 480)), "at the gate")
	await _settle(tree)
	var gatekeeper: NpcRuntimeState = outdoor.npcs.first_npc_in_zone(&"oldpine.npc.bandit_guard", &"oldpine.outdoor.keep_gate", true)
	_check(gatekeeper != null and outdoor.place_player(&"oldpine.outdoor.keep_gate", outdoor.runtime_body_for_character(gatekeeper.character_id).global_position + Vector2(0, 60)), "beside a guard")
	await _settle(tree)
	_check(outdoor.select_npc(gatekeeper.character_id) and outdoor.ask_topics_selected().has("叫阵") and outdoor.ask_topics_selected().has("买路钱"), "the guard can be asked: %s" % [outdoor.ask_topics_selected()])
	var money: MoneyInventoryContext = Finance.session_context(session)
	Finance.add_money(money, CurrencyDenomination.Value.SILVER, 10, &"test.story.silver") # TEST-ONLY
	var silver: StringName = _carried(session, &"es2:obj/money/silver")
	var said: int = ui.log_lines().size()
	var paid: ItemHandlingResult = outdoor.give_to_selected(silver, 10)
	_check(paid.done() and state.marks.get("老松寨的过路钱", 0) == 1, "ten taels of silver: the toll's mark")
	_check(ui.log_lines().slice(said).has("土匪喽罗掂了掂银子，咧嘴一笑：算你识相。进去吧，寨里的弟兄不会难为你。"), "said as written: %s" % [ui.log_lines().slice(said)])
	_check(not guard.attacks_on_sight(gatekeeper.flags(), state, parley) and not commander.attacks_on_sight({}, state, parley), "paid: nobody in the keep attacks")
	session.record_journal()
	_check(state.quests.has("main.chapter1/gate/pay") and state.deeds[-1].did == "给老松寨的喽罗付了买路钱" and StoryQuestLog.objective(state, quests) == "到聚义厅找常老大，问黑衣道士的去向。", "the gate recorded with its deed: %s" % [state.quests])
	# The yard's trap does not fall on one who paid.
	_check(outdoor.place_player(&"oldpine.outdoor.keep_yard", Vector2(3176, 480)), "in the yard")
	await _settle(tree)
	session.player_leaving_zone(&"oldpine.outdoor.keep_yard", &"oldpine.outdoor.keep_hall")
	_check(not session.room_traps().is_shut(&"oldpine.keep2.gate_trap") and outdoor.door(&"oldpine.keep.gate").is_open(), "the gate stays open behind one who paid")
	# 常老大 talks to one who paid.
	var hall: WorldMapController = MapPlaces.enter(session, &"oldpine.outdoor.keep_hall", &"oldpine.outdoor.keep_hall.keep_yard_entry")
	_check(hall != null and hall.map_id() == &"oldpine.keep_hall", "in the hall")
	await _settle(tree)
	var boss: NpcRuntimeState = hall.npcs.first_npc_in_zone(&"oldpine.npc.bandit_commander", &"oldpine.outdoor.keep_hall", true)
	_check(boss != null and hall.place_player(&"oldpine.outdoor.keep_hall", hall.runtime_body_for_character(boss.character_id).global_position + Vector2(0, 60)), "beside 常老大")
	await _settle(tree)
	_check(not session.combat_encounter_coordinator().has_active_encounter(), "no fight: the toll was paid")
	_check(hall.select_npc(boss.character_id), "常老大 in reach")
	var answer: Array[String] = hall.ask_selected("黑衣道士")
	_check(answer.size() >= 3 and answer[1].contains("拿一块金牌子买的路"), "he tells of the taoist: %s" % [answer])
	_check(state.quests.has("main.chapter1/boss/talk") and StoryQuestLog.objective(state, quests) == "从瀑布后面进山洞，找黑衣道士。", "recorded at the ask; the cave is next")
	# The cave: the taoist waits there now (the stage), beside the bones, the token and the box.
	var caves: WorldMapController = MapPlaces.enter(session, &"oldpine.caves.maze", &"oldpine.caves.maze.cave1_landing")
	_check(caves != null and caves.map_id() == CAVES, "into the caves")
	await _settle(tree)
	var taoist: NpcRuntimeState = caves.npcs.first_npc_in_zone(&"native.npc.black_taoist", MOUTH, true)
	_check(taoist != null and taoist.exists_in_map, "the 黑衣道士 is in cave5 now that 常老大 was asked")
	_check(not caves.floor_item_of(TOKEN, MOUTH).is_empty() and not caves.floor_item_of(BOX, MOUTH).is_empty() and not caves.floor_item_of(SKELETON, MOUTH).is_empty(), "the bones, the 腰牌 and the 石匣 lie there")
	_check(caves.place_player(MOUTH, Vector2(820, 420)), "into cave5")
	await _settle(tree)
	session.record_journal()
	_check(state.quests.has("main.chapter1/cave") and StoryQuestLog.objective(state, quests) == "拦住黑衣道士。", "the cave reached; the taoist is next")
	# The fight: he falls and is spared (放过); 历练 for one of note, his mark.
	state.skills.set_raw_level(&"unarmed", 60) # TEST-ONLY: strong enough to fell him, not to kill him outright
	for resource: CharacterResourceState in [state.vitality, state.essence, state.spirit]:
		resource.maximum = 3000 # TEST-ONLY: a fresh character outlasts his blows while the suite drives the rounds
		resource.effective = 3000
		resource.current = 3000
	for skill: StringName in [&"sword", &"dodge", &"parry", &"unarmed", &"throwing"]:
		taoist.character_state.skills.set_raw_level(skill, 0) # TEST-ONLY: he neither lands nor evades a blow
	taoist.character_state.vitality.current = 3 # TEST-ONLY: the next blow fells him
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	var started: CombatSliceInitiationResult = null
	if not coordinator.has_active_encounter():
		caves.select_npc(taoist.character_id)
		started = caves.attack_selected()
	_check(coordinator.has_active_encounter() and player.relationship.has_lethal_target(taoist.character_id), "the fight with him is on, the player kills (%s)" % [null if started == null else CombatSliceInitiationResult.Outcome.find_key(started.outcome)])
	var held: bool = false
	var rounds: int = 0
	for round: int in 300:
		if not coordinator.has_active_encounter():
			break
		coordinator.advance_scheduler(1.0)
		rounds += 1
		if taoist.life_status == CharacterRuntimeLifeStatus.Value.UNCONSCIOUS:
			held = coordinator.spare_downed(taoist.character_id)
			break
	var battle: BattlePresentationController = session.get_node("BattlePresentationLayer/BattleSurface") as BattlePresentationController
	battle.refresh_projection()
	_check(held, "he falls and the player spares him (%s after %d rounds; vitality %d; the player %s; %s)" % [CharacterRuntimeLifeStatus.Value.find_key(taoist.life_status), rounds, taoist.character_state.vitality.current, CharacterRuntimeLifeStatus.Value.find_key(player.life_status), battle.log_panel._text.get_parsed_text().strip_edges().right(700)])
	_run(session)
	(session.get_node("BattlePresentationLayer/BattleSurface") as BattlePresentationController).refresh_projection()
	session.record_journal()
	_check(state.marks.get("放过了黑衣道士", 0) == 1, "spared: his hook's mark")
	_check(state.milestones.has("defeat/native.npc.black_taoist") and state.quests.has("main.chapter1/taoist") and StoryQuestLog.objective(state, quests) == "看看洞里的石壁和那具骸骨。", "felled, one of note: the step; the wall is next: %s" % [state.quests])
	# The wall: 查看 teaches the clues; then the burial, the token with him, the book always.
	_check(caves.select_landmark(WALL) and caves.inspect_selected(), "the wall looked at")
	_check(state.marks.get("看过石壁", 0) == 1, "its clues taught")
	session.record_journal()
	_check(state.quests.has("main.chapter1/wall") and StoryQuestLog.objective(state, quests) == "处置那具骸骨：安葬他，或者带走他身边的腰牌。", "the wall recorded; the bones are next")
	# A `contact` landmark is used from inside its area: at the wall itself.
	_check(caves.place_player(MOUTH, Vector2(888, 340)), "at the wall")
	await _settle(tree)
	_check(caves.select_landmark(WALL) and ui.portal_action_text() == "埋葬骸骨", "埋葬骸骨")
	var before: int = ui.log_lines().size()
	var result: BuryLandmarkPolicy.Result = caves.traverse_selected_portal() as BuryLandmarkPolicy.Result
	await tree.physics_frame
	_check(result != null and result.buried and result.outcome == BuryRoll.Outcome.BOOK and session.active_map_id() == CAVES, "buried: the book, and the floor holds (bury_always_rewards): %s %s %s at %s, %s" % [result != null, null if result == null else result.buried, null if result == null else result.outcome, player.world_location().zone_id, ui.log_lines().slice(before)])
	_check(caves.floor_item_of(SKELETON, MOUTH).is_empty() and caves.floor_item_of(TOKEN, MOUTH).is_empty() and not caves.floor_item_of(PARRYBOOK, MOUTH).is_empty() and not caves.floor_item_of(BOX, MOUTH).is_empty(), "the bones and the 腰牌 are gone, the book lies there, the 石匣 stays")
	_check(ui.log_lines().slice(before).has("你听见山洞顶部的石壁「喀喇」地一声响，一本书坠落下来。"), "the book's line")
	_check(state.marks.get("安葬无名人", 0) == 1, "the burial's mark")
	var rewards_before: int = _rewards(session).size()
	session.record_journal()
	_check(state.quests.has("main.chapter1/bones/bury") and StoryQuestLog.is_done(state, quest), "the burial ends 伪墓: %s" % [state.quests])
	_check(state.deeds[-1].did == "查明了瀑布山洞里的墓是假的" and state.deeds[-2].did == "安葬了瀑布山洞里的无名人", "its deeds")
	_check(state.milestones.has("quest/main.chapter1") and _rewards(session).slice(rewards_before).any(func(line: String) -> bool: return line.begins_with("【历练】你办成了「伪墓」")), "the 历练")
	ui.menu_tab_shown(GameMenu.Tab.JOURNAL)
	var page: String = ui.quest_page.shown_text()
	_check(page.contains("伪墓 · 老松岭 · 已完成") and page.contains("· 你把无名人安葬了，腰牌随他入土。洞顶落下一本《过招要旨》。") and page.contains("· 石壁上的字自称「南危水」"), "the 任务 page: " + page.left(400))
	# Back in the caves later the taoist is gone for good (the stage, judged as the player comes in).
	var outdoor_again: WorldMapController = MapPlaces.enter(session, &"oldpine.outdoor.central_clearing", &"oldpine.outdoor.central_clearing.player_start")
	_check(outdoor_again != null, "out")
	caves = MapPlaces.enter(session, &"oldpine.caves.maze", &"oldpine.caves.maze.cave1_landing")
	await _settle(tree)
	_check(caves != null and not taoist.exists_in_map and taoist.has_flag(NpcDefinition.FLAG_GONE), "the taoist is gone, not made anew")
	# The save keeps it all.
	var snapshot: GameSaveSnapshot = _capture(session)
	var encoded: GameSaveResult = GameSaveJsonCodec.encode(snapshot)
	var decoded: GameSaveResult = GameSaveJsonCodec.decode(encoded.text)
	_check(snapshot != null and decoded.snapshot != null and decoded.snapshot.player.character.quests == state.quests and decoded.snapshot.player.character.marks.get("安葬无名人", 0) == 1, "saved and read back: %s" % [decoded.detail])


func _session(tree: SceneTree) -> WorldSessionController:
	var session: WorldSessionController = (load("res://scenes/world/oldpine/oldpine_world_session.tscn") as PackedScene).instantiate()
	session.configure_source_entry("伪墓", CharacterState.GENDER_MALE)
	session.deterministic_combat_seed = true
	session.deterministic_npc_seed = true
	session.deterministic_world_interaction_seed = true
	tree.root.add_child(session)
	for frame: int in 4:
		await tree.process_frame
	session.set_process(false)
	return session


func _settle(tree: SceneTree) -> void:
	for frame: int in 4:
		await tree.physics_frame
	await tree.process_frame


func _run(session: WorldSessionController) -> void:
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	var rounds: int = 0
	while coordinator.has_active_encounter() and rounds < 300:
		coordinator.advance_scheduler(1.0)
		rounds += 1
	CombatEncounterCoordinator.take_aborted_total()


func _carried(session: WorldSessionController, definition_id: StringName) -> StringName:
	for id: StringName in session.inventory_state().direct_children(ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, session.player_runtime().character_id)):
		if session.item_instance_index().resolve(id).item_definition_id == definition_id:
			return id
	return &""


func _rewards(session: WorldSessionController) -> Array[String]:
	var lines: Array[String] = []
	for line: String in session.shared_ui().log_lines():
		if line.begins_with("【历练】"):
			lines.append(line)
	return lines


func _capture(session: WorldSessionController) -> GameSaveSnapshot:
	var result: OldPineWorldCaptureResult = OldPineWorldSaveCapture.new().capture(session, &"test", "2026-10-29T00:00:00Z")
	return result.snapshot


func _check(ok: bool, label: String) -> void:
	_count += 1
	if not ok:
		_failures.append(label)
