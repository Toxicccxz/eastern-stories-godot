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

## Who fell or died at the last inspect() (combatd.c announce()), taken once.
func take_announcements() -> Array[CombatLifecycleAnnouncement]:
	return []

## Typed command result before any accumulated ordinary opportunity.
func accept_tactical(_result: CombatTacticalExecutionResult) -> void:
	pass

## The player's action brought others into the fight (`tactical.joiners`, roar.c):
## take them in before anyone else acts, appending their bindings to `bindings`.
func admit(_bindings: Array[CombatSliceCharacterBinding], _tactical: CombatTacticalExecutionResult) -> void:
	pass

## An NPC walked out of the fight to `zone_id` (go.c, random_move() in its chat).
func depart(_bindings: Array[CombatSliceCharacterBinding], _character_id: StringName, _zone_id: StringName) -> void:
	pass
