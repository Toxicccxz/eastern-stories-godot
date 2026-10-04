class_name SkillDefinition
extends RefCounted

enum Kind {
	BASIC,
	SPECIALIZED,
}

enum Type {
	MARTIAL,
	KNOWLEDGE,
}

var skill_id: StringName
## to_chinese(skill): chinesed.c's dictionary is not in the mudlib, so the name is authored.
var display_name: String
var kind: int
var skill_type: int
var is_force_style: bool
var legacy_source_path: String
## The skill inherits std/force.c and keeps its hit_ob(): combatd.c's force hit
## (StandardForceHitPolicy) when it is the mapped force.
var standard_force_hit: bool = false
## The skill defines its own hit_ob() (iceforce, spicyclaw, ts-fist), which is not
## ported: a fight that would call it stops instead of skipping it.
var has_own_hit_ob: bool = false
## query_dodge_msg(): what a dodge with this skill looks like ($n dodges $N).
var dodge_messages: Array[String] = []
## parry.c query_parry_msg(weapon): against an armed and an unarmed attacker.
var parry_messages_armed: Array[String] = []
var parry_messages_unarmed: Array[String] = []
## practice_skill() (practice.c): what it writes when it lets the practice happen,
## and its notify_fail() when it does not ("" when it sets none).
var practice_done: String = ""
var practice_fail: String = ""
## skill_improved(): the line it prints when its effect applies, in its colour.
var improved_line: String = ""
var improved_color: StringName = ColoredLine.PLAIN
## The exert functions its exert_function_file() reaches (ExertFunctions ids).
var exert_functions: Array[StringName] = []
var _valid_enabled_uses: Array[StringName] = []
var _actions: Array[CombatActionDefinition] = []
var _practice: PracticePolicy
## valid_learn()'s notify_fail() lines by the rule that refused (VALID_LEARN_KEYS).
var _valid_learn_lines: Dictionary[String, String] = {}

## The SkillLearnPolicyResult reasons whose valid_learn() line skills.json can author.
const VALID_LEARN_KEYS: Dictionary[String, Array] = {
	"max_force": [SkillLearnPolicyResult.Reason.MAXIMUM_INNER_FORCE_TOO_LOW],
	"mapped": [SkillLearnPolicyResult.Reason.MAPPED_SKILL_MISMATCH],
	"weapon": [
		SkillLearnPolicyResult.Reason.PRIMARY_WEAPON_MISSING,
		SkillLearnPolicyResult.Reason.PRIMARY_WEAPON_SKILL_TYPE_MISMATCH,
	],
	"empty_hands": [SkillLearnPolicyResult.Reason.WEAPON_REFERENCES_NOT_EMPTY],
}


func _init(
	p_skill_id: StringName = &"",
	p_kind: int = Kind.BASIC,
	p_skill_type: int = Type.MARTIAL,
	p_is_force_style: bool = false,
	p_valid_enabled_uses: Array[StringName] = [],
	p_legacy_source_path: String = "",
) -> void:
	skill_id = p_skill_id
	kind = p_kind
	skill_type = p_skill_type
	is_force_style = p_is_force_style
	## Definitions may be shared, so never retain or expose a caller-owned
	## mutable collection.
	_valid_enabled_uses = p_valid_enabled_uses.duplicate()
	legacy_source_path = p_legacy_source_path


func can_enable_for(use_id: StringName) -> bool:
	return _valid_enabled_uses.has(use_id)


func valid_enabled_uses() -> Array[StringName]:
	return _valid_enabled_uses.duplicate()


## query_action(): the moves a mapped martial art draws from (combatd.c do_attack);
## null when the skill has none.
func action_set() -> CombatActionSet:
	return null if _actions.is_empty() else CombatActionSet.new(_actions)


## practice_skill() as a rule. A skill daemon without one makes practice.c's
## call return 0: the practice never happens.
func practice_policy() -> PracticePolicy:
	return _practice if _practice != null else UnpracticeablePracticePolicy.new(skill_id)


## The line valid_learn() sets when `result` refused, or "" when it sets none and
## the command's own notify_fail() stays (MudOS: the last call wins).
func valid_learn_line(result: SkillLearnPolicyResult) -> String:
	if result == null:
		return ""
	for key: String in _valid_learn_lines:
		if VALID_LEARN_KEYS[key].has(result.reason):
			return _valid_learn_lines[key]
	return ""


## A skills.json record: {id, name, kind basic|specialized, type martial|knowledge,
## enable?: [use], legacy_source, actions?: [action], dodge_messages?: [line],
## parry_messages?: {armed, unarmed}, standard_force_hit?, hit_ob?,
## practice?: {kee?, force?, done?, fail?, refuses?}, valid_learn?: {key: line},
## improved_line?, improved_color?, exert?: [function]}.
static func from_record(reader: ContentRecordReader) -> SkillDefinition:
	var kinds: Dictionary[String, int] = {"basic": Kind.BASIC, "specialized": Kind.SPECIALIZED}
	var types: Dictionary[String, int] = {"martial": Type.MARTIAL, "knowledge": Type.KNOWLEDGE}
	var kind_text: String = reader.required_text("kind")
	var type_text: String = reader.required_text("type")
	var uses: Array[StringName] = []
	for use: String in reader.text_list("enable"):
		uses.append(StringName(use))
	var definition := SkillDefinition.new(
		StringName(reader.required_text("id")), kinds.get(kind_text, Kind.BASIC), types.get(type_text, Type.MARTIAL),
		false, uses, reader.required_text("legacy_source"),
	)
	definition.display_name = reader.required_text("name")
	definition.standard_force_hit = reader.boolean("standard_force_hit", false)
	definition.has_own_hit_ob = reader.boolean("hit_ob", false)
	if definition.standard_force_hit and definition.has_own_hit_ob:
		reader.fail("hit_ob", "a skill with its own hit_ob() is not std/force.c's")
	definition.dodge_messages = reader.text_list("dodge_messages")
	var parry: ContentRecordReader = reader.child("parry_messages")
	if parry != null:
		definition.parry_messages_armed = parry.text_list("armed")
		definition.parry_messages_unarmed = parry.text_list("unarmed")
		parry.finish()
	var practice: ContentRecordReader = reader.child("practice")
	if practice != null:
		definition.practice_done = practice.text("done")
		definition.practice_fail = practice.text("fail")
		if practice.boolean("refuses", false):
			definition._practice = UnpracticeablePracticePolicy.new(definition.skill_id)
		else:
			var kee: int = practice.integer("kee")
			var force: int = practice.integer("force")
			# practice_skill(): kee and force both at least the cost, then both spent.
			definition._practice = VitalityInnerForcePracticePolicy.new(definition.skill_id, kee, kee, force, force)
		practice.finish()
	definition._valid_learn_lines = reader.text_map("valid_learn")
	for key: String in definition._valid_learn_lines:
		if not VALID_LEARN_KEYS.has(key):
			reader.fail("valid_learn", "unknown rule %s (expected %s)" % [key, ", ".join(VALID_LEARN_KEYS.keys())])
	definition.improved_line = reader.text("improved_line")
	definition.improved_color = StringName(reader.text("improved_color"))
	if definition.improved_color not in [ColoredLine.PLAIN, ColoredLine.HIR, ColoredLine.HIY, ColoredLine.HIC, ColoredLine.HIW]:
		reader.fail("improved_color", "expected HIR, HIY, HIC or HIW")
	for function_id: String in reader.text_list("exert"):
		if not ExertFunctions.has(StringName(function_id)):
			reader.fail("exert", "no exert function %s (expected %s)" % [function_id, ", ".join(ExertFunctions.ORDER)])
		definition.exert_functions.append(StringName(function_id))
	var id_prefix: String = "es2:%s/" % definition.legacy_source_path.trim_suffix(".c")
	for action: ContentRecordReader in reader.children("actions"):
		definition._actions.append(CombatActionDefinition.from_record(action, id_prefix))
	if not definition._actions.is_empty() and not CombatActionSet.new(definition._actions).is_valid():
		reader.fail("actions", "action IDs must be unique")
	if not kinds.has(kind_text):
		reader.fail("kind", "expected basic or specialized")
	if not types.has(type_text):
		reader.fail("type", "expected martial or knowledge")
	if (definition.kind == Kind.SPECIALIZED) == uses.is_empty():
		reader.fail("enable", "a specialized skill is enabled for a use, a basic one for none")
	reader.finish()
	return definition
