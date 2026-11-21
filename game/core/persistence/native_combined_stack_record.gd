class_name NativeCombinedStackRecord
extends RefCounted

var _item_instance_id: StringName
var _amount: int

var item_instance_id: StringName:
	get:
		return _item_instance_id
var amount: int:
	get:
		return _amount


func _init(
	p_item_instance_id: StringName = &"",
	p_amount: int = 0,
) -> void:
	_item_instance_id = p_item_instance_id
	_amount = p_amount


func duplicate_snapshot() -> NativeCombinedStackRecord:
	return NativeCombinedStackRecord.new(_item_instance_id, _amount)


## The order NativeItemStateSnapshot keeps these records in: by item instance ID, a missing record first.
## Reads the fields themselves, not their getters: a save sorts thousands of records.
static func before(left: NativeCombinedStackRecord, right: NativeCombinedStackRecord) -> bool:
	if left == null:
		return right != null
	return right != null and String(left._item_instance_id) < String(right._item_instance_id)
