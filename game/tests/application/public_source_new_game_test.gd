extends RefCounted

const MemoryFiles = preload("res://tests/application/application_shell_test.gd").MemoryFiles
const SHELL = preload("res://scenes/application/application_shell.tscn")
var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	for invalid: String in ["", " ", "凌雪 ", "一二三四五六七", "Alice", "雪1", "雪😀", "雪\n", "雪\t", "雪\u0001"]:
		_check(not NewPlayerNamePolicy.is_valid(invalid), "invalid name rejected: " + invalid.c_escape())
	for valid: String in ["雪", "一二三四五六", "凌雪", "诸葛云", "𠮷雪"]:
		_check(NewPlayerNamePolicy.is_valid(valid), "Han/code-point name accepted: " + valid)
	_check(ApplicationShellState.new_game_setup().is_valid() and ApplicationShellState.new_game_setup().operation() == ApplicationShellState.Operation.NONE, "setup is not busy operation")
	for gender: StringName in [CharacterState.GENDER_MALE, CharacterState.GENDER_FEMALE]:
		await _journey(tree, gender, "凌雪")
	await _journey(tree, CharacterState.GENDER_MALE, "雪")
	await _journey(tree, CharacterState.GENDER_FEMALE, "一二三四五六")
	await _confirmation(tree)
	return {"assertions": _count, "failures": _failures}


func _journey(tree: SceneTree, gender: StringName, display_name: String) -> void:
	var files := MemoryFiles.new()
	var profile := GameSaveStorageProfile.isolated_test("nge5b-public")
	var shell: ApplicationShellController = SHELL.instantiate()
	shell.configure_before_start(profile, files, null, MemoryFiles.new())
	tree.root.add_child(shell)
	await _frames(tree)
	_check(shell.request_new_game_from_menu(), "public New opens setup")
	_check(shell.new_game_setup_panel.visible and not shell.busy_visible() and shell.runtime_host().current_session() == null and not shell.runtime_host().request_pending(), "setup creates no Session/request/RNG/allocator")
	_check(not shell.male_button.button_pressed and not shell.female_button.button_pressed, "gender has no default")
	for invalid: String in ["", "一二三四五六七", "Alice", "雪1", "😀", " ", "雪\n"]:
		shell.player_name_edit.text = invalid
		_check(not shell.submit_new_game_setup() and shell.player_name_edit.text == invalid and shell.runtime_host().current_session() == null, "invalid input retained without Host")
	shell.player_name_edit.text = display_name
	_check(not shell.submit_new_game_setup(), "missing explicit gender blocks birth")
	_check(not shell.runtime_host().request_new_game("Alice", gender), "Host independently rejects invalid name")
	_check(not shell.runtime_host().request_new_game("凌雪", &""), "Host independently rejects missing gender")
	shell.select_new_game_gender(gender)
	_check(shell.submit_new_game_setup() and not shell.submit_new_game_setup(), "valid submit queues exactly once")
	await _frames(tree)
	var session: OldPineWorldSessionController = shell.runtime_host().current_session()
	_check(session != null and shell.shell_state().mode() == ApplicationShellState.Mode.PLAYING, "public Session committed")
	if session == null:
		shell.free()
		return
	var player: WorldPlayerRuntimeState = session.player_runtime()
	_check(session.resident_map_count() == 4 and session.active_map_id() == &"snow.inn", "first public map is Snow Inn with four residents")
	_check(player.facts.display_name == display_name and player.facts.title == "普通百姓" and player.facts.age == 14 and player.facts.race_id == &"human", "source identity exact")
	_check(player.character_id != StringName(display_name) and player.state.gender == gender, "semantic ID independent; selected gender")
	var destination := InventoryTransferDestination.new(ContainmentEndpoint.new(ContainmentEndpoint.Kind.WORLD, &"snow.inn"), true, true, 1000000)
	var death: DeathContext = player.death_context(destination, false)
	_check(death.victim_display_name == display_name and death.victim_gender == gender, "public name/gender reach DeathContext without executing death")
	var a: CharacterBaseAttributes = player.state.attributes
	for value: int in [a.strength, a.courage, a.intelligence, a.spirituality, a.composure, a.personality, a.constitution, a.karma]:
		_check(value == 30, "source attribute30")
	_check(player.state.progression.combat_experience == 0 and player.state.progression.potential == 99, "source exp0 potential99")
	for track: CharacterResourceState in [player.state.essence, player.state.vitality, player.state.spirit]:
		_check(track.current == 100 and track.effective == 100 and track.maximum == 100, "source100/100/100")
	_check(player.body_facts.body_weight == 80000 and player.maximum_encumbrance == 150000 and player.state.recovery.food == 400 and player.state.recovery.water == 400, "approved body and food facts")
	var ids: Array[StringName] = session.inventory_state().direct_children(ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, player.character_id))
	_check(ids.size() == 1 and session.item_instance_index().resolve(ids[0]).item_definition_id == &"es2:obj/cloth", "only cloth; no starter swords/dagger/money")
	_check(player.state.equipment.are_both_hands_empty() and player.armor.aggregate_numeric_modifiers().armor == 1 and player.state.skills.raw_skill_ids().is_empty(), "empty hands, cloth+1, no skills")
	_check(files.files.is_empty(), "birth never autosaves")
	_check(shell.request_pause() and shell.request_save_from_pause(), "public Pause Save")
	await _frames(tree)
	_check(shell.last_result().succeeded(), "public source Save succeeds")
	var saved: GameSaveResult = GameSaveRepository.new(profile, files).load()
	_check(saved.succeeded() and saved.snapshot.metadata.schema_version == 2 and saved.snapshot.world_content_revision == WorldContentRevision.Value.SOURCE_ENTRY_V1, "public Save explicit source schema2")
	var old_id: int = player.get_instance_id()
	shell.free()
	await _frames(tree)
	shell = SHELL.instantiate()
	shell.configure_before_start(profile, files, null, MemoryFiles.new())
	tree.root.add_child(shell)
	await _frames(tree)
	_check(shell.request_continue_from_menu(), "fresh Shell Continue bypasses setup")
	await _frames(tree)
	var restored: WorldPlayerRuntimeState = shell.runtime_host().current_session().player_runtime()
	_check(restored.get_instance_id() != old_id and restored.facts.display_name == display_name and restored.state.gender == gender and restored.body_facts.body_weight == 80000, "fresh runtime exact identity/gender/body")
	shell.free()
	await _frames(tree)


func _confirmation(tree: SceneTree) -> void:
	var files := MemoryFiles.new()
	var profile := GameSaveStorageProfile.isolated_test("nge5b-confirm")
	files.files[profile.canonical_path()] = '{"metadata":{"schema_version":1}}'.to_utf8_buffer()
	var before: Dictionary = files.files.duplicate(true)
	var shell: ApplicationShellController = SHELL.instantiate()
	shell.configure_before_start(profile, files, null, MemoryFiles.new())
	tree.root.add_child(shell)
	await _frames(tree)
	_check(shell.request_new_game_from_menu() and shell.result_visible() and not shell.new_game_setup_panel.visible, "unsupported material confirms before setup")
	_check(shell.dismiss_current_result() and shell.menu_visible() and files.files == before, "confirmation Cancel preserves files")
	shell.request_new_game_from_menu()
	_check(shell.confirm_current_result() and shell.new_game_setup_panel.visible and files.files == before, "confirmation opens setup without write")
	shell.player_name_edit.text = "凌雪"
	shell._handle_system_back()
	_check(shell.menu_visible() and shell.runtime_host().current_session() == null and files.files == before, "system Back cancels without birth/write")
	shell.request_new_game_from_menu()
	shell.confirm_current_result()
	_check(shell.player_name_edit.text.is_empty(), "cancel draft not persisted")
	var escape := InputEventAction.new()
	escape.action = &"ui_cancel"
	escape.pressed = true
	shell._unhandled_input(escape)
	_check(shell.menu_visible(), "Escape cancels setup")
	# Recovery's New Game uses the same confirmation/setup, never technical birth.
	shell._set_state(ApplicationShellState.recovery_choice())
	shell.recovery_new_game_button.pressed.emit()
	_check(shell.result_visible() and shell.confirm_current_result() and shell.new_game_setup_panel.visible, "recovery New reaches same setup")
	_check(shell.cancel_new_game_setup() and files.files == before, "recovery setup Cancel preserves files")
	shell.free()
	await _frames(tree)


func _frames(tree: SceneTree) -> void:
	for i: int in 3:
		await tree.process_frame


func _check(ok: bool, detail: String) -> void:
	_count += 1
	if not ok: _failures.append("NGE5B: " + detail)
