class_name LegacyMarryCardRuntimeIntent
extends RefCounted

enum Effect {
	NOTIFY_ONLINE_PARTNER_IF_PRESENT,
}

var _item_instance_id: StringName
var _legacy_partner_parameter: String
var _effect: int

var item_instance_id: StringName:
	get: return _item_instance_id
var legacy_partner_parameter: String:
	get: return _legacy_partner_parameter
var effect: int:
	get: return _effect


func _init(
	p_item_instance_id: StringName = &"",
	p_legacy_partner_parameter: String = "",
	p_effect: int = Effect.NOTIFY_ONLINE_PARTNER_IF_PRESENT,
) -> void:
	_item_instance_id = p_item_instance_id
	_legacy_partner_parameter = p_legacy_partner_parameter
	_effect = p_effect


func duplicate_snapshot() -> LegacyMarryCardRuntimeIntent:
	return LegacyMarryCardRuntimeIntent.new(
		_item_instance_id,
		_legacy_partner_parameter,
		_effect,
	)
