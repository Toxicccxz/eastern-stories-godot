class_name HockshopPayoutAttempt
extends RefCounted

enum Stage { ALLOCATION, CREATION, ADMISSION, CLEANUP, COMPLETE }
var stage: Stage = Stage.ALLOCATION
var denomination: CurrencyDenomination.Value
var quantity: int = 0
var item_id: StringName
var allocation: SessionItemIdAllocationResult
var creation: CombinedStackAmountResult
var transfer: CombinedStackMergeResult
var cleanup: MoneyMutationResult
var delivered: bool = false
var capacity_rejected: bool = false
var absorbed_index_forgotten: bool = false
