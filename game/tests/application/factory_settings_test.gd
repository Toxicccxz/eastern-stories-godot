extends RefCounted

## 出厂设置: the game as a player gets it, every switch the suite runner turns off turned back
## on (run_suite.gd: the day, the gangs' alert beat, the time nobody watches, the modern death
## price and the autosave, the feel; the fight waiting for orders, its opening, 击倒后 询问), the
## settings at their defaults, through the shell's own New Game. The other suites each turn on
## what they are about; this one has them all on together, so a rule that breaks only when the
## others run beside it (夜里存不了档, 夜里读档的人站成清晨) shows here.
##
## The way, twice. First with the worlds built in one frame (TestFeel.use()): the theme story's
## card, then up the 饮风客栈's stairs on foot (the map change autosaves) and a fight with a rat
## by orders; then a fight that lasts (a rat made hardy, TEST-ONLY): three waits for an order at
## least, a 收势 or a 拍不够, and the 了结 / 放过 question asked on its card and answered there;
## then out onto the square, the evening waited for, a save by hand on the street at night with
## people gone home, and that save read back: the night, the place, and on the player's map each
## person in the room they were in, in or out as they were, nobody walking out after. Then the
## same way again with pacing.json's slices (TestFeel.use_shipped()): New Game started over frames,
## each map's world built over frames behind the loading screen, the load through the worker
## thread. Last, with the slices, a save, a load and a return to the main menu each made while a
## map is still being built, and a Continue from there.
##
## Each New Game has fixed seeds (the session's deterministic_* switches), so a failure reruns.
const MemoryFiles = preload("res://tests/application/application_shell_test.gd").MemoryFiles
const SHELL = preload("res://scenes/application/application_shell.tscn")
const SLOT_1: StringName = &"slot-1"
const NIGHT: Array[StringName] = [&"night", &"midnight"]
const HOLD: StringName = WorldSessionController.WORLD_BUILD_HOLD
## The 饮风客栈's ground floor, where New Game begins.
const INN_MAP: StringName = &"snow.inn"
## Real frames (1/60 s each under --fixed-fps 60) a step may take before it counts as stalled.
const FIGHT_FRAMES: int = 60 * 180
const SETTLE_FRAMES: int = 60 * 30
## The hardy rat (TEST-ONLY): 气 enough in effect that no wound kills it, little of it now, so
## blows fell it (昏倒) before any kills it, and it takes rounds.
const HARDY_KEE: int = 5000
const HARDY_KEE_NOW: int = 120
## A 60 fps frame's time, given the worker threads while the host waits on them.
const FRAME_IDLE_MS: int = 16

var _count: int = 0
## The last save by hand's result, for a failure's message.
var _saved_as: String = ""
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	var before: Array = _battle_settings()
	_factory()
	_check_factory_pacing()
	await _play(tree, false)
	# pacing.json's feel whole: the start and each map's world built over frames.
	TestFeel.use_shipped()
	_check(GameContent.catalog().pacing().feel.map_loading_slice_seconds > 0.0 and GameContent.catalog().pacing().feel.session_start_slice_seconds > 0.0, "pacing.json builds the worlds in slices")
	await _play(tree, true)
	await _mid_build(tree)
	_restore(before)
	return {"assertions": _count, "failures": _failures}


# --- The switches --------------------------------------------------------------------

## What run_suite.gd and the settings set, as they were.
func _battle_settings() -> Array:
	return [BattlePace.speed, BattlePace.hit_flash, BattlePace.after_knockout, BattlePace.opening, BattlePace.manual_turns, ObjectiveHints.shown, DayNightPreference.mode, AutosaveNotice.shown]


func _factory() -> void:
	TestFeel.use()
	TestAway.use()
	TestAlert.use()
	TestDay.use()
	TestDeath.use()
	ApplicationSettingsService._apply_battle(ApplicationSettingsSnapshot.defaults())
	BattlePace.manual_turns = true


func _restore(before: Array) -> void:
	TestDeath.restore()
	TestDay.restore()
	TestAlert.restore()
	TestAway.restore()
	TestFeel.restore()
	BattlePace.speed = before[0]
	BattlePace.hit_flash = before[1]
	BattlePace.after_knockout = before[2]
	BattlePace.opening = before[3]
	BattlePace.manual_turns = before[4]
	ObjectiveHints.shown = before[5]
	DayNightPreference.mode = before[6]
	AutosaveNotice.shown = before[7]


## Every knob as pacing.json sets it, not as a suite left it. Es2Pacing.use_reactions() keeps the
## game's fight (it once made a record of its own, and seven suites fought ES2's fights unseen).
func _check_factory_pacing() -> void:
	var pacing: PacingDefinition = GameContent.catalog().pacing()
	_check(pacing.day_length_minutes < TestDay.STILL_MINUTES and pacing.hostile_alert_seconds > 0.0 and pacing.away_wander_moves > 0 and pacing.corpse_rot_seconds > 0, "the day turns, the gangs shout first, people move and corpses rot while nobody watches")
	_check(pacing.autosave_min_seconds > 0 and pacing.death_exp_percent < PacingDefinition.ES2_DEATH_EXP_PERCENT and pacing.death_keeps_skills, "the autosave and the modern death price")
	_check(not pacing.es2_npc_values and pacing.combat_forecast and pacing.decision_rules().player_turns and pacing.beat_rules().round_beats > 1, "the modern fight: NPCs' own values, the forecast, orders, beats")
	_check(pacing.feel.map_fade_out_seconds > 0.0 and BattlePace.after_knockout == BattlePace.AfterKnockout.ASK and BattlePace.opening == BattlePace.Opening.FULL, "the feel, 击倒后 询问 and the full opening")
	var game: PacingDefinition = Es2Pacing.use_reactions()
	var reactions: PacingDefinition = GameContent.catalog().pacing()
	_check(reactions != game and not reactions.es2_npc_values and reactions.decision_rules().player_turns and reactions.beat_rules().round_beats == game.beat_rules().round_beats and reactions.story_parley and reactions.stealth, "Es2Pacing.use_reactions() keeps the game's fight and story, only the responsiveness at ES2's")
	Es2Pacing.restore(game)


# --- The shell -----------------------------------------------------------------------

## A shell on memory files, its New Game's session seeded as it comes into the tree.
func _shell(tree: SceneTree, files: MemoryFiles, profile: GameSaveStorageProfile) -> ApplicationShellController:
	var shell: ApplicationShellController = SHELL.instantiate()
	shell.configure_before_start(profile, files, null, MemoryFiles.new())
	tree.root.add_child(shell)
	await _frames(tree, 8)
	shell.runtime_host().session_slot.child_entered_tree.connect(_seed)
	return shell


## Fixed seeds for a New Game (a Continue takes its draws from the save).
func _seed(node: Node) -> void:
	var session: WorldSessionController = node as WorldSessionController
	if session != null and not session.is_initialized():
		session.deterministic_npc_seed = true
		session.deterministic_combat_seed = true
		session.deterministic_world_interaction_seed = true


## The shell's New Game, through to the world running past the theme story's card.
func _new_game(tree: SceneTree, shell: ApplicationShellController, files: MemoryFiles, profile: GameSaveStorageProfile, sliced: bool) -> WorldSessionController:
	if shell.request_new_game_from_menu() and shell.shell_state().mode() == ApplicationShellState.Mode.RESULT:
		shell.confirm_current_result()
	shell.player_name_edit.text = "凌雪"
	shell.select_new_game_gender(CharacterState.GENDER_FEMALE)
	_check(shell.submit_new_game_setup(), "New Game")
	var frames: int = await _until_playing(tree, shell)
	var host: OldPineGameRuntimeHost = shell.runtime_host()
	var session: WorldSessionController = host.current_session()
	if not _check(session != null and session.shared_ui() != null, "playing"):
		return null
	_check(session.deterministic_npc_seed and session.deterministic_combat_seed and session.deterministic_world_interaction_seed, "New Game seeded: a failure reruns as it ran")
	if sliced:
		_check(session.start_slice_usec > 0 and frames > 2, "New Game started over frames: %d frames, %d µs a frame" % [frames, session.start_slice_usec])
		_check(session._worlds_built >= 1, "and its first world built behind the cover")
	var overlay: PlayerLifeOverlay = session.shared_ui().life_overlay
	_check(overlay.card_shown() and session.world_time_held(), "the theme story's card over the first moment, world time held")
	overlay.go_on()
	await _frames(tree, 2)
	_check(not session.world_time_held(), "继续: the world runs")
	_check(not files.files.has(profile.for_slot(GameSaveSnapshot.AUTO_SLOT_ID).canonical_path()), "no autosave before the first moment")
	return session


## Frames until the shell plays a session whose start and first world are done; how many.
func _until_playing(tree: SceneTree, shell: ApplicationShellController) -> int:
	var frames: int = 0
	while frames < SETTLE_FRAMES:
		await _frame(tree, shell)
		frames += 1
		var session: WorldSessionController = shell.runtime_host().current_session()
		if shell.shell_state().mode() == ApplicationShellState.Mode.PLAYING and session != null and session.start_finished() and _shown(session):
			break
	return frames


## The player's map's world is up and the loading screen gone (no build holding the world).
func _shown(session: WorldSessionController) -> bool:
	var map: WorldMapController = session.active_map() as WorldMapController
	var view: WorldVoxelView = null if map == null else map.get_node_or_null("MapView") as WorldVoxelView
	return (view == null or view._built) and not session.world_building() and not session.presentation_held(HOLD)


## Frames until `session`'s map world is shown (at once with the slices off); how many it took.
func _until_shown(tree: SceneTree, session: WorldSessionController) -> int:
	var frames: int = 0
	while not _shown(session) and frames < SETTLE_FRAMES:
		await tree.process_frame
		frames += 1
	return frames


# --- The way -------------------------------------------------------------------------

func _play(tree: SceneTree, sliced: bool) -> void:
	var files: MemoryFiles = MemoryFiles.new()
	var profile: GameSaveStorageProfile = GameSaveStorageProfile.isolated_test("factory-settings")
	var shell: ApplicationShellController = await _shell(tree, files, profile)
	var session: WorldSessionController = await _new_game(tree, shell, files, profile, sliced)
	if session == null:
		shell.free()
		return
	var host: OldPineGameRuntimeHost = shell.runtime_host()
	var built: int = session._worlds_built
	if await _rat(tree, session):
		if sliced:
			_check(session._worlds_built > built, "the stairs' map built over frames behind the cover (%d worlds built)" % session._worlds_built)
		var going_on: bool = true
		if not sliced:
			going_on = await _long_fight(tree, session)
		if going_on:
			await _autosaved(tree, host, files, profile)
			await _night_save_and_load(tree, shell, session, files, profile)
	shell.free()
	await _frames(tree, 8)


## The first autosave: a map change landed or a fight over, whichever came first with Save
## allowed (up the stairs a rat may fall on the player at once, and a fight skips the moment).
func _autosaved(tree: SceneTree, host: OldPineGameRuntimeHost, files: MemoryFiles, profile: GameSaveStorageProfile) -> void:
	var auto_path: String = profile.for_slot(GameSaveSnapshot.AUTO_SLOT_ID).canonical_path()
	var repository := SourceEntrySaveRepository.new(profile.for_slot(GameSaveSnapshot.AUTO_SLOT_ID), files)
	var saved: GameSaveResult = null
	var frames: int = 0
	# A second autosave (the rat's fight over) may be rotating the file as it is read (BACKUP_AVAILABLE
	# for that moment): read again once nothing is writing, until a whole save reads back.
	while frames < SETTLE_FRAMES:
		if not host.autosave().running() and files.files.has(auto_path):
			saved = repository.load()
			if saved.succeeded():
				break
		frames += 1
		await tree.process_frame
	if saved == null:
		saved = repository.load()
	_check(saved.succeeded() and saved.snapshot.player.world_location.map_id == &"snow.inn_upstairs", "autosaved upstairs, a whole save: %s" % ("whole" if saved.succeeded() else str(saved.outcome)))


## Up the stairs to the rats (the 新手链's 楼上) and a fight with one, by orders: the opening
## plays, the round waits for the player, each order the cheapest move to hand. A rat has little
## 气: one blow may end it, and a wound past its life kills outright (damage.c die()), so this
## fight may never ask 了结 / 放过; _long_fight() does.
func _rat(tree: SceneTree, session: WorldSessionController) -> bool:
	var upstairs: WorldMapController = await MapPlaces.go_to(tree, session, &"snow.inn_2f")
	if not _check(upstairs != null, "up the stairs on foot"):
		return false
	var rat: NpcRuntimeState = _nearest_rat(upstairs)
	if not _check(rat != null, "a rat upstairs"):
		return false
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	_check(CombatEncounterCoordinator.take_aborted_total() == 0, "no fight aborted before the rat")
	var rat_body: WorldCharacterBody2D = upstairs.runtime_body_for_character(rat.character_id)
	await MapPlaces.drive(tree, upstairs, MapPlaces.spot(upstairs, rat.world_location().zone_id, rat_body.global_position, 64.0))
	# A rat may have come at the player on the way (they are aggressive): that fight is the one.
	if not coordinator.has_active_encounter():
		upstairs.select_npc(rat.character_id)
		_check(upstairs.attack_selected().outcome == CombatSliceInitiationResult.Outcome.COMPLETED, "攻击 the rat")
	var fought: Dictionary = await _fight_by_orders(tree, session, &"", false)
	_check(not coordinator.has_active_encounter(), "the fight ends (%d frames, %d orders)" % [fought["frames"], fought["orders"]])
	_check(fought["orders"] >= 1 and fought["waits"] >= fought["orders"], "fought by orders, the round waiting for each: %d orders, %d waits" % [fought["orders"], fought["waits"]])
	_check(rat.life_status == CharacterRuntimeLifeStatus.Value.DEAD and coordinator.held_victims().is_empty(), "the rat dead, nobody left waiting on 了结 / 放过 (%d answered)" % fought["answered"])
	_check(CombatEncounterCoordinator.take_aborted_total() == 0, "no fight aborted")
	_check(session.player_runtime().life_status == CharacterRuntimeLifeStatus.Value.ACTIVE, "the player stands")
	return await _world_runs_on(tree, session)


## A fight sure to last (another rat, made hardy TEST-ONLY): rounds of orders, the round waiting
## for each, once 收势 pressed (or a move the beats left cannot pay, 拍不够), and the rat falls
## before any blow can kill it, so its card asks 了结 / 放过 and 了结 is pressed there.
func _long_fight(tree: SceneTree, session: WorldSessionController) -> bool:
	var upstairs: WorldMapController = session.active_map() as WorldMapController
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	var rat: NpcRuntimeState = _nearest_rat(upstairs)
	if not _check(rat != null and not coordinator.has_active_encounter(), "another rat, no fight under way"):
		return false
	var kee: CharacterResourceState = rat.character_state.vitality
	kee.maximum = HARDY_KEE
	kee.effective = HARDY_KEE
	kee.current = HARDY_KEE_NOW
	var rat_body: WorldCharacterBody2D = upstairs.runtime_body_for_character(rat.character_id)
	await MapPlaces.drive(tree, upstairs, MapPlaces.spot(upstairs, rat.world_location().zone_id, rat_body.global_position, 64.0))
	if not coordinator.has_active_encounter():
		upstairs.select_npc(rat.character_id)
		_check(upstairs.attack_selected().outcome == CombatSliceInitiationResult.Outcome.COMPLETED, "攻击 the hardy rat")
	var fought: Dictionary = await _fight_by_orders(tree, session, rat.character_id, true)
	print("factory settings: the long fight took %d waits, %d orders, %d 收势, %d 拍不够, %d asked, %d frames" % [fought["waits"], fought["orders"], fought["yields"], fought["short"], fought["asked"], fought["frames"]])
	_check(not coordinator.has_active_encounter(), "the long fight ends (%d frames)" % fought["frames"])
	_check(fought["waits"] >= 3 and fought["orders"] >= 3, "several rounds, each waiting for the player: %d waits, %d orders" % [fought["waits"], fought["orders"]])
	_check(fought["yields"] + fought["short"] >= 1, "收势 pressed or a move the beats left could not pay (拍不够): %d 收势, %d 拍不够" % [fought["yields"], fought["short"]])
	_check(fought["asked"] == 1 and fought["answered"] >= 1, "the fallen rat's card asked 了结 / 放过 and 了结 was pressed there (%d asked, %d answered)" % [fought["asked"], fought["answered"]])
	_check(rat.life_status == CharacterRuntimeLifeStatus.Value.DEAD and coordinator.held_victims().is_empty(), "了结: the rat dead, nobody waiting on the choice")
	_check(CombatEncounterCoordinator.take_aborted_total() == 0, "no fight aborted")
	_check(session.player_runtime().life_status == CharacterRuntimeLifeStatus.Value.ACTIVE, "the player stands")
	return await _world_runs_on(tree, session)


## The panel's hold over, as a player walks on after.
func _world_runs_on(tree: SceneTree, session: WorldSessionController) -> bool:
	var frames: int = 0
	while not session.npc_world_time_allowed() and frames < SETTLE_FRAMES:
		frames += 1
		await tree.process_frame
	return _check(session.npc_world_time_allowed(), "the world runs on after the fight")


func _nearest_rat(map: WorldMapController) -> NpcRuntimeState:
	var rat: NpcRuntimeState = null
	var nearest: float = INF
	var at: Vector2 = map.runtime_player_body().global_position
	for npc: NpcRuntimeState in map.npc_runtimes():
		var body: WorldCharacterBody2D = map.runtime_body_for_character(npc.character_id)
		if npc.definition().definition_id == &"snow.npc.rat" and npc.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE and npc.exists_in_map and body != null and body.global_position.distance_to(at) < nearest:
			rat = npc
			nearest = body.global_position.distance_to(at)
	return rat


## The fight under way, fought on the battle panel as a player does: the cheapest move to hand
## pressed on its button when the round waits; with `yield_once`, 收势 pressed once a round has a
## beat spent; one who falls answered on their card with 了结. Counts what happened: frames, waits
## (each time the round came to wait), orders taken, 收势 taken, waits with a move 拍不够, and the
## 了结 / 放过 questions asked of `watched` and answered.
func _fight_by_orders(tree: SceneTree, session: WorldSessionController, watched: StringName, yield_once: bool) -> Dictionary:
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	var ui: BattlePresentationController = session.get_node("BattlePresentationLayer/BattleSurface")
	var counts: Dictionary = {"frames": 0, "waits": 0, "orders": 0, "yields": 0, "short": 0, "asked": 0, "answered": 0}
	var asked: Dictionary[StringName, bool] = {}
	var waiting: bool = false
	var orders_this_wait: int = 0
	while coordinator.has_active_encounter() and counts["frames"] < FIGHT_FRAMES:
		var held: Array[StringName] = coordinator.held_victims()
		if not held.is_empty():
			var card: BattleParticipantCard = _card(ui, held[0])
			if card != null and card.choice_row.visible and card.finish_button.visible:
				if held[0] == watched and not asked.has(held[0]):
					counts["asked"] += 1
				asked[held[0]] = true
				card.finish_button.pressed.emit()
				if not coordinator.held_victims().has(held[0]):
					counts["answered"] += 1
			elif coordinator.finish_downed(held[0]):
				# Another who fell (not the one watched), its card not drawn yet: 了结 as before.
				counts["answered"] += 1
		elif coordinator.waiting_for_player():
			if not waiting:
				counts["waits"] += 1
				orders_this_wait = 0
				if not coordinator.unaffordable_moves().is_empty():
					counts["short"] += 1
			waiting = true
			ui.refresh_projection()
			var panel: BattleActionPanel = ui.action_panel
			var move: StringName = _affordable_move(coordinator)
			var yield_now: bool = yield_once and counts["yields"] == 0 and counts["orders"] >= 1 and counts["waits"] >= 2
			if (move.is_empty() or yield_now) and panel.yield_button.visible and not panel.yield_button.disabled:
				panel.yield_button.pressed.emit()
				if not coordinator.waiting_for_player():
					counts["yields"] += 1
					waiting = false
			elif move.is_empty():
				coordinator.yield_round()
				waiting = false
			elif panel.move_buttons.has(move):
				panel.move_buttons[move].pressed.emit()
				if not coordinator.waiting_for_player():
					counts["orders"] += 1
					waiting = false
		counts["frames"] += 1
		await tree.process_frame
	return counts


func _card(ui: BattlePresentationController, character_id: StringName) -> BattleParticipantCard:
	ui.refresh_projection()
	ui._present_participants()
	var index: int = ui._shown_participants.find(character_id)
	return null if index < 0 else ui._cards[index]


## The cheapest of the player's moves they can give now (none: 收势).
func _affordable_move(coordinator: CombatEncounterCoordinator) -> StringName:
	var locked: Dictionary[StringName, String] = coordinator.locked_moves()
	var short: Dictionary[StringName, String] = coordinator.unaffordable_moves()
	var best: StringName = &""
	var best_cost: int = 1 << 30
	for move: CombatActionDefinition in coordinator.player_moves():
		if locked.has(move.action_id) or short.has(move.action_id):
			continue
		var cost: int = coordinator.move_cost(move.action_id)
		if cost < best_cost:
			best = move.action_id
			best_cost = cost
	return best


## The evening waited for, back on the square: people go home; a save by hand on the street at
## night, then that save read back over the world (读档): the night, the place, and on the player's
## map each person as they were, in their room, in or out; a few seconds on, nobody walks out.
func _night_save_and_load(tree: SceneTree, shell: ApplicationShellController, session: WorldSessionController, files: MemoryFiles, profile: GameSaveStorageProfile) -> void:
	var square: WorldMapController = await MapPlaces.go_to(tree, session, &"snow.square")
	if not _check(square != null, "back on the square"):
		return
	_check(session.wait_until_phase([&"night"]) and NIGHT.has(session.day_phase_id()), "night falls (%s)" % session.day_phase_id())
	# A few seconds of the night: those going home walk (a walk in hand once kept Save shut).
	await _frames(tree, 60 * 4)
	var saved: bool = false
	for attempt: int in 10:
		if OldPineSaveEligibility.inspect(session).allowed():
			saved = await _save_by_hand(tree, shell, 0)
			break
		await _frames(tree, 60)
	if not _check(saved and files.files.has(profile.for_slot(SLOT_1).canonical_path()), "Save at night on the street (allowed: %s, %s)" % [OldPineSaveEligibility.inspect(session).outcome, _saved_as]):
		return
	var written: GameSaveResult = SourceEntrySaveRepository.new(profile.for_slot(SLOT_1), files).load()
	if not _check(written.succeeded(), "the night's save reads"):
		return
	var at_save: GameSaveSnapshot = written.snapshot
	var map_id: StringName = at_save.player.world_location.map_id
	var indoors: Array[StringName] = _gone_home(at_save, map_id)
	_check(not indoors.is_empty(), "someone on %s had gone home when the night's save was made: %s" % [map_id, indoors])
	# The world goes on a little before the player thinks better of it.
	await _frames(tree, 60 * 2)
	_check(shell.request_pause() and shell.request_load_slots() and shell.choose_slot_row(0) and shell.confirm_current_result(), "系统 → 读档 → the first row, 读取")
	await _until_playing(tree, shell)
	var loaded: WorldSessionController = shell.runtime_host().current_session()
	if not _check(loaded != null and loaded != session and shell.shell_state().mode() == ApplicationShellState.Mode.PLAYING, "the save read back, a new world, playing"):
		return
	_check(NIGHT.has(loaded.day_phase_id()) and absi(loaded.day_clock().day_seconds() - at_save.day_seconds) < 120, "still the night it was saved in (%s, %d s against %d s)" % [loaded.day_phase_id(), loaded.day_clock().day_seconds(), at_save.day_seconds])
	_check(loaded.player_runtime().world_location().zone_id == at_save.player.world_location.zone_id, "on the street where the save was made")
	var moved: Array[String] = _placed_otherwise(at_save, loaded, map_id)
	_check(moved.is_empty(), "on %s each person where the night's save had them, in or out, not where the morning would: %s" % [map_id, moved.slice(0, 6)])
	# A few seconds of the read-back night: those indoors stay in.
	await _frames(tree, 60 * 4)
	var out: Array[StringName] = []
	for character_id: StringName in indoors:
		var npc: NpcRuntimeState = _npc(loaded, map_id, character_id)
		if npc == null or npc.exists_in_map:
			out.append(character_id)
	_check(NIGHT.has(loaded.day_phase_id()) and out.is_empty(), "a few seconds on, nobody who had gone home walks out: %s" % [out])
	await _frames(tree, 30)
	_check(OldPineSaveEligibility.inspect(loaded).allowed(), "and the read-back night can be saved again")


## 系统 → 存档 → row `row`: whether the save was written. Back to playing either way.
func _save_by_hand(tree: SceneTree, shell: ApplicationShellController, row: int) -> bool:
	_check(shell.request_pause() and shell.request_save_slots() and shell.choose_slot_row(row), "系统 → 存档 → row %d" % row)
	var frames: int = 0
	while shell.shell_state().mode() == ApplicationShellState.Mode.SAVING and frames < SETTLE_FRAMES:
		await _frame(tree, shell)
		frames += 1
	await _frames(tree, 2)
	var result: ApplicationOperationResult = shell.last_result()
	var saved: bool = result != null and result.succeeded()
	_saved_as = "none" if result == null else "%s (%d)" % [result.message_key(), result.outcome()]
	shell.dismiss_current_result()
	shell.request_resume()
	await _frames(tree, 2)
	return saved


## Those on `map_id` the save has alive, indoors for the night (an ordinary street person the night
## sends home, off the map).
func _gone_home(save: GameSaveSnapshot, map_id: StringName) -> Array[StringName]:
	var pacing: PacingDefinition = GameContent.catalog().pacing()
	var found: Array[StringName] = []
	for record: GameSaveValueTypes.NpcSpawnStateSnapshot in save.npc_spawn_states:
		var spawn: NpcSpawnDefinition = GameContent.catalog().spawn(record.spawn_id)
		if record.world_location == null or record.world_location.map_id != map_id or spawn == null:
			continue
		if not record.exists_in_world and record.life_status != &"dead" and WorldMapNpcIdle.goes_home_at_night(spawn, pacing):
			found.append(record.character_id)
	return found


## Each person the save has on `map_id` against the read-back world: present or not, their room,
## alive or not. No tolerance: one placed as at dawn is a difference.
func _placed_otherwise(save: GameSaveSnapshot, loaded: WorldSessionController, map_id: StringName) -> Array[String]:
	var differences: Array[String] = []
	var people: int = 0
	for record: GameSaveValueTypes.NpcSpawnStateSnapshot in save.npc_spawn_states:
		if record.world_location == null or record.world_location.map_id != map_id:
			continue
		people += 1
		var npc: NpcRuntimeState = _npc(loaded, map_id, record.character_id)
		if npc == null:
			differences.append("%s missing" % record.character_id)
		elif npc.exists_in_map != record.exists_in_world or npc.world_location().zone_id != record.world_location.zone_id:
			differences.append("%s %s/%s → %s/%s" % [record.character_id, "in" if record.exists_in_world else "out", record.world_location.zone_id, "in" if npc.exists_in_map else "out", npc.world_location().zone_id])
	if people == 0:
		differences.append("nobody on %s in the save" % map_id)
	return differences


func _npc(session: WorldSessionController, map_id: StringName, character_id: StringName) -> NpcRuntimeState:
	var map: WorldMapController = session.world_map_of(map_id)
	if map == null:
		return null
	for npc: NpcRuntimeState in map.npc_runtimes():
		if npc.character_id == character_id:
			return npc
	return null


# --- While a map is being built ------------------------------------------------------

## With the slices on, a map's world goes up over frames behind the loading screen, and the pause
## key still opens 系统 (the shell takes it while playing). A save made then, a load made then, and
## a return to the main menu made then: each comes to an end, nothing stays held or dark, and the
## save made mid-build reads back whole and Continues.
func _mid_build(tree: SceneTree) -> void:
	var files: MemoryFiles = MemoryFiles.new()
	var profile: GameSaveStorageProfile = GameSaveStorageProfile.isolated_test("factory-settings-mid-build")
	var shell: ApplicationShellController = await _shell(tree, files, profile)
	var session: WorldSessionController = await _new_game(tree, shell, files, profile, true)
	if session == null:
		shell.free()
		return
	# Save: out of the inn onto the street, 系统 → 存档 while the street's world goes up.
	if await _out_mid_build(tree, session, "the save"):
		var saved: bool = await _save_by_hand(tree, shell, 0)
		var written: GameSaveResult = SourceEntrySaveRepository.new(profile.for_slot(SLOT_1), files).load()
		_check(saved and written.succeeded() and written.snapshot.player.world_location.map_id == session.active_map_id(), "a save made mid-build is written and reads back, on the new map: %s, %s" % [_saved_as, "whole" if written.succeeded() else str(written.outcome)])
		_check(await _until_shown(tree, session) < SETTLE_FRAMES and not session.world_time_held() and _walks(session), "the build goes on to the end after it, nothing held")
	# Load: back into the inn, 系统 → 读档 of that save while the inn's world goes up.
	var inn: WorldMapController = await _back_in(tree, session)
	if inn != null and _check(session.world_building(), "the inn's world goes up (for the load)"):
		_check(shell.request_pause() and shell.request_load_slots() and shell.choose_slot_row(0) and shell.confirm_current_result(), "系统 → 读档 mid-build")
		await _until_playing(tree, shell)
		var loaded: WorldSessionController = shell.runtime_host().current_session()
		if _check(loaded != null and loaded != session and shell.shell_state().mode() == ApplicationShellState.Mode.PLAYING, "a load made mid-build reads back: a new world, playing"):
			_check(_shown(loaded) and not loaded.world_time_held() and _walks(loaded) and not tree.paused, "the loaded world is up, nothing held, the player walks")
			session = loaded
	# Return to the main menu: (the save read back stands on the street) in, then out again,
	# 系统 → 回主菜单 while the street goes up.
	if session.active_map_id() != INN_MAP:
		await _back_in(tree, session)
		await _until_shown(tree, session)
	if await _out_mid_build(tree, session, "the return"):
		_check(shell.request_pause() and shell.request_return_to_main_menu() and shell.confirm_current_result(), "系统 → 回主菜单 mid-build, confirmed")
		var frames: int = 0
		while shell.shell_state().mode() != ApplicationShellState.Mode.MAIN_MENU and frames < SETTLE_FRAMES:
			await _frame(tree, shell)
			frames += 1
		_check(shell.shell_state().mode() == ApplicationShellState.Mode.MAIN_MENU and shell.runtime_host().current_session() == null and not tree.paused, "the main menu, no world left, nothing paused")
		# And from there the save made mid-build Continues.
		_check(shell.continue_enabled() and shell.request_continue_from_menu(), "继续 from the main menu")
		await _until_playing(tree, shell)
		var continued: WorldSessionController = shell.runtime_host().current_session()
		_check(continued != null and shell.shell_state().mode() == ApplicationShellState.Mode.PLAYING and _shown(continued) and not continued.world_time_held() and _walks(continued), "Continue: playing the save made mid-build, nothing held")
	shell.free()
	await _frames(tree, 8)


## From the inn out through its door onto the street, the walk stopping as the street's world
## starts to go up behind the cover. Whether it is under way (the street not built yet: the
## suite's sessions keep no world they did not build).
func _out_mid_build(tree: SceneTree, session: WorldSessionController, what: String) -> bool:
	var map: WorldMapController = session.active_map() as WorldMapController
	var chain: Array[PortalDefinition] = MapPlaces.portal_chain(map.map_id(), MapPlaces.map_of(&"snow.square"))
	if not _check(chain.size() == 1, "%s: one door from the inn to the street" % what):
		return false
	_release_world(session, MapPlaces.map_of(&"snow.square"))
	if session.player_runtime().world_location().zone_id != chain[0].source_zone_id:
		await MapPlaces.drive_to_zone(tree, map, chain[0].source_zone_id)
	await MapPlaces.take_passage(tree, map, chain[0].portal_id)
	var frames: int = 0
	while not session.world_building() and frames < 120:
		await tree.process_frame
		frames += 1
	return _check(session.active_map_id() == MapPlaces.map_of(&"snow.square") and session.world_building(), "%s: the street's world going up behind the cover" % what)


## Back through the inn's door, stopping as the inn's world starts to go up.
func _back_in(tree: SceneTree, session: WorldSessionController) -> WorldMapController:
	var map: WorldMapController = session.active_map() as WorldMapController
	await _until_shown(tree, session)
	var chain: Array[PortalDefinition] = MapPlaces.portal_chain(map.map_id(), INN_MAP)
	if not _check(chain.size() == 1, "one door back into the inn"):
		return null
	_release_world(session, INN_MAP)
	if session.player_runtime().world_location().zone_id != chain[0].source_zone_id:
		await MapPlaces.drive_to_zone(tree, map, chain[0].source_zone_id)
	await MapPlaces.take_passage(tree, map, chain[0].portal_id)
	var frames: int = 0
	while not session.world_building() and frames < 120:
		await tree.process_frame
		frames += 1
	return session.active_map() as WorldMapController


## A map's voxel world let go (as the session lets the oldest go past voxel_worlds_kept), so the
## next arrival builds it.
func _release_world(session: WorldSessionController, map_id: StringName) -> void:
	var map: WorldMapController = session.world_map_of(map_id)
	var view: WorldVoxelView = null if map == null else map.get_node_or_null("MapView") as WorldVoxelView
	if view != null:
		view.release_world()


func _walks(session: WorldSessionController) -> bool:
	var map: WorldMapController = session.active_map() as WorldMapController
	return map != null and not map.player_body.walk_paused


## One frame. While the host has work on a worker thread (a save, a load, the look at the saves,
## with the slices on), first the idle a frame leaves the main thread in the game: under
## --fixed-fps the frames come back to back, and a paused world's are so light that they starve
## the worker (a save by hand waited past 30 s that way; with real frames it takes seconds).
func _frame(tree: SceneTree, shell: ApplicationShellController) -> void:
	if shell.runtime_host() != null and shell.runtime_host().request_pending():
		OS.delay_msec(FRAME_IDLE_MS)
	await tree.process_frame


func _frames(tree: SceneTree, count: int) -> void:
	for _frame: int in count:
		await tree.process_frame


func _check(condition: bool, label: String) -> bool:
	_count += 1
	if not condition:
		_failures.append(label)
	return condition
