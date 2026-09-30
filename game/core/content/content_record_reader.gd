class_name ContentRecordReader
extends RefCounted

## Typed, fail-reporting access to one authored data record (a JSON object).
## Every problem is appended to the shared error list with the record's path;
## nothing is guessed. finish() reports keys no reader asked for.
const MAXIMUM_SAFE_INTEGER: float = 9007199254740992.0

var _record: Dictionary
var _path: String
var _errors: Array[String]
var _consumed: Dictionary[String, bool] = {}

var path: String:
	get:
		return _path


func _init(record: Dictionary, record_path: String, errors: Array[String]) -> void:
	_record = record
	_path = record_path
	_errors = errors


func has(key: String) -> bool:
	return _record.has(key)


## Keys in authored order, for records whose keys are data (e.g. exits).
func keys() -> Array[String]:
	var result: Array[String] = []
	for key: Variant in _record:
		result.append(str(key))
	return result


func fail(key: String, message: String) -> void:
	_errors.append("%s%s: %s" % [_path, "" if key.is_empty() else "." + key, message])


func text(key: String, fallback: String = "") -> String:
	_consumed[key] = true
	if not _record.has(key):
		return fallback
	var value: Variant = _record[key]
	if value is String:
		return value
	fail(key, "expected a string")
	return fallback


func required_text(key: String) -> String:
	if not _record.has(key):
		_consumed[key] = true
		fail(key, "is required")
		return ""
	var value: String = text(key)
	if value.is_empty():
		fail(key, "must not be empty")
	return value


func integer(key: String, fallback: int = 0) -> int:
	_consumed[key] = true
	if not _record.has(key):
		return fallback
	var parsed: Variant = _as_integer(_record[key])
	if parsed == null:
		fail(key, "expected an integer")
		return fallback
	return parsed


func boolean(key: String, fallback: bool) -> bool:
	_consumed[key] = true
	if not _record.has(key):
		return fallback
	var value: Variant = _record[key]
	if value is bool:
		return value
	fail(key, "expected true or false")
	return fallback


func required_integer(key: String) -> int:
	if not _record.has(key):
		_consumed[key] = true
		fail(key, "is required")
		return 0
	return integer(key)


func text_list(key: String) -> Array[String]:
	_consumed[key] = true
	var result: Array[String] = []
	if not _record.has(key):
		return result
	var value: Variant = _record[key]
	if not value is Array:
		fail(key, "expected an array of strings")
		return result
	for index: int in range(value.size()):
		var element: Variant = value[index]
		if element is String and not element.is_empty():
			result.append(element)
		else:
			fail("%s[%d]" % [key, index], "expected a non-empty string")
	return result


## Object of integer values, in authored order.
func integer_map(key: String) -> Dictionary[String, int]:
	_consumed[key] = true
	var result: Dictionary[String, int] = {}
	if not _record.has(key):
		return result
	var value: Variant = _record[key]
	if not value is Dictionary:
		fail(key, "expected an object of integers")
		return result
	for entry_key: Variant in value:
		var parsed: Variant = _as_integer(value[entry_key])
		if not entry_key is String or entry_key.is_empty() or parsed == null:
			fail("%s.%s" % [key, str(entry_key)], "expected an integer")
			continue
		result[entry_key] = parsed
	return result


## Nested object, or null when the key is absent or not an object.
func child(key: String) -> ContentRecordReader:
	_consumed[key] = true
	if not _record.has(key):
		return null
	var value: Variant = _record[key]
	if value is Dictionary:
		return ContentRecordReader.new(value, "%s.%s" % [_path, key], _errors)
	fail(key, "expected an object")
	return null


func children(key: String) -> Array[ContentRecordReader]:
	_consumed[key] = true
	var result: Array[ContentRecordReader] = []
	if not _record.has(key):
		return result
	var value: Variant = _record[key]
	if not value is Array:
		fail(key, "expected an array of objects")
		return result
	for index: int in range(value.size()):
		var element: Variant = value[index]
		if element is Dictionary:
			result.append(ContentRecordReader.new(
				element, "%s.%s[%d]" % [_path, key, index], _errors,
			))
		else:
			fail("%s[%d]" % [key, index], "expected an object")
	return result


func finish() -> void:
	for key: Variant in _record:
		if not _consumed.has(str(key)):
			fail(str(key), "unknown field")


static func _as_integer(value: Variant) -> Variant:
	if value is int:
		return value
	if value is float and value == floorf(value) and absf(value) <= MAXIMUM_SAFE_INTEGER:
		return int(value)
	return null
