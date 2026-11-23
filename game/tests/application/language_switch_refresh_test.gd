extends RefCounted

## A language switch mid-journey from a language that is not the source one: the game starts
## in the test pseudo-locale, its HUD, menu pages and battle panel are put together there, then
## Settings switches to 简体中文. Nothing put together before the switch may keep the old
## language: no text or hover still carries the pseudo-locale's marks on the HUD, on each menu
## page as it opens again, or on the battle panel (built once, hidden until a fight). The log
## and its toasts keep the lines written before the switch. The other direction (Chinese first)
## cannot find these: a text frozen in the source language is still a message ID, so Godot's
## auto-translation hides the freeze.
const ShellTests := preload("res://tests/application/application_shell_test.gd")
const SHELL := preload("res://scenes/application/application_shell.tscn")

var assertions: int = 0
var failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary:
	await _switch_back(tree)
	return {"assertions": assertions, "failures": failures}


func check(ok: bool, label: String) -> bool:
	assertions += 1
	if not ok:
		failures.append("language switch: " + label)
	return ok


func _switch_back(tree: SceneTree) -> void:
	var settings := ShellTests.MemoryFiles.new()
	settings.files[ApplicationSettingsRepository.SETTINGS_PATH] = (
		"[application]\nschema_version=2\nwindow_mode=\"windowed\"\nlanguage=\"%s\"\n" % PseudoLocale.CODE
	).to_utf8_buffer()
	var catalog: LanguageCatalog = LanguageCatalog.load_from().with_language(PseudoLocale.language())
	var shell: ApplicationShellController = SHELL.instantiate()
	shell.configure_before_start(GameSaveStorageProfile.isolated_test("language-switch"), ShellTests.MemoryFiles.new(), null, settings, null, catalog)
	tree.root.add_child(shell)
	await _frames(tree, 4)
	if not check(TranslationServer.get_locale() == PseudoLocale.CODE and PublicNewGameTestFixture.request(shell), "New Game in the pseudo-locale"):
		shell.free()
		return
	await _frames(tree, 6)
	var session: WorldSessionController = shell.runtime_host().current_session()
	if not check(session != null and session.is_initialized(), "the journey starts"):
		shell.free()
		return
	var ui: SharedGameplayUI = session.shared_ui()
	# Every page put together once in the old language.
	for tab: int in GameMenu.Tab.values():
		if tab != GameMenu.Tab.SYSTEM and GameMenu.tab_available(tab):
			ui.menu.open(tab)
			await _frames(tree, 2)
	ui.menu.close()
	await _frames(tree, 2)
	check(shell.request_pause() and shell.request_settings_from_pause(), "Settings from the pause")
	await _frames(tree, 2)
	var option: OptionButton = shell.language_option
	for index: int in option.item_count:
		if String(option.get_item_metadata(index)) == "zh_CN":
			option.select(index)
	check(shell.apply_settings() and TranslationServer.get_locale() == "zh_CN", "Apply switches to 简体中文")
	check(shell.request_resume(), "back to the journey")
	await _frames(tree, 6)
	check(_stale(ui, true).is_empty(), "the HUD after the switch: %s" % [_stale(ui, true)])
	var battle: Node = session.find_child("BattlePresentationLayer", true, false)
	check(battle != null and _stale(battle).is_empty(), "the battle panel, waiting for a fight: %s" % [[] if battle == null else _stale(battle)])
	# The pages again, shown now in the new language.
	for tab: int in GameMenu.Tab.values():
		if tab != GameMenu.Tab.SYSTEM and GameMenu.tab_available(tab):
			ui.menu.open(tab)
			await _frames(tree, 2)
			var shown: Array[String] = _stale(ui.menu.root, true)
			check(shown.is_empty(), "the %s page in the new language: %s" % [GameMenu.TAB_TITLES[tab], shown])
	ui.menu.close()
	shell.free()
	await _frames(tree, 2)


## "path#property: text" for every text under `root` (with `shown_only`, the shown ones) that
## still carries the pseudo-locale's marks as drawn; the log and its toasts are left out.
static func _stale(root: Node, shown_only: bool = false) -> Array[String]:
	var found: Array[String] = []
	for node: Node in [root] + root.find_children("*", "", true, false):
		if shown_only and node is CanvasItem and not (node as CanvasItem).is_visible_in_tree():
			continue
		if _in_log(node):
			continue
		var texts: Dictionary[String, String] = {}
		if node is Control:
			var control: Control = node as Control
			texts["tooltip"] = control.tooltip_text
			if "text" in control and control.get("text") is String:
				texts["text"] = control.get("text")
			if control is LineEdit:
				texts["placeholder"] = (control as LineEdit).placeholder_text
			if control is RichTextLabel:
				texts["parsed"] = (control as RichTextLabel).get_parsed_text()
			for key: String in texts.keys():
				texts[key] = control.atr(texts[key]) if control.can_auto_translate() else texts[key]
		elif node is Label3D:
			texts["text"] = (node as Label3D).text
		for key: String in texts:
			if texts[key].contains(PseudoLocale.OPEN):
				found.append("%s#%s: %s" % [str(node.get_path()).trim_prefix(str(root.get_path())), key, texts[key].c_escape().left(80)])
	return found


## The log (任务's LogWell) and its toasts keep the lines written before the switch.
static func _in_log(node: Node) -> bool:
	var at: Node = node
	while at != null:
		if at.name in [&"MessageToasts", &"LogWell"]:
			return true
		at = at.get_parent()
	return false


func _frames(tree: SceneTree, count: int) -> void:
	for frame: int in count:
		await tree.process_frame
