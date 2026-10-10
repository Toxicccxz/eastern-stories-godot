class_name SpecialAttackSource
extends RefCounted

## combatd.c do_attack() as a special file reaches it: the fight that runs the file
## supplies one (CombatSpecialAttackSource). Without one no attack happens.


## do_attack(attacker, victim, attacker's weapon): a TYPE_REGULAR attack, or null when
## it cannot run.
func attack(_attacker_id: StringName, _victim_id: StringName) -> SpecialAttack:
	return null


## combatd.c fight(attacker, victim): its courage draw first (an attack on one busy or
## lying unconscious at once), then the attack, or a guard line, or nothing (null).
func fight(_attacker_id: StringName, _victim_id: StringName) -> SpecialAttack:
	return null


## feature/attack.c clean_up_enemy() then select_opponent() for `attacker_id` as the
## fight stands now: random(MAX_OPPONENT = 4) picks one of its enemies, the first when
## the draw is past them; empty when it has none.
func select_opponent(_attacker_id: StringName, _random: Callable) -> StringName:
	return &""
