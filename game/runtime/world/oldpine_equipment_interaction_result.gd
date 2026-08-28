class_name OldPineEquipmentInteractionResult
extends RefCounted

enum Action {
	INVALID,
	WIELD,
	UNWIELD,
}

enum Outcome {
	INVALID_REQUEST,
	PLAYER_NOT_AVAILABLE,
	PLAYER_NOT_ACTIVE,
	ITEM_NOT_REGISTERED,
	ITEM_NOT_DIRECTLY_OWNED,
	ITEM_CONTENT_UNAVAILABLE,
	ITEM_NOT_A_WEAPON,
	WEAPON_DEFINITION_MISMATCH,
	ITEM_NOT_WIELDED,
	EQUIPMENT_TRANSITION,
}

var _action: int
var _outcome: int
var _item_instance_id: StringName
var _equipment_transition: EquipmentTransitionResult

var action: int:
	get: return _action
var outcome: int:
	get: return _outcome
var item_instance_id: StringName:
	get: return _item_instance_id
var equipment_transition: EquipmentTransitionResult:
	get: return _duplicate_transition(_equipment_transition)
var succeeded: bool:
	get:
		return (
			_outcome == Outcome.EQUIPMENT_TRANSITION
			and _equipment_transition != null
			and _equipment_transition.succeeded
		)
var changed: bool:
	get:
		return (
			_outcome == Outcome.EQUIPMENT_TRANSITION
			and _equipment_transition != null
			and _equipment_transition.changed
		)


func _init(
	p_action: int = Action.INVALID,
	p_outcome: int = Outcome.INVALID_REQUEST,
	p_item_instance_id: StringName = &"",
	p_equipment_transition: EquipmentTransitionResult = null,
) -> void:
	_action = p_action
	_outcome = p_outcome
	_item_instance_id = p_item_instance_id
	_equipment_transition = _duplicate_transition(p_equipment_transition)


func _duplicate_transition(
	value: EquipmentTransitionResult,
) -> EquipmentTransitionResult:
	if value == null:
		return null
	return EquipmentTransitionResult.new(
		value.outcome,
		value.succeeded,
		value.changed,
		value.weapon_instance_id,
		value.affected_slot,
		value.previous_primary_instance_id,
	)
