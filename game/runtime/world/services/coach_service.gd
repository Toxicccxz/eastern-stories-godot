class_name CoachService
extends WorldService

## Native (车马行; DECISIONS「车马行」): the cart at a coach stop. 坐车 opens the 地图 page on its
## rides (CoachLines); the one picked is asked first (fare and time), the cart rolls along the
## lit road on the 沙盘, and the player is set down by the cart at the other stop, followed by
## whoever follows them every way. There the fare is paid (the driver makes change) and the
## road's time goes by (WorldSessionController.pass_game_time()); the arrival autosaves as any
## map change does. With the pacing knob coach_travel off (ES2) the cart takes nobody.

## The change the driver counts into the player's hand is theirs however heavy: a change the
## purse could not carry would cost the coin it changed (BankConversionService), so the carry
## limit given for the fare's change is none.
const CHANGE_CARRY: int = 1 << 30


func verb() -> String:
	# TRANSLATORS: the 车马行's cart in the interaction list: take a ride.
	return tr("坐车")


## A ride is no thing to start mid-fight or busy (ES2's busy gate, as for any errand).
func requires_idle() -> bool:
	return true


func in_reach() -> bool:
	var pacing: PacingDefinition = GameContent.catalog().pacing()
	return map.session != null and pacing.coach_travel and pacing.map_page and super.in_reach()


func interact() -> void:
	if not in_reach() or not panel_may_open():
		return
	map.player_body.quarantine_current_movement_input()
	map.session.shared_ui().offer_rides(rides(), choose)


## The rides from this stop the player may take now.
func rides() -> Array[CoachLines.Ride]:
	var state: CharacterState = map.player_runtime().state
	return CoachLines.rides(GameContent.catalog(), state, definition)


## The ride to `to` as it stands now; null when the player cannot take it any more.
func ride_to(to: ServiceDefinition) -> CoachLines.Ride:
	return CoachLines.ride_to(GameContent.catalog(), map.player_runtime().state, definition, to)


## The player picked `ride` on the 地图 page: asked first, with what it costs and takes. The
## answer is why it cannot go ("" when the question is up).
func choose(ride: CoachLines.Ride) -> String:
	var fresh: CoachLines.Ride = null if ride == null else ride_to(ride.to)
	if fresh == null or not in_reach():
		# TRANSLATORS: the 车马行 cannot take the player there now.
		return tr("车夫摇摇头：「这会儿去不了。」")
	if not map.player_can_afford(fresh.fare):
		# TRANSLATORS: the player has less money than a 车马行 fare.
		return tr("你的钱不够付车钱。")
	var catalog: ContentCatalog = GameContent.catalog()
	# TRANSLATORS: the 车马行's question before a ride: {place} where to, {fare} the fare, {time} the time on the road.
	var question: String = tr("坐车去{place}？车钱{fare}，路上约{time}。").format({
		"place": tr(fresh.name), "fare": CoachLines.fare_text(catalog, fresh.fare), "time": CoachLines.duration_text(fresh.minutes),
	})
	# TRANSLATORS: the 车马行's question: the button that takes the ride.
	map.session.shared_ui().ask_first(question, tr("坐车"), _set_off.bind(fresh.to), func() -> bool: return _can_go(fresh.to))
	return ""


func _can_go(to: ServiceDefinition) -> bool:
	var ride: CoachLines.Ride = ride_to(to)
	return ride != null and in_reach() and map.player_can_afford(ride.fare)


## The player said yes: the cart rolls on the 沙盘, then the ride.
func _set_off(to: ServiceDefinition) -> void:
	var ride: CoachLines.Ride = ride_to(to)
	if ride == null or not _can_go(to):
		return
	map.session.shared_ui().play_ride(ride, _ride.bind(to))


## The cart has rolled there on the 沙盘: the menu closes and the player is set down at the
## other stop; there the fare is paid and the road's time goes by. True when they arrived.
func _ride(to: ServiceDefinition) -> bool:
	var ride: CoachLines.Ride = ride_to(to)
	var session: WorldSessionController = map.session
	if ride == null or session == null:
		return false
	session.shared_ui().close_menu()
	if not in_reach() or session.is_transitioning():
		return false
	# The purse is looked at before the cart sets off (money dropped while it rolled on the 沙盘
	# is not there to pay with); nothing changes it between here and the fare taken there.
	if not map.player_can_afford(ride.fare):
		session.shared_ui().append_log_lines([tr("你的钱不够付车钱。")])
		return false
	var zone: ZoneDefinition = GameContent.catalog().zone(to.zone_id)
	var result: OldPineMapHandoffResult = session.handoff_led(to.map_id, to.zone_id, zone.combat_location_id, to.arrival_spawn_id)
	if result == null or not result.succeeded():
		# TRANSLATORS: a 车马行 ride that could not set off after all.
		session.shared_ui().append_log_lines([tr("车夫摇摇头：「这会儿走不了。」")])
		return false
	var lines: Array[String] = []
	var there: WorldMapController = session.active_map() as WorldMapController
	var catalog: ContentCatalog = GameContent.catalog()
	if there != null and _pay(there, ride.fare):
		# TRANSLATORS: a 车马行 ride paid: {fare} the fare.
		lines.append(tr("你付了{fare}车钱。").format({"fare": CoachLines.fare_text(catalog, ride.fare)}))
	else:
		push_error("车马行: the fare (%d) was not taken on the ride to %s" % [ride.fare, to.service_id])
	if session.pass_game_time(ride.minutes * 60):
		# TRANSLATORS: a 车马行 ride ends: {time} the time on the road, {place} where it set the player down.
		lines.append(tr("车马行的车走了{time}，把你送到了{place}。").format({"time": CoachLines.duration_text(ride.minutes), "place": tr(ride.name)}))
	else:
		# TRANSLATORS: a 车马行 ride ends (no time could go by): {place} where it set the player down.
		lines.append(tr("车马行的车把你送到了{place}。").format({"place": tr(ride.name)}))
	session.shared_ui().append_log_lines(lines)
	return true


## The fare from the player's purse on `on` (their map now), the driver making change.
func _pay(on: WorldMapController, fare: int) -> bool:
	var player: WorldPlayerRuntimeState = on.player_runtime()
	var context := MoneyInventoryContext.new(
		ItemLifecycleOwnerContext.new(player.character_id, player.state.equipment, player.armor),
		on.inventory_state(), on.stack_collection(), on.item_instance_index(),
	)
	return MoneyPaymentService.pay_making_change(context, on.item_id_allocator(), CHANGE_CARRY, fare)
