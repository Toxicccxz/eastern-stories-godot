class_name CharacterState
extends RefCounted

## Minimal native composition for the character state shared by the original
## CHARACTER features. It remains pure domain state and contains no training,
## combat, inventory, NPC, or world behavior.

const CharacterBaseAttributesType := preload(
	"res://core/characters/character_base_attributes.gd"
)
const CharacterResourceStateType := preload(
	"res://core/characters/character_resource_state.gd"
)
const CharacterRecoveryStateType := preload(
	"res://core/characters/character_recovery_state.gd"
)
const CharacterConditionStateType := preload(
	"res://core/conditions/character_condition_state.gd"
)
const CharacterSkillStateType := preload("res://core/skills/character_skill_state.gd")
const CharacterProgressionStateType := preload(
	"res://core/characters/character_progression_state.gd"
)
const FamilyStateType := preload("res://core/relationships/family_state.gd")
const ApprenticeshipStateType := preload(
	"res://core/relationships/apprenticeship_state.gd"
)

enum LifeThreshold {
	ACTIVE,
	UNCONSCIOUS,
	DEAD,
}

## Legacy resource mappings:
## essence  -> gin / eff_gin / max_gin
## vitality -> kee / eff_kee / max_kee
## spirit   -> sen / eff_sen / max_sen
var attributes: CharacterBaseAttributesType
var essence: CharacterResourceStateType
var vitality: CharacterResourceStateType
var spirit: CharacterResourceStateType
var recovery: CharacterRecoveryStateType
var conditions: CharacterConditionStateType
var skills: CharacterSkillStateType
var progression: CharacterProgressionStateType
var family: FamilyStateType
var apprenticeship: ApprenticeshipStateType


func _init(
	p_attributes: CharacterBaseAttributesType = null,
	p_essence: CharacterResourceStateType = null,
	p_vitality: CharacterResourceStateType = null,
	p_spirit: CharacterResourceStateType = null,
	p_recovery: CharacterRecoveryStateType = null,
	p_conditions: CharacterConditionStateType = null,
	p_skills: CharacterSkillStateType = null,
	p_progression: CharacterProgressionStateType = null,
	p_family: FamilyStateType = null,
	p_apprenticeship: ApprenticeshipStateType = null,
) -> void:
	attributes = p_attributes if p_attributes != null else CharacterBaseAttributesType.new()
	essence = p_essence if p_essence != null else CharacterResourceStateType.new()
	vitality = p_vitality if p_vitality != null else CharacterResourceStateType.new()
	spirit = p_spirit if p_spirit != null else CharacterResourceStateType.new()
	recovery = p_recovery if p_recovery != null else CharacterRecoveryStateType.new()
	conditions = p_conditions if p_conditions != null else CharacterConditionStateType.new()
	skills = p_skills if p_skills != null else CharacterSkillStateType.new()
	progression = (
		p_progression
		if p_progression != null
		else CharacterProgressionStateType.new()
	)
	family = p_family if p_family != null else FamilyStateType.new()
	apprenticeship = (
		p_apprenticeship
		if p_apprenticeship != null
		else ApprenticeshipStateType.new()
	)


## std/char.c checks effective values first, so death takes precedence when
## both effective and current values have crossed their thresholds.
func life_threshold() -> int:
	if is_death_threshold_reached():
		return LifeThreshold.DEAD
	if is_unconscious_threshold_reached():
		return LifeThreshold.UNCONSCIOUS
	return LifeThreshold.ACTIVE


func is_unconscious_threshold_reached() -> bool:
	return (
		essence.is_unconscious_threshold_reached()
		or vitality.is_unconscious_threshold_reached()
		or spirit.is_unconscious_threshold_reached()
	)


func is_death_threshold_reached() -> bool:
	return (
		essence.is_death_threshold_reached()
		or vitality.is_death_threshold_reached()
		or spirit.is_death_threshold_reached()
	)


func resources_have_valid_invariants() -> bool:
	return (
		essence.has_valid_invariants()
		and vitality.has_valid_invariants()
		and spirit.has_valid_invariants()
	)
