class_name NativeItemStateValidator
extends RefCounted

const EndpointType := preload("res://core/inventory/containment_endpoint.gd")
const ResultType := preload(
	"res://core/persistence/native_item_state_validation_result.gd"
)
const SnapshotType := preload(
	"res://core/persistence/native_item_state_snapshot.gd"
)


static func validate(
	snapshot: NativeItemStateSnapshot,
	definitions: NativeItemDefinitionProjections,
) -> NativeItemStateValidationResult:
	if snapshot == null:
		return _failure(ResultType.Outcome.INVALID_SNAPSHOT)
	if snapshot.schema_version != SnapshotType.CURRENT_SCHEMA_VERSION:
		return _failure(ResultType.Outcome.INVALID_SCHEMA_VERSION)
	if definitions == null or not definitions.is_valid:
		return _failure(ResultType.Outcome.INVALID_DEFINITION_PROJECTIONS)

	var item_records: Array[NativeItemRecord] = snapshot.item_records
	var items: Dictionary[StringName, NativeItemRecord] = {}
	var parents: Dictionary[StringName, ContainmentEndpoint] = {}
	for record: NativeItemRecord in item_records:
		if (
			record == null
			or record.item_instance_id == &""
			or record.item_definition_id == &""
		):
			return _failure(ResultType.Outcome.MALFORMED_ITEM_RECORD)
		if items.has(record.item_instance_id):
			return _failure(
				ResultType.Outcome.DUPLICATE_ITEM_INSTANCE_ID,
				record.item_instance_id,
			)
		if not definitions.has_item_definition(record.item_definition_id):
			return _failure(
				ResultType.Outcome.UNKNOWN_ITEM_DEFINITION,
				record.item_instance_id,
				record.item_definition_id,
			)
		items[record.item_instance_id] = record
		var parent: ContainmentEndpoint = record.direct_parent
		if parent != null:
			if not parent.is_valid():
				return _failure(
					ResultType.Outcome.INVALID_PARENT_ENDPOINT,
					record.item_instance_id,
				)
			parents[record.item_instance_id] = parent

	for item_instance_id: StringName in parents:
		var parent: ContainmentEndpoint = parents[item_instance_id]
		if parent.kind != EndpointType.Kind.ITEM:
			continue
		if not items.has(parent.endpoint_id):
			return _failure(
				ResultType.Outcome.MISSING_PARENT_ITEM,
				item_instance_id,
				parent.endpoint_id,
			)
		if parent.endpoint_id == item_instance_id:
			return _failure(
				ResultType.Outcome.CONTAINMENT_CYCLE,
				item_instance_id,
				parent.endpoint_id,
			)
	var cycle_result: NativeItemStateValidationResult = _validate_parent_cycles(parents)
	if not cycle_result.succeeded:
		return cycle_result

	var stack_ids: Dictionary[StringName, bool] = {}
	for record: NativeCombinedStackRecord in snapshot.combined_stack_records:
		if record == null or record.item_instance_id == &"":
			return _failure(ResultType.Outcome.MALFORMED_STACK_RECORD)
		if stack_ids.has(record.item_instance_id):
			return _failure(
				ResultType.Outcome.DUPLICATE_STACK_RECORD,
				record.item_instance_id,
			)
		if not items.has(record.item_instance_id):
			return _failure(
				ResultType.Outcome.MISSING_STACK_ITEM,
				record.item_instance_id,
			)
		var item_record: NativeItemRecord = items[record.item_instance_id]
		if definitions.stack_definition(item_record.item_definition_id) == null:
			return _failure(
				ResultType.Outcome.NON_STACK_DEFINITION,
				record.item_instance_id,
				item_record.item_definition_id,
			)
		if record.amount < 0:
			return _failure(
				ResultType.Outcome.NEGATIVE_STACK_AMOUNT,
				record.item_instance_id,
			)
		stack_ids[record.item_instance_id] = true
	for item_instance_id: StringName in items:
		var item_record: NativeItemRecord = items[item_instance_id]
		if (
			definitions.stack_definition(item_record.item_definition_id) != null
			and not stack_ids.has(item_instance_id)
		):
			return _failure(
				ResultType.Outcome.MISSING_STACK_STATE,
				item_instance_id,
				item_record.item_definition_id,
			)

	var equipment_characters: Dictionary[StringName, bool] = {}
	var hand_instances: Dictionary[StringName, bool] = {}
	for record: NativeCharacterEquipmentRecord in snapshot.character_equipment_records:
		if record == null or record.character_id == &"":
			return _failure(ResultType.Outcome.MALFORMED_EQUIPMENT_RECORD)
		if equipment_characters.has(record.character_id):
			return _failure(
				ResultType.Outcome.DUPLICATE_EQUIPMENT_CHARACTER,
				record.character_id,
			)
		if (
			record.primary_item_instance_id != &""
			and record.primary_item_instance_id == record.secondary_item_instance_id
		):
			return _failure(
				ResultType.Outcome.DUPLICATE_HAND_INSTANCE,
				record.primary_item_instance_id,
				record.character_id,
			)
		for item_instance_id: StringName in [
			record.primary_item_instance_id,
			record.secondary_item_instance_id,
		]:
			if item_instance_id == &"":
				continue
			var equipment_result: NativeItemStateValidationResult = _validate_equipment_item(
				item_instance_id,
				record.character_id,
				items,
				parents,
				definitions,
			)
			if not equipment_result.succeeded:
				return equipment_result
			hand_instances[item_instance_id] = true
		if record.secondary_item_instance_id != &"":
			var secondary_item: NativeItemRecord = items[
				record.secondary_item_instance_id
			]
			var secondary_definition: WeaponDefinition = definitions.weapon_definition(
				secondary_item.item_definition_id
			)
			if (
				not secondary_definition.can_wield_as_secondary
				or secondary_definition.is_two_handed
			):
				return _failure(
					ResultType.Outcome.EQUIPMENT_DEFINITION_MISMATCH,
					record.secondary_item_instance_id,
					secondary_item.item_definition_id,
				)
		equipment_characters[record.character_id] = true

	var armor_characters: Dictionary[StringName, bool] = {}
	var all_armor_instances: Dictionary[StringName, bool] = {}
	for record: NativeCharacterArmorRecord in snapshot.character_armor_records:
		if record == null or record.character_id == &"":
			return _failure(ResultType.Outcome.MALFORMED_ARMOR_RECORD)
		if armor_characters.has(record.character_id):
			return _failure(
				ResultType.Outcome.DUPLICATE_ARMOR_CHARACTER,
				record.character_id,
			)
		var slots: Dictionary[StringName, bool] = {}
		for slot: NativeArmorSlotRecord in record.slots:
			if slot == null or slot.item_instance_id == &"":
				return _failure(
					ResultType.Outcome.MALFORMED_ARMOR_RECORD,
					record.character_id,
				)
			if slot.armor_type == &"":
				return _failure(
					ResultType.Outcome.INVALID_ARMOR_SLOT,
					slot.item_instance_id,
				)
			if slots.has(slot.armor_type):
				return _failure(
					ResultType.Outcome.DUPLICATE_ARMOR_SLOT,
					record.character_id,
					slot.armor_type,
				)
			if all_armor_instances.has(slot.item_instance_id):
				return _failure(
					ResultType.Outcome.DUPLICATE_ARMOR_INSTANCE,
					slot.item_instance_id,
				)
			if hand_instances.has(slot.item_instance_id):
				return _failure(
					ResultType.Outcome.HAND_ARMOR_INSTANCE_CONFLICT,
					slot.item_instance_id,
					record.character_id,
				)
			var armor_result: NativeItemStateValidationResult = _validate_armor_item(
				slot,
				record.character_id,
				items,
				parents,
				definitions,
			)
			if not armor_result.succeeded:
				return armor_result
			slots[slot.armor_type] = true
			all_armor_instances[slot.item_instance_id] = true
		armor_characters[record.character_id] = true

	return ResultType.new(ResultType.Outcome.SUCCESS)


static func _validate_parent_cycles(
	parents: Dictionary[StringName, ContainmentEndpoint],
) -> NativeItemStateValidationResult:
	for start_id: StringName in parents:
		var visited: Dictionary[StringName, bool] = {start_id: true}
		var current_id: StringName = start_id
		while parents.has(current_id):
			var parent: ContainmentEndpoint = parents[current_id]
			if parent.kind != EndpointType.Kind.ITEM:
				break
			if visited.has(parent.endpoint_id):
				return _failure(
					ResultType.Outcome.CONTAINMENT_CYCLE,
					start_id,
					parent.endpoint_id,
				)
			visited[parent.endpoint_id] = true
			current_id = parent.endpoint_id
	return ResultType.new(ResultType.Outcome.SUCCESS)


static func _validate_equipment_item(
	item_instance_id: StringName,
	character_id: StringName,
	items: Dictionary[StringName, NativeItemRecord],
	parents: Dictionary[StringName, ContainmentEndpoint],
	definitions: NativeItemDefinitionProjections,
) -> NativeItemStateValidationResult:
	if not items.has(item_instance_id):
		return _failure(
			ResultType.Outcome.MISSING_EQUIPMENT_ITEM,
			item_instance_id,
			character_id,
		)
	if not _is_direct_character_child(item_instance_id, character_id, parents):
		return _failure(
			ResultType.Outcome.EQUIPMENT_ITEM_NOT_DIRECT,
			item_instance_id,
			character_id,
		)
	var item_record: NativeItemRecord = items[item_instance_id]
	var weapon: WeaponDefinition = definitions.weapon_definition(
		item_record.item_definition_id
	)
	if weapon == null or weapon.weapon_id != item_record.item_definition_id:
		return _failure(
			ResultType.Outcome.EQUIPMENT_DEFINITION_MISMATCH,
			item_instance_id,
			item_record.item_definition_id,
		)
	return ResultType.new(ResultType.Outcome.SUCCESS)


static func _validate_armor_item(
	slot: NativeArmorSlotRecord,
	character_id: StringName,
	items: Dictionary[StringName, NativeItemRecord],
	parents: Dictionary[StringName, ContainmentEndpoint],
	definitions: NativeItemDefinitionProjections,
) -> NativeItemStateValidationResult:
	if not items.has(slot.item_instance_id):
		return _failure(
			ResultType.Outcome.MISSING_ARMOR_ITEM,
			slot.item_instance_id,
			character_id,
		)
	if not _is_direct_character_child(slot.item_instance_id, character_id, parents):
		return _failure(
			ResultType.Outcome.ARMOR_ITEM_NOT_DIRECT,
			slot.item_instance_id,
			character_id,
		)
	var item_record: NativeItemRecord = items[slot.item_instance_id]
	var definition: ArmorDefinition = definitions.armor_definition(
		item_record.item_definition_id
	)
	if definition == null or definition.item_definition_id != item_record.item_definition_id:
		return _failure(
			ResultType.Outcome.ARMOR_DEFINITION_MISMATCH,
			slot.item_instance_id,
			item_record.item_definition_id,
		)
	if definition.armor_type != slot.armor_type:
		return _failure(
			ResultType.Outcome.ARMOR_SLOT_MISMATCH,
			slot.item_instance_id,
			slot.armor_type,
		)
	return ResultType.new(ResultType.Outcome.SUCCESS)


static func _is_direct_character_child(
	item_instance_id: StringName,
	character_id: StringName,
	parents: Dictionary[StringName, ContainmentEndpoint],
) -> bool:
	if not parents.has(item_instance_id):
		return false
	var parent: ContainmentEndpoint = parents[item_instance_id]
	return (
		parent.kind == EndpointType.Kind.CHARACTER
		and parent.endpoint_id == character_id
	)


static func _failure(
	outcome: int,
	subject_id: StringName = &"",
	related_id: StringName = &"",
) -> NativeItemStateValidationResult:
	return ResultType.new(outcome, subject_id, related_id)
