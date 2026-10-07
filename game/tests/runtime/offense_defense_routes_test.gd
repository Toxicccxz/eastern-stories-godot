extends RefCounted

## Offense/defense routes, PR A: sword/parry/dodge, 封山剑法 and 倒乱七星步法 as data
## (daemon/skill/*.c), weapond.c verbs and race/human.c moves, every apply/* in
## combat (equip.c, set_temp), NPC internal power (race/human.c setup), 柳淳风 and
## 安惜迩 fought (annihir.c accept_fight() answers with kill_ob()), 柳绘心 in the
## study (girl.c) and wear.c's female_only.
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const FONXANSWORD_PREFIX: String = "es2:daemon/skill/fonxansword/"

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_skill_data()
	_test_validation()
	_test_attack_tables()
	_test_apply_values()
	var session: OldPineWorldSessionController = Work.create_session(tree)
	await tree.process_frame
	await _to_snow(tree, session)
	_test_npc_internal_power(session)
	_test_master_projection(session)
	await _test_girl(tree, session)
	await _test_master_spar(tree, session)
	await _test_annihir_kill(tree, session)
	session.free()
	await tree.process_frame
	return {"assertions": _count, "failures": _failures}


func _test_skill_data() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var sword: SkillDefinition = catalog.skill(&"fonxansword")
	var actions: CombatActionSet = sword.action_set()
	_check(actions.size() == 8 and actions.action_at(0).action_id == StringName(FONXANSWORD_PREFIX + "feng-hui-lu-zhuan"), "fonxansword.c: eight moves")
	_check(actions.action_at(0).damage_percent == 30 and actions.action_at(0).damage_type == &"刺伤", "峰回路转: damage 30, 刺伤")
	_check(actions.action_at(3).damage_percent == 0 and actions.action_at(7).damage_percent == 10, "a move without damage adds none")
	_check(sword.valid_enabled_uses() == [&"sword", &"parry"] and catalog.skill(&"chaos-steps").valid_enabled_uses() == [&"dodge", &"move"], "valid_enable()")
	_check(catalog.skill(&"chaos-steps").dodge_messages.size() == 7 and catalog.skill(&"chaos-steps").action_set() == null, "chaos-steps.c: seven dodge lines, no moves")
	_check(catalog.skill(&"fonxanforce").standard_force_hit and catalog.skill(&"celestial").standard_force_hit and not sword.standard_force_hit, "std/force.c hit_ob() kept by fonxanforce and celestial")
	_check(catalog.skill(&"parry").parry_messages_armed.size() == 4 and catalog.skill(&"parry").parry_messages_unarmed.size() == 2, "parry.c's two sets")
	for id: StringName in [&"sword", &"parry", &"dodge", &"force"]:
		_check(catalog.skill(id).kind == SkillDefinition.Kind.BASIC, "%s is basic" % id)


func _test_validation() -> void:
	var errors: Array[String] = []
	SkillDefinition.from_record(ContentRecordReader.new({
		"id": "x", "name": "X", "kind": "specialized", "type": "martial", "enable": ["force"], "legacy_source": "x.c",
		"standard_force_hit": true, "hit_ob": true,
	}, "s", errors))
	_check(errors.size() == 1 and errors[0].contains("hit_ob"), "an own hit_ob() is not std/force.c's: " + str(errors))
	errors.clear()
	ItemContentDefinition.from_record(ContentRecordReader.new({
		"id": "t:blade", "legacy_sources": ["t/blade.c"], "name": "刀", "aliases": ["blade"], "weight": 1,
		"weapon": {"skill": "blade", "damage": 1, "apply": {"strength": 1}},
	}, "i", errors))
	_check(errors.size() == 1 and errors[0].contains("apply.strength"), "only the mudlib's weapon_prop keys: " + str(errors))
	var builder := ContentCatalogBuilder.new()
	builder.add_document({"skills": [{"id": "dodge", "name": "基本轻功", "kind": "basic", "type": "martial", "legacy_source": "d.c"}]}, "k")
	builder.build()
	for expected: String in ["race_actions: no moves for race 'human'", "weapon_actions: no 'slash' action", "skills: 'dodge' needs dodge_messages", "skills: 'parry' needs parry_messages armed and unarmed"]:
		_check(builder.errors().has(expected), "a game catalog needs its fallback moves and lines: " + expected)
	_check(CombatSliceProjectionBuilder._martial_hit_policy(&"liuh-ken", GameContent.catalog().skill(&"liuh-ken").action_set()) == CombatHitPolicyStatus.Value.PROVEN_NO_AUTHORED_EFFECT, "柳家拳 has no hit_ob()")
	_check(CombatSliceProjectionBuilder._martial_hit_policy(&"spicyclaw", null) == CombatHitPolicyStatus.Value.AUTHORED_POLICY_UNAVAILABLE, "an unported mapped skill stops the fight")


func _test_attack_tables() -> void:
	var tables: CombatActionTables = GameContent.catalog().combat_actions()
	var ids: Array[StringName] = []
	for action: CombatActionDefinition in tables.weapon_action_set(&"sword").actions():
		ids.append(action.action_id)
	_check(ids == [&"es2:adm/daemons/weapond/slash", &"es2:adm/daemons/weapond/slice", &"es2:adm/daemons/weapond/thrust"], "std/weapon/sword.c: slash, slice, thrust")
	_check(tables.weapon_action_set(&"blade").action_at(2).damage_percent == 30, "blade.c hack: damage 30")
	var hammer: CombatActionSet = tables.weapon_action_set(&"hammer")
	_check(hammer.size() == 3 and hammer.action_at(0).post_action_policy_id == CombatPostActionIds.BASH_WEAPON, "a hammer bashes, crushes and slams (weapond.c bash_weapon, 野羊山)")
	var human: CombatActionSet = tables.race_action_set(&"human")
	_check(human.size() == 5 and human.action_at(2).legacy_action_text == "$N往$n的$l狠狠地踢了一脚", "race/human.c: five moves")


func _test_apply_values() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	_check(catalog.item(&"es2:d/snow/obj/thin_sword").weapon_apply == {&"courage": -4}, "thin_sword.c: weapon_prop/courage")
	var facts := NpcAuthoredCombatFacts.new([], [], {&"attack": 70, &"parry": 60, &"defense": 5})
	var profile := CombatSliceContentProfile.new(&"", &"", 0, &"human", facts)
	_check([profile.apply_value(&"attack", null), profile.apply_value(&"parry", null), profile.apply_value(&"defense", null)] == [70, 60, 5], "a human's set_temp(apply/...) counts")
	var silk: ItemContentDefinition = catalog.item(&"es2:daemon/class/swordsman/silk_cloth")
	_check(silk.armor_definition().numeric_modifiers.value(&"dodge") == 6, "silk_cloth.c armor_prop/dodge 6")


func _test_npc_internal_power(session: OldPineWorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var master: NpcRuntimeState = _npc(map, &"snow.schoolhall.master.1")
	var state: CharacterState = master.character_state
	_check(state.recovery.inner_force.maximum == 1500 and state.recovery.inner_force.current == 1500 and state.attributes.force_factor == 3, "柳淳风: max_force 1500, force_factor 3")
	_check(state.vitality.maximum == 220 + 1500 / 4, "race/human.c: max_kee 220 + max_force/4")
	var annihir: CharacterState = _npc(map, &"snow.bank.annihir.1").character_state
	_check([annihir.essence.maximum, annihir.vitality.maximum, annihir.spirit.maximum] == [470, 470, 350], "安惜迩: max_gin/kee/sen with max_atman/force/mana / 4")
	var girl: CharacterState = _npc(map, &"snow.nyard.girl.1").character_state
	_check(girl.vitality.maximum == 120 + 200 / 4 and girl.gender == CharacterState.GENDER_FEMALE, "柳绘心: age 15, max_force 200")


func _test_master_projection(session: OldPineWorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var bindings: Array[CombatSliceCharacterBinding] = map._build_participants()
	var master := CombatSliceProjectionBuilder.find_binding(bindings, _npc(map, &"snow.schoolhall.master.1").character_id)
	var annihir := CombatSliceProjectionBuilder.find_binding(bindings, _npc(map, &"snow.bank.annihir.1").character_id)
	var player := CombatSliceProjectionBuilder.find_binding(bindings, session.player_runtime().character_id)
	var input: CombatAttackInput = CombatSliceProjectionBuilder.build_attack_input(master, player, master.content.approved_action_set(
		master.state.equipment.primary_weapon(), &"sword", &"fonxansword").action_at(0))
	_check(input != null and String(input.selected_action.action_id).begins_with(FONXANSWORD_PREFIX), "柳淳风 attacks with 封山剑法")
	_check(input != null and input.attacker.effective_attack_skill_level == 150 / 2 + 150, "sword 150/2 + fonxansword 150")
	var defending: CombatAttackInput = CombatSliceProjectionBuilder.build_attack_input(player, master, player.content.unarmed_action())
	_check(defending != null and defending.defender.effective_dodge_skill_level == 6 + 80 / 2 + 100, "dodge: silk_cloth 6 + 80/2 + chaos-steps 100")
	_check(defending != null and defending.defender.effective_parry_skill_level == 120 / 2 + 150, "parry: 120/2 + fonxansword 150")
	var force: CombatAttackInput = CombatSliceProjectionBuilder.build_attack_input(annihir, player, annihir.content.approved_action_set(
		annihir.state.equipment.primary_weapon(), &"sword", &"fonxansword").action_at(1))
	_check(force != null and force.attacker.force_hit_policy_status == CombatHitPolicyStatus.Value.STANDARD_FORCE, "安惜迩's celestial: combatd.c's standard force hit")


func _test_girl(tree: SceneTree, session: OldPineWorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var hud: SharedGameplayUI = session.shared_ui()
	_check(_beside(map, player, &"snow.nyard", &"snow.nyard.girl.1"), "in the study")
	var girl: NpcRuntimeState = _npc(map, &"snow.nyard.girl.1")
	_check(girl != null and girl.definition().display_name == "柳绘心", "柳绘心 is in the study")
	map.select_npc(girl.character_id)
	map.spar_selected()
	_check(hud.log_lines().slice(-2) == ["柳绘心说道：爹爹说过，不能跟你们这些江湖人物比武过招。", "看起来柳绘心并不想跟你较量。"], "girl.c: no spar with outsiders " + str(hud.log_lines().slice(-2)))
	player.state.family = FamilyState.new(&"family.fonxan", 14)
	map.spar_selected()
	_check(hud.log_lines()[-2] == "柳绘心说道：师姐！别整天想著练功嘛，我们去花园摘花儿玩嘛？", "girl.c: a 封山剑派 sister")
	player.state.gender = CharacterState.GENDER_MALE
	map.spar_selected()
	_check(hud.log_lines()[-2] == "柳绘心说道：我才不要，你们去找李教头练吧！", "girl.c: a 封山剑派 brother")
	_check(not session.combat_encounter_coordinator().has_active_encounter(), "no fight started")
	# wear.c female_only: her clothes are not for a man.
	var cloth: ItemContentDefinition = GameContent.catalog().item(&"es2:d/snow/obj/pink_cloth")
	_check(cloth.female_only and not GameContent.catalog().item(&"es2:obj/cloth").female_only, "pink_cloth.c female_only")
	player.state.gender = CharacterState.GENDER_FEMALE
	player.state.family = FamilyState.new()
	await tree.process_frame


func _test_master_spar(tree: SceneTree, session: OldPineWorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var player: WorldPlayerRuntimeState = session.player_runtime()
	_check(_beside(map, player, &"snow.schoolhall", &"snow.schoolhall.master.1"), "in the hall")
	var master: NpcRuntimeState = _npc(map, &"snow.schoolhall.master.1")
	map.select_npc(master.character_id)
	var started: CombatSliceInitiationResult = map.spar_selected()
	_check(started.outcome == CombatSliceInitiationResult.Outcome.COMPLETED, "柳淳风 accepts a spar (npc.c accept_fight)")
	var seen: Dictionary[String, int] = _run_fight(session)
	_check(seen.get("aborted", 0) == 0 and not session.combat_encounter_coordinator().has_active_encounter(), "the spar runs to its end: " + session.combat_encounter_coordinator().last_abort_detail())
	_check(seen.get("fonxansword", 0) > 0, "柳淳风 used 封山剑法 %s" % str(seen))
	_check(not master.relationship.has_lethal_target(player.character_id), "a spar stays a spar")
	await tree.process_frame


func _test_annihir_kill(tree: SceneTree, session: OldPineWorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var hud: SharedGameplayUI = session.shared_ui()
	_heal(player.state)
	_check(_beside(map, player, &"snow.bank", &"snow.bank.annihir.1"), "in the bank")
	var annihir: NpcRuntimeState = _npc(map, &"snow.bank.annihir.1")
	map.select_npc(annihir.character_id)
	var started: CombatSliceInitiationResult = map.spar_selected()
	_check(started.outcome == CombatSliceInitiationResult.Outcome.COMPLETED, "安惜迩 takes the challenge")
	_check(hud.log_lines().slice(-2) == ["安惜迩说道：咦... 要打就真打吧，光是较量多没意思？", "看起来安惜迩想杀死你！"], "annihir.c accept_fight(), then kill_ob()'s line " + str(hud.log_lines().slice(-3)))
	var red: String = "[color=#%s]看起来安惜迩想杀死你！[/color]" % SharedGameplayUI.ALERT_COLOR.to_html(false)
	_check(hud.combat_log.text.ends_with(red) and not hud.combat_log.text.contains("[color=#%s]安惜迩说道" % SharedGameplayUI.ALERT_COLOR.to_html(false)), "kill_ob()'s line in HIR red, his line plain")
	_check(hud.toasts().is_suppressed() and hud.toasts().latest() == null, "the fight shows its lines: no toast while it runs")
	hud.append_log_lines(["[test] a plain line"])
	_check(hud.combat_log.get_parsed_text().ends_with("[test] a plain line") and hud.toasts().latest() == null, "plain lines stay plain, brackets escaped")
	_check(annihir.relationship.has_lethal_target(player.character_id) and not player.relationship.has_lethal_target(annihir.character_id), "he kills, the challenger only fights (fight.c fight_ob)")
	_check(session.combat_encounter_coordinator().active_encounter().mode == CombatEncounterMode.Value.LETHAL, "a lethal encounter")
	var seen: Dictionary[String, int] = _run_fight(session)
	_check(seen.get("aborted", 0) == 0, "the fight runs without an abort: " + session.combat_encounter_coordinator().last_abort_detail())
	_check(seen.get("fonxansword", 0) > 0, "安惜迩 used 封山剑法 %s" % str(seen))
	await tree.process_frame


func _run_fight(session: OldPineWorldSessionController) -> Dictionary[String, int]:
	var seen: Dictionary[String, int] = {}
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	for _second: int in range(600):
		var advanced: CombatSchedulerAdvanceResult = coordinator.advance_scheduler(1.0)
		for event: CombatSchedulerEvent in advanced.events():
			var resolution: CombatSliceOpportunityResult = event.resolution
			if resolution == null:
				continue
			if resolution.outcome == CombatSliceOpportunityResult.Outcome.ATTACK_CHAIN_INCOMPLETE:
				seen["aborted"] = seen.get("aborted", 0) + 1
			seen["events"] = seen.get("events", 0) + 1
			var moves: Array[String] = []
			if resolution.forward_result != null:
				moves.append(String(resolution.forward_result.selected_action_id))
			if resolution.chain_result != null:
				moves.append(String(resolution.chain_result.reverse_selected_action_id))
			for move: String in moves:
				seen[move] = seen.get(move, 0) + 1
				if move.begins_with(FONXANSWORD_PREFIX):
					seen["fonxansword"] = seen.get("fonxansword", 0) + 1
		if not coordinator.has_active_encounter():
			break
	if not coordinator.last_abort_detail().is_empty():
		seen["aborted"] = seen.get("aborted", 0) + 1
	return seen


func _heal(state: CharacterState) -> void:
	for resource: CharacterResourceState in [state.essence, state.vitality, state.spirit]:
		resource.effective = resource.maximum
		resource.current = resource.maximum


func _to_snow(tree: SceneTree, session: OldPineWorldSessionController) -> void:
	Input.action_press("move_right")
	for _step: int in range(400):
		await tree.physics_frame
		if session.active_map_id() == &"snow.outdoor":
			break
	Input.action_release("move_right")
	await tree.physics_frame
	session.set_process(false)
	_check(session.active_map_id() == &"snow.outdoor", "out of the Inn")


func _beside(map: WorldMapController, player: WorldPlayerRuntimeState, zone_id: StringName, point_id: StringName) -> bool:
	var marker: WorldSpawnMarker2D = map.resolve_spawn_marker(point_id)
	if marker == null:
		return false
	for offset: Vector2 in [Vector2(0, 48), Vector2(48, 0), Vector2(-48, 0), Vector2(0, -48), Vector2(40, 40), Vector2(-40, 40)]:
		if MapPlacementValidator.is_valid_character_position(map, zone_id, marker.global_position + offset):
			map.runtime_player_body().global_position = marker.global_position + offset
			return player.set_world_location(map.location_for_zone(zone_id))
	return false


func _npc(map: WorldMapController, point: StringName) -> NpcRuntimeState:
	for npc: NpcRuntimeState in map.npc_runtimes():
		if npc.spawn_point_id == point:
			return npc
	return null


func _check(ok: bool, label: String) -> void:
	_count += 1
	if not ok: _failures.append("offense/defense: " + label)
