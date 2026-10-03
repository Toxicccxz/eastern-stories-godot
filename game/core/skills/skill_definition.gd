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
var _valid_enabled_uses: Array[StringName] = []
var _actions: Array[CombatActionDefinition] = []


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


## A skills.json record: {id, name, kind basic|specialized, type martial|knowledge,
## enable?: [use], legacy_source, actions?: [action], dodge_messages?: [line],
## parry_messages?: {armed, unarmed}, standard_force_hit?, hit_ob?}.
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
