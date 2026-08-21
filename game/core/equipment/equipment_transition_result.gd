class_name EquipmentTransitionResult
extends RefCounted

enum Outcome {
	WIELDED_PRIMARY,
	WIELDED_SECONDARY,
	SWAPPED_PRIMARY_TO_SECONDARY,
	REPLACED_TWO_HANDED_PRIMARY,
	ALREADY_WIELDED,
	UNWIELDED_PRIMARY,
	UNWIELDED_SECONDARY,
	TWO_HANDED_REQUIRES_EMPTY_HANDS,
	PRIMARY_MUST_BE_UNWIELDED,
	NO_FREE_HAND,
	NOT_WIELDED,
	INVALID_WEAPON_REFERENCE,
}

enum Slot {
	NONE,
	PRIMARY,
	SECONDARY,
	PRIMARY_AND_SECONDARY,
}

var _outcome: int
var _succeeded: bool
var _changed: bool
var _weapon_instance_id: StringName
var _affected_slot: int
var _previous_primary_instance_id: StringName

var outcome: int:
	get:
		return _outcome

var succeeded: bool:
	get:
		return _succeeded

var changed: bool:
	get:
		return _changed

var weapon_instance_id: StringName:
	get:
		return _weapon_instance_id

var affected_slot: int:
	get:
		return _affected_slot

var previous_primary_instance_id: StringName:
	get:
		return _previous_primary_instance_id


func _init(
	p_outcome: int = Outcome.INVALID_WEAPON_REFERENCE,
	p_succeeded: bool = false,
	p_changed: bool = false,
	p_weapon_instance_id: StringName = &"",
	p_affected_slot: int = Slot.NONE,
	p_previous_primary_instance_id: StringName = &"",
) -> void:
	_outcome = p_outcome
	_succeeded = p_succeeded
	_changed = p_changed
	_weapon_instance_id = p_weapon_instance_id
	_affected_slot = p_affected_slot
	_previous_primary_instance_id = p_previous_primary_instance_id
