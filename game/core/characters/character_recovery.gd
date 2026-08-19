class_name CharacterRecovery
extends RefCounted

## Deterministic translation of one eligible feature/damage.c::heal_up() call.
## Scheduling, conditions, combat state, and the full skill system remain outside
## this pure domain service.

const CharacterStateType := preload("res://core/characters/character_state.gd")
const CharacterResourceStateType := preload(
	"res://core/characters/character_resource_state.gd"
)
const CharacterInternalResourceStateType := preload(
	"res://core/characters/character_internal_resource_state.gd"
)
const RecoverySkillLevelsType := preload(
	"res://core/characters/recovery_skill_levels.gd"
)


## Returns the legacy update_flag count. no_heal_up represents only the
## CND_NO_HEAL_UP decision made by std/char.c; it is not a condition system.
## Whether this calculation is invoked at all remains the caller's lifecycle
## and scheduling decision, matching the boundary around damage.c::heal_up().
static func apply_tick(
	character: CharacterStateType,
	skills: RecoverySkillLevelsType,
	is_player_character: bool,
	no_heal_up: bool = false,
) -> int:
	if no_heal_up:
		return 0

	var update_count: int = 0
	if character.recovery.water > 0:
		character.recovery.water -= 1
		update_count += 1
	if character.recovery.food > 0:
		character.recovery.food -= 1
		update_count += 1

	if character.recovery.water < 1 and is_player_character:
		return update_count

	var constitution_recovery: int = character.attributes.constitution / 3
	if _recover_primary_resource(
		character.essence,
		constitution_recovery + character.recovery.atman.current / 10,
	):
		update_count += 1
	if _recover_primary_resource(
		character.vitality,
		constitution_recovery + character.recovery.inner_force.current / 10,
	):
		update_count += 1
	if _recover_primary_resource(
		character.spirit,
		constitution_recovery + character.recovery.mana.current / 10,
	):
		update_count += 1

	if character.recovery.food < 1 and is_player_character:
		return update_count

	if _recover_internal_resource(character.recovery.atman, skills.raw_magic):
		update_count += 1
	if _recover_internal_resource(character.recovery.inner_force, skills.raw_force):
		update_count += 1
	if _recover_internal_resource(character.recovery.mana, skills.raw_spells):
		update_count += 1

	return update_count


static func maximum_food_capacity(body_weight: int) -> int:
	return body_weight / 200


static func maximum_water_capacity(body_weight: int) -> int:
	return body_weight / 200


## feature/damage.c first heals current, caps it at effective, and then repairs
## effective by exactly one when current reached the old effective value.
static func _recover_primary_resource(
	resource: CharacterResourceStateType,
	recovery_amount: int,
) -> bool:
	resource.current += recovery_amount
	if resource.current >= resource.effective:
		resource.current = resource.effective
		if resource.effective < resource.maximum:
			resource.effective += 1
			return true
		return false
	return true


## The legacy update flag advances whenever the branch is eligible, even when
## raw_skill / 2 is zero and current therefore does not change.
static func _recover_internal_resource(
	resource: CharacterInternalResourceStateType,
	raw_skill: int,
) -> bool:
	if resource.maximum == 0 or resource.current >= resource.maximum:
		return false
	resource.current += raw_skill / 2
	if resource.current > resource.maximum:
		resource.current = resource.maximum
	return true
