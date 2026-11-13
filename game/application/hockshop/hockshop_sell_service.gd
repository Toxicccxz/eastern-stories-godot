class_name HockshopSellService
extends RefCounted


## H2 application boundary only; H3 must supply physical permission separately.
## Never awaits, emits callbacks, retries or interleaves Save with mutations.
## Deviation (DECISIONS「拿不动就不收钱」): hockshop.c pays first and loses what the seller cannot
## carry, the item gone all the same. A sale whose money would not fit once the item has left
## the player is refused before anything moves (TOO_HEAVY); one that fits is paid in full (the
## payout's move may count the item still held, which leaves right after).
static func sell(context: MoneyInventoryContext, foods: FoodCollection,
	liquids: LiquidCollection, allocator: SessionItemIdAllocator,
	maximum_encumbrance: int, id: StringName) -> HockshopSellResult:
	var result: HockshopSellResult = HockshopSellResult.new()
	result.valuation = HockshopValuation.appraise(context, foods, liquids, id)
	if result.valuation.outcome != HockshopValuationResult.Outcome.SELLABLE:
		if result.valuation.outcome == HockshopValuationResult.Outcome.AUTHORITY_FAILURE:
			result.outcome = HockshopSellResult.Outcome.AUTHORITY_FAILURE
		return result
	var leaving: int = context.inventory.subtree_weight(id)
	var coming: int = HockshopPayoutService.payout_weight(result.valuation.actual_payout)
	if leaving < 0 or coming < 0:
		result.outcome = HockshopSellResult.Outcome.AUTHORITY_FAILURE
		return result
	if not CarryRoom.fits_change(context, coming - leaving, maximum_encumbrance):
		result.outcome = HockshopSellResult.Outcome.TOO_HEAVY
		return result
	result.outcome = HockshopSellResult.Outcome.AUTHORITY_FAILURE
	result.stage = HockshopSellResult.Stage.PAYOUT
	result.payout = HockshopPayoutService.pay(context, allocator, maxi(maximum_encumbrance, CarryRoom.carried(context)) + leaving + coming, result.valuation.actual_payout)
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
