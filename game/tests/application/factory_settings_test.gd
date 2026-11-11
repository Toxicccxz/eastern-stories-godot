extends RefCounted

## 出厂设置: the game as a player gets it, every switch the suite runner turns off turned back
## on (run_suite.gd: the day, the gangs' alert beat, the time nobody watches, the modern death
## price and the autosave, the feel; the fight waiting for orders, its opening, 击倒后 询问), the
## settings at their defaults, through the shell's own New Game. The other suites each turn on
## what they are about; this one has them all on together, so a rule that breaks only when the
## others run beside it (夜里存不了档, 夜里读档的人站成清晨) shows here.
##
## The way: the theme story's card, then up the 饮风客栈's stairs on foot (the map change
## autosaves) and a fight with a rat by orders, the round waiting for each, 了结 asked; then out
## onto the square, the evening waited for, a save by hand on the street at night, and that save
## read back: the night, the place, and everyone where they stood.
const MemoryFiles = preload("res://tests/application/application_shell_test.gd").MemoryFiles
const SHELL = preload("res://scenes/application/application_shell.tscn")
const SLOT_1: StringName = &"slot-1"
const NIGHT: Array[StringName] = [&"night", &"midnight"]
## Real frames (1/60 s each under --fixed-fps 60) a step may take before it counts as stalled.
const FIGHT_FRAMES: int = 60 * 180
const SETTLE_FRAMES: int = 60 * 30

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	var before: Array = _battle_settings()
	_factory()
	_check_factory_pacing()
	await _play(tree)
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


# --- The way -------------------------------------------------------------------------

func _play(tree: SceneTree) -> void:
	var files: MemoryFiles = MemoryFiles.new()
	var profile: GameSaveStorageProfile = GameSaveStorageProfile.isolated_test("factory-settings")
	var shell: ApplicationShellController = SHELL.instantiate()
	shell.configure_before_start(profile, files, null, MemoryFiles.new())
	tree.root.add_child(shell)
	await _frames(tree, 8)
	if shell.request_new_game_from_menu() and shell.shell_state().mode() == ApplicationShellState.Mode.RESULT:
		shell.confirm_current_result()
	shell.player_name_edit.text = "凌雪"
	shell.select_new_game_gender(CharacterState.GENDER_FEMALE)
	_check(shell.submit_new_game_setup(), "New Game")
	await _frames(tree, 8)
	var host: OldPineGameRuntimeHost = shell.runtime_host()
	var session: WorldSessionController = host.current_session()
	if not _check(session != null and session.shared_ui() != null, "playing"):
		shell.free()
		return
	var overlay: PlayerLifeOverlay = session.shared_ui().life_overlay
	_check(overlay.card_shown() and session.world_time_held(), "the theme story's card over the first moment, world time held")
	overlay.go_on()
	await _frames(tree, 2)
	_check(not session.world_time_held(), "继续: the world runs")
	_check(not files.files.has(profile.for_slot(GameSaveSnapshot.AUTO_SLOT_ID).canonical_path()), "no autosave before the first moment")
	if await _rat(tree, session):
		await _autosaved(tree, host, files, profile)
		await _night_save_and_load(tree, shell, session, files, profile)
	shell.free()
	await _frames(tree, 8)


## The first autosave: a map change landed or a fight over, whichever came first with Save
## allowed (up the stairs a rat may fall on the player at once, and a fight skips the moment).
func _autosaved(tree: SceneTree, host: OldPineGameRuntimeHost, files: MemoryFiles, profile: GameSaveStorageProfile) -> void:
	var auto_path: String = profile.for_slot(GameSaveSnapshot.AUTO_SLOT_ID).canonical_path()
	var frames: int = 0
	while (host.autosave().running() or not files.files.has(auto_path)) and frames < SETTLE_FRAMES:
		frames += 1
		await tree.process_frame
	var saved: GameSaveResult = SourceEntrySaveRepository.new(profile.for_slot(GameSaveSnapshot.AUTO_SLOT_ID), files).load()
	_check(saved.succeeded() and saved.snapshot.player.world_location.map_id == &"snow.inn_upstairs", "autosaved upstairs, a whole save: %s" % ("whole" if saved.succeeded() else str(saved.outcome)))


## Up the stairs to the rats (the 新手链's 楼上) and a fight with one, by orders: the opening
## plays, the round waits for the player, each order the cheapest move to hand; the rat that
## falls (and is not killed outright) waits on 了结 / 放过 (击倒后 询问), and 了结 it is.
func _rat(tree: SceneTree, session: WorldSessionController) -> bool:
	var upstairs: WorldMapController = await MapPlaces.go_to(tree, session, &"snow.inn_2f")
	if not _check(upstairs != null, "up the stairs on foot"):
		return false
	var rat: NpcRuntimeState = null
	var nearest: float = INF
	var at: Vector2 = upstairs.runtime_player_body().global_position
	for npc: NpcRuntimeState in upstairs.npc_runtimes():
		var body: WorldCharacterBody2D = upstairs.runtime_body_for_character(npc.character_id)
		if npc.definition().definition_id == &"snow.npc.rat" and npc.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE and body != null and body.global_position.distance_to(at) < nearest:
			rat = npc
			nearest = body.global_position.distance_to(at)
	if not _check(rat != null, "a rat upstairs"):
		return false
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	var aborted: int = CombatEncounterCoordinator.take_aborted_total()
	var rat_body: WorldCharacterBody2D = upstairs.runtime_body_for_character(rat.character_id)
	await MapPlaces.drive(tree, upstairs, MapPlaces.spot(upstairs, rat.world_location().zone_id, rat_body.global_position, 64.0))
	# A rat may have come at the player on the way (they are aggressive): that fight is the one.
	if not coordinator.has_active_encounter():
		upstairs.select_npc(rat.character_id)
		_check(upstairs.attack_selected().outcome == CombatSliceInitiationResult.Outcome.COMPLETED, "攻击 the rat")
	var orders: int = 0
	var waits: int = 0
	var finished: int = 0
	var frames: int = 0
	var waiting: bool = false
	while coordinator.has_active_encounter() and frames < FIGHT_FRAMES:
		var held: Array[StringName] = coordinator.held_victims()
		if not held.is_empty() and coordinator.finish_downed(held[0]):
			finished += 1
		elif coordinator.waiting_for_player():
			if not waiting:
				waits += 1
			waiting = true
			var move: StringName = _affordable_move(coordinator)
			if move.is_empty():
				coordinator.yield_round()
			elif coordinator.choose_attack(move):
				orders += 1
				waiting = false
		frames += 1
		await tree.process_frame
	_check(not coordinator.has_active_encounter(), "the fight ends (%d frames, %d orders)" % [frames, orders])
	_check(orders >= 2 and waits >= 2, "fought by orders, the round waiting for them: %d orders, %d waits" % [orders, waits])
	# A wound past its life kills outright (damage.c die()); one that only fells it waits on the choice.
	_check(rat.life_status == CharacterRuntimeLifeStatus.Value.DEAD and coordinator.held_victims().is_empty(), "the rat dead, nobody left waiting on 了结 / 放过 (%d 了结)" % finished)
	_check(CombatEncounterCoordinator.take_aborted_total() == aborted, "no fight aborted")
	_check(session.player_runtime().life_status == CharacterRuntimeLifeStatus.Value.ACTIVE, "the player stands")
	# The panel's hold over, as a player walks on after.
	frames = 0
	while not session.npc_world_time_allowed() and frames < SETTLE_FRAMES:
		frames += 1
		await tree.process_frame
	return _check(session.npc_world_time_allowed(), "the world runs on after the fight")


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
## night, then that save read back over the world (读档), the night and everyone where they were.
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
			_check(shell.request_pause() and shell.request_save_slots() and shell.choose_slot_row(0), "系统 → 存档 → the first row")
			await _frames(tree, 8)
			saved = shell.last_result() != null and shell.last_result().succeeded()
			shell.dismiss_current_result()
			shell.request_resume()
			await _frames(tree, 2)
			break
		await _frames(tree, 60)
	if not _check(saved and files.files.has(profile.for_slot(SLOT_1).canonical_path()), "Save at night on the street (allowed: %s)" % OldPineSaveEligibility.inspect(session).outcome):
		return
	var written: GameSaveResult = SourceEntrySaveRepository.new(profile.for_slot(SLOT_1), files).load()
	if not _check(written.succeeded(), "the night's save reads"):
		return
	var at_save: GameSaveSnapshot = written.snapshot
	# The world goes on a little before the player thinks better of it.
	await _frames(tree, 60 * 2)
	_check(shell.request_pause() and shell.request_load_slots() and shell.choose_slot_row(0) and shell.confirm_current_result(), "系统 → 读档 → the first row, 读取")
	await _frames(tree, 12)
	var loaded: WorldSessionController = shell.runtime_host().current_session()
	if not _check(loaded != null and loaded != session and shell.shell_state().mode() == ApplicationShellState.Mode.PLAYING, "the save read back, a new world, playing"):
		return
	_check(NIGHT.has(loaded.day_phase_id()) and absi(loaded.day_clock().day_seconds() - at_save.day_seconds) < 120, "still the night it was saved in (%s, %d s against %d s)" % [loaded.day_phase_id(), loaded.day_clock().day_seconds(), at_save.day_seconds])
	_check(loaded.player_runtime().world_location().zone_id == at_save.player.world_location.zone_id, "on the street where the save was made")
	var moved: Array[String] = []
	var people: int = 0
	for record: GameSaveValueTypes.NpcSpawnStateSnapshot in at_save.npc_spawn_states:
		var npc: NpcRuntimeState = MapPlaces.npc_at(loaded, record.spawn_point_id)
		if npc == null or record.world_location == null:
			continue
		people += 1
		if npc.world_location().zone_id != record.world_location.zone_id:
			moved.append("%s %s → %s" % [record.spawn_point_id, record.world_location.zone_id, npc.world_location().zone_id])
	_check(people > 0 and moved.size() * 20 <= people, "everyone where the night's save had them, not where the morning would (%d of %d moved: %s)" % [moved.size(), people, moved.slice(0, 5)])
	await _frames(tree, 30)
	_check(OldPineSaveEligibility.inspect(loaded).allowed(), "and the read-back night can be saved again")


func _frames(tree: SceneTree, count: int) -> void:
	for _frame: int in count:
		await tree.process_frame


func _check(condition: bool, label: String) -> bool:
	_count += 1
	if not condition:
		_failures.append(label)
	return condition
