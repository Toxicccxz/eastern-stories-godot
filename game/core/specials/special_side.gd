class_name SpecialSide
extends RefCounted

## One character a perform, cast or exert file works on, as the LPC asks it: its
## state and busy, query_temp("apply/<key>") (armor, weapon, create() and timed
## applies, from `applies`), its fight (feature/attack.c: whom it fights and kills,
## last_opponent; none outside a fight) and whether it is living() (conscious).
var character_id: StringName
var state: CharacterState
var busy: ActionBusyState
var relationship: CombatRelationshipState
var living: bool = true
## A player (userp()): improve_skill() in weak mode gives no level.
var is_user: bool = false
## query("age"), for rankd.c's words.
var age: int = 0
## (key: StringName) -> int; none adds nothing.
var _applies: Callable


func _init(
	p_character_id: StringName = &"", p_state: CharacterState = null, p_busy: ActionBusyState = null,
	p_relationship: CombatRelationshipState = null, p_applies: Callable = Callable(),
) -> void:
	character_id = p_character_id
	state = p_state
	busy = p_busy
	relationship = p_relationship
	_applies = p_applies


## query_temp("apply/<key>").
func apply(key: StringName) -> int:
	return _applies.call(key) if _applies.is_valid() else 0


## feature/skill.c query_skill(skill): apply/<skill>, half the raw level and the
## level of the skill it is mapped to.
func query_skill(skill_id: StringName) -> int:
	return state.skills.effective_level(skill_id, apply(skill_id))


## feature/attack.c is_fighting(ob).
func is_fighting(other_id: StringName) -> bool:
	return relationship != null and relationship.has_opponent(other_id)


## feature/attack.c is_killing(id).
func is_killing(other_id: StringName) -> bool:
	return relationship != null and relationship.has_lethal_target(other_id)
