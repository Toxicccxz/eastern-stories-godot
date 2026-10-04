class_name SpecialAttackSource
extends RefCounted

## combatd.c do_attack() as a special file reaches it: the fight that runs the file
## supplies one (CombatSpecialAttackSource). Without one no attack happens.


## do_attack(attacker, victim, attacker's weapon): a TYPE_REGULAR attack, or null when
## it cannot run.
func attack(_attacker_id: StringName, _victim_id: StringName) -> SpecialAttack:
	return null
