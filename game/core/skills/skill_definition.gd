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
var _valid_enabled_uses: Array[StringName] = []


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


## A skills.json record: {id, name, kind basic|specialized, type martial|knowledge,
## enable?: [use], legacy_source}.
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
	if not kinds.has(kind_text):
		reader.fail("kind", "expected basic or specialized")
	if not types.has(type_text):
		reader.fail("type", "expected martial or knowledge")
	if (definition.kind == Kind.SPECIALIZED) == uses.is_empty():
		reader.fail("enable", "a specialized skill is enabled for a use, a basic one for none")
	reader.finish()
	return definition
