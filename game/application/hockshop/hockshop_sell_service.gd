class_name HockshopSellService
extends RefCounted


## H2 application boundary only; H3 must supply physical permission separately.
## Never awaits, emits callbacks, retries or interleaves Save with mutations.
static func sell(context: MoneyInventoryContext, foods: FoodCollection,
	liquids: LiquidCollection, allocator: SessionItemIdAllocator,
	maximum_encumbrance: int, id: StringName) -> HockshopSellResult:
	var result: HockshopSellResult = HockshopSellResult.new()
	result.valuation = HockshopValuation.appraise(context, foods, liquids, id)
	if result.valuation.outcome != HockshopValuationResult.Outcome.SELLABLE:
		if result.valuation.outcome == HockshopValuationResult.Outcome.AUTHORITY_FAILURE:
			result.outcome = HockshopSellResult.Outcome.AUTHORITY_FAILURE
		return result
	result.outcome = HockshopSellResult.Outcome.AUTHORITY_FAILURE
	result.stage = HockshopSellResult.Stage.PAYOUT
	result.payout = HockshopPayoutService.pay(context, allocator, maximum_encumbrance, result.valuation.actual_payout)
	if result.payout.outcome != HockshopPayoutResult.Outcome.COMPLETE:
		return result
	result.stage = HockshopSellResult.Stage.ITEM_REMOVAL
	result.removal = ItemLifecycleService.destroy_item(context.inventory, context.stacks, id,
		ItemLifecycleResult.ChildDisposition.REQUIRE_LEAF, context.owner)
	if not result.removal.succeeded:
		return result
	result.stage = HockshopSellResult.Stage.FOOD_FORGET
	result.food_forgotten = foods.forget_removed(result.removal.removed_instance_ids, context.inventory)
	if not result.food_forgotten:
		return result
	result.stage = HockshopSellResult.Stage.LIQUID_FORGET
	result.liquid_forgotten = liquids.forget_removed(result.removal.removed_instance_ids, context.inventory)
	if not result.liquid_forgotten:
		return result
	result.stage = HockshopSellResult.Stage.INDEX_FORGET
	result.index_forgotten = context.index.forget_destroyed_snapshots(result.removal.removed_instance_ids, context.inventory)
	if not result.index_forgotten:
		return result
	result.stage = HockshopSellResult.Stage.COMPLETE
	result.outcome = HockshopSellResult.Outcome.SOLD
	return result
