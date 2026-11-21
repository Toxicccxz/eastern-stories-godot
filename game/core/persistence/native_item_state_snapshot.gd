class_name NativeItemStateSnapshot
extends RefCounted

const CURRENT_SCHEMA_VERSION: int = 3

var _schema_version: int
var _item_records: Array[NativeItemRecord] = []
var _combined_stack_records: Array[NativeCombinedStackRecord] = []
var _character_equipment_records: Array[NativeCharacterEquipmentRecord] = []
var _character_armor_records: Array[NativeCharacterArmorRecord] = []
var _food_consumable_records: Array[NativeFoodConsumableRecord] = []
var _liquid_consumable_records: Array[NativeLiquidConsumableRecord] = []

var liquid_consumable_records: Array[NativeLiquidConsumableRecord]:
	get:
		var copies: Array[NativeLiquidConsumableRecord] = []
		for record: NativeLiquidConsumableRecord in _liquid_consumable_records:
			copies.append(null if record == null else record.duplicate_snapshot())
		return copies

var food_consumable_records: Array[NativeFoodConsumableRecord]:
	get:
		var copies: Array[NativeFoodConsumableRecord] = []
		for record: NativeFoodConsumableRecord in _food_consumable_records:
			copies.append(null if record == null else record.duplicate_snapshot())
		return copies

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
	p_food_consumable_records: Array[NativeFoodConsumableRecord] = [],
	p_liquid_consumable_records: Array[NativeLiquidConsumableRecord] = [],
	p_adopt: bool = false,
) -> void:
	_schema_version = p_schema_version
	if p_adopt:
		# The records are new and nothing else holds them (a capture's, a decoder's): this
		# snapshot's own as they are (GameSaveValueTypes.CharacterStateSnapshot).
		_item_records = p_item_records
		_combined_stack_records = p_combined_stack_records
		_character_equipment_records = p_character_equipment_records
		_character_armor_records = p_character_armor_records
		_food_consumable_records = p_food_consumable_records
		_liquid_consumable_records = p_liquid_consumable_records
	else:
		for record: NativeItemRecord in p_item_records:
			_item_records.append(null if record == null else record.duplicate_snapshot())
		for record: NativeCombinedStackRecord in p_combined_stack_records:
			_combined_stack_records.append(null if record == null else record.duplicate_snapshot())
		for record: NativeCharacterEquipmentRecord in p_character_equipment_records:
			_character_equipment_records.append(null if record == null else record.duplicate_snapshot())
		for record: NativeCharacterArmorRecord in p_character_armor_records:
			_character_armor_records.append(null if record == null else record.duplicate_snapshot())
		for record: NativeFoodConsumableRecord in p_food_consumable_records:
			_food_consumable_records.append(null if record == null else record.duplicate_snapshot())
		for record: NativeLiquidConsumableRecord in p_liquid_consumable_records:
			_liquid_consumable_records.append(null if record == null else record.duplicate_snapshot())
	_liquid_consumable_records.sort_custom(func(a: NativeLiquidConsumableRecord, b: NativeLiquidConsumableRecord) -> bool:
		if a == null:
			return b != null
		return b != null and String(a.item_instance_id) < String(b.item_instance_id))
	_food_consumable_records.sort_custom(func(a: NativeFoodConsumableRecord, b: NativeFoodConsumableRecord) -> bool:
		if a == null:
			return b != null
		return b != null and String(a.item_instance_id) < String(b.item_instance_id))
	_item_records.sort_custom(NativeItemRecord.before)
	_combined_stack_records.sort_custom(NativeCombinedStackRecord.before)
	_character_equipment_records.sort_custom(NativeCharacterEquipmentRecord.before)
	_character_armor_records.sort_custom(NativeCharacterArmorRecord.before)


func duplicate_snapshot() -> NativeItemStateSnapshot:
	return NativeItemStateSnapshot.new(
		_schema_version,
		_item_records,
		_combined_stack_records,
		_character_equipment_records,
		_character_armor_records,
		_food_consumable_records,
		_liquid_consumable_records,
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
