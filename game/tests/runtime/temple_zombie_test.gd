extends RefCounted

## 茅山 D: 驱尸 (necromancy/animate.c) raises a corpse as the victim's zombie (obj/npc/
## zombie.c), which follows the player across maps, lives on their atman and is left out of
## a save; 桃符纸 (obj/paper_seal.c, two in Snow's 城隍庙) take a 僵尸追魂符 with the
## selected NPC's name (cmds/std/scribe.c, haunt.c), and put on the zombie (attach.c) it
## goes after them while the player stands by, then falls apart. In the real session on
## the temple grounds and the climb. TEST-ONLY fixtures are marked.
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const SouthRoad := preload("res://tests/runtime/snow_south_road_test.gd")
const MapPlaces := preload("res://tests/support/map_places.gd")
const MASTER: StringName = &"common.npc.taoist.taolord"
const FAMILY: StringName = &"family.maoshan"
const ZOMBIE: StringName = &"common.npc.zombie"
const PAPER: StringName = &"es2:obj/paper_seal"
const XUANHE: StringName = &"temple.npc.little_taoist2"
const OLD_TAOIST: StringName = &"temple.npc.old_taoist"
const QINGXU: StringName = &"temple.npc.taoist"
const GUEST: StringName = &"temple.npc.guest"


var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_data()
	var session: WorldSessionController = (load("res://scenes/world/oldpine/oldpine_world_session.tscn") as PackedScene).instantiate()
	session.configure_source_entry("茅工", CharacterState.GENDER_MALE) # 林忌 takes men only
	session.deterministic_combat_seed = true
	session.deterministic_npc_seed = true
	session.deterministic_world_interaction_seed = true
	tree.root.add_child(session)
	await tree.process_frame
	session.set_process(false)
	session.configure_npc_ambience_random_source(SouthRoad.Still.new()) # TEST-ONLY: nobody chats or wanders
	_check(session.handoff_to(&"temple.grounds", &"temple.square", &"temple.square", &"temple.square.gate_arrival").succeeded(), "TEST-ONLY: inside the gate")
	await tree.physics_frame
	await tree.physics_frame
	_make_taoist(session)
	var first: NpcRuntimeState = await _test_animate(tree, session)
	if first != null:
		await _test_follows(tree, session, first)
		await _test_scribe(tree, session)
		await _test_attach(tree, session, first)
	var second: NpcRuntimeState = await _test_drain(tree, session)
	if second != null:
		await _test_master_question(tree, session, second)
		await _test_across_maps(tree, session, second)
		_test_dispell(session, second)
	await _test_save_leaves_it_out(tree, session)
	session.free()
	await tree.process_frame
	return {"assertions": _count, "failures": _failures}


## What the content says: the zombie, the paper, the sheets, 茅山道术's files and the two
## papers in Snow's 城隍庙.
func _test_data() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var zombie: NpcDefinition = catalog.npc(ZOMBIE)
	var raising: NpcRaising = null if zombie == null else zombie.raising()
	_check(raising != null and raising.name_template == "{name}的僵尸" and raising.drain_above == 10 and raising.drain_atman == 10 and raising.drain_gin == 1 and raising.color == ColoredLine.HIR, "zombie.c: named after its corpse, 10 atman and 1 gin a heal_up while its master has more than 10")
	_check(zombie != null and zombie.display_name == "僵尸" and zombie.summoning() == null and zombie.conjuring() == null, "its own name 僵尸; neither summoned nor conjured")
	var raised: NpcDefinition = zombie.raised_as("流氓")
	_check(raised.display_name == "流氓的僵尸" and raised.short_name() == "流氓的僵尸" and raised.definition_id == ZOMBIE, "corpse.c animate(): 流氓的僵尸")
	var paper: ItemContentDefinition = catalog.item(PAPER)
	_check(paper != null and paper.scribe and paper.is_stack and paper.unit == "叠" and paper.base_unit == "张" and paper.stack_base_weight == 5, "桃符纸: a combined item, 叠 of 张, 5 each, drawn on")
	var sheet: ItemContentDefinition = catalog.item(ItemContentDefinition.haunting_sheet_id(PAPER, OLD_TAOIST))
	var other: ItemContentDefinition = catalog.item(ItemContentDefinition.haunting_sheet_id(PAPER, QINGXU))
	_check(sheet != null and sheet.haunts == OLD_TAOIST and sheet.display_name == "僵尸追魂符（老道士）" and sheet.description == paper.description, "a 僵尸追魂符 for 老道士 on a 桃符纸")
	_check(sheet != null and other != null and sheet.stack_definition().stack_compatibility_id != other.stack_definition().stack_compatibility_id and sheet.stack_definition().stack_compatibility_id != paper.stack_definition().stack_compatibility_id, "sheets for another name do not stack, nor with blank paper")
	_check(catalog.item(ItemContentDefinition.haunting_sheet_id(PAPER, ZOMBIE)) == null, "no sheet names a raised NPC")
	var necromancy: SkillDefinition = catalog.skill(&"necromancy")
	var scribes: Array[StringName] = [&"haunt"]
	_check(necromancy.cast_functions.has(&"animate") and necromancy.scribe_functions == scribes, "茅山道术 casts animate and draws haunt")
	var spawn: ItemSpawnDefinition = catalog.item_spawn(&"snow.outdoor.temple.paper_seals")
	_check(spawn != null and spawn.item_definition_id == PAPER and spawn.zone_id == &"snow.temple" and spawn.spawn_point_ids().size() == 2, "d/snow/temple.c: two 桃符纸 in the 城隍庙")


## TEST-ONLY: 林忌's apprentice with spells and 茅山道术 10 enabled, 天师正道 20, 1000 mana,
## 300 atman, full sen.
func _make_taoist(session: WorldSessionController) -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var state: CharacterState = session.player_runtime().state
	var request := NpcApprenticeship.new()
	request.request(state, catalog.npc(MASTER), catalog.family(FAMILY), 1, "壮士")
	request.answer(state, catalog.npc(MASTER), catalog.family(FAMILY), 2, "壮士")
	state.skills.set_raw_level(&"taoism", 20)
	state.skills.set_raw_level(&"spells", 10)
	state.skills.set_raw_level(&"necromancy", 10)
	state.skills.map_skill(&"spells", &"necromancy")
	state.recovery.mana = CharacterInternalResourceState.new(1000, 1000)
	state.recovery.atman = CharacterInternalResourceState.new(300, 300)
	CharacterDerivedValues.refresh_human_player_maxima(state, session.player_runtime().facts.age)
	_full(state)
	_check(state.family.family_id == FAMILY, "TEST-ONLY: a member of 茅山派")


## 玄和 dies in the courtyard; 驱尸 on the corpse: refused without 50 mana, then its line,
## 50 mana and 30 sen, and 玄和的僵尸 stands where the corpse lay, which is gone; its robe
## and boots fall there. The battle panel never offers it.
func _test_animate(tree: SceneTree, session: WorldSessionController) -> NpcRuntimeState:
	var map: WorldMapController = session.active_map() as WorldMapController
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var hud: SharedGameplayUI = session.shared_ui()
	_check(not session.combat_encounter_coordinator().action_infos().any(func(info: CombatTacticalActionInfo) -> bool: return info.action_id == CombatCastTacticalPolicy.action_id_for(&"animate")), "no 驱尸 on the battle panel (animate.c refuses in a fight)")
	var xuanhe: NpcRuntimeState = _first(map, XUANHE)
	_check(xuanhe != null, "玄和 stands in the courtyard")
	if xuanhe == null:
		return null
	await _beside(tree, session, map, xuanhe)
	var corpse: CorpseState = _kill(map, xuanhe, player)
	_check(corpse != null and map.inventory_state().direct_children(ContainmentEndpoint.new(ContainmentEndpoint.Kind.ITEM, corpse.corpse_item_instance_id)).size() == 2, "TEST-ONLY: 玄和 died; robe and boots in his corpse")
	if corpse == null:
		return null
	var held: Array[StringName] = map.inventory_state().direct_children(ContainmentEndpoint.new(ContainmentEndpoint.Kind.ITEM, corpse.corpse_item_instance_id))
	_check(map.select_corpse(corpse.corpse_item_instance_id) and map.animatable_corpse() == corpse, "the selected corpse here may be raised")
	hud.refresh_live_state()
	_check(not hud.animate_button.disabled and hud.animate_button.text == "驱尸", "the HUD offers 驱尸")
	player.state.recovery.mana.current = 49
	var sen: int = player.state.spirit.current
	_check(not map.animate_selected_corpse() and hud.log_lines().back() == "你的法力不够了！" and map.corpses.find_corpse(corpse.corpse_item_instance_id) == corpse and player.state.spirit.current == sen, "49 mana: 你的法力不够了！, nothing paid")
	player.state.recovery.mana.current = 1000
	var before: Array[StringName] = _npc_ids(map)
	_check(map.animate_selected_corpse(), "驱尸")
	_check(hud.log_lines().back() == "你对著地上的玄和的尸体喃喃地念了几句咒语，玄和的尸体抽搐了几下竟站了起来！", "its line: %s" % hud.log_lines().back())
	_check(player.state.recovery.mana.current == 950 and player.state.spirit.current == sen - 30, "50 mana and 30 sen")
	_check(map.corpses.find_corpse(corpse.corpse_item_instance_id) == null and map.selected_interaction_target() == null, "the corpse is gone")
	var zombie: NpcRuntimeState = null
	for id: StringName in _npc_ids(map):
		if not before.has(id):
			zombie = map.find_resident_npc(id)
	_check(zombie != null and SummonedNpc.definition_id_of(zombie.character_id) == ZOMBIE and zombie.definition().display_name == "玄和的僵尸", "玄和的僵尸 stands up")
	if zombie == null:
		return null
	_check(map.summoner_of(zombie.character_id) == player.character_id and zombie.has_flag(NpcDefinition.FLAG_FOLLOWS_PLAYER) and zombie.world_location().zone_id == &"temple.inneryard", "possessed by the player, who it follows; in the courtyard")
	_check(zombie.character_state.vitality.maximum == 400 and zombie.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE, "400 kee")
	var on_floor: bool = true
	for item_id: StringName in held:
		on_floor = on_floor and map.dropped_item_ids().has(item_id) and map.dropped_item_location(item_id).zone_id == &"temple.inneryard"
	_check(on_floor, "the robe and boots fell where the corpse lay (owner: not destructed)")
	var body: WorldCharacterBody2D = map.runtime_body_for_character(zombie.character_id)
	_check(body != null and body.global_position.distance_to(map.runtime_player_body().global_position) >= 48.0, "it stands clear of the player's body")
	return zombie


## The player walks on into the 回廊 and the guest room: it walks after them (go.c's
## follow_me()), 玄和的僵尸走了过来。
func _test_follows(tree: SceneTree, session: WorldSessionController, zombie: NpcRuntimeState) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	map.npc_life._advance_ambience(0.0) # the NPCs' init() see the player in the courtyard
	for zone_id: StringName in [&"temple.corridor7", &"temple.restroom1"]:
		await _place(tree, session, map, zone_id)
		var lines: int = session.shared_ui().log_lines().size()
		map.npc_life._advance_ambience(0.0)
		_check(zombie.world_location().zone_id == zone_id and session.shared_ui().log_lines().slice(lines).has("玄和的僵尸走了过来。"), "it follows into %s: %s" % [zone_id, session.shared_ui().log_lines().slice(lines)])
	# It is still a room behind on its walk when the player goes on: it walks on from there.
	var body: WorldCharacterBody2D = map.runtime_body_for_character(zombie.character_id)
	for _frame: int in range(240):
		map.npc_life.npc_walker().advance(1.0 / 30.0)
		await tree.physics_frame
	_check(not map.npc_life.npc_walker().is_walking(zombie.character_id) and map.physical_zone(&"temple.restroom1").global_rect().has_point(body.global_position), "its body caught up into the guest room")


## Two 桃符纸; 老道士 selected: 画追魂符 refuses without 20 mana or 30 sen (nothing paid), asks
## first when its 40 sen would knock the player out, else draws one: 20 mana, 40 sen, 1 kee
## wounded, one paper becomes 僵尸追魂符（老道士）.
func _test_scribe(tree: SceneTree, session: WorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var hud: SharedGameplayUI = session.shared_ui()
	map.give_new_item_to_player(PAPER) # TEST-ONLY: two papers
	var paper_id: StringName = map.give_new_item_to_player(PAPER)
	paper_id = _carried(session, PAPER)
	_check(map.stack_collection().stack_state(paper_id).amount == 2, "TEST-ONLY: 2 张桃符纸")
	var old: NpcRuntimeState = _first(map, OLD_TAOIST)
	_check(old != null and map.select_npc(old.character_id) and map.scribable_npc() == old, "老道士 selected: his name may be written")
	hud.open_inventory()
	_check(_row_button(hud, paper_id, "Scribe") == "画追魂符：老道士", "the paper's row offers it: %s" % _row_button(hud, paper_id, "Scribe"))
	hud.close_inventory()
	player.state.recovery.mana.current = 19
	_check(not map.scribe_on(paper_id) and hud.log_lines().back() == "你的法力不够了！" and map.stack_collection().stack_state(paper_id).amount == 2, "19 mana: 你的法力不够了！")
	player.state.recovery.mana.current = 1000
	player.state.spirit.current = 29
	_check(not map.scribe_on(paper_id) and hud.log_lines().back() == "你的精神太差了，无法画符。" and player.state.recovery.mana.current == 1000, "29 sen: 你的精神太差了，无法画符。")
	player.state.spirit.current = 35
	_check(map.scribe_knocks_out(), "35 sen: drawing would knock the player out")
	hud._scribe_on(paper_id)
	_check(hud.is_asking() and hud.confirm_prompt.message.text.contains("40 点神"), "asked first: %s" % hud.confirm_prompt.message.text)
	hud.confirm_prompt.cancel()
	await tree.process_frame
	_check(map.stack_collection().stack_state(paper_id).amount == 2 and player.state.spirit.current == 35, "取消: nothing drawn")
	_full(player.state)
	player.state.vitality = CharacterResourceState.new(0, 0, player.state.vitality.maximum) # TEST-ONLY: wounded to 0 effective kee
	_check(map.scribe_kills() and not map.scribe_knocks_out(), "0 effective kee: the drop of blood would kill (eff_kee -1), sen is enough")
	hud._scribe_on(paper_id)
	_check(hud.is_asking() and hud.confirm_prompt.message.text.begins_with("你伤得太重了"), "asked first, as a death: %s" % hud.confirm_prompt.message.text)
	hud.confirm_prompt.cancel()
	await tree.process_frame
	_full(player.state)
	var sen: int = player.state.spirit.current
	var kee: int = player.state.vitality.effective
	_check(map.scribe_on(paper_id), "画追魂符")
	_check(player.state.recovery.mana.current == 980 and player.state.spirit.current == sen - 40 and player.state.vitality.effective == kee - 1, "20 mana, 10 + 30 sen, 1 kee wounded")
	_check(map.stack_collection().stack_state(paper_id).amount == 1, "one paper left")
	var sheet_id: StringName = _carried(session, ItemContentDefinition.haunting_sheet_id(PAPER, OLD_TAOIST))
	_check(not sheet_id.is_empty(), "僵尸追魂符（老道士） carried")
	_check(hud.log_lines().back() == "你咬破手指，用鲜血在桃符纸上画了一道僵尸追魂符，写上了老道士的名字。", "its line: %s" % hud.log_lines().back())
	var me := SpecialSide.new(player.character_id, player.state, player.busy, player.relationship)
	_check(ScribeService.scribe(me, &"haunt", "老道士", true, GameContent.catalog()) == "战斗时不能画符！", "scribe.c in a fight: 战斗时不能画符！")
	player.state.skills.unmap_skill(&"spells")
	_check(ScribeService.scribe(me, &"haunt", "老道士", false, GameContent.catalog()) == "你请先用 enable 指令选择你要使用的咒文系。" and map.scribable_npc() == null, "no spells enabled: refused, and not offered")
	player.state.skills.map_skill(&"spells", &"necromancy")
	_full(player.state)


## A sheet for 清虚 (not here): 这里没有清虚。, the sheet stays. The sheet for 老道士: it is
## used up, 玄和的僵尸 kill_ob()s him and stops following; he fights it back while the
## player stands by; it kills him (the player's kill: killer_reward()'s possessed) and,
## the fight over, falls apart on its next heal_up: 化为一滩血水, no corpse.
func _test_attach(tree: SceneTree, session: WorldSessionController, zombie: NpcRuntimeState) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var hud: SharedGameplayUI = session.shared_ui()
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	var old: NpcRuntimeState = _first(map, OLD_TAOIST)
	var sheet_id: StringName = _carried(session, ItemContentDefinition.haunting_sheet_id(PAPER, OLD_TAOIST))
	_check(map.sheet_carrier() == zombie, "玄和的僵尸 here takes a sheet")
	hud.open_inventory()
	_check(_row_button(hud, sheet_id, "Attach") == "贴到玄和的僵尸身上", "the sheet's row offers it: %s" % _row_button(hud, sheet_id, "Attach"))
	hud.close_inventory()
	map.give_new_item_to_player(ItemContentDefinition.haunting_sheet_id(PAPER, QINGXU)) # TEST-ONLY
	var away: StringName = _carried(session, ItemContentDefinition.haunting_sheet_id(PAPER, QINGXU))
	_check(not map.attach_sheet(away) and hud.log_lines().back() == "这里没有清虚。" and not _carried(session, ItemContentDefinition.haunting_sheet_id(PAPER, QINGXU)).is_empty() and zombie.has_flag(NpcDefinition.FLAG_FOLLOWS_PLAYER), "清虚 is not here: the sheet stays (owner)")
	var kills: int = player.state.progression.kills
	_check(map.attach_sheet(sheet_id), "贴符")
	_check(_carried(session, ItemContentDefinition.haunting_sheet_id(PAPER, OLD_TAOIST)).is_empty(), "the sheet is used up")
	_check(hud.log_lines().back() == "玄和的僵尸眼睛忽然睁开，喃喃地说道：杀....死....老道士....", "do_haunt()'s line: %s" % hud.log_lines().back())
	_check(zombie.has_flag(NpcDefinition.FLAG_SENT) and not zombie.has_flag(NpcDefinition.FLAG_FOLLOWS_PLAYER), "end_tag; it follows the player no more")
	var encounter: CombatEncounter = coordinator.active_encounter()
	_check(encounter != null and encounter.mode == CombatEncounterMode.Value.LETHAL and encounter.participant_for(player.character_id) != null, "a fight began, the player in it")
	if encounter == null:
		return
	_check(zombie.relationship.has_lethal_target(old.character_id) and old.relationship.has_opponent(zombie.character_id) and not old.relationship.has_lethal_target(zombie.character_id), "it kills him; he only fights it back")
	_check(not player.relationship.is_fighting() and not old.relationship.has_opponent(player.character_id), "the player stands by, fought by nobody")
	_check(coordinator.opening_lines(encounter.encounter_id) == ["玄和的僵尸眼睛忽然睁开，喃喃地说道：杀....死....老道士...."], "the battle log opens with it")
	# kill.c from the battle panel: the player joins in, and he kills back.
	var kill: StringName = CombatKillTacticalPolicy.ACTION_ID
	_check(coordinator.kill_target() == old.character_id and _offered(coordinator, kill), "攻击 is offered to one standing by: at 老道士")
	_check((session.get_node("BattlePresentationLayer/BattleSurface") as BattlePresentationController)._question_for(kill).is_empty(), "he is not the player's master: nothing asked")
	var submitted: CombatTacticalResult = coordinator.submit_player_action(CombatTacticalRequest.new(&"kill:1", encounter.encounter_id, player.character_id, kill, CombatTacticalRequest.Category.TACTICAL_DEFENSE))
	_check(submitted.code == CombatTacticalResult.Code.ACCEPTED, "攻击 queued: %s" % BattleFeedbackReader.reason(submitted.code))
	coordinator.advance_scheduler(0.0)
	_check(player.relationship.has_lethal_target(old.character_id) and old.relationship.has_lethal_target(player.character_id) and old.relationship.has_lethal_target(zombie.character_id) == false, "kill.c: the player kills him and he kills the player back; the zombie he only fights")
	_check(coordinator.opening_warnings(encounter.encounter_id).has("看起来老道士想杀死你！"), "kill_ob()'s warning is pinned")
	_check(not _offered(coordinator, kill) and coordinator.kill_target().is_empty(), "攻击 is gone once the player fights")
	old.character_state.vitality.current = -1 # TEST-ONLY: knocked out; one of the two finishes him
	coordinator.advance_scheduler(0.0)
	for _round: int in range(200):
		if not coordinator.has_active_encounter():
			break
		coordinator.advance_scheduler(1.0)
	_refresh(session)
	await tree.process_frame
	_check(not coordinator.has_active_encounter() and CombatEncounterCoordinator.take_aborted_total() == 0, "the fight is over: " + coordinator.last_abort_detail())
	_check(old.life_status == CharacterRuntimeLifeStatus.Value.DEAD and player.state.progression.kills == kills + 1, "老道士 died: the player's kill whoever struck last (its kills are theirs)")
	_check(coordinator.last_completion() != null and coordinator.last_completion().terminal_result.kind == CombatEncounterResultKind.Value.VICTORY, "the player's side won")
	_check(map.find_resident_npc(zombie.character_id) == zombie and zombie.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE, "it stays as the fight ends (no summoned leave)")
	map.npc_life.advance_npc_heartbeat(40.0)
	_check(map.find_resident_npc(zombie.character_id) == null and hud.log_lines().has("玄和的僵尸缓缓地倒了下来，化为一滩血水。"), "its next heal_up: it dispells")
	_check(not map.corpse_states().any(func(corpse: CorpseState) -> bool: return corpse.victim_character_id == zombie.character_id), "no corpse")


## 老道士's corpse raised: each heal_up 老道士的僵尸 tells the player it needs their power
## (HIR, wherever they are) and takes 10 atman and 1 gin.
func _test_drain(tree: SceneTree, session: WorldSessionController) -> NpcRuntimeState:
	var map: WorldMapController = session.active_map() as WorldMapController
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var hud: SharedGameplayUI = session.shared_ui()
	var corpse: CorpseState = null
	for lying: CorpseState in map.corpse_states():
		if lying.victim_display_name == "老道士":
			corpse = lying
	_check(corpse != null, "老道士's corpse lies in the guest room")
	if corpse == null:
		return null
	_full(player.state)
	var before: Array[StringName] = _npc_ids(map)
	_check(map.select_corpse(corpse.corpse_item_instance_id) and map.animate_selected_corpse(), "驱尸 again")
	var zombie: NpcRuntimeState = null
	for id: StringName in _npc_ids(map):
		if not before.has(id):
			zombie = map.find_resident_npc(id)
	_check(zombie != null and zombie.definition().display_name == "老道士的僵尸", "老道士的僵尸")
	if zombie == null:
		return null
	var atman: int = player.state.recovery.atman.current
	var gin: int = player.state.essence.current
	var lines: int = hud.log_lines().size()
	map.npc_life.advance_npc_heartbeat(40.0)
	var beats: int = map.npc_life.npc_heartbeat.heal_ups.get(zombie.character_id, 0)
	_check(beats >= 1 and player.state.recovery.atman.current == atman - 10 * beats and player.state.essence.current == gin - beats, "%d heal_up: 10 atman and 1 gin each (%d → %d)" % [beats, atman, player.state.recovery.atman.current])
	var told: Array[String] = hud.log_lines().slice(lines)
	_check(told.count("老道士的僵尸告诉你：我...需...要...你...的...力...量...") == beats, "its tell each time: %s" % [told])
	_check(map.find_resident_npc(zombie.character_id) == zombie, "it stays while fed")
	# Deviation (默认): nothing taken from a master lying unconscious (ES2's 1 gin kills them).
	player.set_life_status(CharacterRuntimeLifeStatus.Value.UNCONSCIOUS) # TEST-ONLY
	player.state.essence.current = 0
	atman = player.state.recovery.atman.current
	lines = hud.log_lines().size()
	map.npc_life.advance_npc_heartbeat(40.0)
	_check(player.state.essence.current == 0 and player.state.recovery.atman.current == atman and hud.log_lines().size() == lines and map.find_resident_npc(zombie.character_id) == zombie, "the player lies unconscious: it takes nothing, says nothing, stays")
	player.set_life_status(CharacterRuntimeLifeStatus.Value.ACTIVE)
	_full(player.state)
	await tree.process_frame
	return zombie


## A sheet for 林忌 on it in the hall: asked first, as 攻击 on one's master (弑师); 取消
## leaves all as it was.
func _test_master_question(tree: SceneTree, session: WorldSessionController, zombie: NpcRuntimeState) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var hud: SharedGameplayUI = session.shared_ui()
	await _place(tree, session, map, &"temple.temple1")
	_move(map, zombie, &"temple.temple1") # TEST-ONLY
	map.give_new_item_to_player(ItemContentDefinition.haunting_sheet_id(PAPER, MASTER)) # TEST-ONLY
	var sheet_id: StringName = _carried(session, ItemContentDefinition.haunting_sheet_id(PAPER, MASTER))
	_check(map.sheet_carrier() == zombie and map.sheet_target(sheet_id) != null, "林忌 here, the zombie here")
	hud._attach_sheet(sheet_id)
	_check(hud.is_asking() and hud.confirm_prompt.message.text.begins_with("林忌是你的师父。老道士的僵尸会追杀林忌"), "asked first: %s" % hud.confirm_prompt.message.text)
	hud.confirm_prompt.cancel()
	await tree.process_frame
	_check(not session.combat_encounter_coordinator().has_active_encounter() and zombie.has_flag(NpcDefinition.FLAG_FOLLOWS_PLAYER) and not _carried(session, ItemContentDefinition.haunting_sheet_id(PAPER, MASTER)).is_empty(), "取消: nothing happened")


## Out of the 山门 onto the climb: it comes along onto the other map beside the player
## (owner, 茅山 A), 老道士的僵尸走了过来。
func _test_across_maps(tree: SceneTree, session: WorldSessionController, zombie: NpcRuntimeState) -> void:
	var grounds: WorldMapController = session.active_map() as WorldMapController
	await _place(tree, session, grounds, &"temple.square")
	_move(grounds, zombie, &"temple.square") # TEST-ONLY
	_check(session.handoff_to(&"temple.mountain", &"temple.entrance", &"temple.entrance", &"temple.entrance.gate_return").succeeded(), "out of the 山门")
	await tree.physics_frame
	await tree.physics_frame
	var mountain: WorldMapController = session.active_map() as WorldMapController
	_check(mountain.map == &"temple.mountain" and mountain.find_resident_npc(zombie.character_id) == zombie and grounds.find_resident_npc(zombie.character_id) == null, "it is on the climb now, not on the grounds")
	_check(zombie.world_location().zone_id == &"temple.entrance" and mountain.summoner_of(zombie.character_id) == session.player_runtime().character_id and zombie.has_flag(NpcDefinition.FLAG_FOLLOWS_PLAYER), "beside the player, still theirs")
	var body: WorldCharacterBody2D = mountain.runtime_body_for_character(zombie.character_id)
	_check(body != null and body.global_position.distance_to(mountain.runtime_player_body().global_position) < 120.0, "its body beside the player's")
	_check(session.shared_ui().log_lines().back() == "老道士的僵尸走了过来。", "走了过来: %s" % session.shared_ui().log_lines().back())


## The player at 10 atman: its next heal_up dispells it a second later, 化为一滩血水.
func _test_dispell(session: WorldSessionController, zombie: NpcRuntimeState) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var player: WorldPlayerRuntimeState = session.player_runtime()
	player.state.recovery.atman.current = 10
	map.npc_life.advance_npc_heartbeat(40.0)
	_check(player.state.recovery.atman.current == 10, "nothing more taken at 10 atman")
	_check(map.find_resident_npc(zombie.character_id) == null and session.shared_ui().log_lines().back() == "老道士的僵尸缓缓地倒了下来，化为一滩血水。", "it dispells: %s" % session.shared_ui().log_lines().back())
	player.state.recovery.atman.current = 300


## The 进香客 dies on the stairs and is raised: Save is open with it standing; the save
## leaves it out and Continue starts without it. Last: the restore retires this session.
func _test_save_leaves_it_out(tree: SceneTree, session: WorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var player: WorldPlayerRuntimeState = session.player_runtime()
	if map.map != &"temple.mountain":
		_check(false, "on the climb")
		return
	var guest: NpcRuntimeState = _first(map, GUEST)
	_check(guest != null, "the 进香客 is on the stairs")
	if guest == null:
		return
	await _beside(tree, session, map, guest)
	var corpse: CorpseState = _kill(map, guest, player)
	_full(player.state)
	var before: Array[StringName] = _npc_ids(map)
	_check(corpse != null and map.select_corpse(corpse.corpse_item_instance_id) and map.animate_selected_corpse(), "TEST-ONLY: the 进香客 died; 驱尸")
	var raised: Array[StringName] = []
	for id: StringName in _npc_ids(map):
		if not before.has(id):
			raised.append(id)
	_check(raised.size() == 1, "进香客的僵尸 stands")
	if raised.size() != 1:
		return
	await _test_flee(tree, session, map.find_resident_npc(raised[0]))
	_check(OldPineSaveEligibility.inspect(session).allowed(), "Save is open while it stands")
	var snapshot: GameSaveSnapshot = Work.capture(session)
	_check(snapshot != null, "the save captures")
	if snapshot == null:
		return
	var restored: OldPineWorldRestoreResult = OldPineWorldRestoreService.build_candidate(GameSaveJsonCodec.decode(GameSaveJsonCodec.encode(snapshot).text).snapshot, tree.root)
	_check(restored.succeeded(), "Continue restores: " + restored.path)
	if not restored.succeeded():
		return
	var fresh: WorldSessionController = restored.candidate
	_check(fresh.activate_restore_candidate(), "activation")
	var left: Array[StringName] = []
	for npc: NpcRuntimeState in fresh.world_npcs():
		if npc.definition().raising() != null:
			left.append(npc.character_id)
	_check(left.is_empty(), "Continue starts without it: %s" % [left])
	_check(GameSaveJsonCodec.encode(Work.capture(fresh)).text == GameSaveJsonCodec.encode(snapshot).text, "Save/Continue is exact without it")
	fresh.free()
	await tree.process_frame


## A sheet for 玄真 on the stairs above: the fight begins and the player flees it: it ends
## for all (FLED), 玄真 lives, the zombie is done (end_tag) and stands there unfollowing.
func _test_flee(tree: SceneTree, session: WorldSessionController, zombie: NpcRuntimeState) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	var xuanzhen: NpcRuntimeState = _first(map, &"temple.npc.little_taoist1")
	_check(xuanzhen != null, "玄真 sweeps the stairs")
	if xuanzhen == null:
		return
	await _place(tree, session, map, xuanzhen.world_location().zone_id)
	_move(map, zombie, xuanzhen.world_location().zone_id) # TEST-ONLY
	map.give_new_item_to_player(ItemContentDefinition.haunting_sheet_id(PAPER, &"temple.npc.little_taoist1")) # TEST-ONLY
	_check(map.attach_sheet(_carried(session, ItemContentDefinition.haunting_sheet_id(PAPER, &"temple.npc.little_taoist1"))) and coordinator.has_active_encounter(), "it goes after 玄真")
	if not coordinator.has_active_encounter():
		return
	_check(_offered(coordinator, CombatKillTacticalPolicy.ACTION_ID), "攻击 is offered here too")
	xuanzhen.character_state.vitality.current = -1 # TEST-ONLY: knocked out; the zombie would finish her
	coordinator.advance_scheduler(0.0)
	_check(xuanzhen.life_status == CharacterRuntimeLifeStatus.Value.UNCONSCIOUS and coordinator.has_active_encounter(), "玄真 lies there; the zombie's fight goes on")
	_check(coordinator.kill_target() == xuanzhen.character_id and _offered(coordinator, CombatKillTacticalPolicy.ACTION_ID), "攻击 is still at her: kill.c takes one lying unconscious")
	var result: CombatTacticalResult = coordinator.submit_player_action(CombatTacticalRequest.new(&"flee:1", coordinator.active_encounter().encounter_id, player.character_id, CombatFleeTacticalPolicy.ACTION_ID, CombatTacticalRequest.Category.FLEE))
	_check(result.code == CombatTacticalResult.Code.ACCEPTED, "逃跑 is offered to one who fights nobody")
	for _round: int in range(20):
		if not coordinator.has_active_encounter():
			break
		coordinator.advance_scheduler(1.0)
	_refresh(session)
	await tree.process_frame
	_check(not coordinator.has_active_encounter() and CombatEncounterCoordinator.take_aborted_total() == 0 and coordinator.last_completion().terminal_result.kind == CombatEncounterResultKind.Value.FLED, "fled: the fight is over for all")
	_check(xuanzhen.life_status == CharacterRuntimeLifeStatus.Value.UNCONSCIOUS and not xuanzhen.relationship.is_fighting() and not zombie.relationship.is_fighting(), "玄真 lives, lying there; nobody fights on")
	_check(zombie.has_flag(NpcDefinition.FLAG_SENT) and not zombie.has_flag(NpcDefinition.FLAG_FOLLOWS_PLAYER) and map.find_resident_npc(zombie.character_id) == zombie, "it is done with, and stands there until its next heal_up")


# --- Helpers ------------------------------------------------------------------------

## TEST-ONLY: full sen, kee and gin.
static func _full(state: CharacterState) -> void:
	state.spirit = CharacterResourceState.new(state.spirit.maximum, state.spirit.maximum, state.spirit.maximum)
	state.vitality = CharacterResourceState.new(state.vitality.maximum, state.vitality.maximum, state.vitality.maximum)
	state.essence = CharacterResourceState.new(state.essence.maximum, state.essence.maximum, state.essence.maximum)


## TEST-ONLY: `npc` dies outside a fight by the player's hand (last_damage_from); its corpse.
func _kill(map: WorldMapController, npc: NpcRuntimeState, player: WorldPlayerRuntimeState) -> CorpseState:
	npc.relationship.set_last_damage_from(player.character_id)
	npc.character_state.vitality.apply_wound(npc.character_state.vitality.effective + 1)
	map.combat_lifecycle.fall_below_zero()
	for corpse: CorpseState in map.corpse_states():
		if corpse.victim_character_id == npc.character_id:
			return corpse
	return null


## TEST-ONLY: a raised NPC moved into `zone_id` beside the player.
func _move(map: WorldMapController, npc: NpcRuntimeState, zone_id: StringName) -> void:
	var body: WorldCharacterBody2D = map.runtime_body_for_character(npc.character_id)
	var at: Vector2 = MapPlaces.spot(map, zone_id, map.runtime_player_body().global_position + Vector2(56, 0), 120.0)
	body.global_position = at
	npc.set_world_location(map.location_for_zone(zone_id))
	_check(at != Vector2.INF, "TEST-ONLY: %s moved into %s" % [npc.definition().display_name, zone_id])


## Whether the battle panel offers `action_id` now.
func _offered(coordinator: CombatEncounterCoordinator, action_id: StringName) -> bool:
	return coordinator.action_infos().any(func(info: CombatTacticalActionInfo) -> bool: return info.action_id == action_id)


## The carried item of `definition_id`, or "".
func _carried(session: WorldSessionController, definition_id: StringName) -> StringName:
	for row: PlayerInventoryRowProjection in session.player_inventory_rows():
		if row.item_definition_id == definition_id:
			return row.item_instance_id
	return &""


## The text of the inventory row's button `node_name` for `item_id`, or "".
func _row_button(hud: SharedGameplayUI, item_id: StringName, node_name: String) -> String:
	var rows: Array[PlayerInventoryRowProjection] = hud.inventory_rows()
	for index: int in rows.size():
		if rows[index].item_instance_id != item_id:
			continue
		var row: Node = hud.inventory_panel.row_container.get_child(index)
		var button: Button = row.get_node_or_null(node_name) as Button
		return "" if button == null else button.text
	return ""


func _refresh(session: WorldSessionController) -> void:
	(session.get_node("BattlePresentationLayer/BattleSurface") as BattlePresentationController).refresh_projection()


func _npc_ids(map: WorldMapController) -> Array[StringName]:
	var ids: Array[StringName] = []
	for npc: NpcRuntimeState in map.npc_runtimes():
		ids.append(npc.character_id)
	return ids


func _first(map: WorldMapController, definition_id: StringName) -> NpcRuntimeState:
	for npc: NpcRuntimeState in map.resident_npcs():
		if npc.definition().definition_id == definition_id and npc.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE:
			return npc
	return null


## TEST-ONLY: the player in the middle of `zone_id`.
func _place(tree: SceneTree, session: WorldSessionController, map: WorldMapController, zone_id: StringName) -> void:
	var at: Vector2 = MapPlaces.spot(map, zone_id, map.physical_zone(zone_id).global_rect().get_center(), 120.0)
	map.runtime_player_body().global_position = at
	_check(at != Vector2.INF and session.player_runtime().set_world_location(map.location_for_zone(zone_id)), "TEST-ONLY: in %s" % zone_id)
	await tree.physics_frame
	await tree.physics_frame


## TEST-ONLY: the player beside an NPC (`offset` from it), on a free spot of its zone.
func _beside(tree: SceneTree, session: WorldSessionController, map: WorldMapController, npc: NpcRuntimeState, offset: Vector2 = Vector2(0, 56)) -> void:
	var zone_id: StringName = npc.world_location().zone_id
	var body: WorldCharacterBody2D = map.runtime_body_for_character(npc.character_id)
	var at: Vector2 = MapPlaces.spot(map, zone_id, body.global_position + offset, 80.0)
	map.runtime_player_body().global_position = at
	_check(at != Vector2.INF and session.player_runtime().set_world_location(map.location_for_zone(zone_id)), "TEST-ONLY: beside %s" % npc.definition().display_name)
	await tree.physics_frame
	await tree.physics_frame


func _check(ok: bool, label: String) -> void:
	_count += 1
	if not ok:
		_failures.append("茅山 D: " + label)
