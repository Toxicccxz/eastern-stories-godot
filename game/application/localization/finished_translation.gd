class_name FinishedTranslation
extends Translation

## A translation that finishes its text as the language shows it (ShownText: Korean particles
## and whole words, Russian cases and agreement). A control that translates its own text passes
## the filled line through here too (a Label's text is looked up again when it is shaped): that
## line is no message, so it is finished as it stands. A template's marks after an unfilled
## {slot} are left for the line it fills.

var _inner: Translation
var _language: String = ""


func _init(inner: Translation = null) -> void:
	_inner = inner
	if inner != null:
		locale = inner.locale
		_language = inner.locale.get_slice("_", 0)


func _get_message(src_message: StringName, context: StringName) -> StringName:
	var found: StringName = _inner.get_message(src_message, context) if _inner != null else &""
	var text: String = String(src_message) if found == &"" else String(found)
	var finished: String = ShownText.finish(text, _language)
	if found == &"" and finished == text:
		return &""
	return StringName(finished)


func _get_plural_message(src_message: StringName, src_plural_message: StringName, n: int, context: StringName) -> StringName:
	var found: StringName = _inner.get_plural_message(src_message, src_plural_message, n, context) if _inner != null else &""
	return &"" if found == &"" else StringName(ShownText.finish(String(found), _language))
