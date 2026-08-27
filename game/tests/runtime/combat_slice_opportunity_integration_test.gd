extends RefCounted

const BindingScript := preload(
	"res://runtime/combat_slice/combat_slice_character_binding.gd"
)
const ContentScript := preload(
	"res://runtime/combat_slice/combat_slice_content_profile.gd"
)
const LifeStatusScript := preload(
	"res://runtime/combat_slice/combat_slice_life_status.gd"
)
const InitiationResultScript := preload(
	"res://runtime/combat_slice/combat_slice_initiation_result.gd"
)
const ProjectionBuilderScript := preload(
	"res://runtime/combat_slice/combat_slice_projection_builder.gd"
)
const OpportunityResultScript := preload(
	"res://runtime/combat_slice/combat_slice_opportunity_result.gd"
)
const ExecutorScript := preload(
	"res://runtime/combat_slice/combat_slice_opportunity_executor.gd"
)
const CharacterStateScript := preload("res://core/characters/character_state.gd")
const AttributesScript := preload(
	"res://core/characters/character_base_attributes.gd"
)
const ResourceScript := preload(
	"res://core/characters/character_resource_state.gd"
)
const RelationshipScript := preload(
	"res://core/combat/relationship/combat_relationship_state.gd"
)
const FailingRelationshipScript := preload(
	"res://tests/support/failing_combat_relationship_state.gd"
)
const BusyScript := preload("res://core/combat/busy/action_busy_state.gd")
const ArmorScript := preload("res://core/armor/armor_state.gd")
const ArmorDefinitionScript := preload("res://core/armor/armor_definition.gd")
const ArmorModifiersScript := preload(
	"res://core/armor/armor_numeric_modifiers.gd"
)
const EquippedArmorScript := preload("res://core/armor/equipped_armor_ref.gd")
const WeaponDefinitionScript := preload("res://core/equipment/weapon_definition.gd")
const EquippedWeaponScript := preload("res://core/equipment/equipped_weapon_ref.gd")
const ScriptedRandomScript := preload(
	"res://tests/support/scripted_combat_random_source.gd"
)
const EffectRegistryScript := preload(
	"res://core/skills/improvement_effects/skill_improvement_effect_registry.gd"
)
const BaseAttackResultScript := preload(
	"res://core/combat/resolution/combat_attack_result.gd"
)
const FightResultScript := preload(
	"res://core/combat/fight/combat_fight_decision_result.gd"
)
const SelectionResultScript := preload(
	"res://core/combat/relationship/combat_opponent_selection_result.gd"
)
const ForwardResultScript := preload(
	"res://core/combat/execution/combat_single_attack_execution_result.gd"
)
const ChainResultScript := preload(
	"res://core/combat/execution/combat_attack_chain_result.gd"
)

const PLAYER_ID: StringName = &"slice-player"
const NPC_ID: StringName = &"slice-npc"
const ARENA_ID: StringName = &"combat_vertical_slice_arena"

var _assertion_count: int = 0
var _failures: Array[String] = []


func run_all() -> Dictionary[String, Variant]:
	_test_binding_identity_and_independence()
	_test_shared_nested_authorities_and_duplicate_ids_rejected()
	_test_content_profile_and_current_projections()
	_test_present_invalid_primary_does_not_fallback()
	_test_secondary_only_uses_unarmed_provider()
	_test_current_armor_projection()
	_test_lethal_initiation_order_and_failures()
	_test_lifecycle_gate_order_and_runtime_status()
	_test_lifecycle_death_priority_and_dead_actor_honesty()
	_test_busy_gate_and_next_opportunity()
	_test_busy_positive_and_negative_edges()
	_test_availability_projection_semantics()
	_test_runtime_availability_gates_and_cleanup()
	_test_unresolved_cleanup_and_opponent_insertion_order()
	_test_fight_projection_visibility_and_raw_attributes()
	_test_guard_regular_and_quick_opportunities()
	_test_dodge_parry_hit_and_rng_timeline()
	_test_live_reverse_projection_after_progression()
	_test_reverse_threshold_is_not_applied_mid_chain()
	_test_partial_mutations_survive_later_failures()
	_test_threshold_candidate_deferred_to_affected_opportunity()
	_test_result_defensive_snapshots()
	return {
		"assertions": _assertion_count,
		"failures": _failures.duplicate(),
	}


func _test_binding_identity_and_independence() -> void:
	var player: CombatSliceCharacterBinding = _binding(PLAYER_ID, true)
	var npc: CombatSliceCharacterBinding = _binding(NPC_ID, false)
	_assert_true(player.is_valid(), "player binding is coherent")
	_assert_true(npc.is_valid(), "NPC binding is coherent")
	_assert_true(player.state != npc.state, "characters do not share CharacterState")
	_assert_true(player.state.attributes != npc.state.attributes, "attributes are independent")
	_assert_true(player.state.skills != npc.state.skills, "skills are independent")
	_assert_true(player.state.progression != npc.state.progression, "progression is independent")
	_assert_true(player.state.equipment != npc.state.equipment, "equipment is independent")
	_assert_true(player.relationship != npc.relationship, "relationships are independent")
	_assert_true(player.busy != npc.busy, "busy authorities are independent")
	_assert_true(player.armor != npc.armor, "armor authorities are independent")
	_assert_true(player.content != npc.content, "content values need no shared mutable instance")
	var bad: CombatSliceCharacterBinding = BindingScript.new(
		&"bad", player.state, RelationshipScript.new(&"wrong"), BusyScript.new(),
		ArmorScript.new(), ContentScript.new(), ARENA_ID
	)
	_assert_false(bad.is_valid(), "relationship owner mismatch is rejected")


func _test_shared_nested_authorities_and_duplicate_ids_rejected() -> void:
	var pair: Array[CombatSliceCharacterBinding] = _pair()
	pair[1].state.attributes = pair[0].state.attributes
	_assert_incoherent_participants_rejected(pair, "shared attributes rejected")
	pair = _pair()
	pair[1].state.skills = pair[0].state.skills
	_assert_incoherent_participants_rejected(pair, "shared skills rejected")
	pair = _pair()
	pair[1].state.progression = pair[0].state.progression
	_assert_incoherent_participants_rejected(pair, "shared progression rejected")
	pair = _pair()
	pair[1].state.equipment = pair[0].state.equipment
	_assert_incoherent_participants_rejected(pair, "shared equipment rejected")
	pair = _pair()
	pair[1].state.essence = pair[0].state.essence
	_assert_incoherent_participants_rejected(pair, "shared resource rejected")
	pair = _pair()
	pair[1].state.recovery = pair[0].state.recovery
	_assert_incoherent_participants_rejected(pair, "shared recovery rejected")
	var left: CombatSliceCharacterBinding = _binding(PLAYER_ID, true)
	var right: CombatSliceCharacterBinding = _binding(NPC_ID, false)
	var shared_state_binding: CombatSliceCharacterBinding = BindingScript.new(
		right.character_id,
		left.state,
		right.relationship,
		right.busy,
		right.armor,
		right.content,
		right.location_id,
	)
	_assert_incoherent_participants_rejected(
		[left, shared_state_binding],
		"shared CharacterState rejected",
	)
	var duplicate_a: CombatSliceCharacterBinding = _binding(PLAYER_ID, true)
	var duplicate_b: CombatSliceCharacterBinding = _binding(PLAYER_ID, false)
	_assert_incoherent_participants_rejected(
		[duplicate_a, duplicate_b],
		"duplicate stable CharacterId rejected",
	)


func _test_content_profile_and_current_projections() -> void:
	var actor: CombatSliceCharacterBinding = _binding(PLAYER_ID, true)
	var victim: CombatSliceCharacterBinding = _binding(NPC_ID, false)
	var profile: CombatSliceContentProfile = actor.content
	_assert_true(profile.is_valid(), "source-backed content profile is valid")
	_assert_eq(profile.limbs().size(), 16, "human limb projection has exactly 16 entries")
	var mutated_limbs: Array[StringName] = profile.limbs()
	mutated_limbs.clear()
	_assert_eq(profile.limbs().size(), 16, "limbs are defensively copied")
	var action_set: CombatActionSet = profile.slash_action_set()
	_assert_eq(action_set.size(), 1, "slice weapon provider has one action only")
	var slash: CombatActionDefinition = action_set.action_at(0)
	_assert_eq(slash.action_id, ContentScript.SLASH_ACTION_ID, "slash ID is exact")
	_assert_eq(slash.damage_percent, 0, "slash damage percent is exact")
	_assert_eq(slash.force_percent, 0, "slash force percent is exact")
	_assert_eq(slash.damage_type, &"割伤", "slash damage type is exact")
	_assert_eq(slash.legacy_action_text, "$N挥动$w，斩向$n的$l", "slash legacy text is traceable")
	_assert_eq(slash.post_action_policy_id, &"", "slash has no post_action")

	var selection: CombatActionSelectionInput = (
		ProjectionBuilderScript.build_action_selection_input(actor)
	)
	_assert_true(selection.primary_weapon_present, "current primary sword is provider")
	_assert_false(selection.mapped_skill_present, "mapped martial is absent")
	_assert_eq(selection.primary_weapon_action_set().size(), 1, "primary provider stays slash-only")
	var attack: CombatAttackInput = ProjectionBuilderScript.build_attack_input(
		actor, victim, slash
	)
	_assert_true(attack.is_valid(), "current attack input is valid")
	_assert_eq(attack.attacker.weapon_profile.skill_type, &"sword", "weapon skill is sword")
	_assert_eq(attack.attacker.projected_apply_damage, 25, "long sword projects damage 25")
	_assert_eq(attack.attacker.force_hit_policy_status, CombatHitPolicyStatus.Value.NOT_APPLICABLE, "no mapped force policy is reached")
	_assert_eq(attack.attacker.martial_hit_policy_status, CombatHitPolicyStatus.Value.NOT_APPLICABLE, "no martial policy is reached")
	_assert_eq(attack.attacker.weapon_profile.hit_policy_status, CombatHitPolicyStatus.Value.PROVEN_NO_AUTHORED_EFFECT, "weapon has proven no authored hit effect")

	actor.state.equipment.unwield(&"slice-player-sword")
	var unarmed_selection: CombatActionSelectionInput = (
		ProjectionBuilderScript.build_action_selection_input(actor)
	)
	_assert_false(unarmed_selection.primary_weapon_present, "unwield is observed at projection time")
	_assert_eq(unarmed_selection.default_action_set().size(), 1, "no-primary path has explicit source-backed default")
	_assert_eq(unarmed_selection.default_action_set().action_at(0).action_id, ContentScript.UNARMED_ACTION_ID, "default provider is human punch")


func _test_present_invalid_primary_does_not_fallback() -> void:
	var pair: Array[CombatSliceCharacterBinding] = _initiated_pair()
	pair[0].state.equipment.unwield(&"slice-player-sword")
	var unknown_definition: WeaponDefinition = WeaponDefinitionScript.new(
		&"es2:test/unknown_sword", &"sword", false, false, "test/unknown_sword.c"
	)
	var unknown: EquippedWeaponRef = EquippedWeaponScript.new(
		&"unknown-sword-instance", unknown_definition
	)
	pair[0].state.equipment.wield(unknown, false)
	var selection: CombatActionSelectionInput = (
		ProjectionBuilderScript.build_action_selection_input(pair[0])
	)
	_assert_true(selection.primary_weapon_present, "unknown current primary remains present")
	_assert_true(selection.primary_weapon_action_set() == null, "unverified present provider exposes unavailable data")
	var rng: ScriptedCombatRandomSource = ScriptedRandomScript.new([0, 0])
	var result: CombatSliceOpportunityResult = _execute(pair[0], pair, rng)
	_assert_eq(result.outcome, OpportunityResultScript.Outcome.ATTACK_CHAIN_INCOMPLETE, "present unavailable provider fails honestly")
	_assert_eq(result.forward_result.outcome, ForwardResultScript.Outcome.ACTION_SELECTION_FAILED, "closed selector owns unavailable-provider failure")
	_assert_eq(result.forward_result.action_selection_result.outcome, CombatActionSelectionResult.Outcome.PRIMARY_WEAPON_ACTION_DATA_UNAVAILABLE, "default provider is not used as fallback")
	_assert_eq(rng.requested_bounds(), [4, 60], "unavailable primary consumes no action RNG")


func _test_secondary_only_uses_unarmed_provider() -> void:
	var pair: Array[CombatSliceCharacterBinding] = _initiated_pair()
	var original_primary: EquippedWeaponRef = pair[0].state.equipment.primary_weapon()
	pair[0].state.equipment.unwield(original_primary.instance_id)
	_assert_true(
		pair[0].state.equipment._restore_weapons(null, original_primary),
		"test restores source-reachable secondary-only hand state",
	)
	var selection: CombatActionSelectionInput = (
		ProjectionBuilderScript.build_action_selection_input(pair[0])
	)
	_assert_false(selection.primary_weapon_present, "secondary-only state has no primary provider")
	_assert_eq(selection.default_action_set().size(), 1, "secondary is not promoted over unarmed default")
	var rng: ScriptedCombatRandomSource = ScriptedRandomScript.new([0, 0, 0, 0, 0])
	var result: CombatSliceOpportunityResult = _execute(pair[0], pair, rng)
	_assert_eq(result.forward_result.action_selection_result.source_kind, CombatActionSelectionResult.SourceKind.DEFAULT_ACTIONS, "secondary-only execution selects default provider")
	_assert_eq(result.forward_result.selected_action_id, ContentScript.UNARMED_ACTION_ID, "secondary-only execution uses source-backed punch")
	_assert_eq(result.forward_result.action_selection_result.random_upper_bounds(), [1], "one unarmed fallback action still consumes random(1)")


func _test_current_armor_projection() -> void:
	var pair: Array[CombatSliceCharacterBinding] = _pair()
	var slash: CombatActionDefinition = pair[0].content.slash_action()
	var before: CombatAttackInput = ProjectionBuilderScript.build_attack_input(
		pair[0], pair[1], slash
	)
	_assert_eq(before.attacker.attack_usage_bonus, 0, "empty attacker ArmorState projects zero attack")
	_assert_eq(before.defender.armor, 0, "empty defender ArmorState projects zero armor")
	var modifiers: ArmorNumericModifiers = ArmorModifiersScript.new(
		10, 2, 3, 4, 5, 0, 0, 0, 0, 0, 0, 0, 0, 14
	)
	var attacker_definition: ArmorDefinition = ArmorDefinitionScript.new(
		&"slice:armor:attacker", &"cloth", modifiers
	)
	var defender_definition: ArmorDefinition = ArmorDefinitionScript.new(
		&"slice:armor:defender", &"cloth", modifiers
	)
	pair[0].armor._apply_wear(
		EquippedArmorScript.new(&"slice:armor:attacker-instance", attacker_definition)
	)
	pair[1].armor._apply_wear(
		EquippedArmorScript.new(&"slice:armor:defender-instance", defender_definition)
	)
	var after: CombatAttackInput = ProjectionBuilderScript.build_attack_input(
		pair[0], pair[1], slash
	)
	_assert_eq(after.attacker.attack_usage_bonus, 3, "later projection observes current attacker armor attack")
	_assert_eq(after.defender.defense_usage_bonus, 4, "later projection observes current defender armor defense")
	_assert_eq(after.defender.effective_dodge_skill_level, 10, "later projection combines current dodge modifier through SkillState")
	_assert_eq(after.defender.armor, 10, "later projection observes current armor value")
	_assert_eq(after.defender.armor_vs_force, 2, "later projection observes current armor-vs-force")


func _test_lethal_initiation_order_and_failures() -> void:
	var pair: Array[CombatSliceCharacterBinding] = _pair()
	var rng: ScriptedCombatRandomSource = ScriptedRandomScript.new([0])
	var result: CombatSliceInitiationResult = ExecutorScript.initiate_lethal_combat(
		pair[0], pair[1]
	)
	_assert_eq(result.outcome, InitiationResultScript.Outcome.COMPLETED, "valid lethal initiation completes")
	_assert_true(result.first_mutation_attempted and result.first_mutation_succeeded, "player relation is established first")
	_assert_true(result.second_mutation_attempted and result.second_mutation_succeeded, "NPC reciprocal lethal relation is established second")
	_assert_true(result.first_mutation_changed, "player-side lethal initiation reports a changed first transition")
	_assert_true(result.second_mutation_changed, "NPC-side lethal initiation reports a changed second transition")
	_assert_true(pair[0].relationship.has_lethal_target(NPC_ID), "player marks NPC lethal")
	_assert_true(pair[1].relationship.has_lethal_target(PLAYER_ID), "NPC marks player lethal")
	_assert_true(pair[0].relationship.has_opponent(NPC_ID), "player establishes NPC opponent membership")
	_assert_true(pair[1].relationship.has_opponent(PLAYER_ID), "NPC establishes player opponent membership")
	_assert_eq(rng.call_count(), 0, "initiation has no RNG channel")
	_assert_eq(pair[1].state.vitality.current, 220, "initiation does not run an opportunity")

	var self_binding: CombatSliceCharacterBinding = _binding(PLAYER_ID, true)
	_assert_eq(ExecutorScript.initiate_lethal_combat(self_binding, self_binding).outcome, InitiationResultScript.Outcome.SELF_TARGET_REJECTED, "self target is rejected before mutation")
	var distant: CombatSliceCharacterBinding = _binding(NPC_ID, false)
	distant.set_location_id(&"elsewhere")
	_assert_eq(ExecutorScript.initiate_lethal_combat(_binding(PLAYER_ID, true), distant).outcome, InitiationResultScript.Outcome.DIFFERENT_LOCATION, "different location is rejected")
	var absent: CombatSliceCharacterBinding = _binding(NPC_ID, false)
	absent.set_exists_in_encounter(false)
	_assert_eq(ExecutorScript.initiate_lethal_combat(_binding(PLAYER_ID, true), absent).outcome, InitiationResultScript.Outcome.TARGET_NOT_AVAILABLE, "despawned target is rejected")
	var dead: CombatSliceCharacterBinding = _binding(NPC_ID, false)
	dead.set_life_status(LifeStatusScript.Value.DEAD)
	_assert_eq(ExecutorScript.initiate_lethal_combat(_binding(PLAYER_ID, true), dead).outcome, InitiationResultScript.Outcome.TARGET_DEAD, "DEAD target is rejected")
	var unconscious: CombatSliceCharacterBinding = _binding(NPC_ID, false)
	unconscious.set_life_status(LifeStatusScript.Value.UNCONSCIOUS)
	var unconscious_result: CombatSliceInitiationResult = (
		ExecutorScript.initiate_lethal_combat(
			_binding(PLAYER_ID, true),
			unconscious,
		)
	)
	_assert_eq(unconscious_result.outcome, InitiationResultScript.Outcome.COMPLETED, "nonliving non-DEAD target remains a legal lethal target")
	var threshold_crossed: CombatSliceCharacterBinding = _binding(NPC_ID, false)
	threshold_crossed.state.vitality.apply_damage(999)
	var threshold_result: CombatSliceInitiationResult = (
		ExecutorScript.initiate_lethal_combat(
			_binding(PLAYER_ID, true),
			threshold_crossed,
		)
	)
	_assert_eq(threshold_result.outcome, InitiationResultScript.Outcome.COMPLETED, "resource threshold does not invent an initiation rejection")

	var initiator: CombatSliceCharacterBinding = _binding(PLAYER_ID, true)
	var failing_rel: CombatRelationshipState = FailingRelationshipScript.new(NPC_ID)
	failing_rel.fail_add_id = PLAYER_ID
	var failing_target: CombatSliceCharacterBinding = _binding(NPC_ID, false, failing_rel)
	var partial: CombatSliceInitiationResult = ExecutorScript.initiate_lethal_combat(
		initiator, failing_target
	)
	_assert_eq(partial.outcome, InitiationResultScript.Outcome.SECOND_RELATIONSHIP_FAILED, "injected second transition failure is explicit")
	_assert_true(partial.partial_mutation_preserved, "first transition remains after second failure")
	_assert_true(partial.first_mutation_attempted and partial.first_mutation_changed and partial.first_mutation_succeeded, "partial result records completed first transition")
	_assert_true(partial.second_mutation_attempted and partial.second_mutation_changed and not partial.second_mutation_succeeded, "partial result records changed but incomplete second transition")
	_assert_true(initiator.relationship.has_opponent(NPC_ID), "first opponent mutation is not rolled back")
	_assert_true(initiator.relationship.has_lethal_target(NPC_ID), "first lethal marker is not rolled back")
	_assert_true(failing_target.relationship.has_lethal_target(PLAYER_ID), "second-side lethal marker remains after its opponent insertion fails")
	_assert_false(failing_target.relationship.has_opponent(PLAYER_ID), "second-side opponent insertion failure remains visible")


func _test_lifecycle_gate_order_and_runtime_status() -> void:
	var pair: Array[CombatSliceCharacterBinding] = _initiated_pair()
	pair[0].state.vitality.apply_wound(999)
	pair[0].busy.start_busy(2)
	var resources_before: Array[int] = _resource_snapshot(pair[0].state)
	var opponents_before: Array[StringName] = pair[0].relationship.opponent_ids()
	var lethal_before: Array[StringName] = pair[0].relationship.lethal_target_ids()
	var rng: ScriptedCombatRandomSource = ScriptedRandomScript.new([0])
	var death: CombatSliceOpportunityResult = _execute(pair[0], pair, rng)
	_assert_eq(death.outcome, OpportunityResultScript.Outcome.LIFECYCLE_REQUIRED_DEATH, "effective threshold wins over current threshold")
	_assert_eq(death.life_threshold_observed, CharacterState.LifeThreshold.DEAD, "death threshold evidence is retained")
	_assert_eq(pair[0].busy.busy_value, 2, "lifecycle gate precedes busy")
	_assert_eq(rng.call_count(), 0, "lifecycle gate consumes no RNG")
	_assert_eq(pair[0].life_status, LifeStatusScript.Value.ACTIVE, "gate does not execute death lifecycle")
	_assert_true(pair[0].relationship.has_opponent(NPC_ID), "gate does not clear relationships")
	_assert_eq(_resource_snapshot(pair[0].state), resources_before, "lifecycle evidence mutates no current/effective/maximum resource")
	_assert_eq(pair[0].relationship.opponent_ids(), opponents_before, "lifecycle evidence preserves opponent snapshot")
	_assert_eq(pair[0].relationship.lethal_target_ids(), lethal_before, "lifecycle evidence preserves lethal snapshot")
	_assert_eq(death.reached_stage, OpportunityResultScript.ReachedStage.LIFECYCLE_GATE, "lifecycle result reports exact terminal stage")
	var no_later_dependencies: CombatSliceOpportunityResult = (
		ExecutorScript.execute_opportunity(pair[0], [pair[0], pair[1], pair[1]], null, null)
	)
	_assert_eq(no_later_dependencies.outcome, OpportunityResultScript.Outcome.LIFECYCLE_REQUIRED_DEATH, "lifecycle gate is not masked by missing RNG, registry, or duplicate later participant")

	var unconscious_pair: Array[CombatSliceCharacterBinding] = _initiated_pair()
	unconscious_pair[0].state.spirit.apply_damage(999)
	var before_essence: int = unconscious_pair[0].state.essence.current
	var unconscious: CombatSliceOpportunityResult = _execute(
		unconscious_pair[0], unconscious_pair, ScriptedRandomScript.new([0])
	)
	_assert_eq(unconscious.outcome, OpportunityResultScript.Outcome.LIFECYCLE_REQUIRED_UNCONSCIOUS, "ACTIVE current threshold requests unconscious lifecycle")
	_assert_eq(unconscious_pair[0].state.essence.current, before_essence, "gate does not zero resources")
	_assert_eq(unconscious_pair[0].life_status, LifeStatusScript.Value.ACTIVE, "gate does not mutate runtime status")
	unconscious_pair[0].set_life_status(LifeStatusScript.Value.UNCONSCIOUS)
	var later_death: CombatSliceOpportunityResult = _execute(
		unconscious_pair[0], unconscious_pair, ScriptedRandomScript.new([])
	)
	_assert_eq(later_death.outcome, OpportunityResultScript.Outcome.LIFECYCLE_REQUIRED_DEATH, "UNCONSCIOUS current threshold requests later death")


func _test_lifecycle_death_priority_and_dead_actor_honesty() -> void:
	var gin_pair: Array[CombatSliceCharacterBinding] = _initiated_pair()
	gin_pair[0].state.essence.apply_wound(999)
	gin_pair[0].state.vitality.apply_damage(999)
	_assert_eq(_execute(gin_pair[0], gin_pair, ScriptedRandomScript.new([])).outcome, OpportunityResultScript.Outcome.LIFECYCLE_REQUIRED_DEATH, "effective gin death beats current kee unconscious")
	var kee_pair: Array[CombatSliceCharacterBinding] = _initiated_pair()
	kee_pair[0].state.vitality.apply_wound(999)
	kee_pair[0].state.spirit.apply_damage(999)
	_assert_eq(_execute(kee_pair[0], kee_pair, ScriptedRandomScript.new([])).outcome, OpportunityResultScript.Outcome.LIFECYCLE_REQUIRED_DEATH, "effective kee death beats current sen unconscious")
	var sen_pair: Array[CombatSliceCharacterBinding] = _initiated_pair()
	sen_pair[0].state.spirit.apply_wound(999)
	sen_pair[0].state.essence.apply_damage(999)
	_assert_eq(_execute(sen_pair[0], sen_pair, ScriptedRandomScript.new([])).outcome, OpportunityResultScript.Outcome.LIFECYCLE_REQUIRED_DEATH, "effective sen death beats current gin unconscious")
	var dead_pair: Array[CombatSliceCharacterBinding] = _initiated_pair()
	dead_pair[0].set_life_status(LifeStatusScript.Value.DEAD)
	dead_pair[0].state.vitality.apply_wound(999)
	var dead_rng: ScriptedCombatRandomSource = ScriptedRandomScript.new([0])
	var dead: CombatSliceOpportunityResult = _execute(dead_pair[0], dead_pair, dead_rng)
	_assert_eq(dead.outcome, OpportunityResultScript.Outcome.ACTOR_NOT_ACTIVE, "already-DEAD actor does not manufacture another lifecycle request")
	_assert_eq(dead_rng.call_count(), 0, "already-DEAD actor consumes no RNG")
	_assert_eq(dead_pair[0].life_status, LifeStatusScript.Value.DEAD, "malformed dead resources cannot restart or resurrect actor")


func _test_busy_gate_and_next_opportunity() -> void:
	var pair: Array[CombatSliceCharacterBinding] = _initiated_pair()
	pair[0].busy.start_busy(1)
	var first_rng: ScriptedCombatRandomSource = ScriptedRandomScript.new([0])
	var first: CombatSliceOpportunityResult = _execute(pair[0], pair, first_rng)
	_assert_eq(first.outcome, OpportunityResultScript.Outcome.BUSY_ADVANCED, "busy actor advances and returns")
	_assert_true(first.busy_advance_attempted and first.busy_advance_changed, "busy authority advances exactly once")
	_assert_eq(first.busy_before, 1, "busy before evidence is exact")
	_assert_eq(first.busy_after, 0, "busy after evidence is exact")
	_assert_eq(first.reached_stage, OpportunityResultScript.ReachedStage.BUSY_GATE, "busy result reports exact terminal stage")
	_assert_eq(first_rng.call_count(), 0, "busy path suppresses all RNG")
	_assert_true(first.opponent_selection_result == null, "busy path does not select")
	var busy_without_rng_pair: Array[CombatSliceCharacterBinding] = _initiated_pair()
	busy_without_rng_pair[0].busy.start_busy(1)
	var busy_without_rng: CombatSliceOpportunityResult = (
		ExecutorScript.execute_opportunity(
			busy_without_rng_pair[0], [], null, null
		)
	)
	_assert_eq(busy_without_rng.outcome, OpportunityResultScript.Outcome.BUSY_ADVANCED, "busy gate is not masked by unavailable later dependencies")
	var next_rng: ScriptedCombatRandomSource = ScriptedRandomScript.new([0, 59, 0])
	var next: CombatSliceOpportunityResult = _execute(pair[0], pair, next_rng)
	_assert_eq(next.outcome, OpportunityResultScript.Outcome.ENTERED_GUARDING, "next opportunity proceeds after busy clears")
	_assert_eq(next_rng.requested_bounds(), [4, 60, 5], "no second cooldown state delays next opportunity")


func _test_busy_positive_and_negative_edges() -> void:
	var positive_pair: Array[CombatSliceCharacterBinding] = _initiated_pair()
	positive_pair[0].busy.start_busy(3)
	var positive_rng: ScriptedCombatRandomSource = ScriptedRandomScript.new([0])
	var positive: CombatSliceOpportunityResult = _execute(
		positive_pair[0], positive_pair, positive_rng
	)
	_assert_eq(positive.outcome, OpportunityResultScript.Outcome.BUSY_ADVANCED, "busy >1 still returns after one advance")
	_assert_eq(positive.busy_before, 3, "busy >1 snapshots original value")
	_assert_eq(positive.busy_after, 2, "busy >1 decrements exactly once")
	_assert_eq(positive_rng.call_count(), 0, "busy >1 reaches no selection RNG")
	var negative_pair: Array[CombatSliceCharacterBinding] = _initiated_pair()
	negative_pair[0].busy.start_busy(-3, 9)
	var negative_rng: ScriptedCombatRandomSource = ScriptedRandomScript.new([0])
	var negative: CombatSliceOpportunityResult = _execute(
		negative_pair[0], negative_pair, negative_rng
	)
	_assert_eq(negative.outcome, OpportunityResultScript.Outcome.BUSY_ADVANCED, "negative integer busy uses closed authority")
	_assert_eq(negative.busy_before, -3, "negative busy evidence is preserved")
	_assert_eq(negative.busy_after, 0, "negative busy clears on one advance")
	_assert_eq(negative_pair[0].busy.interrupt_threshold, 0, "negative advance clears interrupt threshold")
	_assert_eq(negative_rng.call_count(), 0, "negative busy reaches no RNG")


func _test_availability_projection_semantics() -> void:
	var pair: Array[CombatSliceCharacterBinding] = _initiated_pair()
	var facts: Array[CombatOpponentAvailabilityFacts] = ProjectionBuilderScript.build_opponent_availability(pair[0], pair)
	_assert_eq(facts.size(), 1, "one current relationship creates one availability fact")
	_assert_true(facts[0].exists and facts[0].same_location and facts[0].living, "ACTIVE same-location participant is available and living")
	pair[1].state.vitality.apply_damage(999)
	facts = ProjectionBuilderScript.build_opponent_availability(pair[0], pair)
	_assert_true(facts[0].living, "CharacterState threshold alone does not change runtime living")
	pair[1].set_life_status(LifeStatusScript.Value.UNCONSCIOUS)
	facts = ProjectionBuilderScript.build_opponent_availability(pair[0], pair)
	_assert_true(facts[0].exists and not facts[0].living, "UNCONSCIOUS remains existing but nonliving")
	pair[1].set_life_status(LifeStatusScript.Value.DEAD)
	facts = ProjectionBuilderScript.build_opponent_availability(pair[0], pair)
	_assert_false(facts[0].exists, "DEAD is not encounter-existing availability")
	pair[1].set_life_status(LifeStatusScript.Value.ACTIVE)
	pair[1].set_exists_in_encounter(false)
	facts = ProjectionBuilderScript.build_opponent_availability(pair[0], pair)
	_assert_false(facts[0].exists, "despawned participant is unavailable")
	pair[1].set_exists_in_encounter(true)
	pair[1].set_location_id(&"other")
	facts = ProjectionBuilderScript.build_opponent_availability(pair[0], pair)
	_assert_false(facts[0].same_location, "different location is projected explicitly")
	var unresolved: Array[CombatSliceCharacterBinding] = [pair[0]]
	facts = ProjectionBuilderScript.build_opponent_availability(pair[0], unresolved)
	_assert_false(facts[0].exists, "unresolved known opponent projects exists=false")


func _test_runtime_availability_gates_and_cleanup() -> void:
	var absent_pair: Array[CombatSliceCharacterBinding] = _initiated_pair()
	absent_pair[0].set_exists_in_encounter(false)
	absent_pair[0].busy.start_busy(2)
	var absent_rng: ScriptedCombatRandomSource = ScriptedRandomScript.new([0])
	var absent: CombatSliceOpportunityResult = _execute(
		absent_pair[0], absent_pair, absent_rng
	)
	_assert_eq(absent.outcome, OpportunityResultScript.Outcome.ACTOR_NOT_AVAILABLE, "despawned actor is a typed no-op")
	_assert_eq(absent_rng.call_count(), 0, "actor availability gate consumes no RNG")
	_assert_eq(absent_pair[0].busy.busy_value, 2, "despawned actor does not advance busy")
	var inactive_pair: Array[CombatSliceCharacterBinding] = _initiated_pair()
	inactive_pair[0].set_life_status(LifeStatusScript.Value.UNCONSCIOUS)
	inactive_pair[0].busy.start_busy(2)
	var inactive_rng: ScriptedCombatRandomSource = ScriptedRandomScript.new([0])
	var inactive: CombatSliceOpportunityResult = _execute(
		inactive_pair[0], inactive_pair, inactive_rng
	)
	_assert_eq(inactive.outcome, OpportunityResultScript.Outcome.ACTOR_NOT_ACTIVE, "runtime non-ACTIVE actor is a typed no-op without threshold")
	_assert_eq(inactive_pair[0].busy.busy_value, 2, "runtime non-ACTIVE actor does not advance busy")
	_assert_eq(inactive_rng.call_count(), 0, "runtime non-ACTIVE actor consumes no RNG")
	var disabled_pair: Array[CombatSliceCharacterBinding] = _initiated_pair()
	disabled_pair[0].set_combat_available(false)
	disabled_pair[0].busy.start_busy(2)
	var disabled_rng: ScriptedCombatRandomSource = ScriptedRandomScript.new([0])
	var disabled: CombatSliceOpportunityResult = _execute(
		disabled_pair[0], disabled_pair, disabled_rng
	)
	_assert_eq(disabled.outcome, OpportunityResultScript.Outcome.COMBAT_NOT_AVAILABLE, "explicit combat availability is enforced")
	_assert_eq(disabled_pair[0].busy.busy_value, 2, "combat-disabled actor does not advance busy")
	_assert_eq(disabled_rng.call_count(), 0, "combat-disabled actor consumes no RNG")
	var distant_pair: Array[CombatSliceCharacterBinding] = _initiated_pair()
	distant_pair[1].set_location_id(&"other")
	var cleanup_rng: ScriptedCombatRandomSource = ScriptedRandomScript.new([0])
	var cleanup: CombatSliceOpportunityResult = _execute(
		distant_pair[0], distant_pair, cleanup_rng
	)
	_assert_eq(cleanup.outcome, OpportunityResultScript.Outcome.NO_OPPONENT, "different-location opponent is cleaned before fight")
	_assert_eq(cleanup_rng.call_count(), 0, "empty post-cleanup set consumes no selection RNG")
	_assert_false(distant_pair[0].relationship.has_opponent(NPC_ID), "cleanup mutates current relationship authority")
	_assert_true(distant_pair[0].relationship.has_lethal_target(NPC_ID), "cleanup preserves separate lethal marker")


func _test_unresolved_cleanup_and_opponent_insertion_order() -> void:
	var unresolved_pair: Array[CombatSliceCharacterBinding] = _initiated_pair()
	var unresolved_rng: ScriptedCombatRandomSource = ScriptedRandomScript.new([0])
	var unresolved_participants: Array[CombatSliceCharacterBinding] = [
		unresolved_pair[0]
	]
	var unresolved: CombatSliceOpportunityResult = _execute(
		unresolved_pair[0], unresolved_participants, unresolved_rng
	)
	_assert_eq(unresolved.outcome, OpportunityResultScript.Outcome.NO_OPPONENT, "unresolved expected opponent cleans through exists=false fact")
	_assert_eq(unresolved.opponent_selection_result.removed_opponent_ids(), [NPC_ID], "cleanup result identifies unresolved opponent")
	_assert_eq(unresolved_rng.call_count(), 0, "unresolved cleanup with no survivors consumes no RNG")
	_assert_false(unresolved_pair[0].relationship.has_opponent(NPC_ID), "unresolved opponent is removed from live authority")

	var ordered_pair: Array[CombatSliceCharacterBinding] = _initiated_pair()
	var third: CombatSliceCharacterBinding = _binding(&"slice-third", false)
	ordered_pair[0].relationship.add_opponent(third.character_id)
	var ordered_participants: Array[CombatSliceCharacterBinding] = [
		ordered_pair[0], ordered_pair[1], third
	]
	var facts: Array[CombatOpponentAvailabilityFacts] = (
		ProjectionBuilderScript.build_opponent_availability(
			ordered_pair[0], ordered_participants
		)
	)
	_assert_eq(facts[0].opponent_id, NPC_ID, "availability preserves first insertion")
	_assert_eq(facts[1].opponent_id, third.character_id, "availability preserves second insertion")
	var selection_rng: ScriptedCombatRandomSource = ScriptedRandomScript.new([1])
	var selected: CombatOpponentSelectionResult = CombatOpponentSelectionService.prepare(
		ordered_pair[0].relationship, facts, selection_rng
	)
	_assert_eq(selected.outcome, SelectionResultScript.Outcome.SELECTED, "ordered availability is accepted by closed selector")
	_assert_eq(selected.selected_opponent_id, third.character_id, "random(4)=1 selects insertion index one")


func _test_fight_projection_visibility_and_raw_attributes() -> void:
	var pair: Array[CombatSliceCharacterBinding] = _initiated_pair()
	pair[0].state.attributes.courage_modifier = 1000
	pair[1].state.attributes.composure_modifier = 1000
	var facts: CombatFightDecisionFacts = ProjectionBuilderScript.build_fight_facts(
		pair[0], pair[1]
	)
	_assert_true(facts.target_visible, "first slice visibility is explicit true")
	_assert_eq(facts.attacker_raw_courage, 20, "fight projection uses raw cor")
	_assert_eq(facts.victim_raw_composure, 20, "fight projection uses raw cps")
	_assert_eq(facts.perception.effective_level, 0, "valid current perception projection is present")
	var rng: ScriptedCombatRandomSource = ScriptedRandomScript.new([0, 0, 0, 0, 0])
	var result: CombatSliceOpportunityResult = _execute(pair[0], pair, rng)
	_assert_false(result.fight_decision_result.perception_random_reached, "visible path consumes no perception RNG")
	_assert_eq(result.fight_decision_result.courage_random_bound, 60, "raw cps sets courage bound despite modifier")


func _test_guard_regular_and_quick_opportunities() -> void:
	var guard_pair: Array[CombatSliceCharacterBinding] = _initiated_pair()
	var guard_rng: ScriptedCombatRandomSource = ScriptedRandomScript.new([0, 59, 2])
	var guard: CombatSliceOpportunityResult = _execute(guard_pair[0], guard_pair, guard_rng)
	_assert_eq(guard.outcome, OpportunityResultScript.Outcome.ENTERED_GUARDING, "guard is a terminal no-attack opportunity")
	_assert_true(guard_pair[0].relationship.guarding, "guard mutation remains authoritative")
	_assert_true(guard.forward_result == null and guard.chain_result == null, "guard creates no attack projections")
	_assert_eq(guard.reached_stage, OpportunityResultScript.ReachedStage.FIGHT_DECISION, "guard reports fight-decision terminal stage")
	_assert_eq(guard.random_upper_bounds(), [4, 60, 5], "guard RNG is selection plus fight exactly once")

	var regular_pair: Array[CombatSliceCharacterBinding] = _initiated_pair()
	var regular: CombatSliceOpportunityResult = _execute(
		regular_pair[0], regular_pair, ScriptedRandomScript.new([0, 0, 0, 0, 0])
	)
	_assert_eq(regular.fight_decision_result.outcome, FightResultScript.Outcome.REGULAR_ATTACK, "raw courage branch produces REGULAR")
	_assert_true(regular.forward_result != null, "REGULAR reaches forward attack")

	var quick_pair: Array[CombatSliceCharacterBinding] = _initiated_pair()
	quick_pair[1].busy.start_busy(2)
	var quick_rng: ScriptedCombatRandomSource = ScriptedRandomScript.new([0, 0, 0, 0, 0])
	var quick: CombatSliceOpportunityResult = _execute(quick_pair[0], quick_pair, quick_rng)
	_assert_eq(quick.fight_decision_result.outcome, FightResultScript.Outcome.QUICK_ATTACK, "busy victim produces QUICK")
	_assert_false(quick.fight_decision_result.courage_random_reached, "QUICK consumes no courage RNG")
	_assert_eq(quick.random_upper_bounds(), [4, 1, 16, 13, 120], "QUICK RNG omits fight courage and preserves later closed draws")
	_assert_eq(quick.random_draws(), [0, 0, 0, 0, 0], "QUICK draw zero evidence remains reached and unambiguous")

	var nonliving_pair: Array[CombatSliceCharacterBinding] = _initiated_pair()
	nonliving_pair[1].set_life_status(LifeStatusScript.Value.UNCONSCIOUS)
	var nonliving: CombatSliceOpportunityResult = _execute(
		nonliving_pair[0], nonliving_pair, ScriptedRandomScript.new([0, 0, 0, 0, 0])
	)
	_assert_eq(nonliving.fight_decision_result.outcome, FightResultScript.Outcome.QUICK_ATTACK, "lethal relation retains runtime nonliving victim for QUICK")
	_assert_eq(nonliving.opponent_selection_result.retained_opponent_ids(), [NPC_ID], "UNCONSCIOUS lethal victim remains selectable")


func _test_dodge_parry_hit_and_rng_timeline() -> void:
	var dodge_pair: Array[CombatSliceCharacterBinding] = _initiated_pair()
	var dodge_rng: ScriptedCombatRandomSource = ScriptedRandomScript.new([0, 0, 0, 0, 0])
	var dodge: CombatSliceOpportunityResult = _execute(dodge_pair[0], dodge_pair, dodge_rng)
	_assert_eq(_forward_base_outcome(dodge), BaseAttackResultScript.Outcome.DODGE, "scripted ordinary path dodges")
	_assert_eq(dodge.random_upper_bounds(), [4, 60, 1, 16, 20], "DODGE shares exact ordered RNG timeline")
	_assert_eq(dodge.forward_result.action_selection_result.random_upper_bounds(), [1], "slash selector still consumes random(1)")
	_assert_eq(dodge.forward_result.selected_action_id, ContentScript.SLASH_ACTION_ID, "selected slash identity reaches resolver")

	var parry_pair: Array[CombatSliceCharacterBinding] = _initiated_pair()
	var parry: CombatSliceOpportunityResult = _execute(
		parry_pair[0], parry_pair, ScriptedRandomScript.new([0, 0, 0, 0, 10, 0])
	)
	_assert_eq(_forward_base_outcome(parry), BaseAttackResultScript.Outcome.PARRY, "scripted ordinary path parries")
	_assert_eq(parry.random_upper_bounds(), [4, 60, 1, 16, 20, 20], "PARRY timeline includes exact two defense draws")

	var hit_pair: Array[CombatSliceCharacterBinding] = _initiated_pair()
	var hit_draws: Array[int] = [0, 0, 0, 0, 10, 10, 0, 0, 0, 0, 0]
	var hit: CombatSliceOpportunityResult = _execute(
		hit_pair[0], hit_pair, ScriptedRandomScript.new(hit_draws)
	)
	_assert_eq(_forward_base_outcome(hit), BaseAttackResultScript.Outcome.HIT, "scripted ordinary path hits")
	_assert_eq(hit.outcome, OpportunityResultScript.Outcome.ATTACK_CHAIN_COMPLETE, "ordinary HIT completes chain")
	_assert_true(hit_pair[1].state.vitality.current < 220, "HIT mutates live vitality through closed Core")
	_assert_false(hit.forward_result.post_action_policy_present, "slice does not reach authored post_action")
	_assert_false(hit.reverse_projection_built, "no reverse request builds no reverse projection")
	_assert_eq(hit.chain_result.outcome, ChainResultScript.Outcome.FORWARD_COMPLETE_NO_REVERSE, "no-request chain completes lazily")


func _test_live_reverse_projection_after_progression() -> void:
	var pair: Array[CombatSliceCharacterBinding] = _initiated_pair()
	pair[0].state.skills.set_raw_level(&"sword", 20)
	pair[1].relationship.set_guarding(true)
	var rng: ScriptedCombatRandomSource = ScriptedRandomScript.new(
		[0, 0, 0, 0, 0, 51, 0, 0, 0, 0, 0]
	)
	var result: CombatSliceOpportunityResult = _execute(pair[0], pair, rng)
	_assert_eq(_forward_base_outcome(result), BaseAttackResultScript.Outcome.DODGE, "forward high-power attack is scripted to dodge")
	_assert_eq(pair[1].state.progression.combat_experience, 11, "forward progression mutates future reverse attacker")
	_assert_true(result.reverse_projection_built, "reverse projection is built only after request")
	_assert_eq(result.reverse_attacker_experience_at_projection, 11, "reverse projection rereads post-forward combat_exp")
	_assert_eq(result.chain_result.outcome, ChainResultScript.Outcome.REVERSE_COMPLETE, "live reverse completes through closed chain service")
	_assert_true(result.chain_result.reverse_execution_reached, "synchronous reverse body executes once")
	_assert_eq(result.random_upper_bounds(), [4, 60, 1, 16, 320, 120, 20, 1, 16, 21, 120], "guarding-riposte RNG is selection plus chain without duplicate fight prefix")
	_assert_eq(result.random_draws(), [0, 0, 0, 0, 0, 51, 0, 0, 0, 0, 0], "guarding-riposte draws preserve one continuous source timeline")
	_assert_eq(rng.requested_bounds(), result.random_upper_bounds(), "one random source carries forward and reverse timeline")
	_assert_eq(rng.call_count(), result.random_draws().size(), "result accounts for every shared RNG draw")


func _test_reverse_threshold_is_not_applied_mid_chain() -> void:
	var pair: Array[CombatSliceCharacterBinding] = _initiated_pair()
	pair[0].state.skills.set_raw_level(&"sword", 20)
	pair[0].state.vitality.current = 20
	pair[1].relationship.set_guarding(true)
	var draws: Array[int] = [
		0, 0, 0, 0, 0, 51, 0,
		0, 0, 10, 10, 0, 0, 0, 0, 0,
	]
	var result: CombatSliceOpportunityResult = _execute(
		pair[0], pair, ScriptedRandomScript.new(draws)
	)
	_assert_eq(result.chain_result.outcome, ChainResultScript.Outcome.REVERSE_COMPLETE, "reverse threshold path completes the synchronous chain")
	_assert_eq(result.chain_result.reverse_ordinary_result.base_result.outcome, BaseAttackResultScript.Outcome.HIT, "reverse attack actually hits original attacker")
	_assert_eq(pair[0].state.vitality.current, -1, "reverse hit crosses original attacker current threshold")
	_assert_eq(pair[0].life_status, LifeStatusScript.Value.ACTIVE, "reverse threshold does not mutate runtime life status mid-chain")
	var availability: Array[CombatOpponentAvailabilityFacts] = (
		ProjectionBuilderScript.build_opponent_availability(pair[1], pair)
	)
	_assert_true(availability[0].living, "other actor still sees threshold-crossed ACTIVE target as living before its gate")
	var next_rng: ScriptedCombatRandomSource = ScriptedRandomScript.new([0])
	var next: CombatSliceOpportunityResult = _execute(pair[0], pair, next_rng)
	_assert_eq(next.outcome, OpportunityResultScript.Outcome.LIFECYCLE_REQUIRED_UNCONSCIOUS, "original attacker lifecycle waits for its next outer opportunity")
	_assert_eq(next_rng.call_count(), 0, "later reverse-threshold lifecycle consumes no combat RNG")


func _test_partial_mutations_survive_later_failures() -> void:
	var guard_clear_pair: Array[CombatSliceCharacterBinding] = _initiated_pair()
	guard_clear_pair[0].relationship.set_guarding(true)
	_replace_primary_with_unknown(guard_clear_pair[0])
	var guard_clear: CombatSliceOpportunityResult = _execute(
		guard_clear_pair[0], guard_clear_pair, ScriptedRandomScript.new([0, 0])
	)
	_assert_eq(guard_clear.outcome, OpportunityResultScript.Outcome.ATTACK_CHAIN_INCOMPLETE, "later provider failure remains explicit")
	_assert_false(guard_clear_pair[0].relationship.guarding, "fight-decision guard clear is not rolled back after attack failure")
	_assert_true(guard_clear.forward_result.partial_mutation_preserved, "forward result records earlier relationship mutation")

	var reverse_failure_pair: Array[CombatSliceCharacterBinding] = _initiated_pair()
	reverse_failure_pair[0].state.skills.set_raw_level(&"sword", 20)
	reverse_failure_pair[1].relationship.set_guarding(true)
	_replace_primary_with_unknown(reverse_failure_pair[1])
	var reverse_failure: CombatSliceOpportunityResult = _execute(
		reverse_failure_pair[0],
		reverse_failure_pair,
		ScriptedRandomScript.new([0, 0, 0, 0, 0, 51, 0]),
	)
	_assert_eq(reverse_failure.chain_result.outcome, ChainResultScript.Outcome.REVERSE_ACTION_SELECTION_FAILED, "reverse unavailable provider fails at closed selection boundary")
	_assert_eq(reverse_failure_pair[1].state.progression.combat_experience, 11, "forward progression remains after reverse failure")
	_assert_true(reverse_failure.chain_result.partial_mutation_preserved, "chain records preserved forward mutation")


func _test_threshold_candidate_deferred_to_affected_opportunity() -> void:
	var pair: Array[CombatSliceCharacterBinding] = _initiated_pair()
	pair[1].state.vitality.current = 20
	var hit: CombatSliceOpportunityResult = _execute(
		pair[0], pair, ScriptedRandomScript.new([0, 0, 0, 0, 10, 10, 0, 0, 0, 0, 0])
	)
	_assert_eq(hit.outcome, OpportunityResultScript.Outcome.ATTACK_CHAIN_COMPLETE, "threshold-producing forward still completes its chain")
	_assert_eq(pair[1].state.vitality.current, -1, "attack leaves current vitality at unconscious threshold")
	_assert_eq(pair[1].life_status, LifeStatusScript.Value.ACTIVE, "no lifecycle is applied mid-chain or post-chain")
	var next_rng: ScriptedCombatRandomSource = ScriptedRandomScript.new([0])
	var next: CombatSliceOpportunityResult = _execute(pair[1], pair, next_rng)
	_assert_eq(next.outcome, OpportunityResultScript.Outcome.LIFECYCLE_REQUIRED_UNCONSCIOUS, "affected actor observes threshold only at own next opportunity")
	_assert_eq(next_rng.call_count(), 0, "deferred lifecycle gate still consumes zero RNG")
	_assert_eq(pair[1].life_status, LifeStatusScript.Value.ACTIVE, "6B1 reports but does not execute lifecycle")


func _test_result_defensive_snapshots() -> void:
	var pair: Array[CombatSliceCharacterBinding] = _initiated_pair()
	var result: CombatSliceOpportunityResult = _execute(
		pair[0], pair, ScriptedRandomScript.new([0, 59, 1])
	)
	var selection: CombatOpponentSelectionResult = result.opponent_selection_result
	selection._selected_opponent_id = &"tampered"
	_assert_eq(result.opponent_selection_result.selected_opponent_id, NPC_ID, "opportunity result returns defensive selection snapshots")
	var fight: CombatFightDecisionResult = result.fight_decision_result
	fight._outcome = FightResultScript.Outcome.INVALID_SOURCE_STATE
	_assert_eq(result.fight_decision_result.outcome, FightResultScript.Outcome.ENTERED_GUARDING, "opportunity result returns defensive fight snapshots")
	var bounds: Array[int] = result.random_upper_bounds()
	bounds.clear()
	_assert_eq(result.random_upper_bounds(), [4, 60, 5], "computed RNG evidence is value-like")
	for forbidden_property: StringName in [
		&"state", &"relationship", &"equipment", &"armor", &"busy",
		&"random_source", &"participants",
	]:
		_assert_false(_has_property(result, forbidden_property), "opportunity result retains no authority alias: %s" % forbidden_property)
	var initiation_pair: Array[CombatSliceCharacterBinding] = _pair()
	var initiation: CombatSliceInitiationResult = ExecutorScript.initiate_lethal_combat(
		initiation_pair[0], initiation_pair[1]
	)
	var initiation_copy: CombatSliceInitiationResult = initiation.duplicate_snapshot()
	initiation_copy._target_id = &"tampered"
	_assert_eq(initiation.target_id, NPC_ID, "initiation snapshot is detached")
	for forbidden_property: StringName in [
		&"state", &"relationship", &"participants", &"random_source",
	]:
		_assert_false(_has_property(initiation, forbidden_property), "initiation result retains no authority alias: %s" % forbidden_property)


func _binding(
	character_id: StringName,
	is_user: bool,
	relationship: CombatRelationshipState = null,
) -> CombatSliceCharacterBinding:
	var state: CharacterState = CharacterStateScript.new()
	state.attributes = AttributesScript.new(20, 20, 20, 20, 20, 20, 20, 20)
	state.essence = ResourceScript.new(220, 220, 220)
	state.vitality = ResourceScript.new(220, 220, 220)
	state.spirit = ResourceScript.new(100, 100, 100)
	state.progression.combat_experience = 10
	for skill_id: StringName in [&"sword", &"dodge", &"parry", &"unarmed"]:
		state.skills.set_raw_level(skill_id, 10)
	state.skills.set_raw_level(&"force", 0)
	state.skills.set_raw_level(&"perception", 0)
	var definition: WeaponDefinition = WeaponDefinitionScript.new(
		ContentScript.LONG_SWORD_ID,
		ContentScript.LONG_SWORD_SKILL_ID,
		false,
		false,
		ContentScript.LONG_SWORD_SOURCE,
	)
	var weapon: EquippedWeaponRef = EquippedWeaponScript.new(
		StringName("%s-sword" % String(character_id)),
		definition,
	)
	state.equipment.wield(weapon, false)
	return BindingScript.new(
		character_id,
		state,
		relationship if relationship != null else RelationshipScript.new(character_id),
		BusyScript.new(),
		ArmorScript.new(),
		ContentScript.new(),
		ARENA_ID,
		true,
		LifeStatusScript.Value.ACTIVE,
		is_user,
		true,
	)


func _pair() -> Array[CombatSliceCharacterBinding]:
	return [_binding(PLAYER_ID, true), _binding(NPC_ID, false)]


func _initiated_pair() -> Array[CombatSliceCharacterBinding]:
	var pair: Array[CombatSliceCharacterBinding] = _pair()
	ExecutorScript.initiate_lethal_combat(pair[0], pair[1])
	return pair


func _execute(
	actor: CombatSliceCharacterBinding,
	participants: Array[CombatSliceCharacterBinding],
	rng: ScriptedCombatRandomSource,
) -> CombatSliceOpportunityResult:
	var registry: SkillImprovementEffectRegistry = EffectRegistryScript.new()
	registry.register_legacy_defaults()
	return ExecutorScript.execute_opportunity(actor, participants, rng, registry)


func _assert_incoherent_participants_rejected(
	participants: Array[CombatSliceCharacterBinding],
	message: String,
) -> void:
	var rng: ScriptedCombatRandomSource = ScriptedRandomScript.new([0])
	var result: CombatSliceOpportunityResult = _execute(
		participants[0], participants, rng
	)
	_assert_eq(result.outcome, OpportunityResultScript.Outcome.INVALID_INPUT, message)
	_assert_eq(rng.call_count(), 0, "%s before RNG" % message)


func _replace_primary_with_unknown(binding: CombatSliceCharacterBinding) -> void:
	var current: EquippedWeaponRef = binding.state.equipment.primary_weapon()
	if current != null:
		binding.state.equipment.unwield(current.instance_id)
	var unknown_definition: WeaponDefinition = WeaponDefinitionScript.new(
		&"es2:test/unknown_sword", &"sword", false, false, "test/unknown_sword.c"
	)
	binding.state.equipment.wield(
		EquippedWeaponScript.new(
			StringName("%s-unknown-sword" % String(binding.character_id)),
			unknown_definition,
		),
		false,
	)


func _resource_snapshot(state: CharacterState) -> Array[int]:
	return [
		state.essence.current, state.essence.effective, state.essence.maximum,
		state.vitality.current, state.vitality.effective, state.vitality.maximum,
		state.spirit.current, state.spirit.effective, state.spirit.maximum,
	]


func _has_property(value: Object, property_name: StringName) -> bool:
	for property: Dictionary in value.get_property_list():
		if property["name"] == property_name:
			return true
	return false


func _forward_base_outcome(result: CombatSliceOpportunityResult) -> int:
	if result.forward_result == null or result.forward_result.ordinary_attack_result == null:
		return -1
	return result.forward_result.ordinary_attack_result.base_result.outcome


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
