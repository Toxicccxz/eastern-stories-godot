class_name NativeItemStateRestorer
extends RefCounted

const ResultType := preload(
	"res://core/persistence/native_item_state_validation_result.gd"
)


static func restore(
	snapshot: NativeItemStateSnapshot,
	definitions: NativeItemDefinitionProjections,
) -> NativeItemStateRestoreResult:
	## No authoritative aggregate is created until the complete supplied DTO has
	## passed schema, identity, graph, stack, hand, and armor validation.
	var validation: NativeItemStateValidationResult = NativeItemStateValidator.validate(
		snapshot,
		definitions,
	)
	if not validation.succeeded:
		return NativeItemStateRestoreResult.new(null, validation)

	var items: Dictionary[StringName, ItemInstance] = {}
	var inventory: InventoryState = InventoryState.new()
	for record: NativeItemRecord in snapshot.item_records:
		var item: ItemInstance = ItemInstance.new(
			record.item_instance_id,
			record.item_definition_id,
		)
		items[item.item_instance_id] = item
		if not inventory.register_item(item, record.own_weight):
			return _reconstruction_failure(item.item_instance_id)

	## Trusted graph reconstruction bypasses gameplay capacity/detach semantics,
	## while InventoryState still revalidates endpoint and cycle invariants.
	for record: NativeItemRecord in snapshot.item_records:
		var parent: ContainmentEndpoint = record.direct_parent
		if parent != null and not inventory._apply_reparent(
			record.item_instance_id,
			parent,
		):
			return _reconstruction_failure(record.item_instance_id)

	var stacks: CombinedStackCollection = CombinedStackCollection.new()
	for record: NativeCombinedStackRecord in snapshot.combined_stack_records:
		var item: ItemInstance = items[record.item_instance_id]
		var stack_definition: CombinedStackDefinition = definitions.stack_definition(
			item.item_definition_id
		)
		if not stacks._register_stack(
			CombinedStackState.new(record.item_instance_id, record.amount),
			stack_definition,
		):
			return _reconstruction_failure(record.item_instance_id)

	var equipment_by_character: Dictionary[StringName, EquipmentState] = {}
	for record: NativeCharacterEquipmentRecord in snapshot.character_equipment_records:
		var equipment: EquipmentState = EquipmentState.new()
		var primary: EquippedWeaponRef
		var secondary: EquippedWeaponRef
		if record.primary_item_instance_id != &"":
			var primary_item: ItemInstance = items[record.primary_item_instance_id]
			primary = EquippedWeaponRef.new(
				primary_item.item_instance_id,
				definitions.weapon_definition(primary_item.item_definition_id),
			)
		if record.secondary_item_instance_id != &"":
			var secondary_item: ItemInstance = items[record.secondary_item_instance_id]
			secondary = EquippedWeaponRef.new(
				secondary_item.item_instance_id,
				definitions.weapon_definition(secondary_item.item_definition_id),
			)
		if not equipment._restore_weapons(primary, secondary):
			return _reconstruction_failure(record.character_id)
		equipment_by_character[record.character_id] = equipment

	var armor_by_character: Dictionary[StringName, ArmorState] = {}
	for record: NativeCharacterArmorRecord in snapshot.character_armor_records:
		var armor: ArmorState = ArmorState.new()
		var references: Array[EquippedArmorRef] = []
		for slot: NativeArmorSlotRecord in record.slots:
			var armor_item: ItemInstance = items[slot.item_instance_id]
			references.append(EquippedArmorRef.new(
				armor_item.item_instance_id,
				definitions.armor_definition(armor_item.item_definition_id),
			))
		if not armor._restore_equipped_refs(references):
			return _reconstruction_failure(record.character_id)
		armor_by_character[record.character_id] = armor

	var reconstructed: NativeItemDomainState = NativeItemDomainState.new(
		items,
		inventory,
		stacks,
		equipment_by_character,
		armor_by_character,
	)
	return NativeItemStateRestoreResult.new(reconstructed, validation)


static func _reconstruction_failure(
	subject_id: StringName,
) -> NativeItemStateRestoreResult:
	return NativeItemStateRestoreResult.new(
		null,
		ResultType.new(ResultType.Outcome.RECONSTRUCTION_FAILED, subject_id),
	)
