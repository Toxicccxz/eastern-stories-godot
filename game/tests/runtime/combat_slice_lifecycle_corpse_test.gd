extends RefCounted

const SCENE_PATH: String = "res://scenes/combat/combat_vertical_slice.tscn"
const ScriptedRandomScript := preload(
	"res://tests/support/scripted_combat_random_source.gd"
)

class MaximumCombatRandomSource extends CombatRandomSource:
	var _call_count: int = 0

	func next_below(exclusive_upper_bound: int) -> int:
		_call_count += 1
		return exclusive_upper_bound - 1 if exclusive_upper_bound > 0 else -1

	func call_count() -> int:
		return _call_count

var _assertion_count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_relationship_clear_preserves_source_facts()
	_test_unconscious_adapter_exact_transition()
	_test_second_corpse_placement_failure_preserves_partial_transition()
	await _test_player_unconscious_continues_same_tick(tree)
	await _test_complete_enemy_defeat_path(tree)
	await _test_complete_player_defeat_path(tree)
	await _test_npc_death_creates_authoritative_corpse(tree)
	await _test_player_death_is_terminal_until_reset(tree)
	await _test_blocked_death_preserves_partial_state_and_is_not_retried(tree)
	await _test_failed_death_is_not_retried(tree)
	await _test_reset_clears_corpses_and_lifecycle_state(tree)
	return {
		"assertions": _assertion_count,
		"failures": _failures.duplicate(),
	}


func _test_relationship_clear_preserves_source_facts() -> void:
	var relationship: CombatRelationshipState = CombatRelationshipState.new(&"victim")
	relationship.mark_lethal_target(&"killer")
	relationship.add_opponent(&"ordinary")
	relationship.set_guarding(true)
	relationship.set_last_opponent(&"killer")
	relationship.clear_opponents_preserving_lethal_targets()
	_assert_true(relationship.opponent_ids().is_empty(), "remove_all_enemy clears the local ordered opponent list")
	_assert_true(relationship.has_lethal_target(&"killer"), "remove_all_enemy preserves killer intent")
	_assert_true(relationship.guarding, "remove_all_enemy preserves guarding")
	_assert_eq(relationship.last_opponent_id, &"killer", "remove_all_enemy preserves last opponent")
	relationship.clear_opponents_preserving_lethal_targets()
	_assert_true(relationship.opponent_ids().is_empty(), "folded second remove_all_enemy is an idempotent no-op on the empty list")
	_assert_true(relationship.has_lethal_target(&"killer"), "folded second remove_all_enemy still preserves killer intent")
	var ordinary_pair: Array[CombatSliceCharacterBinding] = CombatSliceDemoFactory.create_participants()
	ordinary_pair[0].relationship.add_opponent(ordinary_pair[1].character_id)
	ordinary_pair[1].relationship.add_opponent(ordinary_pair[0].character_id)
	ordinary_pair[0].state.vitality.current = -1
	var ordinary_request: CombatSliceOpportunityResult = CombatSliceOpportunityExecutor.execute_opportunity(
		ordinary_pair[0],
		ordinary_pair,
		ScriptedRandomScript.new([]),
		SkillImprovementEffectRegistry.new(),
	)
	var ordinary_result: CombatSliceLifecycleResult = CombatSliceLifecycleAdapter.new().execute(
		ordinary_request,
		ordinary_pair[0],
		ordinary_pair,
		ordinary_pair[1],
		InventoryState.new(),
		CombinedStackCollection.new(),
		&"unused-ordinary-corpse",
		_arena_destination(),
		[],
		DeathItemPolicyRegistry.new(),
		DeathRewearPolicyRegistry.new(),
	)
	_assert_eq(ordinary_result.reciprocal_cleanup_successes, 1, "ordinary reciprocal opponent removal succeeds")
	_assert_false(ordinary_pair[1].relationship.has_opponent(ordinary_pair[0].character_id), "ordinary reciprocal side no longer fights unconscious victim")


func _test_unconscious_adapter_exact_transition() -> void:
	var pair: Array[CombatSliceCharacterBinding] = CombatSliceDemoFactory.create_participants()
	var victim: CombatSliceCharacterBinding = pair[0]
	var killer: CombatSliceCharacterBinding = pair[1]
	CombatSliceOpportunityExecutor.initiate_lethal_combat(killer, victim)
	victim.state.essence = CharacterResourceState.new(-1, 41, 60)
	victim.state.vitality = CharacterResourceState.new(17, 42, 70)
	victim.state.spirit = CharacterResourceState.new(9, 43, 80)
	var random: ScriptedCombatRandomSource = ScriptedRandomScript.new([])
	var opportunity: CombatSliceOpportunityResult = (
		CombatSliceOpportunityExecutor.execute_opportunity(
			victim,
			pair,
			random,
			SkillImprovementEffectRegistry.new(),
		)
	)
	_assert_eq(random.call_count(), 0, "lifecycle gate consumes no combat RNG")
	var result: CombatSliceLifecycleResult = CombatSliceLifecycleAdapter.new().execute(
		opportunity,
		victim,
		pair,
		killer,
		InventoryState.new(),
		CombinedStackCollection.new(),
		&"unused-corpse",
		_arena_destination(),
		[],
		DeathItemPolicyRegistry.new(),
		DeathRewearPolicyRegistry.new(),
	)
	_assert_eq(result.outcome, CombatSliceLifecycleResult.Outcome.UNCONSCIOUS_COMPLETE, "current below zero completes unconscious lifecycle")
	_assert_eq(result.requested_kind, CombatSliceLifecycleResult.RequestedKind.UNCONSCIOUS, "B1 request kind is retained")
	_assert_eq(result.old_life_status, CombatSliceLifeStatus.Value.ACTIVE, "old life status is recorded")
	_assert_eq(result.new_life_status, CombatSliceLifeStatus.Value.UNCONSCIOUS, "new life status is recorded")
	_assert_eq([victim.state.essence.current, victim.state.vitality.current, victim.state.spirit.current], [0, 0, 0], "unconscious sets all three current resources exactly zero")
	_assert_eq([victim.state.essence.effective, victim.state.vitality.effective, victim.state.spirit.effective], [41, 42, 43], "unconscious preserves all effective resources")
	_assert_eq([victim.state.essence.maximum, victim.state.vitality.maximum, victim.state.spirit.maximum], [60, 70, 80], "unconscious preserves all maxima")
	_assert_true(result.resources_zeroed, "result records current-resource transition")
	_assert_true(result.local_opponents_cleared, "victim local opponents are cleared")
	_assert_true(victim.relationship.has_lethal_target(killer.character_id), "victim lethal marker survives unconscious cleanup")
	_assert_true(killer.relationship.has_opponent(victim.character_id), "reciprocal lethal side may refuse ordinary removal")
	_assert_eq(result.reciprocal_cleanup_attempts, 1, "one reciprocal cleanup is attempted")
	_assert_eq(result.reciprocal_cleanup_successes, 0, "lethal reciprocal removal refusal is preserved")
	_assert_eq(random.call_count(), 0, "unconscious transition introduces no RNG")

	## A later current-threshold crossing while already unconscious requests death.
	victim.state.vitality.current = -1
	var later: CombatSliceOpportunityResult = CombatSliceOpportunityExecutor.execute_opportunity(
		victim,
		pair,
		random,
		SkillImprovementEffectRegistry.new(),
	)
	_assert_eq(later.outcome, CombatSliceOpportunityResult.Outcome.LIFECYCLE_REQUIRED_DEATH, "current below zero while already unconscious requests death")
	var death_inventory: InventoryState = InventoryState.new()
	var death_result: CombatSliceLifecycleResult = CombatSliceLifecycleAdapter.new().execute(
		later,
		victim,
		pair,
		killer,
		death_inventory,
		CombinedStackCollection.new(),
		&"current-threshold-corpse",
		_arena_destination(),
		[],
		DeathItemPolicyRegistry.new(),
		DeathRewearPolicyRegistry.new(),
	)
	_assert_eq(death_result.outcome, CombatSliceLifecycleResult.Outcome.DEATH_COMPLETE, "current below zero while unconscious completes normal death")
	_assert_eq(victim.life_status, CombatSliceLifeStatus.Value.DEAD, "second threshold transition marks victim dead")
	_assert_false(victim.exists_in_encounter, "second threshold transition removes victim availability")
	_assert_true(death_inventory.is_registered(&"current-threshold-corpse"), "current-threshold death creates a corpse")


func _test_second_corpse_placement_failure_preserves_partial_transition() -> void:
	var pair: Array[CombatSliceCharacterBinding] = CombatSliceDemoFactory.create_participants()
	var victim: CombatSliceCharacterBinding = pair[0]
	var killer: CombatSliceCharacterBinding = pair[1]
	CombatSliceOpportunityExecutor.initiate_lethal_combat(killer, victim)
	victim.state.vitality.effective = -1
	var opportunity: CombatSliceOpportunityResult = CombatSliceOpportunityExecutor.execute_opportunity(
		victim,
		pair,
		ScriptedRandomScript.new([]),
		SkillImprovementEffectRegistry.new(),
	)
	var inventory: InventoryState = CombatSliceDemoFactory.create_inventory_for(pair)
	var constrained_arena: InventoryTransferDestination = InventoryTransferDestination.new(
		ContainmentEndpoint.new(ContainmentEndpoint.Kind.WORLD, CombatSliceDemoFactory.ARENA_ID),
		true,
		true,
		CombatSliceDeathAdapter.BODY_OWN_WEIGHT - 1,
	)
	var result: CombatSliceLifecycleResult = CombatSliceLifecycleAdapter.new().execute(
		opportunity,
		victim,
		pair,
		killer,
		inventory,
		CombinedStackCollection.new(),
		&"second-placement-failure-corpse",
		constrained_arena,
		CombatSliceDemoFactory.create_death_item_facts_for(victim, inventory),
		DeathItemPolicyRegistry.new(),
		DeathRewearPolicyRegistry.new(),
	)
	_assert_eq(result.death_inventory_result.completion_status, DeathInventoryResult.CompletionStatus.COMPLETED, "closed death service completes inventory processing despite the source-positioned first placement failure")
	_assert_true(result.second_corpse_placement_result != null, "damage.c second corpse placement is actually attempted")
	_assert_eq(result.second_corpse_placement_result.outcome, InventoryTransferResult.Outcome.CAPACITY_EXCEEDED, "second placement preserves its exact transfer failure")
	_assert_eq(result.outcome, CombatSliceLifecycleResult.Outcome.DEATH_INVENTORY_FAILED, "failed second placement blocks terminal lifecycle completion")
	_assert_eq(result.partial_stage, CombatSliceLifecycleResult.PartialStage.DEATH_INVENTORY, "failed second placement remains at the inventory stage")
	_assert_eq(victim.life_status, CombatSliceLifeStatus.Value.ACTIVE, "failed second placement does not mark the victim dead")
	_assert_true(victim.exists_in_encounter, "failed second placement does not remove encounter availability")
	_assert_true(killer.relationship.has_lethal_target(victim.character_id), "final lethal cleanup is not run before second placement succeeds")
	var corpse_endpoint: ContainmentEndpoint = ContainmentEndpoint.new(ContainmentEndpoint.Kind.ITEM, result.corpse_item_instance_id)
	_assert_true(inventory.is_direct_child(&"combat-slice-player-long-sword", corpse_endpoint), "already-completed sword transfer remains preserved inside the corpse")


func _test_player_unconscious_continues_same_tick(tree: SceneTree) -> void:
	var controller: CombatVerticalSliceController = _instantiate_scene(tree)
	await tree.physics_frame
	var random: ScriptedCombatRandomSource = ScriptedRandomScript.new(_regular_hit_draws(2))
	controller.configure_random_source(random)
	controller.select_enemy()
	controller.initiate_selected_combat()
	controller.opportunity_timer.stop()
	controller.player_binding.state.essence.current = -1
	var start_position: Vector2 = controller.player_body.position
	var results: Array[CombatSliceOpportunityResult] = controller.process_cadence_tick()
	_assert_eq(results.size(), 2, "player unconscious lifecycle permits enemy's same-tick opportunity")
	_assert_eq(results[0].outcome, CombatSliceOpportunityResult.Outcome.LIFECYCLE_REQUIRED_UNCONSCIOUS, "player opportunity first requests unconscious")
	_assert_eq(controller.last_tick_order(), [CombatSliceDemoFactory.PLAYER_ID, CombatSliceDemoFactory.ENEMY_ID], "stable participant order survives lifecycle execution")
	_assert_eq(controller.player_binding.life_status, CombatSliceLifeStatus.Value.UNCONSCIOUS, "player becomes unconscious before enemy opportunity")
	_assert_true(controller.player_binding.exists_in_encounter, "unconscious player remains in encounter")
	_assert_false(controller.player_body.input_pickable, "unconscious player body cannot initiate selection")
	Input.action_press("move_right")
	controller.player_body._physics_process(1.0 / 60.0)
	Input.action_release("move_right")
	_assert_eq(controller.player_body.position, start_position, "unconscious player movement is disabled by live binding status")
	_assert_true(random.call_count() > 0, "only the later enemy combat opportunity consumes RNG")
	_assert_eq(results[1].fight_decision_result.outcome, CombatFightDecisionResult.Outcome.QUICK_ATTACK, "enemy selects the source QUICK branch against the now-unconscious player")
	_assert_eq(results[1].forward_result.attack_type, CombatAttackType.Value.QUICK, "same-tick enemy attack executes with QUICK type")
	_assert_eq(results[1].outcome, CombatSliceOpportunityResult.Outcome.ATTACK_CHAIN_COMPLETE, "same-tick QUICK attack reaches ordinary attack-chain completion")
	_assert_false(controller.lifecycle_is_pending(), "completed unconscious lifecycle does not block cadence")
	controller.queue_free()
	await tree.process_frame


func _test_complete_enemy_defeat_path(tree: SceneTree) -> void:
	var controller: CombatVerticalSliceController = _instantiate_scene(tree)
	await tree.physics_frame
	controller.configure_random_source(ScriptedRandomScript.new(_regular_hit_draws(2)))
	controller.select_enemy()
	controller.initiate_selected_combat()
	controller.opportunity_timer.stop()
	controller.enemy_binding.state.vitality = CharacterResourceState.new(1, 100, 220)
	var first_tick: Array[CombatSliceOpportunityResult] = controller.process_cadence_tick()
	_assert_eq(first_tick.size(), 2, "playable enemy path starts with player attack then enemy outer opportunity")
	_assert_eq(first_tick[1].outcome, CombatSliceOpportunityResult.Outcome.LIFECYCLE_REQUIRED_UNCONSCIOUS, "ordinary player hit reaches enemy unconscious lifecycle on its own opportunity")
	_assert_eq(controller.enemy_binding.life_status, CombatSliceLifeStatus.Value.UNCONSCIOUS, "playable enemy path reaches unconscious state without manual lifecycle mutation")
	var maximum_random: MaximumCombatRandomSource = MaximumCombatRandomSource.new()
	controller.configure_random_source(maximum_random)
	var observed_quick: bool = false
	for _tick: int in range(20):
		if controller.enemy_binding.life_status == CombatSliceLifeStatus.Value.DEAD:
			break
		var tick_results: Array[CombatSliceOpportunityResult] = controller.process_cadence_tick()
		for opportunity: CombatSliceOpportunityResult in tick_results:
			if opportunity.forward_result != null and opportunity.forward_result.attack_type == CombatAttackType.Value.QUICK:
				observed_quick = true
	_assert_true(observed_quick, "later playable opportunity executes QUICK against unconscious enemy")
	_assert_eq(controller.enemy_binding.life_status, CombatSliceLifeStatus.Value.DEAD, "repeated deterministic combat wounds reach enemy effective death threshold")
	_assert_false(controller.enemy_binding.exists_in_encounter, "completed enemy death removes encounter availability")
	_assert_eq(controller.corpse_states().size(), 1, "complete playable enemy kill creates exactly one authoritative corpse")
	_assert_true(controller.inventory_state.is_direct_child(&"combat-slice-enemy-long-sword", ContainmentEndpoint.new(ContainmentEndpoint.Kind.ITEM, controller.corpse_states()[0].corpse_item_instance_id)), "complete playable enemy kill transfers its sword into the corpse")
	_assert_false(controller.player_binding.relationship.is_fighting(), "complete playable enemy kill terminates survivor combat relationship")
	controller.queue_free()
	await tree.process_frame


func _test_complete_player_defeat_path(tree: SceneTree) -> void:
	var controller: CombatVerticalSliceController = _instantiate_scene(tree)
	await tree.physics_frame
	controller.configure_random_source(ScriptedRandomScript.new(_regular_hit_draws(2)))
	controller.select_enemy()
	controller.initiate_selected_combat()
	controller.opportunity_timer.stop()
	controller.player_binding.busy.start_busy(1)
	controller.player_binding.state.vitality = CharacterResourceState.new(1, 100, 220)
	var first_tick: Array[CombatSliceOpportunityResult] = controller.process_cadence_tick()
	_assert_eq(first_tick[0].outcome, CombatSliceOpportunityResult.Outcome.BUSY_ADVANCED, "playable player-loss path preserves ordered busy completion")
	_assert_true(controller.player_binding.state.vitality.current < 0, "enemy ordinary attack crosses player current threshold")
	controller.configure_random_source(MaximumCombatRandomSource.new())
	var observed_quick: bool = false
	for _tick: int in range(20):
		if controller.player_binding.life_status == CombatSliceLifeStatus.Value.DEAD:
			break
		var tick_results: Array[CombatSliceOpportunityResult] = controller.process_cadence_tick()
		for opportunity: CombatSliceOpportunityResult in tick_results:
			if opportunity.forward_result != null and opportunity.forward_result.attack_type == CombatAttackType.Value.QUICK:
				observed_quick = true
	_assert_true(observed_quick, "enemy later executes QUICK against unconscious player")
	_assert_eq(controller.player_binding.life_status, CombatSliceLifeStatus.Value.DEAD, "deterministic player-loss path reaches normal death")
	_assert_false(controller.player_binding.exists_in_encounter, "completed player death is terminal for the encounter")
	_assert_false(controller.player_body.visible, "completed player death hides the physical body")
	_assert_eq(controller.corpse_states().size(), 1, "player-loss path creates one normal corpse")
	_assert_false(controller.hud.attack_is_enabled(), "player-loss path disables Attack")
	_assert_true(controller.hud.log_lines().back().contains("Reset"), "player-loss path exposes Reset as the only continuation")
	controller.queue_free()
	await tree.process_frame


func _test_npc_death_creates_authoritative_corpse(tree: SceneTree) -> void:
	var controller: CombatVerticalSliceController = _instantiate_scene(tree)
	await tree.physics_frame
	controller.select_enemy()
	controller.initiate_selected_combat()
	controller.opportunity_timer.stop()
	controller.player_binding.busy.start_busy(1)
	var corpse_position: Vector2 = controller.enemy_body.position
	var essence_before: int = controller.enemy_binding.state.essence.current
	controller.enemy_binding.state.vitality.effective = -1
	var results: Array[CombatSliceOpportunityResult] = controller.process_cadence_tick()
	_assert_eq(results.size(), 2, "busy player then enemy death are processed in one tick")
	var lifecycle: CombatSliceLifecycleResult = controller.last_lifecycle_results()[0]
	_assert_eq(lifecycle.outcome, CombatSliceLifecycleResult.Outcome.DEATH_COMPLETE, "effective below zero completes NPC death")
	_assert_false(lifecycle.resources_zeroed, "death does not reuse unconscious resource zeroing")
	_assert_eq(controller.enemy_binding.state.essence.current, essence_before, "death leaves unrelated resource current unchanged")
	_assert_eq(controller.enemy_binding.life_status, CombatSliceLifeStatus.Value.DEAD, "NPC runtime status is dead")
	_assert_false(controller.enemy_binding.exists_in_encounter, "dead NPC leaves encounter availability")
	_assert_false(controller.enemy_body.visible, "dead NPC body is hidden")
	_assert_false(controller.enemy_body.input_pickable, "dead NPC body is unpickable")
	_assert_false(controller.enemy_binding.relationship.is_fighting(), "dead NPC local opponent list is empty")
	_assert_false(controller.player_binding.relationship.is_fighting(), "survivor relationship is cleared after death inventory")
	_assert_false(controller.player_binding.relationship.has_lethal_target(controller.enemy_binding.character_id), "survivor lethal marker is cleared")
	_assert_eq(controller.corpse_states().size(), 1, "controller retains one authoritative corpse state")
	_assert_eq(controller.corpse_decay_intents().size(), 1, "controller retains one initial decay intent without scheduling it")
	_assert_eq(controller.corpse_layer.get_child_count(), 1, "one presentation corpse view is spawned")
	var view: CombatSliceCorpseView = controller.corpse_layer.get_child(0) as CombatSliceCorpseView
	_assert_true(view != null, "corpse layer child is the narrow presentation view")
	_assert_eq(view.position, corpse_position, "corpse view uses captured body position")
	_assert_eq(view.corpse_item_instance_id, lifecycle.corpse_item_instance_id, "corpse view exposes only stable corpse identity")
	_assert_true(lifecycle.death_inventory_result.corpse_state == controller.corpse_states()[0], "Core corpse authority is retained, not copied into view")
	_assert_eq(lifecycle.second_corpse_placement_result.outcome, InventoryTransferResult.Outcome.ALREADY_AT_DESTINATION, "damage.c second corpse move is an explicit same-endpoint no-op")
	_assert_false(lifecycle.second_corpse_placement_result.containment_changed, "second corpse move does not mutate containment")
	var corpse_endpoint: ContainmentEndpoint = ContainmentEndpoint.new(ContainmentEndpoint.Kind.ITEM, lifecycle.corpse_item_instance_id)
	var sword_id: StringName = &"combat-slice-enemy-long-sword"
	_assert_true(controller.inventory_state.is_direct_child(sword_id, corpse_endpoint), "NPC sword becomes direct corpse content")
	_assert_true(controller.enemy_binding.state.equipment.are_both_hands_empty(), "sword transfer unwields through existing authority")
	_assert_true(controller.opportunity_timer.is_stopped(), "cadence stops when death cleanup leaves no relationships")
	controller.queue_free()
	await tree.process_frame


func _test_player_death_is_terminal_until_reset(tree: SceneTree) -> void:
	var controller: CombatVerticalSliceController = _instantiate_scene(tree)
	await tree.physics_frame
	controller.select_enemy()
	controller.initiate_selected_combat()
	controller.opportunity_timer.stop()
	controller.player_binding.state.spirit.effective = -1
	var results: Array[CombatSliceOpportunityResult] = controller.process_cadence_tick()
	_assert_eq(results.size(), 1, "player death cleans relationships before enemy's turn")
	_assert_eq(controller.player_binding.life_status, CombatSliceLifeStatus.Value.DEAD, "player uses normal death status, not ghost state")
	_assert_false(controller.player_binding.exists_in_encounter, "player death is terminal in this encounter")
	_assert_false(controller.player_body.visible, "dead player body is hidden")
	_assert_eq(controller.corpse_states().size(), 1, "player death creates a normal corpse")
	_assert_false(controller.hud.attack_is_enabled(), "terminal player defeat disables Attack")
	_assert_true(controller.hud.log_lines().back().contains("Reset"), "terminal defeat offers explicit reset presentation")
	_assert_true(controller.process_cadence_tick().is_empty(), "dead encounter has no later combat opportunities")
	controller.queue_free()
	await tree.process_frame


func _test_failed_death_is_not_retried(tree: SceneTree) -> void:
	var controller: CombatVerticalSliceController = _instantiate_scene(tree)
	await tree.physics_frame
	controller.select_enemy()
	controller.initiate_selected_combat()
	controller.opportunity_timer.stop()
	var first_corpse_id: StringName = StringName(
		"combat-slice-encounter-%d-corpse-1" % controller.get_instance_id()
	)
	var collision: ItemInstance = ItemInstance.new(
		first_corpse_id,
		CombatSliceDeathAdapter.CORPSE_DEFINITION_ID,
	)
	_assert_true(controller.inventory_state.register_item(collision, 1), "test establishes first corpse-ID collision")
	controller.player_binding.state.vitality.effective = -1
	controller.process_cadence_tick()
	var lifecycle: CombatSliceLifecycleResult = controller.last_lifecycle_results()[0]
	_assert_eq(lifecycle.outcome, CombatSliceLifecycleResult.Outcome.DEATH_INVENTORY_FAILED, "pre-processing corpse registration failure is typed")
	_assert_true(controller.lifecycle_is_pending(), "typed lifecycle failure blocks later cadence")
	_assert_true(controller.opportunity_timer.is_stopped(), "typed lifecycle failure stops timer")
	_assert_eq(controller.corpse_states().size(), 0, "failed corpse registration creates no corpse authority")
	_assert_eq(controller.player_binding.life_status, CombatSliceLifeStatus.Value.ACTIVE, "rejected death does not commit DEAD status")
	_assert_true(controller.player_binding.exists_in_encounter, "rejected death preserves encounter availability")
	_assert_true(controller.player_body.visible, "rejected death keeps the physical body visible")
	_assert_true(controller.process_cadence_tick().is_empty(), "failed death is not retried on the next tick")
	_assert_eq(controller.last_lifecycle_results().size(), 0, "no-retry tick emits no duplicate lifecycle result")
	controller.queue_free()
	await tree.process_frame


func _test_blocked_death_preserves_partial_state_and_is_not_retried(
	tree: SceneTree,
) -> void:
	var controller: CombatVerticalSliceController = _instantiate_scene(tree)
	await tree.physics_frame
	controller.select_enemy()
	controller.initiate_selected_combat()
	controller.opportunity_timer.stop()
	var unknown: ItemInstance = ItemInstance.new(&"unknown-direct-item", &"unknown-definition")
	_assert_true(controller.inventory_state.register_item(unknown, 10), "test registers an unknown item without inventing definition facts")
	var transfer: InventoryTransferResult = InventoryTransferService.new().transfer(
		controller.inventory_state,
		unknown.item_instance_id,
		InventoryTransferDestination.new(
			ContainmentEndpoint.new(
				ContainmentEndpoint.Kind.CHARACTER,
				controller.player_binding.character_id,
			),
			true,
			true,
			100000,
		),
	)
	_assert_true(transfer.succeeded, "unknown item becomes direct victim inventory")
	controller.player_binding.state.vitality.effective = -1
	controller.process_cadence_tick()
	var lifecycle: CombatSliceLifecycleResult = controller.last_lifecycle_results()[0]
	_assert_eq(lifecycle.outcome, CombatSliceLifecycleResult.Outcome.DEATH_INVENTORY_BLOCKED, "uncovered direct item produces typed blocked death")
	_assert_eq(lifecycle.death_inventory_result.outcome, DeathInventoryResult.Outcome.INVALID_ITEM_FACTS, "blocked result retains exact death-service cause")
	_assert_eq(controller.corpse_states().size(), 1, "corpse creation before validation remains authoritative")
	_assert_eq(controller.corpse_layer.get_child_count(), 1, "partial corpse mutation is still presented once")
	_assert_true(
		controller.inventory_state.is_direct_child(
			unknown.item_instance_id,
			ContainmentEndpoint.new(
				ContainmentEndpoint.Kind.CHARACTER,
				controller.player_binding.character_id,
			),
		),
		"blocked death preserves the unprocessed direct item",
	)
	_assert_true(controller.player_binding.state.equipment.has_weapon_instance(&"combat-slice-player-long-sword"), "blocked-before-survivors preserves still-wielded sword")
	_assert_eq(controller.player_binding.life_status, CombatSliceLifeStatus.Value.ACTIVE, "blocked death does not commit DEAD status")
	_assert_true(controller.player_binding.exists_in_encounter, "blocked death preserves encounter availability")
	_assert_true(controller.player_body.visible, "blocked death keeps the physical body visible")
	_assert_true(controller.enemy_binding.relationship.has_lethal_target(controller.player_binding.character_id), "blocked death does not run final lethal cleanup")
	_assert_true(controller.lifecycle_is_pending(), "blocked incomplete death gates cadence")
	_assert_true(controller.process_cadence_tick().is_empty(), "blocked incomplete death is not restarted")
	_assert_eq(controller.corpse_states().size(), 1, "no retry creates no duplicate corpse")
	_assert_eq(controller.corpse_layer.get_child_count(), 1, "no retry creates no duplicate corpse view")
	controller.queue_free()
	await tree.process_frame


func _test_reset_clears_corpses_and_lifecycle_state(tree: SceneTree) -> void:
	var packed: PackedScene = load(SCENE_PATH) as PackedScene
	tree.change_scene_to_packed(packed)
	await tree.process_frame
	var first: CombatVerticalSliceController = tree.current_scene as CombatVerticalSliceController
	first.select_enemy()
	first.initiate_selected_combat()
	first.opportunity_timer.stop()
	first.player_binding.state.vitality.effective = -1
	first.process_cadence_tick()
	_assert_eq(first.corpse_layer.get_child_count(), 1, "pre-reset encounter has exactly one corpse view")
	var first_corpse_id: StringName = first.corpse_states()[0].corpse_item_instance_id
	first._on_reset_button_pressed()
	await tree.process_frame
	await tree.process_frame
	var reset: CombatVerticalSliceController = tree.current_scene as CombatVerticalSliceController
	_assert_eq(reset.corpse_layer.get_child_count(), 0, "reset clears presentation corpses")
	_assert_eq(reset.corpse_states().size(), 0, "reset creates fresh corpse authority collection")
	_assert_eq(reset.corpse_decay_intents().size(), 0, "reset creates fresh decay intent collection")
	_assert_false(reset.lifecycle_is_pending(), "reset clears lifecycle failure state")
	_assert_eq(reset.player_binding.life_status, CombatSliceLifeStatus.Value.ACTIVE, "reset creates a fresh active player")
	_assert_eq(reset.player_binding.state.conditions.size(), 0, "fresh encounter has no active conditions")
	reset.select_enemy()
	reset.initiate_selected_combat()
	reset.opportunity_timer.stop()
	reset.player_binding.state.vitality.effective = -1
	reset.process_cadence_tick()
	_assert_true(reset.corpse_states()[0].corpse_item_instance_id != first_corpse_id, "reloaded encounter allocates a fresh corpse identity without global mutable state")


func _instantiate_scene(tree: SceneTree) -> CombatVerticalSliceController:
	var packed: PackedScene = load(SCENE_PATH) as PackedScene
	var controller: CombatVerticalSliceController = packed.instantiate() as CombatVerticalSliceController
	tree.root.add_child(controller)
	return controller


func _arena_destination() -> InventoryTransferDestination:
	return InventoryTransferDestination.new(
		ContainmentEndpoint.new(ContainmentEndpoint.Kind.WORLD, CombatSliceDemoFactory.ARENA_ID),
		true,
		true,
		1000000,
	)


func _regular_hit_draws(repetitions: int) -> Array[int]:
	var values: Array[int] = []
	for _index: int in range(repetitions):
		values.append_array([0, 0, 0, 0, 10, 10, 0, 0, 0, 0, 0])
	return values


func _assert_true(value: bool, message: String) -> void:
	_assertion_count += 1
	if not value:
		_failures.append("FAIL: %s" % message)


func _assert_false(value: bool, message: String) -> void:
	_assert_true(not value, message)


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	_assertion_count += 1
	if actual != expected:
		_failures.append("FAIL: %s (expected %s, got %s)" % [message, expected, actual])
