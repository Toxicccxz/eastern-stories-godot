extends RefCounted

## ES2 unconsciousness and death for the public player: killers finish an
## unconscious player, death costs what killer_reward() takes, and the player
## comes back at the Snow temple instead of the run ending.
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const SESSION := preload("res://scenes/world/oldpine/oldpine_world_session.tscn")

var assertions: int = 0
var failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_death_rules()
	_skill_death_penalty()
	_revive_delay()
	_life_flow_timeline()
	await _killers_finish_unconscious_player(tree)
	await _death_brings_player_back_at_temple(tree)
	await _unconscious_without_killer_wakes_up(tree)
	await _restored_dead_player_continues(tree)
	return {"assertions": assertions, "failures": failures}


func _death_rules() -> void:
	var state: CharacterState = CharacterState.new()
	state.progression.combat_experience = 1234
	state.progression.potential = 100
	state.progression.potential_spent = 40
	state.attributes.bellicosity = 300
	state.vitality = CharacterResourceState.new(50, 80, 100)
	state.conditions.add_or_replace_duration(&"drunk", 5)
	var result: PlayerDeathResult = PlayerDeathRules.die(state, true)
	check(result.penalized and result.combat_experience_lost == 123 and state.progression.combat_experience == 1111, "combat_exp -= combat_exp / 10")
	check(result.potential_lost == 30 and state.progression.potential == 70, "unspent potential halves toward learned_points")
	check(result.bellicosity_lost == 300 and state.attributes.bellicosity == 0, "bellicosity reset")
	check(result.conditions_cleared == 1 and state.conditions.size() == 0, "clear_condition()")
	check([state.vitality.current, state.vitality.effective, state.vitality.maximum] == [1, 1, 100], "ghost resources 1/1")
	PlayerDeathRules.reincarnate(state)
	check([state.vitality.current, state.vitality.effective] == [1, 100], "reincarnate restores effective only")
	var spent: CharacterState = CharacterState.new()
	spent.progression.potential = 30
	spent.progression.potential_spent = 40
	check(PlayerDeathRules.die(spent, true).potential_lost == 0 and spent.progression.potential == 30, "potential already spent is kept")
	var accident: CharacterState = CharacterState.new()
	accident.progression.combat_experience = 500
	accident.conditions.add_or_replace_duration(&"drunk", 5)
	var no_killer: PlayerDeathResult = PlayerDeathRules.die(accident, false)
	check(not no_killer.penalized and accident.progression.combat_experience == 500 and accident.conditions.size() == 0, "no killer: conditions cleared, no penalty")


func _skill_death_penalty() -> void:
	var empty: CharacterSkillState = CharacterSkillState.new()
	check(empty.apply_death_penalty().is_empty() and not empty.has_skills_mapping(), "no skills mapping: nothing to lose")
	var plain: CharacterSkillState = CharacterSkillState.new()
	plain.set_raw_level(&"unarmed", 3)
	plain.set_raw_level(&"liuh-ken", 0)
	check(plain.map_skill(&"unarmed", &"liuh-ken"), "fixture maps unarmed to liuh-ken")
	var changes: Array[SkillDeathPenaltyChange] = plain.apply_death_penalty()
	check(plain.raw_level(&"unarmed") == 2 and not plain.has_raw_level(&"liuh-ken"), "without learned mapping every skill drops a level; below 0 is deleted")
	check(plain.enabled_use_ids().is_empty(), "skill_map = 0: every enabled skill is disabled")
	var kept: CharacterSkillState = CharacterSkillState.new()
	kept.set_raw_level(&"unarmed", 3)
	kept.set_raw_level(&"liuh-ken", 5)
	kept.map_skill(&"unarmed", &"liuh-ken")
	kept.apply_death_penalty()
	check(kept.raw_level(&"liuh-ken") == 4 and kept.mapped_skill(&"unarmed") == &"", "even a surviving mapped skill is disabled")
	check(changes.size() == 2 and changes[0].skill_id == &"liuh-ken" and changes[0].level_after == -1 and changes[1].level_before == 3 and changes[1].level_after == 2, "changes are reported in id order")
	var learned: CharacterSkillState = CharacterSkillState.new()
	learned.set_raw_level(&"unarmed", 3)
	learned.set_learned_progress(&"unarmed", 9)
	learned.set_raw_level(&"parry", 3)
	learned.set_learned_progress(&"parry", 8)
	var learned_changes: Array[SkillDeathPenaltyChange] = learned.apply_death_penalty()
	check(learned.raw_level(&"unarmed") == 3 and learned.learned_progress(&"unarmed") == 0 and learned_changes[1].progress_cleared, "progress above (lvl+1)^2/2 = 8 is wiped instead of a level")
	check(learned.raw_level(&"parry") == 2 and learned.learned_progress(&"parry") == 8, "progress at the threshold keeps it and loses a level")


func _revive_delay() -> void:
	var draws: ScriptedCombatRandomSource = ScriptedCombatRandomSource.new([50])
	check(UnconsciousReviveDelay.seconds(20, draws) == 80 and draws.requested_bounds() == [80], "random(100 - con) + 30")
	var none: ScriptedCombatRandomSource = ScriptedCombatRandomSource.new([50])
	check(UnconsciousReviveDelay.seconds(100, none) == 30 and none.call_count() == 0, "random(n <= 0) is 0 without a draw")


func _life_flow_timeline() -> void:
	var flow: PlayerLifeFlow = PlayerLifeFlow.new()
	flow.begin_unconscious(40)
	check(flow.advance(39.5) == PlayerLifeFlow.Event.NONE and flow.advance(0.5) == PlayerLifeFlow.Event.REVIVE_DUE, "wake-up after the drawn delay")
	flow.begin_death(PlayerDeathResult.new(), "老松岭 · 南坡林道")
	check(flow.advance(4.9) == PlayerLifeFlow.Event.NONE and flow.messages_shown().is_empty(), "the gargoyle waits 5 s")
	check(flow.advance(0.1) == PlayerLifeFlow.Event.MESSAGE_SHOWN and flow.messages_shown().size() == 1, "first line at 5 s")
	check(flow.skip_to_next_message() == PlayerLifeFlow.Event.MESSAGE_SHOWN and flow.messages_shown().size() == 2, "the player may read ahead")
	flow.advance(5.0)
	flow.advance(5.0)
	check(flow.advance(5.0) == PlayerLifeFlow.Event.REINCARNATE_DUE and flow.messages_shown().size() == 5, "last line and reincarnation together")


## Returns [session, outdoor map] with the player in an encounter against the
## three spath1 bandits, who attack on sight.
func _bandits_attack(tree: SceneTree) -> Array:
	var session: WorldSessionController = Work.create_session(tree)
	await tree.process_frame
	session.set_process(false)
	var portal: PortalDefinition = GameContent.catalog().portal(SnowOldPineConnectionDefinitions.SOUTH_PORTAL_ID)
	check(session.handoff_to(portal.destination_map_id, portal.destination_zone_id, portal.destination_zone_id, portal.destination_spawn_point_id).succeeded(), "fixture enters Old Pine")
	var map: WorldMapController = session.world_map_of(OldPineWorldDefinitions.OUTDOOR_MAP_ID)
	var player: WorldPlayerRuntimeState = session.player_runtime()
	map.player_body.set_world_location(map.location_for_zone(&"oldpine.outdoor.slope"))
	map.player_body.global_position = OldPineTestMap.body(map, "Bandit01").global_position + Vector2(0, 40)
	for bandit: NpcRuntimeState in map.npc_runtimes().slice(0, 3):
		map.aggression_adapter().enter_player_presence(bandit, player, true)
	map.process_pending_aggression()
	check(session.combat_encounter_coordinator().has_active_encounter(), "bandits attack on sight")
	return [session, map]


func _run_encounter(session: WorldSessionController) -> void:
	for step: int in range(400):
		if not session.combat_encounter_coordinator().has_active_encounter():
			return
		session.combat_encounter_coordinator().advance_scheduler(100)


func _killers_finish_unconscious_player(tree: SceneTree) -> void:
	var fixture: Array = await _bandits_attack(tree)
	var session: WorldSessionController = fixture[0]
	var map: WorldMapController = fixture[1]
	var player: WorldPlayerRuntimeState = session.player_runtime()
	# Knocked out but not mortally wounded: kee < 0, eff_kee >= 0.
	player.state.vitality.current = -1
	_run_encounter(session)
	var outcomes: Array[int] = []
	for receipt: CombatSliceLifecycleResult in map.last_lifecycle_results():
		outcomes.append(receipt.outcome)
	check(outcomes == [CombatSliceLifecycleResult.Outcome.UNCONSCIOUS_COMPLETE, CombatSliceLifecycleResult.Outcome.DEATH_COMPLETE], "the player falls unconscious, then a killer finishes them")
	check(player.life_status == CharacterRuntimeLifeStatus.Value.DEAD and map.corpse_states().size() == 1, "death leaves a corpse")
	check(session.player_life_flow().phase == PlayerLifeFlow.Phase.DEATH_SEQUENCE and session.player_life_flow().death_result.penalized, "the unconscious-then-killed path goes to the death sequence with the penalty")
	session.free()
	await tree.process_frame


func _death_brings_player_back_at_temple(tree: SceneTree) -> void:
	var fixture: Array = await _bandits_attack(tree)
	var session: WorldSessionController = fixture[0]
	var map: WorldMapController = fixture[1]
	var player: WorldPlayerRuntimeState = session.player_runtime()
	player.state.progression.combat_experience = 1000
	var carried: Array[StringName] = session.inventory_state().direct_children(ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, player.character_id))
	player.state.vitality.effective = -1
	_run_encounter(session)
	var flow: PlayerLifeFlow = session.player_life_flow()
	check(player.life_status == CharacterRuntimeLifeStatus.Value.DEAD and flow.phase == PlayerLifeFlow.Phase.DEATH_SEQUENCE, "death starts the way back")
	check(flow.death_result.penalized and flow.death_result.combat_experience_lost == 100 and player.state.progression.combat_experience == 900, "the killer's reward penalty applies")
	check(flow.corpse_place == "老松岭 · 林间小路", "the death screen names where the corpse lies")
	check(not OldPineSaveEligibility.inspect(session).allowed(), "no saving while dead")
	var corpse: CorpseState = map.corpse_states()[0]
	var corpse_owner: ContainmentEndpoint = ContainmentEndpoint.new(ContainmentEndpoint.Kind.ITEM, corpse.corpse_item_instance_id)
	check(session.inventory_state().direct_children(corpse_owner) == carried, "everything carried is in the corpse")
	session.skip_death_message()
	check(flow.messages_shown().size() == 1, "reading ahead shows the next line")
	for second: int in range(19):
		session._process(1.0)
	check(flow.is_active() and player.life_status == CharacterRuntimeLifeStatus.Value.DEAD, "still with the gargoyle a second before the last line")
	session._process(1.0)
	check(not flow.is_active() and player.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE and player.exists_in_world, "alive again with the last line")
	check(session.active_map_id() == SnowWorldDefinitions.OUTDOOR_MAP_ID and player.world_location().zone_id == SnowWorldDefinitions.TEMPLE_ZONE_ID, "back at the Snow temple")
	check([player.state.vitality.current, player.state.vitality.effective] == [1, player.state.vitality.maximum], "reincarnated with 1 kee and full effective kee")
	check(session.active_map().runtime_player_body().player_controlled and session.active_map().runtime_player_body().visible, "the player can move again")
	check(OldPineSaveEligibility.inspect(session).allowed(), "saving works again")
	check(Work.capture(session) != null, "a save captures the living player with their Old Pine corpse")
	check(map.corpse_states().size() == 1 and session.inventory_state().direct_children(corpse_owner) == carried, "the corpse still waits in Old Pine")
	# d/snow/temple.c exits: west to the square, south to the first east road.
	var snow: WorldMapController = session.active_map() as WorldMapController
	check(await MapPlaces.drive_to_zone(tree, snow, &"snow.square") and player.world_location().zone_id == &"snow.square", "the temple's west door leads to the square")
	check(await MapPlaces.drive_through(tree, snow, [&"snow.temple", &"snow.eroad1"]) and player.world_location().zone_id == &"snow.eroad1", "the temple's south door leads to the east road")
	session.free()
	await tree.process_frame


func _unconscious_without_killer_wakes_up(tree: SceneTree) -> void:
	var session: WorldSessionController = Work.create_session(tree)
	await tree.process_frame
	session.set_process(false)
	var player: WorldPlayerRuntimeState = session.player_runtime()
	player.set_life_status(CharacterRuntimeLifeStatus.Value.UNCONSCIOUS)
	var receipt: CombatSliceLifecycleResult = CombatSliceLifecycleResult.new()
	receipt._outcome = CombatSliceLifecycleResult.Outcome.UNCONSCIOUS_COMPLETE
	session.on_player_lifecycle(receipt, false, player.world_location())
	var flow: PlayerLifeFlow = session.player_life_flow()
	var delay: float = flow.revive_remaining_seconds
	check(flow.phase == PlayerLifeFlow.Phase.UNCONSCIOUS and delay >= 30.0 and delay < 130.0, "wake-up delay within random(100 - con) + 30")
	check(not OldPineSaveEligibility.inspect(session).allowed(), "no saving while unconscious")
	session._process(delay - 1.0)
	check(player.life_status == CharacterRuntimeLifeStatus.Value.UNCONSCIOUS, "still out before the delay")
	session._process(1.0)
	check(player.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE and not flow.is_active(), "wakes up where they fell")
	check(player.world_location().map_id == SnowWorldDefinitions.INN_MAP_ID, "no relocation on waking")
	session.free()
	await tree.process_frame


func _restored_dead_player_continues(tree: SceneTree) -> void:
	var fixture: Array = await _bandits_attack(tree)
	var session: WorldSessionController = fixture[0]
	var player: WorldPlayerRuntimeState = session.player_runtime()
	player.state.vitality.effective = -1
	_run_encounter(session)
	var experience: int = player.state.progression.combat_experience
	# Saves like this came from builds without the way back from death.
	var snapshot: GameSaveSnapshot = Work.capture(session)
	check(snapshot != null, "capture of a dead player")
	session.free()
	var preparation: OldPineWorldRestoreResult = OldPineWorldRestoreComposition.prepare(snapshot)
	var restored: WorldSessionController = SESSION.instantiate()
	check(restored.configure_restore(preparation.preparation), "restore configured")
	tree.root.add_child(restored)
	check(restored.activate_restore_candidate(), "restore activated")
	restored.set_process(false)
	var flow: PlayerLifeFlow = restored.player_life_flow()
	check(flow.phase == PlayerLifeFlow.Phase.DEATH_SEQUENCE and not flow.death_result.penalized, "the way back resumes without a second penalty")
	for second: int in range(25):
		restored._process(1.0)
	check(restored.player_runtime().life_status == CharacterRuntimeLifeStatus.Value.ACTIVE and restored.player_runtime().world_location().zone_id == SnowWorldDefinitions.TEMPLE_ZONE_ID, "restored ghost comes back at the temple")
	check(restored.player_runtime().state.progression.combat_experience == experience, "experience is not taken twice")
	restored.free()
	await tree.process_frame


func check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok:
		failures.append("death/revival: " + label)
