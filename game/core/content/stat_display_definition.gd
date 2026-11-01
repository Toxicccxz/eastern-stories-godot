class_name StatDisplayDefinition
extends RefCounted

## One number the player reads (现代基线 C; DECISIONS「数值用到才出现」): its name, its one
## line of explanation, and what makes it appear. Data (data/common/stats_display.json); with
## no `when_*` it always shows. shown() reads the state and draws nothing.

const RESOURCES: Array[String] = ["mana", "atman"]
const NONZERO_VALUES: Array[String] = ["bellicosity", "force_factor"]

var stat_id: StringName
var display_name: String
var hint: String
## The skill whose raw level makes it appear (&"": none).
var when_skill: StringName = &""
## The resource whose current or maximum makes it appear (RESOURCES; "": none).
var when_resource: String = ""
## The value that makes it appear while it is not 0 (NONZERO_VALUES; "": none). 杀气 can go
## below 0 (a donation does not stop at it).
var when_nonzero: String = ""


func _init(p_stat_id: StringName, p_display_name: String, p_hint: String) -> void:
	stat_id = p_stat_id
	display_name = p_display_name
	hint = p_hint


## Whether `state` has a use for it. The 经典 pace does not ask (ContentCatalog.stat_shown()).
func shown(state: CharacterState) -> bool:
	if when_skill.is_empty() and when_resource.is_empty() and when_nonzero.is_empty():
		return true
	if not when_skill.is_empty() and state.skills.raw_level(when_skill) > 0:
		return true
	if not when_nonzero.is_empty() and _value(state) != 0:
		return true
	if when_resource.is_empty():
		return false
	var resource: CharacterInternalResourceState = state.recovery.mana if when_resource == "mana" else state.recovery.atman
	return resource.current != 0 or resource.maximum != 0


func _value(state: CharacterState) -> int:
	return state.attributes.bellicosity if when_nonzero == "bellicosity" else state.attributes.force_factor


## {id, name, hint, when_skill?, when_resource?: mana | atman, when_nonzero?: bellicosity | force_factor}
static func from_record(reader: ContentRecordReader) -> StatDisplayDefinition:
	var stat := StatDisplayDefinition.new(StringName(reader.required_text("id")), reader.required_text("name"), reader.required_text("hint"))
	stat.when_skill = StringName(reader.text("when_skill"))
	stat.when_resource = reader.text("when_resource")
	stat.when_nonzero = reader.text("when_nonzero")
	if not stat.when_resource.is_empty() and not RESOURCES.has(stat.when_resource):
		reader.fail("when_resource", "'%s' is not one of %s" % [stat.when_resource, RESOURCES])
	if not stat.when_nonzero.is_empty() and not NONZERO_VALUES.has(stat.when_nonzero):
		reader.fail("when_nonzero", "'%s' is not one of %s" % [stat.when_nonzero, NONZERO_VALUES])
	reader.finish()
	return stat
