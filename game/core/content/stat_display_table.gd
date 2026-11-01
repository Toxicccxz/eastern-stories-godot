class_name StatDisplayTable
extends RefCounted

## The numbers the player reads (stats_display.json), by ID (DECISIONS「数值用到才出现」).

var _stats: Dictionary[StringName, StatDisplayDefinition] = {}


func add(stat: StatDisplayDefinition, reader: ContentRecordReader = null) -> void:
	if _stats.has(stat.stat_id):
		if reader != null:
			reader.fail("id", "stat '%s' is already defined" % stat.stat_id)
		return
	_stats[stat.stat_id] = stat


func stat(stat_id: StringName) -> StatDisplayDefinition:
	return _stats.get(stat_id)


func ids() -> Array[StringName]:
	var result: Array[StringName] = []
	result.assign(_stats.keys())
	return result
