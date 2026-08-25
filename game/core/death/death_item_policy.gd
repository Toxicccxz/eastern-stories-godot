class_name DeathItemPolicy
extends RefCounted

const ContextType := preload("res://core/death/death_context.gd")
const FactsType := preload("res://core/death/death_item_facts.gd")
const ResultType := preload("res://core/death/death_item_policy_result.gd")


func evaluate(_context: ContextType, item: FactsType) -> ResultType:
	return ResultType.new(ResultType.Outcome.KEEP, item.item_instance_id)
