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
	_modern_death()
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


## DECISIONS「减轻死亡」: the record's knobs lighten killer_reward(); 经典 is ES2 to the digit.
func _modern_death() -> void:
	var modern: PacingDefinition = PacingDefinition.new(1000).with_death(3, true, true, true)
	var state: CharacterState = _dying()
	var result: PlayerDeathResult = PlayerDeathRules.die(state, true, modern)
	check(result.penalized and result.combat_experience_lost == 37 and state.progression.combat_experience == 1197, "现代: 3% of combat_exp")
	check(result.potential_lost == 0 and state.progression.potential == 100, "现代: unspent potential stays")
	check(result.skill_changes.is_empty() and result.enabled_skills_cleared == 0 and state.skills.raw_level(&"unarmed") == 3 and state.skills.has_raw_level(&"liuh-ken") and state.skills.mapped_skill(&"unarmed") == &"liuh-ken", "现代: every skill and enable stays")
	check(result.bellicosity_lost == 300 and state.attributes.bellicosity == 0, "现代: bellicosity still resets (a state, not a loss)")
	check([state.vitality.current, state.vitality.effective] == [1, 1] and state.ghost, "现代: still a ghost at 1/1, 阴间 is walked")
	var accident: CharacterState = _dying()
	check(not PlayerDeathRules.die(accident, false, modern).penalized and accident.progression.combat_experience == 1234, "现代: no killer, no penalty")
	var classic: PacingDefinition = PacePresets.of(PacingDefinition.new(1000).with_death(3, true, true, true).with_autosave(180), CharacterState.PACE_CLASSIC)
	check(classic.death_exp_percent == 10 and not classic.death_keeps_potential and not classic.death_keeps_skills and not classic.player_corpse_stays and classic.autosave_min_seconds == 0, "经典 puts all of them back and has no autosave")
	var with_knobs: CharacterState = _dying()
	var plain: CharacterState = _dying()
	var a: PlayerDeathResult = PlayerDeathRules.die(with_knobs, true, classic)
	var b: PlayerDeathResult = PlayerDeathRules.die(plain, true)
	check(a.combat_experience_lost == b.combat_experience_lost and a.potential_lost == b.potential_lost and a.skill_changes.size() == b.skill_changes.size() and a.enabled_skills_cleared == b.enabled_skills_cleared, "经典 costs what ES2 costs, item by item")
	check(with_knobs.progression.combat_experience == 1111 and with_knobs.skills.raw_level(&"unarmed") == 2 and not with_knobs.skills.has_raw_level(&"liuh-ken") and with_knobs.skills.mapped_skill(&"unarmed") == &"", "经典: combat_exp / 10, every skill a level, enables gone")


func _dying() -> CharacterState:
	var state: CharacterState = CharacterState.new()
	state.progression.combat_experience = 1234
	state.progression.potential = 100
	state.progression.potential_spent = 40
	state.attributes.bellicosity = 300
	state.vitality = CharacterResourceState.new(50, 80, 100)
	state.skills.set_raw_level(&"unarmed", 3)
	state.skills.set_raw_level(&"liuh-ken", 0)
	state.skills.map_skill(&"unarmed", &"liuh-ken")
	return state


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
	check(flow.advance(600.0) == PlayerLifeFlow.Event.NONE, "the death card waits for the player")
	flow.continue_from_death()
	check(flow.advance(0.0) == PlayerLifeFlow.Event.ENTER_REALM_DUE and flow.advance(1.0) == PlayerLifeFlow.Event.ENTER_REALM_DUE, "继续: the move to 阴间 is due until it is made")
	flow.finish()
	check(not flow.is_active(), "made: the flow is over")


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
	session.continue_after_death()
	check(not flow.is_active() and session.active_map_id() == DeathWorldDefinitions.MAP_ID and player.state.ghost and player.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE, "继续: a ghost at 鬼门关")
	session.world_map_of(DeathWorldDefinitions.MAP_ID).npc_life._advance_ambience(0.0)
	for second: int in range(24):
		session._process(1.0)
	check(player.state.ghost and session.active_map_id() == DeathWorldDefinitions.MAP_ID, "still with the white gargoyle a second before his last line")
	session._process(1.0)
	check(not player.state.ghost and player.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE and player.exists_in_world, "alive again with his last line")
	check(session.active_map_id() == SnowWorldDefinitions.temple_map_id() and player.world_location().zone_id == SnowWorldDefinitions.TEMPLE_ZONE_ID, "back at the Snow temple (its own map since the remap)")
	# A ghost's heal_up() ticks on its random cadence: two in these 25 s make it 2.
	check(player.state.vitality.current <= 2 and player.state.vitality.effective == player.state.vitality.maximum, "reincarnated with about 1 kee and full effective kee")
	check(session.active_map().runtime_player_body().player_controlled and session.active_map().runtime_player_body().visible, "the player can move again")
	check(OldPineSaveEligibility.inspect(session).allowed(), "saving works again")
	check(Work.capture(session) != null, "a save captures the living player with their Old Pine corpse")
	check(map.corpse_states().size() == 1 and session.inventory_state().direct_children(corpse_owner) == carried, "the corpse still waits in Old Pine")
	# d/snow/temple.c exits: west to the square, south to the first east road.
	var snow: WorldMapController = session.active_map() as WorldMapController
	# Since the remap the temple is its own map: its doors are portals, walked through with the move actions.
	check(await MapPlaces.take_passage(tree, snow, &"snow.temple.west"), "the temple's west door takes the player off the temple's map")
	await tree.physics_frame
	await tree.physics_frame
	check(session.active_map_id() == SnowWorldDefinitions.OUTDOOR_MAP_ID and player.world_location().zone_id == &"snow.square", "the temple's west door leads to the square")
	var street: WorldMapController = session.active_map() as WorldMapController
	check(await MapPlaces.take_passage(tree, street, &"snow.square.east"), "the square's east door takes the player into the temple again")
	await tree.physics_frame
	await tree.physics_frame
	var inside: WorldMapController = session.active_map() as WorldMapController
	check(inside.map_id() == SnowWorldDefinitions.temple_map_id() and player.world_location().zone_id == SnowWorldDefinitions.TEMPLE_ZONE_ID, "and the square's east door leads back to the temple")
	check(await MapPlaces.take_passage(tree, inside, &"snow.temple.south"), "the temple's south door takes the player off the temple's map")
	await tree.physics_frame
	await tree.physics_frame
	check(session.active_map_id() == SnowWorldDefinitions.OUTDOOR_MAP_ID and player.world_location().zone_id == &"snow.eroad1", "the temple's south door leads to the east road")
	session.free()
	await tree.process_frame


func _unconscious_without_killer_wakes_up(tree: SceneTree) -> void:
	# ES2's pace (player_wake_seconds 0): the player waits damage.c's delay itself.
	var previous: PacingDefinition = Es2Pacing.use()
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
	# The production pace (owner, modern fixes II, A9): three real seconds in the dark.
	Es2Pacing.restore(previous)
	player.set_life_status(CharacterRuntimeLifeStatus.Value.UNCONSCIOUS)
	session.on_player_lifecycle(receipt, false, player.world_location())
	check(flow.wakes_quickly() and flow.revive_remaining_seconds >= 30.0, "a quick wake: the same delay in world time")
	session._process(1.0)
	session._process(1.0)
	check(player.life_status == CharacterRuntimeLifeStatus.Value.UNCONSCIOUS, "two seconds: still out")
	session._process(1.0)
	check(player.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE and not flow.is_active(), "three seconds: awake")
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
	restored.continue_after_death()
	restored.world_map_of(DeathWorldDefinitions.MAP_ID).npc_life._advance_ambience(0.0)
	for second: int in range(26):
		restored._process(1.0)
	check(restored.player_runtime().life_status == CharacterRuntimeLifeStatus.Value.ACTIVE and restored.player_runtime().world_location().zone_id == SnowWorldDefinitions.TEMPLE_ZONE_ID, "restored ghost comes back at the temple")
	check(restored.player_runtime().state.progression.combat_experience == experience, "experience is not taken twice")
	restored.free()
	await tree.process_frame


func check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok:
		failures.append("death/revival: " + label)
