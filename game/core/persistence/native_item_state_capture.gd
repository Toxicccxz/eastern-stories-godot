class_name NativeItemStateCapture
extends RefCounted

const ResultType := preload(
	"res://core/persistence/native_item_state_validation_result.gd"
)


static func capture(
	items: Array[ItemInstance],
	inventory: InventoryState,
	stacks: CombinedStackCollection,
	equipment_sources: Array[NativeCharacterEquipmentSource],
	armor_sources: Array[NativeCharacterArmorSource],
	definitions: NativeItemDefinitionProjections,
) -> NativeItemSnapshotCaptureResult:
	if inventory == null or stacks == null:
		return _failure(ResultType.Outcome.INVALID_SNAPSHOT)

	var item_by_id: Dictionary[StringName, ItemInstance] = {}
	for item: ItemInstance in items:
		if item == null or item.item_instance_id == &"" or item.item_definition_id == &"":
			return _failure(ResultType.Outcome.MALFORMED_ITEM_RECORD)
		if item_by_id.has(item.item_instance_id):
			return _failure(
				ResultType.Outcome.DUPLICATE_ITEM_INSTANCE_ID,
				item.item_instance_id,
			)
		if not inventory.is_registered(item.item_instance_id):
			return _failure(
				ResultType.Outcome.ITEM_INSTANCE_NOT_REGISTERED,
				item.item_instance_id,
			)
		item_by_id[item.item_instance_id] = item
	for item_instance_id: StringName in inventory.registered_item_ids():
		if not item_by_id.has(item_instance_id):
			return _failure(
				ResultType.Outcome.UNREPRESENTED_REGISTERED_ITEM,
				item_instance_id,
			)
	for item_instance_id: StringName in stacks.stack_instance_ids():
		if not item_by_id.has(item_instance_id):
			return _failure(
				ResultType.Outcome.ORPHAN_STACK_STATE,
				item_instance_id,
			)
		var item: ItemInstance = item_by_id[item_instance_id]
		var stack_definition: CombinedStackDefinition = stacks.stack_definition(
			item_instance_id
		)
		if (
			stack_definition == null
			or stack_definition.item_definition_id != item.item_definition_id
		):
			return _failure(
				ResultType.Outcome.NON_STACK_DEFINITION,
				item_instance_id,
			)

	var item_records: Array[NativeItemRecord] = []
	var stack_records: Array[NativeCombinedStackRecord] = []
	var sorted_item_ids: Array[StringName] = []
	sorted_item_ids.assign(item_by_id.keys())
	sorted_item_ids.sort_custom(_string_name_less_than)
	for item_instance_id: StringName in sorted_item_ids:
		var item: ItemInstance = item_by_id[item_instance_id]
		item_records.append(NativeItemRecord.new(
			item.item_instance_id,
			item.item_definition_id,
			inventory.own_weight(item.item_instance_id),
			inventory.direct_parent(item.item_instance_id),
		))
		if stacks.has_stack(item_instance_id):
			var stack_state: CombinedStackState = stacks.stack_state(item_instance_id)
			stack_records.append(NativeCombinedStackRecord.new(
				item_instance_id,
				stack_state.amount,
			))

	var equipment_records: Array[NativeCharacterEquipmentRecord] = []
	for source: NativeCharacterEquipmentSource in equipment_sources:
		if source == null or source.equipment_state == null:
			return _failure(ResultType.Outcome.MALFORMED_EQUIPMENT_RECORD)
		var primary: EquippedWeaponRef = source.equipment_state.primary_weapon()
		var secondary: EquippedWeaponRef = source.equipment_state.secondary_weapon()
		for reference: EquippedWeaponRef in [primary, secondary]:
			if reference == null:
				continue
			var item: ItemInstance = item_by_id.get(reference.instance_id)
			if item == null:
				return _failure(
					ResultType.Outcome.MISSING_EQUIPMENT_ITEM,
					reference.instance_id,
				)
			if item.item_definition_id != reference.weapon_id:
				return _failure(
					ResultType.Outcome.EQUIPMENT_DEFINITION_MISMATCH,
					reference.instance_id,
				)
		equipment_records.append(NativeCharacterEquipmentRecord.new(
			source.character_id,
			&"" if primary == null else primary.instance_id,
			&"" if secondary == null else secondary.instance_id,
		))

	var armor_records: Array[NativeCharacterArmorRecord] = []
	for source: NativeCharacterArmorSource in armor_sources:
		if source == null or source.armor_state == null:
			return _failure(ResultType.Outcome.MALFORMED_ARMOR_RECORD)
		var slot_records: Array[NativeArmorSlotRecord] = []
		for armor_type: StringName in source.armor_state.occupied_slots():
			var reference: EquippedArmorRef = source.armor_state.equipped_ref_in_slot(
				armor_type
			)
			var item: ItemInstance = item_by_id.get(reference.item_instance_id)
			if item == null:
				return _failure(
					ResultType.Outcome.MISSING_ARMOR_ITEM,
					reference.item_instance_id,
				)
			if (
				item.item_definition_id != reference.item_definition_id
				or reference.armor_type != armor_type
			):
				return _failure(
					ResultType.Outcome.ARMOR_DEFINITION_MISMATCH,
					reference.item_instance_id,
				)
			slot_records.append(NativeArmorSlotRecord.new(
				armor_type,
				reference.item_instance_id,
			))
		armor_records.append(NativeCharacterArmorRecord.new(
			source.character_id,
			slot_records,
		))

	var snapshot: NativeItemStateSnapshot = NativeItemStateSnapshot.new(
		NativeItemStateSnapshot.CURRENT_SCHEMA_VERSION,
		item_records,
		stack_records,
		equipment_records,
		armor_records,
	)
	var validation: NativeItemStateValidationResult = NativeItemStateValidator.validate(
		snapshot,
		definitions,
	)
	if not validation.succeeded:
		return NativeItemSnapshotCaptureResult.new(null, validation)
	return NativeItemSnapshotCaptureResult.new(snapshot, validation)


static func _failure(
	outcome: int,
	subject_id: StringName = &"",
) -> NativeItemSnapshotCaptureResult:
	return NativeItemSnapshotCaptureResult.new(
		null,
		ResultType.new(outcome, subject_id),
	)


static func _string_name_less_than(left: StringName, right: StringName) -> bool:
	return String(left) < String(right)
