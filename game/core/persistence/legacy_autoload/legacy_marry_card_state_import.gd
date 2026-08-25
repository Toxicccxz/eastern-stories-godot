class_name LegacyMarryCardStateImport
extends RefCounted

var _item_instance_id: StringName
var _legacy_partner_parameter: String

var item_instance_id: StringName:
	get: return _item_instance_id
var legacy_partner_parameter: String:
	get: return _legacy_partner_parameter


func _init(
	p_item_instance_id: StringName = &"",
	p_legacy_partner_parameter: String = "",
) -> void:
	_item_instance_id = p_item_instance_id
	_legacy_partner_parameter = p_legacy_partner_parameter


func duplicate_snapshot() -> LegacyMarryCardStateImport:
	return LegacyMarryCardStateImport.new(
		_item_instance_id,
		_legacy_partner_parameter,
	)
