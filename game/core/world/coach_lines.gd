class_name CoachLines
extends RefCounted

## 车马行 (native; DECISIONS「车马行」): a cart stands at each of the seven towns and the five
## schools' gates (a `coach` service, ServiceDefinition.arrival_spawn_id beside it), and takes the
## player to any other stop they have walked to, by roads they have walked, for a small fare and
## the time the road takes. Pure: it reads the definitions, the pacing and
## CharacterState.visited_maps, and moves or charges nothing.

## Fares are counted in whole 五文.
const FARE_STEP: int = 5
## Game minutes in half a 时辰 (an hour): the ride's time is told by the half 时辰.
const HALF_SHICHEN_MINUTES: int = 60


## A ride from one stop to another: where to, how far, what it costs and takes.
class Ride:
	extends RefCounted
	var from: ServiceDefinition
	var to: ServiceDefinition
	## The 沙盘 place the stop stands in, and its name.
	var cell: StringName
	var name: String
	## The ways between maps on the road there (WorldRoute.guided over the maps walked).
	var route: Array[WorldRoute.Step] = []
	## Coins.
	var fare: int = 0
	## Game minutes on the road.
	var minutes: int = 0

	func legs() -> int:
		return route.size()


## Every stop of the world, by the 沙盘's order of its places (north-west first), then by ID.
static func stops(catalog: ContentCatalog) -> Array[ServiceDefinition]:
	var result: Array[ServiceDefinition] = []
	for map: MapDefinition in catalog.maps():
		for service: ServiceDefinition in catalog.services_for_map(map.map_id):
			if service.kind == &"coach":
				result.append(service)
	var table: AtlasTable = catalog.atlas()
	result.sort_custom(func(a: ServiceDefinition, b: ServiceDefinition) -> bool:
		var cell_a: AtlasCell = table.cell(table.home_of(catalog, a.map_id))
		var cell_b: AtlasCell = table.cell(table.home_of(catalog, b.map_id))
		var key_a: float = INF if cell_a == null else cell_a.at.x + cell_a.at.y
		var key_b: float = INF if cell_b == null else cell_b.at.x + cell_b.at.y
		return key_a < key_b if key_a != key_b else String(a.service_id) < String(b.service_id))
	return result


## The stop the player stands at, or null.
static func stop_at(catalog: ContentCatalog, service_id: StringName) -> ServiceDefinition:
	var service: ServiceDefinition = catalog.service(service_id)
	return service if service != null and service.kind == &"coach" else null


## Every ride from `from` the player may take: to each other stop whose map they have stood on,
## joined to this one by maps they have stood on. A stop on the same map is no ride.
static func rides(catalog: ContentCatalog, state: CharacterState, from: ServiceDefinition) -> Array[Ride]:
	var result: Array[Ride] = []
	if from == null or state == null:
		return result
	for to: ServiceDefinition in stops(catalog):
		var ride: Ride = ride_to(catalog, state, from, to)
		if ride != null:
			result.append(ride)
	return result


## The ride from `from` to `to`; null when the player cannot take it (not been there, no road
## they have walked, the same map).
static func ride_to(catalog: ContentCatalog, state: CharacterState, from: ServiceDefinition, to: ServiceDefinition) -> Ride:
	if from == null or to == null or state == null or from.map_id == to.map_id:
		return null
	if not state.visited_maps.has(String(from.map_id)) or not state.visited_maps.has(String(to.map_id)):
		return null
	var route: Array[WorldRoute.Step] = MapAtlas.route(catalog, state, from.map_id, to.map_id)
	if route.is_empty():
		return null
	var ride := Ride.new()
	ride.from = from
	ride.to = to
	ride.route = route
	var table: AtlasTable = catalog.atlas()
	ride.cell = table.home_of(catalog, to.map_id)
	var cell: AtlasCell = table.cell(ride.cell)
	ride.name = to.display_name if cell == null else cell.name
	var pacing: PacingDefinition = catalog.pacing()
	ride.fare = fare(pacing, route.size())
	ride.minutes = pacing.coach_minutes_per_leg * route.size()
	return ride


## The fare for a ride of `legs` ways between maps, rounded up to whole 五文 (at least 五文).
static func fare(pacing: PacingDefinition, legs: int) -> int:
	var coins: int = pacing.coach_fare_base + pacing.coach_fare_per_leg * maxi(legs, 0)
	return maxi(FARE_STEP, ceili(float(coins) / FARE_STEP) * FARE_STEP)


## How long the road takes, as the driver would say it: by the half 时辰.
static func duration_text(minutes: int) -> String:
	var halves: int = roundi(float(minutes) / float(HALF_SHICHEN_MINUTES))
	if halves <= 0:
		# TRANSLATORS: a 车马行 ride's time on the road: well under an hour.
		return TranslationServer.translate("一盏茶的工夫")
	if halves == 1:
		# TRANSLATORS: a 车马行 ride's time on the road: half a 时辰 (an hour).
		return TranslationServer.translate("半个时辰")
	@warning_ignore("integer_division")
	var whole: int = halves / 2
	# TRANSLATORS: the number two before a measure word (两个时辰), not counted as 二.
	var number: String = TranslationServer.translate("两") if whole == 2 else ChineseNumber.of(whole)
	if halves % 2 == 1:
		# TRANSLATORS: a 车马行 ride's time on the road: {count} 时辰 and a half.
		return TranslationServer.translate("{count}个半时辰").format({"count": number})
	# TRANSLATORS: a 车马行 ride's time on the road: {count} 时辰.
	return TranslationServer.translate("{count}个时辰").format({"count": number})


## A fare as the driver names it: in 文, or 两 of silver and 文 from a 两 up.
static func fare_text(catalog: ContentCatalog, coins: int) -> String:
	var silver_item: ItemContentDefinition = catalog.currency_item(CurrencyDenomination.Value.SILVER)
	var per_silver: int = 100 if silver_item == null else silver_item.currency_base_value
	@warning_ignore("integer_division")
	var silver: int = coins / per_silver
	var rest: int = coins % per_silver
	if silver <= 0:
		# TRANSLATORS: a 车马行 fare: {coins} 文.
		return TranslationServer.translate("{coins}文").format({"coins": ChineseNumber.of(rest)})
	if rest == 0:
		# TRANSLATORS: a 车马行 fare: {silver} 两 of silver.
		return TranslationServer.translate("{silver}两银子").format({"silver": ChineseNumber.of(silver)})
	# TRANSLATORS: a 车马行 fare: {silver} 两 of silver and {coins} 文.
	return TranslationServer.translate("{silver}两银子{coins}文").format({"silver": ChineseNumber.of(silver), "coins": ChineseNumber.of(rest)})
