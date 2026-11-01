extends RefCounted

## 现代基线 A (DECISIONS「存档位」「自动存档」「减轻死亡」): the slots through the shell: three
## to save in and the autosave's, never mixed; the list that reads files lightly; a Load in play
## that replaces the world or leaves it as it was, at the right pace; the autosave at its
## moments, skipped when it cannot, on its own thread; and the death card's way back to it.
const MemoryFiles = preload("res://tests/application/application_shell_test.gd").MemoryFiles
const SHELL = preload("res://scenes/application/application_shell.tscn")
const SLOT_1: StringName = &"slot-1"
const SLOT_2: StringName = &"slot-2"
const SLOT_3: StringName = &"slot-3"

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_newest()
	_summary_of_bad_text()
	_slot_ids()
	await _slots_stay_apart(tree)
	await _load_in_play(tree)
	await _pace_of_a_load_in_play(tree)
	await _saves_of_either_pace(tree)
	await _failed_row_leaves_the_menu_as_it_was(tree)
	TestDeath.use()
	await _autosave_moments(tree)
	await _autosave_rolls(tree)
	await _death_card_goes_back(tree)
	await _broken_autosave_keeps_the_card(tree)
	TestDeath.restore()
	await _no_autosave_when_off(tree)
	return {"assertions": _count, "failures": _failures}


func _newest() -> void:
	var older := GameSaveSlotSummary.new(SLOT_1, GameSaveSlotSummary.State.READY)
	older.saved_at_utc = "2026-10-31T10:00:00Z"
	var newer := GameSaveSlotSummary.new(GameSaveSnapshot.AUTO_SLOT_ID, GameSaveSlotSummary.State.READY)
	newer.saved_at_utc = "2026-10-31T11:00:00Z"
	var broken := GameSaveSlotSummary.new(SLOT_2, GameSaveSlotSummary.State.UNREADABLE)
	var empty := GameSaveSlotSummary.new(SLOT_3)
	_check(GameSaveSlotSummary.newest([older, broken, empty, newer], SLOT_1) == GameSaveSnapshot.AUTO_SLOT_ID, "继续 reads the newest, the autosave among them")
	_check(GameSaveSlotSummary.newest([empty, broken], SLOT_1) == SLOT_2, "with none whole, the one that holds something")
	_check(GameSaveSlotSummary.newest([empty, GameSaveSlotSummary.new(SLOT_2, GameSaveSlotSummary.State.EMPTY, true)], SLOT_1) == SLOT_2, "a slot with only a .bak counts as holding something")
	_check(GameSaveSlotSummary.newest([empty], SLOT_1) == SLOT_1, "with nothing, the fallback")


func _summary_of_bad_text() -> void:
	_check(GameSaveSlotSummary.of_text(SLOT_1, "not json", true, false).state == GameSaveSlotSummary.State.UNREADABLE, "not JSON: unreadable")
	_check(GameSaveSlotSummary.of_text(SLOT_1, "[]", true, false).state == GameSaveSlotSummary.State.UNREADABLE, "not an object: unreadable")
	_check(GameSaveSlotSummary.of_text(SLOT_1, "{\"metadata\": {\"format_id\": \"other\"}, \"player\": {}}", true, false).state == GameSaveSlotSummary.State.UNREADABLE, "another format: unreadable")
	var old: String = JSON.stringify({"metadata": {"format_id": GameSaveSnapshot.FORMAT_ID, "schema_version": GameSaveSnapshot.CURRENT_SCHEMA_VERSION - 1}, "player": {}, "world_content_revision": WorldContentRevision.serialized(WorldContentRevision.CURRENT_PUBLIC)})
	_check(GameSaveSlotSummary.of_text(SLOT_1, old, true, false).state == GameSaveSlotSummary.State.UNSUPPORTED, "an older schema: unsupported")
	var world: String = JSON.stringify({"metadata": {"format_id": GameSaveSnapshot.FORMAT_ID, "schema_version": GameSaveSnapshot.CURRENT_SCHEMA_VERSION}, "player": {}, "world_content_revision": WorldContentRevision.serialized(WorldContentRevision.Value.SOURCE_ENTRY_V1)})
	_check(GameSaveSlotSummary.of_text(SLOT_1, world, true, false).state == GameSaveSlotSummary.State.UNSUPPORTED, "an older world: unsupported")
	_check(GameSaveSlotSummary.of_text(SLOT_1, "{\"metadata\": {\"format_id\": 7}, \"player\": {}}", true, false).state == GameSaveSlotSummary.State.UNREADABLE, "a format of the wrong type: unreadable, no error")
	var typed: String = JSON.stringify({"metadata": {"format_id": GameSaveSnapshot.FORMAT_ID, "schema_version": "4"}, "player": {}, "world_content_revision": WorldContentRevision.serialized(WorldContentRevision.CURRENT_PUBLIC)})
	_check(GameSaveSlotSummary.of_text(SLOT_1, typed, true, false).state == GameSaveSlotSummary.State.UNSUPPORTED, "a schema of the wrong type: unsupported, no error")
	var ghost: String = JSON.stringify({"metadata": {"format_id": GameSaveSnapshot.FORMAT_ID, "schema_version": GameSaveSnapshot.CURRENT_SCHEMA_VERSION}, "player": {"identity": {}, "world_location": {}, "character": {"ghost": "yes"}}, "world_content_revision": WorldContentRevision.serialized(WorldContentRevision.CURRENT_PUBLIC)})
	_check(not GameSaveSlotSummary.of_text(SLOT_1, ghost, true, false).ghost, "a ghost mark of the wrong type: no error")


func _slot_ids() -> void:
	var profile: GameSaveStorageProfile = GameSaveStorageProfile.isolated_test("baseline-ids")
	_check(profile.canonical_path().ends_with("/slot-1-v1.json") and profile.for_slot(GameSaveSnapshot.AUTO_SLOT_ID).canonical_path().ends_with("/auto-v1.json"), "each slot has its own file")
	_check(profile.for_slot(SLOT_3).backup_path().ends_with("/slot-3-v1.json.bak") and profile.for_slot(SLOT_3).temp_path().ends_with("/slot-3-v1.json.tmp"), "and its own .bak and .tmp")
	_check(not profile.for_slot(&"slot-4").is_valid() and not profile.for_slot(GameSaveSnapshot.LEGACY_SLOT_ID).is_valid(), "no slot beyond the game's; the old one is not written")
	_check(GameSaveStorageProfile.release().canonical_path() == "user://save-data/release/slot-1-v1.json", "release keeps its folder")


## 存档 opens the list; three rows to save in, the autosave's greyed; an empty one saves at once,
## a used one asks, and 取消 is back on the list. Each file holds only its own.
func _slots_stay_apart(tree: SceneTree) -> void:
	var files: MemoryFiles = MemoryFiles.new()
	var profile: GameSaveStorageProfile = GameSaveStorageProfile.isolated_test("baseline-apart")
	var shell: ApplicationShellController = await _shell(tree, files, profile)
	_check(shell.load_button.disabled, "with no saves 读取存档 is off")
	await _new_game(tree, shell)
	var session: WorldSessionController = shell.runtime_host().current_session()
	var player: WorldPlayerRuntimeState = session.player_runtime()
	_check(shell.request_pause() and shell.request_save_slots(), "系统's 存档 opens the list")
	_check(shell.shell_state().mode() == ApplicationShellState.Mode.SLOT_LIST and shell.slot_panel.visible and tree.paused, "over the paused world")
	var buttons: Array[Button] = shell.slot_panel.buttons()
	_check(buttons.size() == 4 and buttons[3].disabled and not buttons[0].disabled, "three to save in; the autosave's row only shows")
	_check(buttons[0].text == "手动存档 1（空）", "an empty row says so: " + buttons[0].text)
	await tree.process_frame
	_check(tree.root.gui_get_focus_owner() == buttons[0], "keys and pad start on the first row")
	_check(shell.choose_slot_row(1), "an empty slot saves at once")
	await _frames(tree)
	_check(shell.last_result() != null and shell.last_result().succeeded(), "saved: %s" % shell.last_result())
	_check(files.files.has(profile.for_slot(SLOT_2).canonical_path()) and not files.files.has(profile.for_slot(SLOT_1).canonical_path()), "slot 2's file, and only it")
	shell.dismiss_current_result()
	player.state.progression.combat_experience = 777
	_check(shell.request_save_slots(), "the list again")
	await tree.process_frame
	var used: String = shell.slot_panel.buttons()[1].text
	_check(used.contains("手动存档 2") and used.contains("凌雪") and used.contains("雪亭镇"), "a used row says who and where: " + used)
	_check(shell.choose_slot_row(2), "slot 3 saves too")
	await _frames(tree)
	shell.dismiss_current_result()
	player.state.progression.combat_experience = 888
	_check(shell.request_save_slots() and shell.choose_slot_row(1), "a used slot")
	_check(shell.shell_state().mode() == ApplicationShellState.Mode.RESULT and shell.result_prompt.is_asking() and shell.result_label.text.contains("覆盖") and shell.result_prompt.detail.text.contains("凌雪"), "asks, naming what it replaces")
	await tree.process_frame
	_check(tree.root.gui_get_focus_owner() == shell.cancel_button, "the question starts on 取消")
	_check(shell.dismiss_current_result() and shell.shell_state().mode() == ApplicationShellState.Mode.SLOT_LIST, "取消: back on the list")
	_check(_exp(files, profile, SLOT_2) == 0, "and nothing was written")
	_check(shell.choose_slot_row(1) and shell.confirm_current_result(), "覆盖")
	await _frames(tree)
	_check(_exp(files, profile, SLOT_2) == 888 and _exp(files, profile, SLOT_3) == 777, "each slot holds its own save")
	_check(files.files.has(profile.for_slot(SLOT_2).backup_path()), "slot 2 keeps its .bak")
	_check(not files.files.has(profile.for_slot(SLOT_3).backup_path()), "slot 3 has none yet")
	shell.dismiss_current_result()
	_check(shell.request_save_slots() and shell.cancel_slots() and shell.shell_state().mode() == ApplicationShellState.Mode.PAUSED, "返回: the pause")
	shell.free()
	await _frames(tree)
	# The menu of a fresh start: the newest slot is selected, the broken one is named on its row.
	files.files[profile.for_slot(SLOT_1).canonical_path()] = "broken".to_utf8_buffer()
	shell = await _shell(tree, files, profile)
	_check(not shell.load_button.disabled, "with saves 读取存档 is on")
	_check(shell.continue_enabled() and shell.runtime_host().selected_slot() in [SLOT_2, SLOT_3], "继续 stands on a whole save: %s" % shell.runtime_host().selected_slot())
	_check(shell.request_load_slots(), "读取存档 opens the list")
	_check(shell.slot_panel.buttons()[0].text.contains("无法读取") and not shell.slot_panel.buttons()[0].disabled, "the broken row says so and can be looked into")
	_check(shell.slot_panel.buttons()[3].disabled, "the empty autosave row cannot be picked")
	_check(shell.choose_slot_row(0), "picking it")
	await _frames(tree)
	_check(shell.shell_state().mode() == ApplicationShellState.Mode.MAIN_MENU and not shell.continue_enabled() and shell.runtime_host().selected_slot() == SLOT_1, "the main menu says what is wrong with it")
	_check(shell.request_load_slots() and shell.choose_slot_row(2), "slot 3 from the list")
	await _frames(tree)
	_check(shell.shell_state().mode() == ApplicationShellState.Mode.PLAYING and shell.runtime_host().current_session().player_runtime().state.progression.combat_experience == 777, "starts the journey from it")
	shell.free()
	await _frames(tree)


## 读档 in play: asks, replaces the world, one Session in the slot, the old one gone.
func _load_in_play(tree: SceneTree) -> void:
	var files: MemoryFiles = MemoryFiles.new()
	var profile: GameSaveStorageProfile = GameSaveStorageProfile.isolated_test("baseline-load")
	var shell: ApplicationShellController = await _shell(tree, files, profile)
	await _new_game(tree, shell)
	var first: WorldSessionController = shell.runtime_host().current_session()
	first.player_runtime().state.progression.combat_experience = 500
	_check(shell.request_pause() and shell.request_save_slots() and shell.choose_slot_row(0), "saved in slot 1")
	await _frames(tree)
	shell.dismiss_current_result()
	first.player_runtime().state.progression.combat_experience = 900
	_check(shell.request_load_slots(), "系统's 读档 opens the list")
	_check(not shell.slot_panel.buttons()[0].disabled and shell.slot_panel.buttons()[1].disabled, "a used slot can be picked, an empty one not")
	_check(shell.choose_slot_row(0) and shell.result_prompt.is_asking() and shell.result_label.text.contains("丢失"), "asks: what is unsaved is lost")
	_check(shell.dismiss_current_result() and shell.shell_state().mode() == ApplicationShellState.Mode.SLOT_LIST, "取消: back on the list")
	_check(shell.cancel_slots(), "out of the list")
	_check(shell.request_load_slots() and shell.choose_slot_row(0) and shell.confirm_current_result(), "读取")
	await _frames(tree)
	var second: WorldSessionController = shell.runtime_host().current_session()
	_check(second != first and shell.shell_state().mode() == ApplicationShellState.Mode.PLAYING and not tree.paused, "a new Session, playing")
	_check(second.player_runtime().state.progression.combat_experience == 500, "as saved")
	_check(not is_instance_valid(first) or first.get_parent() == null, "the old one out of the slot")
	_check(shell.runtime_host().session_invariant_holds() and shell.runtime_host().session_slot.get_child_count() == 1, "one Session stands")
	# A bad file changes nothing.
	files.files[profile.canonical_path()] = "broken".to_utf8_buffer()
	_check(shell.request_pause() and shell.request_load_slots(), "the list")
	_check(shell.slot_panel.buttons()[0].disabled, "from play a broken save cannot be picked")
	_check(shell.cancel_slots(), "out of the list")
	shell.free()
	await _frames(tree)


## PacePresets: a Load in play builds the new Session beside the old one; the catalog ends on
## the new one's pace whichever it is, and on its own once they are gone.
func _pace_of_a_load_in_play(tree: SceneTree) -> void:
	var own: PacingDefinition = GameContent.catalog().pacing()
	var files: MemoryFiles = MemoryFiles.new()
	var profile: GameSaveStorageProfile = GameSaveStorageProfile.isolated_test("baseline-pace")
	var shell: ApplicationShellController = await _shell(tree, files, profile)
	await _new_game(tree, shell, CharacterState.PACE_CLASSIC)
	_check(GameContent.catalog().pacing() != own, "a classic world stands on its own pacing")
	_check(shell.request_pause() and shell.request_save_slots() and shell.choose_slot_row(0), "saved")
	await _frames(tree)
	shell.dismiss_current_result()
	_check(shell.request_load_slots() and shell.choose_slot_row(0) and shell.confirm_current_result(), "读取 the classic save over the classic world")
	await _frames(tree)
	var restored: WorldSessionController = shell.runtime_host().current_session()
	_check(restored != null and restored.player_runtime().state.pace == CharacterState.PACE_CLASSIC, "the classic character")
	_check(GameContent.catalog().pacing() != own and not GameContent.catalog().pacing().sky_weather and not GameContent.catalog().pacing().story_parley, "the catalog stays classic (the old Session's going does not put it back)")
	shell.free()
	await _frames(tree)
	_check(GameContent.catalog().pacing() == own, "with the Sessions gone, the catalog's own pacing")
	# A failed candidate leaves the world it would have replaced on its pace.
	var classic: PacingDefinition = PacePresets.apply(GameContent.catalog(), CharacterState.PACE_CLASSIC)
	var second: PacingDefinition = PacePresets.apply(GameContent.catalog(), CharacterState.PACE_MODERN)
	_check(classic == own and second == own, "each stands on the same base")
	PacePresets.restore(GameContent.catalog(), second, CharacterState.PACE_MODERN)
	_check(GameContent.catalog().pacing() != own and not GameContent.catalog().pacing().sky_weather, "the second gone, the first's pace again")
	PacePresets.restore(GameContent.catalog(), classic, CharacterState.PACE_CLASSIC)
	_check(GameContent.catalog().pacing() == own, "the last gone, the catalog's own")


## A save is checked under its own pace, not the catalog's: a classic save reads on the main
## menu of a fresh start (木人, the NPCs' classic values), and either pace over the other in play.
func _saves_of_either_pace(tree: SceneTree) -> void:
	var own: PacingDefinition = GameContent.catalog().pacing()
	var files: MemoryFiles = MemoryFiles.new()
	var profile: GameSaveStorageProfile = GameSaveStorageProfile.isolated_test("baseline-paces")
	var shell: ApplicationShellController = await _shell(tree, files, profile)
	await _new_game(tree, shell, CharacterState.PACE_CLASSIC)
	_check(shell.request_pause() and shell.request_save_slots() and shell.choose_slot_row(0), "a classic save in slot 1")
	await _frames(tree)
	shell.free()
	await _frames(tree)
	_check(GameContent.catalog().pacing() == own, "the catalog is modern again")
	shell = await _shell(tree, files, profile)
	_check(shell.continue_enabled(), "a fresh start: the classic save can be continued")
	await _new_game(tree, shell)
	_check(shell.request_pause() and shell.request_save_slots() and shell.choose_slot_row(1), "a modern save in slot 2, in a modern world")
	await _frames(tree)
	shell.dismiss_current_result()
	_check(shell.request_load_slots() and shell.choose_slot_row(0) and shell.confirm_current_result(), "the classic save over the modern world")
	await _frames(tree, 12)
	var classic: WorldSessionController = shell.runtime_host().current_session()
	_check(classic.player_runtime().state.pace == CharacterState.PACE_CLASSIC and not GameContent.catalog().pacing().training_dummies and not GameContent.catalog().pacing().sky_weather, "a classic world, on classic pacing")
	_check(shell.request_pause() and shell.request_load_slots() and shell.choose_slot_row(1) and shell.confirm_current_result(), "the modern save over the classic world")
	await _frames(tree, 12)
	var modern: WorldSessionController = shell.runtime_host().current_session()
	_check(modern != classic and modern.player_runtime().state.pace == CharacterState.PACE_MODERN and GameContent.catalog().pacing() == own, "a modern world, on the catalog's own pacing")
	shell.free()
	await _frames(tree)
	_check(GameContent.catalog().pacing() == own, "and it stays")


## A row that looks whole and does not load: told, and 继续 and 恢复 still mean the slot the
## menu spoke of.
func _failed_row_leaves_the_menu_as_it_was(tree: SceneTree) -> void:
	var files: MemoryFiles = MemoryFiles.new()
	var profile: GameSaveStorageProfile = GameSaveStorageProfile.isolated_test("baseline-row")
	var shell: ApplicationShellController = await _shell(tree, files, profile)
	await _new_game(tree, shell)
	shell.runtime_host().current_session().player_runtime().state.progression.combat_experience = 444
	_check(shell.request_pause() and shell.request_save_slots() and shell.choose_slot_row(1), "slot 2")
	await _frames(tree)
	shell.free()
	await _frames(tree)
	# Whole as JSON, wrong as a save, and older than slot 2.
	var text: String = files.files[profile.for_slot(SLOT_2).canonical_path()].get_string_from_utf8()
	files.files[profile.for_slot(SLOT_1).canonical_path()] = text.replace("\"day_seconds\"", "\"day_second\"").replace("\"saved_at_utc\": \"2", "\"saved_at_utc\": \"1").to_utf8_buffer()
	shell = await _shell(tree, files, profile)
	_check(shell.continue_enabled() and shell.runtime_host().selected_slot() == SLOT_2, "继续 stands on slot 2")
	_check(shell.request_load_slots() and not shell.slot_panel.buttons()[0].disabled and shell.choose_slot_row(0), "slot 1 from the list")
	await _frames(tree)
	_check(shell.shell_state().mode() == ApplicationShellState.Mode.RESULT and shell.runtime_host().current_session() == null, "it does not load, and says so")
	_check(shell.dismiss_current_result() and shell.continue_enabled(), "the menu again")
	_check(shell.request_continue_from_menu(), "继续")
	await _frames(tree)
	var session: WorldSessionController = shell.runtime_host().current_session()
	_check(session != null and session.player_runtime().state.progression.combat_experience == 444, "reads slot 2, not the row that failed")
	shell.free()
	await _frames(tree)


## A landed map change saves; the interval holds the next; a scene, a ghost or a fight skips it,
## and it is not made up later. Reads the world only.
func _autosave_moments(tree: SceneTree) -> void:
	var files: MemoryFiles = MemoryFiles.new()
	var profile: GameSaveStorageProfile = GameSaveStorageProfile.isolated_test("baseline-auto")
	var shell: ApplicationShellController = await _shell(tree, files, profile)
	await _new_game(tree, shell)
	var host: OldPineGameRuntimeHost = shell.runtime_host()
	var session: WorldSessionController = host.current_session()
	var auto_path: String = profile.for_slot(GameSaveSnapshot.AUTO_SLOT_ID).canonical_path()
	_check(not files.files.has(auto_path), "no autosave before a moment")
	var combat: RandomStreamSnapshot = session.combat_random_source().capture_random_state()
	var npc: RandomStreamSnapshot = session.npc_random_source().capture_random_state()
	var world: RandomStreamSnapshot = session.world_interaction_random_source().capture_random_state()
	var zone: ZoneDefinition = GameContent.catalog().zone(&"snow.square")
	_check(session.handoff_to(&"snow.outdoor", &"snow.square", zone.combat_location_id, &"snow.square.inn_entry").succeeded(), "out onto the square")
	await tree.process_frame
	_check(host.autosave().running(), "the map change sets it off, on the first frame after")
	_check(_same(combat, session.combat_random_source().capture_random_state()) and _same(npc, session.npc_random_source().capture_random_state()) and _same(world, session.world_interaction_random_source().capture_random_state()), "it draws from none of the streams")
	await _autosaved(tree, host)
	_check(files.files.has(auto_path), "auto-v1.json")
	var repository: GameSaveRepository = SourceEntrySaveRepository.new(profile.for_slot(GameSaveSnapshot.AUTO_SLOT_ID), files)
	var saved: GameSaveResult = repository.load()
	_check(saved.succeeded() and saved.snapshot.metadata.slot_id == GameSaveSnapshot.AUTO_SLOT_ID and saved.snapshot.player.world_location.zone_id == &"snow.square", "a whole save of the square, in the auto slot")
	await _frames(tree)
	_check(session.shared_ui().toasts().latest_text() == "已自动存档", "the line is told: " + session.shared_ui().toasts().latest_text())
	var written: PackedByteArray = files.files[auto_path]
	_check(session.handoff_to(&"snow.inn", &"snow.inn.main_floor", GameContent.catalog().zone(&"snow.inn.main_floor").combat_location_id, &"snow.inn.entry_from_square").outcome in [OldPineMapHandoffResult.Outcome.COMPLETED, OldPineMapHandoffResult.Outcome.DESTINATION_MARKER_MISSING], "back or not, the interval holds")
	await _frames(tree)
	_check(files.files[auto_path] == written and not host.autosave().running(), "within 180 s nothing is written")
	var later: int = Time.get_ticks_msec() + 181_000
	var autosave: GameAutosave = host.autosave()
	_check(autosave.due(session, later), "after it, the next moment saves")
	session.hold_scene(true)
	_check(not autosave.due(session, later), "not while a scene plays (Save's own check)")
	session.hold_scene(false)
	session.player_runtime().state.ghost = true
	_check(OldPineSaveEligibility.inspect(session).allowed() and not autosave.due(session, later), "a ghost may Save but never autosaves")
	_check(not autosave.begin(session, later) and not autosave.running(), "the moment passes")
	session.player_runtime().state.ghost = false
	var moment: Signal = session.autosave_moment
	var fired: Array[int] = [0]
	moment.connect(func() -> void: fired[0] += 1)
	session._fight_shown = true
	session._note_fight_over()
	_check(fired[0] == 1, "a fight over is a moment, once")
	session._note_fight_over()
	_check(fired[0] == 1, "and not again")
	await _frames(tree)
	shell.free()
	await _frames(tree)


## The autosave rolls: the one before stays as the .bak, and the list offers it.
func _autosave_rolls(tree: SceneTree) -> void:
	var files: MemoryFiles = MemoryFiles.new()
	var profile: GameSaveStorageProfile = GameSaveStorageProfile.isolated_test("baseline-roll")
	var shell: ApplicationShellController = await _shell(tree, files, profile)
	await _new_game(tree, shell)
	var host: OldPineGameRuntimeHost = shell.runtime_host()
	var session: WorldSessionController = host.current_session()
	session.player_runtime().state.progression.combat_experience = 100
	_check(host.autosave().begin(session), "first")
	await _autosaved(tree, host)
	session.player_runtime().state.progression.combat_experience = 200
	_check(host.autosave().begin(session, Time.get_ticks_msec() + 200_000), "second, past the interval")
	await _autosaved(tree, host)
	_check(_exp(files, profile, GameSaveSnapshot.AUTO_SLOT_ID) == 200, "the slot holds the last")
	var auto: GameSaveStorageProfile = profile.for_slot(GameSaveSnapshot.AUTO_SLOT_ID)
	_check(GameSaveJsonCodec.decode(files.files[auto.backup_path()].get_string_from_utf8()).snapshot.player.character.progression.combat_experience == 100, "its .bak the one before")
	_check(shell.request_pause() and shell.request_load_slots(), "the list")
	var buttons: Array[Button] = shell.slot_panel.buttons()
	_check(buttons.size() == 5 and buttons[4].text.contains("上一份自动存档"), "offers 上一份自动存档")
	_check(shell.choose_slot_row(4) and shell.confirm_current_result(), "读取 it")
	await _frames(tree)
	var back: WorldSessionController = host.current_session()
	_check(back != session and back.player_runtime().state.progression.combat_experience == 100, "the one before")
	shell.free()
	await _frames(tree)


## The card offers the autosave of this character; asks; 取消 is back on the card; 读取 replaces
## the dead world with the living one. Another journey's autosave is not offered.
func _death_card_goes_back(tree: SceneTree) -> void:
	var files: MemoryFiles = MemoryFiles.new()
	var profile: GameSaveStorageProfile = GameSaveStorageProfile.isolated_test("baseline-death")
	var shell: ApplicationShellController = await _shell(tree, files, profile)
	await _new_game(tree, shell)
	var host: OldPineGameRuntimeHost = shell.runtime_host()
	var session: WorldSessionController = host.current_session()
	var overlay: PlayerLifeOverlay = _overlay(session)
	await _die(tree, session)
	_check(overlay.text().contains("你死了。"), "the card")
	_check(not _to_autosave(overlay).visible, "no autosave yet: no way back offered")
	shell.free()
	await _frames(tree)
	shell = await _shell(tree, files, profile)
	await _new_game(tree, shell)
	host = shell.runtime_host()
	session = host.current_session()
	session.player_runtime().state.progression.combat_experience = 321
	_check(host.autosave().begin(session), "an autosave of this character")
	await _autosaved(tree, host)
	overlay = _overlay(session)
	session.player_runtime().state.progression.combat_experience = 400
	await _die(tree, session)
	_check(_to_autosave(overlay).visible and _to_autosave(overlay).text == "回到上次自动存档", "the card offers it")
	await tree.process_frame
	_check(tree.root.gui_get_focus_owner() != null and tree.root.gui_get_focus_owner().name == &"Continue", "继续 keeps the keys")
	_check(_to_autosave(overlay).focus_mode != Control.FOCUS_NONE, "the pad can reach it")
	overlay.return_to_autosave()
	_check(shell.shell_state().mode() == ApplicationShellState.Mode.RESULT and shell.result_prompt.is_asking() and shell.result_label.text.contains("回到上次自动存档") and shell.result_prompt.detail.text.contains("雪亭镇"), "asks, saying where: " + shell.result_prompt.detail.text)
	await _frames(tree)
	_check(tree.paused and tree.root.gui_get_focus_owner() == shell.cancel_button, "the question holds the keys over the card")
	_check(shell.dismiss_current_result() and shell.shell_state().mode() == ApplicationShellState.Mode.PLAYING and not tree.paused, "取消: back on the card")
	await _frames(tree)
	_check(overlay.text().contains("你死了。") and tree.root.gui_get_focus_owner() != null and tree.root.gui_get_focus_owner().name == &"Continue", "继续 has the keys again")
	overlay.return_to_autosave()
	_check(shell.confirm_current_result(), "读取")
	await _frames(tree)
	var back: WorldSessionController = host.current_session()
	_check(back != session and back.player_runtime().state.progression.combat_experience == 321, "the world of the autosave")
	_check(back.player_runtime().life_status == CharacterRuntimeLifeStatus.Value.ACTIVE and not back.player_runtime().state.ghost and not back.player_life_flow().is_active(), "alive, the death undone")
	_check(shell.shell_state().mode() == ApplicationShellState.Mode.PLAYING and not tree.paused, "playing")
	shell.free()
	await _frames(tree)
	# Another journey's autosave lies in the slot, under the very same name.
	shell = await _shell(tree, files, profile)
	await _new_game(tree, shell)
	session = shell.runtime_host().current_session()
	_check(shell.runtime_host().autosave_row().display_name == session.player_runtime().facts.display_name, "the slot holds a save of the same name")
	overlay = _overlay(session)
	await _die(tree, session)
	_check(not _to_autosave(overlay).visible, "another journey's autosave is not offered, whatever the name")
	shell.free()
	await _frames(tree)


## The file turned bad: told, and the player is back on the card, the world as it was.
func _broken_autosave_keeps_the_card(tree: SceneTree) -> void:
	var files: MemoryFiles = MemoryFiles.new()
	var profile: GameSaveStorageProfile = GameSaveStorageProfile.isolated_test("baseline-bad")
	var shell: ApplicationShellController = await _shell(tree, files, profile)
	await _new_game(tree, shell)
	var host: OldPineGameRuntimeHost = shell.runtime_host()
	var session: WorldSessionController = host.current_session()
	_check(host.autosave().begin(session), "an autosave")
	await _autosaved(tree, host)
	var overlay: PlayerLifeOverlay = _overlay(session)
	await _die(tree, session)
	_check(_to_autosave(overlay).visible, "offered")
	var auto: GameSaveStorageProfile = profile.for_slot(GameSaveSnapshot.AUTO_SLOT_ID)
	var text: String = files.files[auto.canonical_path()].get_string_from_utf8()
	files.files[auto.canonical_path()] = text.replace("\"day_seconds\"", "\"day_second\"").to_utf8_buffer()
	overlay.return_to_autosave()
	_check(shell.confirm_current_result(), "读取")
	await _frames(tree)
	_check(host.current_session() == session and shell.shell_state().mode() == ApplicationShellState.Mode.RESULT and not shell.result_prompt.detail.visible, "told, over the same world")
	_check(shell.dismiss_current_result() and shell.shell_state().mode() == ApplicationShellState.Mode.PLAYING and session.player_life_flow().phase == PlayerLifeFlow.Phase.DEATH_SEQUENCE, "back on the card")
	await _frames(tree)
	session.continue_after_death()
	await _frames(tree)
	_check(session.active_map_id() == DeathWorldDefinitions.MAP_ID and session.player_runtime().state.ghost, "the world goes on: 继续 still leads to 阴间")
	shell.free()
	await _frames(tree)


## autosave_min_seconds 0 (经典, and every suite): no moment saves, the card offers nothing.
func _no_autosave_when_off(tree: SceneTree) -> void:
	var files: MemoryFiles = MemoryFiles.new()
	var profile: GameSaveStorageProfile = GameSaveStorageProfile.isolated_test("baseline-off")
	var shell: ApplicationShellController = await _shell(tree, files, profile)
	await _new_game(tree, shell)
	var session: WorldSessionController = shell.runtime_host().current_session()
	var zone: ZoneDefinition = GameContent.catalog().zone(&"snow.square")
	_check(session.handoff_to(&"snow.outdoor", &"snow.square", zone.combat_location_id, &"snow.square.inn_entry").succeeded(), "a map change")
	await _frames(tree)
	_check(not shell.runtime_host().autosave().running() and files.files.is_empty(), "writes nothing")
	var overlay: PlayerLifeOverlay = _overlay(session)
	await _die(tree, session)
	_check(not _to_autosave(overlay).visible, "and the card offers nothing")
	shell.free()
	await _frames(tree)


func _shell(tree: SceneTree, files: MemoryFiles, profile: GameSaveStorageProfile) -> ApplicationShellController:
	var shell: ApplicationShellController = SHELL.instantiate()
	shell.configure_before_start(profile, files, null, MemoryFiles.new())
	tree.root.add_child(shell)
	await _frames(tree)
	return shell


func _new_game(tree: SceneTree, shell: ApplicationShellController, pace: StringName = CharacterState.PACE_MODERN, display_name: String = "凌雪") -> void:
	if shell.request_new_game_from_menu() and shell.shell_state().mode() == ApplicationShellState.Mode.RESULT:
		shell.confirm_current_result()
	shell.runtime_host().opening_card = false
	shell.player_name_edit.text = display_name
	shell.select_new_game_gender(CharacterState.GENDER_FEMALE)
	shell.select_new_game_pace(pace)
	_check(shell.submit_new_game_setup(), "New Game")
	await _frames(tree)
	shell.select_new_game_pace(CharacterState.PACE_MODERN)


func _frames(tree: SceneTree, count: int = 8) -> void:
	for _frame: int in count:
		await tree.process_frame


func _autosaved(tree: SceneTree, host: OldPineGameRuntimeHost) -> void:
	var frames: int = 0
	while host.autosave().running() and frames < 5000:
		frames += 1
		await tree.process_frame
	await tree.process_frame


func _overlay(session: WorldSessionController) -> PlayerLifeOverlay:
	return session.shared_ui().life_overlay


func _to_autosave(overlay: PlayerLifeOverlay) -> Button:
	return overlay.find_child("ToAutosave", true, false) as Button


## TEST-ONLY: a mortal wound.
func _die(tree: SceneTree, session: WorldSessionController) -> void:
	session.player_runtime().state.vitality.effective = -1
	(session.active_map() as WorldMapController).player_fall_below_zero()
	await tree.physics_frame
	await _frames(tree, 3)


func _exp(files: MemoryFiles, profile: GameSaveStorageProfile, slot_id: StringName) -> int:
	var path: String = profile.for_slot(slot_id).canonical_path()
	if not files.files.has(path):
		return -1
	return GameSaveJsonCodec.decode(files.files[path].get_string_from_utf8()).snapshot.player.character.progression.combat_experience


func _same(left: RandomStreamSnapshot, right: RandomStreamSnapshot) -> bool:
	return left.seed == right.seed and left.state == right.state


func _check(condition: bool, label: String) -> void:
	_count += 1
	if not condition:
		_failures.append(label)
