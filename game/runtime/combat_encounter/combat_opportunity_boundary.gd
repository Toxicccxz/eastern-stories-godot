class_name CombatOpportunityBoundary
extends RefCounted

## Synchronous outer boundary, never inside a forward/reverse attack chain.
## False means stop this batch before any further opportunity or RNG draw.
func inspect(_bindings: Array[CombatSliceCharacterBinding], _event: CombatSchedulerEvent = null) -> bool:
	return false

## Typed command result before any accumulated ordinary opportunity.
func accept_tactical(_result: CombatTacticalExecutionResult) -> void:
	pass
