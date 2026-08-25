class_name LegacyAutoloadImportResult
extends RefCounted

const EntryResultType := preload(
	"res://core/persistence/legacy_autoload/legacy_autoload_entry_result.gd"
)
const BandageStateType := preload(
	"res://core/persistence/legacy_autoload/legacy_bandage_state_import.gd"
)
const MarryStateType := preload(
	"res://core/persistence/legacy_autoload/legacy_marry_card_state_import.gd"
)
const MarryIntentType := preload(
	"res://core/persistence/legacy_autoload/legacy_marry_card_runtime_intent.gd"
)
const StackIntentType := preload(
	"res://core/persistence/legacy_autoload/legacy_stack_destruction_intent.gd"
)
const SnapshotType := preload(
	"res://core/persistence/native_item_state_snapshot.gd"
)
const ValidationResultType := preload(
	"res://core/persistence/native_item_state_validation_result.gd"
)

enum Outcome {
	COMPLETE,
	INCOMPLETE_UNSUPPORTED,
	INVALID_INPUT,
}

var _outcome: int
var _original_entry_count: int
var _entry_results: Array[EntryResultType] = []
var _snapshot_candidate: SnapshotType
var _bandage_states: Array[BandageStateType] = []
var _marry_card_states: Array[MarryStateType] = []
var _marry_card_runtime_intents: Array[MarryIntentType] = []
var _stack_destruction_intents: Array[StackIntentType] = []
var _validation_result: ValidationResultType

var outcome: int:
	get: return _outcome
var original_entry_count: int:
	get: return _original_entry_count
var entry_results: Array[EntryResultType]:
	get: return _entry_results.duplicate()
var snapshot_candidate: SnapshotType:
	get:
		return (
			null
			if _snapshot_candidate == null
			else _snapshot_candidate.duplicate_snapshot()
		)
var bandage_states: Array[BandageStateType]:
	get: return _duplicate_bandage_states()
var marry_card_states: Array[MarryStateType]:
	get: return _duplicate_marry_states()
var marry_card_runtime_intents: Array[MarryIntentType]:
	get: return _duplicate_marry_intents()
var stack_destruction_intents: Array[StackIntentType]:
	get: return _duplicate_stack_intents()
var validation_result: ValidationResultType:
	get:
		return (
			null
			if _validation_result == null
			else ValidationResultType.new(
				_validation_result.outcome,
				_validation_result.subject_id,
				_validation_result.related_id,
			)
		)


func _init(
	p_outcome: int = Outcome.INVALID_INPUT,
	p_original_entry_count: int = 0,
	p_entry_results: Array[EntryResultType] = [],
	p_snapshot_candidate: SnapshotType = null,
	p_bandage_states: Array[BandageStateType] = [],
	p_marry_card_states: Array[MarryStateType] = [],
	p_marry_card_runtime_intents: Array[MarryIntentType] = [],
	p_stack_destruction_intents: Array[StackIntentType] = [],
	p_validation_result: ValidationResultType = null,
) -> void:
	_outcome = p_outcome
	_original_entry_count = p_original_entry_count
	_entry_results = p_entry_results.duplicate()
	_snapshot_candidate = (
		null
		if p_snapshot_candidate == null
		else p_snapshot_candidate.duplicate_snapshot()
	)
	for state: BandageStateType in p_bandage_states:
		_bandage_states.append(state.duplicate_snapshot())
	for state: MarryStateType in p_marry_card_states:
		_marry_card_states.append(state.duplicate_snapshot())
	for intent: MarryIntentType in p_marry_card_runtime_intents:
		_marry_card_runtime_intents.append(intent.duplicate_snapshot())
	for intent: StackIntentType in p_stack_destruction_intents:
		_stack_destruction_intents.append(intent.duplicate_snapshot())
	_validation_result = (
		null
		if p_validation_result == null
		else ValidationResultType.new(
			p_validation_result.outcome,
			p_validation_result.subject_id,
			p_validation_result.related_id,
		)
	)


func _duplicate_bandage_states() -> Array[BandageStateType]:
	var result: Array[BandageStateType] = []
	for state: BandageStateType in _bandage_states:
		result.append(state.duplicate_snapshot())
	return result


func _duplicate_marry_states() -> Array[MarryStateType]:
	var result: Array[MarryStateType] = []
	for state: MarryStateType in _marry_card_states:
		result.append(state.duplicate_snapshot())
	return result


func _duplicate_marry_intents() -> Array[MarryIntentType]:
	var result: Array[MarryIntentType] = []
	for intent: MarryIntentType in _marry_card_runtime_intents:
		result.append(intent.duplicate_snapshot())
	return result


func _duplicate_stack_intents() -> Array[StackIntentType]:
	var result: Array[StackIntentType] = []
	for intent: StackIntentType in _stack_destruction_intents:
		result.append(intent.duplicate_snapshot())
	return result
