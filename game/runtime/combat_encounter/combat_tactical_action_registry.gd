class_name CombatTacticalActionRegistry
extends RefCounted

## An explicit typed ID registry; not a callback-name or daemon dispatcher.
var _policies: Array[CombatTacticalActionPolicy] = []


func register_policy(policy: CombatTacticalActionPolicy) -> bool:
	if policy == null or not policy.is_valid() or find(policy.action_id) != null:
		return false
	_policies.append(policy)
	return true


func action_infos() -> Array[CombatTacticalActionInfo]:
	var result: Array[CombatTacticalActionInfo] = []
	for policy: CombatTacticalActionPolicy in _policies:
		if policy.is_valid():
			result.append(CombatTacticalActionInfo.new(
				policy.action_id, policy.category, policy.target_rule, policy.blocks_when_busy,
			))
	return result


func find(action_id: StringName) -> CombatTacticalActionPolicy:
	for policy: CombatTacticalActionPolicy in _policies:
		if policy.action_id == action_id:
			return policy
	return null
