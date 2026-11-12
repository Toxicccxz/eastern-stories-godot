class_name CarryRoom
extends RefCounted

## 先查再收钱 (native; DECISIONS「拿不动就不收钱」): before any money moves for something the
## player is to receive, whether they can carry it. ES2 takes the money first and lets the
## move fail (vendor.c, finance.c, the bank, work): the goods or coins are lost. These answer
## the question beforehand with the very sum InventoryTransferService.transfer() checks
## (contents_weight + the item's weight against the player's maximum_encumbrance).


## What a fresh `content` weighs as it comes (a combined item: create()'s amount).
static func fresh_weight(content: ItemContentDefinition) -> int:
	if content == null:
		return 0
	if content.is_stack:
		return CurrencyArithmetic.multiply(maxi(content.default_amount, 0), content.stack_base_weight)
	return content.own_weight


## The weight the player carries now.
static func carried(context: MoneyInventoryContext) -> int:
	return context.inventory.contents_weight(context.endpoint())


## The weight pay(`price`) would take off the player (it only takes coins, never gives
## change): what MoneyPaymentService.amounts_after() leaves, by each coin's base weight. 0 when
## the price would not be paid.
static func weight_paid(context: MoneyInventoryContext, price: int) -> int:
	var held: Array[int] = MoneyPaymentService.held_amounts(context)
	var after: Array[int] = MoneyPaymentService.amounts_after(held, price)
	if after.is_empty():
		return 0
	var paid: int = 0
	var denominations: Array[CurrencyDenomination.Value] = [CurrencyDenomination.Value.GOLD, CurrencyDenomination.Value.SILVER, CurrencyDenomination.Value.COIN]
	for i: int in 3:
		var content: ItemContentDefinition = GameContent.catalog().currency_item(denominations[i])
		if content != null:
			paid += (held[i] - after[i]) * content.stack_base_weight
	return paid


## Whether `weight` more fits once `price` is paid (0: nothing paid): within the limit after, or
## no heavier than before (one over the limit already may still trade coins for something lighter).
static func fits_after_paying(context: MoneyInventoryContext, price: int, weight: int, maximum_encumbrance: int) -> bool:
	var paid: int = weight_paid(context, price) if price > 0 else 0
	return fits_change(context, weight - paid, maximum_encumbrance)


## Whether the player may take `change` more weight (negative: lighter): within the limit after,
## or no heavier than before.
static func fits_change(context: MoneyInventoryContext, change: int, maximum_encumbrance: int) -> bool:
	return change <= 0 or carried(context) + change <= maximum_encumbrance
