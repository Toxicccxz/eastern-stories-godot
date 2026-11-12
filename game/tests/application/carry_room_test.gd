extends RefCounted

## DECISIONS「拿不动就不收钱」: before money moves, whether the player can carry what they get
## (CarryRoom). The answer uses pay()'s own arithmetic; a refusal moves nothing; a purchase or an
## exchange with room behaves as before; the ledgers stay whole (no coin lost, no item ownerless).

const Finance := preload("res://tests/runtime/snow_finance_test.gd")
const Dumpling := preload("res://tests/runtime/snow_dumpling_test.gd")
const COIN = CurrencyDenomination.Value.COIN
const SILVER = CurrencyDenomination.Value.SILVER
const GOLD = CurrencyDenomination.Value.GOLD

var assertions: int = 0
var failures: Array[String] = []


func run_all(_tree: SceneTree) -> Dictionary[String, Variant]:
	_amounts_after_matches_pay()
	_weight_paid()
	_fits_change()
	_purchase_ledger()
	_exchange_ledger()
	return {"assertions": assertions, "failures": failures}


## amounts_after() is pay()'s arithmetic: what pay() leaves when it completes, empty when not.
func _amounts_after_matches_pay() -> void:
	var mismatches: Array[String] = []
	for gold: int in [0, 1, 2]:
		for silver: int in [0, 1, 3, 150]:
			for coin: int in [0, 1, 37, 99, 250]:
				for price: int in [1, 15, 99, 100, 101, 250, 9999, 10000, 10037, 20350]:
					var f: Finance.Fixture = Finance.amounts(gold, silver, coin)
					var planned: Array[int] = MoneyPaymentService.amounts_after(MoneyPaymentService.held_amounts(f.context), price)
					var paid: MoneyPaymentResult = MoneyPaymentService.pay(f.context, price)
					var after: Array[int] = [Finance.amount(f.context, GOLD), Finance.amount(f.context, SILVER), Finance.amount(f.context, COIN)]
					if paid.succeeded() != not planned.is_empty() or (paid.succeeded() and planned != after):
						mismatches.append("%s pays %d: planned %s, pay %s %s" % [[gold, silver, coin], price, planned, paid.outcome, after])
	check(mismatches.is_empty(), "amounts_after() is pay()'s arithmetic: " + str(mismatches.slice(0, 5)))


## The weight pay() takes off: coins 1 each, silver and gold 37.
func _weight_paid() -> void:
	var f: Finance.Fixture = Finance.amounts(0, 1, 100)
	check(CarryRoom.weight_paid(f.context, 15) == 15, "15 文 from 100 coins: 15")
	check(CarryRoom.weight_paid(f.context, 150) == 37 + 50, "a silver and 50 coins: 87")
	check(CarryRoom.weight_paid(f.context, 1000) == 0, "not affordable: nothing paid")
	check(Finance.amount(f.context, COIN) == 100 and Finance.amount(f.context, SILVER) == 1, "asking moves nothing")


## Within the limit after, or no heavier than before.
func _fits_change() -> void:
	var f: Finance.Fixture = Finance.amounts(0, 0, 100)
	Finance.ballast(f.context, 900)
	check(CarryRoom.fits_change(f.context, 0, 1000) and not CarryRoom.fits_change(f.context, 1, 1000), "at the limit: nothing more")
	check(CarryRoom.fits_change(f.context, -50, 900), "over the limit already: lighter still allowed")
	check(not CarryRoom.fits_change(f.context, 10, 900), "over the limit already: heavier refused")
	check(CarryRoom.fits_after_paying(f.context, 15, 15, 1000) and not CarryRoom.fits_after_paying(f.context, 15, 16, 1000), "what is paid makes room")


## A purchase: refused at the limit with nothing moved; with room, the price taken once and the
## goods in the player's hands; the items registered are exactly the player's and the index's.
func _purchase_ledger() -> void:
	for room: int in [0, 1000]:
		var f: Finance.Fixture = Finance.amounts(0, 1, 100)
		Finance.ballast(f.context, 2000)
		var foods: FoodCollection = FoodCollection.new()
		var before_ids: Array[StringName] = f.context.inventory.registered_item_ids()
		var carried: int = CarryRoom.carried(f.context)
		var result: VendorPurchaseResult = Dumpling.buy_dumpling(f.context, foods, f.allocator, carried - 15 + 80 - 1 + room)
		if room == 0:
			check(result.outcome == VendorPurchaseResult.Outcome.TOO_HEAVY and not result.paid and not result.delivered, "a purchase that would not fit is refused")
			check(Finance.amount(f.context, COIN) == 100 and Finance.amount(f.context, SILVER) == 1 and f.context.inventory.registered_item_ids() == before_ids, "refused: no coin taken, nothing made")
			check(f.allocator.next_dynamic_sequence == 1 and foods.instance_ids().is_empty(), "refused: no ID, no food state")
		else:
			check(result.delivered and Finance.amount(f.context, COIN) == 85, "with room: 15 paid, delivered")
			check(f.context.inventory.is_direct_child(result.item_id, f.context.endpoint()) and f.context.inventory.registered_item_ids().size() == before_ids.size() + 1, "with room: one new thing, in the player's hands")
		check(f.context.index.snapshot_ids() == f.context.inventory.registered_item_ids(), "index and inventory agree")
		for id: StringName in f.context.inventory.registered_item_ids():
			check(f.context.inventory.direct_parent(id) != null, "no item without an owner: " + String(id))


## An exchange: refused when it would end over the limit and heavier; the value held unchanged
## either way (bank.c's rounding aside: the amounts here change evenly).
func _exchange_ledger() -> void:
	for limit: int in [1062 - 1, 1062]:
		var f: Finance.Fixture = Finance.amounts(0, 2, 0)
		Finance.ballast(f.context, 925)
		var value_before: int = _value(f.context)
		var result: BankConversionResult = BankConversionService.convert(f.context, f.allocator, limit, SILVER, COIN, 1)
		check(result.outcome == (BankConversionResult.Outcome.SUCCESS if limit == 1062 else BankConversionResult.Outcome.TOO_HEAVY), "exchange to 1062 against the limit %d" % limit)
		check(_value(f.context) == value_before, "the money held is worth the same: no coin lost")
		check(f.context.index.snapshot_ids() == f.context.inventory.registered_item_ids(), "index and inventory agree")


func _value(context: MoneyInventoryContext) -> int:
	return Finance.amount(context, GOLD) * 10000 + Finance.amount(context, SILVER) * 100 + Finance.amount(context, COIN)


func check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok:
		failures.append(label)
