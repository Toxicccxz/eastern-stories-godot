class_name HockshopValuationResult
extends RefCounted

## QUEST_ITEM: a native quest item (no_drop) the story still asks for; the pawnshop will not
## take it (DECISIONS「任务物品不丢」). ES2's own no_drop things sell as hockshop.c sells them.
enum Outcome { SELLABLE, WORTHLESS, MONEY_REJECTED, UNSUPPORTED_ITEM,
	INVALID_ITEM_STATE, NOT_DIRECTLY_HELD, ITEM_NOT_FOUND, AUTHORITY_FAILURE, QUEST_ITEM }

var outcome: Outcome = Outcome.AUTHORITY_FAILURE
var item_id: StringName
var definition_id: StringName
var source_value: int = 0
var actual_payout: int = 0
