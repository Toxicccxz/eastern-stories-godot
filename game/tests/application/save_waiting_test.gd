extends RefCounted

## Waiting to save (审查修补 X, 2026-11-19; DECISIONS「自动存档」), through the shell and its host:
## a Save asked for on 系统 while someone makes a thing for the player finishes the making on the
## spot (the thing handed over) and saves, where it used to say 等一会儿再存档 with the world
## standing still; a telling that gives nothing (天驼关's 黄石隘口 story) never blocks a save; an
## autosave moment refused for a doorway is not tried while the player walks but taken when the
## menu opens or at the next moment; the 决战前 save finishes the work first and never waits.

const ShellTests := preload("res://tests/application/application_shell_test.gd")
const SHELL_SCENE: PackedScene = preload("res://scenes/application/application_shell.tscn")
const LEG: StringName = &"es2:obj/example/chicken_leg"

var _count: int = 0
var _files: ShellTests.MemoryFiles
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	var files := ShellTests.MemoryFiles.new()
	_files = files
	var shell: ApplicationShellController = SHELL_SCENE.instantiate()
	_check(shell.configure_before_start(GameSaveStorageProfile.isolated_test("save-waiting"), files, null, ShellTests.MemoryFiles.new()), "shell configures")
	tree.root.add_child(shell)
	await _frames(tree, 3)
	shell.runtime_host().opening_card = false
	shell.request_new_game_from_menu()
	shell.player_name_edit.text = "等存"
	shell.select_new_game_gender(CharacterState.GENDER_FEMALE)
	_check(shell.submit_new_game_setup(), "New Game")
	await _frames(tree, 8)
	if shell.shell_state().mode() == ApplicationShellState.Mode.RESULT:
		shell.confirm_current_result()
		await _frames(tree, 3)
	var session: WorldSessionController = shell.runtime_host().current_session()
	if _check(session != null and shell.shell_state().mode() == ApplicationShellState.Mode.PLAYING, "playing"):
		await _test_telling(tree, shell, session)
		await _test_making(tree, shell, session)
		await _test_waiting_autosave(tree, shell, session)
		await _test_waiting_keep(tree, shell, session)
	shell.queue_free()
	await _frames(tree, 2)
	return {"assertions": _count, "failures": _failures.duplicate()}


## The first one standing on the map, to make or tell things (TEST-ONLY: anyone will do).
func _someone(session: WorldSessionController) -> NpcRuntimeState:
	var map := session.active_map() as WorldMapController
	for npc: NpcRuntimeState in map.npc_runtimes():
		if npc.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE and map.runtime_body_for_character(npc.character_id) != null:
			return npc
	return null


## 黄石隘口 (d/canyon/npc/captain.c tell_story()): a making with no thing at its end.
func _story() -> NpcMaking:
	for rule: NpcInquiryRule in GameContent.catalog().npc(&"canyon.npc.captain").talk().inquiry_rules("黄石隘口"):
		if rule.make != null:
			return rule.make
	return null


func _save_on_system(tree: SceneTree, shell: ApplicationShellController, label: String) -> bool:
	_check(shell.request_pause() and shell.request_save_from_pause(), "%s: 系统 → 存档" % label)
	await _until(tree, func() -> bool: return shell.shell_state().mode() == ApplicationShellState.Mode.RESULT)
	var result: ApplicationOperationResult = shell.last_result()
	var saved: bool = result != null and result.succeeded()
	shell.dismiss_current_result()
	await _frames(tree, 2)
	shell.request_resume()
	await _frames(tree, 2)
	return saved


func _test_telling(tree: SceneTree, shell: ApplicationShellController, session: WorldSessionController) -> void:
	var story: NpcMaking = _story()
	var npc: NpcRuntimeState = _someone(session)
	if not _check(story != null and story.gives.is_empty() and npc != null, "黄石隘口 is a telling with nothing at its end"):
		return
	var map := session.active_map() as WorldMapController
	map.npc_life.start_making(npc, story) # TEST-ONLY: the captain's story, told by whoever is here
	_check(map.npc_life.makings.has(npc.character_id) and not map.npc_life.holds_work(), "a story under way holds nothing")
	_check(OldPineSaveEligibility.inspect(session).allowed(), "Save is allowed while it is told")
	_check(await _save_on_system(tree, shell, "the story"), "and a Save on 系统 is written")
	_check(map.npc_life.makings.has(npc.character_id), "the story goes on, not hurried to its end")
	map.npc_life.makings.erase(npc.character_id)


func _test_making(tree: SceneTree, shell: ApplicationShellController, session: WorldSessionController) -> void:
	var story: NpcMaking = _story()
	var npc: NpcRuntimeState = _someone(session)
	if story == null or npc == null:
		return
	var thing := NpcMaking.new()
	thing.every = 2.0
	thing.lines = story.lines.slice(0, 3)
	thing.gives = LEG
	var map := session.active_map() as WorldMapController
	var before: bool = session.player_held_item_ids().has(LEG)
	map.npc_life.start_making(npc, thing) # TEST-ONLY: a making with a thing at its end
	_check(not before and map.npc_life.holds_work(), "someone makes a 烤鸡腿 for the player")
	# A Save refused for something else (a doorway) hands over nothing.
	var body: WorldCharacterBody2D = session.active_map().runtime_player_body()
	var stood: Vector2 = body.global_position
	body.global_position = Vector2(-5000, -5000) # TEST-ONLY
	_check(not await _save_on_system(tree, shell, "a refused Save"), "in a doorway the Save is refused")
	_check(map.npc_life.makings.has(npc.character_id) and not session.player_held_item_ids().has(LEG), "and the making goes on: nothing handed over")
	body.global_position = stood
	_check(OldPineSaveEligibility.inspect(session).outcome == OldPineSaveEligibilityResult.Outcome.NPC_WORKING, "a save now would lose it")
	_check(await _save_on_system(tree, shell, "a making"), "a Save on 系统 is written all the same")
	_check(not map.npc_life.makings.has(npc.character_id) and session.player_held_item_ids().has(LEG), "the making was finished on the spot: the 烤鸡腿 in hand")
	var loaded: GameSaveResult = SourceEntrySaveRepository.new(GameSaveStorageProfile.isolated_test("save-waiting").for_slot(shell.runtime_host().selected_slot()), _files).load()
	_check(loaded.succeeded() and GameSaveJsonCodec.encode(loaded.snapshot).text.contains("chicken_leg"), "and the save holds it")


## A doorway refuses the autosave's moment: it waits, is not taken while the player walks on,
## and is taken when the menu opens.
func _test_waiting_autosave(tree: SceneTree, shell: ApplicationShellController, session: WorldSessionController) -> void:
	var host: OldPineGameRuntimeHost = shell.runtime_host()
	var autosave: GameAutosave = host.autosave()
	var pacing: PacingDefinition = GameContent.catalog().pacing()
	GameContent.catalog().set_pacing(pacing.copy().with_autosave(180)) # TEST-ONLY: the shipped interval
	await _written_out(tree, autosave)
	autosave.take_finished()
	autosave.restart_interval(-1) # TEST-ONLY: the interval over
	var body: WorldCharacterBody2D = session.active_map().runtime_player_body()
	var stood: Vector2 = body.global_position
	body.global_position = Vector2(-5000, -5000) # TEST-ONLY: a spot no zone holds (a doorway's like)
	session.autosave_moment.emit()
	await _frames(tree, 3)
	_check(autosave.waiting() and not autosave.running(), "the moment waits for the player to step on")
	body.global_position = stood
	var until: int = Time.get_ticks_msec() + 1500
	while Time.get_ticks_msec() < until:
		await tree.process_frame
	_check(autosave.waiting() and not autosave.running(), "stepped on and walking: not taken while the player walks")
	session.shared_ui().open_menu()
	await _frames(tree, 3)
	_check(autosave.running() or not autosave.waiting(), "the menu opens: the moment is taken")
	await _written_out(tree, autosave)
	await _frames(tree, 2)
	session.shared_ui().close_menu()
	await _frames(tree, 2)
	_check(_written(GameSaveSnapshot.AUTO_SLOT_ID), "the autosave is written")
	# Refused again, a fight's end (any moment) takes it.
	autosave.restart_interval(-1) # TEST-ONLY
	body.global_position = Vector2(-5000, -5000) # TEST-ONLY
	session.autosave_moment.emit()
	await _frames(tree, 3)
	body.global_position = stood
	_check(autosave.waiting(), "waiting again")
	session.autosave_moment.emit()
	await _frames(tree, 3)
	_check(autosave.running() or not autosave.waiting(), "the next moment takes it")
	await _written_out(tree, autosave)
	GameContent.catalog().set_pacing(pacing)


## 决战前 (keep_save): someone making a thing is done on the spot and the save is written; in a
## doorway it says it could not, and keeps no moment for later (the act goes on to 下了决战: a
## 决战前 save taken after that would not be one).
func _test_waiting_keep(tree: SceneTree, shell: ApplicationShellController, session: WorldSessionController) -> void:
	var host: OldPineGameRuntimeHost = shell.runtime_host()
	var kept: GameAutosave = host._kept
	var map := session.active_map() as WorldMapController
	var npc: NpcRuntimeState = _someone(session)
	var story: NpcMaking = _story()
	var thing := NpcMaking.new()
	thing.every = 2.0
	thing.lines = story.lines.slice(0, 2)
	thing.gives = LEG
	map.npc_life.start_making(npc, thing) # TEST-ONLY
	session.keep_save_requested.emit()
	_check(not map.npc_life.makings.has(npc.character_id), "the making is done first")
	await _written_out(tree, kept)
	_check(_written(GameSaveSnapshot.KEEP_SLOT_ID), "the 决战前 save is written")
	var body: WorldCharacterBody2D = session.active_map().runtime_player_body()
	var stood: Vector2 = body.global_position
	body.global_position = Vector2(-5000, -5000) # TEST-ONLY
	session.keep_save_requested.emit()
	await _frames(tree, 3)
	var told: Array[String] = session.shared_ui().toasts().shown_texts()
	for waiting: MessageToasts.Entry in session.shared_ui().toasts()._waiting:
		told.append(waiting.text)
	_check(not kept.waiting() and not kept.running() and told.has("「决战前」存档没能存下"), "in a doorway: said it could not, nothing kept for later: %s" % [told])
	body.global_position = stood
	session.shared_ui().open_menu()
	await _frames(tree, 3)
	_check(not kept.running(), "the menu opening does not take it later")
	session.shared_ui().close_menu()
	await _frames(tree, 2)


## Whether `slot_id`'s file holds a whole save.
func _written(slot_id: StringName) -> bool:
	return SourceEntrySaveRepository.new(GameSaveStorageProfile.isolated_test("save-waiting").for_slot(slot_id), _files).load().succeeded()


## Real time until the save under way is written (its worker writes 3 MB; frames run fast here).
func _written_out(tree: SceneTree, save: GameAutosave) -> void:
	var began: int = Time.get_ticks_msec()
	while save.running() and Time.get_ticks_msec() - began < 60000:
		await tree.process_frame
	await _frames(tree, 2)


func _until(tree: SceneTree, done: Callable, limit: int = 3000) -> void:
	var frames: int = 0
	while not done.call() and frames < limit:
		frames += 1
		await tree.process_frame


func _frames(tree: SceneTree, count: int) -> void:
	for i: int in count:
		await tree.process_frame


func _check(condition: bool, message: String) -> bool:
	_count += 1
	if not condition:
		_failures.append(message)
	return condition
