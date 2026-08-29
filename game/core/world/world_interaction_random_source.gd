class_name WorldInteractionRandomSource
extends RefCounted

## Narrow RNG boundary for authored world interactions. The caller owns bound
## validation so legacy non-positive bounds remain ordered typed ambiguities.


func next_below(_exclusive_upper_bound: int) -> int:
	return -1
