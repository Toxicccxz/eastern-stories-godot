class_name NpcInitializationRandomSource
extends RefCounted

## Returns a value in [0, exclusive_upper_bound). Runtime adapters may wrap a
## RandomNumberGenerator; deterministic tests provide scripted values.
func next_below(_exclusive_upper_bound: int) -> int:
	return -1


## MudOS random(n): n <= 0 returns 0 without a draw; otherwise next_below(n).
## Every LPC random() site calls this (global rule, docs/migration/DECISIONS.md).
func legacy_random(n: int) -> int:
	return 0 if n <= 0 else next_below(n)
