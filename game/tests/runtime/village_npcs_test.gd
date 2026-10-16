extends RefCounted

## 玉螺湖村 A (d/village/npc): the villagers and what they fight with — the 商人 with 天邪派's arts
## (walking out of a fight), the 渔夫's 风雨身法, the 采花妞's 紫花瓣儿, the 农妇's 菜刀 and her age
## line, 刘老农's 六阴剑法 and 火蝠身法 (no spar), the 瓜农's 封山 arts and his 西瓜, the rats and
## the 白鳞冰龙; their chat and inquiries; every kind fought thirty seconds without the fight
## stopping. TEST-ONLY fixtures are marked.
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const SouthRoad := preload("res://tests/runtime/snow_south_road_test.gd")
const KINDS: Array[StringName] = [
	&"village.npc.trader1", &"village.npc.woman1", &"village.npc.flowergirl", &"village.npc.oldliu",
	&"village.npc.rat", &"village.npc.meloner", &"village.npc.fisher", &"village.npc.dragon",
]
## combat_exp of each kind (the files' set("combat_exp"); the 农妇's is 20 + random(40), the rat's unset).
const EXP: Dictionary = {
	&"village.npc.trader1": 80000, &"village.npc.flowergirl": 700, &"village.npc.oldliu": 10000, &"village.npc.rat": 0,
	&"village.npc.meloner": 8000, &"village.npc.fisher": 20000, &"village.npc.dragon": 1000000,
}
## What each kind carries (cloth, money and arms, in carry_object() order).
const GEAR: Dictionary = {
	&"village.npc.trader1": [&"es2:obj/money/silver", &"es2:obj/cloth"],
	&"village.npc.woman1": [&"es2:obj/money/coin", &"es2:obj/cloth", &"es2:d/village/npc/obj/knife"],
	&"village.npc.flowergirl": [&"es2:obj/money/coin", &"es2:obj/cloth", &"es2:d/village/npc/obj/flower"],
	&"village.npc.oldliu": [&"es2:obj/money/coin", &"es2:obj/cloth", &"es2:d/village/npc/obj/parrybook"],
	&"village.npc.meloner": [&"es2:obj/cloth"],
	&"village.npc.fisher": [&"es2:obj/cloth"],
}
## The maps the fights walk, with where the player stands at first (the houses are their own
## maps since the remap: the 农妇's, 刘老农's with the rats' storeroom, the 瓜棚).
const MAPS: Array = [
	[&"village.main", &"village.road1", &"village.road1.canyon_arrival"],
	[&"village.farmhouse_house", &"village.farmhouse1", &"village.farmhouse1.road4_entry"],
	[&"village.liu_house", &"village.home", &"village.home.littlegarden_entry"],
	[&"village.melonguard_house", &"village.melonguard", &"village.melonguard.road7_entry"],
	[&"village.icecave", &"village.lakebottom1", &"village.lakebottom1.dive_arrival"],
]

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_people()
	var session: WorldSessionController = Work.create_session(tree)
	await tree.process_frame
	session.set_process(false)
	session.configure_npc_ambience_random_source(SouthRoad.Still.new()) # TEST-ONLY: nobody chats or wanders
	await _test_fights(tree, session)
	await _test_walks_out_onto_another_map(tree, session)
	session.free()
	await tree.process_frame
	return {"assertions": _count, "failures": _failures}


## go.c in a fight onto another map (the 商人 walks out south to 京师's 北大街; since the remap a
## shop's door is such a way too): he is there at once, his body goes through once the fight is
## over, and a save finds him there.
func _test_walks_out_onto_another_map(tree: SceneTree, session: WorldSessionController) -> void:
	var village: WorldMapController = session.world_map_of(&"village.main")
	var trader: NpcRuntimeState = null
	for npc: NpcRuntimeState in village.npc_runtimes():
		if NpcDefinition.unnamed_id(npc.definition_id) == &"village.npc.trader1" and npc.world_location().zone_id == &"village.road2" and npc.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE:
			trader = npc
			break
	var map: WorldMapController = null if trader == null else MapPlaces.enter(session, &"village.road2", trader.spawn_point_id)
	if not _check(map == village, "beside the 商人 on 青石小路 (TEST-ONLY)"):
		return
	await tree.physics_frame
	map.select_npc(trader.character_id)
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	if not _check(map.attack_selected().outcome == CombatSliceInitiationResult.Outcome.COMPLETED, "the player attacks the 商人"):
		return
	var encounter: CombatEncounter = coordinator.active_encounter()
	coordinator._resolution.depart(session.encounter_combat_bindings(encounter), trader.character_id, &"city.nroad2") # TEST-ONLY: as his combat chat's random_move would
	_check(trader.world_location().map_id == &"city.main" and trader.world_location().zone_id == &"city.nroad2", "in 北大街 at once, on 京师's map: %s" % trader.world_location().map_id)
	var rounds: int = 0
	while coordinator.has_active_encounter() and rounds < 20:
		coordinator.advance_scheduler(1.0)
		rounds += 1
	var city: WorldMapController = session.world_map_of(&"city.main")
	_check(not coordinator.has_active_encounter() and coordinator.npc_walked_out(encounter.encounter_id), "he walked out, and that ends it")
	_check(city.find_resident_npc(trader.character_id) == trader and village.find_resident_npc(trader.character_id) == null and city.runtime_body_for_character(trader.character_id) != null, "his record and body went through onto 京师's map")
	session.shared_ui().dismiss_current_panel()
	await tree.physics_frame
	var snapshot: GameSaveSnapshot = Work.capture(session)
	if _check(snapshot != null, "a save with him in 北大街"):
		var decoded: GameSaveResult = GameSaveJsonCodec.decode(GameSaveJsonCodec.encode(snapshot).text)
		var restored: OldPineWorldRestoreResult = OldPineWorldRestoreService.build_candidate(decoded.snapshot, tree.root)
		_check(restored.succeeded() and restored.candidate.world_map_of(&"city.main").find_resident_npc(trader.character_id) != null, "and Continue finds him there: %s" % restored.path)
		if restored.succeeded():
			restored.candidate.free()
			await tree.process_frame


func _test_people() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	for id: StringName in KINDS:
		var npc: NpcDefinition = catalog.npc(id)
		_check(npc != null and not npc.dealings().is_fight_deferred(), "%s can be fought" % id)
		if EXP.has(id):
			_check(npc.combat_experience == EXP[id], "%s: %d exp" % [id, npc.combat_experience])
		var carried: Array[StringName] = []
		for entry: NpcLoadoutEntry in npc.loadout_entries():
			carried.append(entry.item_definition_id)
		_check(carried == GEAR.get(id, []), "%s carries %s" % [id, carried])
	for id: StringName in [&"stormdance", &"chaos-steps", &"fonxansword", &"fonxanforce", &"celestial", &"celestrike", &"six-chaos-sword", &"pyrobat-steps", &"liuh-ken"]:
		_check(catalog.skill(id) != null, "%s is ported" % id)
	var trader: NpcTalk = catalog.npc(&"village.npc.trader1").talk()
	_check(trader.chat_chance == 30 and trader.combat_chat_chance == 15 and trader.combat_chat_entries().size() == 2, "商人: 绮云镇阿泰 and wandering; 杀人啦 and walking out of a fight")
	var woman: Array = catalog.npc(&"village.npc.woman1").talk().combat_chat_entries()
	_check(woman.size() == 2 and woman[0] is NpcFightChat.Wield and (woman[0] as NpcFightChat.Wield).combat_chance == 10 and woman[1] is NpcFightChat.SayByAge, "农妇: wield_weapon(), converse_one()")
	_check((woman[1] as NpcFightChat.SayByAge).says(14, 30) == ["唉，我那可怜的儿啊，年龄比你还小。!"] and (woman[1] as NpcFightChat.SayByAge).says(30, 30) == ["以大欺小啊你..."], "younger than her: 我那可怜的儿; else 以大欺小")
	_check(catalog.npc(&"village.npc.woman1").talk().answer("儿").size() == 1 and catalog.npc(&"village.npc.woman1").talk().chat_chance == 20, "农妇 weeps for her son; 儿: 听说黑松山总抓小孩子")
	_check(Array(catalog.npc(&"village.npc.flowergirl").talk().answer("小娟")) == ["这要到黑松山去问。"], "采花妞: 小娟 is a question for 黑松山")
	var fisher: NpcTalk = catalog.npc(&"village.npc.fisher").talk()
	_check(fisher.chat_chance == 2 and fisher.combat_chat_chance == 10 and fisher.answer("桂花").size() == 1, "渔夫: the 水怪; 桂花 (kept: the author's joke, 默认)")
	var liu: NpcDefinition = catalog.npc(&"village.npc.oldliu")
	_check(liu.skill_map().get(&"sword") == &"six-chaos-sword" and liu.skill_map().get(&"dodge") == &"pyrobat-steps" and liu.skill_map().get(&"unarmed") == &"liuh-ken", "刘老农: 六阴剑法, 火蝠身法, 柳家拳")
	_check(liu.talk().has_greeting() and catalog.npc(&"village.npc.meloner").talk().has_greeting(), "刘老农 and the 瓜农 greet")
	var flower: ItemContentDefinition = catalog.item(&"es2:d/village/npc/obj/flower")
	_check(flower.display_name == "紫花瓣儿" and flower.weapon_skill_type == &"throwing", "紫花瓣儿: thrown")
	var book: ItemContentDefinition = catalog.item(&"es2:d/village/npc/obj/parrybook")
	_check(book != null and book.item_definition_id != &"es2:d/oldpine/npc/obj/parrybook" and book.study.max_skill == 60 and book.study.exp_required == 2000, "the village's own 过招要旨: parry to 60 from 2000 exp")
	var dragon: NpcDefinition = catalog.npc(&"village.npc.dragon")
	_check(dragon.attitude == NpcDefinition.Attitude.AGGRESSIVE and dragon.race_id == &"beast", "白鳞冰龙: aggressive beasts")


## Every kind fights to the end without the fight stopping.
func _test_fights(tree: SceneTree, session: WorldSessionController) -> void:
	var fought: Array[StringName] = []
	for entry: Array in MAPS:
		_check(session.handoff_to(entry[0], entry[1], entry[1], entry[2]).succeeded(), "onto %s" % entry[0])
		await tree.process_frame
		var map: WorldMapController = session.active_map() as WorldMapController
		for npc: NpcRuntimeState in map.resident_npcs():
			var id: StringName = npc.definition().definition_id
			if not KINDS.has(id) or not npc.exists_in_map or fought.has(id) or npc.life_status != CharacterRuntimeLifeStatus.Value.ACTIVE:
				continue
			fought.append(id)
			await _fight(tree, session, map, npc)
	_check(fought.size() == KINDS.size(), "%d kinds fought: %s" % [fought.size(), fought])


func _fight(tree: SceneTree, session: WorldSessionController, map: WorldMapController, npc: NpcRuntimeState) -> void:
	var name: String = npc.definition().display_name
	var player: WorldPlayerRuntimeState = session.player_runtime()
	_full(player)
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	_open_doors(map)
	_check(map.relocate_player(npc.world_location().zone_id, npc.spawn_point_id), "beside %s" % name)
	await tree.physics_frame
	await tree.physics_frame
	CombatEncounterCoordinator.take_aborted_total()
	if not coordinator.has_active_encounter():
		map.select_npc(npc.character_id)
		var started: CombatSliceInitiationResult = map.attack_selected()
		_check(started.outcome == CombatSliceInitiationResult.Outcome.COMPLETED, "the player attacks %s: %s %s" % [name, CombatSliceInitiationResult.Outcome.find_key(started.outcome), session.shared_ui().log_lines().slice(-2)])
	coordinator.advance_scheduler(30.0)
	_check(CombatEncounterCoordinator.take_aborted_total() == 0, "%s: thirty seconds of fighting without a stop" % name)
	_finish_fight(session)
	await tree.physics_frame


## TEST-ONLY: the doors open, so the relocations stand in reach.
func _open_doors(map: WorldMapController) -> void:
	for door: WorldDoor in map.doors():
		if not door.is_open():
			door.set_open(true)


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


func _check(condition: bool, message: String) -> bool:
	_count += 1
	if not condition:
		_failures.append("village npcs: " + message)
	return condition
