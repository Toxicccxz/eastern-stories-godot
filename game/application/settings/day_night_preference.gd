class_name DayNightPreference
extends RefCounted

## The 昼夜 setting (DECISIONS「昼夜」): a setting, not the save, as BattlePace is. 跟随游戏时间
## lights the voxel view by the DayClock; 一直白天 and 一直夜晚 hold the day or the night
## frame, at once, for the owner's look at a map by night. The application settings set it
## once loaded and on 应用.
enum Value { FOLLOW, DAY, NIGHT }

const STORAGE: Dictionary[int, String] = {Value.FOLLOW: "follow", Value.DAY: "day", Value.NIGHT: "night"}

static var mode: int = Value.FOLLOW


static func is_valid(value: int) -> bool:
	return STORAGE.has(value)


static func storage_value(value: int) -> String:
	return STORAGE.get(value, STORAGE[Value.FOLLOW])


## -1 for a stored value that is none of the three.
static func from_storage(text: String) -> int:
	for value: int in STORAGE:
		if STORAGE[value] == text:
			return value
	return -1
