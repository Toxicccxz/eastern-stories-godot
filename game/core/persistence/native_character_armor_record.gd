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
