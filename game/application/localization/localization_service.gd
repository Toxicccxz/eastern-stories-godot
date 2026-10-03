class_name LocalizationService
extends RefCounted

## Shows the game in one language: follows the system's unless the player chose one in
## Settings. Only the chosen language's translation is loaded (see LanguageResolver for
## why Godot is not left to pick), the TranslationServer locale is set even for the
## source language so text shaping and system font fallback use Chinese glyph forms, and
## the project theme's font takes the language's font list.

## The Settings preference that follows the system language.
const FOLLOW_SYSTEM: String = ""

var _catalog: LanguageCatalog
var _system_locale: String
var _active: LanguageDefinition
var _loaded: Translation
var _locale_before: String = ""


func _init(catalog: LanguageCatalog = null, system_locale: String = "") -> void:
	_catalog = LanguageCatalog.load_from() if catalog == null else catalog
	_system_locale = OS.get_locale() if system_locale.is_empty() else system_locale


func catalog() -> LanguageCatalog:
	return _catalog


func active_code() -> String:
	return "" if _active == null else _active.code


## A preference that names no listed language (removed since it was saved) follows the system.
func is_known(preference: String) -> bool:
	return preference == FOLLOW_SYSTEM or _catalog.find(preference) != null


func language_for(preference: String) -> LanguageDefinition:
	var language: LanguageDefinition = _catalog.find(preference)
	if language == null:
		language = _catalog.find(LanguageResolver.resolve(_system_locale, _catalog))
	return language


## Returns whether the shown language changed.
func apply(preference: String) -> bool:
	var language: LanguageDefinition = language_for(preference)
	if language == null or language == _active:
		return false
	var translation: Translation = language.translation
	if translation == null and not language.translation_path.is_empty():
		translation = load(language.translation_path) as Translation
		if translation == null:
			push_error("languages: cannot load %s" % language.translation_path)
			return false
	if _active == null:
		_locale_before = TranslationServer.get_locale()
	if _loaded != null:
		TranslationServer.remove_translation(_loaded)
	_loaded = translation
	if _loaded != null:
		TranslationServer.add_translation(_loaded)
	TranslationServer.set_locale(language.code)
	_apply_font(language.font_names)
	_active = language
	return true


## Puts the locale, translations and font back as they were before the first apply()
## (a shell leaving the tree; tests run many shells in one process).
func release() -> void:
	if _active == null:
		return
	if _loaded != null:
		TranslationServer.remove_translation(_loaded)
	_loaded = null
	_active = null
	TranslationServer.set_locale(_locale_before)
	_apply_font(PackedStringArray())


static func _apply_font(font_names: PackedStringArray) -> void:
	var theme: Theme = ThemeDB.get_project_theme()
	var font: SystemFont = null if theme == null else theme.default_font as SystemFont
	if font != null and font.font_names != font_names:
		font.font_names = font_names
