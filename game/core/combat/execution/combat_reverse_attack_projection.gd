class_name CombatReverseAttackProjection
extends RefCounted

## Caller-built only after the forward attack returned its terminal request.
## Mutable authorities are input-only and are not copied into chain results.
var _attacker_authority: CombatCharacterAuthority
var _defender_authority: CombatCharacterAuthority
var _action_selection_input: CombatActionSelectionInput
var _attack_input_template: CombatAttackInput
var _attacker_facts: CombatProgressionFacts
var _defender_facts: CombatProgressionFacts
var _defender_busy_projection: CombatBusyInterruptProjection
var _defender_busy_state: ActionBusyState
var _attacker_relationship: CombatRelationshipState
var _defender_relationship: CombatRelationshipState
var _modifier_projection: CombatReverseModifierProjection


func _init(
	p_attacker_authority: CombatCharacterAuthority = null,
	p_defender_authority: CombatCharacterAuthority = null,
	p_action_selection_input: CombatActionSelectionInput = null,
	p_attack_input_template: CombatAttackInput = null,
	p_attacker_facts: CombatProgressionFacts = null,
	p_defender_facts: CombatProgressionFacts = null,
	p_defender_busy_projection: CombatBusyInterruptProjection = null,
	p_defender_busy_state: ActionBusyState = null,
	p_attacker_relationship: CombatRelationshipState = null,
	p_defender_relationship: CombatRelationshipState = null,
	p_modifier_projection: CombatReverseModifierProjection = null,
) -> void:
	_attacker_authority = p_attacker_authority
	_defender_authority = p_defender_authority
	_action_selection_input = _copy_selection_input(p_action_selection_input)
	_attack_input_template = _copy_attack_input(p_attack_input_template)
	_attacker_facts = (
		p_attacker_facts.duplicate_snapshot()
		if p_attacker_facts != null
		else null
	)
	_defender_facts = (
		p_defender_facts.duplicate_snapshot()
		if p_defender_facts != null
		else null
	)
	_defender_busy_projection = (
		p_defender_busy_projection.duplicate_snapshot()
		if p_defender_busy_projection != null
		else null
	)
	_defender_busy_state = p_defender_busy_state
	_attacker_relationship = p_attacker_relationship
	_defender_relationship = p_defender_relationship
	_modifier_projection = (
		p_modifier_projection.duplicate_snapshot()
		if p_modifier_projection != null
		else null
	)


func attacker_authority() -> CombatCharacterAuthority:
	return _attacker_authority


func defender_authority() -> CombatCharacterAuthority:
	return _defender_authority


func action_selection_input() -> CombatActionSelectionInput:
	return _copy_selection_input(_action_selection_input)


func attack_input_template() -> CombatAttackInput:
	return _copy_attack_input(_attack_input_template)


func attacker_facts() -> CombatProgressionFacts:
	return _attacker_facts.duplicate_snapshot() if _attacker_facts != null else null


func defender_facts() -> CombatProgressionFacts:
	return _defender_facts.duplicate_snapshot() if _defender_facts != null else null


func defender_busy_projection() -> CombatBusyInterruptProjection:
	return (
		_defender_busy_projection.duplicate_snapshot()
		if _defender_busy_projection != null
		else null
	)


func defender_busy_state() -> ActionBusyState:
	return _defender_busy_state


func attacker_relationship() -> CombatRelationshipState:
	return _attacker_relationship


func defender_relationship() -> CombatRelationshipState:
	return _defender_relationship


func modifier_projection() -> CombatReverseModifierProjection:
	return (
		_modifier_projection.duplicate_snapshot()
		if _modifier_projection != null
		else null
	)


static func _copy_selection_input(
	value: CombatActionSelectionInput,
) -> CombatActionSelectionInput:
	if value == null:
		return null
	return CombatActionSelectionInput.new(
		value.mapped_skill_present,
		value.mapped_action_set(),
		value.primary_weapon_present,
		value.primary_weapon_action_set(),
		value.default_action_set(),
	)


static func _copy_attack_input(value: CombatAttackInput) -> CombatAttackInput:
	if value == null:
		return null
	return CombatAttackInput.new(
		value.attacker,
		value.defender,
		value.selected_action,
	)
