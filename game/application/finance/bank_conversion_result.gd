class_name BankConversionResult
extends RefCounted

enum Outcome { SUCCESS, UNSUPPORTED_TARGET, UNSUPPORTED_SOURCE, SOURCE_MISSING, INVALID_QUANTITY, INSUFFICIENT_SOURCE, ROUNDED_TO_ZERO, ARITHMETIC_FAILURE, ALLOCATION_FAILED, CREATION_FAILED, DELIVERY_FAILED, AUTHORITY_FAILURE }
enum Stage { VALIDATION, ALLOCATION, CREATION, TRANSFER, TARGET_AMOUNT, SOURCE_AMOUNT, CLEANUP, COMPLETE }
var outcome: Outcome = Outcome.AUTHORITY_FAILURE
var stage: Stage = Stage.VALIDATION
var source_id: StringName = &""
var target_id: StringName = &""
var source_quantity: int = 0
var target_quantity: int = 0
var allocation: SessionItemIdAllocationResult
var creation: CombinedStackAmountResult
var transfer: CombinedStackMergeResult
var target_change: MoneyMutationResult
var source_change: MoneyMutationResult
var cleanup: MoneyMutationResult


func succeeded() -> bool:
	return outcome == Outcome.SUCCESS
