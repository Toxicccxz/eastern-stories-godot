class_name ApplicationWindowMode
extends RefCounted

## 窗口, 全屏 (the display's own exclusive full screen) and 无边框全屏 (a borderless
## window over the whole screen). Settings files before version 4 had only windowed and
## "fullscreen", which was the borderless kind; they read as BORDERLESS.
enum Value {
	WINDOWED,
	FULLSCREEN,
	BORDERLESS,
}


static func is_valid(value: int) -> bool:
	return value >= Value.WINDOWED and value <= Value.BORDERLESS


static func storage_value(value: int) -> String:
	match value:
		Value.WINDOWED:
			return "windowed"
		Value.FULLSCREEN:
			return "fullscreen"
		Value.BORDERLESS:
			return "borderless"
	return ""


static func from_storage(value: String) -> int:
	match value:
		"windowed":
			return Value.WINDOWED
		"fullscreen":
			return Value.FULLSCREEN
		"borderless":
			return Value.BORDERLESS
	return -1
