class_name LegacyBandageStateImport
extends RefCounted

const LEGACY_RESTORED_BLOOD_SOAKED: int = 3

var _item_instance_id: StringName
var _legacy_name: String
var _blood_soaked: int
var _native_wear_established: bool

var item_instance_id: StringName:
	get: return _item_instance_id
var legacy_name: String:
	get: return _legacy_name
var blood_soaked: int:
	get: return _blood_soaked
var native_wear_established: bool:
	get: return _native_wear_established


func _init(
	p_item_instance_id: StringName = &"",
	p_legacy_name: String = "",
	p_native_wear_established: bool = false,
) -> void:
	_item_instance_id = p_item_instance_id
	_legacy_name = p_legacy_name
	_blood_soaked = LEGACY_RESTORED_BLOOD_SOAKED
	_native_wear_established = p_native_wear_established


func duplicate_snapshot() -> LegacyBandageStateImport:
	return LegacyBandageStateImport.new(
		_item_instance_id,
		_legacy_name,
		_native_wear_established,
	)
