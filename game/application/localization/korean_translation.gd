class_name KoreanTranslation
extends Translation

## The Korean translation as loaded, giving back its text as KoreanText shows it: particles
## picked, words kept whole on a wrapped line. A control that translates its own text passes
## the filled line through here too (a Label's text is looked up again when it is shaped):
## that line is no message, so it is finished as it stands. A template's pairs after an
## unfilled {slot} are left for the line it fills.

var _inner: Translation


func _init(inner: Translation = null) -> void:
	_inner = inner
	if inner != null:
		locale = inner.locale


func _get_message(src_message: StringName, context: StringName) -> StringName:
	var found: StringName = _inner.get_message(src_message, context) if _inner != null else &""
	var text: String = String(src_message) if found == &"" else String(found)
	var finished: String = KoreanText.finish(text)
	if found == &"" and finished == text:
		return &""
	return StringName(finished)


func _get_plural_message(src_message: StringName, src_plural_message: StringName, n: int, context: StringName) -> StringName:
	var found: StringName = _inner.get_plural_message(src_message, src_plural_message, n, context) if _inner != null else &""
	return &"" if found == &"" else StringName(KoreanText.finish(String(found)))
