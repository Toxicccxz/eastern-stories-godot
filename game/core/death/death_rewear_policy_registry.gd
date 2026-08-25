class_name DeathRewearPolicyRegistry
extends RefCounted

enum Policy {
	GENERIC_BASE_WEAR,
	BANDAGE_ALWAYS_FAILS,
	LATEMOON_SKIRT,
}

var _policies: Dictionary[StringName, int] = {}


func register_bandage(item_definition_id: StringName) -> bool:
	return _register(item_definition_id, Policy.BANDAGE_ALWAYS_FAILS)


func register_latemoon_skirt(item_definition_id: StringName) -> bool:
	return _register(item_definition_id, Policy.LATEMOON_SKIRT)


func policy_for(item_definition_id: StringName) -> int:
	return int(_policies.get(item_definition_id, Policy.GENERIC_BASE_WEAR))


func registered_definition_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	result.assign(_policies.keys())
	result.sort_custom(_string_name_less_than)
	return result


func _register(item_definition_id: StringName, policy: int) -> bool:
	if item_definition_id == &"" or _policies.has(item_definition_id):
		return false
	_policies[item_definition_id] = policy
	return true


func _string_name_less_than(left: StringName, right: StringName) -> bool:
	return String(left) < String(right)
