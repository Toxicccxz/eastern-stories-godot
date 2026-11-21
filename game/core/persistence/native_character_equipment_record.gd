class_name NativeCharacterEquipmentRecord
extends RefCounted

var _character_id: StringName
var _primary_item_instance_id: StringName
var _secondary_item_instance_id: StringName

var character_id: StringName:
	get:
		return _character_id
var primary_item_instance_id: StringName:
	get:
		return _primary_item_instance_id
var secondary_item_instance_id: StringName:
	get:
		return _secondary_item_instance_id


func _init(
	p_character_id: StringName = &"",
	p_primary_item_instance_id: StringName = &"",
	p_secondary_item_instance_id: StringName = &"",
) -> void:
	_character_id = p_character_id
	_primary_item_instance_id = p_primary_item_instance_id
	_secondary_item_instance_id = p_secondary_item_instance_id


func duplicate_snapshot() -> NativeCharacterEquipmentRecord:
	return NativeCharacterEquipmentRecord.new(
		_character_id,
		_primary_item_instance_id,
		_secondary_item_instance_id,
	)


## The order NativeItemStateSnapshot keeps these records in: by character ID, a missing record first.
## Reads the fields themselves, not their getters: a save sorts thousands of records.
static func before(left: NativeCharacterEquipmentRecord, right: NativeCharacterEquipmentRecord) -> bool:
	if left == null:
		return right != null
	return right != null and String(left._character_id) < String(right._character_id)
