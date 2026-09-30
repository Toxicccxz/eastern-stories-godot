class_name UnconsciousReviveDelay
extends RefCounted

## feature/damage.c unconcious(): call_out("revive", random(100 - con) + 30).
## MudOS random(n) with n <= 0 returns 0 without a draw.
static func seconds(constitution: int, random_source: CombatRandomSource) -> int:
	var bound: int = 100 - constitution
	if bound <= 0 or random_source == null:
		return 30
	var draw: int = random_source.next_below(bound)
	if draw < 0 or draw >= bound:
		return 30
	return draw + 30
