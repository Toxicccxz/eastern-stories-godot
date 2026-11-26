class_name NativeCharacterArmorRecord
extends RefCounted

var _character_id: StringName
var _slots: Array[NativeArmorSlotRecord] = []

var character_id: StringName:
	get:
		return _character_id
var slots: Array[NativeArmorSlotRecord]:
	get:
		return _duplicate_slots()


func _init(
	p_character_id: StringName = &"",
	p_slots: Array[NativeArmorSlotRecord] = [],
) -> void:
	_character_id = p_character_id
	for slot: NativeArmorSlotRecord in p_slots:
		_slots.append(null if slot == null else slot.duplicate_snapshot())
	_slots.sort_custom(_slot_less_than)


func duplicate_snapshot() -> NativeCharacterArmorRecord:
	return NativeCharacterArmorRecord.new(_character_id, _slots)


func _duplicate_slots() -> Array[NativeArmorSlotRecord]:
	var result: Array[NativeArmorSlotRecord] = []
	for slot: NativeArmorSlotRecord in _slots:
		result.append(null if slot == null else slot.duplicate_snapshot())
	return result


func _slot_less_than(
	left: NativeArmorSlotRecord,
	right: NativeArmorSlotRecord,
) -> bool:
	if left == null:
		return right != null
	if right == null:
		return false
	return String(left.armor_type) < String(right.armor_type)


## The order NativeItemStateSnapshot keeps these records in: by character ID, a missing record first.
## Reads the fields themselves, not their getters: a save sorts thousands of records.
static func before(left: NativeCharacterArmorRecord, right: NativeCharacterArmorRecord) -> bool:
	if left == null:
		return right != null
	return right != null and String(left._character_id) < String(right._character_id)
