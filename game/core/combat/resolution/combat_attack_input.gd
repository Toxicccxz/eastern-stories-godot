class_name CombatAttackInput
extends RefCounted

var _attacker: CombatAttackerSnapshot
var _defender: CombatDefenderSnapshot
var _selected_action: CombatActionDefinition
## Optional composition authority, never a preselected next action. The resolver
## receives a fresh three-argument input containing only the committed selection.
var _approved_actions: CombatActionSet

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
	p_approved_actions: CombatActionSet = null,
) -> void:
	_approved_actions = CombatActionSet.new(p_approved_actions.actions()) if p_approved_actions != null else null
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


func approved_actions() -> CombatActionSet:
	return CombatActionSet.new(_approved_actions.actions()) if _approved_actions != null else null


func accepts_action(selected: CombatActionDefinition) -> bool:
	if _approved_actions != null:
		return _approved_actions.contains_exact(selected)
	return CombatActionSet.same_action(selected, _selected_action)


func matches_action_source(selection: CombatActionSelectionInput) -> bool:
	return _approved_actions == null or (selection != null and _approved_actions.matches_exact(selection.current_action_set()) and _approved_actions.contains_exact(_selected_action))
