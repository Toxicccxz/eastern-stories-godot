class_name SnowWorkResult
extends RefCounted

enum Outcome { SUCCESS, TOO_TIRED, INTERACTION_BLOCKED, INVALID_AUTHORITY, ALLOCATION_FAILED, DELIVERY_FAILED_CAPACITY, AUTHORITY_FAILURE }

var outcome: Outcome = Outcome.INVALID_AUTHORITY
var costs_applied: bool = false
var reward_id: StringName = &""
var allocation: SessionItemIdAllocationResult
var transfer: CombinedStackMergeResult
var cleanup: ItemLifecycleResult


func succeeded() -> bool:
	return outcome == Outcome.SUCCESS
