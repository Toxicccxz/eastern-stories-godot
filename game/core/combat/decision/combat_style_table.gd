class_name CombatStyleTable
extends RefCounted

## The fight styles the data defines (combat_styles.json), by ID, and the default of each
## race (DECISIONS「战斗内容」). Empty (no data): nobody has a style — random(n), the knob's
## cooldown for all.

var _styles: Dictionary[StringName, CombatStyle] = {}
var _defaults: Dictionary[StringName, CombatStyle] = {}


func add(style: CombatStyle, reader: ContentRecordReader = null) -> void:
	if _styles.has(style.style_id):
		if reader != null:
			reader.fail("id", "fight style '%s' is already defined" % style.style_id)
		return
	_styles[style.style_id] = style
	for race: StringName in style.default_for:
		if _defaults.has(race):
			if reader != null:
				reader.fail("default_for", "race '%s' already has a default style" % race)
			continue
		_defaults[race] = style


func style(style_id: StringName) -> CombatStyle:
	return _styles.get(style_id)


func has(style_id: StringName) -> bool:
	return _styles.has(style_id)


func ids() -> Array[StringName]:
	var result: Array[StringName] = []
	result.assign(_styles.keys())
	return result


## The style an NPC fights in: its own when named, else its race's default, else null.
func style_of(npc: NpcDefinition) -> CombatStyle:
	if npc == null:
		return null
	if not npc.fight_style.is_empty():
		return _styles.get(npc.fight_style)
	return _defaults.get(npc.race_id)


func is_empty() -> bool:
	return _styles.is_empty()
