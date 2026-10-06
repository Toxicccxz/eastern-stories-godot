extends RefCounted

## The shared ConfirmPrompt (owner, 2026-10-06: an important or deadly choice is asked
## first, through one reusable component): the component itself, then in Snow the
## HUD's 切磋 with a weapon in hand, 化尸粉 on a corpse that still holds things, the
## first master's 拜师 and 攻击 on one's own master. An unarmed 切磋, 攻击 on anyone
## else and an empty corpse go ahead at once. TEST-ONLY fixtures are marked.
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const Finance := preload("res://tests/runtime/snow_finance_test.gd")
const SouthRoad := preload("res://tests/runtime/snow_south_road_test.gd")
const Master := preload("res://tests/support/snow_master.gd")
const TRAINEE: StringName = &"snow.school2.trainee.1.character"
const GUARD: StringName = &"snow.school1.guard.1.character"
const DOG: StringName = &"snow.eroad2.dog.1.character"
const DUST: StringName = &"es2:obj/dust"

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	await _test_component(tree)
	var session: OldPineWorldSessionController = Work.create_session(tree)
	await tree.process_frame
	session.set_process(false)
	session.configure_npc_ambience_random_source(SouthRoad.Still.new()) # TEST-ONLY: nobody chats or wanders
	_check(session.handoff_to(&"snow.outdoor", &"snow.square", &"snow.square", &"snow.square.inn_entry").succeeded(), "out on the square")
	for frame: int in range(5):
		await tree.process_frame
	var map: WorldMapController = session.active_map() as WorldMapController
	_test_spar(session, map)
	_test_dissolve(session, map)
	await _test_first_master(session, map)
	_test_master_attack(session, map)
	session.free()
	await tree.process_frame
	return {"assertions": _count, "failures": _failures}


func _test_component(tree: SceneTree) -> void:
	var host := Control.new()
	tree.root.add_child(host)
	var prompt := ConfirmPrompt.new()
	host.add_child(prompt)
	var answers: Array[String] = []
	prompt.confirmed.connect(func() -> void: answers.append("yes"))
	prompt.cancelled.connect(func() -> void: answers.append("no"))
	prompt.ask("要拜师吗？", "确定拜师")
	_check(prompt.is_asking() and prompt.visible and prompt.message.visible and prompt.message.text == "要拜师吗？", "ask(): the question shows")
	_check(prompt.confirm_button.text == "确定拜师" and prompt.cancel_button.text == "取消" and prompt.cancel_button.visible, "the choice and 取消")
	prompt.focus_default()
	_check(prompt.cancel_button.has_focus(), "取消 holds the focus")
	prompt.confirm_button.pressed.emit()
	prompt.confirm_button.pressed.emit()
	_check(answers == ["yes"] and not prompt.is_asking(), "one answer per question: " + str(answers))
	prompt.ask("", "确定")
	_check(not prompt.message.visible, "an empty question hides its line")
	host.hide()
	_check(answers == ["yes", "no"], "hidden while it asks: 取消 (" + str(answers) + ")")
	host.show()
	prompt.tell("存档失败。")
	_check(not prompt.cancel_button.visible and prompt.confirm_button.text == "确定", "tell(): one button")
	prompt.focus_default()
	_check(prompt.confirm_button.has_focus(), "the notice's button holds the focus")
	prompt.confirm_button.pressed.emit()
	_check(answers == ["yes", "no", "yes"], "the notice's button answers")
	prompt.ask("x", "y")
	prompt.dismiss()
	_check(answers.size() == 3 and not prompt.visible and not prompt.is_asking(), "dismiss(): hidden without an answer")
	host.free()
	await tree.process_frame


## 切磋: unarmed at once; with 刘安禄's blade, asked first (取消, 关闭, 确定切磋).
func _test_spar(session: OldPineWorldSessionController, map: WorldMapController) -> void:
	var hud: SharedGameplayUI = session.shared_ui()
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	var trainee: NpcRuntimeState = map.find_resident_npc(TRAINEE)
	_select(map, hud, &"snow.school2", trainee)
	_check(not map.spar_is_armed(trainee) and hud.spar_is_enabled(), "the trainee: an unarmed 切磋")
	hud.spar_button.pressed.emit()
	_check(not hud.is_asking() and coordinator.has_active_encounter(), "an unarmed 切磋 is not asked")
	_run(session)
	var guard: NpcRuntimeState = map.find_resident_npc(GUARD)
	_select(map, hud, &"snow.school1", guard)
	_check(map.spar_is_armed(guard), "刘安禄's blade arms the spar")
	hud.spar_button.pressed.emit()
	var text: String = hud.confirm_prompt.message.text
	_check(hud.is_asking() and not coordinator.has_active_encounter() and text.begins_with("刀剑无眼：") and text.ends_with("确定要和刘安禄切磋吗？"), "asked first: " + text)
	_check(hud.confirm_prompt.confirm_button.text == "确定切磋" and hud.confirm_prompt.cancel_button.has_focus(), "确定切磋 / 取消, 取消 focused")
	hud.confirm_prompt.cancel_button.pressed.emit()
	_check(not hud.is_asking() and not hud._presentation_layout.frame.visible and not coordinator.has_active_encounter(), "取消: no spar, the frame closed")
	hud.spar_button.pressed.emit()
	hud._presentation_layout.close_panel()
	_check(not hud.is_asking() and not coordinator.has_active_encounter(), "关闭 answers 取消")
	hud.spar_button.pressed.emit()
	hud.confirm_prompt.confirm_button.pressed.emit()
	_check(coordinator.has_active_encounter() and coordinator.active_encounter().mode == CombatEncounterMode.Value.SPAR and hud.log_lines().back() == "刀剑无眼，持兵刃比试可能真的受伤。", "确定切磋: the spar, and its hint in the log")
	_run(session)


## 化尸粉: 刘安禄's corpse holds his things (asked); the dog's is empty (at once).
func _test_dissolve(session: OldPineWorldSessionController, map: WorldMapController) -> void:
	var hud: SharedGameplayUI = session.shared_ui()
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	var player: WorldPlayerRuntimeState = session.player_runtime()
	player.state.progression.combat_experience = 100000 # TEST-ONLY: a fresh character loses to anyone
	var guard: NpcRuntimeState = map.find_resident_npc(GUARD)
	_select(map, hud, &"snow.school1", guard)
	_wound(guard)
	hud.attack_button.pressed.emit()
	_check(not hud.is_asking() and coordinator.has_active_encounter(), "攻击 on anyone but one's master is not asked")
	_run(session)
	var corpse: CorpseState = _corpse_of(map, GUARD)
	_check(corpse != null and map.select_corpse(corpse.corpse_item_instance_id) and map.dissolvable_corpse_contents() > 0, "刘安禄's corpse, with his things in it")
	var dust: StringName = _give(session, DUST, 3) # TEST-ONLY
	hud.inventory_panel.dissolve_requested.emit(dust)
	var text: String = hud.confirm_prompt.message.text
	_check(hud.is_asking() and text.begins_with("化尸粉会把刘安禄的尸体连同里面的 %d 件物品一起化成一滩黄水" % map.dissolvable_corpse_contents()) and hud.confirm_prompt.confirm_button.text == "确定化掉", "asked first: " + text)
	hud.confirm_prompt.cancel_button.pressed.emit()
	_check(_corpse_of(map, GUARD) != null and session.stack_collection().stack_state(dust).amount == 3, "取消: the corpse and the powder stay")
	hud.inventory_panel.dissolve_requested.emit(dust)
	hud.confirm_prompt.confirm_button.pressed.emit()
	_check(_corpse_of(map, GUARD) == null and session.stack_collection().stack_state(dust).amount == 2 and hud.inventory_is_open(), "确定化掉: dissolved, back in the 背包")
	var dog: NpcRuntimeState = map.find_resident_npc(DOG)
	_select(map, hud, &"snow.eroad2", dog)
	_wound(dog)
	map.attack_selected()
	_run(session)
	corpse = _corpse_of(map, DOG)
	_check(corpse != null and map.select_corpse(corpse.corpse_item_instance_id) and map.dissolvable_corpse_contents() == 0, "the dog's corpse holds nothing")
	hud.inventory_panel.dissolve_requested.emit(dust)
	_check(not hud.is_asking() and _corpse_of(map, DOG) == null, "an empty corpse is dissolved at once")


## 拜师 柳淳风 without a family: asked only when he will take the player.
func _test_first_master(session: OldPineWorldSessionController, map: WorldMapController) -> void:
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var master: NpcRuntimeState = _master(map)
	session.shared_ui().dismiss_current_panel() # the 背包 from the dissolve
	_check(map.relocate_player(&"snow.schoolhall", master.spawn_point_id), "beside 柳淳风")
	await session.get_tree().physics_frame
	var school: TeacherService = map.service(&"snow.outdoor.schoolhall.master") as TeacherService
	player.state.attributes.courage = 25 # TEST-ONLY
	player.state.attributes.composure = 10 # TEST-ONLY: below his cps 20
	school.ui.interact()
	var ui: TeacherPanel = school.ui
	_check(ui.panel.visible, "his panel")
	ui.apprentice_button.pressed.emit()
	_check(not ui.is_confirming() and not player.state.family.has_family() and player.apprenticeship_request.is_pending(), "one he refuses is not asked: " + str(school.last_lines))
	player.state.attributes.composure = 25 # TEST-ONLY
	ui.apprentice_button.pressed.emit()
	_check(not ui.is_confirming() and school.last_lines == ["你想拜柳淳风为师，但是对方还没有答应。"], "a request still waiting is not asked either")
	ui.cancel_apprentice()
	ui.apprentice_button.pressed.emit()
	var text: String = ui.confirm_text.text
	_check(ui.is_confirming() and not ui.apprentice_button.visible and text.begins_with("拜柳淳风为师，便成为封山剑派的弟子。日后若再改投别派，就是背叛师门") and ui.keep_button.text == "再想想" and ui.confirm_button.text == "确定拜师", "the first master is asked first: " + text)
	ui.keep_button.pressed.emit()
	_check(not ui.is_confirming() and ui.apprentice_button.visible and not player.state.family.has_family(), "再想想: nothing changes")
	ui.apprentice_button.pressed.emit()
	ui.confirm_button.pressed.emit()
	_check(NpcApprenticeship.is_master_of(player.state, Master.definition()) and not ui.is_confirming(), "确定拜师: 柳淳风's disciple")
	ui.apprentice_button.pressed.emit()
	_check(not ui.is_confirming() and school.last_lines == ["你恭恭敬敬地向柳淳风磕头请安，叫道：「师父！」"], "greeting one's master is not asked")
	ui.close_panel()


## 攻击 柳淳风 as his disciple: asked first with what the kill would cost.
func _test_master_attack(session: OldPineWorldSessionController, map: WorldMapController) -> void:
	var hud: SharedGameplayUI = session.shared_ui()
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	var player: WorldPlayerRuntimeState = session.player_runtime()
	player.state.progression.score = 7 # TEST-ONLY
	var master: NpcRuntimeState = _master(map)
	_select(map, hud, &"snow.schoolhall", master)
	_check(hud.attack_is_enabled(), "攻击 offered on 柳淳风")
	hud.attack_button.pressed.emit()
	var text: String = hud.confirm_prompt.message.text
	_check(hud.is_asking() and not coordinator.has_active_encounter() and text.begins_with("柳淳风是你的师父。") and text.contains("被逐出封山剑派") and text.contains("综合评价清零（现在是 7）") and text.contains("背叛师门的次数变成 1 次"), "asked first: " + text)
	hud.confirm_prompt.cancel_button.pressed.emit()
	_check(not coordinator.has_active_encounter() and player.state.family.has_family(), "取消: no fight")
	hud.attack_button.pressed.emit()
	hud.confirm_prompt.confirm_button.pressed.emit()
	_check(coordinator.has_active_encounter() and coordinator.active_encounter().mode != CombatEncounterMode.Value.SPAR, "确定攻击: a fight to the death")


func _select(map: WorldMapController, hud: SharedGameplayUI, zone_id: StringName, npc: NpcRuntimeState) -> void:
	_check(map.relocate_player(zone_id, npc.spawn_point_id) and map.select_npc(npc.character_id), "beside " + String(npc.character_id))
	hud.refresh_live_state()


func _master(map: WorldMapController) -> NpcRuntimeState:
	for npc: NpcRuntimeState in map.resident_npcs():
		if npc.definition().definition_id == Master.MASTER_ID:
			return npc
	return null


## TEST-ONLY: one blow ends it.
func _wound(npc: NpcRuntimeState) -> void:
	npc.character_state.vitality.effective = 1
	npc.character_state.vitality.current = 1


func _corpse_of(map: WorldMapController, character_id: StringName) -> CorpseState:
	for corpse: CorpseState in map.corpse_states():
		if corpse.victim_character_id == character_id:
			return corpse
	return null


## Advances the encounter one combat round at a time until it is gone.
func _run(session: OldPineWorldSessionController) -> void:
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
func _give(session: OldPineWorldSessionController, definition_id: StringName, amount: int) -> StringName:
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
