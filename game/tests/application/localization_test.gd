extends RefCounted

## The localization foundation: which language a system locale gets (Chinese by
## script), the language list, the Settings language (kept, applied at once, a
## version 1 file following the system), the test pseudo-locale's marks, and the
## shell's own screens under it: menu, setup form, Settings and a confirmation.
const ShellTests := preload("res://tests/application/application_shell_test.gd")
const SHELL := preload("res://scenes/application/application_shell.tscn")

var assertions: int = 0
var failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary:
	_resolver()
	_catalog()
	_service()
	_settings()
	_pseudo_marks()
	await _shell_screens(tree)
	return {"assertions": assertions, "failures": failures}


func check(ok: bool, label: String) -> bool:
	assertions += 1
	if not ok:
		failures.append("localization: " + label)
	return ok


static func _language(code: String, script_code: String) -> LanguageDefinition:
	return LanguageDefinition.new(code, code, script_code)


func _resolver() -> void:
	var source_only: LanguageCatalog = LanguageCatalog.source_only()
	var both: LanguageCatalog = source_only.with_language(_language("zh_TW", "Hant")).with_language(_language("en", ""))
	# Godot itself would give a zh_CN or zh_SG system the Traditional catalog (language match only).
	var expected: Dictionary[String, String] = {
		"zh_CN": "zh_CN", "zh_Hans_CN": "zh_CN", "zh-Hans-SG": "zh_CN", "zh_SG": "zh_CN", "zh_MY": "zh_CN", "zh": "zh_CN",
		"zh_TW": "zh_TW", "zh_Hant_TW": "zh_TW", "zh_HK": "zh_TW", "zh-Hant-HK": "zh_TW", "zh_MO": "zh_TW",
		"en_US": "en", "en_GB": "en", "ja_JP": "zh_CN", "fr": "zh_CN", "": "zh_CN",
	}
	for locale: String in expected:
		check(LanguageResolver.resolve(locale, both) == expected[locale], "%s -> %s, not %s" % [locale, expected[locale], LanguageResolver.resolve(locale, both)])
	check(LanguageResolver.resolve("zh_HK", source_only) == "zh_CN", "with Simplified alone a Traditional system reads the source")
	check(LanguageResolver.resolve("en_US", source_only) == "zh_CN", "a language not listed reads the default (Simplified)")


func _catalog() -> void:
	var catalog: LanguageCatalog = LanguageCatalog.load_from()
	var source: LanguageDefinition = catalog.find("zh_CN")
	check(catalog.default_code() == "zh_CN" and source != null and source.is_source() and source.name == "简体中文", "languages.json: Simplified Chinese is the source, by its own name")
	check(not source.font_names.is_empty(), "the source language names its fonts")
	var broken: LanguageCatalog = LanguageCatalog.load_from("res://locale/no_such_languages.json")
	check(broken.languages().size() == 1 and broken.find("zh_CN") != null, "an unreadable list leaves the source language")


func _service() -> void:
	var before: String = TranslationServer.get_locale()
	var pseudo: LanguageDefinition = PseudoLocale.language()
	var service := LocalizationService.new(LanguageCatalog.load_from().with_language(pseudo), "en_US")
	check(service.apply(LocalizationService.FOLLOW_SYSTEM) and service.active_code() == "zh_CN" and TranslationServer.get_locale() == "zh_CN", "follow system: an English system reads Simplified, and the locale says so (glyph forms, line breaks)")
	check(TranslationServer.translate("观察") == "观察", "the source language translates nothing")
	check(service.apply(PseudoLocale.CODE) and TranslationServer.get_locale() == PseudoLocale.CODE, "a chosen language applies")
	check(TranslationServer.translate("观察") == "〖观察〗", "its catalog is loaded")
	check(not service.apply(PseudoLocale.CODE), "applying it again changes nothing")
	check(service.apply("xx_YY") and service.active_code() == "zh_CN", "a language no longer listed follows the system")
	check(TranslationServer.translate("观察") == "观察", "the previous catalog is unloaded")
	var theme: Theme = ThemeDB.get_project_theme()
	var font: SystemFont = null if theme == null else theme.default_font as SystemFont
	check(font != null and font.font_names == service.catalog().find("zh_CN").font_names, "the project theme's font takes the language's fonts")
	service.release()
	check(TranslationServer.get_locale() == before and font.font_names.is_empty(), "release puts locale and font back")


func _settings() -> void:
	var files := ShellTests.MemoryFiles.new()
	var repository := ApplicationSettingsRepository.new(files)
	files.files[ApplicationSettingsRepository.SETTINGS_PATH] = "[application]\nschema_version=1\nwindow_mode=\"fullscreen\"\n".to_utf8_buffer()
	var old: ApplicationSettingsResult = repository.load()
	check(old.succeeded() and old.snapshot().window_mode() == ApplicationWindowMode.Value.FULLSCREEN and old.snapshot().language() == "", "a version 1 file keeps its window mode and follows the system language")
	check(repository.write(ApplicationSettingsSnapshot.defaults().with_language("zh_TW")).succeeded() and repository.load().snapshot().language() == "zh_TW", "the language round-trips")
	files.files[ApplicationSettingsRepository.SETTINGS_PATH] = "[application]\nschema_version=2\nwindow_mode=\"windowed\"\nlanguage=3\n".to_utf8_buffer()
	check(repository.load().outcome() == ApplicationSettingsResult.Outcome.INVALID_SETTINGS, "a language that is not text is rejected")
	files.files[ApplicationSettingsRepository.SETTINGS_PATH] = "[application]\nschema_version=2\nwindow_mode=\"windowed\"\n".to_utf8_buffer()
	check(repository.load().outcome() == ApplicationSettingsResult.Outcome.INVALID_SETTINGS, "version 2 must hold the language")
	files.files.clear()
	var localization := LocalizationService.new(LanguageCatalog.load_from().with_language(PseudoLocale.language()), "en_US")
	var service := ApplicationSettingsService.new(repository, ApplicationWindowModeCapability.new(), localization)
	service.load_and_apply()
	var switched: ApplicationSettingsServiceResult = service.apply_and_persist_language(PseudoLocale.CODE)
	check(switched.succeeded() and localization.active_code() == PseudoLocale.CODE and repository.load().snapshot().language() == PseudoLocale.CODE, "Settings: the language applies at once and is kept")
	check(not service.apply_and_persist_language("xx_YY").succeeded() and localization.active_code() == PseudoLocale.CODE, "an unknown language is refused")
	localization.release()


func _pseudo_marks() -> void:
	check(PseudoLocale.mark("你给{npc}{item}。") == "〖你给〗{npc}{item}〖。〗", "named slots stay outside the marks")
	check(PseudoLocale.mark("%s对你而言太重了。") == "%s〖对你而言太重了。〗", "%s stays outside")
	check(PseudoLocale.mark("$N用爪子往$n的$l一抓") == "$N〖用爪子往〗$n〖的〗$l〖一抓〗", "ES2 $ slots stay outside")
	check(PseudoLocale.mark("{line} [color=#8b959e]（-{damage}）[/color]") == "{line} [color=#8b959e]〖（-〗{damage}〖）〗[/color]", "BBCode stays outside")
	check(PseudoLocale.untranslated("〖你给〗店小二〖一个包子〗") == "店小二", "an unmarked name is found")
	check(PseudoLocale.untranslated("〖你说道：〗凌雪", PackedStringArray(["凌雪"])).is_empty(), "the player's own name is allowed")
	check(PseudoLocale.untranslated("〖草鞋〗(Sandals)〖。〗").is_empty(), "an ES2 id in parentheses is allowed")
	check(not PseudoLocale.untranslated("Take").is_empty(), "English is found too")
	var messages: Array[Dictionary] = PseudoLocale.read_pot()
	var ids: Array = messages.map(func(message: Dictionary) -> String: return message["id"])
	check(messages.size() > 900 and ids.has("观察") and ids.has("你给{npc}{item}。") and ids.has("东方故事"), "the template holds code, scene and content text")


func _shell_screens(tree: SceneTree) -> void:
	var files := ShellTests.MemoryFiles.new()
	var profile := GameSaveStorageProfile.isolated_test("localization-shell")
	# Something in the slot: the menu says what it is and New Game asks first.
	files.files[profile.canonical_path()] = '{"metadata":{"schema_version":1}}'.to_utf8_buffer()
	var settings := ShellTests.MemoryFiles.new()
	settings.files[ApplicationSettingsRepository.SETTINGS_PATH] = (
		"[application]\nschema_version=2\nwindow_mode=\"windowed\"\nlanguage=\"%s\"\n" % PseudoLocale.CODE
	).to_utf8_buffer()
	var catalog: LanguageCatalog = LanguageCatalog.load_from().with_language(PseudoLocale.language())
	var shell: ApplicationShellController = SHELL.instantiate()
	shell.configure_before_start(profile, files, null, settings, null, catalog)
	tree.root.add_child(shell)
	await _frames(tree, 4)
	var allowed := PackedStringArray(["简体中文", "伪语言"])
	check(TranslationServer.get_locale() == PseudoLocale.CODE, "the shell starts in the kept language")
	_scan(shell, allowed, "main menu")
	check(shell.request_new_game_from_menu() and shell.result_overlay.visible, "New Game over a save asks first")
	_scan(shell, allowed, "New Game confirmation")
	shell.dismiss_current_result()
	await _frames(tree, 2)
	check(shell.request_settings_from_main_menu() and shell.language_row.visible, "Settings shows the language row with two languages")
	_scan(shell, allowed, "Settings")
	var option: OptionButton = shell.language_option
	check(option.item_count == 3 and String(option.get_item_metadata(option.selected)) == PseudoLocale.CODE, "跟随系统 and both languages, the kept one selected")
	option.select(0)
	check(shell.apply_settings() and TranslationServer.get_locale() == "zh_CN", "跟随系统 applies at once (an English or Chinese system reads Simplified)")
	check(settings.files.has(ApplicationSettingsRepository.SETTINGS_PATH) and ApplicationSettingsRepository.new(settings).load().snapshot().language() == "", "and is kept")
	shell.free()
	await _frames(tree, 2)


func _scan(root: Node, allowed: PackedStringArray, screen: String) -> void:
	var findings: Array[String] = VisibleTextScan.untranslated(root, allowed)
	check(findings.is_empty(), "%s: every text went through a translation: %s" % [screen, findings])


func _frames(tree: SceneTree, count: int) -> void:
	for frame: int in count:
		await tree.process_frame
