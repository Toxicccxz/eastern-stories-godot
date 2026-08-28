class_name OldPineWeaponContentResolution
extends RefCounted

enum Outcome {
	INVALID_REQUEST,
	LONG_SWORD,
	SHORT_SWORD,
	UNARMED,
	PRIMARY_ITEM_NOT_AVAILABLE,
	PRIMARY_DEFINITION_MISMATCH,
	PRIMARY_CONTENT_UNAVAILABLE,
	UNSUPPORTED_PRIMARY,
}

var _outcome: int
var _primary_item_instance_id: StringName
var _primary_item_definition_id: StringName
var _content_profile: CombatSliceContentProfile

var outcome: int:
	get: return _outcome
var primary_item_instance_id: StringName:
	get: return _primary_item_instance_id
var primary_item_definition_id: StringName:
	get: return _primary_item_definition_id
var content_profile: CombatSliceContentProfile:
	get: return _content_profile
var succeeded: bool:
	get:
		return _outcome in [Outcome.LONG_SWORD, Outcome.SHORT_SWORD, Outcome.UNARMED]


func _init(
	p_outcome: int = Outcome.INVALID_REQUEST,
	p_primary_item_instance_id: StringName = &"",
	p_primary_item_definition_id: StringName = &"",
	p_content_profile: CombatSliceContentProfile = null,
) -> void:
	_outcome = p_outcome
	_primary_item_instance_id = p_primary_item_instance_id
	_primary_item_definition_id = p_primary_item_definition_id
	_content_profile = p_content_profile
