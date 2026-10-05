class_name SpecialAttack
extends RefCounted

## One combatd.c do_attack(me, victim, weapon) a special file calls straight
## (swordjab.c, fakefault.c): the forward attack and, when the victim answered, its
## riposte (`chain`'s reverse attack). `line_index` is how many of the special's lines
## were shown before it. Read-only once made.
var attacker_id: StringName
var victim_id: StringName
var forward: CombatSingleAttackExecutionResult
var chain: CombatAttackChainResult
var line_index: int = 0
## What the player saw of the forward attack's and the riposte's post_actions (bash_weapon,
## throw_weapon), told after each.
var told: Array[ColoredLine] = []
var reverse_told: Array[ColoredLine] = []


func _init(
	p_attacker_id: StringName = &"", p_victim_id: StringName = &"",
	p_forward: CombatSingleAttackExecutionResult = null, p_chain: CombatAttackChainResult = null,
) -> void:
	attacker_id = p_attacker_id
	victim_id = p_victim_id
	forward = p_forward
	chain = p_chain


## The attack and its riposte ran to the end (an aborting fight's chain does not).
func is_complete() -> bool:
	return chain != null and chain.outcome in [
		CombatAttackChainResult.Outcome.FORWARD_COMPLETE_NO_REVERSE,
		CombatAttackChainResult.Outcome.REVERSE_COMPLETE,
	]


## damage.c last_damage_from for `character_id` after this attack: who hit them last
## in it (the riposte comes after the forward blow), or empty.
func last_hitter(character_id: StringName) -> StringName:
	if chain != null and chain.reverse_execution_reached and chain.reverse_victim_id == character_id and _hit(chain.reverse_ordinary_result):
		return chain.reverse_attacker_id
	if forward != null and victim_id == character_id and _hit(forward.ordinary_attack_result):
		return attacker_id
	return &""


static func _hit(ordinary: CombatOrdinaryAttackResult) -> bool:
	return ordinary != null and ordinary.has_base_result and ordinary.base_result.outcome == CombatAttackResult.Outcome.HIT
