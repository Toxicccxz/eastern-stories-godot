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
## What its hit_ob() adds after std/force.c's (iceforce.c's wound and iceshock), or null.
var force_hit_wound: ForceHitWound
## query_dodge_msg(): what a dodge with this skill looks like ($n dodges $N).
var dodge_messages: Array[String] = []
## parry.c query_parry_msg(weapon): against an armed and an unarmed attacker.
var parry_messages_armed: Array[String] = []
var parry_messages_unarmed: Array[String] = []
## practice_skill() (practice.c): what it writes when it lets the practice happen,
## and its notify_fail() when it does not ("" when it sets none); the one for the
## weapon in hand is apart (spring-blade.c checks the weapon before kee).
var practice_done: String = ""
var practice_fail: String = ""
var practice_weapon_fail: String = ""
## celestrike.c says another line when inner force is short ("" uses practice_fail).
var practice_force_fail: String = ""
## necromancy.c says its own line for mana and for sen (PracticePolicy.refusal() keys).
var practice_refusal_lines: Dictionary[StringName, String] = {}
## skill_improved(): the line it prints when its effect applies, in its colour.
var improved_line: String = ""
var improved_color: StringName = ColoredLine.PLAIN
## The line shows only on levels divisible by this (six-chaos-sword.c: every tenth);
## 0 shows it on every level skill_improved() runs.
var improved_every: int = 0
## The exert functions its exert_function_file() reaches (ExertFunctions ids).
var exert_functions: Array[StringName] = []
## The perform actions and spells its perform_action_file() and cast_spell_file()
## reach (SpecialFunctions ids).
var perform_functions: Array[StringName] = []
var cast_functions: Array[StringName] = []
## The 符 its scribe_spell_file() reaches (SpecialFunctions.SCRIBES ids).
var scribe_functions: Array[StringName] = []
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
	"bellicosity": [SkillLearnPolicyResult.Reason.BELLICOSITY_TOO_LOW],
	"max_bellicosity": [SkillLearnPolicyResult.Reason.BELLICOSITY_TOO_HIGH],
	"max_mana": [SkillLearnPolicyResult.Reason.MAXIMUM_MANA_TOO_LOW],
	"raw_skill": [SkillLearnPolicyResult.Reason.RAW_SKILL_TOO_LOW],
	"gender": [SkillLearnPolicyResult.Reason.GENDER_MISMATCH],
	"spi": [SkillLearnPolicyResult.Reason.BASE_SPIRITUALITY_TOO_LOW],
	"strength": [SkillLearnPolicyResult.Reason.STRENGTH_AND_INNER_FORCE_TOO_LOW],
	"effective_skill": [SkillLearnPolicyResult.Reason.EFFECTIVE_SKILL_TOO_LOW],
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
## parry_messages?: {armed, unarmed}, standard_force_hit?, force_hit_wound?: ForceHitWound, hit_ob?,
## practice?: {kee?, force?, mana?, sen?, weapon?, done?, fail?, force_fail?, mana_fail?, sen_fail?, weapon_fail?,
## refuses?, conjure?: PracticeConjuring}, valid_learn?: {key: line},
## improved_line?, improved_color?, improved_every?, exert?: [function], perform?: [action], cast?: [spell]}.
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
	var wound: ContentRecordReader = reader.child("force_hit_wound")
	if wound != null:
		definition.force_hit_wound = ForceHitWound.from_record(wound)
		if not definition.standard_force_hit:
			reader.fail("force_hit_wound", "goes after std/force.c's hit_ob(): needs standard_force_hit")
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
		definition.practice_weapon_fail = practice.text("weapon_fail")
		definition.practice_force_fail = practice.text("force_fail")
		if practice.boolean("refuses", false):
			definition._practice = UnpracticeablePracticePolicy.new(definition.skill_id)
			# kee, force and weapon stay unread (finish() reports them); weapon_fail was read above.
			if practice.has("weapon_fail"):
				practice.fail("weapon_fail", "a skill that refuses practice checks no weapon")
		else:
			var kee: int = practice.integer("kee")
			var force: int = practice.integer("force")
			var mana: int = practice.integer("mana")
			var sen: int = practice.integer("sen")
			for key: String in ["mana", "sen"]:
				var line: String = practice.text(key + "_fail")
				if line.is_empty():
					continue
				if practice.integer(key) <= 0:
					practice.fail(key + "_fail", "goes with " + key)
				definition.practice_refusal_lines[StringName(key)] = line
			var weapon: StringName = StringName(practice.text("weapon"))
			if not weapon.is_empty() and not SkillUseIds.is_enable_command_use(weapon):
				practice.fail("weapon", "not a skill_type enable.c knows")
			if weapon.is_empty() != definition.practice_weapon_fail.is_empty():
				practice.fail("weapon_fail", "goes with weapon")
			if not definition.practice_force_fail.is_empty() and force <= 0:
				practice.fail("force_fail", "goes with force")
			# practice_skill(): the weapon, then kee, force and sen each at least the cost, then all spent.
			definition._practice = VitalityInnerForcePracticePolicy.new(definition.skill_id, kee, kee, force, force, weapon).with_mana(mana, mana).with_spirit(sen, sen)
			var conjure: ContentRecordReader = practice.child("conjure")
			if conjure != null:
				definition._practice.conjuring = PracticeConjuring.from_record(conjure)
		practice.finish()
	definition._valid_learn_lines = reader.text_map("valid_learn")
	for key: String in definition._valid_learn_lines:
		if not VALID_LEARN_KEYS.has(key):
			reader.fail("valid_learn", "unknown rule %s (expected %s)" % [key, ", ".join(VALID_LEARN_KEYS.keys())])
	definition.improved_line = reader.text("improved_line")
	definition.improved_color = StringName(reader.text("improved_color"))
	definition.improved_every = reader.integer("improved_every")
	if definition.improved_every < 0 or (definition.improved_every > 0 and definition.improved_line.is_empty()):
		reader.fail("improved_every", "a period of 0 or more, for an improved_line")
	if definition.improved_color != ColoredLine.PLAIN and not ColoredLine.COLORS.has(definition.improved_color):
		reader.fail("improved_color", "expected one of %s" % ", ".join(ColoredLine.COLORS))
	for function_id: String in reader.text_list("exert"):
		if not ExertFunctions.has(StringName(function_id)):
			reader.fail("exert", "no exert function %s (expected %s)" % [function_id, ", ".join(ExertFunctions.ORDER)])
		definition.exert_functions.append(StringName(function_id))
	for function_id: String in reader.text_list("perform"):
		if not SpecialFunctions.PERFORMS.has(StringName(function_id)):
			reader.fail("perform", "no perform action %s (expected %s)" % [function_id, ", ".join(SpecialFunctions.PERFORMS)])
		definition.perform_functions.append(StringName(function_id))
	for function_id: String in reader.text_list("cast"):
		if not SpecialFunctions.CASTS.has(StringName(function_id)):
			reader.fail("cast", "no spell %s (expected %s)" % [function_id, ", ".join(SpecialFunctions.CASTS)])
		definition.cast_functions.append(StringName(function_id))
	for function_id: String in reader.text_list("scribe"):
		if not SpecialFunctions.SCRIBES.has(StringName(function_id)):
			reader.fail("scribe", "no scribe file %s (expected %s)" % [function_id, ", ".join(SpecialFunctions.SCRIBES)])
		definition.scribe_functions.append(StringName(function_id))
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
