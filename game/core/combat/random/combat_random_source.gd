class_name CombatRandomSource
extends RefCounted

## Narrow random boundary for deterministic Combat Core rules.
## Implementations must return 0 <= value < exclusive_upper_bound.
func next_below(_exclusive_upper_bound: int) -> int:
	return -1


## MudOS random(n): n <= 0 returns 0 without a draw; otherwise next_below(n).
## Every LPC random() site calls this (global rule, docs/migration/DECISIONS.md).
func legacy_random(n: int) -> int:
	return 0 if n <= 0 else next_below(n)
