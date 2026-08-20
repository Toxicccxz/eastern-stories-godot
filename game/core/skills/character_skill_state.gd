class_name CharacterSkillState
extends RefCounted

const SkillLoadoutType := preload("res://core/skills/skill_loadout.gd")
const SkillProgressStateType := preload("res://core/skills/skill_progress_state.gd")
const SkillImprovementResultType := preload(
	"res://core/skills/skill_improvement_result.gd"
)

## Specific typed equivalents of feature/skill.c's skills and learned maps.
## They are not exposed as a generic dbase or mutable collection.
var _raw_levels: Dictionary[StringName, int] = {}
var _learned_progress: Dictionary[StringName, int] = {}
var _has_skills_mapping: bool = false
var _has_learned_mapping: bool = false
var _loadout: SkillLoadoutType


func _init() -> void:
	## Mapping mutation stays behind map_skill()/unmap_skill() so callers cannot
	## bypass the target-presence and enable-transition boundaries.
	_loadout = SkillLoadoutType.new()


func set_raw_level(skill_id: StringName, level: int) -> void:
	_has_skills_mapping = true
	_raw_levels[skill_id] = level


func set_learned_progress(skill_id: StringName, progress: int) -> void:
	_has_learned_mapping = true
	_learned_progress[skill_id] = progress


func remove_skill(skill_id: StringName) -> bool:
	if not _has_skills_mapping:
		return false
	_raw_levels.erase(skill_id)
	if _has_learned_mapping:
		_learned_progress.erase(skill_id)
	## feature/skill.c returns undefinedp() after deletion, so once the lazy
	## skills mapping exists the legacy return value is true even for a missing ID.
	return true


func has_raw_level(skill_id: StringName) -> bool:
	return _raw_levels.has(skill_id)


## query_skill(skill, 1): missing and explicitly absent skills both read as 0.
func raw_level(skill_id: StringName) -> int:
	return _raw_levels.get(skill_id, 0)


func learned_progress(skill_id: StringName) -> int:
	return _learned_progress.get(skill_id, 0)


func progress_state(skill_id: StringName) -> SkillProgressStateType:
	return SkillProgressStateType.new(
		_raw_levels.has(skill_id),
		raw_level(skill_id),
		_learned_progress.has(skill_id),
		learned_progress(skill_id),
	)


## query_skill(skill): explicit modifier input replaces query_temp("apply/...").
## The mapped special skill contributes its full raw level.
func effective_level(skill_id: StringName, temporary_modifier: int = 0) -> int:
	var value: int = temporary_modifier + raw_level(skill_id) / 2
	if _loadout.has_enabled_skill(skill_id):
		value += raw_level(_loadout.enabled_skill(skill_id))
	return value


## Low-level feature/skill.c mapping semantics: the target must have a defined
## raw entry, but the base/use skill need not be present. Definition-level
## valid_enable checks belong to SkillEnableTransition.
func map_skill(use_id: StringName, mapped_skill_id: StringName) -> bool:
	if not _has_skills_mapping or not _raw_levels.has(mapped_skill_id):
		return false
	_loadout.set_enabled_skill(use_id, mapped_skill_id)
	return true


func unmap_skill(use_id: StringName) -> bool:
	return _loadout.remove_enabled_skill(use_id)


func mapped_skill(use_id: StringName) -> StringName:
	return _loadout.enabled_skill(use_id)


## Deterministic improve_skill() transition. The caller supplies the legacy
## userp() fact explicitly; no command, ability, or runtime dependency is used.
## Returns a typed snapshot; authored skill_improved() effects are processed by
## the separate SkillImprovementEffectRegistry.
func improve_skill(
	skill_id: StringName,
	amount: int,
	base_spirituality: int,
	weak_mode: bool = false,
	is_player_character: bool = true,
) -> SkillImprovementResultType:
	var previous_level: int = raw_level(skill_id)
	var learned_before: int = learned_progress(skill_id)
	var can_gain_raw_level: bool = not weak_mode or not is_player_character
	if can_gain_raw_level:
		_has_skills_mapping = true
		if not _raw_levels.has(skill_id):
			_raw_levels[skill_id] = 0

	var adjusted_amount: int = amount
	var learned_skill_count: int = _learned_progress.size()
	if learned_skill_count > base_spirituality:
		adjusted_amount /= learned_skill_count - base_spirituality
	if adjusted_amount == 0:
		adjusted_amount = 1

	_has_learned_mapping = true
	_learned_progress[skill_id] = learned_progress(skill_id) + adjusted_amount
	var leveled_up: bool = false
	if can_gain_raw_level:
		var next_level: int = raw_level(skill_id) + 1
		var threshold: int = next_level * next_level
		if learned_progress(skill_id) > threshold:
			_raw_levels[skill_id] = next_level
			_learned_progress[skill_id] = 0
			leveled_up = true

	return SkillImprovementResultType.new(
		skill_id,
		previous_level,
		raw_level(skill_id),
		leveled_up,
		learned_before,
		learned_progress(skill_id),
	)
