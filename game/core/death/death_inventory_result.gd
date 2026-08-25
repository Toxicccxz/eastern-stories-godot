class_name DeathInventoryResult
extends RefCounted

const PolicyResultType := preload(
	"res://core/death/death_item_policy_result.gd"
)
const TransferResultType := preload(
	"res://core/inventory/inventory_transfer_result.gd"
)
const RewearResultType := preload("res://core/death/death_rewear_result.gd")
const SpawnIntentType := preload(
	"res://core/death/deferred_npc_spawn_intent.gd"
)
const CorpseStateType := preload("res://core/corpses/corpse_state.gd")
const DecayIntentType := preload(
	"res://core/corpses/corpse_decay_schedule_intent.gd"
)
const LifecycleResultType := preload(
	"res://core/items/lifecycle/item_lifecycle_result.gd"
)

enum Branch {
	UNKNOWN,
	GHOST,
	NORMAL,
	WIZARD,
}

enum Outcome {
	COMPLETED,
	INVALID_DOMAIN_STATE,
	INVALID_CONTEXT,
	INVALID_ITEM_FACTS,
	INVALID_CORPSE_IDENTITY,
	CORPSE_REGISTRATION_FAILED,
	POLICY_DESTRUCTION_FAILED,
	DEFERRED_RUNTIME_EFFECT,
	POLICY_DEPENDENCY_UNAVAILABLE,
	REWEAR_DEPENDENCY_UNAVAILABLE,
}

enum CompletionStatus {
	COMPLETED,
	REJECTED_BEFORE_PROCESSING,
	BLOCKED_INCOMPLETE,
}

enum RestartDisposition {
	NOT_APPLICABLE,
	SAFE_AFTER_INPUT_CORRECTION,
	DO_NOT_RESTART_FROM_BEGINNING,
}

var _outcome: int
var _branch: int
var _direct_snapshot_ids: Array[StringName] = []
var _policy_results: Array[PolicyResultType] = []
var _destroyed_instance_ids: Array[StringName] = []
var _survivor_transfer_results: Array[TransferResultType] = []
var _rewear_results: Array[RewearResultType] = []
var _deferred_effects: Array[SpawnIntentType] = []
var _corpse_item_instance_id: StringName
var _corpse_state: CorpseStateType
var _corpse_placement_result: TransferResultType
var _initial_decay_intent: DecayIntentType
var _stopped_item_instance_id: StringName
var _policy_lifecycle_results: Array[LifecycleResultType] = []

var outcome: int:
	get: return _outcome
var branch: int:
	get: return _branch
var direct_snapshot_ids: Array[StringName]:
	get: return _direct_snapshot_ids.duplicate()
var policy_results: Array[PolicyResultType]:
	get: return _policy_results.duplicate()
var destroyed_instance_ids: Array[StringName]:
	get: return _destroyed_instance_ids.duplicate()
var survivor_transfer_results: Array[TransferResultType]:
	get: return _survivor_transfer_results.duplicate()
var rewear_results: Array[RewearResultType]:
	get: return _rewear_results.duplicate()
var deferred_effects: Array[SpawnIntentType]:
	get: return _deferred_effects.duplicate()
var corpse_item_instance_id: StringName:
	get: return _corpse_item_instance_id
var corpse_state: CorpseStateType:
	get: return _corpse_state
var corpse_placement_result: TransferResultType:
	get: return _corpse_placement_result
var initial_decay_intent: DecayIntentType:
	get: return _initial_decay_intent
var stopped_item_instance_id: StringName:
	get: return _stopped_item_instance_id
var policy_lifecycle_results: Array[LifecycleResultType]:
	get: return _policy_lifecycle_results.duplicate()
var completion_status: int:
	get:
		if _outcome == Outcome.COMPLETED:
			return CompletionStatus.COMPLETED
		if (
			_corpse_state != null
			or _outcome == Outcome.POLICY_DESTRUCTION_FAILED
			or _outcome == Outcome.DEFERRED_RUNTIME_EFFECT
			or _outcome == Outcome.POLICY_DEPENDENCY_UNAVAILABLE
			or _outcome == Outcome.REWEAR_DEPENDENCY_UNAVAILABLE
		):
			return CompletionStatus.BLOCKED_INCOMPLETE
		return CompletionStatus.REJECTED_BEFORE_PROCESSING
var restart_disposition: int:
	get:
		if completion_status == CompletionStatus.COMPLETED:
			return RestartDisposition.NOT_APPLICABLE
		if completion_status == CompletionStatus.BLOCKED_INCOMPLETE:
			return RestartDisposition.DO_NOT_RESTART_FROM_BEGINNING
		return RestartDisposition.SAFE_AFTER_INPUT_CORRECTION


func _init(
	p_outcome: int = Outcome.INVALID_DOMAIN_STATE,
	p_branch: int = Branch.UNKNOWN,
	p_direct_snapshot_ids: Array[StringName] = [],
	p_policy_results: Array[PolicyResultType] = [],
	p_destroyed_instance_ids: Array[StringName] = [],
	p_survivor_transfer_results: Array[TransferResultType] = [],
	p_rewear_results: Array[RewearResultType] = [],
	p_deferred_effects: Array[SpawnIntentType] = [],
	p_corpse_item_instance_id: StringName = &"",
	p_corpse_state: CorpseStateType = null,
	p_corpse_placement_result: TransferResultType = null,
	p_initial_decay_intent: DecayIntentType = null,
	p_stopped_item_instance_id: StringName = &"",
	p_policy_lifecycle_results: Array[LifecycleResultType] = [],
) -> void:
	_outcome = p_outcome
	_branch = p_branch
	_direct_snapshot_ids = p_direct_snapshot_ids.duplicate()
	_policy_results = p_policy_results.duplicate()
	_destroyed_instance_ids = p_destroyed_instance_ids.duplicate()
	_survivor_transfer_results = p_survivor_transfer_results.duplicate()
	_rewear_results = p_rewear_results.duplicate()
	_deferred_effects = p_deferred_effects.duplicate()
	_corpse_item_instance_id = p_corpse_item_instance_id
	_corpse_state = p_corpse_state
	_corpse_placement_result = p_corpse_placement_result
	_initial_decay_intent = p_initial_decay_intent
	_stopped_item_instance_id = p_stopped_item_instance_id
	_policy_lifecycle_results = p_policy_lifecycle_results.duplicate()
