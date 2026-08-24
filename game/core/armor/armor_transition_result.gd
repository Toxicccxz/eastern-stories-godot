class_name ArmorTransitionResult
extends RefCounted

const ArmorNumericModifiersType := preload(
	"res://core/armor/armor_numeric_modifiers.gd"
)

enum Outcome {
	WORN,
	ALREADY_WORN,
	REMOVED,
	INVALID_ARMOR_STATE,
	INVALID_ITEM_INSTANCE,
	INVALID_ARMOR_DEFINITION,
	DEFINITION_MISMATCH,
	ITEM_NOT_DIRECTLY_OWNED,
	INVALID_ARMOR_SLOT,
	SLOT_OCCUPIED,
	NOT_WORN,
}

var _outcome: int
var _succeeded: bool
var _changed: bool
var _item_instance_id: StringName
var _item_definition_id: StringName
var _armor_type: StringName
var _applied_modifiers: ArmorNumericModifiersType

var outcome: int:
	get:
		return _outcome
var succeeded: bool:
	get:
		return _succeeded
var changed: bool:
	get:
		return _changed
var item_instance_id: StringName:
	get:
		return _item_instance_id
var item_definition_id: StringName:
	get:
		return _item_definition_id
var armor_type: StringName:
	get:
		return _armor_type
var applied_modifiers: ArmorNumericModifiersType:
	get:
		return _applied_modifiers.duplicate_snapshot()


func _init(
	p_outcome: int = Outcome.INVALID_ITEM_INSTANCE,
	p_succeeded: bool = false,
	p_changed: bool = false,
	p_item_instance_id: StringName = &"",
	p_item_definition_id: StringName = &"",
	p_armor_type: StringName = &"",
	p_applied_modifiers: ArmorNumericModifiersType = null,
) -> void:
	_outcome = p_outcome
	_succeeded = p_succeeded
	_changed = p_changed
	_item_instance_id = p_item_instance_id
	_item_definition_id = p_item_definition_id
	_armor_type = p_armor_type
	_applied_modifiers = (
		ArmorNumericModifiersType.new()
		if p_applied_modifiers == null
		else p_applied_modifiers.duplicate_snapshot()
	)
