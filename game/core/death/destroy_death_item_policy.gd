class_name DestroyDeathItemPolicy
extends "res://core/death/death_item_policy.gd"

func evaluate(_context: ContextType, item: FactsType) -> ResultType:
	return ResultType.new(ResultType.Outcome.DESTROY_ITEM, item.item_instance_id)
