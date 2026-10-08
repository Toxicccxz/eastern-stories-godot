extends RefCounted

## 青石村's villagers: what create() draws (apply/dodge, coins, kid4's gender, worker2's
## hammer or rope, kid2's attitude on each spar), the chat functions as data (oldman2's sigh
## and 国之将亡, kid4's lines) and in a fight: woman1's 菜刀 and her age line, the old
## couple's ask_for_help() bringing the other in to kill the player. TEST-ONLY fixtures are
## marked.
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const SouthRoad := preload("res://tests/runtime/snow_south_road_test.gd")
const Specials := preload("res://tests/runtime/combat_specials_test.gd")
const KNIFE: StringName = &"es2:d/green/npc/obj/knife"
const HAMMER: StringName = &"es2:d/green/obj/hammer"
const ROPE: StringName = &"es2:d/green/obj/rope"
const COIN: StringName = &"es2:obj/money/coin"

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_definitions()
	var session: WorldSessionController = Work.create_session(tree)
	await tree.process_frame
	session.set_process(false)
	session.configure_npc_ambience_random_source(SouthRoad.Still.new()) # TEST-ONLY: nobody chats or wanders
	var village: WorldMapController = session.world_map_of(&"green.village")
	_test_created(session, village)
	await _test_attitude(tree, session)
	await _test_woman(tree, session)
	await _test_old_couple(tree, session)
	session.free()
	await tree.process_frame
	return {"assertions": _count, "failures": _failures}


func _test_definitions() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var kid2: NpcDefinition = catalog.npc(&"green.npc.kid2")
	_check(kid2.attitude_roll() != null and kid2.attitude_roll().pick(24) == "peaceful" and kid2.attitude_roll().pick(25) == "friendly", "kid2: random(50) < 25 peaceful, else friendly")
	_check(kid2.apply_rolls()[&"dodge"].admits(3) and kid2.apply_rolls()[&"dodge"].admits(4) and not kid2.apply_rolls()[&"dodge"].admits(5), "kid2's dodge 3 + random(2)")
	_check(catalog.npc(&"green.npc.kid4").gender_roll().resolve(Fixed.new(20)) == "女性" and catalog.npc(&"green.npc.kid4").gender_roll().resolve(Fixed.new(21)) == "男性", "kid4: random(50) > 20 a boy")
	var choice: NpcLoadoutEntry = catalog.npc(&"green.npc.worker2").loadout_entries()[2]
	_check(choice.is_choice() and choice.chosen(40).item_definition_id == ROPE and choice.chosen(41).item_definition_id == HAMMER and choice.chosen(41).equipment_intent == NpcLoadoutEntry.EquipmentIntent.WIELD_PRIMARY, "worker2: random(50) > 40 wields a hammer, else a rope")
	var talk: NpcTalk = catalog.npc(&"green.npc.oldman2").talk()
	_check(talk.chat_chance == 10 and talk.chat_entries() == [NpcTalk.SILENT_EMOTE, "村长说道：国之将亡.....\n"], "村长: the sigh (nothing shows) and 国之将亡")
	_check(talk.answer("玉佩").size() == 6 and talk.answer("玉佩")[5] == "造孽啊........\n", "his 玉佩 story: the strings ask.c says")
	var woman: Array = catalog.npc(&"green.npc.woman1").talk().combat_chat_entries()
	_check(woman.size() == 2 and woman[0] is NpcFightChat.Wield and (woman[0] as NpcFightChat.Wield).combat_chance == 10 and woman[1] is NpcFightChat.SayByAge, "woman1: wield_weapon(), converse_one()")
	var by_age: NpcFightChat.SayByAge = woman[1]
	_check(by_age.says(14, 30) == ["死小孩, 专们欺负老人家!"] and by_age.says(30, 30) == ["以大欺小啊你..."], "younger than her: 死小孩; else 以大欺小")
	var old: Array = catalog.npc(&"green.npc.oldman").talk().combat_chat_entries()
	_check(old[0] is NpcFightChat.CallPartner and (old[0] as NpcFightChat.CallPartner).partner_id == &"green.npc.oldwoman" and old[1] is NpcFightChat.Wield, "老公公: ask_for_help() (the old woman), wield_something()")
	_check(catalog.npc(&"green.npc.kid4").talk().chat_entries().size() == 3, "kid4 peers at the door and talks")


func _test_created(session: WorldSessionController, village: WorldMapController) -> void:
	var hammers: int = 0
	var ropes: int = 0
	for npc: NpcRuntimeState in village.resident_npcs():
		var id: StringName = npc.definition().definition_id
		var dodge: int = npc.character_state.applies.get("dodge", -1)
		match id:
			&"green.npc.worker2":
				_check(dodge >= 10 and dodge <= 14, "a quarry worker's dodge 10 + random(5): %d" % dodge)
				var held: StringName = npc.character_state.equipment.primary_weapon().weapon_id if not npc.character_state.equipment.is_primary_hand_empty() else &""
				var rope: bool = _carries(session, npc, ROPE)
				_check((held == HAMMER) != rope, "a hammer in hand or a rope, never both: %s %s" % [held, rope])
				hammers += 1 if held == HAMMER else 0
				ropes += 1 if rope else 0
			&"green.npc.kid2":
				_check(dodge >= 3 and dodge <= 4, "kid2's dodge: %d" % dodge)
				var coins: int = _coins(session, npc)
				_check(coins >= 5 and coins <= 14, "kid2's coins 5 + random(10): %d" % coins)
			&"green.npc.kid3":
				_check(dodge >= 3 and dodge <= 5 and _coins(session, npc) >= 10 and _coins(session, npc) <= 19, "kid3's dodge and coins")
			&"green.npc.woman1":
				_check(dodge >= 10 and dodge <= 14 and _carries(session, npc, KNIFE) and npc.character_state.equipment.is_primary_hand_empty(), "a woman: her 菜刀 carried, not in hand")
			&"green.npc.worker1":
				_check(npc.character_state.equipment.primary_weapon().weapon_id == HAMMER and dodge == -1, "the 工匠 wields his hammer; his dodge 10 is fixed (apply)")
	_check(hammers + ropes == 5, "five quarry workers: %d hammers, %d ropes" % [hammers, ropes])
	var kids: Array[NpcRuntimeState] = []
	for npc: NpcRuntimeState in session.world_map_of(&"green.mountain").resident_npcs():
		if npc.definition().definition_id == &"green.npc.kid4":
			kids.append(npc)
	_check(kids.size() == 2 and kids[0].character_state.gender in [&"男性", &"女性"] and kids[0].character_state.applies.get("dodge", 0) in [4, 5], "the cave mouth's two children")
	var worker: NpcRuntimeState = _first(village, &"green.npc.worker2")
	var hand: CombatSliceContentProfile = village.npc_combat_content(worker.character_id)
	var holding: bool = not worker.character_state.equipment.is_primary_hand_empty()
	_check(hand.is_verified_primary(worker.character_state.equipment.primary_weapon()) if holding else not hand.has_attack_skill_definition(&"hammer"), "a worker fights with what he holds (hammer, or bare hands with a rope)")


## kid2.c: query("attitude") draws again each time a spar asks.
func _test_attitude(tree: SceneTree, session: WorldSessionController) -> void:
	var map: WorldMapController = session.world_map_of(&"green.village")
	_check(session.handoff_to(&"green.village", &"green.path6", &"green.path6", &"green.path6.snow_entry").succeeded(), "TEST-ONLY: into the village")
	await tree.physics_frame
	await tree.physics_frame
	var kid: NpcRuntimeState = _first(map, &"green.npc.kid2")
	_check(map.relocate_player(&"green.path2", kid.spawn_point_id), "beside a child at the crossroads")
	await tree.physics_frame
	var hud: SharedGameplayUI = session.shared_ui()
	map.select_npc(kid.character_id)
	session.configure_world_interaction_random_source(ScriptedWorldInteractionRandomSource.new([30])) # TEST-ONLY: friendly
	map.spar_selected()
	_check(hud.log_lines()[-2].ends_with("的对手？") and not session.combat_encounter_coordinator().has_active_encounter(), "random(50) 30: friendly, he declines: %s" % [hud.log_lines().slice(-2)])
	session.configure_world_interaction_random_source(ScriptedWorldInteractionRandomSource.new([10])) # TEST-ONLY: peaceful
	map.spar_selected()
	_check(session.combat_encounter_coordinator().has_active_encounter(), "random(50) 10: peaceful, he takes it up")
	_end_fight(session)


## woman1.c in a fight: wield_weapon() once (then chat_chance_combat 10), converse_one().
func _test_woman(tree: SceneTree, session: WorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var woman: NpcRuntimeState = null
	for npc: NpcRuntimeState in map.resident_npcs():
		if npc.definition().definition_id == &"green.npc.woman1" and npc.world_location().zone_id == &"green.house0":
			woman = npc
	await _beside(tree, map, woman)
	player.state.vitality = CharacterResourceState.new(50000, 50000, 50000) # TEST-ONLY: outlast her
	map.select_npc(woman.character_id)
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	_check(map.attack_selected().outcome == CombatSliceInitiationResult.Outcome.COMPLETED, "the player attacks a woman at home")
	var bindings: Array[CombatSliceCharacterBinding] = session.encounter_combat_bindings(coordinator.active_encounter())
	var me: CombatSliceCharacterBinding = _binding(bindings, woman.character_id)
	var enemy: CombatSliceCharacterBinding = _binding(bindings, player.character_id)
	var chat := CombatNpcChat.new(coordinator._resident_npc, coordinator._npc_wield, coordinator._respect_of).with_villagers(coordinator._npc_wield_item, coordinator._age_of, coordinator._idle_partner)
	var drawn: CombatNpcChatResult = chat.beat(me, [enemy], [enemy], Specials.Pattern.new([0, 0]), SkillImprovementEffectRegistry.new())
	_check(_templates(drawn) == ["妇人说道：没见识过我的菜刀神功是吧, 接招!"], "random(100) 0, entry 0: she says it: %s" % [_templates(drawn)])
	_check(woman.character_state.equipment.primary_weapon_skill_type() == &"blade" and me.content.is_verified_primary(me.state.equipment.primary_weapon()), "and wields her 菜刀")
	_check(woman.combat_chat_chance == 10, "chat_chance_combat 10 from now on")
	_check(chat.beat(me, [enemy], [enemy], Specials.Pattern.new([9, 0]), SkillImprovementEffectRegistry.new()) == null, "random(100) 9 < 10 but the knife is in hand: nothing")
	_check(chat.beat(me, [enemy], [enemy], Specials.Pattern.new([10, 1]), SkillImprovementEffectRegistry.new()) == null, "random(100) 10 is not below 10")
	var line: String = "死小孩, 专们欺负老人家!" if player.facts.age < woman.age else "以大欺小啊你..."
	var age: CombatNpcChatResult = chat.beat(me, [enemy], [enemy], Specials.Pattern.new([0, 1]), SkillImprovementEffectRegistry.new())
	_check(_templates(age) == ["妇人说道：" + line], "converse_one() against the player's age (%d) and hers (%d): %s" % [player.facts.age, woman.age, _templates(age)])
	_end_fight(session)


## ask_for_help(): attacked to the death, the old man calls; the old woman shouts and
## comes in to kill the player; in a spar nobody comes.
func _test_old_couple(tree: SceneTree, session: WorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var man: NpcRuntimeState = _first(map, &"green.npc.oldman")
	var wife: NpcRuntimeState = _first(map, &"green.npc.oldwoman")
	await _beside(tree, map, man)
	player.state.vitality = CharacterResourceState.new(50000, 50000, 50000) # TEST-ONLY
	map.select_npc(man.character_id)
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	_check(map.attack_selected().outcome == CombatSliceInitiationResult.Outcome.COMPLETED, "the player attacks the old man")
	var bindings: Array[CombatSliceCharacterBinding] = session.encounter_combat_bindings(coordinator.active_encounter())
	var me: CombatSliceCharacterBinding = _binding(bindings, man.character_id)
	var enemy: CombatSliceCharacterBinding = _binding(bindings, player.character_id)
	var chat := CombatNpcChat.new(coordinator._resident_npc, coordinator._npc_wield, coordinator._respect_of).with_villagers(coordinator._npc_wield_item, coordinator._age_of, coordinator._idle_partner)
	var called: CombatNpcChatResult = chat.beat(me, [enemy], [enemy], Specials.Pattern.new([0, 0]), SkillImprovementEffectRegistry.new())
	_check(_templates(called) == ["老婆婆喊道: 老公我来帮你了!"] and called.joiners() == [wife.character_id], "random(100) 0, entry 0: she shouts and comes: %s" % [_templates(called)])
	session.configure_combat_random_source(Specials.Zero.new()) # TEST-ONLY: every beat chats, ask_for_help() first
	CombatEncounterCoordinator.take_aborted_total()
	coordinator.advance_scheduler(2.0)
	var encounter: CombatEncounter = coordinator.active_encounter()
	_check(encounter != null and encounter.participant_for(wife.character_id) != null, "the old woman is in the fight")
	_check(wife.relationship.lethal_target_ids().has(player.character_id), "to kill the player (kill_ob())")
	_check(CombatEncounterCoordinator.take_aborted_total() == 0, "and the fight goes on")
	_end_fight(session)


func _beside(tree: SceneTree, map: WorldMapController, npc: NpcRuntimeState) -> void:
	_check(npc != null and map.relocate_player(npc.world_location().zone_id, npc.spawn_point_id), "TEST-ONLY: beside %s" % ("?" if npc == null else npc.definition().display_name))
	await tree.physics_frame


func _carries(session: WorldSessionController, npc: NpcRuntimeState, definition_id: StringName) -> bool:
	for item_id: StringName in session.inventory_state().direct_children(ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, npc.character_id)):
		var item: ItemInstance = session.item_instance_index().resolve(item_id)
		if item != null and item.item_definition_id == definition_id:
			return true
	return false


func _coins(session: WorldSessionController, npc: NpcRuntimeState) -> int:
	for item_id: StringName in session.inventory_state().direct_children(ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, npc.character_id)):
		var item: ItemInstance = session.item_instance_index().resolve(item_id)
		if item != null and item.item_definition_id == COIN:
			return session.stack_collection().stack_state(item_id).amount
	return 0


func _end_fight(session: WorldSessionController) -> void:
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	var rounds: int = 0
	while coordinator.has_active_encounter() and rounds < 600:
		var info: CombatTacticalActionInfo = coordinator.action_infos()[0]
		coordinator.submit_player_action(CombatTacticalRequest.new(info.action_id, coordinator.active_encounter().encounter_id, session.player_runtime().character_id, info.action_id, info.category))
		coordinator.advance_scheduler(1.0)
		rounds += 1
	_check(not coordinator.has_active_encounter(), "TEST-ONLY: the player flees the fight")


func _templates(result: CombatNpcChatResult) -> Array[String]:
	var texts: Array[String] = []
	if result != null:
		for line: VisionLine in result.lines():
			texts.append(line.template)
	return texts


func _first(map: WorldMapController, definition_id: StringName) -> NpcRuntimeState:
	for npc: NpcRuntimeState in map.resident_npcs():
		if npc.definition().definition_id == definition_id:
			return npc
	return null


func _binding(bindings: Array[CombatSliceCharacterBinding], character_id: StringName) -> CombatSliceCharacterBinding:
	for binding: CombatSliceCharacterBinding in bindings:
		if binding.character_id == character_id:
			return binding
	return null


## An NPC-creation source that always draws `value`.
class Fixed extends NpcInitializationRandomSource:
	var _value: int

	func _init(value: int) -> void:
		_value = value

	func next_below(_bound: int) -> int:
		return _value


func _check(ok: bool, label: String) -> void:
	_count += 1
	if not ok:
		_failures.append(label)
