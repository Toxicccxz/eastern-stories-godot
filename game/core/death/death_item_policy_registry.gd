class_name DeathItemPolicyRegistry
extends RefCounted

const PolicyType := preload("res://core/death/death_item_policy.gd")
const ResultType := preload("res://core/death/death_item_policy_result.gd")
const ContextType := preload("res://core/death/death_context.gd")
const FactsType := preload("res://core/death/death_item_facts.gd")

var _policies: Dictionary[StringName, PolicyType] = {}


func register_policy(
	item_definition_id: StringName,
	policy: PolicyType,
) -> bool:
	if item_definition_id == &"" or policy == null or _policies.has(item_definition_id):
		return false
	_policies[item_definition_id] = policy
	return true


func evaluate(context: ContextType, item: FactsType) -> ResultType:
	var policy: PolicyType = _policies.get(item.item_definition_id)
	if policy == null:
		return ResultType.new(ResultType.Outcome.KEEP, item.item_instance_id)
	return policy.evaluate(context, item)


func registered_definition_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	result.assign(_policies.keys())
	result.sort_custom(_string_name_less_than)
	return result


func _string_name_less_than(left: StringName, right: StringName) -> bool:
	return String(left) < String(right)
