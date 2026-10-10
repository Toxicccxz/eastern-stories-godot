class_name PlayerObjectReset
extends RefCounted

## obj/user.c reset(), which MudOS calls on the player object on the rooms' schedule
## (TIME_TO_RESET / 2 + random(TIME_TO_RESET / 2) seconds apart): a point of potential while
## less than 100 of it is unspent, and a caught steal forgotten (CrimeRecord).

const UNSPENT_BELOW: int = 100


static func apply(state: CharacterState) -> void:
	if state == null:
		return
	var progression: CharacterProgressionState = state.progression
	if progression.potential - progression.potential_spent < UNSPENT_BELOW:
		progression.potential += 1
	CrimeRecord.reset(state)
