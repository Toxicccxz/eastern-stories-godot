class_name LanguageDefinition
extends RefCounted

## One language the game can show (res://locale/languages.json). The source language,
## Simplified Chinese, has no translation: its text is the message IDs themselves.

## A locale code, e.g. zh_CN, zh_TW, en.
var code: String
## The language's own name (简体中文, 繁體中文, English); never translated.
var name: String
## ISO 15924 script for Chinese (Hans or Hant); empty for other languages.
var script_code: String
## A .po (or .translation) file; empty for the source language.
var translation_path: String
## System font families tried first for this language's text.
var font_names: PackedStringArray
## A translation built in memory (the test pseudo-locale); otherwise loaded from translation_path.
var translation: Translation


func _init(
	p_code: String = "",
	p_name: String = "",
	p_script: String = "",
	p_translation_path: String = "",
	p_font_names: PackedStringArray = PackedStringArray(),
	p_translation: Translation = null,
) -> void:
	code = p_code
	name = p_name
	script_code = p_script
	translation_path = p_translation_path
	font_names = p_font_names
	translation = p_translation


func language() -> String:
	return code.get_slice("_", 0)


func is_source() -> bool:
	return translation_path.is_empty() and translation == null
