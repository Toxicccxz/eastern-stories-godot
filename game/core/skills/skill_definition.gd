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
