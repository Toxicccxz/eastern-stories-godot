class_name PracticePolicy
extends RefCounted

const CharacterStateType := preload("res://core/characters/character_state.gd")

var skill_id: StringName
## What the practice may conjure once paid for (necromancy.c's 观想虫); null for none.
var conjuring: PracticeConjuring


func _init(p_skill_id: StringName = &"") -> void:
	skill_id = p_skill_id


## Typed replacement for practice_skill(). Implementations may mutate the
## character before returning, matching the LPC hook contract.
func practice(_character: CharacterStateType) -> bool:
	return true


## Whether practice_skill() refuses `character` for the weapon in its hand (its
## own notify_fail(), spring-blade.c's 你必须先找一把刀). Pure: changes nothing.
func refuses_weapon(_character: CharacterStateType) -> bool:
	return false


## Which of practice_skill()'s checks refuses `character` now (&"weapon", &"kee",
## &"force", &"mana", &"sen"), or &"" when none does. Pure: changes nothing.
func refusal(_character: CharacterStateType) -> StringName:
	return &""
