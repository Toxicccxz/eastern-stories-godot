extends RefCounted

## 水烟阁 A (d/waterfog, daemon/class/fighter): the 28 rooms on three maps and the
## way in from Snow's sroad5; the eleven NPC types as imported, with what they wield and
## wear; 天邪神掌, 六阴追魂剑法 and 火蝠身法; 萧辟尘's consider() (NpcWeaponMatch) in a fight;
## the 红衣武士's refusal to spar; entrance.c's valid_leave() (a weapon in hand while a
## 水烟阁武士 stands there keeps the player out of the 正厅); the signs looked at. TEST-ONLY
## fixtures are marked.
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const Finance := preload("res://tests/runtime/snow_finance_test.gd")
const SouthRoad := preload("res://tests/runtime/snow_south_road_test.gd")
const Specials := preload("res://tests/runtime/combat_specials_test.gd")
const LONGSWORD: StringName = &"es2:obj/longsword"
const MASTER: StringName = &"common.npc.fighter.master"
const CHAMPION: StringName = &"common.npc.fighter.champion"
const EXECUTIONER: StringName = &"common.npc.fighter.executioner"
const ROOMS: Array[String] = [
	"sroad1", "sroad2", "sroad3", "stair1", "stair2", "stair3", "stair4", "clifftop", "stair5",
	"frontyard", "wpath1", "wpath2", "wpath3", "wpath4", "wpath5", "swordtomb", "entrance",
	"guildhall", "westhall", "easthall", "weststair", "eaststair", "storage", "servroom",
	"kitchen", "west_2f", "forehall", "east_2f",
]
const ITEMS: Array[StringName] = [
	&"es2:d/waterfog/obj/guard_suit", &"es2:d/waterfog/obj/leather_boot", &"es2:d/waterfog/obj/watcher_suit",
	&"es2:d/waterfog/obj/watcher_hat", &"es2:d/waterfog/obj/red_suit", &"es2:d/waterfog/obj/red_hat",
	&"es2:d/waterfog/obj/sorrowfire", &"es2:d/waterfog/obj/iron_staff", &"es2:daemon/class/fighter/houndbane",
	&"es2:daemon/class/fighter/soulimpaler", &"es2:daemon/class/fighter/icy_boot", &"es2:daemon/class/fighter/icy_girth",
	&"es2:daemon/class/fighter/icy_cloth", &"es2:daemon/class/fighter/icy_ribbon",
]

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_data()
	_test_weapon_match()
	_test_exit_rule()
	var session: OldPineWorldSessionController = Work.create_session(tree)
	await tree.process_frame
	session.set_process(false)
	session.configure_npc_ambience_random_source(SouthRoad.Still.new()) # TEST-ONLY: nobody chats or wanders
	_test_the_way_in(session)
	await _test_mountain(tree, session)
	await _test_gate(tree, session)
	await _test_consider(tree, session)
	await _test_elite_guard(tree, session)
	session.free()
	await tree.process_frame
	return {"assertions": _count, "failures": _failures}


func _test_data() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var maps: Dictionary[StringName, int] = {}
	for room: String in ROOMS:
		var room_id := StringName("es2:d/waterfog/" + room)
		var zone: ZoneDefinition = catalog.zone(StringName("waterfog." + room))
		_check(catalog.room(room_id) != null and zone != null and zone.room_ids()[0] == room_id, "%s: a zone of its own" % room)
		if zone != null:
			maps[zone.map_id] = maps.get(zone.map_id, 0) + 1
	_check(maps == {&"waterfog.mountain": 16, &"waterfog.pavilion": 9, &"waterfog.upstairs": 3}, "16 rooms on the mountain, 9 on the ground floor, 3 upstairs: %s" % maps)
	_check(catalog.zone(&"waterfog.guildhall").room_ids() == [&"es2:d/waterfog/guildhall", &"es2:daemon/class/fighter/guildhall"], "the 正厅 also takes daemon/class/fighter/guildhall.c (its own copy's paths lack a slash)")
	var spawns: Dictionary[StringName, int] = {}
	for spawn: NpcSpawnDefinition in catalog.spawns():
		if String(spawn.zone_id).begins_with("waterfog."):
			spawns[spawn.npc_definition_id] = spawns.get(spawn.npc_definition_id, 0) + spawn.spawn_point_ids().size()
	_check(spawns == {
		&"waterfog.npc.guard": 4, &"waterfog.npc.watcher": 1, &"waterfog.npc.celes_tiger": 1, &"common.npc.fighter.champion": 1,
		&"common.npc.fighter.master": 1, &"common.npc.fighter.executioner": 1, &"waterfog.npc.servant": 2,
		&"waterfog.npc.elite_guard": 4, &"waterfog.npc.elder5": 1, &"waterfog.npc.elder6": 1, &"waterfog.npc.elder7": 1,
	}, "eighteen NPCs of eleven kinds; 小天邪虎 stands nowhere (no room places it): %s" % spawns)
	for item_id: StringName in ITEMS:
		_check(catalog.item(item_id) != null, "item %s" % item_id)
	_check(catalog.item(&"es2:d/waterfog/obj/guard_suit").legacy_source_paths().size() == 2, "obj and npc/obj are one item (byte-identical copies)")
	var master: NpcDefinition = catalog.npc(MASTER)
	_check(master.display_name == "萧辟尘" and master.teaching().family_name == "天邪派" and master.teaching().family_generation == 16, "萧辟尘: 天邪派's sixteenth generation")
	_check(master.skill_map().get(&"sword") == &"six-chaos-sword" and master.skill_map().get(&"unarmed") == &"celestrike" and master.skill_map().get(&"dodge") == &"pyrobat-steps", "he fights with 六阴追魂剑法, 天邪神掌 and 火蝠身法")
	var entries: Array = master.talk().combat_chat_entries()
	_check(master.talk().combat_chat_chance == 80 and entries.size() == 3 and entries[0] is NpcWeaponMatch and (entries[0] as NpcWeaponMatch).weapon_type == &"sword", "chat_msg_combat: consider(), powerup, recover")
	var guard_rules: Array[NpcFightRule] = catalog.npc(&"waterfog.npc.elite_guard").fight_rules()
	_check(guard_rules.size() == 1 and not guard_rules[0].accept and guard_rules[0].say == "这位$RESPECT，在下正在执行勤务，恕不奉陪。", "the 红衣武士 is on duty: no spar")
	_check(not catalog.npc(&"waterfog.npc.celes_tiger").can_speak(), "天邪虎: a beast (bite, claw), not asked to spar")
	var celestrike: SkillDefinition = catalog.skill(&"celestrike")
	_check(celestrike.display_name == "天邪神掌" and celestrike.action_set().size() == 7 and celestrike.action_set().action_at(6).force_percent == 320, "天邪神掌: seven moves, 气撼九重天 force 320")
	var six: SkillDefinition = catalog.skill(&"six-chaos-sword")
	_check(six.display_name == "六阴追魂剑法" and six.action_set().size() == 6 and six.action_set().action_at(0).damage_percent == 170 and six.can_enable_for(&"parry"), "六阴追魂剑法: six moves, 群魔乱舞 damage 170, enabled for parry too")
	var bat: SkillDefinition = catalog.skill(&"pyrobat-steps")
	_check(bat.display_name == "火蝠身法" and bat.dodge_messages.size() == 5 and bat.can_enable_for(&"move"), "火蝠身法: five dodges")
	for basic: StringName in [&"staff", &"throwing", &"perception"]:
		_check(catalog.skill(basic) != null and catalog.skill(basic).kind == SkillDefinition.Kind.BASIC, "basic %s" % basic)
	var sign: WorldLandmarkDefinition = catalog.landmark(&"waterfog.guildhall.landmark.sign")
	_check(sign != null and sign.is_valid() and sign.policy == &"look" and sign.action_label.is_empty() and sign.portal_ids().is_empty() and sign.description.begins_with("要成为一名武者并不难"), "the 正厅's sign: looked at, nothing to do")
	_check(catalog.landmark(&"waterfog.swordtomb.landmark.monolith").description.contains("风波剑神黎红药前辈葬剑于此"), "葬剑亭's monolith")
	var rules: Array[ZoneExitRuleDefinition] = catalog.exit_rules_between(&"waterfog.entrance", &"waterfog.guildhall")
	_check(rules.size() == 1 and rules[0].present_npc_id == &"waterfog.npc.guard" and rules[0].lines == ["水烟阁武士喝道：慢著，进水烟阁，先放下你的兵刃！", "水烟阁武士挡住了你的去路。"], "entrance.c's valid_leave(), north only")
	_check(catalog.exit_rules_between(&"waterfog.guildhall", &"waterfog.entrance").is_empty(), "nothing stops the way out")


## consider(): an armed enemy standing and no weapon: the says, wield; none armed and a
## weapon: put away; an armed enemy lying down does not count.
func _test_weapon_match() -> void:
	var rule: NpcWeaponMatch = (GameContent.catalog().npc(MASTER).talk().combat_chat_entries()[0] as NpcWeaponMatch)
	var Enemy := NpcWeaponMatch.Enemy
	var wield: NpcWeaponMatch.Decision = rule.decide([Enemy.new(true, false, "壮士"), Enemy.new(true, true, "姑娘")], false)
	_check(wield.change == NpcWeaponMatch.Change.WIELD and wield.says == ["姑娘既然使兵刃，在下空手接招未免不敬。", "进招吧！"], "the first armed enemy: %s" % [wield.says])
	_check(rule.decide([Enemy.new(true, true, "姑娘")], true).change == NpcWeaponMatch.Change.NONE, "armed against an armed enemy: nothing")
	var down: NpcWeaponMatch.Decision = rule.decide([Enemy.new(false, true, "姑娘")], true)
	_check(down.change == NpcWeaponMatch.Change.UNWIELD and down.says == ["既然姑娘不使兵刃，在下自然奉陪！"], "an armed enemy lying down is not armed (living()): %s" % [down.says])
	var two: NpcWeaponMatch.Decision = rule.decide([Enemy.new(true, false, "壮士"), Enemy.new(true, false, "姑娘")], true)
	_check(two.change == NpcWeaponMatch.Change.UNWIELD and two.says == ["嗯... 既然二位都是空手，在下理当奉陪！"], "two bare-handed enemies: chinese_number(2): %s" % [two.says])
	_check(rule.decide([Enemy.new(true, false, "壮士")], false).change == NpcWeaponMatch.Change.NONE, "both bare-handed: nothing")
	_check(rule.decide([], true).change == NpcWeaponMatch.Change.NONE, "no enemy: nothing")


func _test_exit_rule() -> void:
	var rule: ZoneExitRuleDefinition = GameContent.catalog().exit_rules_between(&"waterfog.entrance", &"waterfog.guildhall")[0]
	_check(rule.refuses(true, true) and not rule.refuses(false, true) and not rule.refuses(true, false), "a weapon in hand and a guard present, both needed")


func _test_the_way_in(session: OldPineWorldSessionController) -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var west: PortalDefinition = catalog.portal(&"snow.sroad5.west")
	var east: PortalDefinition = catalog.portal(&"waterfog.sroad1.east")
	_check(west != null and west.source_zone_id == &"snow.sroad5" and west.destination_zone_id == &"waterfog.sroad1" and west.legacy_command == "west", "sroad5 west to the 青石官道")
	_check(east != null and east.destination_zone_id == &"snow.sroad5" and east.destination_spawn_point_id == &"snow.sroad5.waterfog_return", "and back east")
	var snow: WorldMapController = session.resident_map(&"snow.outdoor") as WorldMapController
	_check(snow.spawn_matches_zone(&"snow.sroad5.waterfog_return", &"snow.sroad5"), "Snow's return marker inside sroad5")
	var mountain: WorldMapController = session.world_map_of(&"waterfog.mountain")
	_check(mountain != null and mountain.spawn_matches_zone(&"waterfog.sroad1.snow_entry", &"waterfog.sroad1") and mountain.spawn_matches_zone(&"waterfog.frontyard.gate_return", &"waterfog.frontyard"), "the mountain's arrival markers")


## The mountain: the stone tablet beside wpath2 is only looked at.
func _test_mountain(tree: SceneTree, session: OldPineWorldSessionController) -> void:
	_check(session.handoff_to(&"waterfog.mountain", &"waterfog.sroad1", &"waterfog.sroad1", &"waterfog.sroad1.snow_entry").succeeded(), "on the 青石官道")
	await tree.physics_frame
	await tree.physics_frame
	var map: WorldMapController = session.active_map() as WorldMapController
	var hud: SharedGameplayUI = session.shared_ui()
	_check(map.map_id() == &"waterfog.mountain" and map.resident_npcs().size() == 4, "two guards at the stairs' foot, the 司事 and the 天邪虎 at the pavilion")
	_check(map.select_landmark(&"waterfog.wpath2.landmark.stone"), "the stone tablet selected")
	hud.refresh_live_state()
	_check(not hud.portal_action_is_enabled(), "nothing to do with it but look")
	map.inspect_selected()
	_check(hud.inspection_text.text.begins_with("石碑\n石碑上面几个苍劲古朴的字写道：虹谷石台"), "查看 reads item_desc: " + hud.inspection_text.text)
	hud.dismiss_current_panel()


## entrance.c valid_leave(): north with a weapon in hand while a 水烟阁武士 stands there.
func _test_gate(tree: SceneTree, session: OldPineWorldSessionController) -> void:
	_check(session.handoff_to(&"waterfog.pavilion", &"waterfog.entrance", &"waterfog.entrance", &"waterfog.entrance.yard_arrival").succeeded(), "in the 正门")
	await tree.physics_frame
	await tree.physics_frame
	var map: WorldMapController = session.active_map() as WorldMapController
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var hud: SharedGameplayUI = session.shared_ui()
	var sword: StringName = _give(session, LONGSWORD)
	session.wield_player_item(sword)
	_check(not player.state.equipment.is_primary_hand_empty(), "TEST-ONLY: a long sword in hand")
	var hall: WorldPhysicalZoneArea2D = map.physical_zone(&"waterfog.guildhall")
	var door: Rect2 = map.physical_zone(&"waterfog.entrance").global_rect()
	map.runtime_player_body().global_position = Vector2(door.get_center().x, door.position.y - 8) # just past the edge
	_check(not map.accept_zone_presence(hall), "valid_leave() returns 0")
	_check(player.world_location().zone_id == &"waterfog.entrance" and door.grow(-19).has_point(map.runtime_player_body().global_position), "the player stays in the 正门, back inside its edge")
	_check(hud.log_lines().slice(-2) == ["水烟阁武士喝道：慢著，进水烟阁，先放下你的兵刃！", "水烟阁武士挡住了你的去路。"], "the guard's shout, then why: %s" % [hud.log_lines().slice(-2)])
	var lines: int = hud.log_lines().size()
	map.runtime_player_body().global_position = Vector2(door.get_center().x, door.position.y - 8)
	map.accept_zone_presence(hall)
	_check(hud.log_lines().size() == lines, "a held key is told once")
	session.unwield_player_item(sword)
	_check(player.state.equipment.is_primary_hand_empty(), "the sword put away")
	map.runtime_player_body().global_position = Vector2(door.get_center().x, door.position.y - 8)
	_check(map.accept_zone_presence(hall) and player.world_location().zone_id == &"waterfog.guildhall", "bare-handed, into the 正厅")
	var masters: Array[StringName] = []
	for npc: NpcRuntimeState in map.resident_npcs():
		if npc.world_location().zone_id == &"waterfog.guildhall":
			masters.append(npc.definition().definition_id)
	_check(masters.size() == 3 and masters.has(CHAMPION) and masters.has(EXECUTIONER) and masters.has(MASTER), "於兰天武, 萧辟尘 and 潘军禅 in the 正厅: %s" % [masters])
	var champion: NpcRuntimeState = _first(map, CHAMPION)
	var executioner: NpcRuntimeState = _first(map, EXECUTIONER)
	var master: NpcRuntimeState = _first(map, MASTER)
	_check(champion.character_state.equipment.primary_weapon_skill_type() == &"blade" and executioner.character_state.equipment.primary_weapon_skill_type() == &"sword", "妖刀狗屠 and 邪剑穿灵 in hand")
	_check(master.character_state.equipment.is_primary_hand_empty(), "萧辟尘 carries his long sword, not wielded")
	_check(map.select_landmark(&"waterfog.guildhall.landmark.sign"), "the 樟木匾")
	map.inspect_selected()
	_check(hud.inspection_text.text.contains("只要你加入(join)武者同盟"), "its text")
	hud.dismiss_current_panel()


## consider() in a fight: the player's sword brings his out; bare hands put it away.
func _test_consider(tree: SceneTree, session: OldPineWorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var master: NpcRuntimeState = _first(map, MASTER)
	var sword: StringName = _carried(session, player.character_id, LONGSWORD)
	session.wield_player_item(sword)
	_check(not player.state.equipment.is_primary_hand_empty(), "the long sword again")
	_check(map.relocate_player(&"waterfog.guildhall", master.spawn_point_id), "beside 萧辟尘")
	await tree.physics_frame
	player.state.vitality = CharacterResourceState.new(50000, 50000, 50000) # TEST-ONLY: outlast him
	map.select_npc(master.character_id)
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	_check(map.attack_selected().outcome == CombatSliceInitiationResult.Outcome.COMPLETED, "the player attacks him")
	var bindings: Array[CombatSliceCharacterBinding] = session.encounter_combat_bindings(coordinator.active_encounter())
	var me: CombatSliceCharacterBinding = _binding(bindings, master.character_id)
	var enemy: CombatSliceCharacterBinding = _binding(bindings, player.character_id)
	var chat := CombatNpcChat.new(coordinator._resident_npc, coordinator._npc_wield, coordinator._respect_of)
	var respect: String = RankWords.query_respect(player.state.gender, player.facts.age, player.state.affiliation.class_id)
	var drawn: CombatNpcChatResult = chat.beat(me, [enemy], [enemy], Specials.Pattern.new([0, 0]), SkillImprovementEffectRegistry.new())
	_check(drawn != null and _templates(drawn) == ["萧辟尘说道：%s既然使兵刃，在下空手接招未免不敬。" % respect, "萧辟尘说道：进招吧！"], "random(100) 0 < 80, entry 0: consider() speaks: %s" % [_templates(drawn)])
	_check(master.character_state.equipment.primary_weapon_skill_type() == &"sword" and me.state.equipment.primary_weapon_skill_type() == &"sword", "and wields his long sword")
	_check(chat.beat(me, [enemy], [enemy], Specials.Pattern.new([0, 0]), SkillImprovementEffectRegistry.new()) == null, "both armed: nothing more")
	# His blows are the sword's now: the fight goes on with it (no abort), its damage 25 counts.
	CombatEncounterCoordinator.take_aborted_total()
	var held: EquippedWeaponRef = master.character_state.equipment.primary_weapon()
	var armed: CombatSliceCharacterBinding = _binding(session.encounter_combat_bindings(coordinator.active_encounter()), master.character_id)
	_check(armed.content.is_verified_primary(held) and armed.content.projected_apply_damage(held) >= 25, "his binding verifies the long sword and counts its damage")
	for round: int in 12:
		if not coordinator.has_active_encounter():
			break
		coordinator.advance_scheduler(1.0)
	_check(CombatEncounterCoordinator.take_aborted_total() == 0 and coordinator.has_active_encounter() and master.character_state.equipment.primary_weapon_skill_type() == &"sword", "twelve rounds with his sword drawn: the fight goes on")
	player.state.equipment.unwield(sword) # TEST-ONLY: hands free in the fight
	var bare: CombatNpcChatResult = chat.beat(me, [enemy], [enemy], Specials.Pattern.new([0, 0]), SkillImprovementEffectRegistry.new())
	_check(bare != null and _templates(bare) == ["萧辟尘说道：既然%s不使兵刃，在下自然奉陪！" % respect], "bare-handed: he says so: %s" % [_templates(bare)])
	_check(master.character_state.equipment.is_primary_hand_empty(), "and puts it away")
	_check(chat.beat(me, [enemy], [enemy], Specials.Pattern.new([80]), SkillImprovementEffectRegistry.new()) == null, "random(100) 80 is not below 80: nothing")
	_end_fight(session)


## The 红衣武士 refuses a spar (accept_fight()).
func _test_elite_guard(tree: SceneTree, session: OldPineWorldSessionController) -> void:
	_check(session.handoff_to(&"waterfog.upstairs", &"waterfog.west_2f", &"waterfog.west_2f", &"waterfog.west_2f.stairs_arrival").succeeded(), "upstairs, west")
	await tree.physics_frame
	await tree.physics_frame
	var map: WorldMapController = session.active_map() as WorldMapController
	_check(map.resident_npcs().size() == 7, "four 红衣武士 and three elders upstairs")
	var guard: NpcRuntimeState = null
	for npc: NpcRuntimeState in map.resident_npcs():
		if guard == null and npc.definition().definition_id == &"waterfog.npc.elite_guard" and npc.world_location().zone_id == &"waterfog.west_2f":
			guard = npc
	_check(guard != null and map.select_npc(guard.character_id), "a 红衣武士 selected")
	var hud: SharedGameplayUI = session.shared_ui()
	var player: WorldPlayerRuntimeState = session.player_runtime()
	map.spar_selected()
	var respect: String = RankWords.query_respect(player.state.gender, player.facts.age, player.state.affiliation.class_id)
	_check(hud.log_lines().slice(-2) == ["水烟阁红衣武士说道：这位%s，在下正在执行勤务，恕不奉陪。" % respect, "看起来水烟阁红衣武士并不想跟你较量。"], "on duty: %s" % [hud.log_lines().slice(-2)])
	_check(not session.combat_encounter_coordinator().has_active_encounter(), "no spar")


func _end_fight(session: OldPineWorldSessionController) -> bool:
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	var rounds: int = 0
	while coordinator.has_active_encounter() and rounds < 600:
		var info: CombatTacticalActionInfo = coordinator.action_infos()[0]
		coordinator.submit_player_action(CombatTacticalRequest.new(info.action_id, coordinator.active_encounter().encounter_id, session.player_runtime().character_id, info.action_id, info.category))
		coordinator.advance_scheduler(1.0)
		rounds += 1
	_check(not coordinator.has_active_encounter(), "TEST-ONLY: the player flees the fight")
	return true


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


func _carried(session: OldPineWorldSessionController, character_id: StringName, definition_id: StringName) -> StringName:
	for item_id: StringName in session.inventory_state().direct_children(ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, character_id)):
		var item: ItemInstance = session.item_instance_index().resolve(item_id)
		if item != null and item.item_definition_id == definition_id:
			return item_id
	return &""


## TEST-ONLY: a carried item.
func _give(session: OldPineWorldSessionController, definition_id: StringName) -> StringName:
	var context: MoneyInventoryContext = Finance.session_context(session)
	var content: ItemContentDefinition = GameContent.catalog().item(definition_id)
	var allocation: SessionItemIdAllocationResult = session.item_id_allocator().allocate(context.inventory)
	var item := ItemInstance.new(allocation.item_instance_id, definition_id)
	assert(context.inventory.register_item(item, content.own_weight))
	assert(context.index.register_snapshot(item))
	var destination := InventoryTransferDestination.new(context.endpoint(), true, true, 1000000)
	assert(InventoryTransferService.new().transfer(context.inventory, item.item_instance_id, destination).succeeded)
	return item.item_instance_id


func _check(ok: bool, label: String) -> void:
	_count += 1
	if not ok:
		_failures.append(label)
