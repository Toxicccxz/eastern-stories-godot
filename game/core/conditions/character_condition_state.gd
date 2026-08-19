class_name CharacterConditionState
extends RefCounted

const ConditionPayloadType := preload("res://core/conditions/condition_payload.gd")
const DurationConditionPayloadType := preload(
	"res://core/conditions/duration_condition_payload.gd"
)

## The dictionary is constrained to stable StringName IDs and typed payloads;
## callers cannot access the collection itself or use LPC-style property paths.
var _conditions: Dictionary[StringName, ConditionPayloadType] = {}


## Equivalent to apply_condition(): applying an existing ID replaces its whole
## payload rather than merging or accumulating it.
func add_or_replace(condition_id: StringName, payload: ConditionPayloadType) -> void:
	_conditions[condition_id] = payload


func add_or_replace_duration(condition_id: StringName, remaining: int) -> void:
	add_or_replace(condition_id, DurationConditionPayloadType.new(remaining))


func get_condition(condition_id: StringName) -> ConditionPayloadType:
	return _conditions.get(condition_id) as ConditionPayloadType


func has_condition(condition_id: StringName) -> bool:
	return _conditions.has(condition_id)


func remove_condition(condition_id: StringName) -> bool:
	return _conditions.erase(condition_id)


func clear() -> void:
	_conditions.clear()


func size() -> int:
	return _conditions.size()


## feature/condition.c snapshots keys before updating. LPC mapping key order is
## not contractual, so the native domain uses stable ascending IDs.
func sorted_condition_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for condition_id: StringName in _conditions:
		ids.append(condition_id)
	ids.sort_custom(_condition_id_before)
	return ids


static func _condition_id_before(left: StringName, right: StringName) -> bool:
	return String(left) < String(right)
