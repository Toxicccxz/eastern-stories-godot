class_name WindDefinition
extends RefCounted

## Native (第十章 A; DECISIONS「风」): a map's guiding wind — the 寻风地带's, which blows out of 岚城
## (樵夫的旧记载: 风大不能行……风停处即是城; 先帝的解读: 逆风而行). The wind follows one of the map's
## `routes`, a line of the layout's spawn points ending in its calm: wherever the player stands it
## blows from a point a little ahead along the route toward them, so walking into it leads to the
## calm, and within `calm_radius` of the route's last point it is still. Which route blows is
## drawn when the player comes in by one of `enter_portals` (`pick` per_entry; fixed: the first)
## and kept as the route's saved `mark` (the others' cleared), so a Continue blows the same one;
## the town has drifted by the next coming. Each gust (`gust_ms` of world time) the runtime tells
## where it comes from when that changes, now and then a gust veers (`veer_percent`, drawn) and
## is told so and counts for nothing; one standing farther than `route_radius` from the route
## meets the gale (`gale`, ScriptedAct branches as a native hazard's, run only with pacing's
## native_hazards); one carrying `bell` hears it ring clear when their way went into the wind
## (within `upwind_degrees`), dull when it did not, once when the wind stops.
## The rule is the 2D map's: presentation (grass, mist, bells, the HUD's vane) only shows the
## vector the runtime gives it.

enum Pick { PER_ENTRY, FIXED }

## How far ahead along the route the wind's source lies from the nearest point on it (px).
const LOOKAHEAD: float = 192.0
## The eight quarters the wind is told from, clockwise from north (2D: y grows south).
const QUARTERS: Array[String] = ["北", "东北", "东", "东南", "南", "西南", "西", "西北"]

class Route:
	extends RefCounted
	var route_id: StringName
	## The saved mark naming this route the one that blows.
	var mark: String
	## Spawn point ids, from the way in to the calm (the last).
	var points: Array[StringName] = []

var wind_id: StringName
var map_id: StringName
var zone_ids: Array[StringName] = []
var routes: Array[Route] = []
var pick: Pick = Pick.PER_ENTRY
var enter_portal_ids: Array[StringName] = []
var calm_radius: float = 96.0
var route_radius: float = 224.0
var gust_ms: int = 6000
var veer_percent: int = 0
var veer_degrees: int = 90
var bell_item_id: StringName = &""
var upwind_degrees: int = 50
var gale: Array[ScriptedAct] = []
var legacy_source_path: String


## {id, map, zones, routes: [{id, mark, points}], pick?, enter_portals, calm_radius?, route_radius?,
## gust_seconds?, veer_percent?, veer_degrees?, bell?, upwind_degrees?, gale?: {acts: [...]}, legacy_source}.
static func from_record(reader: ContentRecordReader) -> WindDefinition:
	var wind := WindDefinition.new()
	wind.wind_id = StringName(reader.required_text("id"))
	wind.map_id = StringName(reader.required_text("map"))
	for zone_id: String in reader.text_list("zones"):
		wind.zone_ids.append(StringName(zone_id))
	if wind.zone_ids.is_empty():
		reader.fail("zones", "the wind blows somewhere")
	for record: ContentRecordReader in reader.children("routes"):
		var route := Route.new()
		route.route_id = StringName(record.required_text("id"))
		route.mark = record.required_text("mark")
		for point_id: String in record.text_list("points"):
			route.points.append(StringName(point_id))
		if route.points.size() < 2:
			record.fail("points", "a route runs from a way in to a calm: two points or more")
		record.finish()
		wind.routes.append(route)
	if wind.routes.is_empty():
		reader.fail("routes", "the wind follows a route")
	var how: String = reader.text("pick", "per_entry")
	if how == "fixed":
		wind.pick = Pick.FIXED
	elif how != "per_entry":
		reader.fail("pick", "per_entry or fixed")
	for portal_id: String in reader.text_list("enter_portals"):
		wind.enter_portal_ids.append(StringName(portal_id))
	wind.calm_radius = float(reader.integer("calm_radius", 96))
	wind.route_radius = float(reader.integer("route_radius", 224))
	wind.gust_ms = 1000 * reader.integer("gust_seconds", 6)
	wind.veer_percent = reader.integer("veer_percent", 0)
	wind.veer_degrees = reader.integer("veer_degrees", 90)
	wind.bell_item_id = StringName(reader.text("bell"))
	wind.upwind_degrees = reader.integer("upwind_degrees", 50)
	var gale: ContentRecordReader = reader.child("gale")
	if gale != null:
		for record: ContentRecordReader in gale.children("acts"):
			wind.gale.append(ScriptedAct.from_record(record))
		gale.finish()
		if wind.gale.is_empty():
			reader.fail("gale", "a gale does something")
	wind.legacy_source_path = reader.required_text("legacy_source")
	reader.finish()
	if wind.calm_radius <= 0.0 or wind.route_radius <= wind.calm_radius or wind.gust_ms <= 0:
		reader.fail("route_radius", "calm_radius, gust_seconds positive and route_radius beyond the calm")
	if wind.veer_percent < 0 or wind.veer_percent > 100 or wind.upwind_degrees <= 0 or wind.upwind_degrees > 180:
		reader.fail("veer_percent", "veer_percent 0–100, upwind_degrees 1–180")
	return wind


## The route the player's saved marks name, or null (none drawn yet).
func route_marked(marks: Dictionary[String, int]) -> Route:
	for route: Route in routes:
		if marks.get(route.mark, 0) != 0:
			return route
	return null


## The route `drawn` picks (MudOS random(sizeof(routes))); FIXED: the first.
func route_drawn(drawn: int) -> Route:
	if pick == Pick.FIXED:
		return routes[0]
	return routes[clampi(drawn, 0, routes.size() - 1)]


## Where the wind comes from at `at` along a route laid at `points` (px), as a unit vector the wind
## blows along (from its source toward the player); ZERO in the calm (within calm_radius of the last
## point). The source lies LOOKAHEAD ahead along the route of the nearest point on it.
func blowing(points: PackedVector2Array, at: Vector2) -> Vector2:
	if points.size() < 2 or at.distance_to(points[-1]) <= calm_radius:
		return Vector2.ZERO
	var near: Dictionary = _nearest(points, at)
	var source: Vector2 = _ahead(points, int(near["segment"]), near["point"], LOOKAHEAD)
	if source.distance_to(at) < 1.0:
		source = points[-1]
	var toward: Vector2 = at - source
	return Vector2.ZERO if toward.length() < 1.0 else toward.normalized()


## How far `at` stands from the route laid at `points` (px).
func off_route(points: PackedVector2Array, at: Vector2) -> float:
	if points.size() < 2:
		return 0.0
	return at.distance_to(_nearest(points, at)["point"])


## Whether one standing at `at` is in the calm.
func calm_at(points: PackedVector2Array, at: Vector2) -> bool:
	return points.size() >= 2 and at.distance_to(points[-1]) <= calm_radius


## Whether a way walked (`moved`, px) went into a wind blowing along `wind`: within upwind_degrees of
## straight into it. Too short a way (under 24 px) went nowhere.
func went_upwind(wind: Vector2, moved: Vector2) -> bool:
	if wind == Vector2.ZERO or moved.length() < 24.0:
		return false
	return rad_to_deg(absf(moved.angle_to(-wind))) <= float(upwind_degrees)


## The quarter (QUARTERS) a wind blowing along `wind` comes from; "" for none.
static func quarter_of(wind: Vector2) -> String:
	if wind == Vector2.ZERO:
		return ""
	var from: Vector2 = -wind
	# North is up (−y); angles clockwise from it.
	var degrees: float = fposmod(rad_to_deg(atan2(from.x, -from.y)), 360.0)
	return QUARTERS[int(round(degrees / 45.0)) % 8]


## A gust veered by `degrees` (signed) from `wind`.
static func veered(wind: Vector2, degrees: float) -> Vector2:
	return wind.rotated(deg_to_rad(degrees))


func _nearest(points: PackedVector2Array, at: Vector2) -> Dictionary:
	var best: float = INF
	var best_point: Vector2 = points[0]
	var best_segment: int = 0
	for i: int in points.size() - 1:
		var point: Vector2 = Geometry2D.get_closest_point_to_segment(at, points[i], points[i + 1])
		var distance: float = point.distance_to(at)
		if distance < best:
			best = distance
			best_point = point
			best_segment = i
	return {"point": best_point, "segment": best_segment}


func _ahead(points: PackedVector2Array, segment: int, from: Vector2, length: float) -> Vector2:
	var left: float = length
	var here: Vector2 = from
	for i: int in range(segment, points.size() - 1):
		var to: Vector2 = points[i + 1]
		var step: float = here.distance_to(to)
		if step >= left:
			return here.move_toward(to, left)
		left -= step
		here = to
	return points[-1]
