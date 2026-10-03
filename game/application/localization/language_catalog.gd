class_name LanguageCatalog
extends RefCounted

## The languages a player can choose, read from res://locale/languages.json. Adding a
## language is a translation file plus one entry there; no code changes. A file that
## cannot be read leaves the source language alone, so the game still shows its text.
const PATH: String = "res://locale/languages.json"
const SOURCE_CODE: String = "zh_CN"

var _default_code: String = SOURCE_CODE
var _languages: Array[LanguageDefinition] = []


static func load_from(path: String = PATH) -> LanguageCatalog:
	var catalog := LanguageCatalog.new()
	var errors: Array[String] = []
	var text: String = FileAccess.get_file_as_string(path)
	var document: Variant = JSON.parse_string(text) if not text.is_empty() else null
	if not document is Dictionary or not document.get("languages") is Array:
		errors.append("%s: expected a `languages` array" % path)
	else:
		for entry: Variant in document["languages"]:
			var language: LanguageDefinition = _language(entry, path, errors)
			if language != null and catalog.find(language.code) == null:
				catalog._languages.append(language)
		catalog._default_code = String(document.get("default", SOURCE_CODE))
	if catalog.find(catalog._default_code) == null:
		errors.append("%s: the default language %s is not listed" % [path, catalog._default_code])
	if not errors.is_empty():
		for error: String in errors:
			push_error("languages: " + error)
		return source_only()
	return catalog


## The source language alone: what the game shows when languages.json is unusable.
static func source_only() -> LanguageCatalog:
	var catalog := LanguageCatalog.new()
	catalog._languages.append(LanguageDefinition.new(SOURCE_CODE, "简体中文", "Hans"))  # NO_TRANSLATE: a language's own name
	return catalog


static func _language(entry: Variant, path: String, errors: Array[String]) -> LanguageDefinition:
	if not entry is Dictionary or not entry.get("code") is String or not entry.get("name") is String:
		errors.append("%s: each language needs a `code` and a `name`" % path)
		return null
	var fonts := PackedStringArray()
	for font: Variant in entry.get("fonts", []):
		if font is String:
			fonts.append(font)
	var translation_path: String = String(entry.get("translation", ""))
	if not translation_path.is_empty() and not ResourceLoader.exists(translation_path):
		errors.append("%s: %s has no translation at %s" % [path, entry["code"], translation_path])
		return null
	return LanguageDefinition.new(entry["code"], entry["name"], String(entry.get("script", "")), translation_path, fonts)


## A copy with one more language (a test language, e.g. the pseudo-locale).
func with_language(language: LanguageDefinition) -> LanguageCatalog:
	var copy := LanguageCatalog.new()
	copy._default_code = _default_code
	copy._languages = _languages.duplicate()
	copy._languages.append(language)
	return copy


func default_code() -> String:
	return _default_code


func languages() -> Array[LanguageDefinition]:
	return _languages.duplicate()


func find(code: String) -> LanguageDefinition:
	for language: LanguageDefinition in _languages:
		if language.code == code:
			return language
	return null
