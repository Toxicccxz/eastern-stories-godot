class_name MoneyMutationResult
extends RefCounted

enum Outcome { SUCCESS, ARITHMETIC_FAILURE, AUTHORITY_FAILURE }
var outcome: Outcome = Outcome.AUTHORITY_FAILURE
var item_id: StringName = &""
var requested_amount: int = 0
var amount_change: CombinedStackAmountResult
var removal: ItemLifecycleResult
var index_forgotten: bool = false


func succeeded() -> bool:
	return outcome == Outcome.SUCCESS
