class_name ApplicationWindowMode
extends RefCounted

enum Value {
	WINDOWED,
	FULLSCREEN,
}


static func is_valid(value: int) -> bool:
	return value >= Value.WINDOWED and value <= Value.FULLSCREEN


static func storage_value(value: int) -> String:
	match value:
		Value.WINDOWED:
			return "windowed"
		Value.FULLSCREEN:
			return "fullscreen"
	return ""


static func from_storage(value: String) -> int:
	match value:
		"windowed":
			return Value.WINDOWED
		"fullscreen":
			return Value.FULLSCREEN
	return -1
