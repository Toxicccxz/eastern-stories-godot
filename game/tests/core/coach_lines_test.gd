extends RefCounted

## 车马行 (DECISIONS「车马行」) as rules: the twelve stops and their arrival points, a ride only
## to a stop walked to by roads walked, the fare (10 文 + 5 文 a leg, by the 五文) and the
## road's time (30 game minutes a leg) as the driver says them, the knobs, and
## the fare paid with change made from silver or gold.

const Finance := preload("res://tests/runtime/snow_finance_test.gd")
## The seven towns and the five schools' gates (owner, 2026-11-04).
const STOP_MAPS: Array[StringName] = [
	&"snow.outdoor", &"cloud.outdoor", &"choyin.town", &"city.main", &"village.main", &"guanbei.horse_market", &"fanfang.bazaar",
	&"green.village", &"temple.grounds", &"waterfog.mountain", &"latemoon.manor", &"sanyen.grounds",
]

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_stops()
	_test_rides()
	_test_fare_and_time()
	_test_knobs()
	_test_making_change()
	await tree.process_frame
	return {"assertions": _count, "failures": _failures.duplicate()}


func _test_stops() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var stops: Array[ServiceDefinition] = CoachLines.stops(catalog)
	var maps: Array[StringName] = []
	for stop: ServiceDefinition in stops:
		maps.append(stop.map_id)
		_check(stop.arrival_spawn_id == StringName(String(stop.zone_id) + ".coach_arrival"), "%s sets riders down by its cart" % stop.service_id)
		_check(stop.display_name == "车马行" and stop.legacy_source.begins_with("native: 车马行"), "%s is native and says so" % stop.service_id)
		_check(not catalog.atlas().home_of(catalog, stop.map_id).is_empty(), "%s stands in a place on the 沙盘" % stop.service_id)
	_check(stops.size() == STOP_MAPS.size(), "twelve stops: %d" % stops.size())
	for map_id: StringName in STOP_MAPS:
		_check(maps.has(map_id), "a stop on %s" % map_id)
	_check(CoachLines.stop_at(catalog, &"snow.mstreet4.coach") != null and CoachLines.stop_at(catalog, &"snow.mstreet4.bounty") == null, "stop_at() knows only the carts")
	var errors: Array[String] = []
	ServiceDefinition.from_record(ContentRecordReader.new({"id": "x.coach", "kind": "coach", "zone": "x", "name": "车马行", "reach": 96, "legacy_source": "native"}, "test", errors))
	_check(not errors.is_empty(), "a coach stop without its arrival point is refused")
	errors.clear()
	ServiceDefinition.from_record(ContentRecordReader.new({"id": "x.bank", "kind": "bank", "zone": "x", "name": "钱庄", "reach": 96, "arrival": "x.a", "legacy_source": "x"}, "test", errors))
	_check(not errors.is_empty(), "and any other service with one")


func _test_rides() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var snow: ServiceDefinition = CoachLines.stop_at(catalog, &"snow.mstreet4.coach")
	var cloud: ServiceDefinition = CoachLines.stop_at(catalog, &"cloud.entrance.coach")
	var temple: ServiceDefinition = CoachLines.stop_at(catalog, &"temple.square.coach")
	var state := CharacterState.new()
	state.visited_maps = {"snow.outdoor": 1}
	_check(CoachLines.rides(catalog, state, snow).is_empty(), "no ride to a town not walked to")
	state.visited_maps["cloud.outdoor"] = 2
	var rides: Array[CoachLines.Ride] = CoachLines.rides(catalog, state, snow)
	_check(rides.size() == 1 and rides[0].to == cloud and rides[0].name == "绮云镇" and rides[0].cell == &"cloud.outdoor", "walked to 绮云镇: a ride there")
	_check(rides.size() == 1 and rides[0].legs() == 1 and rides[0].fare == 15 and rides[0].minutes == 30, "one leg: 十五文, half a 时辰")
	state.visited_maps["temple.grounds"] = 3
	_check(CoachLines.ride_to(catalog, state, snow, temple) == null, "灵心观 stood on (a teleport), the mountain road not walked: no ride")
	state.visited_maps["temple.mountain"] = 4
	var to_temple: CoachLines.Ride = CoachLines.ride_to(catalog, state, snow, temple)
	_check(to_temple != null and to_temple.legs() == 2 and to_temple.fare == 20 and to_temple.minutes == 60, "the mountain road walked: two legs, 二十文, an hour")
	_check(CoachLines.ride_to(catalog, state, snow, snow) == null, "no ride to where one stands")
	_check(CoachLines.ride_to(catalog, state, cloud, snow) != null, "and back the other way")


func _test_fare_and_time() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var pacing: PacingDefinition = catalog.pacing()
	_check([CoachLines.fare(pacing, 1), CoachLines.fare(pacing, 4), CoachLines.fare(pacing, 9)] == [15, 30, 55], "fares by legs: 15, 30, 55")
	var odd: PacingDefinition = pacing.copy().with_coach(true, 3, 4, 30)
	_check(CoachLines.fare(odd, 1) == 10 and CoachLines.fare(odd, 0) == 5, "rounded up to whole 五文, at least 五文")
	_check([CoachLines.fare_text(catalog, 15), CoachLines.fare_text(catalog, 100), CoachLines.fare_text(catalog, 155)] == ["十五文", "一两银子", "一两银子五十五文"], "fares as said")
	var said: Array[String] = []
	for minutes: int in [20, 30, 60, 90, 120, 150, 270, 360]:
		said.append(CoachLines.duration_text(minutes))
	_check(said == ["一盏茶的工夫", "半个时辰", "半个时辰", "一个时辰", "一个时辰", "一个半时辰", "两个半时辰", "三个时辰"], "the road's time as said: %s" % [said])


func _test_knobs() -> void:
	var pacing: PacingDefinition = GameContent.catalog().pacing()
	_check(pacing.coach_travel and [pacing.coach_fare_base, pacing.coach_fare_per_leg, pacing.coach_minutes_per_leg] == [10, 5, 30], "pacing.json: the coach, 10 + 5 文 a leg, 30 minutes a leg")
	_check(pacing.feel.coach_ride_seconds == 0.0, "suites ride without the 沙盘's picture (feel off)")
	_check(not PacingDefinition.new().coach_travel, "without the knob: no coach (ES2)")
	_check(pacing.copy().coach_travel and pacing.copy().coach_minutes_per_leg == 30, "copy() keeps them")


func _test_making_change() -> void:
	var silver: Finance.Fixture = Finance.amounts(0, 1, 0)
	_check(MoneyPaymentService.pay_making_change(silver.context, silver.allocator, 1000000, 15), "a 两 of silver pays 十五文")
	_check(Finance.amount(silver.context, CurrencyDenomination.Value.SILVER) == 0 and Finance.amount(silver.context, CurrencyDenomination.Value.COIN) == 85, "and 85 文 change")
	var gold: Finance.Fixture = Finance.amounts(1, 0, 0)
	_check(MoneyPaymentService.pay_making_change(gold.context, gold.allocator, 1000000, 15), "a 两 of gold pays too")
	_check(Finance.amount(gold.context, CurrencyDenomination.Value.SILVER) == 99 and Finance.amount(gold.context, CurrencyDenomination.Value.COIN) == 85, "99 两 and 85 文 change")
	var coins: Finance.Fixture = Finance.amounts(0, 1, 20)
	_check(MoneyPaymentService.pay_making_change(coins.context, coins.allocator, 1000000, 15), "coins enough")
	_check(Finance.amount(coins.context, CurrencyDenomination.Value.SILVER) == 1 and Finance.amount(coins.context, CurrencyDenomination.Value.COIN) == 5, "the silver kept")
	var purse: Finance.Fixture = Finance.amounts(0, 0, 100)
	_check(MoneyPaymentService.can_afford(purse.context, 15).outcome == MoneyAffordabilityResult.Outcome.DENOMINATION_REJECTED, "finance.c: coins alone are 「找不开」 to a shop")
	_check(MoneyPaymentService.pay_making_change(purse.context, purse.allocator, 1000000, 15) and Finance.amount(purse.context, CurrencyDenomination.Value.COIN) == 85, "the driver takes 十五文 of a hundred coins")
	var hundreds: Finance.Fixture = Finance.amounts(0, 2, 0)
	_check(MoneyPaymentService.pay_making_change(hundreds.context, hundreds.allocator, 1000000, 150), "一两银子五十文 from two 两")
	_check(Finance.amount(hundreds.context, CurrencyDenomination.Value.SILVER) == 0 and Finance.amount(hundreds.context, CurrencyDenomination.Value.COIN) == 50, "a 两 changed, 50 文 back")
	var poor: Finance.Fixture = Finance.amounts(0, 0, 10)
	_check(not MoneyPaymentService.pay_making_change(poor.context, poor.allocator, 1000000, 15) and Finance.amount(poor.context, CurrencyDenomination.Value.COIN) == 10, "十文 short of 十五: nothing taken")


func _check(ok: bool, label: String) -> void:
	_count += 1
	if not ok:
		_failures.append(label)
