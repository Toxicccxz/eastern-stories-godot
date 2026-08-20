class_name UnpracticeablePracticePolicy
extends "res://core/training/practice_policy.gd"

## Represents daemons such as fonxanforce.c whose valid_learn() succeeds but
## practice_skill() always rejects direct practice.
func practice(_character: CharacterStateType) -> bool:
	return false
