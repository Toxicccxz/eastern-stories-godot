class_name ApplicationUiScale
extends RefCounted

## 界面缩放: the whole interface drawn this many percent of its size (the world camera
## makes up for it, so the map, with the names and labels drawn on it, stays as large as
## at 100%).
const DEFAULT: int = 100
const PERCENTS: Array[int] = [100, 125, 150]


static func is_valid(percent: int) -> bool:
	return PERCENTS.has(percent)


static func factor(percent: int) -> float:
	return float(percent if is_valid(percent) else DEFAULT) / 100.0
