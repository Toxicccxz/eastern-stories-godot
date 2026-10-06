extends RefCounted

## Old Pine remainder B: conditions on the heart beat (daemon/condition/snake_poison.c,
## std/char.c), 金银花蛇's hit_ob(), combined items (std/item/combined.c) and their users:
## 蛇药 (snake_drug.c, sold by 杨掌柜) and 金疮药 applied, 飞刀 thrown (THROWING, weapond.c
## throw_weapon) by 黑衣人, the Snow square's three travellers and the player, and 化尸粉
## (obj/dust.c) used by the player and by 黑衣人's killed_enemy() (spy.c).
## TEST-ONLY fixtures are marked where used (resources, amounts); fights draw from the
## session's deterministic seeds.
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const Finance := preload("res://tests/runtime/snow_finance_test.gd")
const NoHeal := preload("res://tests/support/no_heal_condition_effect.gd")
const SNAKE_DRUG: StringName = &"es2:obj/drug/snake_drug"
const HURT_DRUG: StringName = &"es2:obj/drug/hurt_drug"
const DUST: StringName = &"es2:obj/dust"
const SPY_KNIFE: StringName = &"es2:d/oldpine/obj/throwing_knife"
const SNOW_KNIFE: StringName = &"es2:d/snow/npc/obj/throwing_knife"
const POISON: StringName = &"snake_poison"


## Every reset tick is 5: the tick comes on the sixth 2-second beat.
class Fives extends RecoveryCadenceRandomSource:
	func draw_reset_tick() -> int:
		return 5


var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_data()
	_test_record_rules()
	_test_condition_tick()
	_test_apply_rules()
	var session: OldPineWorldSessionController = Work.create_session(tree)
	await tree.process_frame
	_test_square_travellers(session)
	_test_shop_and_hockshop(session)
	await _test_snake(tree, session)
	session.free()
	await tree.process_frame
	session = Work.create_session(tree)
	await tree.process_frame
	await _test_player_throws(tree, session)
	session.free()
	await tree.process_frame
	session = Work.create_session(tree)
	await tree.process_frame
	await _test_spy(tree, session)
	session.free()
	await tree.process_frame
	return {"assertions": _count, "failures": _failures}


func _test_data() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var snake_spawn: NpcSpawnDefinition = catalog.spawn(&"oldpine.stone.venomsnake")
	var spy_spawn: NpcSpawnDefinition = catalog.spawn(&"oldpine.tree.tree1.spy")
	var travellers: NpcSpawnDefinition = catalog.spawn(&"snow.outdoor.square.trav_blades")
	_check(snake_spawn != null and snake_spawn.quantity == 1 and snake_spawn.zone_id == &"oldpine.stone.top", "stone.c: one 金银花蛇 on the stone")
	_check(spy_spawn != null and spy_spawn.quantity == 1 and spy_spawn.zone_id == &"oldpine.tree.canopy", "tree1.c: one 黑衣人 in the pine")
	_check(travellers != null and travellers.quantity == 3 and travellers.zone_id == &"snow.square", "square.c: three 飞刀 travellers")
	var snake: NpcDefinition = catalog.npc(&"oldpine.npc.venomsnake")
	var hit: NpcHitCondition = snake.hit_condition()
	_check(hit != null and hit.condition_id == POISON and hit.duration == 20 and hit.below == 10 and hit.color == ColoredLine.HIG and hit.message == "你觉得被咬中的地方一阵麻痒！", "venomsnake.c hit_ob(): snake_poison 20 below 10, HIG")
	_check(snake.authored_combat_facts().apply_value(&"armor") == 60 and snake.authored_combat_facts().apply_value(&"damage") == 70 and snake.capability_ids() == [&"aggressive_on_player_presence"], "the snake: apply/damage 70, armor 60, aggressive")
	var spy: NpcDefinition = catalog.npc(&"oldpine.npc.spy")
	_check(spy.killed_enemy() != null and spy.killed_enemy().say == "哈哈哈哈哈哈。" and spy.killed_enemy().dissolve_after_ms == 1000 and spy.hit_condition() == null, "spy.c killed_enemy(): laughs, dissolves a second later")
	_check(NpcBerserk.applies_to(spy) and spy.bellicosity() == 2000, "黑衣人 is not aggressive but goes berserk (bellicosity 2000 over score 400)")
	var carried: Array[String] = []
	for entry: NpcLoadoutEntry in spy.loadout_entries():
		carried.append("%s %d %d" % [entry.item_definition_id, entry.quantity, entry.equipment_intent])
	_check(carried == ["%s 30 %d" % [SPY_KNIFE, NpcLoadoutEntry.EquipmentIntent.WIELD_PRIMARY], "es2:d/oldpine/npc/obj/black_cloth 1 %d" % NpcLoadoutEntry.EquipmentIntent.WEAR, "%s 30 %d" % [DUST, NpcLoadoutEntry.EquipmentIntent.NONE]], "黑衣人 wields thirty 飞刀, wears 夜行衣, carries thirty 化尸粉: " + str(carried))
	var drug: ItemContentDefinition = catalog.item(SNAKE_DRUG)
	_check(drug.is_stack and drug.base_unit == "份" and drug.stack_base_weight == 0 and drug.default_amount == 1 and drug.value == 1000 and drug.apply == &"snake_drug" and drug.currency_definition() == null, "蛇药: combined, 份, base_weight 0 (base_weiht typo), value 1000, applied")
	var dust: ItemContentDefinition = catalog.item(DUST)
	_check(dust.is_stack and dust.dissolves and dust.stack_base_weight == 1 and dust.value == 1000, "化尸粉: combined, dissolves corpses")
	_check(catalog.item(HURT_DRUG).apply == &"hurt_drug" and not catalog.item(HURT_DRUG).is_stack, "金疮药 is applied, one object")
	var knife: ItemContentDefinition = catalog.item(SNOW_KNIFE)
	_check(knife.is_stack and knife.default_amount == 100 and knife.weapon_skill_type == &"throwing" and knife.weapon_damage == 20 and knife.base_unit == "把" and knife.stack_base_weight == 300 and knife.value == 0, "Snow's 飞刀: a hundred, throwing 20, no value")
	_check(catalog.item(SPY_KNIFE).default_amount == 1 and catalog.item(SPY_KNIFE).is_stack, "Old Pine's 飞刀 is made one at a time")
	var herbalist: VendorDefinition = catalog.vendor(&"snow.vendor.herbalist")
	_check(herbalist.item_definition_id("snake drug") == SNAKE_DRUG and herbalist.price("snake drug", drug) == 1000, "杨掌柜 sells 蛇药 for its value")
	var throws: CombatActionSet = catalog.combat_actions().weapon_action_set(&"throwing")
	var throw_action: CombatActionDefinition = null if throws == null or throws.actions().is_empty() else throws.actions()[0]
	_check(throw_action != null and throws.actions().size() == 1 and throw_action.legacy_action_text == "$N将$w对准$n的$l射了过去" and throw_action.post_action_policy_id == CombatPostActionIds.THROW_WEAPON, "throwing.c's verb throw runs throw_weapon")


func _test_record_rules() -> void:
	var errors: Array[String] = []
	NpcHitCondition.from_record(ContentRecordReader.new({"condition": "snake_poison", "duration": 0, "below": 10, "message": "x"}, "t", errors))
	_check(not errors.is_empty(), "a hit_ob needs a positive duration")
	errors.clear()
	NpcHitCondition.from_record(ContentRecordReader.new({"condition": "snake_poison", "duration": 20, "below": 10, "message": "x", "color": "HIB"}, "t", errors))
	_check(not errors.is_empty(), "a hit_ob's color is one ColoredLine knows")
	errors.clear()
	NpcKilledEnemy.from_record(ContentRecordReader.new({}, "t", errors))
	_check(not errors.is_empty(), "killed_enemy needs a say or a dissolve")
	errors.clear()
	CombatActionDefinition.from_record(ContentRecordReader.new({"id": "bash", "action": "x", "damage_type": "挫伤", "post_action": "spin_weapon"}, "t", errors), "w/")
	_check(not errors.is_empty(), "a post_action that is not ported is refused")
	errors.clear()
	var item: Dictionary = {"id": "t", "legacy_sources": ["t.c"], "name": "t", "aliases": ["t"], "weight": 1, "combined": {"base_unit": "份", "base_weight": 1, "amount": 1}}
	ItemContentDefinition.from_record(ContentRecordReader.new(item, "t", errors))
	_check(not errors.is_empty(), "a combined item takes its weight from base_weight")
	errors.clear()
	item.erase("weight")
	item["apply"] = "elixir"
	ItemContentDefinition.from_record(ContentRecordReader.new(item, "t", errors))
	_check(not errors.is_empty(), "an unknown apply is refused")


## std/char.c heart_beat(): on the tick update_condition() runs, then heal_up() unless
## a condition said CND_NO_HEAL_UP. snake_poison.c wounds kee 10 and sen 10, prints its
## line and goes on at 0 once more (duration < 1 ends it after the hit).
func _test_condition_tick() -> void:
	var state: CharacterState = _state()
	state.conditions.add_or_replace_duration(POISON, 1)
	var cadence := PlayerRecoveryCadence.new(Fives.new(), true)
	var busy := ActionBusyState.new()
	_check(cadence.advance(10.0, state, busy).conditions_updated == 0 and state.vitality.effective == 100, "five beats count down: nothing yet")
	var first: PlayerRecoveryCadenceResult = cadence.advance(2.0, state, busy)
	_check(first.opportunities == 1 and first.conditions_updated == 1 and _remaining(state) == 0, "the sixth beat is the tick: poison 1 -> 0, still there")
	_check(first.lines.size() == 1 and first.lines[0].text == "你中的蛇毒发作了！" and first.lines[0].color == ColoredLine.HIG, "the line, in HIG")
	_check(state.vitality.effective == 90 and state.spirit.current == 90, "kee wounded by 10, sen damaged by 10 (nothing to heal on: no food): eff %d" % state.vitality.effective)
	var second: PlayerRecoveryCadenceResult = cadence.advance(12.0, state, busy)
	_check(second.conditions_updated == 1 and not state.conditions.has_condition(POISON) and second.lines.size() == 1, "at 0 it strikes once more and ends")
	var third: PlayerRecoveryCadenceResult = cadence.advance(12.0, state, busy)
	_check(third.opportunities == 1 and third.conditions_updated == 0 and third.lines.is_empty(), "nothing left")
	# CND_NO_HEAL_UP skips heal_up() on that tick.
	var system := ConditionSystem.new()
	system.register_effect(NoHeal.new())
	var held: CharacterState = _state()
	held.vitality.current = 50
	held.conditions.add_or_replace_duration(NoHeal.TEST_CONDITION_ID, 3)
	var no_heal: PlayerRecoveryCadenceResult = PlayerRecoveryCadence.new(Fives.new(), true, system).advance(12.0, held, ActionBusyState.new())
	_check(no_heal.conditions_updated == 1 and no_heal.last_update_count == 0 and held.vitality.current == 50, "CND_NO_HEAL_UP: no heal_up() that tick")
	# A tick that leaves the character below zero ends the advance there.
	var dying: CharacterState = _state()
	dying.vitality.effective = 5
	dying.conditions.add_or_replace_duration(POISON, 9)
	var died: PlayerRecoveryCadenceResult = PlayerRecoveryCadence.new(Fives.new(), true).advance(120.0, dying, ActionBusyState.new())
	_check(died.conditions_updated == 1 and dying.life_threshold() == CharacterState.LifeThreshold.DEAD and _remaining(dying) == 8, "below zero effective kee: the advance stops for the fall")


## snake_drug.c do_apply() and hurt_drug.c apply_medicine().
func _test_apply_rules() -> void:
	var state: CharacterState = _state()
	var none: ItemApplyFunctions.Result = ItemApplyFunctions.apply(&"snake_drug", state, false)
	_check(not none.accepted and none.lines == ["你没有中蛇毒。"] and not none.used_up, "not poisoned: 你没有中蛇毒。")
	state.conditions.add_or_replace_duration(POISON, 2)
	var dose: ItemApplyFunctions.Result = ItemApplyFunctions.apply(&"snake_drug", state, true)
	_check(dose.accepted and dose.used_up and _remaining(state) == 1 and dose.lines == ["你服下蛇药，顿时感觉好多了。但是你中的蛇毒并没有完全清除。", "体内的蛇毒还剩 1 分，每服一剂解去一分。"], "one dose lowers it by one, also in a fight; what is left is said (modern fixes): " + str(dose.lines))
	dose = ItemApplyFunctions.apply(&"snake_drug", state, false)
	_check(dose.accepted and _remaining(state) == 0 and state.conditions.has_condition(POISON) and dose.lines == ["你服下蛇药，顿时感觉好多了。你终于清除了体内所有的蛇毒！"], "the last one: cleared (the condition stays at 0)")
	var hurt: CharacterState = _state()
	var unhurt: ItemApplyFunctions.Result = ItemApplyFunctions.apply(&"hurt_drug", hurt, false)
	_check(not unhurt.accepted and unhurt.lines == ["你没有受伤啊?"], "unhurt: 你没有受伤啊?")
	hurt.vitality.effective = 50
	var fighting: ItemApplyFunctions.Result = ItemApplyFunctions.apply(&"hurt_drug", hurt, true)
	_check(not fighting.accepted and fighting.lines == ["战斗中不能用药治伤!"] and hurt.vitality.effective == 50, "not in a fight")
	var applied: ItemApplyFunctions.Result = ItemApplyFunctions.apply(&"hurt_drug", hurt, false)
	_check(applied.accepted and applied.used_up and hurt.vitality.effective == 70 and applied.lines == ["你敷上金疮药 ."], "20 eff_kee at most")
	hurt.vitality.effective = 95
	ItemApplyFunctions.apply(&"hurt_drug", hurt, false)
	_check(hurt.vitality.effective == 100, "min(20, max - eff)")


## square.c: three travellers with a hundred 飞刀 each, wielded.
func _test_square_travellers(session: OldPineWorldSessionController) -> void:
	var outdoor: WorldMapController = session.world_map_of(&"snow.outdoor")
	var amounts: Array[int] = []
	for npc: NpcRuntimeState in outdoor.npc_runtimes():
		if npc.definition().definition_id != &"snow.npc.trav_blade":
			continue
		var weapon: EquippedWeaponRef = npc.character_state.equipment.primary_weapon()
		amounts.append(-1 if weapon == null else session.stack_collection().stack_state(weapon.instance_id).amount)
	_check(amounts == [100, 100, 100], "three travellers wield a hundred 飞刀 each: " + str(amounts))


## buy.c of a combined item merges into the buyer's stack; hockshop.c values a stack by
## query("value") whatever its amount, and 飞刀 has none; drop.c destructs what is
## worth nothing, a split part too.
func _test_shop_and_hockshop(session: OldPineWorldSessionController) -> void:
	var money: MoneyInventoryContext = Finance.session_context(session)
	Finance.add_money(money, CurrencyDenomination.Value.SILVER, 30, &"test.venom.silver") # TEST-ONLY
	var vendor: VendorDefinition = GameContent.catalog().vendor(&"snow.vendor.herbalist")
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var bought: Array[StringName] = []
	for _i: int in range(2):
		var purchase: VendorPurchaseResult = VendorPurchaseService.buy(vendor, "snake drug", GameContent.catalog(), money,
			session.food_collection(), session.liquid_collection(), session.item_id_allocator(), player.maximum_encumbrance)
		_check(purchase.delivered and purchase.price == 1000, "蛇药 bought for 1000")
		bought.append(purchase.item_id)
	var drugs: Array[StringName] = _carried(session, player.character_id, SNAKE_DRUG)
	_check(drugs.size() == 1 and drugs[0] == bought[1] and session.stack_collection().stack_state(drugs[0]).amount == 2, "the second pack merges with the first: one stack of two")
	_check(Finance.amount(money, CurrencyDenomination.Value.SILVER) == 10, "twenty taels paid")
	var quote: HockshopValuationResult = HockshopValuation.appraise(money, session.food_collection(), session.liquid_collection(), drugs[0])
	_check(quote.outcome == HockshopValuationResult.Outcome.SELLABLE and quote.source_value == 1000 and quote.actual_payout == 800, "the hockshop values the stack as one 蛇药 (query(\"value\"))")
	var knives: StringName = _give(session, SNOW_KNIFE, 10) # TEST-ONLY
	var worthless: HockshopValuationResult = HockshopValuation.appraise(money, session.food_collection(), session.liquid_collection(), knives)
	_check(worthless.outcome == HockshopValuationResult.Outcome.WORTHLESS, "飞刀 is worth nothing to the hockshop")
	var map: WorldMapController = session.active_map() as WorldMapController
	var dropped: ItemHandlingResult = map.drop_item(knives, 3)
	_check(dropped.done() and dropped.destroyed and session.stack_collection().stack_state(knives).amount == 7, "drop 3 of 10 飞刀: split off and destructed, worth nothing (drop.c)")
	var rows: Array[PlayerInventoryRowProjection] = session.player_inventory_rows()
	var knife_row: PlayerInventoryRowProjection = null
	for row: PlayerInventoryRowProjection in rows:
		if row.item_instance_id == knives:
			knife_row = row
	_check(knife_row != null and knife_row.amount == 7 and knife_row.category == ItemContentDefinition.CATEGORY_WEAPON, "the inventory row counts the stack")
	session.shared_ui().show_inventory(rows)
	var panel: PlayerInventoryPanel = session.shared_ui().inventory_panel
	_check(_row_has(panel, knives, "Amount") and _row_has(panel, drugs[0], "Amount") and _row_has(panel, drugs[0], "Apply"), "a stack gets an amount box; 蛇药 a 使用 button")


## The snake bites: hit_ob() poisons; outside the fight it strikes on the beat; 蛇药
## lowers it; Save keeps it; 化尸粉 dissolves the snake's corpse.
func _test_snake(tree: SceneTree, session: OldPineWorldSessionController) -> void:
	_check(session.handoff_to(&"oldpine.stone", &"oldpine.stone.top", &"oldpine.stone.top", &"oldpine.stone.top.landing").succeeded(), "up on the stone")
	await tree.physics_frame
	var map: WorldMapController = session.active_map() as WorldMapController
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var snake: NpcRuntimeState = null
	for npc: NpcRuntimeState in map.npc_runtimes():
		if npc.definition().definition_id == &"oldpine.npc.venomsnake":
			snake = npc
	_check(snake != null, "金银花蛇 is on the stone")
	if snake == null:
		return
	var natural_kee: int = player.state.vitality.maximum
	player.state.vitality = CharacterResourceState.new(5000, 5000, 5000) # TEST-ONLY: outlast the snake
	map.aggression_adapter().enter_player_presence(snake, player, true)
	var started: Array[CombatSliceInitiationResult] = map.process_pending_aggression()
	_check(started.size() == 1 and started[0].outcome == CombatSliceInitiationResult.Outcome.COMPLETED, "the snake attacks")
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	var ui: BattlePresentationController = session.get_node("BattlePresentationLayer/BattleSurface")
	for _round: int in range(80):
		if player.state.conditions.has_condition(POISON) or not coordinator.has_active_encounter():
			break
		coordinator.advance_scheduler(1.0)
		ui.refresh_projection()
	_check(_remaining(player.state) == 20, "a bite poisons: snake_poison 20")
	_check(player.relationship.last_damage_from_id == snake.character_id, "the snake is last_damage_from")
	_check(ui.log_panel._text.get_parsed_text().contains("你觉得被咬中的地方一阵麻痒！"), "the bite's line in the battle log")
	for _round: int in range(5):
		coordinator.advance_scheduler(1.0)
	_check(_remaining(player.state) == 20, "no beat in a fight (the world stands still): still 20")
	snake.character_state.vitality = CharacterResourceState.new(-1, -1, 260) # TEST-ONLY: the snake dies
	for _round: int in range(10):
		if not coordinator.has_active_encounter():
			break
		coordinator.advance_scheduler(1.0)
	_check(not coordinator.has_active_encounter() and snake.life_status == CharacterRuntimeLifeStatus.Value.DEAD, "the snake dies")
	await tree.process_frame
	player.state.vitality = CharacterResourceState.new(natural_kee, natural_kee, natural_kee) # TEST-ONLY: max_kee as Save derives it
	session.shared_ui().refresh_exploration()
	_check(session.shared_ui().player_vitality_text.text.ends_with("蛇毒"), "the HUD names the poison: " + session.shared_ui().player_vitality_text.text)
	var before: int = _remaining(player.state)
	var beat: PlayerRecoveryCadenceResult = session.advance_player_recovery(30.0)
	# Fifteen beats hold one tick at least (5 + random(10)); a low countdown left from
	# before the fight can give two.
	_check(beat.conditions_updated >= 1 and _remaining(player.state) == before - beat.conditions_updated, "within fifteen beats the poison strikes: %d -> %d" % [before, _remaining(player.state)])
	_check(Array(session.shared_ui().log_lines()).has("你中的蛇毒发作了！"), "its line in the log")
	var work: RefCounted = Work.new()
	await work.round_trip(tree, session, Work.capture(session), "poisoned")
	_check(work._failures.is_empty(), "Save/Continue keeps the poison: " + str(work._failures))
	var snapshot: GameSaveSnapshot = Work.capture(session)
	var saved: Array[String] = []
	for condition: RefCounted in snapshot.player.character.conditions:
		saved.append("%s %d" % [condition.get("condition_id"), condition.get("remaining")])
	_check(saved == ["snake_poison %d" % _remaining(player.state)], "the save holds it: " + str(saved))
	# 蛇药, one dose at a time.
	var drug: StringName = _give(session, SNAKE_DRUG, 2) # TEST-ONLY: with the two bought, four
	var left: int = _remaining(player.state)
	_check(map.apply_item(drug) and _remaining(player.state) == left - 1 and session.stack_collection().stack_state(drug).amount == 3, "one dose: poison - 1, three packs left")
	_check(Array(session.shared_ui().log_lines()).has("你服下蛇药，顿时感觉好多了。但是你中的蛇毒并没有完全清除。"), "snake_drug.c's lines")
	player.state.conditions.add_or_replace_duration(POISON, 1) # TEST-ONLY
	CombinedStackService.set_amount(session.stack_collection(), session.inventory_state(), drug, 1) # TEST-ONLY
	_check(map.apply_item(drug) and _remaining(player.state) == 0 and _carried(session, player.character_id, SNAKE_DRUG).is_empty(), "the last pack clears it and is gone")
	_check(Array(session.shared_ui().log_lines()).has("你服下蛇药，顿时感觉好多了。你终于清除了体内所有的蛇毒！"), "cleared")
	beat = session.advance_player_recovery(30.0)
	_check(beat.conditions_updated == 1 and not player.state.conditions.has_condition(POISON), "at 0 it strikes once more, then it is gone (snake_poison.c)")
	_check(not map.apply_item(_give(session, SNAKE_DRUG, 1)), "not poisoned: refused, the pack kept")
	# 金疮药.
	player.state.vitality.effective = natural_kee - 10 # TEST-ONLY
	var medicine: StringName = _give(session, HURT_DRUG, 1)
	_check(map.apply_item(medicine) and player.state.vitality.effective == natural_kee and not session.inventory_state().is_registered(medicine), "金疮药 cures 10 of the 10 missing and is used up")
	# 化尸粉 on the snake's corpse.
	var corpse: CorpseState = null
	for candidate: CorpseState in map.corpse_states():
		if candidate.victim_display_name == "金银花蛇":
			corpse = candidate
	_check(corpse != null and map.select_corpse(corpse.corpse_item_instance_id), "the snake's corpse, selected")
	var dust: StringName = _give(session, DUST, 2) # TEST-ONLY
	_check(map.dissolvable_corpse_name() == "金银花蛇", "化尸粉 is offered on it")
	session.shared_ui().show_inventory(session.player_inventory_rows())
	_check(_row_has(session.shared_ui().inventory_panel, dust, "Dissolve"), "the 化尸粉 row has 化去金银花蛇的尸体")
	_check(map.dissolve_selected_corpse(dust), "dissolve corpse")
	_check(map.corpse_states().is_empty() and session.stack_collection().stack_state(dust).amount == 1, "the corpse is gone, one 化尸粉 used")
	_check(Array(session.shared_ui().log_lines()).has("你用指甲挑了一点化尸粉在金银花蛇的尸体上，只听见一阵「嗤嗤」声响带著一股可怕的恶臭，金银花蛇的尸体只剩下一滩黄水。"), "dust.c's line")
	_check(not map.dissolve_selected_corpse(dust), "nothing selected any more: no")
	work = Work.new()
	await work.round_trip(tree, session, Work.capture(session), "a dissolved corpse")
	_check(work._failures.is_empty(), "Save/Continue after the corpse is gone: " + str(work._failures))


## The player throws 飞刀 at 黑衣人: one per attack; the last is unwielded with
## weapond.c's line, then the player fights bare-handed.
func _test_player_throws(tree: SceneTree, session: OldPineWorldSessionController) -> void:
	_check(session.handoff_to(&"oldpine.tree", &"oldpine.tree.canopy", &"oldpine.tree.canopy", &"oldpine.tree.canopy.tree1_landing").succeeded(), "up the pine")
	await tree.physics_frame
	var map: WorldMapController = session.active_map() as WorldMapController
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var spy: NpcRuntimeState = _find(map, &"oldpine.npc.spy")
	player.state.vitality = CharacterResourceState.new(5000, 5000, 5000) # TEST-ONLY
	var knives: StringName = _give(session, SNOW_KNIFE, 2) # TEST-ONLY: two
	_check(session.wield_player_item(knives).succeeded, "the player wields 飞刀")
	map.select_npc(spy.character_id)
	_check(map.attack_selected().outcome == CombatSliceInitiationResult.Outcome.COMPLETED, "the player attacks 黑衣人")
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	var ui: BattlePresentationController = session.get_node("BattlePresentationLayer/BattleSurface")
	for _round: int in range(40):
		if not session.inventory_state().is_registered(knives) or not coordinator.has_active_encounter():
			break
		coordinator.advance_scheduler(1.0)
		ui.refresh_projection()
	var text: String = ui.log_panel._text.get_parsed_text()
	_check(not session.inventory_state().is_registered(knives) and player.state.equipment.primary_weapon() == null, "two throws, two knives: gone and unwielded")
	_check(text.contains("你将飞刀对准黑衣人的") and text.contains("你的飞刀用完了！"), "the throw and the last one's line: " + text.right(300))


## 黑衣人 throws his thirty, one by one; with none left he fights bare-handed. When he
## kills the player he laughs and a second later dissolves the body with 化尸粉.
func _test_spy(tree: SceneTree, session: OldPineWorldSessionController) -> void:
	_check(session.handoff_to(&"oldpine.tree", &"oldpine.tree.canopy", &"oldpine.tree.canopy", &"oldpine.tree.canopy.tree1_landing").succeeded(), "up the pine")
	await tree.physics_frame
	var map: WorldMapController = session.active_map() as WorldMapController
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var spy: NpcRuntimeState = _find(map, &"oldpine.npc.spy")
	var knife: EquippedWeaponRef = spy.character_state.equipment.primary_weapon()
	var stacks: CombinedStackCollection = session.stack_collection()
	_check(knife != null and stacks.stack_state(knife.instance_id).amount == 30, "黑衣人 wields thirty 飞刀")
	var dust: Array[StringName] = _carried(session, spy.character_id, DUST)
	_check(dust.size() == 1 and stacks.stack_state(dust[0]).amount == 30, "and carries thirty 化尸粉")
	player.state.vitality = CharacterResourceState.new(5000, 5000, 5000) # TEST-ONLY
	map.select_npc(spy.character_id)
	_check(map.attack_selected().outcome == CombatSliceInitiationResult.Outcome.COMPLETED, "the player attacks 黑衣人")
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	var ui: BattlePresentationController = session.get_node("BattlePresentationLayer/BattleSurface")
	for _round: int in range(30):
		if stacks.stack_state(knife.instance_id).amount < 28:
			break
		coordinator.advance_scheduler(1.0)
		ui.refresh_projection()
	_check(stacks.stack_state(knife.instance_id).amount < 30 and ui.log_panel._text.get_parsed_text().contains("黑衣人将飞刀对准你的"), "each throw uses one: %d left" % stacks.stack_state(knife.instance_id).amount)
	CombinedStackService.set_amount(stacks, session.inventory_state(), knife.instance_id, 1) # TEST-ONLY: the last one
	for _round: int in range(30):
		if not session.inventory_state().is_registered(knife.instance_id):
			break
		coordinator.advance_scheduler(1.0)
	_check(not session.inventory_state().is_registered(knife.instance_id) and spy.character_state.equipment.primary_weapon() == null, "the last 飞刀 thrown: he is bare-handed")
	ui.refresh_projection()
	_check(not ui.log_panel._text.get_parsed_text().contains("飞刀用完了"), "his own 用完了 line is told to him, not the player")
	player.state.vitality = CharacterResourceState.new(0, 0, 5000) # TEST-ONLY: the next blow fells the player
	player.state.progression.combat_experience = 0
	for _round: int in range(200):
		if player.life_status == CharacterRuntimeLifeStatus.Value.DEAD:
			break
		coordinator.advance_scheduler(1.0)
	_check(player.life_status == CharacterRuntimeLifeStatus.Value.DEAD, "黑衣人 kills the player")
	_check(Array(session.shared_ui().log_lines()).has("黑衣人说道：哈哈哈哈哈哈。"), "killed_enemy(): he laughs, and the dying player hears it")
	var corpse_ids: Array[StringName] = []
	for corpse: CorpseState in map.corpse_states():
		corpse_ids.append(corpse.corpse_item_instance_id)
	_check(corpse_ids.size() == 1, "the player's corpse lies in the pine")
	# TEST-ONLY: world time only as the test steps it; frames just draw the death screen.
	session.set_process(false)
	var overlay: PlayerLifeOverlay = session.shared_ui().life_overlay
	# process_frame comes before that frame's _process(): the screen draws in the second.
	await tree.process_frame
	await tree.process_frame
	_check(overlay.text().contains("你的尸体和随身物品留在：老松岭 · 大松树上"), "the death screen says where the corpse lies: " + overlay.text())
	map.advance_npc_heartbeat(0.5)
	_check(map.corpse_states().size() == 1, "half a second: not yet")
	map.advance_npc_heartbeat(0.6)
	_check(map.corpse_states().is_empty() and not session.inventory_state().is_registered(corpse_ids[0]) and stacks.stack_state(dust[0]).amount == 29, "a second later the corpse and all in it are dissolved; 29 化尸粉 left")
	await tree.process_frame
	await tree.process_frame
	_check(overlay.text().contains("你的尸体已经不在了。") and not overlay.text().contains("留在"), "and the death screen no longer sends the player back for it: " + overlay.text())
	session.set_process(true)


func _state() -> CharacterState:
	return CharacterState.new(
		CharacterBaseAttributes.new(0, 0, 0, 0, 0, 0, 30),
		CharacterResourceState.new(100, 100, 100),
		CharacterResourceState.new(100, 100, 100),
		CharacterResourceState.new(100, 100, 100),
	)


func _remaining(state: CharacterState) -> int:
	var payload: DurationConditionPayload = state.conditions.get_condition(POISON) as DurationConditionPayload
	return -1 if payload == null else payload.remaining


## TEST-ONLY: a new item of `definition_id` (a stack of `amount`) in the player's hands, merged.
func _give(session: OldPineWorldSessionController, definition_id: StringName, amount: int) -> StringName:
	var context: MoneyInventoryContext = Finance.session_context(session)
	var content: ItemContentDefinition = GameContent.catalog().item(definition_id)
	var allocation: SessionItemIdAllocationResult = session.item_id_allocator().allocate(context.inventory)
	var item := ItemInstance.new(allocation.item_instance_id, definition_id)
	assert(context.inventory.register_item(item, 0 if content.is_stack else content.own_weight))
	assert(context.index.register_snapshot(item))
	var destination := InventoryTransferDestination.new(context.endpoint(), true, true, 1000000)
	if not content.is_stack:
		assert(InventoryTransferService.new().transfer(context.inventory, item.item_instance_id, destination).succeeded)
		return item.item_instance_id
	assert(CombinedStackService.register_stack(context.stacks, context.inventory, item, content.stack_definition(), amount).accepted)
	var merged: CombinedStackMergeResult = CombinedStackService.transfer_and_merge(context.stacks, context.inventory, item.item_instance_id, destination, null, null, context.owner)
	assert(context.index.forget_destroyed_snapshots(merged.absorbed_instance_ids, context.inventory))
	return merged.surviving_instance_id


func _carried(session: OldPineWorldSessionController, character_id: StringName, definition_id: StringName) -> Array[StringName]:
	var found: Array[StringName] = []
	for item_id: StringName in session.inventory_state().direct_children(ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, character_id)):
		var item: ItemInstance = session.item_instance_index().resolve(item_id)
		if item != null and item.item_definition_id == definition_id:
			found.append(item_id)
	return found


func _find(map: WorldMapController, definition_id: StringName) -> NpcRuntimeState:
	for npc: NpcRuntimeState in map.npc_runtimes():
		if npc.definition().definition_id == definition_id:
			return npc
	return null


## The inventory panel's row for `item_id` has a child control named `control`.
func _row_has(panel: PlayerInventoryPanel, item_id: StringName, control: String) -> bool:
	var rows: Array[PlayerInventoryRowProjection] = panel.visible_rows()
	for index: int in rows.size():
		if rows[index].item_instance_id == item_id:
			return panel.row_container.get_child(index).find_child(control, true, false) != null
	return false


func _check(condition: bool, label: String) -> void:
	_count += 1
	if not condition:
		_failures.append(label)
