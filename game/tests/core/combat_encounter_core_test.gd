extends RefCounted

const TriggerCauseScript := preload(
	"res://core/combat/encounter/combat_trigger_cause.gd"
)
const EncounterModeScript := preload(
	"res://core/combat/encounter/combat_encounter_mode.gd"
)
const LifecycleScript := preload(
	"res://core/combat/encounter/combat_encounter_lifecycle.gd"
)
const ResultKindScript := preload(
	"res://core/combat/encounter/combat_encounter_result_kind.gd"
)
const EventKindScript := preload(
	"res://core/combat/encounter/combat_encounter_event_kind.gd"
)
const TriggerCandidateScript := preload(
	"res://core/combat/encounter/combat_trigger_candidate.gd"
)
const TriggerScript := preload("res://core/combat/encounter/combat_trigger.gd")
const BindingScript := preload(
	"res://core/combat/encounter/combat_encounter_authority_binding.gd"
)
const ParticipantScript := preload(
	"res://core/combat/encounter/combat_participant.gd"
)
const HostilityScript := preload(
	"res://core/combat/encounter/combat_directed_hostility.gd"
)
const TargetAssignmentScript := preload(
	"res://core/combat/encounter/combat_target_assignment.gd"
)
const ResultScript := preload(
	"res://core/combat/encounter/combat_encounter_result.gd"
)
const EventScript := preload(
	"res://core/combat/encounter/combat_encounter_event.gd"
)
const EncounterScript := preload(
	"res://core/combat/encounter/combat_encounter.gd"
)
const CharacterStateScript := preload("res://core/characters/character_state.gd")
const RelationshipScript := preload(
	"res://core/combat/relationship/combat_relationship_state.gd"
)
const BusyScript := preload("res://core/combat/busy/action_busy_state.gd")
const ArmorScript := preload("res://core/armor/armor_state.gd")
const LocationScript := preload("res://core/world/world_location_state.gd")

const ENCOUNTER_ID: StringName = &"encounter-cxr2-1"
const TRIGGER_ID: StringName = &"trigger-cxr2-1"
const ACTOR_ID: StringName = &"actor-a"
const HOSTILE_ONE_ID: StringName = &"hostile-b1"
const HOSTILE_TWO_ID: StringName = &"hostile-b2"
const SIDE_A: StringName = &"side-a"
const SIDE_B: StringName = &"side-b"

var _assertion_count: int = 0
var _failures: Array[String] = []


func run_all() -> Dictionary[String, Variant]:
	_test_trigger_contract()
	_test_authority_binding_identity()
	_test_participant_side_and_construction_invariants()
	_test_directed_hostility()
	_test_target_assignment()
	_test_lifecycle_and_terminal_result()
	_test_structural_event_ordering()
	_test_three_participant_model()
	return {
		"assertions": _assertion_count,
		"failures": _failures.duplicate(),
	}


func _test_trigger_contract() -> void:
	var candidates: Array[CombatTriggerCandidate] = [
		TriggerCandidateScript.new(ACTOR_ID, SIDE_A),
		TriggerCandidateScript.new(HOSTILE_ONE_ID, SIDE_B),
	]
	var source: WorldLocationState = _location()
	var trigger: CombatTrigger = TriggerScript.new(
		TRIGGER_ID,
		TriggerCauseScript.Value.PLAYER_LETHAL_ATTACK,
		EncounterModeScript.Value.LETHAL,
		ACTOR_ID,
		candidates,
		source,
	)
	_assert_true(trigger.is_valid(), "valid typed trigger accepted")
	_assert_true(trigger is RefCounted, "trigger is RefCounted domain value")
	_assert_eq(trigger.trigger_id, TRIGGER_ID, "trigger correlation ID preserved")
	_assert_eq(trigger.cause, TriggerCauseScript.Value.PLAYER_LETHAL_ATTACK, "closed trigger cause preserved")
	_assert_eq(trigger.requested_mode, EncounterModeScript.Value.LETHAL, "requested encounter mode preserved")
	_assert_eq(trigger.initiator_id, ACTOR_ID, "initiator semantic ID preserved")
	_assert_eq(trigger.candidates().size(), 2, "typed candidates preserved")
	_assert_eq(trigger.candidates()[1].side_id, SIDE_B, "candidate side preserved")
	_assert_true(trigger.source_location.same_location(source), "semantic source location preserved")
	_assert_false(trigger.source_location == source, "source location is immutable snapshot data")
	var returned_candidates: Array[CombatTriggerCandidate] = trigger.candidates()
	returned_candidates.clear()
	_assert_eq(trigger.candidates().size(), 2, "returned candidate array cannot mutate trigger")

	_assert_false(
		TriggerScript.new(&"", trigger.cause, trigger.requested_mode, ACTOR_ID, candidates, source).is_valid(),
		"empty trigger ID rejected",
	)
	_assert_false(
		TriggerScript.new(TRIGGER_ID, -1, trigger.requested_mode, ACTOR_ID, candidates, source).is_valid(),
		"invalid cause rejected",
	)
	_assert_false(
		TriggerScript.new(TRIGGER_ID, trigger.cause, -1, ACTOR_ID, candidates, source).is_valid(),
		"invalid mode rejected",
	)
	_assert_false(
		TriggerScript.new(TRIGGER_ID, trigger.cause, trigger.requested_mode, &"", candidates, source).is_valid(),
		"empty initiator rejected",
	)
	_assert_false(
		TriggerScript.new(TRIGGER_ID, trigger.cause, trigger.requested_mode, ACTOR_ID, candidates, null).is_valid(),
		"missing source location rejected",
	)
	var duplicate_candidates: Array[CombatTriggerCandidate] = [
		TriggerCandidateScript.new(ACTOR_ID, SIDE_A),
		TriggerCandidateScript.new(ACTOR_ID, SIDE_B),
	]
	_assert_false(
		TriggerScript.new(TRIGGER_ID, trigger.cause, trigger.requested_mode, ACTOR_ID, duplicate_candidates, source).is_valid(),
		"duplicate candidate semantic IDs rejected",
	)
	var missing_initiator: Array[CombatTriggerCandidate] = [
		TriggerCandidateScript.new(HOSTILE_ONE_ID, SIDE_B),
	]
	_assert_false(
		TriggerScript.new(TRIGGER_ID, trigger.cause, trigger.requested_mode, ACTOR_ID, missing_initiator, source).is_valid(),
		"initiator must be among candidate facts",
	)
	_assert_false(
		TriggerScript.new(TRIGGER_ID, TriggerCauseScript.Value.SCRIPTED, EncounterModeScript.Value.SCRIPTED, ACTOR_ID, candidates, source).is_valid(),
		"scripted mode requires stable authored policy ID",
	)
	_assert_true(
		TriggerScript.new(TRIGGER_ID, TriggerCauseScript.Value.SCRIPTED, EncounterModeScript.Value.SCRIPTED, ACTOR_ID, candidates, source, &"oldpine-scripted-1").is_valid(),
		"scripted policy semantic ID is accepted",
	)


func _test_authority_binding_identity() -> void:
	var state: CharacterState = CharacterStateScript.new()
	var relationship: CombatRelationshipState = RelationshipScript.new(ACTOR_ID)
	var busy: ActionBusyState = BusyScript.new()
	var armor: ArmorState = ArmorScript.new()
	var binding: CombatEncounterAuthorityBinding = BindingScript.new(
		ACTOR_ID,
		state,
		relationship,
		busy,
		armor,
	)
	_assert_true(binding.is_valid(), "complete authority binding valid")
	_assert_true(binding.state == state, "binding retains exact CharacterState")
	_assert_true(binding.state.skills == state.skills, "binding uses composed exact skill authority")
	_assert_true(binding.state.equipment == state.equipment, "binding uses composed exact EquipmentState")
	_assert_true(binding.relationship == relationship, "binding retains exact relationship authority")
	_assert_true(binding.busy == busy, "binding retains exact busy authority")
	_assert_true(binding.armor == armor, "binding retains exact ArmorState")
	var duplicate: CombatEncounterAuthorityBinding = binding.duplicate_reference()
	_assert_false(duplicate == binding, "binding wrapper can be copied independently")
	_assert_true(duplicate.state == state, "copied binding retains exact CharacterState")
	_assert_true(duplicate.relationship == relationship, "copied binding retains exact relationship")
	_assert_true(duplicate.busy == busy, "copied binding retains exact busy state")
	_assert_true(duplicate.armor == armor, "copied binding retains exact armor state")
	state.gender = &"authority-identity-proof"
	_assert_eq(
		duplicate.state.gender,
		&"authority-identity-proof",
		"authority mutations are visible through exact reference",
	)
	_assert_false(
		BindingScript.new(ACTOR_ID, state, RelationshipScript.new(&"other"), busy, armor).is_valid(),
		"relationship owner must match participant identity",
	)
	_assert_false(BindingScript.new(ACTOR_ID, state, relationship, busy, null).is_valid(), "missing authority rejected")


func _test_participant_side_and_construction_invariants() -> void:
	var actor: CombatParticipant = _participant(ACTOR_ID, SIDE_A)
	var hostile: CombatParticipant = _participant(HOSTILE_ONE_ID, SIDE_B)
	_assert_true(actor.is_valid(), "participant with exact matching binding valid")
	_assert_eq(actor.side_id, SIDE_A, "open semantic side ID preserved")
	_assert_false(CombatParticipant.new(ACTOR_ID, &"", actor.binding).is_valid(), "empty side rejected")
	_assert_false(
		CombatParticipant.new(&"other", SIDE_A, actor.binding).is_valid(),
		"participant ID must match authority binding",
	)

	var valid: CombatEncounter = _encounter([actor, hostile], [_hostility(SIDE_A, SIDE_B)])
	_assert_true(valid.is_valid(), "valid encounter construction accepted")
	_assert_eq(valid.participants().size(), 2, "participant collection retained")
	_assert_eq(valid.side_ids(), [SIDE_A, SIDE_B], "side collection derives in participant order")
	_assert_true(valid.participant_for(ACTOR_ID).binding.state == actor.binding.state, "encounter copy keeps exact state authority")

	var trigger: CombatTrigger = _trigger_for([actor, hostile])
	var duplicate_participants: Array[CombatParticipant] = [actor, actor]
	var duplicate: CombatEncounter = EncounterScript.new(
		ENCOUNTER_ID,
		trigger,
		duplicate_participants,
		[_hostility(SIDE_A, SIDE_B)],
	)
	_assert_false(duplicate.is_valid(), "duplicate accepted participant IDs rejected")

	var wrong_side: CombatParticipant = _participant(HOSTILE_ONE_ID, &"side-c")
	var side_mismatch: CombatEncounter = EncounterScript.new(
		ENCOUNTER_ID,
		trigger,
		[actor, wrong_side],
		[] as Array[CombatDirectedHostility],
	)
	_assert_false(side_mismatch.is_valid(), "accepted side must match trigger candidate fact")

	var no_initiator: CombatEncounter = EncounterScript.new(
		ENCOUNTER_ID,
		trigger,
		[hostile] as Array[CombatParticipant],
		[] as Array[CombatDirectedHostility],
	)
	_assert_false(no_initiator.is_valid(), "accepted participants must retain trigger initiator")


func _test_directed_hostility() -> void:
	var participants: Array[CombatParticipant] = _three_participants()
	var one_way: CombatEncounter = _encounter(
		participants,
		[_hostility(SIDE_A, SIDE_B)],
	)
	_assert_true(one_way.is_valid(), "one-way directed hostility valid")
	_assert_true(one_way.has_directed_hostility(SIDE_A, SIDE_B), "A to B hostility represented")
	_assert_false(one_way.has_directed_hostility(SIDE_B, SIDE_A), "B to A may remain non-hostile")
	_assert_true(one_way.is_hostile(ACTOR_ID, HOSTILE_ONE_ID), "participant target follows side direction")
	_assert_false(one_way.is_hostile(HOSTILE_ONE_ID, ACTOR_ID), "reverse participant hostility not inferred")

	var both: Array[CombatDirectedHostility] = [
		_hostility(SIDE_A, SIDE_B),
		_hostility(SIDE_B, SIDE_A),
	]
	var symmetric: CombatEncounter = _encounter(participants, both)
	_assert_true(symmetric.is_valid(), "two explicit directions represent symmetric hostility")
	_assert_true(symmetric.is_hostile(ACTOR_ID, HOSTILE_ONE_ID), "symmetric forward direction exists")
	_assert_true(symmetric.is_hostile(HOSTILE_ONE_ID, ACTOR_ID), "symmetric reverse direction exists")

	var unknown: CombatEncounter = _encounter(
		participants,
		[_hostility(SIDE_A, &"unknown-side")],
	)
	_assert_false(unknown.is_valid(), "hostility referencing unknown side rejected")
	var duplicate: CombatEncounter = _encounter(
		participants,
		[_hostility(SIDE_A, SIDE_B), _hostility(SIDE_A, SIDE_B)],
	)
	_assert_false(duplicate.is_valid(), "duplicate directed hostility rejected")
	_assert_false(_hostility(SIDE_A, SIDE_A).is_valid(), "self-side hostility fact rejected")


func _test_target_assignment() -> void:
	var encounter: CombatEncounter = _encounter(
		_three_participants(),
		[_hostility(SIDE_A, SIDE_B)],
	)
	_assert_true(encounter.activate(), "valid encounter activates")
	_assert_true(encounter.set_current_target(ACTOR_ID, HOSTILE_ONE_ID), "valid hostile target accepted")
	_assert_eq(encounter.current_target_for(ACTOR_ID), HOSTILE_ONE_ID, "current target query returns semantic ID")
	_assert_false(encounter.set_current_target(ACTOR_ID, ACTOR_ID), "self target rejected")
	_assert_false(encounter.set_current_target(ACTOR_ID, &"unknown"), "unknown target rejected")
	_assert_false(encounter.set_current_target(HOSTILE_ONE_ID, ACTOR_ID), "non-hostile reverse target rejected")
	_assert_eq(encounter.current_target_for(ACTOR_ID), HOSTILE_ONE_ID, "invalid changes preserve valid target")
	_assert_false(encounter.set_current_target(ACTOR_ID, HOSTILE_ONE_ID), "duplicate target assignment produces no mutation")
	_assert_eq(encounter.target_assignments().size(), 1, "only one assignment exists per actor")
	_assert_true(encounter.set_current_target(ACTOR_ID, HOSTILE_TWO_ID), "explicit target change succeeds")
	_assert_eq(encounter.current_target_for(ACTOR_ID), HOSTILE_TWO_ID, "replacement target stored")
	_assert_eq(encounter.target_assignments().size(), 1, "target change replaces instead of duplicating")
	_assert_true(encounter.clear_current_target(ACTOR_ID), "explicit target clear succeeds")
	_assert_eq(encounter.current_target_for(ACTOR_ID), &"", "target clear removes assignment")
	_assert_false(encounter.clear_current_target(ACTOR_ID), "clearing absent target rejected")


func _test_lifecycle_and_terminal_result() -> void:
	_assert_true(
		LifecycleScript.can_transition(LifecycleScript.Value.ESTABLISHING, LifecycleScript.Value.ACTIVE),
		"establishing to active transition allowed",
	)
	_assert_true(
		LifecycleScript.can_transition(LifecycleScript.Value.ACTIVE, LifecycleScript.Value.RESOLVING),
		"active to resolving transition allowed",
	)
	_assert_true(
		LifecycleScript.can_transition(LifecycleScript.Value.RESOLVING, LifecycleScript.Value.COMPLETED),
		"resolving to completed transition allowed",
	)
	_assert_false(
		LifecycleScript.can_transition(LifecycleScript.Value.COMPLETED, LifecycleScript.Value.ACTIVE),
		"terminal encounter cannot reopen",
	)

	var encounter: CombatEncounter = _encounter(
		_three_participants(),
		[_hostility(SIDE_A, SIDE_B)],
	)
	_assert_eq(encounter.phase, LifecycleScript.Value.ESTABLISHING, "encounter starts establishing")
	_assert_false(encounter.begin_resolving(), "cannot resolve before activation")
	_assert_false(encounter.complete(_victory_result()), "cannot complete before resolving")
	_assert_true(encounter.activate(), "activation transition succeeds")
	_assert_false(encounter.activate(), "activation cannot repeat")
	_assert_true(encounter.begin_resolving(), "active encounter begins resolving")
	_assert_false(encounter.begin_resolving(), "resolving transition cannot repeat")
	var wrong_id: CombatEncounterResult = ResultScript.new(
		&"wrong-encounter",
		EncounterModeScript.Value.LETHAL,
		ResultKindScript.Value.VICTORY,
		[SIDE_A] as Array[StringName],
		[SIDE_B] as Array[StringName],
	)
	_assert_false(encounter.complete(wrong_id), "result encounter ID mismatch rejected")
	_assert_eq(encounter.phase, LifecycleScript.Value.RESOLVING, "invalid result preserves resolving phase")
	var unknown_side: CombatEncounterResult = ResultScript.new(
		ENCOUNTER_ID,
		EncounterModeScript.Value.LETHAL,
		ResultKindScript.Value.VICTORY,
		[&"unknown-side"] as Array[StringName],
	)
	_assert_false(encounter.complete(unknown_side), "result referencing unknown side rejected")
	var result: CombatEncounterResult = _victory_result()
	_assert_true(result.is_valid(), "typed terminal result valid")
	_assert_true(encounter.complete(result), "resolving encounter completes once")
	_assert_eq(encounter.phase, LifecycleScript.Value.COMPLETED, "completed phase committed")
	_assert_true(encounter.terminal_result != null, "terminal result assigned")
	_assert_false(encounter.terminal_result == result, "terminal result exposed as immutable snapshot")
	_assert_eq(encounter.terminal_result.kind, ResultKindScript.Value.VICTORY, "terminal result kind preserved")
	_assert_false(encounter.complete(_victory_result()), "second completion rejected")
	_assert_false(encounter.activate(), "completed encounter cannot reactivate")
	_assert_false(encounter.set_current_target(ACTOR_ID, HOSTILE_ONE_ID), "terminal encounter rejects target mutation")

	var failed: CombatEncounter = _encounter(
		_three_participants(),
		[_hostility(SIDE_A, SIDE_B)],
	)
	var failed_result: CombatEncounterResult = ResultScript.new(
		ENCOUNTER_ID,
		EncounterModeScript.Value.LETHAL,
		ResultKindScript.Value.FAILED_TO_ESTABLISH,
	)
	_assert_true(failed.fail_to_establish(failed_result), "failed establishment terminal path accepted")
	_assert_eq(failed.phase, LifecycleScript.Value.FAILED_TO_ESTABLISH, "failed establishment phase committed")
	_assert_false(failed.fail_to_establish(failed_result), "failed encounter cannot fail twice")
	_assert_false(failed.activate(), "failed encounter cannot activate")

	var invalid_scripted: CombatEncounterResult = ResultScript.new(
		ENCOUNTER_ID,
		EncounterModeScript.Value.SCRIPTED,
		ResultKindScript.Value.SCRIPTED,
	)
	_assert_false(invalid_scripted.is_valid(), "scripted result requires stable semantic result ID")


func _test_structural_event_ordering() -> void:
	var encounter: CombatEncounter = _encounter(
		_three_participants(),
		[_hostility(SIDE_A, SIDE_B)],
	)
	_assert_eq(encounter.events().size(), 0, "establishing encounter begins with empty event sequence")
	encounter.activate()
	encounter.set_current_target(ACTOR_ID, HOSTILE_ONE_ID)
	encounter.set_current_target(ACTOR_ID, HOSTILE_TWO_ID)
	encounter.begin_resolving()
	encounter.complete(_victory_result())
	var events: Array[CombatEncounterEvent] = encounter.events()
	_assert_eq(events.size(), 5, "structural operations emit exactly five events")
	for index: int in range(events.size()):
		_assert_eq(events[index].sequence, index + 1, "event sequence is deterministic and monotonic")
		_assert_eq(events[index].encounter_id, ENCOUNTER_ID, "event retains semantic encounter ID")
		_assert_true(events[index].is_valid(), "emitted event is typed and valid")
	_assert_eq(events[0].kind, EventKindScript.Value.ENCOUNTER_ESTABLISHED, "first event establishes encounter")
	_assert_eq(events[1].kind, EventKindScript.Value.TARGET_CHANGED, "initial target event follows establishment")
	_assert_eq(events[1].previous_target_id, &"", "initial target change has explicit empty previous target")
	_assert_eq(events[2].previous_target_id, HOSTILE_ONE_ID, "target replacement records previous target")
	_assert_eq(events[2].current_target_id, HOSTILE_TWO_ID, "target replacement records current target")
	_assert_eq(events[3].kind, EventKindScript.Value.PHASE_CHANGED, "resolving is typed phase event")
	_assert_eq(events[3].current_phase, LifecycleScript.Value.RESOLVING, "resolving phase carried structurally")
	_assert_eq(events[4].kind, EventKindScript.Value.ENCOUNTER_COMPLETED, "terminal event is final")
	_assert_true(events[4].result is CombatEncounterResult, "terminal event carries typed result")
	events.clear()
	_assert_eq(encounter.events().size(), 5, "returned event array cannot mutate encounter history")

	var failed: CombatEncounter = _encounter(
		_three_participants(),
		[_hostility(SIDE_A, SIDE_B)],
	)
	failed.fail_to_establish(
		ResultScript.new(
			ENCOUNTER_ID,
			EncounterModeScript.Value.LETHAL,
			ResultKindScript.Value.FAILED_TO_ESTABLISH,
		)
	)
	_assert_eq(failed.events().size(), 1, "failed establishment emits one terminal event")
	_assert_eq(failed.events()[0].sequence, 1, "failed sequence also begins deterministically at one")
	_assert_eq(failed.events()[0].kind, EventKindScript.Value.ENCOUNTER_FAILED_TO_ESTABLISH, "failed terminal event typed")


func _test_three_participant_model() -> void:
	var participants: Array[CombatParticipant] = _three_participants()
	var encounter: CombatEncounter = _encounter(
		participants,
		[_hostility(SIDE_A, SIDE_B), _hostility(SIDE_B, SIDE_A)],
	)
	_assert_true(encounter.is_valid(), "one-versus-multiple encounter construction succeeds")
	_assert_eq(encounter.participants().size(), 3, "three participants retained without 1v1 cap")
	_assert_eq(encounter.participants()[0].side_id, SIDE_A, "single side-A participant preserved")
	_assert_eq(encounter.participants()[1].side_id, SIDE_B, "first side-B participant preserved")
	_assert_eq(encounter.participants()[2].side_id, SIDE_B, "second side-B participant preserved")
	encounter.activate()
	_assert_true(encounter.set_current_target(ACTOR_ID, HOSTILE_TWO_ID), "actor can target second hostile independently")
	_assert_true(encounter.set_current_target(HOSTILE_ONE_ID, ACTOR_ID), "other participant has independent target")
	_assert_eq(encounter.target_assignments().size(), 2, "target collection is per actor, not global enemy field")
	_assert_eq(encounter.current_target_for(ACTOR_ID), HOSTILE_TWO_ID, "actor target remains independent")
	_assert_eq(encounter.current_target_for(HOSTILE_ONE_ID), ACTOR_ID, "hostile target remains independent")
	_assert_false(
		encounter.participant_for(HOSTILE_ONE_ID).binding.state
		== encounter.participant_for(HOSTILE_TWO_ID).binding.state,
		"independent participants do not share CharacterState",
	)


func _encounter(
	participants: Array[CombatParticipant],
	hostilities: Array[CombatDirectedHostility],
) -> CombatEncounter:
	return EncounterScript.new(
		ENCOUNTER_ID,
		_trigger_for(participants),
		participants,
		hostilities,
	)


func _trigger_for(participants: Array[CombatParticipant]) -> CombatTrigger:
	var candidates: Array[CombatTriggerCandidate] = []
	for participant: CombatParticipant in participants:
		if participant == null:
			continue
		if _candidate_index(candidates, participant.participant_id) < 0:
			candidates.append(
				TriggerCandidateScript.new(participant.participant_id, participant.side_id)
			)
	return TriggerScript.new(
		TRIGGER_ID,
		TriggerCauseScript.Value.PLAYER_LETHAL_ATTACK,
		EncounterModeScript.Value.LETHAL,
		ACTOR_ID,
		candidates,
		_location(),
	)


func _three_participants() -> Array[CombatParticipant]:
	return [
		_participant(ACTOR_ID, SIDE_A),
		_participant(HOSTILE_ONE_ID, SIDE_B),
		_participant(HOSTILE_TWO_ID, SIDE_B),
	]


func _participant(participant_id: StringName, side_id: StringName) -> CombatParticipant:
	var state: CharacterState = CharacterStateScript.new()
	var binding: CombatEncounterAuthorityBinding = BindingScript.new(
		participant_id,
		state,
		RelationshipScript.new(participant_id),
		BusyScript.new(),
		ArmorScript.new(),
	)
	return ParticipantScript.new(participant_id, side_id, binding)


func _hostility(from_side_id: StringName, to_side_id: StringName) -> CombatDirectedHostility:
	return HostilityScript.new(from_side_id, to_side_id)


func _location() -> WorldLocationState:
	return LocationScript.new(&"oldpine", &"outdoor", &"south-slope", &"oldpine-outdoor")


func _victory_result() -> CombatEncounterResult:
	return ResultScript.new(
		ENCOUNTER_ID,
		EncounterModeScript.Value.LETHAL,
		ResultKindScript.Value.VICTORY,
		[SIDE_A] as Array[StringName],
		[SIDE_B] as Array[StringName],
		[HOSTILE_ONE_ID, HOSTILE_TWO_ID] as Array[StringName],
	)


func _candidate_index(
	candidates: Array[CombatTriggerCandidate],
	participant_id: StringName,
) -> int:
	for index: int in range(candidates.size()):
		if candidates[index].participant_id == participant_id:
			return index
	return -1


func _assert_true(value: bool, message: String) -> void:
	_assertion_count += 1
	if not value:
		_failures.append(message)


func _assert_false(value: bool, message: String) -> void:
	_assert_true(not value, message)


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	_assertion_count += 1
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [message, expected, actual])
