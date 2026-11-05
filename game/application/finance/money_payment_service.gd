class_name MoneyPaymentService
extends RefCounted


static func can_afford(context: MoneyInventoryContext, price: int) -> MoneyAffordabilityResult:
	var result: MoneyAffordabilityResult = MoneyAffordabilityResult.new()
	if price < 1:
		result.outcome = MoneyAffordabilityResult.Outcome.INVALID_PRICE
		return result
	if context == null or not context.is_valid():
		return result
	var selections: Array[CurrencyStackSelection] = _select(context)
	for selection: CurrencyStackSelection in selections:
		if selection.outcome == CurrencyStackSelection.Outcome.AUTHORITY_FAILURE:
			return result
	result.gold_id = selections[0].item_id
	result.silver_id = selections[1].item_id
	result.coin_id = selections[2].item_id
	var units: Array[int] = _unit_values()
	result.outcome = SourceAffordability.evaluate(price,
		CurrencyArithmetic.multiply(selections[0].amount, units[0]),
		CurrencyArithmetic.multiply(selections[1].amount, units[1]),
		selections[2].amount, not result.silver_id.is_empty(), not result.coin_id.is_empty())
	return result


## Independent low-level pay_money: does not invoke can_afford, know goods or mint change.
@warning_ignore("integer_division")
static func pay(context: MoneyInventoryContext, price: int) -> MoneyPaymentResult:
	var result: MoneyPaymentResult = MoneyPaymentResult.new()
	result.remaining_price = price
	if price < 1:
		result.outcome = MoneyPaymentResult.Outcome.INVALID_PRICE
		return result
	if context == null or not context.is_valid():
		return result
	var selections: Array[CurrencyStackSelection] = _select(context)
	var units: Array[int] = _unit_values()
	var values: Array[int] = []
	var total: int = 0
	result.stage = MoneyPaymentResult.Stage.TOTAL
	for i: int in range(3):
		var selection: CurrencyStackSelection = selections[i]
		if selection.outcome == CurrencyStackSelection.Outcome.AUTHORITY_FAILURE:
			return result
		result.selected_ids.append(selection.item_id)
		var value: int = CurrencyArithmetic.multiply(selection.amount, units[i])
		values.append(value)
		total = CurrencyArithmetic.add(total, value)
		if total < 0:
			result.outcome = MoneyPaymentResult.Outcome.ARITHMETIC_FAILURE
			return result
	if total < price:
		result.outcome = MoneyPaymentResult.Outcome.INSUFFICIENT_TOTAL
		return result
	for i: int in range(3):
		var selection: CurrencyStackSelection = selections[i]
		if selection.item_id.is_empty() or result.remaining_price < units[i]:
			continue
		result.stage = [MoneyPaymentResult.Stage.GOLD, MoneyPaymentResult.Stage.SILVER, MoneyPaymentResult.Stage.COIN][i]
		var after: int = 0
		var next_remaining: int = result.remaining_price
		if values[i] >= result.remaining_price:
			after = selection.amount - result.remaining_price / units[i]
			next_remaining %= units[i]
		elif i == 2:
			result.outcome = MoneyPaymentResult.Outcome.CANNOT_COMPLETE
			return result
		else:
			next_remaining -= values[i]
		# In the LPC full-value else branch residual changes before set_amount;
		# in the sufficient-value branch modulo is after successful amount change.
		if values[i] < result.remaining_price:
			result.remaining_price = next_remaining
		var mutation: MoneyMutationResult = context.set_amount(selection.item_id, after)
		result.mutations.append(mutation)
		if not mutation.succeeded():
			result.outcome = MoneyPaymentResult.Outcome.ARITHMETIC_FAILURE if mutation.outcome == MoneyMutationResult.Outcome.ARITHMETIC_FAILURE else MoneyPaymentResult.Outcome.AUTHORITY_FAILURE
			return result
		result.remaining_price = next_remaining
	result.stage = MoneyPaymentResult.Stage.FINAL
	result.outcome = MoneyPaymentResult.Outcome.SUCCESS if result.remaining_price == 0 else MoneyPaymentResult.Outcome.CANNOT_COMPLETE
	return result


## Native (车马行; DECISIONS「车马行」): pays `price` with pay(), first changing a larger coin
## into a hundred of the next (BankConversionService, as the 钱庄 would) while the coins carried
## would not come out even: one who takes a fare makes change. Not can_afford(): finance.c says
## 「找不开」 to a purse of coins alone, however many. False when the money is not there; nothing
## is taken then. A change the purse cannot carry (`maximum_encumbrance`) costs the coin changed
## (BankConversionService): give a limit the change always fits under.
static func pay_making_change(context: MoneyInventoryContext, allocator: SessionItemIdAllocator, maximum_encumbrance: int, price: int) -> bool:
	if price < 1 or context == null or not context.is_valid():
		return false
	var units: Array[int] = _unit_values()
	# A coin changed each pass, the smaller first: a few passes at most for any fare.
	for _change: int in CHANGE_PASSES:
		var held: Array[int] = _held(context)
		if held.is_empty() or held[0] * units[0] + held[1] * units[1] + held[2] < price:
			return false
		if _comes_out_even(held, units, price):
			return pay(context, price).succeeded()
		var from: CurrencyDenomination.Value = CurrencyDenomination.Value.SILVER if held[1] > 0 else CurrencyDenomination.Value.GOLD
		var to: CurrencyDenomination.Value = CurrencyDenomination.Value.COIN if held[1] > 0 else CurrencyDenomination.Value.SILVER
		if not BankConversionService.convert(context, allocator, maximum_encumbrance, from, to, 1).succeeded():
			return false
	return false


## Changes a pay_making_change() makes at most before it gives up.
const CHANGE_PASSES: int = 8


## The gold, silver and coins carried (one stack each, as pay() takes them); empty when a stack
## cannot be read.
static func _held(context: MoneyInventoryContext) -> Array[int]:
	var held: Array[int] = []
	for selection: CurrencyStackSelection in _select(context):
		if selection.outcome == CurrencyStackSelection.Outcome.AUTHORITY_FAILURE:
			return []
		held.append(selection.amount if selection.outcome == CurrencyStackSelection.Outcome.FOUND else 0)
	return held


## Whether pay() comes out even with `held`: what the gold and the silver leave, the coins cover.
static func _comes_out_even(held: Array[int], units: Array[int], price: int) -> bool:
	var remaining: int = price
	for i: int in 2:
		if held[i] <= 0 or units[i] <= 0 or remaining < units[i]:
			continue
		var value: int = held[i] * units[i]
		remaining = remaining % units[i] if value >= remaining else remaining - value
	return held[2] >= remaining


static func _select(context: MoneyInventoryContext) -> Array[CurrencyStackSelection]:
	return [context.select(CurrencyDenomination.Value.GOLD), context.select(CurrencyDenomination.Value.SILVER), context.select(CurrencyDenomination.Value.COIN)]


## Gold, silver, coin base values. A missing denomination already fails its
## selection, so the placeholder 0 is never used in arithmetic.
static func _unit_values() -> Array[int]:
	var units: Array[int] = []
	for denomination: CurrencyDenomination.Value in [CurrencyDenomination.Value.GOLD, CurrencyDenomination.Value.SILVER, CurrencyDenomination.Value.COIN]:
		var content: ItemContentDefinition = GameContent.catalog().currency_item(denomination)
		units.append(0 if content == null else content.currency_base_value)
	return units
