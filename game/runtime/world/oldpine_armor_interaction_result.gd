class_name OldPineArmorInteractionResult
extends RefCounted

enum Action {
	INVALID,
	WEAR,
	REMOVE,
}

enum Outcome {
	INVALID_REQUEST,
	PLAYER_NOT_AVAILABLE,
	PLAYER_NOT_ACTIVE,
	ITEM_NOT_REGISTERED,
	ITEM_NOT_DIRECTLY_OWNED,
	ITEM_CONTENT_UNAVAILABLE,
	ITEM_NOT_ARMOR,
	ARMOR_DEFINITION_MISMATCH,
	ITEM_NOT_WORN,
	ARMOR_TRANSITION,
}

var _action: int
var _outcome: int
var _item_instance_id: StringName
var _armor_transition: ArmorTransitionResult

var action: int:
	get: return _action
var outcome: int:
	get: return _outcome
var item_instance_id: StringName:
	get: return _item_instance_id
var armor_transition: ArmorTransitionResult:
	get: return _duplicate_transition(_armor_transition)
var succeeded: bool:
	get:
		return (
			_outcome == Outcome.ARMOR_TRANSITION
			and _armor_transition != null
			and _armor_transition.succeeded
		)
var changed: bool:
	get:
		return (
			_outcome == Outcome.ARMOR_TRANSITION
			and _armor_transition != null
			and _armor_transition.changed
		)


func _init(
	p_action: int = Action.INVALID,
	p_outcome: int = Outcome.INVALID_REQUEST,
	p_item_instance_id: StringName = &"",
	p_armor_transition: ArmorTransitionResult = null,
) -> void:
	_action = p_action
	_outcome = p_outcome
	_item_instance_id = p_item_instance_id
	_armor_transition = _duplicate_transition(p_armor_transition)


static func _duplicate_transition(
	value: ArmorTransitionResult,
) -> ArmorTransitionResult:
	if value == null:
		return null
	return ArmorTransitionResult.new(
		value.outcome,
		value.succeeded,
		value.changed,
		value.item_instance_id,
		value.item_definition_id,
		value.armor_type,
		value.applied_modifiers,
	)
