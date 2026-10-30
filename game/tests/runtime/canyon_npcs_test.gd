extends RefCounted

## 天驼关 A (d/canyon/npc): the garrison and what it fights with — the soldiers of 40000 to
## 120000 exp with their 军刀 and 长剑, 李信 and 严廷殷 with 天邪派's arts (六阴剑法, 天邪神功's
## powerup and recover, 火蝠身法, 天邪掌), 赫造基 with 茅山's (谷衣心法, 茅山道术's four bolts and
## 召护法) and his 迷幻经纶; the chat, the inquiries; every kind fought thirty seconds without the
## fight stopping. TEST-ONLY fixtures are marked.
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const SouthRoad := preload("res://tests/runtime/snow_south_road_test.gd")
const KINDS: Array[StringName] = [
	&"canyon.npc.door_guard", &"canyon.npc.guard1", &"canyon.npc.guard2", &"canyon.npc.leader1", &"canyon.npc.captain",
	&"canyon.npc.leader2", &"canyon.npc.vice_general", &"canyon.npc.general", &"canyon.npc.adviser", &"canyon.npc.seller",
]
## combat_exp of each kind (the files' set("combat_exp")).
const EXP: Dictionary = {
	&"canyon.npc.door_guard": 60000, &"canyon.npc.guard1": 40000, &"canyon.npc.guard2": 40000, &"canyon.npc.leader1": 80000,
	&"canyon.npc.captain": 120000, &"canyon.npc.leader2": 80000, &"canyon.npc.vice_general": 400000, &"canyon.npc.general": 900000,
	&"canyon.npc.adviser": 300000, &"canyon.npc.seller": 50000,
}
## What each kind wields and wears.
const GEAR: Dictionary = {
	&"canyon.npc.door_guard": [&"es2:d/canyon/npc/obj/blade"],
	&"canyon.npc.leader1": [&"es2:d/canyon/npc/obj/sword"],
	&"canyon.npc.captain": [&"es2:d/canyon/npc/obj/sword", &"es2:d/canyon/npc/obj/armor"],
	&"canyon.npc.leader2": [&"es2:d/canyon/npc/obj/blade"],
	&"canyon.npc.vice_general": [&"es2:obj/longsword", &"es2:d/canyon/npc/obj/armor"],
	&"canyon.npc.general": [&"es2:d/canyon/npc/obj/broken_sword", &"es2:d/canyon/npc/obj/cloud_armor"],
	&"canyon.npc.adviser": [&"es2:d/canyon/npc/obj/fan_sword", &"es2:d/canyon/npc/obj/hat"],
	&"canyon.npc.seller": [&"es2:d/canyon/npc/obj/blade"],
}
## The maps the fights walk, with where the player stands at first (the camp is its own map).
const MAPS: Array = [
	[&"canyon.camp", &"canyon.camp2", &"canyon.camp2.tent_return"],
	[&"canyon.armory", &"canyon.blackmarket", &"canyon.blackmarket.swear_arrival"],
]

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_people()
	_test_arts()
	var session: WorldSessionController = Work.create_session(tree)
	await tree.process_frame
	session.set_process(false)
	session.configure_npc_ambience_random_source(SouthRoad.Still.new()) # TEST-ONLY: nobody chats or wanders
	await _test_fights(tree, session)
	session.free()
	await tree.process_frame
	return {"assertions": _count, "failures": _failures}


func _test_people() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	for id: StringName in KINDS:
		var npc: NpcDefinition = catalog.npc(id)
		_check(npc != null and not npc.dealings().is_fight_deferred() and npc.combat_experience == EXP[id], "%s: %d exp, can be fought" % [id, 0 if npc == null else npc.combat_experience])
		var carried: Array[StringName] = []
		for entry: NpcLoadoutEntry in npc.loadout_entries():
			carried.append(entry.item_definition_id)
		_check(carried == GEAR.get(id, []), "%s carries %s" % [id, carried])
	var general: NpcDefinition = catalog.npc(&"canyon.npc.general")
	_check(general.display_name == "严廷殷" and general.nickname == "镇国大将军" and general.title == "天邪派第十六代弟子" and general.description.contains("威风凛凛"), "严廷殷, 镇国大将军, 天邪派第十六代弟子 (威风凛凛)")
	for id: StringName in [&"canyon.npc.general", &"canyon.npc.vice_general"]:
		var npc: NpcDefinition = catalog.npc(id)
		var map: Dictionary[StringName, StringName] = npc.skill_map()
		_check(map.get(&"sword") == &"six-chaos-sword" and map.get(&"parry") == &"six-chaos-sword" and map.get(&"force") == &"celestial" and map.get(&"unarmed") == &"celestrike" and map.get(&"dodge") == &"pyrobat-steps", "%s: 天邪派's arts" % npc.display_name)
		var exerts: Array[StringName] = []
		for entry: Variant in npc.talk().combat_chat_entries():
			exerts.append((entry as NpcSpecialAction).function_id)
		_check(npc.talk().combat_chat_chance == 80 and exerts == [&"powerup", &"recover"], "%s: exert powerup or recover in a fight" % npc.display_name)
	var adviser: NpcDefinition = catalog.npc(&"canyon.npc.adviser")
	var spells: Array[StringName] = []
	for entry: Variant in adviser.talk().combat_chat_entries():
		spells.append((entry as NpcSpecialAction).function_id)
	_check(adviser.skill_map().get(&"spells") == &"necromancy" and adviser.skill_map().get(&"magic") == &"taoism" and adviser.skill_map().get(&"force") == &"gouyee", "赫造基: 茅山道术, 道术, 谷衣心法")
	_check(spells == [&"drainerbolt", &"netherbolt", &"feeblebolt", &"invocation"] and adviser.description.contains("睿智"), "赫造基 casts the four (睿智, 默认)")
	var veteran: NpcDefinition = catalog.npc(&"canyon.npc.guard2")
	_check(veteran.talk().chat_chance == 15 and veteran.description.contains("这\n里的守军"), "老兵 chats (这里)")
	_check(veteran.talk().inquiry_topics() == ["黄石隘口", "后备兵", "军火库"] and catalog.npc(&"canyon.npc.leader2").talk().inquiry_topics() == ["黄石隘口", "后备兵"], "老兵's and 老队长's topics")
	_check(general.talk().inquiry_topics() == ["黄石隘口", "后备兵", "兵器库", "印鉴", "信", "程不平", "印鉴丢过", "关北"] and catalog.npc(&"canyon.npc.adviser").talk().inquiry_topics() == ["兵器库", "印鉴", "拓模"] and catalog.npc(&"canyon.npc.seller").talk().inquiry_topics() == ["印色"], "严廷殷 asks for his 印鉴 to be found, then 关北 A's letter topics after the LPC's four; 赫造基 on the 兵器库 and the mould; the 后备兵 on the 印色 (DECISIONS「关北 A」)")
	_check(catalog.npc(&"canyon.npc.vice_general").talk().has_greeting(), "李信 greets (throws out) the unlisted")
	var hat: ItemContentDefinition = catalog.item(&"es2:d/canyon/npc/obj/hat")
	_check(hat.display_name == "迷幻经纶" and hat.armor_definition() != null, "迷幻经纶: worn on the head")
	_check(catalog.item(&"es2:d/canyon/npc/obj/broken_sword").weapon_damage == 65, "破残奇剑: 65 damage")


func _test_arts() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	for id: StringName in [&"six-chaos-sword", &"celestial", &"pyrobat-steps", &"celestrike", &"necromancy", &"taoism", &"gouyee"]:
		_check(catalog.skill(id) != null, "%s is ported (水烟阁, 茅山)" % id)
	_check(catalog.skill(&"celestial").exert_functions.has(&"powerup"), "天邪神功's powerup")


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


func _check(condition: bool, message: String) -> void:
	_count += 1
	if not condition:
		_failures.append("canyon npcs: " + message)
