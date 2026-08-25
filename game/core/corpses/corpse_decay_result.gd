class_name CorpseDecayResult
extends RefCounted

const IntentType := preload(
	"res://core/corpses/corpse_decay_schedule_intent.gd"
)
const ScatterResultType := preload(
	"res://core/corpses/corpse_content_transfer_result.gd"
)
const LifecycleResultType := preload(
	"res://core/items/lifecycle/item_lifecycle_result.gd"
)

enum Outcome {
	TRANSITIONED,
	FINALIZED,
	INVALID_DOMAIN_STATE,
	INVALID_INTENT,
	DESTINATION_CONTEXT_REQUIRED,
	DESTINATION_MISMATCH,
	FINAL_DESTRUCTION_FAILED,
}

var _outcome: int
var _succeeded: bool
var _previous_stage: int
var _current_stage: int
var _next_intent: IntentType
var _scatter_results: Array[ScatterResultType] = []
var _lifecycle_result: LifecycleResultType

var outcome: int:
	get: return _outcome
var succeeded: bool:
	get: return _succeeded
var previous_stage: int:
	get: return _previous_stage
var current_stage: int:
	get: return _current_stage
var next_intent: IntentType:
	get: return _next_intent
var scatter_results: Array[ScatterResultType]:
	get: return _scatter_results.duplicate()
var lifecycle_result: LifecycleResultType:
	get: return _lifecycle_result


func _init(
	p_outcome: int = Outcome.INVALID_DOMAIN_STATE,
	p_succeeded: bool = false,
	p_previous_stage: int = 0,
	p_current_stage: int = 0,
	p_next_intent: IntentType = null,
	p_scatter_results: Array[ScatterResultType] = [],
	p_lifecycle_result: LifecycleResultType = null,
) -> void:
	_outcome = p_outcome
	_succeeded = p_succeeded
	_previous_stage = p_previous_stage
	_current_stage = p_current_stage
	_next_intent = p_next_intent
	_scatter_results = p_scatter_results.duplicate()
	_lifecycle_result = p_lifecycle_result
