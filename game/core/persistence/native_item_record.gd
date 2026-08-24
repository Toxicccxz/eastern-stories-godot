class_name NativeItemRecord
extends RefCounted

const ContainmentEndpointType := preload(
	"res://core/inventory/containment_endpoint.gd"
)

var _item_instance_id: StringName
var _item_definition_id: StringName
var _own_weight: int
var _direct_parent: ContainmentEndpointType

var item_instance_id: StringName:
	get:
		return _item_instance_id
var item_definition_id: StringName:
	get:
		return _item_definition_id
var own_weight: int:
	get:
		return _own_weight
var direct_parent: ContainmentEndpointType:
	get:
		return (
			null
			if _direct_parent == null
			else _direct_parent.duplicate_snapshot()
		)


func _init(
	p_item_instance_id: StringName = &"",
	p_item_definition_id: StringName = &"",
	p_own_weight: int = 0,
	p_direct_parent: ContainmentEndpointType = null,
) -> void:
	_item_instance_id = p_item_instance_id
	_item_definition_id = p_item_definition_id
	_own_weight = p_own_weight
	_direct_parent = (
		null
		if p_direct_parent == null
		else p_direct_parent.duplicate_snapshot()
	)


func duplicate_snapshot() -> NativeItemRecord:
	return NativeItemRecord.new(
		_item_instance_id,
		_item_definition_id,
		_own_weight,
		_direct_parent,
	)
