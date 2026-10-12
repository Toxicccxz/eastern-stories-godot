extends RefCounted

## 京师 A (d/city/npc, u/cp): the people of the city — the 守城兵 (vendetta authority, 反了！反了！),
## the 行人 whose gender, skills and chat chance create() draws, the 商人's 密宗大手印 and 铁布衫,
## 桃X仙's get, wear and wield all, 陈天星 who takes 陈剑秋's letter (asked first) and offers to
## take the player, the vendors and their greetings; every kind fought thirty seconds without the
## fight stopping (but 黑你没商量: the bank is no_fight). TEST-ONLY fixtures are marked.
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const SouthRoad := preload("res://tests/runtime/snow_south_road_test.gd")
const MapPlaces := preload("res://tests/support/map_places.gd")
const CHEN: StringName = &"city.npc.chen"
const WALKER: StringName = &"city.npc.walker"
const CHATER: StringName = &"common.npc.chater2"
const LETTER: StringName = &"es2:u/cloud/npc/obj/letter"
const KINDS: Array[StringName] = [
	&"city.npc.guard", WALKER, &"city.npc.trader", &"snow.npc.scavenger", CHEN, &"city.npc.clother",
	&"city.npc.shoer", &"city.npc.weaponor", &"city.npc.waiter", &"city.npc.boss", &"city.npc.vendor",
	&"city.npc.caker", &"city.npc.dumpling_seller", CHATER,
]
## combat_exp of each kind (the files' set("combat_exp")).
const EXP: Dictionary = {
	&"city.npc.guard": 100000, WALKER: 30000, &"city.npc.trader": 5000, CHEN: 1000000, &"city.npc.microsof": 100000,
	&"city.npc.clother": 300000, &"city.npc.shoer": 220000, &"city.npc.weaponor": 120000, &"city.npc.waiter": 5,
	&"city.npc.boss": 1000, &"city.npc.vendor": 30000, &"city.npc.caker": 30, &"city.npc.dumpling_seller": 30, CHATER: 100,
}

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_people()
	_test_walker_draws()
	_test_silent_master()
	var session: WorldSessionController = Work.create_session(tree)
	await tree.process_frame
	session.set_process(false)
	session.configure_npc_ambience_random_source(SouthRoad.Still.new()) # TEST-ONLY: nobody chats or wanders
	_check(session.handoff_to(&"city.main", &"city.nroad2", &"city.nroad2", &"city.nroad2.village_arrival").succeeded(), "on the 北驿道")
	await tree.process_frame
	await _test_chater(tree, session)
	await _test_walkers_kept(tree, session)
	await _test_chen(tree, session)
	await _test_fights(tree, session)
	session.free()
	await tree.process_frame
	return {"assertions": _count, "failures": _failures}


func _test_people() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	for id: StringName in EXP:
		var npc: NpcDefinition = catalog.npc(id)
		_check(npc != null and not npc.dealings().is_fight_deferred(), "%s can be fought" % id)
		_check(npc != null and npc.combat_experience == EXP[id], "%s: %d exp" % [id, EXP[id]])
	var guard: NpcDefinition = catalog.npc(&"city.npc.guard")
	_check(guard.dealings().vendetta_mark == "authority" and guard.dealings().accept_kill.line == "守城兵大叫：反了！反了！", "守城兵: vendetta authority; 反了！反了！ when attacked")
	_check(guard.talk().combat_chat_chance == 15 and guard.talk().combat_chat_entries().size() == 2, "守城兵: 束手就缚 and 造反 in a fight")
	var trader: NpcDefinition = catalog.npc(&"city.npc.trader")
	_check(trader.skill_map().get(&"unarmed") == &"bloodystrike" and trader.skill_levels().any(func(s: NpcSkillLevelDefinition) -> bool: return s.skill_id == &"iron-cloth" and s.raw_level == 50), "商人: 密宗大手印 mapped, 铁布衫 50")
	_check(trader.talk().chat_chance == 30 and trader.talk().combat_chat_chance == 15, "商人: 买官 talk; 你也想打劫？ and walking out of a fight")
	var chen: NpcDefinition = catalog.npc(CHEN)
	var teaching: NpcTeaching = chen.teaching()
	_check(teaching.family_name == "振远镖局" and teaching.family_generation == 0 and teaching.family_privileges == 0, "陈天星 founded 振远镖局 (privs 0: he teaches his own)")
	_check(teaching.apprentice.kind == NpcTeaching.Kind.SILENT and teaching.apprentice.class_id == &"guardman" and teaching.apprentice.title == "振远镖局第一代弟子", "no attempt_apprentice(); 振远镖局第一代弟子, guardman")
	_check(Array(chen.talk().answer("拜师")) == ["是剑秋推荐的嘛？可有他的信物？\n"], "拜师: 可有他的信物？")
	var walker: NpcDefinition = catalog.npc(WALKER)
	_check(walker.skill_roll() != null and walker.skill_roll().bound == 4 and walker.skill_roll().skills.get(&"spicyclaw") == 20 and walker.talk().chat_chance_roll() != null, "行人: random(4) skills and random(20) chat")
	_check(Array(walker.talk().answer("买官")) == ["全是那个该死的尚书作的孽。\n"], "行人: 买官 (the closure's string)")
	var chater: NpcDefinition = catalog.npc(CHATER)
	_check(chater.name_pick().size() == 7 and chater.name_pick().has("桃花仙") and chater.talk().chat_chance == 10, "桃X仙: seven names; chat 10")
	var entries: Array = chater.talk().chat_entries()
	_check(entries.size() == 7 and entries.slice(0, 3) == [NpcTalk.GET_ALL, NpcTalk.WEAR_ALL, NpcTalk.WIELD_ALL] and entries.slice(3).all(func(e: Variant) -> bool: return e == NpcTalk.SILENT_EMOTE), "get all, wear all, wield all and four silent drools")
	_check(catalog.room(&"es2:d/city/bank").no_fight and catalog.npc(&"city.npc.microsof").talk().has_greeting(), "黑你没商量 greets in his no_fight bank")
	var waiter: Array[NpcObjectRule] = catalog.npc(&"city.npc.waiter").dealings().object_rules
	_check(waiter.size() == 3 and waiter[0].drops and waiter[0].value_at_most == 999 and waiter[2].mark_giver == "酒楼", "店小二: below 1000 on the floor, 1000 and more marks/酒楼")
	for vendor: Array in [[&"city.vendor.waiter", 3], [&"city.vendor.caker", 1], [&"city.vendor.shoer", 3], [&"city.vendor.clother", 3], [&"city.vendor.weaponor", 9], [&"city.vendor.vendor", 1], [&"city.vendor.dumpling_seller", 1]]:
		_check(catalog.vendor(vendor[0]) != null and catalog.vendor(vendor[0]).goods_keys().size() == vendor[1], "%s: %d goods" % vendor)
	_check(catalog.skill(&"bloodystrike") != null and catalog.skill(&"iron-cloth") != null, "密宗大手印 and 铁布衫 are ported")


## walker.c's draws: gender random(3), age 20 + random(45), random(4) == 0 skills, chat random(20).
func _test_walker_draws() -> void:
	var walker: NpcDefinition = GameContent.catalog().npc(WALKER)
	var cases: Array = [[[0, 10, 0, 7], &"女性", 30, true, 7], [[1, 44, 3, 19], &"男性", 64, false, 19]]
	for case: Array in cases:
		var draws: Array[int] = []
		draws.assign(case[0])
		for _i: int in range(40):
			draws.append(0)
		var npc: NpcRuntimeState = NpcCharacterStateFactory.new().create_one(walker, &"test.walker", &"test.spawn", &"test.point",
			WorldLocationState.new(&"city", &"city.main", &"city.street2", &"city.street2"),
			InventoryState.new(), CombinedStackCollection.new(), ScriptedNpcInitializationRandomSource.new(draws), [])
		_check(npc != null, "a 行人 is made from draws %s" % [case[0]])
		if npc == null:
			continue
		var skilled: bool = npc.character_state.skills.raw_level(&"spicyclaw") == 20 and npc.character_state.skills.mapped_skill(&"unarmed") == &"spicyclaw"
		_check(npc.character_state.gender == case[1] and npc.age == case[2] and skilled == case[3] and npc.chat_chance == case[4], "draws %s: %s, %d, skills %s, chat %d: %s %d %s %d" % [case[0], case[1], case[2], case[3], case[4], npc.character_state.gender, npc.age, skilled, npc.chat_chance])


## chen.c has no attempt_apprentice(): 拜师 only waits; his recruit then takes the player at once.
func _test_silent_master() -> void:
	var chen: NpcDefinition = GameContent.catalog().npc(CHEN)
	var family: FamilyDefinition = GameContent.catalog().family(chen.teaching().family_id)
	var student := CharacterState.new()
	var request := NpcApprenticeship.new()
	_check(request.request(student, chen, family, 1000, "这位壮士") == NpcApprenticeship.Outcome.PENDING and request.lines == ["你想要拜陈天星为师。"] and request.is_pending_with(CHEN), "拜师: 你想要拜陈天星为师。 and it waits")
	_check(request.request(student, chen, family, 1000, "这位壮士") == NpcApprenticeship.Outcome.PENDING and request.lines == ["你想拜陈天星为师，但是对方还没有答应。"], "again: 对方还没有答应")
	_check(request.npc_recruit(student, chen, family, 1000) == NpcApprenticeship.Outcome.RECRUITED, "his recruit takes the waiting request at once")
	_check(request.lines.has("陈天星决定收你为弟子。") and student.family.generation == 1 and student.affiliation.class_id == &"guardman", "陈天星决定收你为弟子: the first generation, a guardman: %s" % [request.lines])


## 桃X仙 (u/cp/chater2.c): get all takes what lies on the 驿道, wear all and wield all put it on.
func _test_chater(tree: SceneTree, session: WorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var hud: SharedGameplayUI = session.shared_ui()
	var chater: NpcRuntimeState = null
	for npc: NpcRuntimeState in map.resident_npcs():
		if NpcDefinition.unnamed_id(npc.definition().definition_id) == CHATER:
			chater = npc
	_check(chater != null and chater.definition().display_name.begins_with("桃") and chater.definition().display_name.ends_with("仙"), "桃X仙 on the 驿道: %s" % ("" if chater == null else chater.definition().display_name))
	if chater == null:
		return
	var body: WorldCharacterBody2D = map.runtime_body_for_character(chater.character_id)
	_check(map.place_player(&"city.nroad2", MapPlaces.spot(map, &"city.nroad2", body.global_position + Vector2(48, 0), 60.0)), "TEST-ONLY: beside 桃X仙")
	await tree.physics_frame
	await tree.physics_frame
	var boots: StringName = map.floor_items.give_new_item_to_player(&"es2:d/city/npc/obj/deer_boot") # TEST-ONLY
	var sword: StringName = map.floor_items.give_new_item_to_player(&"es2:obj/longsword") # TEST-ONLY
	_check(map.drop_item(boots).done() and map.drop_item(sword).done(), "the player drops 鹿皮小靴 and a 长剑")
	var name: String = chater.definition().display_name
	map.npc_life._command(chater, NpcTalk.GET_ALL)
	var got: Array[String] = hud.log_lines().slice(-2)
	_check(got == ["%s捡起一件鹿皮小靴。" % name, "%s捡起一把长剑。" % name], "get all: %s" % [got])
	_check(not map.floor_items.floor_item_ids().has(boots) and not map.floor_items.floor_item_ids().has(sword), "nothing lies there now")
	map.npc_life._command(chater, NpcTalk.WEAR_ALL)
	_check(hud.log_lines()[-1] == "%s穿上一件鹿皮小靴。" % name and chater.armor.is_worn(boots), "wear all: %s" % hud.log_lines()[-1])
	map.npc_life._command(chater, NpcTalk.WIELD_ALL)
	_check(hud.log_lines()[-1] == "%s装备长剑作武器。" % name and chater.character_state.equipment.has_weapon_instance(sword), "wield all: %s" % hud.log_lines()[-1])
	var before: int = hud.log_lines().size()
	map.npc_life._command(chater, NpcTalk.WEAR_ALL)
	map.npc_life._command(chater, NpcTalk.WIELD_ALL)
	map.npc_life._command(chater, NpcTalk.GET_ALL)
	_check(hud.log_lines().size() == before, "nothing more to take or put on: nothing said")
	_check(Work.capture(session) != null, "Save with 桃X仙 armed")


## Each 行人 keeps the chat chance create() drew, through Save and Continue.
func _test_walkers_kept(tree: SceneTree, session: WorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var chances: Dictionary = {}
	for npc: NpcRuntimeState in map.resident_npcs():
		if npc.definition().definition_id == WALKER:
			chances[npc.character_id] = npc.chat_chance
			_check(npc.chat_chance >= 0 and npc.chat_chance < 20, "a 行人's chat_chance: random(20): %d" % npc.chat_chance)
		elif npc.chat_chance != -1:
			_check(false, "%s draws no chat chance" % npc.definition().definition_id)
	_check(chances.size() == 3, "three 行人")
	var snapshot: GameSaveSnapshot = Work.capture(session)
	_check(snapshot != null, "Save with the 行人")
	if snapshot == null:
		return
	var kept: int = 0
	for spawn: GameSaveValueTypes.NpcSpawnStateSnapshot in snapshot.npc_spawn_states:
		if chances.has(spawn.character_id) and spawn.chat_chance == chances[spawn.character_id]:
			kept += 1
	_check(kept == 3, "Save keeps each 行人's chat chance (%d)" % kept)
	var encoded: GameSaveResult = GameSaveJsonCodec.encode(snapshot)
	var decoded: GameSaveResult = GameSaveJsonCodec.decode(encoded.text)
	var restored: OldPineWorldRestoreResult = OldPineWorldRestoreService.build_candidate(decoded.snapshot, tree.root)
	_check(encoded.succeeded() and decoded.succeeded() and restored.succeeded(), "Continue builds: %s" % restored.path)
	if not restored.succeeded():
		return
	var fresh: WorldSessionController = restored.candidate
	_check(fresh.activate_restore_candidate(), "Continue activates")
	var back: int = 0
	for npc: NpcRuntimeState in (fresh.active_map() as WorldMapController).resident_npcs():
		if chances.has(npc.character_id) and npc.chat_chance == chances[npc.character_id]:
			back += 1
	_check(back == 3, "Continue: each 行人 keeps its chat chance (%d)" % back)
	var after: GameSaveSnapshot = Work.capture(fresh)
	_check(after != null and GameSaveJsonCodec.encode(after).text == encoded.text, "Save again: the same file")
	fresh.free()
	await tree.process_frame


## 陈剑秋's letter: asked first; 陈天星 takes it and offers; 拜师 makes the player his.
func _test_chen(tree: SceneTree, session: WorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var hud: SharedGameplayUI = session.shared_ui()
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var chen: NpcRuntimeState = null
	for npc: NpcRuntimeState in map.resident_npcs():
		if npc.definition().definition_id == CHEN:
			chen = npc
	var body: WorldCharacterBody2D = map.runtime_body_for_character(chen.character_id)
	_check(map.place_player(&"city.biaoju", MapPlaces.spot(map, &"city.biaoju", body.global_position + Vector2(0, 48), 40.0)), "TEST-ONLY: beside 陈天星 in 振远总局")
	await tree.physics_frame
	await tree.physics_frame
	_check(map.select_npc(chen.character_id), "陈天星")
	var cloth: StringName = map.floor_items.give_new_item_to_player(&"es2:obj/cloth") # TEST-ONLY
	var teased: ItemHandlingResult = map.give_to_selected(cloth)
	_check(teased.outcome == ItemHandlingResult.Outcome.REFUSED and teased.lines == ["不要戏弄我！", "陈天星没有收下。"], "a 布衣: 不要戏弄我！ and it comes back (M2, 默认): %s" % [teased.lines])
	var plain: StringName = map.floor_items.give_new_item_to_player(LETTER) # TEST-ONLY: a letter that is nobody's
	var doubted: ItemHandlingResult = map.give_to_selected(plain)
	_check(doubted.outcome == ItemHandlingResult.Outcome.REFUSED and doubted.lines[0].begins_with("陈天星狐疑地望着你") and doubted.lines[-1] == "陈天星没有收下。", "a letter not the player's: 这是你的嘛？ and back: %s" % [doubted.lines])
	var letter: StringName = map.floor_items.give_new_item_to_player(ItemContentDefinition.master_id(LETTER)) # TEST-ONLY: 陈剑秋 wrote it for the player
	hud.items.give_item(letter, 0)
	await tree.physics_frame
	_check(hud.is_asking() and hud.confirm_prompt.message.text.contains("你再向他拜师"), "asked first: %s" % hud.confirm_prompt.message.text)
	hud.confirm_prompt.cancel_button.pressed.emit()
	await tree.physics_frame
	_check(_carries(session, letter), "取消: the letter is still the player's")
	hud.items.give_item(letter, 0)
	await tree.physics_frame
	hud.confirm_prompt.confirm_button.pressed.emit()
	await tree.physics_frame
	var log: Array[String] = hud.log_lines()
	var at: int = log.rfind("陈天星说道：果然是剑秋侄儿推荐来的。我收你啦。")
	_check(at >= 0 and log.slice(at, at + 4) == ["陈天星说道：果然是剑秋侄儿推荐来的。我收你啦。", "陈天星想要收你为弟子。", "如果你愿意拜陈天星为师父，就向他拜师。", "你给陈天星一封信件。"], "taken, and he offers: %s" % [log.slice(-5)])
	_check(not _carries(session, letter) and player.apprenticeship_request.is_offered(CHEN) and not player.state.family.has_family(), "the letter is his; not taken yet")
	var service: TeacherService = null
	for candidate: WorldService in map.service_nodes:
		if candidate is TeacherService and (candidate as TeacherService).npc.character_id == chen.character_id:
			service = candidate as TeacherService
	_check(service != null and player.would_be_taken_by(chen.definition()), "拜师 now takes the player (the teacher panel asks first)")
	service.request_apprentice()
	_check(NpcApprenticeship.is_master_of(player.state, chen.definition()) and player.state.family.generation == 1 and player.state.affiliation.class_id == &"guardman" and player.shown_title() == "振远镖局第一代弟子", "振远镖局第一代弟子: %s %s" % [player.shown_title(), service.last_lines])
	_check(service.last_lines.has("恭喜您成为振远镖局的第一代弟子。"), "恭喜您成为振远镖局的第一代弟子: %s" % [service.last_lines])
	_check(Work.capture(session) != null, "Save as 陈天星's apprentice")


## Every kind fights to the end without the fight stopping.
func _test_fights(tree: SceneTree, session: WorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var fought: Array[StringName] = []
	var rebellion: bool = false
	for npc: NpcRuntimeState in map.resident_npcs():
		var id: StringName = NpcDefinition.unnamed_id(npc.definition().definition_id)
		if not KINDS.has(id) or not npc.exists_in_map or fought.has(id) or npc.life_status != CharacterRuntimeLifeStatus.Value.ACTIVE:
			continue
		fought.append(id)
		var lines: Array[String] = await _fight(tree, session, map, npc)
		if id == &"city.npc.guard":
			rebellion = lines.has("守城兵大叫：反了！反了！")
	_check(fought.size() == KINDS.size(), "%d kinds fought: %s" % [fought.size(), fought])
	_check(rebellion, "attacked, a 守城兵 cries 反了！反了！")
	_check(session.player_runtime().state.vendetta.get("authority", 0) == 0, "attacking is no killing: no vendetta yet")


func _fight(tree: SceneTree, session: WorldSessionController, map: WorldMapController, npc: NpcRuntimeState) -> Array[String]:
	var name: String = npc.definition().display_name
	var player: WorldPlayerRuntimeState = session.player_runtime()
	_full(player)
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	_check(map.relocate_player(npc.world_location().zone_id, npc.spawn_point_id), "beside %s" % name)
	await tree.physics_frame
	await tree.physics_frame
	CombatEncounterCoordinator.take_aborted_total()
	var said: Array[String] = []
	if not coordinator.has_active_encounter():
		var start: int = session.shared_ui().log_lines().size()
		map.select_npc(npc.character_id)
		var started: CombatSliceInitiationResult = map.attack_selected()
		_check(started.outcome == CombatSliceInitiationResult.Outcome.COMPLETED, "the player attacks %s: %s %s" % [name, CombatSliceInitiationResult.Outcome.find_key(started.outcome), session.shared_ui().log_lines().slice(-2)])
		said.assign(session.shared_ui().log_lines().slice(start))
	coordinator.advance_scheduler(30.0)
	_check(CombatEncounterCoordinator.take_aborted_total() == 0, "%s: thirty seconds of fighting without a stop" % name)
	_finish_fight(session)
	await tree.physics_frame
	return said


## TEST-ONLY: away from the fight, by fleeing as often as it takes.
func _finish_fight(session: WorldSessionController) -> void:
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var rounds: int = 0
	while coordinator.has_active_encounter() and rounds < 600:
		var info: CombatTacticalActionInfo = coordinator.action_infos()[0]
		coordinator.submit_player_action(CombatTacticalRequest.new(info.action_id, coordinator.active_encounter().encounter_id, player.character_id, info.action_id, info.category))
		coordinator.advance_scheduler(1.0)
		rounds += 1
	_check(not coordinator.has_active_encounter() and CombatEncounterCoordinator.take_aborted_total() == 0, "TEST-ONLY: out of the fight")
	session.shared_ui().dismiss_current_panel()
	for opponent_id: StringName in player.relationship.opponent_ids(): # TEST-ONLY: as walking away would
		player.relationship.remove_lethal_relation(opponent_id)
		player.relationship.remove_opponent(opponent_id)


func _full(player: WorldPlayerRuntimeState) -> void:
	player.state.vitality = CharacterResourceState.new(1000000, 1000000, 1000000) # TEST-ONLY: nobody dies here
	player.state.essence = CharacterResourceState.new(1000000, 1000000, 1000000) # TEST-ONLY
	player.state.spirit = CharacterResourceState.new(1000000, 1000000, 1000000) # TEST-ONLY
	player.state.progression.combat_experience = 100000 # TEST-ONLY


func _carries(session: WorldSessionController, item_id: StringName) -> bool:
	var player: WorldPlayerRuntimeState = session.player_runtime()
	return session.inventory_state().direct_children(ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, player.character_id)).has(item_id)


func _check(condition: bool, message: String) -> void:
	_count += 1
	if not condition:
		_failures.append("city npcs: " + message)
