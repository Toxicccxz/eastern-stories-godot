class_name LegacyStackDestructionIntent
extends RefCounted

const LEGACY_DELAY_SECONDS: int = 1

var _item_instance_id: StringName
var _requested_amount: int
var _delay_seconds: int

var item_instance_id: StringName:
	get: return _item_instance_id
var requested_amount: int:
	get: return _requested_amount
var delay_seconds: int:
	get: return _delay_seconds


func _init(
	p_item_instance_id: StringName = &"",
	p_requested_amount: int = 0,
) -> void:
	_item_instance_id = p_item_instance_id
	_requested_amount = p_requested_amount
	_delay_seconds = LEGACY_DELAY_SECONDS


func duplicate_snapshot() -> LegacyStackDestructionIntent:
	return LegacyStackDestructionIntent.new(
		_item_instance_id,
		_requested_amount,
	)
