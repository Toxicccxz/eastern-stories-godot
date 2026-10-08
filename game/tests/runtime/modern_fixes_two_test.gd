extends RefCounted

## Modern fixes II (owner, 2026-10-08, DECISIONS「积压问题的处理」), in Snow: max kee
## follows max_force at once (A7); 冥思 without 基本咒文 says why; how strong an NPC
## looks (目标详情) and 切磋 with one clearly stronger asked first (A10); giving away
## what one has equipped or a large sum asked first, a donation not; on the battle panel
## 运功疗伤 greyed with heal.c's line, the exerts' and spells' hover, no "你的目标是X。";
## the player lying unconscious for pacing.json's player_wake_seconds while the world
## lives damage.c's whole delay (A9). TEST-ONLY fixtures are marked.
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const Finance := preload("res://tests/runtime/snow_finance_test.gd")
const SouthRoad := preload("res://tests/runtime/snow_south_road_test.gd")
const TRAINEE: StringName = &"snow.school2.trainee.1.character"
const GUARD: StringName = &"snow.school1.guard.1.character"
const KEEPER: StringName = &"snow.temple.keeper.1.character"

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_bands()
	var session: WorldSessionController = Work.create_session(tree)
	await tree.process_frame
	session.set_process(false)
	session.configure_npc_ambience_random_source(SouthRoad.Still.new()) # TEST-ONLY: nobody chats or wanders
	_check(session.handoff_to(&"snow.outdoor", &"snow.square", &"snow.square", &"snow.square.inn_entry").succeeded(), "out on the square")
	for frame: int in range(5):
		await tree.process_frame
	var map: WorldMapController = session.active_map() as WorldMapController
	_test_max_kee(session)
	_test_cultivation_hint(session)
	_test_strength(session, map)
	_test_give(session, map)
	_test_battle_actions(session, map)
	_test_quick_wake(session, map)
	session.free()
	await tree.process_frame
	return {"assertions": _count, "failures": _failures}


## RelativeStrength: four times and 500 more is clearly stronger; twice and 100 more
## stronger; the same the other way; small differences near zero are even.
func _test_bands() -> void:
	_check(RelativeStrength.band(0, 500) == RelativeStrength.Band.MUCH_STRONGER, "0 vs 500: clearly stronger")
	_check(RelativeStrength.band(0, 499) == RelativeStrength.Band.STRONGER, "0 vs 499: stronger")
	_check(RelativeStrength.band(0, 99) == RelativeStrength.Band.EVEN, "0 vs 99: even")
	_check(RelativeStrength.band(1000, 4000) == RelativeStrength.Band.MUCH_STRONGER, "1000 vs 4000: clearly stronger")
	_check(RelativeStrength.band(1000, 3999) == RelativeStrength.Band.STRONGER, "1000 vs 3999: stronger")
	_check(RelativeStrength.band(1000, 1000) == RelativeStrength.Band.EVEN, "even")
	_check(RelativeStrength.band(2000, 1000) == RelativeStrength.Band.WEAKER, "2000 vs 1000: weaker")
	_check(RelativeStrength.band(4000, 1000) == RelativeStrength.Band.MUCH_WEAKER, "4000 vs 1000: far weaker")
	_check(RelativeStrength.clearly_stronger(0, 500) and not RelativeStrength.clearly_stronger(0, 499), "the confirm threshold")


## A7: exercise raises max_force from 3 to 4, and max kee gains its quarter at once.
func _test_max_kee(session: WorldSessionController) -> void:
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var state: CharacterState = player.state
	# TEST-ONLY: what 柳淳风's lessons and enable give.
	state.skills.set_raw_level(&"force", 10)
	state.skills.set_raw_level(&"fonxanforce", 10)
	state.skills.map_skill(&"force", &"fonxanforce")
	state.recovery.inner_force.maximum = 3 # TEST-ONLY: just below a quarter's step
	state.recovery.inner_force.current = 6
	_check(state.vitality.maximum == CharacterDerivedValues.human_maximum_vitality(player.facts.age, 3), "max kee before: no quarter of 3")
	var result: CultivationResult = session.martial_arts().exercise(30)
	_check(result != null and result.completion == CultivationResult.Completion.MAXIMUM_INCREASED and state.recovery.inner_force.maximum == 4, "exercise: max_force 4")
	_check(state.vitality.maximum == CharacterDerivedValues.human_maximum_vitality(player.facts.age, 4), "max kee follows at once (A7): %d" % state.vitality.maximum)
	state.vitality.current = state.vitality.maximum # TEST-ONLY: rested


## 冥思 and 修行 with no 基本咒文 / 基本法术: the bottleneck, then why.
func _test_cultivation_hint(session: WorldSessionController) -> void:
	var arts: PlayerMartialArts = session.martial_arts()
	var state: CharacterState = session.player_runtime().state
	_check(arts.cultivation_hint(SkillIds.SPELLS) == "需要先学会基本咒文，法力才能增长。", "the page's hint for 冥思")
	var result: CultivationResult = arts.meditate(30)
	_check(result != null and result.success and ColoredLine.texts(arts.last_lines).back() == "需要先学会基本咒文，法力才能增长。", "冥思 says why: %s" % [ColoredLine.texts(arts.last_lines)])
	state.skills.set_raw_level(SkillIds.SPELLS, 1) # TEST-ONLY
	_check(arts.cultivation_hint(SkillIds.SPELLS).is_empty(), "with 基本咒文 no hint")
	state.skills.set_raw_level(SkillIds.SPELLS, 0)
	state.spirit.current = state.spirit.maximum # TEST-ONLY: rested


## 目标详情 says how strong the NPC looks; 切磋 with one clearly stronger is asked first.
func _test_strength(session: WorldSessionController, map: WorldMapController) -> void:
	var hud: SharedGameplayUI = session.shared_ui()
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	var trainee: NpcRuntimeState = map.find_resident_npc(TRAINEE)
	_select(map, hud, &"snow.school2", trainee)
	_check(map.inspect_selected() and hud.inspection_text.text.ends_with("他看起来比你强。"), "a trainee looks stronger: " + hud.inspection_text.text)
	_check(map.selected_spar_risk() == WorldMapController.SparRisk.NONE, "but not clearly: no question")
	trainee.character_state.progression.combat_experience = 3000 # TEST-ONLY
	_check(map.inspect_selected() and hud.inspection_text.text.ends_with("他看起来比你强得多。"), "3000: much stronger")
	_check(map.selected_spar_risk() == WorldMapController.SparRisk.STRONGER, "a clearly stronger, unarmed partner")
	hud.spar_button.pressed.emit()
	var text: String = hud.confirm_prompt.message.text
	_check(hud.is_asking() and not coordinator.has_active_encounter() and text.begins_with("武馆弟子看起来比你强得多：") and text.ends_with("确定要和武馆弟子切磋吗？"), "asked first: " + text)
	hud.confirm_prompt.cancel_button.pressed.emit()
	_check(not coordinator.has_active_encounter(), "取消: no spar")
	trainee.character_state.progression.combat_experience = 100
	var guard: NpcRuntimeState = map.find_resident_npc(GUARD)
	_select(map, hud, &"snow.school1", guard)
	hud.spar_button.pressed.emit()
	text = hud.confirm_prompt.message.text
	_check(hud.is_asking() and text.begins_with("刘安禄看起来比你强得多，而且有人手持兵刃："), "刘安禄: armed and much stronger: " + text)
	hud.confirm_prompt.cancel_button.pressed.emit()
	session.player_runtime().state.progression.combat_experience = 100000 # TEST-ONLY
	_check(map.inspect_selected() and hud.inspection_text.text.ends_with("他看起来远不如你。"), "seen from 100000 exp: far weaker")
	hud.spar_button.pressed.emit()
	_check(hud.is_asking() and hud.confirm_prompt.message.text.begins_with("刀剑无眼："), "his blade alone still asks")
	hud.confirm_prompt.cancel_button.pressed.emit()
	session.player_runtime().state.progression.combat_experience = 0
	hud._presentation_layout.close_panel()


## 给: the worn 布衣 and a 黄金 are asked first; silver is not; the temple keeper's
## donation box is not asked about gold.
func _test_give(session: WorldSessionController, map: WorldMapController) -> void:
	var hud: SharedGameplayUI = session.shared_ui()
	var trainee: NpcRuntimeState = map.find_resident_npc(TRAINEE)
	_select(map, hud, &"snow.school2", trainee)
	var worn: StringName = &""
	for row: PlayerInventoryRowProjection in session.player_inventory_rows():
		if row.equipment_slot != PlayerInventoryRowProjection.EquipmentSlot.NONE:
			worn = row.item_instance_id
	_check(not worn.is_empty(), "the player wears something")
	hud._give_item(worn, 0)
	var text: String = hud.confirm_prompt.message.text
	_check(hud.is_asking() and text.contains("正装备在你身上") and text.contains("武馆弟子"), "giving what one wears is asked: " + text)
	hud.confirm_prompt.cancel_button.pressed.emit()
	_check(_carries(session, worn), "取消: still worn")
	var gold_id: StringName = GameContent.catalog().currency_item(CurrencyDenomination.Value.GOLD).item_definition_id
	var silver_id: StringName = GameContent.catalog().currency_item(CurrencyDenomination.Value.SILVER).item_definition_id
	var gold: StringName = _give(session, gold_id, 3)
	var silver: StringName = _give(session, silver_id, 5)
	hud._give_item(gold, 1)
	text = hud.confirm_prompt.message.text
	_check(hud.is_asking() and text.begins_with("确定把") and text.contains("黄金") and text.contains("武馆弟子"), "a gold tael is asked: " + text)
	hud.confirm_prompt.cancel_button.pressed.emit()
	hud._presentation_layout.close_panel()
	hud._give_item(silver, 1)
	_check(not hud.is_asking(), "one silver tael is not asked")
	var keeper: NpcRuntimeState = map.find_resident_npc(KEEPER)
	_select(map, hud, &"snow.temple", keeper)
	var before: int = Finance.amount(Finance.session_context(session), CurrencyDenomination.Value.GOLD)
	hud._give_item(gold, 1)
	_check(not hud.is_asking() and Finance.amount(Finance.session_context(session), CurrencyDenomination.Value.GOLD) == before - 1, "a donation to the temple keeper is not asked")
	hud._presentation_layout.close_panel()


## The battle panel in a spar with a trainee: 运功疗伤 greyed with heal.c's line and
## pressing it does nothing; 运功恢复气 says what it does; no "你的目标是X。".
func _test_battle_actions(session: WorldSessionController, map: WorldMapController) -> void:
	var ui: BattlePresentationController = session.get_node("BattlePresentationLayer/BattleSurface")
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	var trainee: NpcRuntimeState = map.find_resident_npc(TRAINEE)
	_select(map, session.shared_ui(), &"snow.school2", trainee)
	_check(map.spar_selected().outcome == CombatSliceInitiationResult.Outcome.COMPLETED, "a spar with the trainee")
	ui.refresh_projection()
	var heal: Button = _button(ui.action_panel, "运功疗伤")
	var recover: Button = _button(ui.action_panel, "运功恢复气")
	_check(heal != null and heal.disabled and heal.tooltip_text == "战斗中运功疗伤？找死吗？", "运功疗伤 greyed with heal.c's line")
	_check(recover != null and not recover.disabled and recover.tooltip_text == "运功恢复气：用 20 点内力恢复气", "运功恢复气's hover: " + ("" if recover == null else recover.tooltip_text))
	if heal != null:
		heal.pressed.emit()
	ui.refresh_projection()
	_check(coordinator.has_active_encounter() and ui.current_projection().queued_action() == null, "pressing the greyed button queues nothing")
	var catalog := BattleActionPresentationCatalog.new()
	_check(catalog.tooltip_for(&"cast.dun.self") == "施法「遁」：脱离战斗，回到雪亭镇城隍庙（80 法力，可能失败）", "遁's hover: " + catalog.tooltip_for(&"cast.dun.self"))
	_check(catalog.tooltip_for(&"cast.saveme").begins_with("施法「召天将」：召来一名天将相助（100 法力"), "召天将's hover")
	_check(catalog.tooltip_for(&"flee").is_empty(), "逃跑 has none")
	var log: String = ui.log_panel._text.get_parsed_text()
	_check(not log.contains("你的目标是"), "no first-target line in the battle log")
	_run(session)
	ui.refresh_projection()


## A9: knocked out, the player lies in the dark for player_wake_seconds (3) of real time
## while NPC heart beats, their waking and the rest of world time run the whole delay;
## with ES2's pace (0) the player waits the delay itself.
func _test_quick_wake(session: WorldSessionController, map: WorldMapController) -> void:
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var flow: PlayerLifeFlow = session.player_life_flow()
	var trainee: NpcRuntimeState = map.find_resident_npc(TRAINEE)
	_check(GameContent.catalog().pacing().player_wake_seconds == 3, "pacing.json: three seconds in the dark")
	# TEST-ONLY: the trainee lies unconscious for 30 s, the player for 60 s.
	trainee.set_life_status(CharacterRuntimeLifeStatus.Value.UNCONSCIOUS)
	trainee.set_revive_in_ms(30000)
	player.set_life_status(CharacterRuntimeLifeStatus.Value.UNCONSCIOUS)
	flow.begin_unconscious(60, GameContent.catalog().pacing().player_wake_seconds)
	_check(flow.wakes_quickly() and is_equal_approx(flow.world_time_scale(), 20.0), "world time runs 20 times as fast")
	session._process(1.0)
	_check(player.life_status == CharacterRuntimeLifeStatus.Value.UNCONSCIOUS and is_equal_approx(flow.revive_remaining_seconds, 40.0), "one real second: 20 s of world time")
	session._process(1.0)
	_check(trainee.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE, "the trainee came to on world time")
	session._process(1.0)
	_check(player.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE and flow.phase == PlayerLifeFlow.Phase.NONE, "three real seconds: the player comes to")
	_check(is_equal_approx(flow.world_time_scale(), 1.0), "world time back to its pace")
	var previous: PacingDefinition = Es2Pacing.use()
	player.set_life_status(CharacterRuntimeLifeStatus.Value.UNCONSCIOUS)
	flow.begin_unconscious(60, GameContent.catalog().pacing().player_wake_seconds)
	session._process(3.0)
	_check(not flow.wakes_quickly() and player.life_status == CharacterRuntimeLifeStatus.Value.UNCONSCIOUS and is_equal_approx(flow.revive_remaining_seconds, 57.0), "ES2's pace: the delay itself")
	session._process(57.0)
	_check(player.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE, "ES2's pace: awake after 60 s")
	Es2Pacing.restore(previous)


func _select(map: WorldMapController, hud: SharedGameplayUI, zone_id: StringName, npc: NpcRuntimeState) -> void:
	_check(map.relocate_player(zone_id, npc.spawn_point_id) and map.select_npc(npc.character_id), "beside " + String(npc.character_id))
	hud.refresh_live_state()


func _button(panel: BattleActionPanel, label: String) -> Button:
	for child: Node in panel._actions.get_children():
		if (child as Button).text == label:
			return child as Button
	return null


func _carries(session: WorldSessionController, item_id: StringName) -> bool:
	for row: PlayerInventoryRowProjection in session.player_inventory_rows():
		if row.item_instance_id == item_id:
			return true
	return false


## Advances the encounter one combat round at a time until it is gone.
func _run(session: WorldSessionController) -> void:
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	var rounds: int = 0
	while coordinator.has_active_encounter() and rounds < 300:
		var advanced: CombatSchedulerAdvanceResult = coordinator.advance_scheduler(1.0)
		rounds += 1
		if advanced.cycles_processed == 0 and coordinator.has_active_encounter():
			_check(false, "the fight stalled after %d rounds" % rounds)
			return
	_check(not coordinator.has_active_encounter(), "the fight ended")


## TEST-ONLY: a carried stack of `definition_id`.
func _give(session: WorldSessionController, definition_id: StringName, amount: int) -> StringName:
	var context: MoneyInventoryContext = Finance.session_context(session)
	var content: ItemContentDefinition = GameContent.catalog().item(definition_id)
	var allocation: SessionItemIdAllocationResult = session.item_id_allocator().allocate(context.inventory)
	var item := ItemInstance.new(allocation.item_instance_id, definition_id)
	assert(context.inventory.register_item(item, 0))
	assert(context.index.register_snapshot(item))
	var destination := InventoryTransferDestination.new(context.endpoint(), true, true, 1000000)
	assert(CombinedStackService.register_stack(context.stacks, context.inventory, item, content.stack_definition(), amount).accepted)
	var merged: CombinedStackMergeResult = CombinedStackService.transfer_and_merge(context.stacks, context.inventory, item.item_instance_id, destination, null, null, context.owner)
	assert(context.index.forget_destroyed_snapshots(merged.absorbed_instance_ids, context.inventory))
	return merged.surviving_instance_id


func _check(ok: bool, label: String) -> void:
	_count += 1
	if not ok:
		_failures.append(label)
