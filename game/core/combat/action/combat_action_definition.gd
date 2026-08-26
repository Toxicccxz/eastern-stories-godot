class_name CombatActionDefinition
extends RefCounted

## Immutable typed projection of combatd.c action fields that are active or
## needed for future presentation/policy routing. Legacy dodge/parry fields are
## intentionally absent because combatd.c does not consume them.
var _action_id: StringName
var _damage_percent: int
var _force_percent: int
var _damage_type: StringName
var _presentation_key: StringName
var _legacy_action_text: String
var _displayed_weapon_or_body_token: String
var _post_action_policy_id: StringName

var action_id: StringName:
	get:
		return _action_id
var damage_percent: int:
	get:
		return _damage_percent
var force_percent: int:
	get:
		return _force_percent
var damage_type: StringName:
	get:
		return _damage_type
var presentation_key: StringName:
	get:
		return _presentation_key
var legacy_action_text: String:
	get:
		return _legacy_action_text
var displayed_weapon_or_body_token: String:
	get:
		return _displayed_weapon_or_body_token
var post_action_policy_id: StringName:
	get:
		return _post_action_policy_id


func _init(
	p_action_id: StringName = &"",
	p_damage_percent: int = 0,
	p_force_percent: int = 0,
	p_damage_type: StringName = &"",
	p_presentation_key: StringName = &"",
	p_legacy_action_text: String = "",
	p_displayed_weapon_or_body_token: String = "",
	p_post_action_policy_id: StringName = &"",
) -> void:
	_action_id = p_action_id
	_damage_percent = p_damage_percent
	_force_percent = p_force_percent
	_damage_type = p_damage_type
	_presentation_key = p_presentation_key
	_legacy_action_text = p_legacy_action_text
	_displayed_weapon_or_body_token = p_displayed_weapon_or_body_token
	_post_action_policy_id = p_post_action_policy_id


func is_valid() -> bool:
	return not _action_id.is_empty()


func duplicate_snapshot() -> CombatActionDefinition:
	return CombatActionDefinition.new(
		_action_id,
		_damage_percent,
		_force_percent,
		_damage_type,
		_presentation_key,
		_legacy_action_text,
		_displayed_weapon_or_body_token,
		_post_action_policy_id,
	)
