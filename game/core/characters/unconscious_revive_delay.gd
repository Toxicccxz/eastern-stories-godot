class_name UnconsciousReviveDelay
extends RefCounted

## feature/damage.c unconcious(): call_out("revive", random(100 - con) + 30).
static func seconds(constitution: int, random_source: CombatRandomSource) -> int:
	if random_source == null:
		return 30
	var bound: int = 100 - constitution
	var draw: int = random_source.legacy_random(bound)
	if bound > 0 and (draw < 0 or draw >= bound):
		return 30
	return draw + 30
