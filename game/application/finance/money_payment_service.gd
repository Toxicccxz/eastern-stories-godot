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
	result.outcome = SourceAffordability.evaluate(price,
		CurrencyArithmetic.multiply(selections[0].amount, SourceGold.BASE_VALUE),
		CurrencyArithmetic.multiply(selections[1].amount, SourceSilver.BASE_VALUE),
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
	var units: Array[int] = [SourceGold.BASE_VALUE, SourceSilver.BASE_VALUE, SourceCoin.BASE_VALUE]
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


static func _select(context: MoneyInventoryContext) -> Array[CurrencyStackSelection]:
	return [context.select(CurrencyDenomination.Value.GOLD), context.select(CurrencyDenomination.Value.SILVER), context.select(CurrencyDenomination.Value.COIN)]
