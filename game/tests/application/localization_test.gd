extends RefCounted

## The localization foundation: which language a system locale gets (Chinese by
## script), the language list, the Settings language (kept, applied at once, a
## version 1 file following the system), the test pseudo-locale's marks, and the
## shell's own screens under it: menu, setup form, Settings and a confirmation.
const ShellTests := preload("res://tests/application/application_shell_test.gd")
const SHELL := preload("res://scenes/application/application_shell.tscn")
## The language files it breaks on purpose: a .po that is not there (Godot's two lines and the
## catalog's), a languages list without its array or its default language.
const EXPECTED_ERRORS: Dictionary = {"res://locale/missing.po": 3, "res://locale/no_such_languages.json": 2}

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
	var english: LanguageDefinition = catalog.find("en")
	check(english != null and english.preview and not english.is_source() and ResourceLoader.exists(english.translation_path), "English is listed in preview, with its .po")
	check(LanguageResolver.resolve("en_US", catalog) == "zh_CN", "a language in preview is never given to a system on its own")
	var both: LanguageCatalog = LanguageCatalog.source_only().with_language(_language("en", ""))
	check(LanguageResolver.resolve("en_US", both) == "en", "once out of preview, an English system gets it")
	var traditional: LanguageDefinition = catalog.find("zh_Hant")
	check(traditional != null and traditional.preview and traditional.script_code == "Hant" and ResourceLoader.exists(traditional.translation_path), "繁體中文 is listed in preview, written in Hant, with its .po")
	check(ResourceLoader.exists(traditional.face_path) and traditional.face_path != GameTheme.PIXEL_FONT_PATH, "and draws in a pixel face of its own (Taiwan's glyph forms)")
	check(LanguageResolver.resolve("zh_TW", catalog) == "zh_CN" and LanguageResolver.resolve("zh_Hant_HK", catalog) == "zh_CN", "in preview, a Taiwan or Hong Kong system still reads Simplified")
	var released: LanguageCatalog = LanguageCatalog.source_only().with_language(_language("zh_Hant", "Hant"))
	check(LanguageResolver.resolve("zh_TW", released) == "zh_Hant" and LanguageResolver.resolve("zh_MO", released) == "zh_Hant", "once out of preview, Taiwan, Hong Kong and Macau get it")
	var korean: LanguageDefinition = catalog.find("ko")
	check(korean != null and korean.preview and ResourceLoader.exists(korean.translation_path) and ResourceLoader.exists(korean.face_path), "한국어 is listed in preview, with its .po and a pixel face of its own")
	check(LanguageResolver.resolve("ko_KR", catalog) == "zh_CN", "in preview, a Korean system still reads Simplified")
	check(LanguageResolver.resolve("ko_KR", LanguageCatalog.source_only().with_language(_language("ko", ""))) == "ko", "once out of preview, a Korean system gets it")
	var japanese: LanguageDefinition = catalog.find("ja")
	check(japanese != null and japanese.preview and ResourceLoader.exists(japanese.translation_path) and ResourceLoader.exists(japanese.face_path), "日本語 is listed in preview, with its .po and a pixel face of its own (Japanese glyph forms)")
	check(LanguageResolver.resolve("ja_JP", catalog) == "zh_CN", "in preview, a Japanese system still reads Simplified")
	check(LanguageResolver.resolve("ja_JP", LanguageCatalog.source_only().with_language(_language("ja", ""))) == "ja", "once out of preview, a Japanese system gets it")
	var russian: LanguageDefinition = catalog.find("ru")
	check(russian != null and russian.preview and ResourceLoader.exists(russian.translation_path) and russian.face_path.is_empty(), "Русский is listed in preview, with its .po, in the bundled pixel face (it draws Cyrillic)")
	check(LanguageResolver.resolve("ru_RU", catalog) == "zh_CN", "in preview, a Russian system still reads Simplified")
	check(LanguageResolver.resolve("ru_RU", LanguageCatalog.source_only().with_language(_language("ru", ""))) == "ru", "once out of preview, a Russian system gets it")
	var spanish: LanguageDefinition = catalog.find("es_419")
	check(spanish != null and spanish.preview and ResourceLoader.exists(spanish.translation_path) and spanish.face_path.is_empty(), "Español is listed in preview, with its .po, in the bundled pixel face (it draws á é ñ ¿ ¡)")
	check(LanguageResolver.resolve("es_MX", catalog) == "zh_CN", "in preview, a Spanish system still reads Simplified")
	check(LanguageResolver.resolve("es_MX", LanguageCatalog.source_only().with_language(_language("es_419", ""))) == "es_419" and LanguageResolver.resolve("es_ES", LanguageCatalog.source_only().with_language(_language("es_419", ""))) == "es_419", "once out of preview, a Spanish system gets it, Mexico's or Spain's")
	var portuguese: LanguageDefinition = catalog.find("pt_BR")
	check(portuguese != null and portuguese.preview and ResourceLoader.exists(portuguese.translation_path) and portuguese.face_path.is_empty(), "Português is listed in preview, with its .po, in the bundled pixel face (it draws ã õ ç â ê ô à)")
	check(LanguageResolver.resolve("pt_BR", catalog) == "zh_CN", "in preview, a Portuguese system still reads Simplified")
	check(LanguageResolver.resolve("pt_BR", LanguageCatalog.source_only().with_language(_language("pt_BR", ""))) == "pt_BR" and LanguageResolver.resolve("pt_PT", LanguageCatalog.source_only().with_language(_language("pt_BR", ""))) == "pt_BR", "once out of preview, a Portuguese system gets it, Brazil's or Portugal's")
	var broken: LanguageCatalog = LanguageCatalog.load_from("res://locale/no_such_languages.json")
	check(broken.languages().size() == 1 and broken.find("zh_CN") != null, "an unreadable list leaves the source language")


func _service() -> void:
	var before: String = TranslationServer.get_locale()
	var pseudo: LanguageDefinition = PseudoLocale.language()
	var service := LocalizationService.new(LanguageCatalog.load_from().with_language(pseudo), "en_US")
	check(service.apply(LocalizationService.FOLLOW_SYSTEM) and service.active_code() == "zh_CN" and TranslationServer.get_locale() == "zh_CN", "follow system: an English system reads Simplified, and the locale says so (glyph forms, line breaks)")
	check(TranslationServer.translate("丢下") == "丢下", "the source language translates nothing")
	check(service.apply(PseudoLocale.CODE) and TranslationServer.get_locale() == PseudoLocale.CODE, "a chosen language applies")
	check(TranslationServer.translate("丢下") == "〖丢下〗", "its catalog is loaded")
	check(not service.apply(PseudoLocale.CODE), "applying it again changes nothing")
	check(service.apply("xx_YY") and service.active_code() == "zh_CN", "a language no longer listed follows the system")
	check(TranslationServer.translate("丢下") == "丢下", "the previous catalog is unloaded")
	var theme: Theme = ThemeDB.get_project_theme()
	check(theme.default_font is FontFile and theme.default_font.resource_path == GameTheme.BODY_FONT_PATH and (theme.default_font as FontFile).allow_system_fallback, "the text face is the bundled pixel face (像素界面); the system fills in glyphs it lacks")
	check(LocalizationService.language_font(theme) == null, "no system font chained under it to retarget (one that finds none of its names falls back to the theme's own font: a loop)")
	var face: FontFile = LocalizationService.theme_face(theme)
	var bundled: PackedByteArray = face.data
	check(service.apply("zh_Hant") and TranslationServer.translate("新游戏") == "新遊戲" and TranslationServer.translate("返回主菜单") == "返回主選單", "繁體中文: its catalog is loaded, menu words included")
	var taiwan: FontFile = load(service.catalog().find("zh_Hant").face_path)
	check(face.data == taiwan.data and face.data != bundled and face.resource_path == GameTheme.PIXEL_FONT_PATH, "the theme's one pixel face now draws Taiwan's glyph forms")
	check(service.apply("zh_CN") and face.data == bundled, "back to Simplified, the bundled glyphs return")
	check(service.apply("ko") and TranslationServer.get_translation_object("ko") is FinishedTranslation, "한국어: its catalog is loaded through FinishedTranslation")
	check(KoreanText.without_joiners(TranslationServer.translate("新游戏")) == "새 게임" and TranslationServer.translate("新游戏").contains(KoreanText.WORD_JOINER), "a Korean message comes with its words kept whole")
	check(KoreanText.without_joiners(ShownText.of(TranslationServer.translate("{npc}说道：{line}").format({"npc": "점소이", "line": "어서 옵쇼"}))) == "점소이가 말한다. “어서 옵쇼”", "a filled line shows the particle its name takes")
	check(not MessageGrammar.shows_chinese() and ChineseNumber.of(10) == "10", "numbers in digits")
	check(service.apply("ja") and TranslationServer.translate("新游戏") == "はじめから" and TranslationServer.translate("返回主菜单") == "タイトルに戻る", "日本語: its catalog is loaded")
	check(face.data == (load(service.catalog().find("ja").face_path) as FontFile).data, "and the theme's pixel face draws Japanese glyph forms")
	check(not MessageGrammar.shows_chinese() and ChineseNumber.of(10) == "10", "numbers the game fills are digits")
	check(WorldSpeechBubbles.bubble_text("店小二「いらっしゃいませ」") == "いらっしゃいませ" and WorldSpeechBubbles.bubble_text("店小二が首を振った。「知らない」") == "知らない", "a bubble shows what is said, without the name and the quotes")
	check(TranslationServer.translate("两") == "両", "两 is the tael of silver there (the number two before a measure word is a digit outside Chinese)")
	check(service.apply("ru") and WorldSpeechBubbles.bubble_text("Трактирный слуга говорит: «Заходите!»") == "Заходите!" and WorldSpeechBubbles.bubble_text("Трактирный слуга зевает.") == "Трактирный слуга зевает.", "Русский: a bubble shows what is said, without who says it and the «»")
	check(service.apply("es_419") and TranslationServer.get_translation_object("es") is FinishedTranslation and face.data == bundled, "Español: its catalog is loaded through FinishedTranslation, in the bundled face")
	check(not MessageGrammar.shows_chinese() and ChineseNumber.of(10) == "10", "numbers in digits")
	check(WorldSpeechBubbles.bubble_text("El mozo dice: \"¡Pase!\"") == "¡Pase!", "a bubble shows what is said, without who says it and the quotes")
	check(service.apply("pt_BR") and TranslationServer.get_translation_object("pt_BR") is FinishedTranslation and face.data == bundled, "Português: its catalog is loaded through FinishedTranslation, in the bundled face")
	service.apply("zh_Hant")
	service.release()
	check(TranslationServer.get_locale() == before and face.data == bundled, "release puts the locale and the face back")


func _settings() -> void:
	var files := ShellTests.MemoryFiles.new()
	var repository := ApplicationSettingsRepository.new(files)
	files.files[ApplicationSettingsRepository.SETTINGS_PATH] = "[application]\nschema_version=1\nwindow_mode=\"fullscreen\"\n".to_utf8_buffer()
	var old: ApplicationSettingsResult = repository.load()
	check(old.succeeded() and old.snapshot().window_mode() == ApplicationWindowMode.Value.BORDERLESS and old.snapshot().language() == "", "a version 1 file keeps its (borderless) full screen and follows the system language")
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
	# A listed language whose translation does not load: refused, and not kept.
	var unloadable := LanguageDefinition.new("xx", "XX", "", "res://locale/missing.po")
	var broken := LocalizationService.new(LanguageCatalog.load_from().with_language(unloadable), "en_US")
	var broken_service := ApplicationSettingsService.new(repository, ApplicationWindowModeCapability.new(), broken)
	broken_service.load_and_apply()
	var kept_before: String = repository.load().snapshot().language()
	var refused: ApplicationSettingsServiceResult = broken_service.apply_and_persist_language("xx")
	check(refused.outcome() == ApplicationSettingsServiceResult.Outcome.APPLY_FAILURE and broken.active_code() != "xx" and repository.load().snapshot().language() == kept_before, "a language that will not load is reported and not kept")
	broken.release()


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
	check(messages.size() > 900 and ids.has("丢下") and ids.has("你给{npc}{item}。") and ids.has("东方故事"), "the template holds code, scene and content text")


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
	# The title's line is the title in the other language, never translated (title_screen.json).
	var allowed := PackedStringArray(["简体中文", "繁體中文（預覽）", "English (preview)", "한국어 (미리 보기)", "日本語（プレビュー）", "Русский (предварительная версия)", "Español (Latinoamérica) (vista previa)", "Português (Brasil) (versão prévia)", "伪语言", "东方故事"])
	check(TranslationServer.get_locale() == PseudoLocale.CODE, "the shell starts in the kept language")
	_scan(shell, allowed, "main menu")
	check(shell.request_new_game_from_menu() and shell.result_overlay.visible, "New Game over a save asks first")
	_scan(shell, allowed, "New Game confirmation")
	shell.dismiss_current_result()
	await _frames(tree, 2)
	check(shell.request_settings_from_main_menu() and shell.language_row.visible, "Settings shows the language row")
	_scan(shell, allowed, "Settings")
	var option: OptionButton = shell.language_option
	check(option.item_count == 10 and String(option.get_item_metadata(option.selected)) == PseudoLocale.CODE, "跟随系统 and the nine languages, the kept one selected")
	option.select(0)
	check(shell.apply_settings() and TranslationServer.get_locale() == "zh_CN", "跟随系统 applies at once (an English or Chinese system reads Simplified)")
	check(settings.files.has(ApplicationSettingsRepository.SETTINGS_PATH) and ApplicationSettingsRepository.new(settings).load().snapshot().language() == "", "and is kept")
	shell.free()
	await _frames(tree, 2)
	# As shipped: Simplified Chinese; Traditional Chinese, English, Korean, Japanese, Russian, Spanish and Portuguese in preview, listed in Settings.
	var shipped: ApplicationShellController = SHELL.instantiate()
	shipped.configure_before_start(GameSaveStorageProfile.isolated_test("localization-shipped"), ShellTests.MemoryFiles.new(), null, ShellTests.MemoryFiles.new())
	tree.root.add_child(shipped)
	await _frames(tree, 4)
	check(shipped.request_settings_from_main_menu() and shipped.language_row.visible and shipped.language_option.item_count == 9, "as shipped, Settings lists 跟随系统, 简体中文, 繁體中文（預覽）, English (preview), 한국어 (미리 보기), 日本語（プレビュー）, Русский (предварительная версия), Español (Latinoamérica) (vista previa) and Português (Brasil) (versão prévia)")
	check(String(shipped.language_option.get_item_metadata(shipped.language_option.selected)) == LocalizationService.FOLLOW_SYSTEM, "following the system by default")
	shipped.free()
	await _frames(tree, 2)


func _scan(root: Node, allowed: PackedStringArray, screen: String) -> void:
	var findings: Array[String] = VisibleTextScan.untranslated(root, allowed)
	check(findings.is_empty(), "%s: every text went through a translation: %s" % [screen, findings])


func _frames(tree: SceneTree, count: int) -> void:
	for frame: int in count:
		await tree.process_frame
