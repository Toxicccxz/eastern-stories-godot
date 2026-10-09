extends RefCounted

## 山烟寺 A (d/sanyen, u/cloud/npc/monk_guard.c): the monks and what they fight with. The
## kinds as imported (玄智和尚 from daemon/class/bonze, the 护寺武僧 of the repaired yard),
## their refusals by the challenger's class (accept_fight rules `class`), 流云杖法 and 莲华心法,
## 化缘和尚 in 绮云镇 fought at last, and npc.c random_move() in a fight: go.c's 落荒而逃, the
## fight goes on without it and it is where it went once the fight is over. TEST-ONLY
## fixtures are marked.
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const SouthRoad := preload("res://tests/runtime/snow_south_road_test.gd")
const MASTER: StringName = &"common.npc.bonze.master"
const MONK: StringName = &"sanyen.npc.monk"
## The maps the fights walk, with where the player stands at first.
const MAPS: Array = [
	[&"sunhill.mountain", &"sanyen.gate", &"sanyen.gate.temple_return"],
	[&"sanyen.grounds", &"sanyen.front_yard", &"sanyen.front_yard.gate_arrival"],
	[&"cloud.outdoor", &"cloud.monky", &"cloud.monky.monk.1"],
]
const KINDS: Array[StringName] = [
	&"sanyen.npc.greeting", &"cloud.npc.monk_guard", MONK, &"sanyen.npc.bonze", MASTER, &"sanyen.npc.cripple",
	&"sanyen.npc.drug_bonze", &"sanyen.npc.cook_bonze", &"sanyen.npc.little_bonze", &"sanyen.npc.work_bonze", &"cloud.npc.monk",
]


## Every draw 0: the NPC's chat always speaks and random_move() takes the first exit.
class Zeros:
	extends CombatRandomSource

	func next_below(_exclusive_upper_bound: int) -> int:
		return 0


var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_people()
	_test_refusals()
	_test_arts()
	_test_walk_out_chat()
	var session: WorldSessionController = Work.create_session(tree)
	await tree.process_frame
	session.set_process(false)
	session.configure_npc_ambience_random_source(SouthRoad.Still.new()) # TEST-ONLY: nobody chats or wanders
	await _test_walk_out_fight(tree, session)
	await _test_walk_out_leaves_the_rest(tree, session)
	await _test_fights(tree, session)
	session.free()
	await tree.process_frame
	return {"assertions": _count, "failures": _failures}


func _test_people() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	for id: StringName in KINDS:
		var npc: NpcDefinition = catalog.npc(id)
		_check(npc != null and not npc.dealings().is_fight_deferred(), "%s can be fought" % id)
	var master: NpcDefinition = catalog.npc(MASTER)
	_check(master.display_name == "玄智和尚" and master.class_id == &"bonze" and master.skill_map().get(&"magic") == &"essencemagic" and master.skill_map().get(&"parry") == &"cloudstaff", "玄智: staff and parry 流云杖法, force 莲华心法, magic 八识神通")
	var guard: NpcDefinition = catalog.npc(&"cloud.npc.monk_guard")
	_check(guard.display_name == "护寺武僧" and guard.description.begins_with("    知客僧伫立在佛像前"), "the 护寺武僧's look, copied from a 知客僧, word for word")
	var monk_talk: NpcTalk = catalog.npc(MONK).talk()
	_check(monk_talk.combat_chat_chance == 30 and monk_talk.combat_chat_entries() == [NpcTalk.RANDOM_MOVE, NpcTalk.SILENT_EMOTE], "独眼头陀: 30, random_move or hehe")
	var cripple_talk: NpcTalk = catalog.npc(&"sanyen.npc.cripple").talk()
	_check(cripple_talk.combat_chat_chance == 20 and cripple_talk.combat_chat_entries() == [NpcTalk.RANDOM_MOVE, NpcTalk.SILENT_EMOTE], "跛僧人: 20, random_move or sigh")
	var targets: Array[String] = []
	for id: StringName in KINDS:
		targets.append(catalog.npc(id).display_name)
	for name: String in ["知客僧", "扫地僧", "药僧", "跛僧人", "独眼头陀", "护寺武僧", "化缘和尚"]:
		_check(targets.has(name), "朱鸿雪's %s stands" % name)


## accept_fight(): the monks answer a monk otherwise (`class`); the 护寺武僧 takes both on.
func _test_refusals() -> void:
	var stranger := NpcSparConsent.Challenger.new(CharacterState.GENDER_MALE, 20, &"", &"")
	var brother := NpcSparConsent.Challenger.new(CharacterState.GENDER_MALE, 20, &"bonze", &"")
	var cases: Array = [
		[MASTER, stranger, "施主既然身负绝艺，老衲佩服便是，也不必较量了。", false],
		[MASTER, brother, "阿弥陀佛！出家人戒逞强恶斗！老衲不敢违反清规。", false],
		[&"cloud.npc.monk_guard", stranger, "佛门圣地也是可随意骚扰的么！", true],
		[&"cloud.npc.monk_guard", brother, "你身为佛家弟子，竟敢违反清规！", true],
		[&"cloud.npc.monk", brother, "阿弥陀佛！出家人戒逞强恶斗！贫僧不敢违反清规。", false],
		[&"cloud.npc.monk", stranger, "施主既然身负绝艺，贫僧佩服便是，也不必较量了。", false],
		[&"sanyen.npc.greeting", stranger, "阿弥陀佛！小僧武功低微，认输便是。", false],
		[&"sanyen.npc.little_bonze", stranger, "师父! 救命啊!!  啊....不要打我..:(", false],
		[&"sanyen.npc.cook_bonze", stranger, "阿弥陀佛 !! 贫僧的菜刀是用来切菜的, 不是用来砍人的。", false],
	]
	for entry: Array in cases:
		var npc := NpcRuntimeState.new(&"x", GameContent.catalog().npc(entry[0]), &"", &"", _full_state())
		var answer: NpcSparConsent = NpcSparConsent.decide(npc, entry[1])
		_check(answer.accepted == entry[3] and answer.lines.size() == 1 and answer.lines[0].text == entry[2], "%s to %s: %s" % [entry[0], entry[1].class_id, entry[2]])


func _test_arts() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var staff: SkillDefinition = catalog.skill(&"cloudstaff")
	_check(staff != null and staff.display_name == "流云杖法" and staff.can_enable_for(&"staff") and staff.can_enable_for(&"parry") and staff._actions.size() == 4, "流云杖法: staff and parry, four moves")
	var lotus: SkillDefinition = catalog.skill(&"lotusforce")
	_check(lotus != null and lotus.display_name == "莲华心法" and lotus.can_enable_for(&"force") and lotus.exert_functions.has(&"heal"), "莲华心法: a force with 疗伤")
	for id: StringName in [&"buddhism", &"chanting", &"essencemagic"]:
		_check(catalog.skill(id) != null and catalog.skill(id).skill_type == SkillDefinition.Type.KNOWLEDGE, "%s is a knowledge" % id)
	_check(catalog.skill(&"essencemagic").can_enable_for(&"magic"), "八识神通 enables as 法术")


## npc.c random_move() in a fight through go.c: 往<dir>落荒而逃了。 and where it went; a go
## that fails says nothing.
func _test_walk_out_chat() -> void:
	var monk := NpcRuntimeState.new(&"monk", GameContent.catalog().npc(MONK))
	var chat := CombatNpcChat.new(func(id: StringName) -> NpcRuntimeState: return monk if id == &"monk" else null).with_leaving(
		func(_id: StringName, _draw: Callable) -> NpcRandomMove.Move: return NpcRandomMove.Move.new("north", &"sanyen.temple"))
	var actor := CombatSliceCharacterBinding.new(&"monk", _full_state(), CombatRelationshipState.new(&"monk"), ActionBusyState.new(), ArmorState.new(), CombatSliceContentProfile.new(), &"here")
	var said: CombatNpcChatResult = chat._walk_out(actor, monk, Zeros.new())
	_check(said != null and said.lines()[0].template == "独眼头陀往北落荒而逃了。" and said.departure_zone_id() == &"sanyen.temple", "独眼头陀往北落荒而逃了。")
	var stuck := CombatNpcChat.new(func(_id: StringName) -> NpcRuntimeState: return monk).with_leaving(
		func(_id: StringName, _draw: Callable) -> NpcRandomMove.Move: return null)
	_check(stuck._walk_out(actor, monk, Zeros.new()) == null, "a go that fails: nothing")
	var catalog: ContentCatalog = GameContent.catalog()
	var move: NpcRandomMove.Move = NpcRandomMove.choose_with(catalog, &"sanyen.road1", &"sanyen.road1", func(_n: int) -> int: return 0, func(_a: StringName, _b: StringName) -> bool: return false)
	_check(move != null and move.direction == "north" and move.to_zone_id == &"sanyen.temple", "road1.c's first exit is north, into the hall")
	_check(NpcRandomMove.choose_with(catalog, &"sanyen.road1", &"sanyen.road1", func(_n: int) -> int: return 0, func(_a: StringName, _b: StringName) -> bool: return true) == null, "a shut 金门 keeps him")


## A real fight with the 独眼头陀 on the flagstones: his chat walks him into the hall, the
## fight ends with nobody fallen, and he is in the hall afterwards.
func _test_walk_out_fight(tree: SceneTree, session: WorldSessionController) -> void:
	_check(session.handoff_to(&"sanyen.grounds", &"sanyen.front_yard", &"sanyen.front_yard", &"sanyen.front_yard.gate_arrival").succeeded(), "onto the temple grounds")
	await tree.physics_frame
	var map: WorldMapController = session.active_map() as WorldMapController
	var monk: NpcRuntimeState = _npc(map, MONK)
	var player: WorldPlayerRuntimeState = session.player_runtime()
	_full(player)
	_check(map.relocate_player(&"sanyen.road1", monk.spawn_point_id), "beside the 独眼头陀")
	await tree.physics_frame
	map.select_npc(monk.character_id)
	var original: CombatRandomSource = map.combat_random_source()
	session.configure_combat_random_source(Zeros.new()) # TEST-ONLY: his chat speaks and takes the first exit
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	_check(map.attack_selected().outcome == CombatSliceInitiationResult.Outcome.COMPLETED, "the player attacks him")
	var encounter_id: StringName = coordinator.active_encounter().encounter_id
	var rounds: int = 0
	while coordinator.has_active_encounter() and rounds < 20:
		coordinator.advance_scheduler(1.0)
		rounds += 1
	session.configure_combat_random_source(original)
	var receipt: CombatEncounterCompletionResult = coordinator.last_completion()
	_check(not coordinator.has_active_encounter() and receipt != null and receipt.succeeded() and CombatEncounterCoordinator.take_aborted_total() == 0, "the fight is over")
	_check(receipt.terminal_result.losing_side_ids().is_empty() and receipt.terminal_result.subject_participant_ids().is_empty(), "nobody fell, nobody lost")
	_check(coordinator.npc_walked_out(encounter_id), "he walked out of it")
	_check(BattleFeedbackReader.completion_text(receipt, player.life_status, false, true) == "战斗结束。", "战斗结束。, not 双方都停了手")
	var said: bool = false
	for event: CombatSchedulerEvent in coordinator.completed_feedback().ordinary_after(0):
		if event.chat != null:
			for line: VisionLine in event.chat.lines():
				said = said or line.template == "独眼头陀往北落荒而逃了。"
	_check(said, "told in the fight: 独眼头陀往北落荒而逃了。")
	_check(monk.world_location().zone_id == &"sanyen.temple" and monk.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE, "he stands in the hall: %s" % monk.world_location().zone_id)
	_check(not monk.relationship.is_fighting() and not player.relationship.is_fighting(), "neither fights the other")
	_check(map.return_home(monk) and monk.world_location().zone_id == &"sanyen.road1", "the room's reset calls him home")
	await tree.physics_frame


## Two against the player, one walks out: the fight goes on against the other, the one who
## left is in the hall at once (a roar no longer reaches him, the battle panel drops him);
## when the second walks out too, the fight ends and reads 战斗结束。.
func _test_walk_out_leaves_the_rest(tree: SceneTree, session: WorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var monk: NpcRuntimeState = _npc(map, MONK)
	var cripple: NpcRuntimeState = _npc(map, &"sanyen.npc.cripple")
	var player: WorldPlayerRuntimeState = session.player_runtime()
	_full(player)
	_check(map.relocate_player(&"sanyen.road1", monk.spawn_point_id), "beside the 独眼头陀 again")
	await tree.physics_frame
	cripple.set_world_location(map.location_for_zone(&"sanyen.road1")) # TEST-ONLY: the 跛僧人 stands on the flagstones
	map.select_npc(monk.character_id)
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	var original: CombatRandomSource = map.combat_random_source()
	_check(map.attack_selected().outcome == CombatSliceInitiationResult.Outcome.COMPLETED, "the player attacks the 独眼头陀")
	var encounter: CombatEncounter = coordinator.active_encounter()
	var resolution: CombatEncounterResolution = coordinator._resolution
	var joins: Array[CombatJoin] = [CombatJoin.new(cripple.character_id, [player.character_id] as Array[StringName])]
	resolution.admit(session.encounter_combat_bindings(encounter), CombatTacticalExecutionResult.new(CombatTacticalExecutionResult.Outcome.APPLIED).with_joins(joins)) # TEST-ONLY: he joins as ask_for_help() would bring him
	_check(encounter.participant_for(cripple.character_id) != null and cripple.relationship.has_opponent(player.character_id), "the 跛僧人 joins against the player")
	resolution.depart(session.encounter_combat_bindings(encounter), monk.character_id, &"sanyen.temple") # TEST-ONLY: as his chat's random_move would
	_check(monk.world_location().zone_id == &"sanyen.temple" and not monk.relationship.is_fighting() and not player.relationship.has_opponent(monk.character_id), "the 头陀 is out of the fight and in the hall at once")
	var room: Array[SpecialSide] = map.combat_lifecycle.exert_room(player.character_id, session.encounter_combat_bindings(encounter))
	_check(room.all(func(side: SpecialSide) -> bool: return side.character_id != monk.character_id) and room.any(func(side: SpecialSide) -> bool: return side.character_id == cripple.character_id), "a roar reaches the 跛僧人, not him")
	var shown: Array[StringName] = []
	for card: BattleParticipantProjection in BattleProjectionBuilder.build(session).participants():
		shown.append(card.participant_id)
	_check(not shown.has(monk.character_id) and shown.has(cripple.character_id), "the battle panel drops him: %s" % [shown])
	coordinator.advance_scheduler(1.0)
	_check(coordinator.has_active_encounter() and coordinator.active_encounter() == encounter, "the fight goes on against the 跛僧人")
	session.configure_combat_random_source(Zeros.new()) # TEST-ONLY: the 跛僧人's chat walks him out north
	var rounds: int = 0
	while coordinator.has_active_encounter() and rounds < 20:
		coordinator.advance_scheduler(1.0)
		rounds += 1
	session.configure_combat_random_source(original)
	var receipt: CombatEncounterCompletionResult = coordinator.last_completion()
	_check(not coordinator.has_active_encounter() and receipt.succeeded() and coordinator.npc_walked_out(encounter.encounter_id), "he walks out too, and that ends it")
	_check(cripple.world_location().zone_id == &"sanyen.temple", "the 跛僧人 in the hall: %s" % cripple.world_location().zone_id)
	_check(map.return_home(monk) and map.return_home(cripple), "both called home")
	await tree.physics_frame


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
	_check(map.relocate_player(npc.world_location().zone_id, npc.spawn_point_id), "beside %s" % name)
	await tree.physics_frame
	map.select_npc(npc.character_id)
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	CombatEncounterCoordinator.take_aborted_total()
	_check(map.attack_selected().outcome == CombatSliceInitiationResult.Outcome.COMPLETED, "the player attacks %s" % name)
	coordinator.advance_scheduler(30.0)
	_check(CombatEncounterCoordinator.take_aborted_total() == 0, "%s: thirty seconds of fighting without a stop" % name)
	var rounds: int = 0
	while coordinator.has_active_encounter() and rounds < 600:
		var info: CombatTacticalActionInfo = coordinator.action_infos()[0]
		coordinator.submit_player_action(CombatTacticalRequest.new(info.action_id, coordinator.active_encounter().encounter_id, player.character_id, info.action_id, info.category))
		coordinator.advance_scheduler(1.0)
		rounds += 1
	_check(not coordinator.has_active_encounter() and CombatEncounterCoordinator.take_aborted_total() == 0, "TEST-ONLY: away from %s" % name)


func _full(player: WorldPlayerRuntimeState) -> void:
	player.state.vitality = CharacterResourceState.new(1000000, 1000000, 1000000) # TEST-ONLY: nobody dies here
	player.state.essence = CharacterResourceState.new(1000000, 1000000, 1000000) # TEST-ONLY
	player.state.spirit = CharacterResourceState.new(1000000, 1000000, 1000000) # TEST-ONLY
	player.state.progression.combat_experience = 100000 # TEST-ONLY


func _npc(map: WorldMapController, definition_id: StringName) -> NpcRuntimeState:
	for npc: NpcRuntimeState in map.resident_npcs():
		if npc.definition().definition_id == definition_id and npc.exists_in_map:
			return npc
	return null


func _full_state() -> CharacterState:
	return CharacterState.new(
		CharacterBaseAttributes.new(0, 0, 0, 0, 0, 0, 30),
		CharacterResourceState.new(200, 200, 200),
		CharacterResourceState.new(200, 200, 200),
		CharacterResourceState.new(200, 200, 200),
	)


func _check(condition: bool, message: String) -> void:
	_count += 1
	if not condition:
		_failures.append("sanyen npcs: " + message)
