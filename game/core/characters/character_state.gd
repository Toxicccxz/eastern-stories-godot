class_name CharacterState
extends RefCounted

## Minimal native composition for the character state shared by the original
## CHARACTER features. This phase intentionally contains no combat, skills,
## inventory, NPC, or world behavior.

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


func _init(
	p_attributes: CharacterBaseAttributesType = null,
	p_essence: CharacterResourceStateType = null,
	p_vitality: CharacterResourceStateType = null,
	p_spirit: CharacterResourceStateType = null,
	p_recovery: CharacterRecoveryStateType = null,
	p_conditions: CharacterConditionStateType = null,
) -> void:
	attributes = p_attributes if p_attributes != null else CharacterBaseAttributesType.new()
	essence = p_essence if p_essence != null else CharacterResourceStateType.new()
	vitality = p_vitality if p_vitality != null else CharacterResourceStateType.new()
	spirit = p_spirit if p_spirit != null else CharacterResourceStateType.new()
	recovery = p_recovery if p_recovery != null else CharacterRecoveryStateType.new()
	conditions = p_conditions if p_conditions != null else CharacterConditionStateType.new()


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
