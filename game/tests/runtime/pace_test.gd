extends RefCounted

## 取消经典模式 (owner, 2026-11-10; DECISIONS「取消经典模式」): one game, the catalog's pacing. The
## New Game panel asks no 节奏, the 角色 page shows none, a save writes none; a save from the
## time of two paces reads on when it was 现代 and is refused, plainly, when it was 经典.

const SHELL_SCENE: PackedScene = preload("res://scenes/application/application_shell.tscn")
const ShellTests := preload("res://tests/application/application_shell_test.gd")

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_save_field()
	_test_slot_row()
	await _test_panel(tree)
	return {"assertions": _count, "failures": _failures.duplicate()}


## No save carries a pace; an older one's "modern" reads, its "classic" is another contract's.
func _test_save_field() -> void:
	var codec := GameSaveJsonCodec.new()
	var snapshot: GameSaveValueTypes.CharacterStateSnapshot = GameSaveValueTypes.CharacterStateSnapshot.new(CharacterState.GENDER_MALE)
	var encoded: Variant = codec._encode_character(snapshot)
	_check(encoded is Dictionary and not encoded.has("pace"), "a save writes no pace")
	_check(codec._decode_character(encoded, "t") != null, "and reads back")
	encoded["pace"] = "modern"
	_check(GameSaveJsonCodec.new()._decode_character(encoded, "t") != null, "an older 现代 save reads on")
	encoded["pace"] = "classic"
	codec = GameSaveJsonCodec.new()
	_check(codec._decode_character(encoded, "t") == null and codec._error != null and codec._error.outcome == GameSaveResult.Outcome.INCOMPATIBLE_DEVELOPMENT_CONTRACT and codec._error.path == "t.pace", "an older 经典 save is refused as another contract's")
	encoded["pace"] = "hardcore"
	codec = GameSaveJsonCodec.new()
	_check(codec._decode_character(encoded, "t") == null and codec._error != null and codec._error.outcome == GameSaveResult.Outcome.INVALID_FIELD_TYPE, "anything else is a broken file")
	_check(ApplicationProductResultMapper._inspect_repository_result(GameSaveResult.failure(GameSaveResult.Outcome.INCOMPATIBLE_DEVELOPMENT_CONTRACT, "player.character.pace")).message_key() == &"save.incompatible_development", "the player is told to start a new game")


## The slot list says so before anyone tries to load it.
func _test_slot_row() -> void:
	var root: Dictionary = {
		"metadata": {"format_id": GameSaveSnapshot.FORMAT_ID, "schema_version": GameSaveSnapshot.CURRENT_SCHEMA_VERSION, "saved_at_utc": "2026-11-01T00:00:00Z"},
		"world_content_revision": WorldContentRevision.serialized(WorldContentRevision.CURRENT_PUBLIC),
		"player": {"identity": {"display_name": "守旧"}, "world_location": {"zone_id": "snow.inn"}, "character": {"pace": "classic"}},
	}
	var slot: StringName = GameSaveSnapshot.MANUAL_SLOT_IDS[0]
	_check(GameSaveSlotSummary.of_text(slot, JSON.stringify(root), true, false).state == GameSaveSlotSummary.State.UNSUPPORTED, "a 经典 save's row: from another version")
	root["player"]["character"]["pace"] = "modern"
	_check(GameSaveSlotSummary.of_text(slot, JSON.stringify(root), true, false).state == GameSaveSlotSummary.State.READY, "a 现代 one's: ready")
	root["player"]["character"].erase("pace")
	_check(GameSaveSlotSummary.of_text(slot, JSON.stringify(root), true, false).state == GameSaveSlotSummary.State.READY, "one without the field: ready")


## The New Game panel asks a name and a gender, nothing else; the world stands on the catalog's
## pacing and leaves it as it was.
func _test_panel(tree: SceneTree) -> void:
	var production: PacingDefinition = GameContent.catalog().pacing()
	var shell: ApplicationShellController = SHELL_SCENE.instantiate()
	_check(shell.configure_before_start(GameSaveStorageProfile.isolated_test("pace"), ShellTests.MemoryFiles.new(), null, ShellTests.MemoryFiles.new()), "shell configures")
	tree.root.add_child(shell)
	for frame: int in 3:
		await tree.process_frame
	shell.runtime_host().opening_card = false
	_check(shell.request_new_game_from_menu() and shell.get_node_or_null("%PaceOption") == null and shell.new_game_setup_panel.find_children("*", "OptionButton", true, false).is_empty(), "the panel has no 节奏 to choose")
	shell.player_name_edit.text = "凌雪"
	shell.select_new_game_gender(CharacterState.GENDER_MALE)
	_check(shell.submit_new_game_setup(), "the journey starts")
	for frame: int in 4:
		await tree.process_frame
	if shell.shell_state().mode() == ApplicationShellState.Mode.RESULT:
		shell.confirm_current_result()
		for frame: int in 3:
			await tree.process_frame
	var session: WorldSessionController = shell.runtime_host().current_session()
	_check(session != null and GameContent.catalog().pacing() == production and production.bounty_board and production.training_dummies, "the world stands on the catalog's own pacing")
	if session != null:
		_check(_npc_of(session, &"native.npc.wooden_dummy.1") != null and session.bounties().enabled() and session.player_runtime().state.milestones.has("region/snow"), "木人 stand, the board is up, the birthplace is written down")
		var sheet := CharacterSheet.new()
		sheet.refresh(session.player_runtime(), session)
		_check(sheet.find_child("Pace", true, false) == null, "the 角色 page has no 节奏 line")
		sheet.free()
	shell.queue_free()
	await tree.process_frame
	await tree.process_frame
	_check(GameContent.catalog().pacing() == production, "and the pacing is the same once it is gone")


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
