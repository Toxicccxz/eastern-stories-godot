class_name CombatRandomSource
extends RefCounted

## Narrow random boundary for deterministic Combat Core rules.
## Implementations must return 0 <= value < exclusive_upper_bound.
func next_below(_exclusive_upper_bound: int) -> int:
	return -1
