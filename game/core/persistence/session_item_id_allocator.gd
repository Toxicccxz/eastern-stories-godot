class_name SessionItemIdAllocator
extends RefCounted

const MAX_SEQUENCE: int = 9223372036854775807
const DYNAMIC_SEPARATOR: String = ".dynamic."

var _scope: StringName = &""
var _next_dynamic_sequence: int = 0

var scope: StringName:
	get:
		return _scope
var next_dynamic_sequence: int:
	get:
		return _next_dynamic_sequence


func _init(
	p_scope: StringName = &"",
	p_next_dynamic_sequence: int = 0,
) -> void:
	_scope = p_scope
	_next_dynamic_sequence = p_next_dynamic_sequence


func is_valid() -> bool:
	return not _scope.is_empty() and _next_dynamic_sequence >= 0


func snapshot() -> GameSaveValueTypes.ItemIdAllocatorSnapshot:
	if not is_valid():
		return null
	return GameSaveValueTypes.ItemIdAllocatorSnapshot.new(
		_scope,
		_next_dynamic_sequence,
	)


func allocate(inventory: InventoryState) -> SessionItemIdAllocationResult:
	if not is_valid() or inventory == null:
		return SessionItemIdAllocationResult.new()
	if _next_dynamic_sequence == MAX_SEQUENCE:
		return SessionItemIdAllocationResult.new(
			SessionItemIdAllocationResult.Outcome.SEQUENCE_OVERFLOW
		)
	var candidate: StringName = StringName(
		"%s%s%d" % [String(_scope), DYNAMIC_SEPARATOR, _next_dynamic_sequence]
	)
	if inventory.is_registered(candidate):
		return SessionItemIdAllocationResult.new(
			SessionItemIdAllocationResult.Outcome.COLLISION,
			candidate,
		)
	_next_dynamic_sequence += 1
	return SessionItemIdAllocationResult.new(
		SessionItemIdAllocationResult.Outcome.ALLOCATED,
		candidate,
	)


static func restore(
	saved: GameSaveValueTypes.ItemIdAllocatorSnapshot,
	represented_item_ids: Array[StringName],
) -> SessionItemIdAllocatorRestoreResult:
	if saved == null or saved.scope.is_empty() or saved.next_dynamic_sequence < 0:
		return SessionItemIdAllocatorRestoreResult.new()
	var next_sequence: int = saved.next_dynamic_sequence
	var seen: Dictionary[StringName, bool] = {}
	var dynamic_namespace: String = String(saved.scope) + ".dynamic"
	var dynamic_prefix: String = String(saved.scope) + DYNAMIC_SEPARATOR
	for item_instance_id: StringName in represented_item_ids:
		if item_instance_id.is_empty():
			return SessionItemIdAllocatorRestoreResult.new(
				SessionItemIdAllocatorRestoreResult.Outcome.MALFORMED_SAME_SCOPE_ID,
				null,
				item_instance_id,
			)
		if seen.has(item_instance_id):
			return SessionItemIdAllocatorRestoreResult.new(
				SessionItemIdAllocatorRestoreResult.Outcome.DUPLICATE_REPRESENTED_ID,
				null,
				item_instance_id,
			)
		seen[item_instance_id] = true
		var text_id: String = String(item_instance_id)
		if text_id.begins_with(dynamic_namespace) and not text_id.begins_with(
			dynamic_prefix
		):
			return SessionItemIdAllocatorRestoreResult.new(
				SessionItemIdAllocatorRestoreResult.Outcome.MALFORMED_SAME_SCOPE_ID,
				null,
				item_instance_id,
			)
		if not text_id.begins_with(dynamic_prefix):
			continue
		var suffix: String = text_id.substr(dynamic_prefix.length())
		var decoded: GameSaveResult = DecimalInt64Codec.decode(
			suffix,
			"item_instance_id.dynamic_sequence",
		)
		if not decoded.succeeded():
			return SessionItemIdAllocatorRestoreResult.new(
				SessionItemIdAllocatorRestoreResult.Outcome.MALFORMED_SAME_SCOPE_ID,
				null,
				item_instance_id,
			)
		var represented_sequence: int = DecimalInt64Codec.integer_value(decoded)
		if represented_sequence < 0:
			return SessionItemIdAllocatorRestoreResult.new(
				SessionItemIdAllocatorRestoreResult.Outcome.MALFORMED_SAME_SCOPE_ID,
				null,
				item_instance_id,
			)
		if represented_sequence == MAX_SEQUENCE:
			return SessionItemIdAllocatorRestoreResult.new(
				SessionItemIdAllocatorRestoreResult.Outcome.SEQUENCE_OVERFLOW,
				null,
				item_instance_id,
			)
		next_sequence = maxi(next_sequence, represented_sequence + 1)
	return SessionItemIdAllocatorRestoreResult.new(
		SessionItemIdAllocatorRestoreResult.Outcome.RESTORED,
		SessionItemIdAllocator.new(saved.scope, next_sequence),
	)
