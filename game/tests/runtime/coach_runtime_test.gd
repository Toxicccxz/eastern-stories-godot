extends RefCounted

## 车马行 in the world (DECISIONS「车马行」): every stop's cart stands on its map with its
## 坐车 in reach of where a ride sets the player down, and every way out of its room still walked
## straight through (the cart blocks none); at 雪亭驿's cart the 地图 page opens on the rides
## walked to (the card: the fare, the time, 坐车去这里), the question first, then the ride: set
## down by 绮云镇's cart, 十五文 paid, half a 时辰 gone, said in the log; the page left while the
## cart rolls on the 沙盘 takes nobody; a purse too light is told so, before and at the cart's
## setting off; with the classic knobs no cart takes anybody.

const Finance := preload("res://tests/runtime/snow_finance_test.gd")
const MapPlaces := preload("res://tests/support/map_places.gd")

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	var session: WorldSessionController = await _session(tree)
	await _test_stops(tree, session)
	await _test_offer(tree, session)
	await _test_ride(tree, session)
	await _test_left_page(tree, session)
	await _test_poor(tree, session)
	session.free()
	await tree.process_frame
	var previous: PacingDefinition = Es2Pacing.use()
	var classic: WorldSessionController = await _session(tree)
	await _test_classic(tree, classic)
	classic.free()
	Es2Pacing.restore(previous)
	await tree.process_frame
	return {"assertions": _count, "failures": _failures.duplicate()}


## Set down at each stop: there, in its zone, the cart's 坐车 in reach.
func _test_stops(tree: SceneTree, session: WorldSessionController) -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	for stop: ServiceDefinition in CoachLines.stops(catalog):
		var zone: ZoneDefinition = catalog.zone(stop.zone_id)
		var result: OldPineMapHandoffResult = session.handoff_to(stop.map_id, stop.zone_id, zone.combat_location_id, stop.arrival_spawn_id)
		if session.active_map_id() == stop.map_id and (result == null or not result.succeeded()):
			# Already on that map: put down by the cart all the same.
			(session.active_map() as WorldMapController).relocate_player(stop.zone_id, stop.arrival_spawn_id)
		await _settle(tree)
		var map: WorldMapController = session.active_map() as WorldMapController
		_check(map != null and map.map_id() == stop.map_id and session.player_runtime().world_location().zone_id == stop.zone_id, "set down at %s" % stop.service_id)
		var cart: CoachService = null if map == null else map.service(stop.service_id) as CoachService
		_check(cart != null, "%s: its cart is a service on the map" % stop.service_id)
		if cart == null:
			continue
		_check(cart.in_reach() and cart.verb() == "坐车" and cart.context_title() == "车马行 · 坐车", "%s: 坐车 in reach where a ride sets one down" % stop.service_id)
		_check(MapPlacementValidator.is_valid_character_position(map, stop.zone_id, map.runtime_player_body().global_position), "%s: a free spot to stand" % stop.service_id)
		var furnished: bool = false
		for node: Node in map.find_children("Furnishing*", "Node2D", true, false):
			if (node.get_meta("look", {}) as Dictionary).get("kind", "") == "coach":
				furnished = furnished or (node as Node2D).global_position.distance_to(cart.point.global_position) < 160.0
		_check(furnished, "%s: the cart itself stands beside it" % stop.service_id)
		_check(_ways_clear(map, stop).is_empty(), "%s: every way out of its room walked straight through: %s" % [stop.service_id, _ways_clear(map, stop)])


## The ways out of the stop's room a body cannot walk to from beside the cart without going
## round through a third room: the seams to its neighbours (not behind a door) and its passages.
func _ways_clear(map: WorldMapController, stop: ServiceDefinition) -> Array[String]:
	var catalog: ContentCatalog = GameContent.catalog()
	var blocked: Array[String] = []
	var from: Vector2 = map.runtime_player_body().global_position
	var here: Rect2 = MapPlaces.zone_rect(map, stop.zone_id).grow(24.0)
	var doors: Array[DoorDefinition] = catalog.doors_for_map(stop.map_id)
	for zone: ZoneDefinition in catalog.zones_for_map(stop.map_id):
		if zone.zone_id == stop.zone_id or not catalog.zones_adjacent(stop.zone_id, zone.zone_id):
			continue
		if doors.any(func(door: DoorDefinition) -> bool: return door.zone_ids().has(stop.zone_id) and door.zone_ids().has(zone.zone_id)):
			continue
		var seam: Vector2 = MapPlaces.doorway(map, stop.zone_id, zone.zone_id)
		if not seam.is_finite():
			continue
		var there: Rect2 = MapPlaces.zone_rect(map, zone.zone_id).grow(24.0)
		var path: PackedVector2Array = MapRoute.path(map, from, MapPlaces.spot(map, zone.zone_id, seam))
		if path.is_empty() or not Array(path).all(func(point: Vector2) -> bool: return here.has_point(point) or there.has_point(point)):
			blocked.append(String(zone.zone_id))
	for portal: PortalDefinition in catalog.portals_for_map(stop.map_id):
		if portal.source_zone_id != stop.zone_id:
			continue
		var path: PackedVector2Array = MapRoute.path(map, from, MapPlaces.passage_spot(map, portal.portal_id))
		if path.is_empty() or not Array(path).all(func(point: Vector2) -> bool: return here.has_point(point)):
			blocked.append(String(portal.portal_id))
	return blocked


## At 雪亭驿's cart: the 地图 page on the rides.
func _test_offer(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	state.visited_maps = {"snow.outdoor": 1, "cloud.outdoor": 2, "temple.grounds": 3} # TEST-ONLY: 灵心观 reached, the mountain road not
	var cart: CoachService = await _at_cart(tree, session, &"snow.mstreet4.coach")
	if cart == null:
		return
	var rides: Array[CoachLines.Ride] = cart.rides()
	_check(rides.size() == 1 and rides[0].to.service_id == &"cloud.entrance.coach", "one ride: to 绮云镇 (灵心观's road not walked)")
	var ui: SharedGameplayUI = session.shared_ui()
	cart.interact()
	await tree.process_frame
	_check(ui.menu.is_presented() and ui.menu.current_tab() == GameMenu.Tab.MAP and ui.map_page.offers_rides(), "坐车: the menu on its 地图 page, offering the rides")
	_check(ui.map_page.rides().has(&"cloud.outdoor") and ui.map_page.rides().size() == 1, "the page's ride: 绮云镇")
	ui.map_page._select(&"cloud.outdoor")
	var card: String = ui.map_page.shown_text()
	_check(card.contains("车钱 十五文　路上约半个时辰") and card.contains("坐车去这里"), "the card: the fare, the time, 坐车去这里: %s" % card)
	ui.map_page._select(&"snow.outdoor")
	_check(ui.map_page.shown_text().contains("车马行的车就停在这里。"), "here: the cart stands here")
	ui.map_page._select(&"temple.grounds")
	_check(ui.map_page.shown_text().contains("车马行的车不到这里。") and not ui.map_page.shown_text().contains("坐车去这里"), "灵心观: no ride")
	ui.close_menu()
	await tree.process_frame
	_check(not ui.map_page.offers_rides(), "the menu closed: no rides offered (the 地图 page is itself again)")


## The ride to 绮云镇: asked first, then set down by its cart, paid, half a 时辰 gone.
func _test_ride(tree: SceneTree, session: WorldSessionController) -> void:
	var cart: CoachService = await _at_cart(tree, session, &"snow.mstreet4.coach")
	if cart == null:
		return
	var context: MoneyInventoryContext = Finance.session_context(session)
	Finance.add_money(context, CurrencyDenomination.Value.SILVER, 1, &"000-test-coach-silver") # TEST-ONLY: a 两, to be changed
	var coins: int = _value(session)
	var day: int = session.day_clock().day_seconds()
	var ui: SharedGameplayUI = session.shared_ui()
	cart.interact()
	await tree.process_frame
	ui.map_page._select(&"cloud.outdoor")
	var ride_row: Button = null
	for button: Button in ui.map_page.row_buttons:
		if button.text == "坐车去这里":
			ride_row = button
	_check(ride_row != null, "坐车去这里 on the card")
	if ride_row == null:
		return
	ride_row.pressed.emit()
	_check(ui.is_asking() and ui.confirm_prompt.message.text == "坐车去绮云镇？车钱十五文，路上约半个时辰。" and ui.confirm_prompt.confirm_button.text == "坐车", "asked first: %s" % ui.confirm_prompt.message.text)
	_check(session.active_map_id() == &"snow.outdoor", "nothing yet")
	var before: int = ui.log_lines().size()
	ui.confirm_prompt.confirm_button.pressed.emit()
	await _settle(tree)
	var location: WorldLocationState = session.player_runtime().world_location()
	_check(session.active_map_id() == &"cloud.outdoor" and location.zone_id == &"cloud.entrance", "set down at 绮云镇's gate: %s %s" % [session.active_map_id(), location.zone_id])
	_check(not ui.menu.is_presented(), "the menu closed for the ride")
	var map: WorldMapController = session.active_map() as WorldMapController
	var marker: WorldSpawnMarker2D = map.resolve_spawn_marker(&"cloud.entrance.coach_arrival")
	_check(marker != null and map.runtime_player_body().global_position.distance_to(marker.global_position) < 24.0, "by the cart")
	_check(_value(session) == coins - 15, "十五文 paid (the driver changed the 两): %d → %d" % [coins, _value(session)])
	_check(posmod(session.day_clock().day_seconds() - day, DayClock.DAY_MINUTES * 60) == 30 * 60, "half a 时辰 on the road")
	var lines: Array[String] = ui.log_lines().slice(before)
	_check(lines.has("你付了十五文车钱。") and lines.has("车马行的车走了半个时辰，把你送到了绮云镇。"), "said: %s" % [lines])
	_check(session.player_runtime().state.visited_maps.has("cloud.outdoor"), "绮云镇 still walked to")


## The ride said yes to, the 地图 page left while the cart rolls on the 沙盘 (another tab):
## the cart stops, nobody goes, nothing is paid.
func _test_left_page(tree: SceneTree, session: WorldSessionController) -> void:
	var cart: CoachService = await _at_cart(tree, session, &"cloud.entrance.coach")
	if cart == null:
		return
	var pacing: PacingDefinition = GameContent.catalog().pacing()
	var feel: FeelDefinition = pacing.feel
	pacing.feel = feel.but({"coach_ride_ms": 2000}) # TEST-ONLY: the picture on
	var ui: SharedGameplayUI = session.shared_ui()
	var coins: int = _value(session)
	cart.interact()
	await tree.process_frame
	var ride: CoachLines.Ride = ui.map_page.rides().get(&"snow.outdoor")
	_check(ride != null, "a ride back to 雪亭镇")
	if ride != null:
		ui.map_page._select(&"snow.outdoor")
		_check(cart.choose(ride).is_empty() and ui.is_asking(), "asked")
		ui.confirm_prompt.confirm_button.pressed.emit()
		await tree.process_frame
		_check(ui.map_page.riding() and ui.map_page.row_buttons.all(func(b: Button) -> bool: return b.disabled), "the cart rolls on the 沙盘, the card greyed")
		ui.menu.show_tab(GameMenu.Tab.INVENTORY)
		await tree.create_timer(2.3).timeout
		_check(not ui.map_page.riding() and session.active_map_id() == &"cloud.outdoor" and _value(session) == coins, "another tab: the cart stopped, nobody went, nothing paid")
	ui.close_menu()
	pacing.feel = feel
	await tree.process_frame


## A purse lighter than the fare: told so, nothing asked.
func _test_poor(tree: SceneTree, session: WorldSessionController) -> void:
	var cart: CoachService = await _at_cart(tree, session, &"cloud.entrance.coach")
	if cart == null:
		return
	var context: MoneyInventoryContext = Finance.session_context(session)
	for denomination: CurrencyDenomination.Value in [CurrencyDenomination.Value.GOLD, CurrencyDenomination.Value.SILVER, CurrencyDenomination.Value.COIN]:
		var held: CurrencyStackSelection = context.select(denomination)
		if held.outcome == CurrencyStackSelection.Outcome.FOUND:
			context.set_amount(held.item_id, 0) # TEST-ONLY: an empty purse
	var rides: Array[CoachLines.Ride] = cart.rides()
	_check(not rides.is_empty(), "rides from 绮云镇")
	if rides.is_empty():
		return
	_check(cart.choose(rides[0]) == "你的钱不够付车钱。" and not session.shared_ui().is_asking(), "too poor: told, not asked")
	var before: int = session.shared_ui().log_lines().size()
	_check(not cart._ride(rides[0].to) and session.active_map_id() == &"cloud.outdoor", "money gone by the time the cart sets off (dropped while it rolled): nobody goes")
	_check(session.shared_ui().log_lines().slice(before).has("你的钱不够付车钱。"), "and is told why")


func _test_classic(tree: SceneTree, session: WorldSessionController) -> void:
	var cart: CoachService = await _at_cart(tree, session, &"snow.mstreet4.coach")
	_check(cart != null and not cart.in_reach() and cart.context_title().is_empty(), "经典: the cart takes nobody")


func _at_cart(tree: SceneTree, session: WorldSessionController, service_id: StringName) -> CoachService:
	var stop: ServiceDefinition = GameContent.catalog().service(service_id)
	if session.active_map_id() == stop.map_id:
		(session.active_map() as WorldMapController).relocate_player(stop.zone_id, stop.arrival_spawn_id)
	else:
		session.handoff_to(stop.map_id, stop.zone_id, GameContent.catalog().zone(stop.zone_id).combat_location_id, stop.arrival_spawn_id)
	await _settle(tree)
	var map: WorldMapController = session.active_map() as WorldMapController
	var cart: CoachService = null if map == null else map.service(service_id) as CoachService
	_check(cart != null, "at %s" % service_id)
	return cart


## The money carried, in coins.
func _value(session: WorldSessionController) -> int:
	var total: int = 0
	for row: PlayerInventoryRowProjection in session.player_inventory_rows():
		var denomination: CurrencyDenomination.Value = GameContent.catalog().denomination_of(row.item_definition_id)
		if denomination != CurrencyDenomination.Value.UNSUPPORTED:
			total += row.amount * GameContent.catalog().currency_item(denomination).currency_base_value
	return total


func _session(tree: SceneTree) -> WorldSessionController:
	var session: WorldSessionController = (load("res://scenes/world/oldpine/oldpine_world_session.tscn") as PackedScene).instantiate()
	session.configure_source_entry("车马", CharacterState.GENDER_MALE)
	session.deterministic_combat_seed = true
	session.deterministic_npc_seed = true
	session.deterministic_world_interaction_seed = true
	tree.root.add_child(session)
	for frame: int in 4:
		await tree.process_frame
	session.set_process(false)
	return session


func _settle(tree: SceneTree) -> void:
	for frame: int in 4:
		await tree.physics_frame
	await tree.process_frame


func _check(ok: bool, label: String) -> void:
	_count += 1
	if not ok:
		_failures.append(label)
