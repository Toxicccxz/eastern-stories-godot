extends RefCounted

## 乔阴 B (d/choyin): the town's secrets and 姑射山. The stone lion lifted into the 神秘洞穴
## (w_street1.c), its 护草神兽 and the 忘忧草 its die() leaves (the player's own when they struck
## last), smelt back to 振远镖局, where 陈剑秋 writes his letter; 放弃 in the cave. The hole
## under the 树王坟 (owner: plan Q2) to the hollow, its unseen 朦胧鬼影 (Q3: not drawn or
## picked, the player's turns pass on perception with a native line, no corpse), the 桃木箱 for
## the 武官 and his 白杨经, once. 姑射山: the tree to the cranes (fought now: beast.c's default
## action), the vine (random(dodge) < 30 into the 寒谷), the 缚仙绳 where a 仙鹤 is, the 云幡
## down to the 丹炉 and its 仙丹, the 寒谷's vase out to 晚月庄's bamboo. The hermit's 草堂:
## a book taken, put back on leaving, pray and dancing refused. 游晋 and the 荷包. The
## 咒剑王禅 against a ghost (taoist/sword.c hit_ob()). TEST-ONLY fixtures are marked.
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const Finance := preload("res://tests/runtime/snow_finance_test.gd")
const SouthRoad := preload("res://tests/runtime/snow_south_road_test.gd")
const MapPlaces := preload("res://tests/support/map_places.gd")
const GRASS: StringName = &"es2:d/choyin/obj/grass"
const LETTER: StringName = &"es2:u/cloud/npc/obj/letter"
const CHEST: StringName = &"es2:d/choyin/obj/chest"
const MAGIC_BOOK: StringName = &"es2:d/choyin/obj/magic_book"
const SILK_BAG: StringName = &"es2:d/choyin/npc/obj/silk_bag"
const BOOK1: StringName = &"es2:d/choyin/npc/obj/book1"
const BOOK2: StringName = &"es2:d/choyin/npc/obj/book2"
const ROPE: StringName = &"es2:d/choyin/obj/goldenrope"
const TABLET: StringName = &"es2:d/choyin/obj/tablet"
const BRACELET: StringName = &"es2:d/latemoon/obj/bracelet"
const BLADE: StringName = &"es2:d/choyin/obj/blade"
const SHADOW: StringName = &"choyin.npc.shadow"
const GHOST: StringName = &"choyin.npc.ghost"
const LION: StringName = &"choyin.npc.lion"
const CRANE: StringName = &"choyin.npc.crane"
const SERGEANT: StringName = &"choyin.npc.sergeant"
const GIRL: StringName = &"choyin.npc.girl"
const YOUNGMAN: StringName = &"choyin.npc.youngman"
const B_HEADER: StringName = &"cloud.npc.b_header"
const UNSEEN: String = "你看不见对手，无从下手。"


## Every draw the highest: every blow lands, the sword's random(max_atman) wins.
class Highest:
	extends CombatRandomSource

	func next_below(bound: int) -> int:
		return maxi(bound - 1, 0)


## Every draw 0: a fighter is always brave enough (fight()'s random(cps * 3) < cor).
class Lowest:
	extends CombatRandomSource

	func next_below(_bound: int) -> int:
		return 0


var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_catalog()
	_test_ghost_bane()
	_test_chen_reminder()
	var session: WorldSessionController = Work.create_session(tree)
	await tree.process_frame
	session.set_process(false)
	session.configure_npc_ambience_random_source(SouthRoad.Still.new()) # TEST-ONLY: nobody chats or wanders
	await _test_lion(tree, session)
	await _test_hollow(tree, session)
	await _test_lovers(tree, session)
	await _test_hermit(tree, session)
	await _test_guye(tree, session)
	session.free()
	await tree.process_frame
	return {"assertions": _count, "failures": _failures}


func _test_catalog() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	_check(catalog.npc(SHADOW).is_ghost() and catalog.npc(GHOST).is_ghost() and not catalog.npc(LION).is_ghost(), "朦胧鬼影 and 孤魂野鬼 are ghosts (is_ghost())")
	var shadow: NpcDefinition = catalog.npc(SHADOW)
	_check(shadow.authored_combat_facts().apply_value(&"blade") == 80 and shadow.attitude == NpcDefinition.Attitude.AGGRESSIVE, "the 朦胧鬼影: apply/blade 80 (query_skill()), aggressive")
	var hooks: NpcHooks = catalog.npc(LION).hooks()
	_check(hooks != null and hooks.die_item_id == GRASS and hooks.die_item_master, "lion.c die(): a 忘忧草 with its killer's master_id")
	var mastered: ItemContentDefinition = catalog.item(ItemContentDefinition.master_id(GRASS))
	_check(mastered != null and mastered.mastered and mastered.display_name == "忘忧草" and catalog.item(GRASS).masters and not catalog.item(GRASS).mastered, "the 忘忧草's master form: the same grass, the player's")
	_check(catalog.item(ItemContentDefinition.master_id(LETTER)) != null, "陈剑秋's letter records its master")
	_check(not catalog.npc(CRANE).dealings().is_fight_deferred(), "the 仙鹤 can be fought")
	var crane := CombatSliceContentProfile.new().for_npc_definition(catalog.npc(CRANE))
	_check(crane.readiness() == CombatSliceContentProfile.Readiness.READY and crane.unarmed_action_set().size() == 1 and crane.unarmed_action_set().action_at(0).legacy_action_text == "$N攻击$n的$l", "beast.c's default action for a beast without verbs: its first %s is the limb (默认)")
	_check(catalog.item(TABLET).apply == ItemApplyFunctions.TABLET and ItemApplyFunctions.verb(ItemApplyFunctions.TABLET) == "吃", "the 仙丹 is eaten")
	var named: Array[String] = []
	for id: StringName in catalog.item(BOOK1).name_pick_ids() + catalog.item(BOOK2).name_pick_ids():
		named.append(catalog.item(id).display_name)
	_check(named.size() == 13 and named.has("「笑傲江湖」") and named.has("「八卦步法」"), "the hermit's books: eight and five names")
	var lift: WorldLandmarkDefinition = catalog.landmark(&"choyin.w_street1.landmark.statue")
	_check(lift.policy == &"lift" and lift.setting("limit") == 10 and lift.setting("divisor") == 5 and lift.portal_id == &"choyin.w_street1.lift", "the lion lifts: count + str / 5 reaching 10")
	var vine: WorldLandmarkDefinition = catalog.landmark(&"choyin.guyehill.landmark.vine")
	_check(vine.policy == &"vine" and vine.setting("below") == 30 and vine.portal_ids() == [&"choyin.guyehill.hold_fall", &"choyin.guyehill.hold_climb"], "the vine: below 30 falls into the 寒谷")
	_check(catalog.landmark(&"choyin.oldpine_unused") == null and catalog.landmark(&"oldpine.outdoor.landmark.epath2_vine").setting("below") == 0, "Old Pine's vine keeps epath2.c's 5")
	_check(catalog.zone(&"choyin.club").refusal("pray").begins_with("也不知道隐士怎么弄的") and catalog.zone(&"choyin.club").refusal("tie").is_empty(), "the 草堂 answers pray and dancing")
	_check(catalog.item(BRACELET).act.command == "pray" and catalog.item(&"es2:d/latemoon/obj/book").act.command == "dancing", "the bracelet prays, the dance book dances")


## daemon/class/taoist/sword.c hit_ob() against a ghost: random(max_atman) above its atman / 2
## wounds its gin by query_spi() and heals the wielder; otherwise random(spi) adds to the blow.
func _test_ghost_bane() -> void:
	var bane: WeaponGhostBane = GameContent.catalog().item(&"es2:daemon/class/taoist/sword").ghost_bane
	_check(bane != null and bane.line == "王禅剑发出一股金色的罡气，流遍$N的全身。" and bane.color == ColoredLine.HIY, "咒剑王禅's hit_ob() line")
	var weapon := WeaponCombatProfile.new(&"es2:daemon/class/taoist/sword", &"sword", CombatHitPolicyStatus.Value.GHOST_BANE)
	weapon.ghost_bane = bane
	weapon.wielder_max_atman = 100
	weapon.wielder_spirituality = 40
	var attacker := CombatAttackerSnapshot.new(
		&"player", true, 1000000, 0, 0, &"sword", 100, 0, 10, CombatStrengthProjection.new(20, 0, 0), true,
		&"", CombatHitPolicyStatus.Value.NOT_APPLICABLE, &"", CombatHitPolicyStatus.Value.NOT_APPLICABLE,
		CombatHitPolicyStatus.Value.NOT_APPLICABLE, weapon, &"force", 0, null, null, 0, null,
	)
	var ghost := CombatDefenderSnapshot.new(&"shadow", true, false, 1, 0, 0, 2, 2, 2, 0, 0, false, [&"头部"], &"force", 0, 0, 0, 10)
	ghost.ghost_atman = 0
	var essence := CharacterResourceState.new(400, 400, 400)
	var mine := CharacterResourceState.new(10, 100, 100)
	var result: CombatAttackResult = CombatAttackResolver.resolve(
		CombatAttackInput.new(attacker, ghost, CombatActionDefinition.new(&"ordinary", 0, 0, &"割伤")),
		essence, CharacterResourceState.new(500, 500, 500), CharacterResourceState.new(500, 500, 500), Highest.new(),
		CharacterInternalResourceState.new(0, 0), mine, CharacterResourceState.new(10, 100, 100), CharacterResourceState.new(10, 100, 100),
	)
	_check(result.outcome == CombatAttackResult.Outcome.HIT and result.calculation.weapon_bane == bane and result.calculation.weapon_bane_amount == 40, "random(100) 99 over 0: the line, query_spi() 40")
	_check(essence.effective == 360 and mine.current == 50, "the ghost's gin wounded by 40, the wielder's gin healed by 40")
	var living := CombatDefenderSnapshot.new(&"man", true, false, 1, 0, 0, 2, 2, 2, 0, 0, false, [&"头部"], &"force", 0, 0, 0, 10)
	var plain: CombatAttackResult = CombatAttackResolver.resolve(
		CombatAttackInput.new(attacker, living, CombatActionDefinition.new(&"ordinary", 0, 0, &"割伤")),
		CharacterResourceState.new(400, 400, 400), CharacterResourceState.new(500, 500, 500), CharacterResourceState.new(500, 500, 500), Highest.new(),
		CharacterInternalResourceState.new(0, 0), CharacterResourceState.new(10, 100, 100), CharacterResourceState.new(10, 100, 100), CharacterResourceState.new(10, 100, 100),
	)
	_check(plain.outcome == CombatAttackResult.Outcome.HIT and plain.calculation.weapon_bane == null, "anyone else: nothing")
	ghost.ghost_atman = 300
	var missed: CombatAttackResult = CombatAttackResolver.resolve(
		CombatAttackInput.new(attacker, ghost, CombatActionDefinition.new(&"ordinary", 0, 0, &"割伤")),
		CharacterResourceState.new(400, 400, 400), CharacterResourceState.new(500, 500, 500), CharacterResourceState.new(500, 500, 500), Highest.new(),
		CharacterInternalResourceState.new(0, 0), CharacterResourceState.new(10, 100, 100), CharacterResourceState.new(10, 100, 100), CharacterResourceState.new(10, 100, 100),
	)
	_check(missed.calculation.weapon_bane == null and missed.calculation.final_strength_bonus == 20 + 39, "a strong ghost (atman 300): random(spi) 39 adds to the blow (%d)" % missed.calculation.final_strength_bonus)


## d/city/npc/chen.c (陈天星, 京师: region plan #12) takes 陈剑秋's letter by its master_id and
## recruits. REMINDER: this fails once he is placed, until his accept_object() is ported.
func _test_chen_reminder() -> void:
	var placed: bool = false
	for npc: NpcDefinition in GameContent.catalog().npcs():
		placed = placed or npc.legacy_source_path == "d/city/npc/chen.c"
	_check(not placed, "REMINDER (#12): 陈天星 stands now: port his accept_object() of 陈剑秋's letter (item_master) and recruit, then replace this check")


## w_street1.c: lifts counted with str / 5 open the hole; the 护草神兽 attacks; killed by the
## player its corpse holds their 忘忧草; smelt, it blows them to 振远镖局; 陈剑秋 writes for one
## of his family. Without the grass the cave keeps them: 放弃 wakes them in the Inn.
func _test_lion(tree: SceneTree, session: WorldSessionController) -> void:
	_check(session.handoff_to(&"choyin.town", &"choyin.n_gate", &"choyin.n_gate", &"choyin.n_gate.road_arrival").succeeded(), "in the town")
	await tree.physics_frame
	var map: WorldMapController = session.active_map() as WorldMapController
	var hud: SharedGameplayUI = session.shared_ui()
	var player: WorldPlayerRuntimeState = session.player_runtime()
	_full(player)
	var statue: StringName = &"choyin.w_street1.landmark.statue"
	_check(map.place_player(&"choyin.w_street1", MapPlaces.spot(map, &"choyin.w_street1", map.landmark_areas[statue].global_position)), "by the stone lion")
	await tree.physics_frame
	_check(map.select_landmark(statue), "the lion selected")
	@warning_ignore("integer_division")
	var needed: int = maxi(1, 10 - player.state.attributes.strength / 5)
	var lifts: int = 0
	while session.active_map_id() == &"choyin.town" and lifts < 12:
		map.traverse_selected_portal()
		lifts += 1
	_check(lifts == needed and session.active_map_id() == &"choyin.lion_cave", "%d lifts with str %d open the hole: %d" % [needed, player.state.attributes.strength, lifts])
	var lines: Array[String] = hud.log_lines()
	_check(lines.count("你努力地抬着石狮子，试图抬起一点点。") >= needed and lines.has("石狮子竟然向左移动了尺许，漏出向下的洞穴。\n你从洞口掉了下去。") and lines[-1] == "石狮子又缓缓地向右移动了尺许，正好盖住洞口。", "the lift's lines (fixed): %s" % [lines.slice(-3)])
	await tree.physics_frame
	await tree.physics_frame
	var cave: WorldMapController = session.active_map() as WorldMapController
	var lion: NpcRuntimeState = _npc(cave, LION)
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	for frame: int in 6:
		if coordinator.has_active_encounter():
			break
		await tree.physics_frame
	_check(lion != null and coordinator.has_active_encounter(), "the 护草神兽 attacks at once (its reach is the cave)")
	lion.character_state.vitality.apply_wound(lion.character_state.vitality.effective + 1) # TEST-ONLY: the last blow
	var rounds: int = 0
	while coordinator.has_active_encounter() and rounds < 20:
		coordinator.advance_scheduler(1.0)
		rounds += 1
	_check(lion.life_status == CharacterRuntimeLifeStatus.Value.DEAD and CombatEncounterCoordinator.take_aborted_total() == 0, "the 护草神兽 dies")
	var grass: StringName = &""
	var corpse_id: StringName = &""
	for corpse: CorpseState in cave.corpse_states():
		for item_id: StringName in session.inventory_state().direct_children(ContainmentEndpoint.new(ContainmentEndpoint.Kind.ITEM, corpse.corpse_item_instance_id)):
			if session.item_instance_index().resolve(item_id).item_definition_id == ItemContentDefinition.master_id(GRASS):
				grass = item_id
				corpse_id = corpse.corpse_item_instance_id
	_check(not grass.is_empty(), "its corpse holds the player's own 忘忧草 (master_id)")
	session.shared_ui().dismiss_current_panel()
	_check(cave.place_player(&"choyin.lionroom", MapPlaces.spot(cave, &"choyin.lionroom", cave.corpses.lying_at(cave.corpses.find_corpse(corpse_id)), 48.0)), "beside the beast's corpse")
	await tree.physics_frame
	await tree.physics_frame
	_check(cave.select_corpse(corpse_id) and cave.take_selected_loot_item(grass).succeeded, "the player takes it")
	# Smelt without it first: the cave keeps the player.
	var smell: WorldService = _service(cave, &"choyin.lionroom.smell")
	_check(smell != null and smell.in_reach() and smell.context_title().contains("闻忘忧草"), "the cave's 闻忘忧草")
	var held: Dictionary = _set_aside(session, grass) # TEST-ONLY: the grass out of the pack for a moment
	smell.interact()
	_check(hud.log_lines()[-1] == "你身上没有忘忧草啊。" and session.active_map_id() == &"choyin.lion_cave", "no grass: 你身上没有忘忧草啊。")
	_put_back(session, held)
	_check(Work.capture(session) != null, "Save holding the player's 忘忧草")
	smell.interact()
	await tree.physics_frame
	_check(session.active_map_id() == &"cloud.outdoor" and player.world_location().zone_id == &"cloud.biaoju", "the wind carries the player to 振远镖局")
	_check(hud.log_lines().has("一阵怪风骤然刮起，你仿佛腾云驾雾般。"), "the wind's line")
	var town: WorldMapController = session.active_map() as WorldMapController
	var chen: NpcRuntimeState = _npc(town, B_HEADER)
	_check(chen != null and town.relocate_player(&"cloud.biaoju", chen.spawn_point_id), "beside 陈剑秋")
	await tree.physics_frame
	await tree.physics_frame
	town.select_npc(chen.character_id)
	player.state.family.family_id = &"family.zhenyuan" # TEST-ONLY: one of 振远镖局
	var given: ItemHandlingResult = town.floor_items.give_to_selected(_carried(session, ItemContentDefinition.master_id(GRASS)))
	_check(given.done() and given.lines.has("陈剑秋大喜过望，：“好，好，我这就给你写信。”") and given.lines.has("陈剑秋交给你一封信件。"), "陈剑秋 writes his letter: %s" % [given.lines])
	_check(not _carried(session, ItemContentDefinition.master_id(LETTER)).is_empty(), "the letter is the player's (master_id)")
	var plain: StringName = _give(session, GRASS) # TEST-ONLY: a 忘忧草 someone else got
	var refused: ItemHandlingResult = town.floor_items.give_to_selected(plain)
	_check(not refused.done() and refused.lines.has("陈剑秋笑了笑说：“这不是你得到的吧？”。") and not _carried(session, GRASS).is_empty(), "one the player did not get: 这不是你得到的吧, and it stays with them")
	player.state.family.family_id = &"" # TEST-ONLY
	# Back into the cave without a grass: 放弃 wakes the player in the Inn.
	_drop_all(session, GRASS) # TEST-ONLY
	_check(session.handoff_to(&"choyin.lion_cave", &"choyin.lionroom", &"choyin.lionroom", &"choyin.lionroom.fall_arrival").succeeded(), "in the cave again")
	await tree.physics_frame
	cave = session.active_map() as WorldMapController
	var dark: StringName = &"choyin.lionroom.landmark.dark"
	_check(cave.select_landmark(dark), "the dark selected")
	cave.traverse_selected_portal()
	await tree.physics_frame
	_check(player.world_location().zone_id == &"snow.inn.main_floor" and hud.log_lines().has("你在洞里苦等良久，终于昏昏沉沉地睡了过去……醒来时，你已经躺在雪亭镇的饮风客栈里。"), "放弃: the Inn")


## tree_tomb.c's hole (owner: plan Q2) down to the hollow; its three 朦胧鬼影 are unseen (Q3):
## not drawn nor picked, they attack, the player's turns pass on perception; one dies without a
## corpse and its blade falls. The 桃木箱 for the 武官 and his 白杨经, once.
func _test_hollow(tree: SceneTree, session: WorldSessionController) -> void:
	_check(session.handoff_to(&"choyin.town", &"choyin.n_gate", &"choyin.n_gate", &"choyin.n_gate.road_arrival").succeeded(), "in the town again")
	await tree.physics_frame
	var map: WorldMapController = session.active_map() as WorldMapController
	var hud: SharedGameplayUI = session.shared_ui()
	var player: WorldPlayerRuntimeState = session.player_runtime()
	_full(player)
	for ghost: NpcRuntimeState in _all(map, GHOST):
		var body: WorldCharacterBody2D = map.runtime_body_for_character(ghost.character_id)
		_check(body != null and not body.visible and not body.input_pickable and not map.select_npc(ghost.character_id), "the 孤魂野鬼 at %s is unseen and cannot be picked" % ghost.world_location().zone_id)
	var hole: StringName = &"choyin.tree_tomb.landmark.hole"
	_check(map.place_player(&"choyin.tree_tomb", MapPlaces.spot(map, &"choyin.tree_tomb", map.landmark_areas[hole].global_position)) and map.select_landmark(hole), "at the stump's hole")
	await tree.physics_frame
	map.traverse_selected_portal()
	await tree.physics_frame
	_check(session.active_map_id() == &"choyin.tree_hollow" and hud.log_lines().has("你攀著粗糙的洞壁，爬进了树桩中间的大洞。"), "down the hole into the hollow")
	var hollow: WorldMapController = session.active_map() as WorldMapController
	var shadows: Array[NpcRuntimeState] = _all(hollow, SHADOW)
	_check(shadows.size() == 3, "three 朦胧鬼影")
	for shadow: NpcRuntimeState in shadows:
		var body: WorldCharacterBody2D = hollow.runtime_body_for_character(shadow.character_id)
		_check(not body.visible and not body.input_pickable and not hollow.select_npc(shadow.character_id), "a 朦胧鬼影 unseen")
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	for frame: int in 6:
		if coordinator.has_active_encounter():
			break
		await tree.physics_frame
	_check(coordinator.has_active_encounter(), "a 朦胧鬼影 attacks")
	var unseen: int = 0
	var cast := BattlePresentationProjection.new(&"test", CombatEncounterMode.Value.LETHAL, player.character_id)
	var narrator := BattleNarrator.new()
	for second: int in 8:
		for event: CombatSchedulerEvent in coordinator.advance_scheduler(1.0).events():
			if event.actor_id != player.character_id or event.resolution == null or event.resolution.fight_decision_result == null:
				continue
			if event.resolution.fight_decision_result.outcome == CombatFightDecisionResult.Outcome.TARGET_NOT_PERCEIVED:
				var told: Array[BattleNarrationLine] = narrator.opportunity(event, cast)
				unseen += 1 if told.size() == 1 and told[0].text == UNSEEN else 0
	_check(unseen >= 3 and player.state.skills.effective_level(&"perception") == 0, "without perception every turn passes: %s (%d)" % [UNSEEN, unseen])
	var fighting: NpcRuntimeState = null
	for shadow: NpcRuntimeState in shadows:
		if shadow.relationship.is_fighting():
			fighting = shadow
	fighting.character_state.vitality.apply_wound(fighting.character_state.vitality.effective + 1) # TEST-ONLY: the last blow
	var rounds: int = 0
	while fighting.life_status != CharacterRuntimeLifeStatus.Value.DEAD and rounds < 10:
		coordinator.advance_scheduler(1.0)
		rounds += 1
	var corpses: int = hollow.corpse_states().size()
	var blade: StringName = hollow.floor_items.floor_item_of(BLADE, &"choyin.tomb1")
	_check(fighting.life_status == CharacterRuntimeLifeStatus.Value.DEAD and corpses == 0 and not blade.is_empty(), "a ghost dies without a corpse; its 乌檀木刀 falls (corpses %d)" % corpses)
	await _leave_fight(tree, session)
	# North to the 桃木箱.
	_check(await _take_floor(tree, hollow, CHEST, &"choyin.tomb3") and not _carried(session, CHEST).is_empty(), "the 桃木箱 lies in the sandalwood end: the player takes it")
	_check(session.handoff_to(&"choyin.town", &"choyin.n_gate", &"choyin.n_gate", &"choyin.n_gate.road_arrival").succeeded(), "up again")
	await tree.physics_frame
	map = session.active_map() as WorldMapController
	var sergeant: NpcRuntimeState = _npc(map, SERGEANT)
	_check(sergeant != null and map.relocate_player(sergeant.world_location().zone_id, sergeant.spawn_point_id), "beside the 武官")
	await tree.physics_frame
	await tree.physics_frame
	map.select_npc(sergeant.character_id)
	_check(map.ask_topics_selected().has("桃木箱子"), "he asks after a 桃木箱子")
	var gift: ItemHandlingResult = map.floor_items.give_to_selected(_carried(session, CHEST))
	_check(gift.done() and gift.lines == ["武官说道：太好了！就是这个箱子！", "武官说道：在下出门在外，没有携带太多银两 ...", "武官说道：如果您不嫌弃的话，这本古书便请笑纳。", "武官给你一本「白杨经」。", "你给武官一个桃木箱。"], "his thanks, then give.c's line: %s" % [gift.lines])
	_check(not _carried(session, MAGIC_BOOK).is_empty() and GameContent.catalog().item(MAGIC_BOOK).study.skill_id == &"magic", "the 「白杨经」 (magic, to 20)")
	_check(not map.ask_topics_selected().has("桃木箱子") and not map.ask_topics_selected().has("箱子"), "箱子 and 桃木箱子 forgotten")
	var rumors: Array[String] = map.ask_selected("传闻")
	_check(not rumors.has("武官说道：在下失落了一件重要物事，是装在一个桃木箱子里，不知你有没有看见？"), "rumors forgotten: %s" % [rumors])
	var second_chest: StringName = _give(session, CHEST) # TEST-ONLY: another chest
	var again: ItemHandlingResult = map.floor_items.give_to_selected(second_chest)
	_check(not again.done() and not _carried(session, CHEST).is_empty(), "a second chest is not taken (chest_found)")


## girl.c's 游晋: the 荷包, once (默认); youngman.c takes it, his 心事 is told.
func _test_lovers(tree: SceneTree, session: WorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var girl: NpcRuntimeState = _npc(map, GIRL)
	_check(girl != null and map.relocate_player(girl.world_location().zone_id, girl.spawn_point_id), "beside the 官家小姐")
	await tree.physics_frame
	await tree.physics_frame
	map.select_npc(girl.character_id)
	_check(map.ask_topics_selected().has("游晋"), "she can be asked about 游晋")
	var said: Array[String] = map.ask_selected("游晋")
	_check(said.has("官家小姐说道：小女子有一事相求 ... 请您将这个交给游 ... 游公子。") and said.has("官家小姐给你一个紫罗鸳鸯荷包。") and not _carried(session, SILK_BAG).is_empty(), "the 荷包: %s" % [said])
	_check(not map.ask_topics_selected().has("游晋"), "given once (默认)")
	var youngman: NpcRuntimeState = _npc(session.active_map() as WorldMapController, YOUNGMAN)
	if youngman == null:
		_check(session.handoff_to(&"choyin.hotel_2f", &"choyin.hotel2", &"choyin.hotel2", &"choyin.hotel2.stairs_arrival").succeeded(), "up to the 福林楼")
		await tree.physics_frame
		map = session.active_map() as WorldMapController
		youngman = _npc(map, YOUNGMAN)
	_check(youngman != null and map.relocate_player(youngman.world_location().zone_id, youngman.spawn_point_id), "beside 游晋")
	await tree.physics_frame
	await tree.physics_frame
	map.select_npc(youngman.character_id)
	_check(map.ask_topics_selected().has("心事"), "his 心事")
	var given: ItemHandlingResult = map.floor_items.give_to_selected(_carried(session, SILK_BAG))
	_check(given.done() and given.lines.has("贵公子一眼瞥见荷包上的鸳鸯图案，立刻一把抢了过去。") and given.lines.has("贵公子说道：原来爹爹替我主张的婚事，竟然是 ..."), "游晋 takes the 荷包: %s" % [given.lines])
	_check(not map.ask_topics_selected().has("心事"), "his 心事 is over")


## club.c: a book scratched off the table (its name drawn) goes back on leaving; one leaving
## without reads 你离开草堂!; the bracelet's pray fails there.
func _test_hermit(tree: SceneTree, session: WorldSessionController) -> void:
	_check(session.handoff_to(&"choyin.east", &"choyin.solidpath1", &"choyin.solidpath1", &"choyin.solidpath1.gate_arrival").succeeded(), "east of the town")
	await tree.physics_frame
	var map: WorldMapController = session.active_map() as WorldMapController
	var hud: SharedGameplayUI = session.shared_ui()
	map.set_door_open(&"choyin.fence.door", true)
	_check(map.place_player(&"choyin.club", MapPlaces.service_spot(map, &"choyin.club.scratch", &"choyin.club")), "in the 草堂 by the books")
	await tree.physics_frame
	await tree.physics_frame
	var scratch: WorldService = _service(map, &"choyin.club.scratch")
	_check(scratch != null and scratch.in_reach(), "the books in reach")
	scratch.interact()
	var book: StringName = _carried_kind(session, [BOOK1, BOOK2])
	var content: ItemContentDefinition = null if book.is_empty() else GameContent.catalog().item(session.item_instance_index().resolve(book).item_definition_id)
	_check(hud.log_lines().has("你乘人不备，抓起一本书藏入怀中。") and content != null and content.display_name.begins_with("「") and content.study != null and session.player_runtime().temp_marks.get("choyin/书", 0) == 1, "a hermit's book, named: %s" % ("" if content == null else content.display_name))
	var bracelet: StringName = _give(session, BRACELET) # TEST-ONLY
	var sen: int = session.player_runtime().state.spirit.current
	_check(map.floor_items.act_with_item(bracelet) and hud.log_lines()[-1] == "也不知道隐士怎么弄的，你的玛瑙手镯不灵验了。" and session.player_runtime().state.spirit.current == sen and session.player_runtime().world_location().zone_id == &"choyin.club", "the 玛瑙手镯 fails in the 草堂")
	_check(await MapPlaces.drive_to_zone(tree, map, &"choyin.fence"), "out east to the bamboo")
	_check(_carried_kind(session, [BOOK1, BOOK2]).is_empty() and hud.log_lines().has("你将书放回到矮几。"), "the book goes back")
	_check(await MapPlaces.drive_to_zone(tree, map, &"choyin.club"), "back in")
	_check(await MapPlaces.drive_to_zone(tree, map, &"choyin.fence"), "out again")
	_check(hud.log_lines()[-1] == "你离开草堂!" or hud.log_lines().slice(-3).has("你离开草堂!"), "without a book: 你离开草堂!: %s" % [hud.log_lines().slice(-3)])


## 姑射山: the vine (random(dodge) < 30: the 寒谷, else the 山洞 and its 缚仙绳), the tree to the
## cranes, the rope where a 仙鹤 is (50 sen), the 云幡 down to the 丹炉, its 仙丹, out to 桐柏山;
## the 寒谷's vase to 晚月庄's bamboo. A 仙鹤 fought: beast.c's default action.
func _test_guye(tree: SceneTree, session: WorldSessionController) -> void:
	var hud: SharedGameplayUI = session.shared_ui()
	var player: WorldPlayerRuntimeState = session.player_runtime()
	_check(session.handoff_to(&"choyin.guye", &"choyin.spath", &"choyin.spath", &"choyin.spath.gate_arrival").succeeded(), "south to 姑射山")
	await tree.physics_frame
	var map: WorldMapController = session.active_map() as WorldMapController
	var vine: StringName = &"choyin.guyehill.landmark.vine"
	_check(map.place_player(&"choyin.guyehill", MapPlaces.spot(map, &"choyin.guyehill", map.landmark_areas[vine].global_position)) and map.select_landmark(vine), "at the cliff's vine")
	await tree.physics_frame
	var random: WorldInteractionRandomSource = session.world_interaction_random_source()
	player.state.skills.set_raw_level(&"dodge", 100) # TEST-ONLY
	session.configure_world_interaction_random_source(ScriptedWorldInteractionRandomSource.new([29])) # TEST-ONLY: random(dodge) 29
	map.traverse_selected_portal()
	await tree.physics_frame
	_check(player.world_location().zone_id == &"choyin.hollow" and hud.log_lines().has("只听见一声杀猪般的惨叫，你已坠落深谷。。"), "29 < 30: into the 寒谷")
	var valley: WorldMapController = session.active_map() as WorldMapController
	_check(valley.place_player(&"choyin.hollow3", MapPlaces.spot(valley, &"choyin.hollow3", valley.landmark_areas[&"choyin.hollow3.landmark.vase"].global_position)), "at the 寒谷's end")
	await tree.physics_frame
	_check(not valley.floor_items.floor_item_of(&"es2:d/choyin/obj/orchid", &"choyin.hollow3").is_empty(), "a 寒谷幽兰 there")
	_check(valley.select_landmark(&"choyin.hollow3.landmark.vase"), "the vase")
	valley.traverse_selected_portal()
	await tree.physics_frame
	_check(player.world_location().zone_id == &"latemoon.bamboo" and hud.log_lines().has("寒谷幽兰忽地绽放,幻出七色光华.你轻轻地飘起..."), "the orchid floats the player to 晚月庄's bamboo")
	_check(session.handoff_to(&"choyin.guye", &"choyin.spath", &"choyin.spath", &"choyin.spath.gate_arrival").succeeded(), "back to 姑射山")
	await tree.physics_frame
	map = session.active_map() as WorldMapController
	_check(map.place_player(&"choyin.guyehill", MapPlaces.spot(map, &"choyin.guyehill", map.landmark_areas[vine].global_position)) and map.select_landmark(vine), "at the vine again")
	await tree.physics_frame
	session.configure_world_interaction_random_source(ScriptedWorldInteractionRandomSource.new([30])) # TEST-ONLY: random(dodge) 30
	map.traverse_selected_portal()
	await tree.physics_frame
	_check(player.world_location().zone_id == &"choyin.halfhole" and hud.log_lines().has("你手脚俐落地攀附著藤蔓，慢慢地爬近山洞。"), "30: up to the 山洞")
	session.configure_world_interaction_random_source(random)
	var cliff: WorldMapController = session.active_map() as WorldMapController
	_check(await _take_floor(tree, cliff, ROPE, &"choyin.halfhole"), "the 缚仙绳 lies in the cave")
	var rope: StringName = _carried(session, ROPE)
	_check(not rope.is_empty() and GameContent.catalog().item(ROPE).no_drop, "the player takes it (no_drop)")
	cliff.floor_items.act_with_item(rope)
	_check(hud.log_lines()[-1] == "你要缚何物?" and player.world_location().zone_id == &"choyin.halfhole", "no crane here: 你要缚何物?")
	_check(session.handoff_to(&"choyin.crown", &"choyin.craneroom", &"choyin.craneroom", &"choyin.craneroom.climb_arrival").succeeded(), "up in the 树冠 (as the tree's climb)")
	await tree.physics_frame
	var crown: WorldMapController = session.active_map() as WorldMapController
	var sen: int = player.state.spirit.current
	crown.floor_items.act_with_item(rope)
	await tree.physics_frame
	_check(player.world_location().zone_id == &"choyin.platform" and hud.log_lines().has("你双手合掌，随风而起，落于仙鹤背上......") and player.state.spirit.current == sen - 50, "on a crane's back to the 云台, 50 sen")
	var summit: WorldMapController = session.active_map() as WorldMapController
	var flag: StringName = &"choyin.platform.landmark.flag"
	_check(summit.place_player(&"choyin.platform", MapPlaces.spot(summit, &"choyin.platform", summit.landmark_areas[flag].global_position)) and summit.select_landmark(flag), "by the 云幡")
	await tree.physics_frame
	summit.traverse_selected_portal()
	await tree.physics_frame
	_check(player.world_location().zone_id == &"choyin.stove" and hud.log_lines().has("你碰了云幡,云幡动了一下.....\n白光一闪,云台忽地裂开"), "the 云幡 opens the way down to the 丹炉")
	var furnace: WorldMapController = session.active_map() as WorldMapController
	_check(await _take_floor(tree, furnace, TABLET, &"choyin.stove"), "仙丹 in the furnace")
	player.state.vitality = CharacterResourceState.new(10, 100, 100) # TEST-ONLY: hurt
	var tablet: StringName = _carried(session, TABLET)
	_check(furnace.floor_items.apply_item(tablet) and player.state.vitality.current == 40 and hud.log_lines()[-1] == "你拿出一粒仙丹，纳入口中. 吃的太急, 鼻涕眼泪流了满脸..", "a 仙丹 eaten: 30 kee back")
	_full(player)
	# The tree, and a 仙鹤 fought.
	_check(session.handoff_to(&"choyin.guye", &"choyin.spath", &"choyin.spath", &"choyin.spath.gate_arrival").succeeded(), "姑射山 once more")
	await tree.physics_frame
	map = session.active_map() as WorldMapController
	var tree_landmark: StringName = &"choyin.guyehill.landmark.tree"
	_check(map.place_player(&"choyin.guyehill", MapPlaces.spot(map, &"choyin.guyehill", map.landmark_areas[tree_landmark].global_position)) and map.select_landmark(tree_landmark), "at the old tree")
	await tree.physics_frame
	map.traverse_selected_portal()
	await tree.physics_frame
	_check(player.world_location().zone_id == &"choyin.craneroom" and hud.log_lines().has("你七手八脚地爬上了古树。"), "up the tree to the cranes")
	crown = session.active_map() as WorldMapController
	var crane: NpcRuntimeState = _npc(crown, CRANE)
	_check(crane != null and crown.relocate_player(&"choyin.craneroom", crane.spawn_point_id), "beside a 仙鹤")
	await tree.physics_frame
	await tree.physics_frame
	crown.select_npc(crane.character_id)
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	var combat: CombatRandomSource = session.combat_random_source()
	session.configure_combat_random_source(Lowest.new()) # TEST-ONLY: the crane strikes back
	CombatEncounterCoordinator.take_aborted_total()
	_check(crown.attack_selected().outcome == CombatSliceInitiationResult.Outcome.COMPLETED, "the player attacks a 仙鹤")
	var cast := BattlePresentationProjection.new(&"test", CombatEncounterMode.Value.LETHAL, player.character_id, crane.character_id, [
		BattleParticipantProjection.new(player.character_id, "你"), BattleParticipantProjection.new(crane.character_id, "仙鹤"),
	])
	var narrator := BattleNarrator.new()
	var crane_line: String = ""
	for second: int in 6:
		for event: CombatSchedulerEvent in coordinator.advance_scheduler(1.0).events():
			if event.actor_id != crane.character_id:
				continue
			for line: BattleNarrationLine in narrator.opportunity(event, cast):
				if line.text.begins_with("仙鹤攻击你的"):
					crane_line = line.text
	session.configure_combat_random_source(combat)
	_check(crane_line.ends_with("！") and not crane_line.contains("%s") and CombatEncounterCoordinator.take_aborted_total() == 0, "仙鹤攻击你的<limb>！: %s" % crane_line)
	await _leave_fight(tree, session)


func _leave_fight(tree: SceneTree, session: WorldSessionController) -> void:
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
	await tree.physics_frame


## Beside the item lying in `zone_id`, then get.c on it. Whether the player holds one now.
func _take_floor(tree: SceneTree, map: WorldMapController, definition_id: StringName, zone_id: StringName) -> bool:
	var item_id: StringName = map.floor_items.floor_item_of(definition_id, zone_id)
	var view: WorldFloorItemView = null if item_id.is_empty() else map.floor_items.floor_item_view(item_id)
	if view == null or not map.place_player(zone_id, MapPlaces.spot(map, zone_id, view.global_position, 48.0)):
		return false
	await tree.physics_frame
	await tree.physics_frame
	if not map.floor_items.select_floor_item(item_id):
		return false
	map.floor_items.take_selected_floor_item()
	return not _carried(map.session, definition_id).is_empty()


func _service(map: WorldMapController, service_id: StringName) -> WorldService:
	for service: WorldService in map.service_nodes:
		if service.service_id() == service_id:
			return service
	return null


func _full(player: WorldPlayerRuntimeState) -> void:
	player.state.vitality = CharacterResourceState.new(1000000, 1000000, 1000000) # TEST-ONLY: nobody dies here
	player.state.essence = CharacterResourceState.new(1000000, 1000000, 1000000) # TEST-ONLY
	player.state.spirit = CharacterResourceState.new(1000000, 1000000, 1000000) # TEST-ONLY
	player.state.progression.combat_experience = 100000 # TEST-ONLY


func _npc(map: WorldMapController, definition_id: StringName) -> NpcRuntimeState:
	for npc: NpcRuntimeState in map.resident_npcs():
		if npc.definition().definition_id == definition_id and npc.exists_in_map and npc.life_status != CharacterRuntimeLifeStatus.Value.DEAD:
			return npc
	return null


func _all(map: WorldMapController, definition_id: StringName) -> Array[NpcRuntimeState]:
	var found: Array[NpcRuntimeState] = []
	for npc: NpcRuntimeState in map.resident_npcs():
		if npc.definition().definition_id == definition_id and npc.exists_in_map:
			found.append(npc)
	return found


func _carried(session: WorldSessionController, definition_id: StringName) -> StringName:
	var carried := ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, session.player_runtime().character_id)
	for id: StringName in session.inventory_state().direct_children(carried):
		if session.item_instance_index().resolve(id).item_definition_id == definition_id:
			return id
	return &""


## One carried item of these kinds, any of their drawn names.
func _carried_kind(session: WorldSessionController, kinds: Array[StringName]) -> StringName:
	var carried := ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, session.player_runtime().character_id)
	for id: StringName in session.inventory_state().direct_children(carried):
		if kinds.has(ItemContentDefinition.unnamed_id(session.item_instance_index().resolve(id).item_definition_id)):
			return id
	return &""


## TEST-ONLY: an item of `definition_id` in the player's pack.
func _give(session: WorldSessionController, definition_id: StringName) -> StringName:
	var context: MoneyInventoryContext = Finance.session_context(session)
	var content: ItemContentDefinition = GameContent.catalog().item(definition_id)
	var allocation: SessionItemIdAllocationResult = session.item_id_allocator().allocate(context.inventory)
	var item := ItemInstance.new(allocation.item_instance_id, definition_id)
	assert(context.inventory.register_item(item, content.own_weight))
	assert(context.index.register_snapshot(item))
	var destination := InventoryTransferDestination.new(context.endpoint(), true, true, 1000000)
	assert(InventoryTransferService.new().transfer(context.inventory, item.item_instance_id, destination).succeeded)
	return item.item_instance_id


## TEST-ONLY: the item into a holder of its own for a moment (the corpse's container kind).
func _set_aside(session: WorldSessionController, item_id: StringName) -> Dictionary:
	var context: MoneyInventoryContext = Finance.session_context(session)
	var aside := ContainmentEndpoint.new(ContainmentEndpoint.Kind.WORLD, &"choyin.test_aside")
	assert(InventoryTransferService.new().transfer(context.inventory, item_id, InventoryTransferDestination.new(aside, true, true, 1000000)).succeeded)
	return {"id": item_id}


func _put_back(session: WorldSessionController, held: Dictionary) -> void:
	var context: MoneyInventoryContext = Finance.session_context(session)
	assert(InventoryTransferService.new().transfer(context.inventory, held["id"], InventoryTransferDestination.new(context.endpoint(), true, true, 1000000)).succeeded)


## TEST-ONLY: every carried item of `definition_id` gone.
func _drop_all(session: WorldSessionController, definition_id: StringName) -> void:
	var context: MoneyInventoryContext = Finance.session_context(session)
	var id: StringName = _carried(session, definition_id)
	while not id.is_empty():
		var removal: ItemLifecycleResult = ItemLifecycleService.destroy_item(context.inventory, context.stacks, id, ItemLifecycleResult.ChildDisposition.REQUIRE_LEAF, context.owner)
		assert(removal.succeeded and context.index.forget_destroyed_snapshots(removal.removed_instance_ids, context.inventory))
		id = _carried(session, definition_id)


func _check(condition: bool, message: String) -> void:
	_count += 1
	if not condition:
		_failures.append("choyin secrets: " + message)
