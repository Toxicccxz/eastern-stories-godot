extends RefCounted

## Internal power in combat, in a running Snow session: the 武学 page's 加力
## (enforce.c) and 运功 (exert.c: fonxanforce's heal, /d/force's recover, refresh and
## regenerate); in a spar the battle panel's 加力 (set at once) and 运功 buttons
## (queued, busy 1 after), the player's force hit spending force_factor on each hit
## that lands, std/force.c's reflection told in the battle log against 柳淳风, and
## Continue adding max_force/4 to max kee (race/human.c at login).
## TEST-ONLY fixtures, each marked where used: force 10 / 封山派内功 10 enabled,
## max_force 50 and force 100 set directly, wounds set directly, combat experience.
const Work := preload("res://tests/runtime/snow_work_income_test.gd")

var _count: int = 0
var _failures: Array[String] = []
var _session: WorldSessionController
var _player: WorldPlayerRuntimeState
var _state: CharacterState
var _hud: SharedGameplayUI
var _ui: BattlePresentationController
var _hits: int = 0
var _spent: bool = true
var _reflected: StandardForceHitResult


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_session = Work.create_session(tree)
	await tree.process_frame
	await _to_snow(tree)
	_player = _session.player_runtime()
	_state = _player.state
	_hud = _session.shared_ui()
	_ui = _session.get_node("BattlePresentationLayer/BattleSurface")
	# TEST-ONLY: what 柳淳风's lessons, enable and hours of exercise give.
	_state.skills.set_raw_level(&"force", 10)
	_state.skills.set_raw_level(&"fonxanforce", 10)
	_state.skills.map_skill(&"force", &"fonxanforce")
	_state.recovery.inner_force.maximum = 50
	_state.recovery.inner_force.current = 100
	_test_page()
	await _test_continue(tree)
	await _test_battle(tree)
	await _test_reflection(tree)
	_session.free()
	await tree.process_frame
	return {"assertions": _count, "failures": _failures}


func _test_page() -> void:
	var page: MartialArtsPage = _hud.martial_arts_page()
	_hud.open_martial_arts()
	page.refresh()
	_check(page.force_text.text == "内力 100 / 50 (+0)", "hp.c's 内力 with (+force_factor): " + page.force_text.text)
	_check(page.enforce_amount.max_value == 7, "加力 up to query_skill(force) 15 / 2")
	for function_id: StringName in [&"heal", &"recover", &"refresh", &"regenerate"]:
		_check(page.buttons.has("exert:%s" % function_id), "运功 offers %s" % function_id)
	_check(page.buttons["exert:heal"].text == "疗伤" and page.buttons["exert:regenerate"].text == "恢复精", "doc/help/force's names")
	page.enforce_amount.value = 3
	page.enforce_button.pressed.emit()
	_check(_last() == ["Ok."] and _state.attributes.force_factor == 3, "enforce 3: Ok.")
	_check(page.force_text.text == "内力 100 / 50 (+3)", "the page follows: " + page.force_text.text)
	_state.vitality.effective = 60 # TEST-ONLY: a wound.
	_state.vitality.current = 60
	page.buttons["exert:heal"].pressed.emit()
	_check(_last() == ["你全身放松，坐下来开始运功疗伤。"], "heal.c's line " + str(_last()))
	_check(_state.vitality.effective == 73 and _state.recovery.inner_force.current == 50 and _state.attributes.force_factor == 0, "eff_kee + 13, 50 force, force_factor 0")
	var white: String = "[color=#%s]你全身放松" % SharedGameplayUI.ES2_COLORS[ColoredLine.HIW].to_html(false)
	_check(_hud.combat_log.text.contains(white), "in HIW in the log")
	page.buttons["exert:recover"].pressed.emit()
	_check(_last()[0] == "你深深吸了几口气，脸色看起来好多了。" and _state.vitality.current == 73 and _state.recovery.inner_force.current == 30, "recover.c: kee back to eff_kee for 20 force")
	page.buttons["exert:recover"].pressed.emit()
	_check(_last() == ["你的气已经恢复到上限了。"], "recover.c with kee full")
	_hud.dismiss_current_panel()


## Save, then Continue: max kee 100 + max_force 50 / 4; the rest as saved.
func _test_continue(tree: SceneTree) -> void:
	_state.attributes.force_factor = 2
	var snapshot: GameSaveSnapshot = Work.capture(_session)
	var decoded: GameSaveResult = GameSaveJsonCodec.decode(GameSaveJsonCodec.encode(snapshot).text)
	var restored: OldPineWorldRestoreResult = OldPineWorldRestoreService.build_candidate(decoded.snapshot, tree.root)
	_check(restored.succeeded(), "Continue " + restored.path)
	if not restored.succeeded():
		return
	var state: CharacterState = restored.candidate.player_runtime().state
	_check(_state.vitality.maximum == 100 and state.vitality.maximum == 112, "max kee 100 before, 112 after Continue: %d" % state.vitality.maximum)
	_check(state.vitality.effective == _state.vitality.effective and state.vitality.current == _state.vitality.current, "eff_kee and kee as saved")
	_check(state.attributes.force_factor == 2 and state.recovery.inner_force.current == _state.recovery.inner_force.current, "force_factor and force saved")
	restored.candidate.free()
	await tree.process_frame


func _test_battle(tree: SceneTree) -> void:
	_heal()
	_state.recovery.inner_force.current = 100
	_state.progression.combat_experience = 5000 # TEST-ONLY: hits that land.
	_session.martial_arts().enforce(3)
	var map: WorldMapController = _session.active_map() as WorldMapController
	_check(_beside(map, &"snow.school2", &"snow.school2.trainee.1"), "beside a trainee")
	await tree.physics_frame
	map.select_npc(_npc(map, &"snow.school2.trainee.1").character_id)
	_check(map.spar_selected().outcome == CombatSliceInitiationResult.Outcome.COMPLETED, "a spar starts")
	# TEST-ONLY: without an enabled force there is no 加力 row and no 运功.
	_state.skills.unmap_skill(&"force")
	_ui.refresh_projection()
	_check(not _ui.action_panel.enforce_row.visible and _ui.current_projection().actions().size() == 2, "no enabled force: Flee and 投降 alone, no 加力")
	_state.skills.map_skill(&"force", &"fonxanforce")
	_ui.refresh_projection()
	var labels: Array[String] = []
	for info: CombatTacticalActionInfo in _ui.current_projection().actions():
		labels.append(_ui.action_catalog.label_for(info.action_id))
	_check(labels == ["逃跑", "投降", "运功疗伤", "运功恢复气", "运功恢复神", "运功恢复精"], "the battle panel: Flee, 投降 and the enabled force's functions " + str(labels))
	var panel: BattleActionPanel = _ui.action_panel
	_check(panel.enforce_row.visible and panel.enforce_text.text == "加力 +3" and panel.enforce_amount.max_value == 7, "加力 +3, up to 7")
	panel.enforce_amount.value = 5
	panel.enforce_button.pressed.emit()
	_check(_state.attributes.force_factor == 5 and _ui.feedback_reader().recent().back().text == "Ok.", "enforce in the fight, at once: Ok.")
	_check(_log().contains("Ok."), "in the battle log")
	_ui.refresh_projection()
	_check(panel.enforce_text.text == "加力 +5", "the panel follows")
	_state.vitality.current = 50 # TEST-ONLY: hurt.
	_press(panel, "运功恢复气")
	var events: Array[CombatSchedulerEvent] = _advance()
	_check(_log().contains("你准备运功恢复气。") and _log().contains("你深深吸了几口气，脸色看起来好多了。"), "queued, then recover.c's line in the battle log")
	var busy_turn: bool = false
	for event: CombatSchedulerEvent in events:
		if event.actor_id == _player.character_id and event.resolution != null and event.resolution.outcome == CombatSliceOpportunityResult.Outcome.BUSY_ADVANCED:
			busy_turn = true
	_check(busy_turn and _state.vitality.current == 65, "busy 1: the player's next turn goes by; kee + 15")
	_press(panel, "运功疗伤")
	_advance()
	_check(_log().contains("战斗中运功疗伤？找死吗？"), "heal.c refuses in a fight")
	for _second: int in range(300):
		if not _session.combat_encounter_coordinator().has_active_encounter():
			break
		_advance()
	_check(_hits > 0 and _spent, "each landed hit spends force_factor 5 (%d hits)" % _hits)
	_check(not _session.combat_encounter_coordinator().has_active_encounter(), "the spar ends")
	await tree.process_frame


## Bare-handed with 加力 against 柳淳风's 1500 force: the hit falls short and his
## force throws the player back. A fight, not a spar: combatd.c ends a spar on its
## first blow, often his.
func _test_reflection(tree: SceneTree) -> void:
	# TEST-ONLY: hits that land on a master, and kee to outlast his sword.
	_state.progression.combat_experience = 20000000
	_state.vitality.maximum = 3000
	_heal()
	_state.recovery.inner_force.current = 100
	_session.martial_arts().enforce(1)
	var map: WorldMapController = _session.active_map() as WorldMapController
	_check(_beside(map, &"snow.schoolhall", &"snow.schoolhall.master.1"), "in the hall")
	await tree.physics_frame
	map.select_npc(_npc(map, &"snow.schoolhall.master.1").character_id)
	_check(map.attack_selected().outcome == CombatSliceInitiationResult.Outcome.COMPLETED, "the player attacks 柳淳风")
	_reflected = null
	for _second: int in range(300):
		_advance()
		if _reflected != null or not _session.combat_encounter_coordinator().has_active_encounter():
			break
	var reflected: StandardForceHitResult = _reflected
	_check(reflected != null, "a reflection within the fight")
	if reflected == null:
		return
	var wound: int = reflected.reflection_mutation.requested_wound
	var line: String = Es2CombatMessages.force_reflection_message(wound).replace("$N", "你").replace("$n", "柳淳风")
	_check(_log().contains(line), "std/force.c's line for %d: %s" % [wound, line])
	var mutation: StandardForceReflectionMutationResult = reflected.reflection_mutation
	_check(mutation.requested_damage == wound * 2 and mutation.vitality_effective_after_wound == mutation.vitality_effective_before - wound, "kee damage twice the wound, eff_kee down by it")
	_check(mutation.vitality_current_after_damage == mutation.vitality_current_before - wound * 2, "kee down by twice the wound")
	await tree.process_frame


## One second of the fight, told in the battle log; the player's landed hits are
## counted (each must spend `_factor`) and a reflection kept.
func _advance() -> Array[CombatSchedulerEvent]:
	var events: Array[CombatSchedulerEvent] = _session.combat_encounter_coordinator().advance_scheduler(1.0).events()
	_ui.refresh_projection()
	for event: CombatSchedulerEvent in events:
		var base: CombatAttackResult = _player_hit(event)
		if base == null or not base.has_standard_force_result:
			continue
		var force: StandardForceHitResult = base.standard_force_result
		_hits += 1
		_spent = _spent and force.force_before - force.force_after_deduction == _state.attributes.force_factor
		if force.outcome == StandardForceHitResult.Outcome.REFLECTION:
			_reflected = force
	return events


## The player's landed hit in `event`'s forward attack, else null.
func _player_hit(event: CombatSchedulerEvent) -> CombatAttackResult:
	var resolution: CombatSliceOpportunityResult = event.resolution
	if resolution == null or resolution.forward_result == null or event.actor_id != _player.character_id:
		return null
	var ordinary: CombatOrdinaryAttackResult = resolution.forward_result.ordinary_attack_result
	if ordinary == null or not ordinary.has_base_result or ordinary.base_result.outcome != CombatAttackResult.Outcome.HIT:
		return null
	return ordinary.base_result


func _press(panel: BattleActionPanel, label: String) -> void:
	for button: Node in panel._actions.get_children():
		if (button as Button).text == label:
			(button as Button).pressed.emit()
			return
	_check(false, "no %s button" % label)


func _log() -> String:
	return _ui.log_panel._text.get_parsed_text()


func _last() -> Array[String]:
	return ColoredLine.texts(_session.martial_arts().last_lines)


func _heal() -> void:
	for resource: CharacterResourceState in [_state.essence, _state.vitality, _state.spirit]:
		resource.effective = resource.maximum
		resource.current = resource.maximum


func _to_snow(tree: SceneTree) -> void:
	Input.action_press("move_right")
	for _step: int in range(400):
		await tree.physics_frame
		if _session.active_map_id() == &"snow.outdoor":
			break
	Input.action_release("move_right")
	await tree.physics_frame
	_session.set_process(false)
	_check(_session.active_map_id() == &"snow.outdoor", "out of the Inn")


func _beside(map: WorldMapController, zone_id: StringName, point_id: StringName) -> bool:
	var marker: WorldSpawnMarker2D = map.resolve_spawn_marker(point_id)
	if marker == null:
		return false
	for offset: Vector2 in [Vector2(0, 48), Vector2(48, 0), Vector2(-48, 0), Vector2(0, -48), Vector2(40, 40), Vector2(-40, 40)]:
		if MapPlacementValidator.is_valid_character_position(map, zone_id, marker.global_position + offset):
			map.runtime_player_body().global_position = marker.global_position + offset
			return _player.set_world_location(map.location_for_zone(zone_id))
	return false


func _npc(map: WorldMapController, point: StringName) -> NpcRuntimeState:
	for npc: NpcRuntimeState in map.npc_runtimes():
		if npc.spawn_point_id == point:
			return npc
	return null


func _check(ok: bool, label: String) -> void:
	_count += 1
	if not ok:
		_failures.append("internal power combat: " + label)
