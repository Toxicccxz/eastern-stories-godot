class_name DumplingPurchaseResult
extends RefCounted

enum Outcome { SUCCESS, INTERACTION_BLOCKED, INVALID_OFFER, AFFORDABILITY_REJECTED, PAYMENT_FAILED, ALLOCATION_FAILED, CREATION_FAILED, DELIVERY_FAILED, AUTHORITY_FAILURE }
enum Stage { OFFER, AFFORDABILITY, PAYMENT, ALLOCATION, CREATION, DELIVERY, CLEANUP, COMPLETE }
var outcome: Outcome = Outcome.AUTHORITY_FAILURE
var stage: Stage = Stage.OFFER
var price: int = 0
var paid: bool = false
var delivered: bool = false
var item_id: StringName = &""
var affordability: MoneyAffordabilityResult
var payment: MoneyPaymentResult
var allocation: SessionItemIdAllocationResult
var transfer: InventoryTransferResult
var cleanup: FoodItemRemovalResult
