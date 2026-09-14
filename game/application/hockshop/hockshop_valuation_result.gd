class_name HockshopValuationResult
extends RefCounted

enum Outcome { SELLABLE, WORTHLESS, MONEY_REJECTED, UNSUPPORTED_ITEM,
	INVALID_ITEM_STATE, NOT_DIRECTLY_HELD, ITEM_NOT_FOUND, AUTHORITY_FAILURE }

var outcome: Outcome = Outcome.AUTHORITY_FAILURE
var item_id: StringName
var definition_id: StringName
var source_value: int = 0
var actual_payout: int = 0
