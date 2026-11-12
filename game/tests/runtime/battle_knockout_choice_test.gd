extends RefCounted

## 了结 / 放过 the player's way (review 2026-11-12, 战斗表现层; DECISIONS「了结 / 放过」「战斗演出 E」):
## in 手动, with the real buttons (mouse clicks), keys (Q / E) and pad (D-pad, A) — never a
## private function or an emitted signal. One against one: the question is told and its
## buttons pulse as the fight comes to wait on it, the focus goes to 「放过」 and the pad walks
## to 了结. One against two: a move goes on while one still stands; one passed over for another
## target can be picked again (Q / E, plates), the mark goes when he comes to, and with nobody
## left to strike his panel comes back; a target change refused says why in the strip. 自动:
## the strip's 克 / 被克 is the resolver's verdict. After a load the arena's and seals' sounds
## (BattleSounds.current) are the loaded session's. In 青石村; TEST-ONLY fixtures are marked.
const Sof := preload("res://tests/runtime/spare_or_finish_test.gd")
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const SouthRoad := preload("res://tests/runtime/snow_south_road_test.gd")
const Specials := preload("res://tests/runtime/combat_specials_test.gd")
const Transaction := preload("res://tests/runtime/oldpine_save_load_transaction_test.gd")
const QUARRYMAN: StringName = &"green.npc.worker2"
const HOST_SCENE: PackedScene = preload("res://scenes/runtime/oldpine_game_runtime_host.tscn")

var _count: int = 0
var _failures: Array[String] = []
## The helpers of spare_or_finish_test (its checks are counted with these).
var _sof := Sof.new()


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	var knockout_before: int = BattlePace.after_knockout
	var manual_before: bool = BattlePace.manual_turns
	var session: WorldSessionController = Work.create_session(tree)
	await tree.process_frame
	session.set_process(false)
	session.configure_npc_ambience_random_source(SouthRoad.Still.new()) # TEST-ONLY: nobody chats or wanders
	_check(session.handoff_to(&"green.village", &"green.path6", &"green.path6", &"green.path6.snow_entry").succeeded(), "TEST-ONLY: into the village")
	await tree.physics_frame
	await tree.physics_frame
	Sof._strong(session.player_runtime().state)
	BattlePace.after_knockout = BattlePace.AfterKnockout.ASK
	await _test_alone(tree, session)
	await _test_two(tree, session)
	await _test_auto_verdict(tree, session)
	BattlePace.manual_turns = manual_before
	BattlePace.after_knockout = knockout_before
	session.free()
	await tree.process_frame
	await _test_sounds_after_load(tree)
	BattlePace.manual_turns = manual_before
	BattlePace.after_knockout = knockout_before
	_count += _sof._count
	_failures.append_array(_sof._failures)
	return {"assertions": _count, "failures": _failures}


## One against one in 手动: the 采石工 falls; nobody is left to strike, every move dims — the
## strip asks for 了结 / 放过 at once and the buttons pulse, no move pressed; the focus is on
## 「放过」, the D-pad walks to 了结 and back, the moves' up leads to it; A on 放过 spares him.
func _test_alone(tree: SceneTree, session: WorldSessionController) -> void:
	var quarryman: NpcRuntimeState = _sof._first(session.world_map_of(&"green.village"), QUARRYMAN)
	var map: WorldMapController = await _sof._beside(tree, session, quarryman)
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	BattlePace.manual_turns = true
	map.select_npc(quarryman.character_id)
	_check(map.attack_selected().outcome == CombatSliceInitiationResult.Outcome.COMPLETED, "the player attacks a 采石工 (手动)")
	var ui: BattlePresentationController = _ui(session)
	await _frames(tree, 3)
	_check(ui.is_visible_in_tree() and ui.current_projection().manual and ui.current_projection().waiting, "the panel waits for the player's move")
	var move: Button = _enabled_move(ui)
	_check(move != null, "a move to press")
	if move == null:
		return
	# A real click on a move: the beat is chosen (the round would run on it).
	_click(tree, move)
	await _frames(tree, 1)
	_check(not coordinator.player_choice().is_empty(), "a click on a move chooses it")
	_sof._fell(coordinator, quarryman)
	await _frames(tree, 3)
	var card: BattleParticipantCard = ui._panel_card(1)
	_check(coordinator.held_victims() == [quarryman.character_id] and card != null and card.participant_id() == quarryman.character_id and card.choice_row.visible, "he falls and is held; the right panel asks 了结 / 放过")
	if card == null:
		return
	var dimmed: bool = true
	for button: Button in ui.action_panel.move_buttons.values():
		dimmed = dimmed and button.disabled
	_check(dimmed, "nobody to strike: every move dims")
	_check(_strip_says(ui, BattlePresentationController.CHOOSE_FIRST), "the strip asks at once, no move pressed: " + str(_strip_texts(ui)))
	_check(card._choice_pulse != null and card._choice_pulse.is_valid(), "the buttons pulse")
	_check(tree.root.gui_get_focus_owner() == card.spare_button, "the focus is on 放过: %s" % tree.root.gui_get_focus_owner())
	var first: Button = ui.action_panel.first_move_button()
	_check(first != null and first.get_node_or_null(first.focus_neighbor_top) == card.spare_button, "up from the moves: 放过")
	await _pad(tree, JOY_BUTTON_DPAD_LEFT)
	_check(tree.root.gui_get_focus_owner() == card.finish_button, "the D-pad's left: 了结: %s" % tree.root.gui_get_focus_owner())
	await _pad(tree, JOY_BUTTON_DPAD_RIGHT)
	_check(tree.root.gui_get_focus_owner() == card.spare_button, "right again: 放过")
	await _pad(tree, JOY_BUTTON_A)
	_check(coordinator.held_victims().is_empty(), "A: 放过")
	coordinator.advance_scheduler(0.0)
	_check(not coordinator.has_active_encounter() and quarryman.life_status == CharacterRuntimeLifeStatus.Value.UNCONSCIOUS, "nobody else to fight: over, he lives")
	await _settle(tree, session)


## One against two in 手动 (老公公 calls 老婆婆, ES2's ask_for_help()): he falls while she stands —
## a move goes on (the fight turns it on her), no question asked. A target change the fight
## refuses says why in the strip. E to her passes him over; he comes to: the mark goes; down
## again, his panel is back. Both down: the question, Q / E reach either; 了结 her, and with
## nobody left to strike his panel and its buttons come back; 放过 ends the fight.
func _test_two(tree: SceneTree, session: WorldSessionController) -> void:
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var home: WorldMapController = session.world_map_of(&"green.house2_house")
	var man: NpcRuntimeState = _sof._first(home, &"green.npc.oldman")
	var wife: NpcRuntimeState = _sof._first(home, &"green.npc.oldwoman")
	var map: WorldMapController = await _sof._beside(tree, session, man)
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	BattlePace.manual_turns = true
	map.select_npc(man.character_id)
	_check(map.attack_selected().outcome == CombatSliceInitiationResult.Outcome.COMPLETED, "the player attacks 老公公 (手动)")
	var bindings: Array[CombatSliceCharacterBinding] = session.encounter_combat_bindings(coordinator.active_encounter())
	var chat := CombatNpcChat.new(coordinator._resident_npc, coordinator._npc_wield, coordinator._respect_of).with_villagers(coordinator._npc_wield_item, coordinator._age_of, coordinator._idle_partner)
	var called: CombatNpcChatResult = chat.beat(_sof._binding(bindings, man.character_id), [], [], Specials.Pattern.new([0, 0]), SkillImprovementEffectRegistry.new())
	_check(called != null and called.joins().size() == 1, "TEST-ONLY: ask_for_help() brings 老婆婆")
	if called == null:
		return
	coordinator.resolution().admit(bindings, CombatTacticalExecutionResult.new(CombatTacticalExecutionResult.Outcome.APPLIED).with_joins(called.joins()))
	player.relationship.mark_lethal_target(wife.character_id) # TEST-ONLY: as if the player had 攻击 her too
	var ui: BattlePresentationController = _ui(session)
	await _frames(tree, 3)
	# He falls; she stands.
	_sof._fell(coordinator, man)
	await _frames(tree, 3)
	_check(coordinator.held_victims() == [man.character_id] and wife.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE, "he is held; she stands")
	_check(not _strip_says(ui, BattlePresentationController.CHOOSE_FIRST), "someone still stands: nothing asked")
	var move: Button = _enabled_move(ui)
	_check(move != null, "the moves stay lit")
	if move != null:
		_click(tree, move)
		await _frames(tree, 1)
		_check(not coordinator.player_choice().is_empty() and not _strip_says(ui, BattlePresentationController.CHOOSE_FIRST), "a click on a move goes on (not refused for the one held)")
		var events_from: int = coordinator.active_scheduler().events().size()
		coordinator.advance_scheduler(1.0)
		var at_wife: bool = false
		for event: CombatSchedulerEvent in coordinator.active_scheduler().events().slice(events_from):
			at_wife = at_wife or (event.actor_id == player.character_id and event.target_id == wife.character_id and event.resolution != null)
		_check(at_wife and not _sof._struck(coordinator, man.character_id, events_from), "the fight turned it on her; nobody struck him")
		await _frames(tree, 2)
	# A target change the fight refuses (TEST-ONLY: the session is in a swap while the change is
	# sent): E says why where the player looks, and the panel stays.
	_check(ui._panel_card(1).participant_id() == man.character_id, "his panel (held) on the right")
	var swap := func() -> void: session._session_swap_suspended = true
	var back := func(_result: CombatTargetResult) -> void: session._session_swap_suspended = false
	ui.target_submitting.connect(swap)
	ui.target_received.connect(back)
	await _key(tree, KEY_E)
	ui.target_submitting.disconnect(swap)
	ui.target_received.disconnect(back)
	_check(_strip_says(ui, "换目标：" + BattleFeedbackReader.target_reason(CombatTargetResult.Code.APPLICATION_BLOCKED)) and ui._panel_card(1).participant_id() == man.character_id, "the refusal in the strip; his panel stays: " + str(_strip_texts(ui)))
	await _frames(tree, 2)
	# E: her (the fight's target already); he is passed over.
	await _key(tree, KEY_E)
	await _frames(tree, 2)
	_check(coordinator.active_encounter().current_target_for(player.character_id) == wife.character_id and ui._panel_card(1).participant_id() == wife.character_id and ui._passed_held.has(man.character_id), "E: her, the right panel hers; he is passed over")
	# He comes to: his mark goes.
	man.set_revive_in_ms(300) # TEST-ONLY: a short call_out
	await _round(tree, ui, coordinator)
	_check(man.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE and not ui._passed_held.has(man.character_id), "he comes to: his mark goes")
	_sof._fell(coordinator, man)
	await _frames(tree, 3)
	var card: BattleParticipantCard = ui._panel_card(1)
	_check(card != null and card.participant_id() == man.character_id and card.choice_row.visible, "down again: his panel and its buttons")
	await _key(tree, KEY_E)
	await _frames(tree, 2)
	_check(ui._panel_card(1).participant_id() == wife.character_id, "E: her again")
	# Both down: the question; Q / E reach either.
	_sof._fell(coordinator, wife)
	await _frames(tree, 3)
	_check(coordinator.held_victims().size() == 2 and _strip_says(ui, BattlePresentationController.CHOOSE_FIRST), "both down: the question")
	card = ui._panel_card(1)
	_check(card != null and card.participant_id() == wife.character_id and card.choice_row.visible and tree.root.gui_get_focus_owner() == card.spare_button, "her panel asks; the focus on its 放过")
	await _key(tree, KEY_E)
	await _frames(tree, 2)
	card = ui._panel_card(1)
	_check(card != null and card.participant_id() == man.character_id and card.choice_row.visible, "E reaches him, held: his buttons")
	_check(coordinator.active_encounter().current_target_for(player.character_id) == wife.character_id or coordinator.active_encounter().current_target_for(player.character_id).is_empty(), "the fight's target is not changed by showing him")
	await _key(tree, KEY_Q)
	await _frames(tree, 2)
	card = ui._panel_card(1)
	_check(card != null and card.participant_id() == wife.character_id, "Q: her again")
	if card == null or card.participant_id() != wife.character_id:
		return
	# 了结 her (a click), then the blows (moves clicked) until she dies.
	_click(tree, card.finish_button)
	await _frames(tree, 2)
	_check(coordinator.held_victims() == [man.character_id], "了结 her")
	for _round: int in range(40):
		if wife.life_status == CharacterRuntimeLifeStatus.Value.DEAD or not coordinator.has_active_encounter():
			break
		await _round(tree, ui, coordinator)
	_check(wife.life_status == CharacterRuntimeLifeStatus.Value.DEAD and coordinator.has_active_encounter(), "she dies; the fight waits on him")
	await _frames(tree, 3)
	card = ui._panel_card(1)
	_check(card != null and card.participant_id() == man.character_id and card.choice_row.visible, "nobody left to strike: his panel and buttons are back (not hers, dead): %s" % (&"" if card == null else card.participant_id()))
	if card == null or card.participant_id() != man.character_id:
		return
	_click(tree, card.spare_button)
	await _frames(tree, 1)
	coordinator.advance_scheduler(0.0)
	_check(not coordinator.has_active_encounter() and man.life_status == CharacterRuntimeLifeStatus.Value.UNCONSCIOUS, "放过 him: the fight is over, he lives")
	await _settle(tree, session)


## 自动: whole rounds run between two looks; whatever the strip says of the player's last
## beat, its 克 / 被克 is the ring the resolver read for that blow (CombatAttackCalculation.ring).
func _test_auto_verdict(tree: SceneTree, session: WorldSessionController) -> void:
	BattlePace.manual_turns = false
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var target: NpcRuntimeState = null
	for npc: NpcRuntimeState in session.world_map_of(&"green.village").resident_npcs():
		if target == null and npc.definition().definition_id == QUARRYMAN and npc.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE:
			target = npc
	_check(target != null, "a 采石工 standing")
	if target == null:
		return
	var map: WorldMapController = await _sof._beside(tree, session, target)
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	target.character_state.vitality = CharacterResourceState.new(50000, 50000, 50000) # TEST-ONLY: he lasts the rounds
	map.select_npc(target.character_id)
	_check(map.attack_selected().outcome == CombatSliceInitiationResult.Outcome.COMPLETED, "the player attacks a 采石工 (自动)")
	var ui: BattlePresentationController = _ui(session)
	await _frames(tree, 2)
	var compared: int = 0
	var verdicts: int = 0
	for _round: int in range(30):
		if not coordinator.has_active_encounter():
			break
		coordinator.advance_scheduler(1.0)
		await _frames(tree, 1)
		var shown: String = ui.action_panel._result
		var last: CombatAttackResult = _last_player_blow(coordinator, player.character_id)
		if last == null or not shown.begins_with("你出") or shown.contains("你出了"):
			continue
		compared += 1
		var ring: int = last.calculation.ring
		var expected: String = "克！" if ring > 0 else ("被克" if ring < 0 else "")
		if ring != 0:
			verdicts += 1
			_check(shown.contains(" · " + expected), "round %d: the ring said %s; the strip: %s" % [_round, expected, shown])
		else:
			_check(not shown.contains("克"), "round %d: the ring said neither; the strip: %s" % [_round, shown])
	_check(compared >= 10 and verdicts >= 3, "enough beats compared: %d (%d with a verdict)" % [compared, verdicts])
	target.character_state.vitality = CharacterResourceState.new(100, 100, 100) # TEST-ONLY
	BattlePace.after_knockout = BattlePace.AfterKnockout.FINISH
	_sof._run(coordinator)
	BattlePace.after_knockout = BattlePace.AfterKnockout.ASK
	await _settle(tree, session)


## Continue and Load build the session aside and move it into place: the sounds the arena and
## the seals cue (BattleSounds.current) are the loaded session's battle panel's; a load that
## fails keeps the current session's.
func _test_sounds_after_load(tree: SceneTree) -> void:
	var profile := GameSaveStorageProfile.isolated_test("battle-sounds-load-%d" % Time.get_ticks_usec())
	var files := Transaction.MemoryFiles.new()
	var host: OldPineGameRuntimeHost = HOST_SCENE.instantiate()
	_check(host.configure_before_start(profile, files), "a test profile")
	tree.root.add_child(host)
	await tree.process_frame
	var first: WorldSessionController = host.current_session()
	_check(BattleSounds.current == _ui(first).sounds, "a new game: its panel's sounds")
	_check(host.request_save(), "Save")
	await _frames(tree, 2)
	_check(host.last_save_result().succeeded(), "saved")
	_check(host.request_load(), "Load")
	await _frames(tree, 2)
	var loaded: WorldSessionController = host.current_session()
	_check(host.last_load_result().succeeded() and loaded != first, "loaded: another session")
	_check(BattleSounds.current != null and is_instance_valid(BattleSounds.current) and BattleSounds.current == _ui(loaded).sounds, "after the load: the loaded panel's sounds (%s)" % BattleSounds.current)
	var failing := Transaction.FailingActivationCoordinator.new(GameSaveRepository.new(profile, files))
	failing.load_replacing(loaded, host.session_slot, host.staging_slot)
	_check(BattleSounds.current == _ui(loaded).sounds, "a load that fails keeps them")
	BattleSounds.current.played.clear()
	BattleSounds.cue(BattleSounds.SEAL)
	_check(not BattleSounds.current.played.is_empty(), "a cue plays on them")
	host.get_parent().remove_child(host)
	host.free()
	await tree.process_frame


# --- Helpers ------------------------------------------------------------------------

func _ui(session: WorldSessionController) -> BattlePresentationController:
	return session.get_node("BattlePresentationLayer/BattleSurface")


## The first move the player may press now, or null.
func _enabled_move(ui: BattlePresentationController) -> Button:
	for id: StringName in ui.action_panel.move_order():
		var button: Button = ui.action_panel.move_buttons[id]
		if button.is_visible_in_tree() and not button.disabled:
			return button
	return null


## One round the player's way: a move clicked (when one waits), the fight advanced.
func _round(tree: SceneTree, ui: BattlePresentationController, coordinator: CombatEncounterCoordinator) -> void:
	var move: Button = _enabled_move(ui)
	if move != null:
		_click(tree, move)
		await _frames(tree, 1)
	coordinator.advance_scheduler(1.0)
	await _frames(tree, 2)


## The player's last blow resolved in the fight (an ordinary attack with its calculation).
func _last_player_blow(coordinator: CombatEncounterCoordinator, player_id: StringName) -> CombatAttackResult:
	var events: Array[CombatSchedulerEvent] = coordinator.active_scheduler().events()
	for index: int in range(events.size() - 1, -1, -1):
		var event: CombatSchedulerEvent = events[index]
		if event.actor_id != player_id or event.resolution == null:
			continue
		var forward: CombatSingleAttackExecutionResult = event.resolution.forward_result
		var ordinary: CombatOrdinaryAttackResult = null if forward == null else forward.ordinary_attack_result
		if ordinary == null or not ordinary.has_base_result:
			return null
		return ordinary.base_result
	return null


## The strip's lines as shown (each row's text).
func _strip_texts(ui: BattlePresentationController) -> PackedStringArray:
	var texts := PackedStringArray()
	for row: Node in ui._recent.get_children():
		if (row as Control).visible:
			texts.append((row.get_node("Text") as RichTextLabel).get_parsed_text())
	return texts


func _strip_says(ui: BattlePresentationController, text: String) -> bool:
	for shown: String in _strip_texts(ui):
		if shown.contains(text):
			return true
	return false


func _click(tree: SceneTree, button: Control) -> void:
	var click := InputEventMouseButton.new()
	click.position = button.get_global_rect().get_center()
	click.global_position = click.position
	click.button_index = MOUSE_BUTTON_LEFT
	click.button_mask = MOUSE_BUTTON_MASK_LEFT
	click.pressed = true
	tree.root.push_input(click, true)
	click.pressed = false
	click.button_mask = 0
	tree.root.push_input(click, true)


func _key(tree: SceneTree, keycode: Key) -> void:
	for pressed: bool in [true, false]:
		var key := InputEventKey.new()
		key.keycode = keycode
		key.pressed = pressed
		Input.parse_input_event(key)
		await tree.process_frame


func _pad(tree: SceneTree, button: JoyButton) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = button
		event.pressed = pressed
		Input.parse_input_event(event)
		await tree.process_frame
	await tree.process_frame


func _frames(tree: SceneTree, count: int) -> void:
	for _frame: int in count:
		await tree.process_frame


func _settle(tree: SceneTree, session: WorldSessionController) -> void:
	_ui(session).refresh_projection()
	await _frames(tree, 2)
	_check(CombatEncounterCoordinator.take_aborted_total() == 0, "no fight aborted")


func _check(ok: bool, label: String) -> void:
	_count += 1
	if not ok:
		_failures.append(label)
