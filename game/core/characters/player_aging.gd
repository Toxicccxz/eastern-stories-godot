class_name PlayerAging
extends RefCounted

## 成长曲线 C (owner 2026-11-19「都照推荐」, plan Q6; DECISIONS「成长曲线 C」): the player grows up as
## they gain experience. ES2 ages a player by the time spent online (obj/user.c update_age(): 14 +
## age_modify + mud_age / 86400, a year for every 24 hours played), and race/human.c's setup_human()
## gives 精 and 气 20 more a year from 15 to 20 (神 stays until 30). The game keeps no such clock: the
## age follows combat_exp instead, by pacing.json's `player_age_by_exp` (left out, the player stays
## the 14 a new character starts at, as with no clock). An age once reached is kept: losing exp (a
## death) takes no year back. Pure: it reads numbers and decides nothing about time.

## One row of `player_age_by_exp`: from `min_exp` combat_exp on, the player is `age`.
class Step:
	extends RefCounted
	var min_exp: int = 0
	var age: int = 0

	func _init(p_min_exp: int = 0, p_age: int = 0) -> void:
		min_exp = p_min_exp
		age = p_age


## The age a player of `current` years comes to at `combat_exp` by `steps`: the oldest step reached,
## never younger than `current`.
static func grown_age(current: int, combat_exp: int, steps: Array[Step]) -> int:
	var age: int = current
	for step: Step in steps:
		if combat_exp >= step.min_exp:
			age = maxi(age, step.age)
	return age
