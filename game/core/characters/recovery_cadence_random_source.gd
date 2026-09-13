class_name RecoveryCadenceRandomSource
extends RefCounted

## Only the source std/char.c reset draw. Transient, never part of Save RNG.
func draw_reset_tick() -> int:
	return -1
