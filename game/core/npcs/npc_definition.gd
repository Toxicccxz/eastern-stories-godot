class_name NpcDefinition
extends RefCounted

const AttributeOverridesType := preload(
	"res://core/npcs/npc_base_attribute_overrides.gd"
)
const ResourceOverridesType := preload("res://core/npcs/npc_resource_overrides.gd")
const SkillLevelType := preload("res://core/npcs/npc_skill_level_definition.gd")
const LoadoutEntryType := preload("res://core/npcs/npc_loadout_entry.gd")

enum Attitude {
	PEACEFUL,
	AGGRESSIVE,
}

var _definition_id: StringName
var _legacy_source_path: String
var _display_name: String
var _aliases: Array[StringName] = []
var _race_id: StringName
var _has_authored_gender: bool
var _gender: StringName
var _has_authored_age: bool
var _age: int
var _base_attribute_overrides: AttributeOverridesType
var _resource_overrides: ResourceOverridesType
var _combat_experience: int
var _score: int
var _attitude: int
var _skill_levels: Array[NpcSkillLevelDefinition] = []
var _loadout_entries: Array[NpcLoadoutEntry] = []
var _capability_ids: Array[StringName] = []

var definition_id: StringName:
	get:
		return _definition_id
var legacy_source_path: String:
	get:
		return _legacy_source_path
var display_name: String:
	get:
		return _display_name
var race_id: StringName:
	get:
		return _race_id
var has_authored_gender: bool:
	get:
		return _has_authored_gender
var gender: StringName:
	get:
		return _gender
var has_authored_age: bool:
	get:
		return _has_authored_age
var age: int:
	get:
		return _age
var combat_experience: int:
	get:
		return _combat_experience
var score: int:
	get:
		return _score
var attitude: int:
	get:
		return _attitude


func _init(
	p_definition_id: StringName = &"",
	p_legacy_source_path: String = "",
	p_display_name: String = "",
	p_aliases: Array[StringName] = [],
	p_race_id: StringName = &"",
	p_has_authored_gender: bool = false,
	p_gender: StringName = &"",
	p_has_authored_age: bool = false,
	p_age: int = 0,
	p_base_attribute_overrides: AttributeOverridesType = null,
	p_resource_overrides: ResourceOverridesType = null,
	p_combat_experience: int = 0,
	p_score: int = 0,
	p_attitude: int = Attitude.PEACEFUL,
	p_skill_levels: Array[NpcSkillLevelDefinition] = [],
	p_loadout_entries: Array[NpcLoadoutEntry] = [],
	p_capability_ids: Array[StringName] = [],
) -> void:
	_definition_id = p_definition_id
	_legacy_source_path = p_legacy_source_path
	_display_name = p_display_name
	_aliases = p_aliases.duplicate()
	_race_id = p_race_id
	_has_authored_gender = p_has_authored_gender
	_gender = p_gender
	_has_authored_age = p_has_authored_age
	_age = p_age
	_base_attribute_overrides = (
		AttributeOverridesType.new()
		if p_base_attribute_overrides == null
		else p_base_attribute_overrides.duplicate_snapshot()
	)
	_resource_overrides = (
		ResourceOverridesType.new()
		if p_resource_overrides == null
		else p_resource_overrides.duplicate_snapshot()
	)
	for skill: SkillLevelType in p_skill_levels:
		_skill_levels.append(null if skill == null else skill.duplicate_snapshot())
	for entry: LoadoutEntryType in p_loadout_entries:
		_loadout_entries.append(null if entry == null else entry.duplicate_snapshot())
	_combat_experience = p_combat_experience
	_score = p_score
	_attitude = p_attitude
	_capability_ids = p_capability_ids.duplicate()


func aliases() -> Array[StringName]:
	return _aliases.duplicate()


func base_attribute_overrides() -> AttributeOverridesType:
	return _base_attribute_overrides.duplicate_snapshot()


func resource_overrides() -> ResourceOverridesType:
	return _resource_overrides.duplicate_snapshot()


func skill_levels() -> Array[NpcSkillLevelDefinition]:
	var result: Array[NpcSkillLevelDefinition] = []
	for skill: SkillLevelType in _skill_levels:
		result.append(skill.duplicate_snapshot())
	return result


func loadout_entries() -> Array[NpcLoadoutEntry]:
	var result: Array[NpcLoadoutEntry] = []
	for entry: LoadoutEntryType in _loadout_entries:
		result.append(entry.duplicate_snapshot())
	return result


func capability_ids() -> Array[StringName]:
	return _capability_ids.duplicate()


func has_capability(capability_id: StringName) -> bool:
	return _capability_ids.has(capability_id)


func is_valid() -> bool:
	if (
		_definition_id.is_empty()
		or _legacy_source_path.is_empty()
		or _display_name.is_empty()
		or _aliases.is_empty()
		or _race_id.is_empty()
		or (_has_authored_gender and _gender.is_empty())
		or _attitude < Attitude.PEACEFUL
		or _attitude > Attitude.AGGRESSIVE
	):
		return false
	if not _unique_non_empty_ids(_aliases) or not _unique_non_empty_ids(_capability_ids):
		return false
	var skill_ids: Dictionary[StringName, bool] = {}
	for skill: SkillLevelType in _skill_levels:
		if skill == null or not skill.is_valid() or skill_ids.has(skill.skill_id):
			return false
		skill_ids[skill.skill_id] = true
	for entry: LoadoutEntryType in _loadout_entries:
		if entry == null or not entry.is_valid():
			return false
	return true


static func _unique_non_empty_ids(ids: Array[StringName]) -> bool:
	var seen: Dictionary[StringName, bool] = {}
	for id: StringName in ids:
		if id.is_empty() or seen.has(id):
			return false
		seen[id] = true
	return true
