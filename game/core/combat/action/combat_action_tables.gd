class_name CombatActionTables
extends RefCounted

## The attack actions that come from no skill (common/combat_actions.json): a
## race's own moves (race/human.c combat_action, its default_actions) and
## weapond.c's verbs with the verbs each weapon kind sets (std/weapon/<kind>.c).
## Every kind the mudlib's weapons use has its verbs (hammers and staffs bash, crush
## and slam; throwing weapons throw); a kind without any attacks with `slash`.
const SLASH_VERB: StringName = &"slash"

var _race_actions: Dictionary[StringName, CombatActionSet] = {}
var _verb_actions: Dictionary[StringName, CombatActionDefinition] = {}
var _weapon_verbs: Dictionary[StringName, Array] = {}


## The race's own moves; null for a race without any in data.
func race_action_set(race_id: StringName) -> CombatActionSet:
	return _race_actions.get(race_id)


## weapond.c query_action(): a verb of the weapon kind's `verbs`, drawn by the
## caller. A kind whose verbs are not in data attacks with `slash`.
func weapon_action_set(skill_type: StringName) -> CombatActionSet:
	var actions: Array[CombatActionDefinition] = []
	for verb: StringName in _weapon_verbs.get(skill_type, [SLASH_VERB]):
		actions.append(_verb_actions.get(verb))
	return CombatActionSet.new(actions)


## `race_actions` record: {race, legacy_source, actions: [action]}.
func add_race(reader: ContentRecordReader) -> void:
	var race_id: StringName = StringName(reader.required_text("race"))
	var prefix: String = "es2:%s/" % reader.required_text("legacy_source").trim_suffix(".c")
	var actions: Array[CombatActionDefinition] = []
	for action: ContentRecordReader in reader.children("actions"):
		actions.append(CombatActionDefinition.from_record(action, prefix))
	var action_set := CombatActionSet.new(actions)
	if _race_actions.has(race_id):
		reader.fail("race", "'%s' already has actions" % race_id)
	elif not action_set.is_valid():
		reader.fail("actions", "needs at least one action, IDs unique")
	else:
		_race_actions[race_id] = action_set
	reader.finish()


## `weapon_actions` record: {legacy_source (weapond.c), actions: [action, id = verb],
## verbs: [{skill, verbs, legacy_source}]}.
func add_weapon_actions(reader: ContentRecordReader) -> void:
	var prefix: String = "es2:%s/" % reader.required_text("legacy_source").trim_suffix(".c")
	for record: ContentRecordReader in reader.children("actions"):
		var verb: StringName = StringName(record.text("id"))
		var action: CombatActionDefinition = CombatActionDefinition.from_record(record, prefix)
		if _verb_actions.has(verb):
			reader.fail("actions", "verb '%s' is defined twice" % verb)
		_verb_actions[verb] = action
	if not _verb_actions.has(SLASH_VERB):
		reader.fail("actions", "the fallback verb 'slash' is required")
	for record: ContentRecordReader in reader.children("verbs"):
		var skill_type: StringName = StringName(record.required_text("skill"))
		var verbs: Array[StringName] = []
		for verb: String in record.text_list("verbs"):
			if not _verb_actions.has(StringName(verb)):
				record.fail("verbs", "unknown verb '%s'" % verb)
			verbs.append(StringName(verb))
		record.required_text("legacy_source")
		record.finish()
		if verbs.is_empty() or _weapon_verbs.has(skill_type):
			reader.fail("verbs", "'%s' needs one list of verbs" % skill_type)
		_weapon_verbs[skill_type] = verbs
	reader.finish()
