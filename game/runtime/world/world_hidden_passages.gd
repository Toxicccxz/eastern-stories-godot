class_name WorldHiddenPassages
extends RefCounted

## The Session's hidden passages (hidden_passage and dial landmarks): one
## HiddenPassageState each, pushed (or turned and pressed) by the landmark's policy,
## advanced by world time, and the scene passages of both maps kept in step with it.
## ES2 opens the way up only when the room below is loaded (find_object); every native
## room always is, so both open together. A dial closes on time even on a player below,
## who opens it again from there (its dial_below landmark).
var _session: WorldSessionController
var _states: Dictionary[StringName, HiddenPassageState] = {}
var _carried_ms: float = 0.0


func _init(session: WorldSessionController) -> void:
	_session = session
	for landmark: WorldLandmarkDefinition in GameContent.catalog().hidden_passages():
		_states[landmark.landmark_id] = HiddenPassageState.new()


func state(landmark_id: StringName) -> HiddenPassageState:
	return _states.get(landmark_id)


## Continue with the player below a hidden passage: the way back stands open.
func open_for_player_below() -> void:
	for landmark_id: StringName in _states:
		var landmark: WorldLandmarkDefinition = GameContent.catalog().landmark(landmark_id)
		if _player_below(landmark):
			_states[landmark_id].open_for_player_below()
			_apply(landmark, true)


## weapon_storage.c do_push(): the push line, then check_trigger().
func push(landmark: WorldLandmarkDefinition) -> HiddenPassagePushResult:
	var result: HiddenPassagePushResult = HiddenPassagePushResult.new()
	var passage: HiddenPassageState = null if landmark == null else _states.get(landmark.landmark_id)
	if passage == null:
		return result
	result.pushed = true
	if not landmark.message("push").is_empty():
		_session.shared_ui().append_log_lines([TranslationServer.translate(landmark.message("push"))])
	result.opened = passage.push(landmark.setting("pushes"), 1000 * landmark.setting("open_seconds"), landmark.setting("every_push") == 1)
	if result.opened:
		_apply(landmark, true)
		_session.shared_ui().append_log_lines([TranslationServer.translate(landmark.message("open"))])
	return result


## jitan.c do_turn(): the turn's line, and one more of its count.
func turn(landmark: WorldLandmarkDefinition, turn: WorldLandmarkDefinition.Turn) -> bool:
	var passage: HiddenPassageState = null if landmark == null or turn == null else _states.get(landmark.landmark_id)
	if passage == null:
		return false
	_session.shared_ui().append_log_lines([TranslationServer.translate(turn.line)])
	passage.turn(turn.count)
	return true


## jitan.c do_press(): the floor opens when the turns are right (open), else nothing is
## said (the turns are cleared, M4).
func press(landmark: WorldLandmarkDefinition) -> HiddenPassagePushResult:
	var result: HiddenPassagePushResult = HiddenPassagePushResult.new()
	var passage: HiddenPassageState = null if landmark == null else _states.get(landmark.landmark_id)
	if passage == null:
		return result
	result.pushed = true
	result.opened = passage.press(landmark.combination, 1000 * landmark.setting("open_seconds"))
	if result.opened:
		_apply(landmark, true)
		_session.shared_ui().append_log_lines([TranslationServer.translate(landmark.message("open"))])
	return result


## The dial's way opened from below (owner Q2 (a)): 天花板…露出一个向上的阶梯。
func open_from_below(opener: WorldLandmarkDefinition) -> HiddenPassagePushResult:
	var result: HiddenPassagePushResult = HiddenPassagePushResult.new()
	var dial: WorldLandmarkDefinition = null if opener == null else GameContent.catalog().landmark(opener.opens)
	var passage: HiddenPassageState = null if dial == null else _states.get(dial.landmark_id)
	if passage == null:
		return result
	result.pushed = true
	result.opened = passage.open_from_below(1000 * dial.setting("open_seconds"))
	if result.opened:
		_apply(dial, true)
		_session.shared_ui().append_log_lines([TranslationServer.translate(dial.message("open_below"))])
	return result


## weapon_storage.c reset(): delete("left_trigger") when the landmark's room resets.
func reset_room(legacy_room: String) -> void:
	for landmark_id: StringName in _states:
		if GameContent.catalog().landmark(landmark_id).legacy_source_path == legacy_room:
			_states[landmark_id].reset()


## close_passage() once the call_out's time has passed in the world. The close
## line is seen in the landmark's room (message("vision", ..., this_object())).
func advance(delta: float) -> void:
	_carried_ms += maxf(0.0, delta) * 1000.0
	var elapsed: int = int(_carried_ms)
	_carried_ms -= elapsed
	for landmark_id: StringName in _states:
		var landmark: WorldLandmarkDefinition = GameContent.catalog().landmark(landmark_id)
		if _states[landmark_id].advance(elapsed, _player_below(landmark)):
			_apply(landmark, false)
			var location: WorldLocationState = _session.player_runtime().world_location()
			if location != null and location.zone_id == landmark.zone_id:
				_session.shared_ui().append_log_lines([TranslationServer.translate(landmark.message("close"))])
			# tunnel4.c close_passage(): east_castle sees its slab fall back.
			elif location != null and not landmark.message("close_beyond").is_empty() and location.zone_id == _below_zone(landmark):
				_session.shared_ui().append_log_lines([TranslationServer.translate(landmark.message("close_beyond"))])
			# jitan.c close_passage(): the room below sees its stairs go back up.
			elif location != null and landmark.policy == &"dial" and location.zone_id == _below_zone(landmark):
				_session.shared_ui().append_log_lines([TranslationServer.translate(landmark.message("close_below"))])


func _apply(landmark: WorldLandmarkDefinition, open: bool) -> void:
	for portal_id: StringName in landmark.portal_ids():
		var portal: PortalDefinition = GameContent.catalog().portal(portal_id)
		var map: WorldResidentMapController = null if portal == null else _session.resident_map(portal.source_map_id)
		if map != null:
			map.set_portal_open(portal_id, open)


## The player stands where the passage's way down leads (and it has a way back up:
## a single way there closes whoever stands beyond it, as road6.c's grass). A dial's
## way shuts on them all the same: they open it from below; so does one that closes on time
## (tunnel4.c's slab: up there one never needs it).
func _player_below(landmark: WorldLandmarkDefinition) -> bool:
	if landmark.portal_ids().size() < 2 or landmark.policy == &"dial" or landmark.setting("closes_on_time") == 1:
		return false
	var location: WorldLocationState = _session.player_runtime().world_location()
	return location != null and location.zone_id == _below_zone(landmark)


## Where the landmark's way down leads.
func _below_zone(landmark: WorldLandmarkDefinition) -> StringName:
	var down: PortalDefinition = GameContent.catalog().portal(landmark.portal_id)
	return &"" if down == null else down.destination_zone_id
