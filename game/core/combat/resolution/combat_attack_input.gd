class_name CombatAttackInput
extends RefCounted

var _attacker: CombatAttackerSnapshot
var _defender: CombatDefenderSnapshot
var _selected_action: CombatActionDefinition

var attacker: CombatAttackerSnapshot:
	get:
		return _attacker.duplicate_snapshot() if _attacker != null else null
var defender: CombatDefenderSnapshot:
	get:
		return _defender.duplicate_snapshot() if _defender != null else null
var selected_action: CombatActionDefinition:
	get:
		return _selected_action.duplicate_snapshot() if _selected_action != null else null


func _init(
	p_attacker: CombatAttackerSnapshot = null,
	p_defender: CombatDefenderSnapshot = null,
	p_selected_action: CombatActionDefinition = null,
) -> void:
	_attacker = p_attacker.duplicate_snapshot() if p_attacker != null else null
	_defender = p_defender.duplicate_snapshot() if p_defender != null else null
	_selected_action = (
		p_selected_action.duplicate_snapshot() if p_selected_action != null else null
	)


func is_valid() -> bool:
	return (
		_attacker != null
		and _attacker.is_valid()
		and _defender != null
		and _defender.is_valid()
		and _selected_action != null
		and _selected_action.is_valid()
	)
