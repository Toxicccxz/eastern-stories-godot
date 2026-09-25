extends RefCounted

const MemoryFiles = preload("res://tests/application/application_shell_test.gd").MemoryFiles
const SHELL = preload("res://scenes/application/application_shell.tscn")
var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_name_policy()
	_check(ApplicationShellState.new_game_setup().is_valid() and ApplicationShellState.new_game_setup().operation() == ApplicationShellState.Operation.NONE, "setup is not busy operation")
	for gender: StringName in [CharacterState.GENDER_MALE, CharacterState.GENDER_FEMALE]:
		await _journey(tree, gender, "凌雪")
	await _journey(tree, CharacterState.GENDER_MALE, "雪")
	await _journey(tree, CharacterState.GENDER_FEMALE, "一二三四五六")
	await _journey(tree, CharacterState.GENDER_FEMALE, "Alice")
	await _journey(tree, CharacterState.GENDER_MALE, "José·凌雪")
	await _journey(tree, CharacterState.GENDER_FEMALE, "Jose\u0301 O’雪")
	await _direct_host(tree)
	await _confirmation(tree)
	await _technical_profile_rejected(tree)
	return {"assertions": _count, "failures": _failures}


func _name_policy() -> void:
	var defaults: NewPlayerNamePolicy.Rules = NewPlayerNamePolicy.default_rules()
	_check(defaults.minimum_length == 1 and defaults.maximum_length == 24 and not defaults.allow_digits and defaults.allowed_separators == " -'’·" and defaults.reserved_names.is_empty(), "exact default rules")
	for valid: String in ["雪", "凌雪", "一二三四五六", "一二三四五六七", "𠮷雪", "Alice", "Xavier", "José", "Élodie", "Jean-Luc", "O'Connor", "O’Connor", "Mary Jane", "山田太郎", "김민수", "Αλέξανδρος", "Алексей", "阿依古丽·买买提", "Jose\u0301", "a\u0301\u0327", "नमस्ते", "علي"]:
		_check(NewPlayerNamePolicy.validate(valid).succeeded and NewPlayerNamePolicy.is_valid(valid), "generic Unicode name accepted: " + valid)
	for invalid: String in ["", " ", " Alice", "Alice ", "Alice1", "雪1", "雪😀", "😀", "A/B", "A\\B", "A_B", "Jean--Luc", "Mary  Jane", "O''Connor", "-Alice", "Alice-", "·Alice", "Alice·", "雪\n", "雪\t", "A:B", "A;B", "A\"B", "[Alice]", "<Alice>", "A=B", "A+B", "A²", "AⅣ", "A١", "A１", "\u0301A", "A \u0301B", "A-\u0301B", "A\u00a0B", "A\u3000B"]:
		_check(not NewPlayerNamePolicy.is_valid(invalid), "invalid name rejected exactly: " + invalid.c_escape())
	for invisible: int in [1, 0x7f, 0x85, 0xad, 0x034f, 0x061c, 0x115f, 0x1160, 0x17b4, 0x17b5, 0x180b, 0x180e, 0x180f, 0x200b, 0x200c, 0x200d, 0x200e, 0x200f, 0x2028, 0x202e, 0x2060, 0x2066, 0x3164, 0xe000, 0xfe00, 0xfe0f, 0xfeff, 0xffa0, 0xfffd, 0x1d173, 0xe0001, 0xe0100, 0xe01ef, 0xf0000]:
		_check(not NewPlayerNamePolicy.is_valid("A" + String.chr(invisible) + "B"), "control/invisible/private-use code point rejected: %x" % invisible)
	for left: String in defaults.allowed_separators:
		_check(NewPlayerNamePolicy.is_valid("A" + left + "雪"), "each explicit separator is accepted internally")
		_check(NewPlayerNamePolicy.validate(left + "A").reason == NewPlayerNamePolicy.Reason.LEADING_SEPARATOR, "each leading separator rejected")
		_check(NewPlayerNamePolicy.validate("A" + left).reason == NewPlayerNamePolicy.Reason.TRAILING_SEPARATOR, "each trailing separator rejected")
		for right: String in defaults.allowed_separators:
			_check(NewPlayerNamePolicy.validate("A" + left + right + "B").reason == NewPlayerNamePolicy.Reason.CONSECUTIVE_SEPARATOR, "mixed adjacent separators rejected")
	_check(NewPlayerNamePolicy.validate("").reason == NewPlayerNamePolicy.Reason.EMPTY, "empty reason")
	_check(NewPlayerNamePolicy.validate("A1").reason == NewPlayerNamePolicy.Reason.INVALID_CHARACTER, "invalid character reason")
	_check(not NewPlayerNamePolicy.is_valid("ℹ") and not NewPlayerNamePolicy.is_valid("AℹB"), "pictographic letter excluded despite Unicode letter category")
	for letter: String in ["A", "雪", "𠮷"]:
		_check(NewPlayerNamePolicy.is_valid(letter.repeat(24)), "24 code points accepted regardless of bytes/UTF16 units")
		_check(NewPlayerNamePolicy.validate(letter.repeat(25)).reason == NewPlayerNamePolicy.Reason.TOO_LONG, "25 code points rejected")
	_check(NewPlayerNamePolicy.is_valid("a\u0301".repeat(12)) and not NewPlayerNamePolicy.is_valid("a\u0301".repeat(13)), "combining marks count as code points, not grapheme clusters")
	var rules: NewPlayerNamePolicy.Rules = NewPlayerNamePolicy.default_rules()
	rules.maximum_length = 4
	_check(not NewPlayerNamePolicy.is_valid("Alice", rules) and NewPlayerNamePolicy.is_valid("Alice"), "custom maximum changes acceptance without changing defaults")
	rules.maximum_length = 25
	_check(NewPlayerNamePolicy.is_valid("𠮷".repeat(25), rules), "custom maximum can also expand")
	rules.minimum_length = 3
	_check(NewPlayerNamePolicy.validate("Al", rules).reason == NewPlayerNamePolicy.Reason.TOO_SHORT and NewPlayerNamePolicy.is_valid("Ali", rules), "custom minimum enforced")
	rules.allow_digits = true
	_check(NewPlayerNamePolicy.is_valid("Alice1", rules) and NewPlayerNamePolicy.is_valid("雪١２", rules), "opt-in decimal digits across scripts")
	_check(not NewPlayerNamePolicy.is_valid("Alice²", rules) and not NewPlayerNamePolicy.is_valid("A1\u0301", rules), "digits do not enable all numbers or digit-attached marks")
	rules.allowed_separators = rules.allowed_separators.replace("-", "")
	_check(not NewPlayerNamePolicy.is_valid("Jean-Luc", rules) and NewPlayerNamePolicy.is_valid("Mary Jane", rules), "removing separator changes only explicit set")
	rules.allowed_separators = "_"
	_check(NewPlayerNamePolicy.is_valid("A_B", rules) and not NewPlayerNamePolicy.is_valid("A B", rules), "configured punctuation replaces default set")
	rules.reserved_names.append("Alice")
	_check(NewPlayerNamePolicy.validate("Alice", rules).reason == NewPlayerNamePolicy.Reason.RESERVED_NAME and NewPlayerNamePolicy.is_valid("alice", rules), "reserved names are exact and case-sensitive")
	_check(NewPlayerNamePolicy.default_rules().reserved_names.is_empty(), "default rule collections are independent")
	rules.reserved_names.append("José")
	_check(NewPlayerNamePolicy.is_valid("Jose\u0301", rules), "no implicit Unicode normalization")
	for bad_separators: String in ["\t", "\u00a0", "\u200b", "A", "1", "\u0301", "😀"]:
		rules.allowed_separators = bad_separators
		_check(NewPlayerNamePolicy.validate("Alice", rules).reason == NewPlayerNamePolicy.Reason.INVALID_RULES, "unsafe separator configuration fails closed")
	rules = NewPlayerNamePolicy.default_rules()
	rules.minimum_length = 0
	_check(NewPlayerNamePolicy.validate("Alice", rules).reason == NewPlayerNamePolicy.Reason.INVALID_RULES, "minimum cannot disable nonempty identity")
	rules.minimum_length = 3
	rules.maximum_length = 2
	_check(NewPlayerNamePolicy.validate("Alice", rules).reason == NewPlayerNamePolicy.Reason.INVALID_RULES, "inverted bounds fail closed")


func _direct_host(tree: SceneTree) -> void:
	var shell: ApplicationShellController = SHELL.instantiate()
	shell.configure_before_start(GameSaveStorageProfile.isolated_test("p2r2-host"), MemoryFiles.new(), null, MemoryFiles.new())
	tree.root.add_child(shell)
	await _frames(tree)
	for invalid: String in ["Alice1", " Alice", "A\u200bB", "Jean--Luc", "𠮷".repeat(25)]:
		_check(not shell.runtime_host().request_new_game(invalid, CharacterState.GENDER_FEMALE) and not shell.runtime_host().request_pending() and shell.runtime_host().current_session() == null, "direct Host validates before request/session: " + invalid.c_escape())
	_check(shell.runtime_host().request_new_game("Xavier", CharacterState.GENDER_MALE), "direct Host accepts generalized name through same policy")
	await _frames(tree)
	_check(shell.runtime_host().current_session().player_runtime().facts.display_name == "Xavier", "direct Host preserves accepted display text")
	shell.free()
	await _frames(tree)


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
	_check(not shell.player_name_edit.placeholder_text.contains("中文") and shell.player_name_edit.placeholder_text.contains("24") and not shell.setup_message.text.contains("中文"), "setup prompt and placeholder reflect generalized policy")
	for invalid: String in ["", "𠮷".repeat(25), "Alice1", "雪1", "😀", " ", "雪\n", "A\u200bB", " Alice", "Mary  Jane"]:
		shell.player_name_edit.text = invalid
		_check(not shell.submit_new_game_setup() and shell.player_name_edit.text == invalid and shell.runtime_host().current_session() == null, "invalid input retained without Host")
	_check(not shell.setup_message.text.contains("中文") and shell.setup_message.text.contains("1–24") and shell.setup_message.text.contains("分隔符不能连用"), "validation message describes generalized rules")
	shell.player_name_edit.text = display_name
	_check(not shell.submit_new_game_setup(), "missing explicit gender blocks birth")
	_check(not shell.runtime_host().request_new_game("Alice1", gender), "Host independently rejects invalid name")
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
	_check(player.character_id == &"oldpine.player" and player.state.gender == gender, "fixed semantic ID independent of exact entered name; selected gender")
	_check(session.encounter_display_name(player.character_id) == display_name and (session.active_map().runtime_player_body().get_node("NameLabel") as Label).text == display_name, "accepted text reaches existing presentation without rewriting")
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
	_check(saved.snapshot.player.identity.display_name == display_name and saved.snapshot.items.schema_version == 3, "Save preserves exact accepted name and item schema3")
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
	_check(restored.character_id == player.character_id and restored.death_context(destination, false).victim_display_name == display_name, "Continue preserves semantic ID and exact DeathContext name")
	_check(shell.runtime_host().current_session().encounter_display_name(restored.character_id) == display_name and (shell.runtime_host().current_session().active_map().runtime_player_body().get_node("NameLabel") as Label).text == display_name, "Continue presentation preserves exact multilingual/separator/combining text")
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


func _technical_profile_rejected(tree: SceneTree) -> void:
	var technical: OldPineWorldSessionController = preload("res://scenes/world/oldpine/oldpine_world_session.tscn").instantiate()
	tree.root.add_child(technical)
	var snapshot: GameSaveSnapshot = OldPineWorldSaveCapture.new().capture(technical, &"test", "2026-09-11T00:00:00Z").snapshot
	var encoded: GameSaveResult = GameSaveJsonCodec.encode(snapshot)
	_check(encoded.succeeded(), "technical codec remains an explicit internal fixture")
	technical.free()
	await _frames(tree)
	for suffix: String in ["", ".bak", ".tmp"]:
		var files := MemoryFiles.new()
		var profile := GameSaveStorageProfile.isolated_test("nge6-reject-technical")
		files.files[profile.canonical_path() + suffix] = encoded.text.to_utf8_buffer()
		var before: Dictionary = files.files.duplicate(true)
		var shell: ApplicationShellController = SHELL.instantiate()
		shell.configure_before_start(profile, files, null, MemoryFiles.new())
		tree.root.add_child(shell)
		await _frames(tree)
		_check(not shell.continue_enabled() and not shell.recovery_enabled(), "technical file never advertised as public Continue/Recovery: " + suffix)
		var host: OldPineGameRuntimeHost = shell.runtime_host()
		# Exercise the request even though the UI correctly disables it.
		var requested: bool = host.request_continue() if suffix.is_empty() else host.request_recovery(GameSaveRecoverySource.Value.BACKUP if suffix == ".bak" else GameSaveRecoverySource.Value.TEMP)
		_check(requested, "public Host re-reads selected file: " + suffix)
		await _frames(tree)
		_check(not host.last_load_result().succeeded() and host.current_session() == null and host.session_invariant_holds(), "technical file cannot create a public Session: " + suffix)
		_check(files.files == before, "unsupported technical file remains byte-exact: " + suffix)
		_check(not SourceEntrySaveRepository.new(profile, files).save(snapshot).succeeded() and files.files == before, "public repository rejects technical Save before any write")
		shell.free()
		await _frames(tree)


func _frames(tree: SceneTree) -> void:
	for i: int in 3:
		await tree.process_frame


func _check(ok: bool, detail: String) -> void:
	_count += 1
	if not ok: _failures.append("NGE5B: " + detail)
