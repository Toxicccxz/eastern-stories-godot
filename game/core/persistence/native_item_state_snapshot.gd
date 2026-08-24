class_name NativeItemStateSnapshot
extends RefCounted

const CURRENT_SCHEMA_VERSION: int = 1

var _schema_version: int
var _item_records: Array[NativeItemRecord] = []
var _combined_stack_records: Array[NativeCombinedStackRecord] = []
var _character_equipment_records: Array[NativeCharacterEquipmentRecord] = []
var _character_armor_records: Array[NativeCharacterArmorRecord] = []

var schema_version: int:
	get:
		return _schema_version
var item_records: Array[NativeItemRecord]:
	get:
		return _duplicate_item_records()
var combined_stack_records: Array[NativeCombinedStackRecord]:
	get:
		return _duplicate_stack_records()
var character_equipment_records: Array[NativeCharacterEquipmentRecord]:
	get:
		return _duplicate_equipment_records()
var character_armor_records: Array[NativeCharacterArmorRecord]:
	get:
		return _duplicate_armor_records()


func _init(
	p_schema_version: int = CURRENT_SCHEMA_VERSION,
	p_item_records: Array[NativeItemRecord] = [],
	p_combined_stack_records: Array[NativeCombinedStackRecord] = [],
	p_character_equipment_records: Array[NativeCharacterEquipmentRecord] = [],
	p_character_armor_records: Array[NativeCharacterArmorRecord] = [],
) -> void:
	_schema_version = p_schema_version
	for record: NativeItemRecord in p_item_records:
		_item_records.append(null if record == null else record.duplicate_snapshot())
	for record: NativeCombinedStackRecord in p_combined_stack_records:
		_combined_stack_records.append(
			null if record == null else record.duplicate_snapshot()
		)
	for record: NativeCharacterEquipmentRecord in p_character_equipment_records:
		_character_equipment_records.append(
			null if record == null else record.duplicate_snapshot()
		)
	for record: NativeCharacterArmorRecord in p_character_armor_records:
		_character_armor_records.append(
			null if record == null else record.duplicate_snapshot()
		)
	_item_records.sort_custom(_item_record_less_than)
	_combined_stack_records.sort_custom(_stack_record_less_than)
	_character_equipment_records.sort_custom(_equipment_record_less_than)
	_character_armor_records.sort_custom(_armor_record_less_than)


func duplicate_snapshot() -> NativeItemStateSnapshot:
	return NativeItemStateSnapshot.new(
		_schema_version,
		_item_records,
		_combined_stack_records,
		_character_equipment_records,
		_character_armor_records,
	)


func _duplicate_item_records() -> Array[NativeItemRecord]:
	var result: Array[NativeItemRecord] = []
	for record: NativeItemRecord in _item_records:
		result.append(null if record == null else record.duplicate_snapshot())
	return result


func _duplicate_stack_records() -> Array[NativeCombinedStackRecord]:
	var result: Array[NativeCombinedStackRecord] = []
	for record: NativeCombinedStackRecord in _combined_stack_records:
		result.append(null if record == null else record.duplicate_snapshot())
	return result


func _duplicate_equipment_records() -> Array[NativeCharacterEquipmentRecord]:
	var result: Array[NativeCharacterEquipmentRecord] = []
	for record: NativeCharacterEquipmentRecord in _character_equipment_records:
		result.append(null if record == null else record.duplicate_snapshot())
	return result


func _duplicate_armor_records() -> Array[NativeCharacterArmorRecord]:
	var result: Array[NativeCharacterArmorRecord] = []
	for record: NativeCharacterArmorRecord in _character_armor_records:
		result.append(null if record == null else record.duplicate_snapshot())
	return result


func _item_record_less_than(left: NativeItemRecord, right: NativeItemRecord) -> bool:
	if left == null:
		return right != null
	if right == null:
		return false
	return String(left.item_instance_id) < String(right.item_instance_id)


func _stack_record_less_than(
	left: NativeCombinedStackRecord,
	right: NativeCombinedStackRecord,
) -> bool:
	if left == null:
		return right != null
	if right == null:
		return false
	return String(left.item_instance_id) < String(right.item_instance_id)


func _equipment_record_less_than(
	left: NativeCharacterEquipmentRecord,
	right: NativeCharacterEquipmentRecord,
) -> bool:
	if left == null:
		return right != null
	if right == null:
		return false
	return String(left.character_id) < String(right.character_id)


func _armor_record_less_than(
	left: NativeCharacterArmorRecord,
	right: NativeCharacterArmorRecord,
) -> bool:
	if left == null:
		return right != null
	if right == null:
		return false
	return String(left.character_id) < String(right.character_id)
