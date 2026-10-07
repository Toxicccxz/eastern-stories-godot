class_name CombatOpportunityBoundary
extends RefCounted

## Synchronous outer boundary, never inside a forward/reverse attack chain.
## False means stop this batch before any further opportunity or RNG draw.
## `tactical`: the player's action run just before (a perform's attacks), if any.
func inspect(
	_bindings: Array[CombatSliceCharacterBinding], _event: CombatSchedulerEvent = null,
	_tactical: CombatTacticalExecutionResult = null,
) -> bool:
	return false

## Typed command result before any accumulated ordinary opportunity.
func accept_tactical(_result: CombatTacticalExecutionResult) -> void:
	pass

## The player's action brought others into the fight (`tactical.joiners`, roar.c):
## take them in before anyone else acts, appending their bindings to `bindings`.
func admit(_bindings: Array[CombatSliceCharacterBinding], _tactical: CombatTacticalExecutionResult) -> void:
	pass
