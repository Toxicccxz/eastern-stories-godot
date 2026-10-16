class_name WorldWait
extends RefCounted

## Something the player waits for, as the HUD shows it (DECISIONS「响应性」: what takes
## time is seen): its line, how far it has come, and 继续 when the player may hurry it.

## Already in the shown language.
var text: String
## How far it has come, 0 to 1; below 0: no bar.
var progress: float
## 继续: brings its next step now (-> bool: whether anything was still to come); not valid
## when it cannot be hurried.
var hurry: Callable


func _init(p_text: String, p_progress: float = -1.0, p_hurry: Callable = Callable()) -> void:
	text = p_text
	progress = p_progress
	hurry = p_hurry
