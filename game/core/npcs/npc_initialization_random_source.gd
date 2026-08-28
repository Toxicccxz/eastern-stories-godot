class_name NpcInitializationRandomSource
extends RefCounted

## Returns a value in [0, exclusive_upper_bound). Runtime adapters may wrap a
## RandomNumberGenerator; deterministic tests provide scripted values.
func next_below(_exclusive_upper_bound: int) -> int:
	return -1
