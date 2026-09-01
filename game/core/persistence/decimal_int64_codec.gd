class_name DecimalInt64Codec
extends RefCounted

const MAX_TEXT: String = "9223372036854775807"
const MIN_MAGNITUDE_TEXT: String = "9223372036854775808"


static func encode(value: int) -> String:
	return str(value)


static func decode(value: Variant, path: String = "") -> GameSaveResult:
	if typeof(value) != TYPE_STRING:
		return GameSaveResult.failure(GameSaveResult.Outcome.INVALID_FIELD_TYPE, path, "expected canonical decimal string")
	var text: String = value
	if text == "0":
		return _integer_success(0)
	var negative: bool = text.begins_with("-")
	var digits: String = text.substr(1) if negative else text
	if digits.is_empty() or digits[0] == "0":
		return GameSaveResult.failure(GameSaveResult.Outcome.INVALID_INTEGER, path, "non-canonical decimal")
	for index: int in range(digits.length()):
		var code: int = digits.unicode_at(index)
		if code < 48 or code > 57:
			return GameSaveResult.failure(GameSaveResult.Outcome.INVALID_INTEGER, path, "non-canonical decimal")
	var limit: String = MIN_MAGNITUDE_TEXT if negative else MAX_TEXT
	if digits.length() > limit.length() or (digits.length() == limit.length() and digits > limit):
		return GameSaveResult.failure(GameSaveResult.Outcome.INTEGER_OUT_OF_RANGE, path, "signed int64 overflow")
	if negative and digits == MIN_MAGNITUDE_TEXT:
		return _integer_success(-9223372036854775807 - 1)
	var parsed: int = 0
	for index: int in range(digits.length()):
		parsed = parsed * 10 + digits.unicode_at(index) - 48
	return _integer_success(-parsed if negative else parsed)


static func integer_value(result: GameSaveResult) -> int:
	return int(result.detail)


static func _integer_success(value: int) -> GameSaveResult:
	return GameSaveResult.new(GameSaveResult.Outcome.SUCCESS, "", str(value))
