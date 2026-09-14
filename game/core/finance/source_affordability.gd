class_name SourceAffordability
extends RefCounted

## feature/finance.c::can_afford, NOT an exact-change feasibility solver.
## All amounts are selected-stack values. Presence must not be inferred from >0.
static func evaluate(price: int, gold: int, silver: int, coin: int, silver_present: bool, coin_present: bool) -> MoneyAffordabilityResult.Outcome:
	if price < 1:
		return MoneyAffordabilityResult.Outcome.INVALID_PRICE
	var total: int = CurrencyArithmetic.add(CurrencyArithmetic.add(gold, silver), coin)
	if total < 0:
		return MoneyAffordabilityResult.Outcome.ARITHMETIC_FAILURE
	if total < price:
		return MoneyAffordabilityResult.Outcome.INSUFFICIENT_TOTAL
	if coin_present:
		if coin < price % 100:
			return MoneyAffordabilityResult.Outcome.DENOMINATION_REJECTED
	elif price % 100 != 0:
		return MoneyAffordabilityResult.Outcome.DENOMINATION_REJECTED
	if silver_present:
		if coin_present and silver + coin < price % 10000:
			return MoneyAffordabilityResult.Outcome.DENOMINATION_REJECTED
	elif price % 10000 != 0:
		return MoneyAffordabilityResult.Outcome.DENOMINATION_REJECTED
	return MoneyAffordabilityResult.Outcome.AFFORDABLE
