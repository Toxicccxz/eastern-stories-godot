extends RefCounted

## 前两小时 E (owner, 2026-10-26; DECISIONS「经典模式总开关」): the New Game panel's 节奏 — 经典 puts
## the six progression knobs at ES2's before the world is built (no 木人, no board, no 历练),
## 现代 leaves the game's; the choice is in CharacterState.pace and the save, the 角色 page
## says it, and the catalog's pacing comes back when the session goes.

const DUMMY_SPAWN: StringName = &"native.snow.school2.wooden_dummy.1"
const SHELL_SCENE: PackedScene = preload("res://scenes/application/application_shell.tscn")
const ShellTests := preload("res://tests/application/application_shell_test.gd")

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_presets()
	_test_save_field()
	await _test_classic_world(tree)
	await _test_modern_world(tree)
	await _test_panel(tree)
	return {"assertions": _count, "failures": _failures.duplicate()}


func _test_presets() -> void:
	var production: PacingDefinition = GameContent.catalog().pacing()
	var classic: PacingDefinition = PacePresets.of(production, CharacterState.PACE_CLASSIC)
	_check(not classic.milestone_rewards and classic.catch_up_max_percent == 0 and not classic.staged_potential_cap and classic.player_exercise_gain == 1 and not classic.bounty_board and not classic.training_dummies, "经典: the six knobs at ES2's")
	_check(classic.feel.training_step_seconds == production.feel.training_step_seconds and classic.player_exp_gain == production.player_exp_gain and classic.bounty_refresh_seconds == production.bounty_refresh_seconds, "the rest stays the game's")
	_check(PacePresets.of(production, CharacterState.PACE_MODERN) == production and PacePresets.of(production, &"") == production, "现代 (and unset): the catalog's own")
	_check(PacePresets.shown_name(CharacterState.PACE_CLASSIC) == "经典" and PacePresets.shown_name(&"") == "现代", "named on the 角色 page")


## The save keeps the pace; a file without it reads as 现代; a wrong one is refused.
func _test_save_field() -> void:
	var state := CharacterState.new()
	state.pace = CharacterState.PACE_CLASSIC
	var codec := GameSaveJsonCodec.new()
	var snapshot: GameSaveValueTypes.CharacterStateSnapshot = GameSaveValueTypes.CharacterStateSnapshot.new(CharacterState.GENDER_MALE).with_pace(CharacterState.PACE_CLASSIC)
	var encoded: Variant = codec._encode_character(snapshot)
	_check(encoded is Dictionary and encoded.get("pace") == "classic", "written as a string: %s" % [encoded.get("pace")])
	var back: GameSaveValueTypes.CharacterStateSnapshot = codec._decode_character(encoded, "t")
	_check(back != null and back.pace == CharacterState.PACE_CLASSIC, "read back")
	encoded.erase("pace")
	back = codec._decode_character(encoded, "t")
	_check(back != null and back.pace.is_empty(), "an older save: 现代")
	encoded["pace"] = "hardcore"
	_check(codec._decode_character(encoded, "t") == null, "an unknown pace is refused")


func _test_classic_world(tree: SceneTree) -> void:
	var production: PacingDefinition = GameContent.catalog().pacing()
	var session: WorldSessionController = await _session(tree, CharacterState.PACE_CLASSIC)
	var state: CharacterState = session.player_runtime().state
	_check(state.pace == CharacterState.PACE_CLASSIC, "the character plays 经典")
	_check(not GameContent.catalog().pacing().training_dummies and not GameContent.catalog().pacing().milestone_rewards, "the catalog's pacing is 经典 while it runs")
	_check(_npc_of(session, &"native.npc.wooden_dummy.1") == null, "no 木人 in the 教练场")
	_check(not session.bounties().enabled(), "no board")
	_check(not state.milestones.has("region/snow"), "the birthplace is not even written down (no 历练)")
	var sheet := CharacterSheet.new()
	sheet.refresh(session.player_runtime(), session)
	_check(sheet.pace.text == "节奏：经典（开局选定）", "the 角色 page: " + sheet.pace.text)
	session.free()
	await tree.process_frame
	_check(GameContent.catalog().pacing() == production and GameContent.catalog().pacing().training_dummies, "the session gone, the catalog's pacing is back")


func _test_modern_world(tree: SceneTree) -> void:
	var session: WorldSessionController = await _session(tree, CharacterState.PACE_MODERN)
	var state: CharacterState = session.player_runtime().state
	_check(state.pace == CharacterState.PACE_MODERN and GameContent.catalog().pacing().training_dummies, "现代: the game's pacing")
	_check(_npc_of(session, &"native.npc.wooden_dummy.1") != null and state.milestones.has("region/snow"), "木人 stand, the birthplace is written down")
	var sheet := CharacterSheet.new()
	sheet.refresh(session.player_runtime(), session)
	_check(sheet.pace.text == "节奏：现代（开局选定）", "the 角色 page: " + sheet.pace.text)
	session.free()
	await tree.process_frame


## The New Game panel: 现代 by default; 经典 chosen goes through the host to the character.
func _test_panel(tree: SceneTree) -> void:
	var shell: ApplicationShellController = SHELL_SCENE.instantiate()
	_check(shell.configure_before_start(GameSaveStorageProfile.isolated_test("pace"), ShellTests.MemoryFiles.new(), null, ShellTests.MemoryFiles.new()), "shell configures")
	tree.root.add_child(shell)
	for frame: int in 3:
		await tree.process_frame
	shell.runtime_host().opening_card = false
	_check(shell.request_new_game_from_menu() and shell.selected_pace() == CharacterState.PACE_MODERN and shell.pace_option.get_item_text(0) == "现代（推荐）", "the panel offers 现代 first")
	shell.player_name_edit.text = "守旧"
	shell.select_new_game_gender(CharacterState.GENDER_MALE)
	shell.select_new_game_pace(CharacterState.PACE_CLASSIC)
	_check(shell.selected_pace() == CharacterState.PACE_CLASSIC and shell.submit_new_game_setup(), "经典 chosen, the journey starts")
	for frame: int in 4:
		await tree.process_frame
	if shell.shell_state().mode() == ApplicationShellState.Mode.RESULT:
		shell.confirm_current_result()
		for frame: int in 3:
			await tree.process_frame
	var session: WorldSessionController = shell.runtime_host().current_session()
	_check(session != null and session.player_runtime().state.pace == CharacterState.PACE_CLASSIC and not GameContent.catalog().pacing().bounty_board, "through the host: a 经典 world")
	shell.queue_free()
	await tree.process_frame
	await tree.process_frame
	_check(GameContent.catalog().pacing().bounty_board, "and the pacing back once it is gone")


func _session(tree: SceneTree, pace: StringName) -> WorldSessionController:
	var session: WorldSessionController = (load("res://scenes/world/oldpine/oldpine_world_session.tscn") as PackedScene).instantiate()
	session.configure_source_entry("节奏", CharacterState.GENDER_MALE, pace)
	session.deterministic_combat_seed = true
	session.deterministic_npc_seed = true
	session.deterministic_world_interaction_seed = true
	tree.root.add_child(session)
	for frame: int in 4:
		await tree.process_frame
	session.set_process(false)
	return session


func _npc_of(session: WorldSessionController, definition_id: StringName) -> NpcRuntimeState:
	for map: WorldMapController in session.world_maps():
		for npc: NpcRuntimeState in map.npc_runtimes():
			if npc.definition().definition_id == definition_id:
				return npc
	return null


func _check(ok: bool, label: String) -> void:
	_count += 1
	if not ok:
		_failures.append(label)
