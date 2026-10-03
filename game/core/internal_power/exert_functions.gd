class_name ExertFunctions
extends RefCounted

## The exert function files the game has, by the name exert.c is given. A force
## skill's exert_function_file() reaches those skills.json lists under `exert`.
## Labels follow doc/help/force (regenerate 恢复自己的精 …).

const ORDER: Array[StringName] = [&"heal", &"recover", &"refresh", &"regenerate"]
# TRANSLATORS: doc/help/force: what an exert function does, as a button (运功 X).
const LABELS: Dictionary[StringName, String] = {
	&"heal": "疗伤",
	&"recover": "恢复气",
	&"refresh": "恢复神",
	&"regenerate": "恢复精",
}

static var _functions: Dictionary[StringName, ExertFunction] = {}


static func find(function_id: StringName) -> ExertFunction:
	if _functions.is_empty():
		var all: Array[ExertFunction] = [
			HealExertFunction.new(),
			RestoreExertFunction.new(&"recover", RestoreExertFunction.Track.KEE,
				"你的气已经恢复到上限了。", "$N深深吸了几口气，脸色看起来好多了。"),
			RestoreExertFunction.new(&"refresh", RestoreExertFunction.Track.SEN,
				"你的神已经恢复到上限了。", "$N微一凝神，缓缓地吸了口气，看起来有精神多了。"),
			RestoreExertFunction.new(&"regenerate", RestoreExertFunction.Track.GIN,
				"你的精力已经恢复到上限了。", "$N深深地吸了口气，手脚活动了几下，看起来有活力多了。"),
		]
		for function: ExertFunction in all:
			_functions[function.id] = function
	return _functions.get(function_id)


static func has(function_id: StringName) -> bool:
	return ORDER.has(function_id)
