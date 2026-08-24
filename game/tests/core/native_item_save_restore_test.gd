extends RefCounted

const ItemDefinitionScript := preload("res://core/items/item_definition.gd")
const ItemInstanceScript := preload("res://core/items/item_instance.gd")
const EndpointScript := preload("res://core/inventory/containment_endpoint.gd")
const InventoryStateScript := preload("res://core/inventory/inventory_state.gd")
const WeaponDefinitionScript := preload("res://core/equipment/weapon_definition.gd")
const EquippedWeaponRefScript := preload("res://core/equipment/equipped_weapon_ref.gd")
const EquipmentStateScript := preload("res://core/equipment/equipment_state.gd")
const ArmorModifiersScript := preload("res://core/armor/armor_numeric_modifiers.gd")
const ArmorDefinitionScript := preload("res://core/armor/armor_definition.gd")
const EquippedArmorRefScript := preload("res://core/armor/equipped_armor_ref.gd")
const ArmorStateScript := preload("res://core/armor/armor_state.gd")
const StackDefinitionScript := preload(
	"res://core/items/combined/combined_stack_definition.gd"
)
const StackStateScript := preload("res://core/items/combined/combined_stack_state.gd")
const StackCollectionScript := preload(
	"res://core/items/combined/combined_stack_collection.gd"
)
const ItemRecordScript := preload("res://core/persistence/native_item_record.gd")
const StackRecordScript := preload(
	"res://core/persistence/native_combined_stack_record.gd"
)
const EquipmentRecordScript := preload(
	"res://core/persistence/native_character_equipment_record.gd"
)
const ArmorSlotRecordScript := preload(
	"res://core/persistence/native_armor_slot_record.gd"
)
const ArmorRecordScript := preload(
	"res://core/persistence/native_character_armor_record.gd"
)
const SnapshotScript := preload(
	"res://core/persistence/native_item_state_snapshot.gd"
)
const DefinitionProjectionsScript := preload(
	"res://core/persistence/native_item_definition_projections.gd"
)
const EquipmentSourceScript := preload(
	"res://core/persistence/native_character_equipment_source.gd"
)
const ArmorSourceScript := preload(
	"res://core/persistence/native_character_armor_source.gd"
)
const ValidationResultScript := preload(
	"res://core/persistence/native_item_state_validation_result.gd"
)
const ValidatorScript := preload(
	"res://core/persistence/native_item_state_validator.gd"
)
const CaptureResultScript := preload(
	"res://core/persistence/native_item_snapshot_capture_result.gd"
)
const CaptureScript := preload(
	"res://core/persistence/native_item_state_capture.gd"
)
const DomainStateScript := preload(
	"res://core/persistence/native_item_domain_state.gd"
)
const RestoreResultScript := preload(
	"res://core/persistence/native_item_state_restore_result.gd"
)
const RestorerScript := preload(
	"res://core/persistence/native_item_state_restorer.gd"
)

const CHARACTER_ID: StringName = &"character:phase_4b5a"
const DEF_PLAIN: StringName = &"item:plain"
const DEF_BAG: StringName = &"item:bag"
const DEF_PRIMARY: StringName = &"weapon:primary"
const DEF_SECONDARY: StringName = &"weapon:secondary"
const DEF_TWO_HANDED: StringName = &"weapon:two_handed"
const DEF_COMBINED_FLAGS: StringName = &"weapon:two_handed_secondary"
const DEF_BOOTS: StringName = &"armor:boots"
const DEF_FEET: StringName = &"armor:feet"
const DEF_BANDAGE: StringName = &"armor:bandage"
const DEF_SHIELD: StringName = &"armor:shield"
const DEF_CUSTOM_ARMOR: StringName = &"armor:custom"
const DEF_STACK: StringName = &"money:coin"
const DEF_HYBRID: StringName = &"item:test_hybrid"

var _assertion_count: int = 0
var _failures: Array[String] = []


func run_all() -> Dictionary[String, Variant]:
	_test_schema_shape_ordering_and_immutability()
	_test_definition_projection_boundary()
	_test_capture_restore_representative_state()
	_test_schema_item_and_parent_failures()
	_test_stack_failures_and_exact_weight_restore()
	_test_equipment_failures_and_historical_shapes()
	_test_armor_failures_custom_slots_and_definition_changes()
	_test_all_or_nothing_independence_and_capture_boundaries()
	return {
		"assertions": _assertion_count,
		"failures": _failures.duplicate(),
	}


func _test_schema_shape_ordering_and_immutability() -> void:
	var parent: EndpointScript = _character(CHARACTER_ID)
	var source_record: ItemRecordScript = ItemRecordScript.new(
		&"item:z",
		DEF_PLAIN,
		17,
		parent,
	)
	var source_slot: ArmorSlotRecordScript = ArmorSlotRecordScript.new(
		&"feet",
		&"armor:feet_instance",
	)
	var snapshot: SnapshotScript = SnapshotScript.new(
		SnapshotScript.CURRENT_SCHEMA_VERSION,
		[
			source_record,
			ItemRecordScript.new(&"item:a", DEF_PLAIN, -4),
		],
		[
			StackRecordScript.new(&"stack:z", 3),
			StackRecordScript.new(&"stack:a", 0),
		],
		[
			EquipmentRecordScript.new(&"character:z"),
			EquipmentRecordScript.new(&"character:a"),
		],
		[
			ArmorRecordScript.new(&"character:z", [source_slot]),
			ArmorRecordScript.new(&"character:a"),
		],
	)
	_assert_eq(snapshot.schema_version, 1, "schema v1 is explicit and positive")
	_assert_eq(
		_item_record_ids(snapshot.item_records),
		[&"item:a", &"item:z"],
		"item records sort by stable instance ID",
	)
	_assert_eq(
		_stack_record_ids(snapshot.combined_stack_records),
		[&"stack:a", &"stack:z"],
		"stack records sort by stable instance ID",
	)
	_assert_eq(
		_equipment_character_ids(snapshot.character_equipment_records),
		[&"character:a", &"character:z"],
		"equipment records sort by character ID",
	)
	_assert_eq(
		_armor_character_ids(snapshot.character_armor_records),
		[&"character:a", &"character:z"],
		"armor records sort by character ID",
	)

	## GDScript underscore privacy is conventional, so mutate every caller copy
	## to prove the DTO owns only scalar/value snapshots.
	parent._endpoint_id = &"character:mutated"
	source_record._own_weight = 999
	source_slot._armor_type = &"mutated"
	var returned_items: Array[NativeItemRecord] = snapshot.item_records
	returned_items[-1]._item_instance_id = &"mutated"
	returned_items.clear()
	_assert_eq(snapshot.item_records.size(), 2, "item array getter is defensive")
	_assert_eq(snapshot.item_records[-1].item_instance_id, &"item:z", "item record is defensive")
	_assert_eq(snapshot.item_records[-1].own_weight, 17, "own weight scalar is immutable")
	_assert_eq(
		snapshot.item_records[-1].direct_parent.endpoint_id,
		CHARACTER_ID,
		"parent endpoint is defensive",
	)
	var returned_armor: Array[NativeCharacterArmorRecord] = snapshot.character_armor_records
	var returned_slots: Array[NativeArmorSlotRecord] = returned_armor[-1].slots
	returned_slots.clear()
	_assert_eq(snapshot.character_armor_records[-1].slots.size(), 1, "armor slots getter is defensive")
	_assert_eq(snapshot.character_armor_records[-1].slots[0].armor_type, &"feet", "slot scalar is immutable")
	var returned_stacks: Array[NativeCombinedStackRecord] = snapshot.combined_stack_records
	returned_stacks[0]._amount = 999
	returned_stacks.clear()
	_assert_eq(snapshot.combined_stack_records[0].amount, 0, "stack record getter is defensive")
	var returned_equipment: Array[NativeCharacterEquipmentRecord] = snapshot.character_equipment_records
	returned_equipment[0]._character_id = &"mutated"
	returned_equipment.clear()
	_assert_eq(snapshot.character_equipment_records[0].character_id, &"character:a", "equipment record getter is defensive")
	_assert_false(_has_property(snapshot, &"file_path"), "snapshot has no storage path")
	_assert_false(_has_property(snapshot, &"pending_destruction"), "schema omits runtime pending intent")
	_assert_false(_has_property(source_record, &"root_holder"), "item record does not persist root holder")
	_assert_false(_has_property(source_record, &"ancestry"), "item record does not persist ancestry")


func _test_definition_projection_boundary() -> void:
	var source_item: ItemDefinitionScript = ItemDefinitionScript.new(
		DEF_PLAIN,
		"reference/es2/mudlib/obj/test.c",
	)
	var source_modifiers: ArmorModifiersScript = ArmorModifiersScript.new(7)
	var projections: DefinitionProjectionsScript = DefinitionProjectionsScript.new(
		[source_item, ItemDefinitionScript.new(DEF_BOOTS)],
		[],
		[ArmorDefinitionScript.new(DEF_BOOTS, &"boots", source_modifiers)],
	)
	_assert_true(projections.is_valid, "well-formed explicit projections are valid")
	source_item._legacy_source_path = "mutated"
	source_modifiers._armor = 99
	var returned_item: ItemDefinitionScript = projections.item_definition(DEF_PLAIN)
	returned_item._legacy_source_path = "mutated again"
	var returned_armor: ArmorDefinitionScript = projections.armor_definition(DEF_BOOTS)
	returned_armor._armor_type = &"mutated"
	_assert_eq(
		projections.item_definition(DEF_PLAIN).legacy_source_path,
		"reference/es2/mudlib/obj/test.c",
		"projection copies authored item facts",
	)
	_assert_eq(projections.armor_definition(DEF_BOOTS).armor_type, &"boots", "projection getter is defensive")
	_assert_eq(projections.armor_definition(DEF_BOOTS).numeric_modifiers.armor, 7, "projection copies armor modifiers")
	_assert_false(
		DefinitionProjectionsScript.new([
			ItemDefinitionScript.new(DEF_PLAIN),
			ItemDefinitionScript.new(DEF_PLAIN),
		]).is_valid,
		"duplicate base definition IDs invalidate projections",
	)
	_assert_false(
		DefinitionProjectionsScript.new([ItemDefinitionScript.new(&"")]).is_valid,
		"empty base definition ID invalidates projections",
	)
	_assert_false(
		DefinitionProjectionsScript.new(
			[ItemDefinitionScript.new(DEF_PLAIN)],
			[WeaponDefinitionScript.new(DEF_PRIMARY, &"sword")],
		).is_valid,
		"weapon projection without matching base definition is invalid",
	)
	_assert_false(
		DefinitionProjectionsScript.new(
			[ItemDefinitionScript.new(DEF_PLAIN)],
			[],
			[ArmorDefinitionScript.new(DEF_BOOTS, &"boots")],
		).is_valid,
		"armor projection without matching base definition is invalid",
	)
	_assert_false(
		DefinitionProjectionsScript.new(
			[ItemDefinitionScript.new(DEF_PLAIN)],
			[],
			[],
			[StackDefinitionScript.new(DEF_STACK, &"legacy:/coin", 1)],
		).is_valid,
		"stack projection without matching base definition is invalid",
	)


func _test_capture_restore_representative_state() -> void:
	var definitions: DefinitionProjectionsScript = _definitions()
	var inventory: InventoryStateScript = InventoryStateScript.new()
	var stacks: StackCollectionScript = StackCollectionScript.new()
	var items: Array[ItemInstance] = [
		_item(&"world:ground", DEF_PLAIN),
		_item(&"item:nested", DEF_PLAIN),
		_item(&"stack:money", DEF_STACK),
		_item(&"container:bag", DEF_BAG),
		_item(&"armor:boots_instance", DEF_BOOTS),
		_item(&"weapon:secondary_instance", DEF_SECONDARY),
		_item(&"weapon:primary_instance", DEF_PRIMARY),
		_item(&"item:unparented", DEF_PLAIN),
	]
	var weights: Dictionary[StringName, int] = {
		&"weapon:primary_instance": 11,
		&"weapon:secondary_instance": 12,
		&"armor:boots_instance": 13,
		&"container:bag": 7,
		&"stack:money": 25,
		&"item:nested": 5,
		&"item:unparented": -3,
		&"world:ground": 9,
	}
	for item: ItemInstance in items:
		_assert_true(inventory.register_item(item, weights[item.item_instance_id]), "capture item registers")
	_place(inventory, &"weapon:primary_instance", _character(CHARACTER_ID))
	_place(inventory, &"weapon:secondary_instance", _character(CHARACTER_ID))
	_place(inventory, &"armor:boots_instance", _character(CHARACTER_ID))
	_place(inventory, &"container:bag", _character(CHARACTER_ID))
	_place(inventory, &"stack:money", _character(CHARACTER_ID))
	_place(inventory, &"item:nested", _item_endpoint(&"container:bag"))
	_place(inventory, &"world:ground", _world(&"world:logical_market"))
	_assert_true(
		stacks._register_stack(
			StackStateScript.new(&"stack:money", 25),
			definitions.stack_definition(DEF_STACK),
		),
		"capture stack state registers without recomputing saved weight",
	)
	var equipment: EquipmentStateScript = EquipmentStateScript.new()
	_assert_true(
		equipment._restore_weapons(
			EquippedWeaponRefScript.new(
				&"weapon:primary_instance",
				definitions.weapon_definition(DEF_PRIMARY),
			),
			EquippedWeaponRefScript.new(
				&"weapon:secondary_instance",
				definitions.weapon_definition(DEF_SECONDARY),
			),
		),
		"capture equipment fixture is structurally valid",
	)
	var armor: ArmorStateScript = ArmorStateScript.new()
	_assert_true(
		armor._restore_equipped_refs([
			EquippedArmorRefScript.new(
				&"armor:boots_instance",
				definitions.armor_definition(DEF_BOOTS),
			),
		]),
		"capture armor fixture is structurally valid",
	)
	var capture: CaptureResultScript = CaptureScript.capture(
		items,
		inventory,
		stacks,
		[EquipmentSourceScript.new(CHARACTER_ID, equipment)],
		[ArmorSourceScript.new(CHARACTER_ID, armor)],
		definitions,
	)
	_assert_true(capture.succeeded, "representative native capture succeeds")
	var snapshot: SnapshotScript = capture.snapshot
	_assert_eq(snapshot.item_records.size(), 8, "capture includes every represented live item")
	_assert_eq(snapshot.combined_stack_records.size(), 1, "capture includes stack mutable state")
	_assert_eq(snapshot.character_equipment_records.size(), 1, "capture includes represented Equipment state")
	_assert_eq(snapshot.character_armor_records.size(), 1, "capture includes represented Armor state")
	_assert_eq(snapshot.combined_stack_records[0].amount, 25, "capture reads exact stack amount")
	_assert_eq(snapshot.item_records[0].item_instance_id, &"armor:boots_instance", "capture ordering stable")
	_assert_eq(_record(snapshot, &"item:unparented").direct_parent, null, "capture preserves unparented live item")
	_assert_eq(
		_record(snapshot, &"world:ground").direct_parent.endpoint_id,
		&"world:logical_market",
		"capture preserves logical world endpoint",
	)

	var restored: RestoreResultScript = RestorerScript.restore(snapshot, definitions)
	_assert_true(restored.succeeded, "representative native restore succeeds")
	_assert_eq(restored.validation_result.outcome, ValidationResultScript.Outcome.SUCCESS, "restore reports typed success")
	var state: DomainStateScript = restored.reconstructed_state
	_assert_eq(state.item_instance_ids().size(), 8, "restore reconstructs every item identity")
	for item: ItemInstance in items:
		var restored_item: ItemInstanceScript = state.item_instance(item.item_instance_id)
		_assert_eq(restored_item.item_definition_id, item.item_definition_id, "definition identity round-trips")
		_assert_eq(state.inventory.own_weight(item.item_instance_id), weights[item.item_instance_id], "own weight round-trips exactly")
	_assert_true(
		state.inventory.is_direct_child(&"item:nested", _item_endpoint(&"container:bag")),
		"nested direct parent round-trips",
	)
	_assert_eq(
		state.inventory.root_holder(&"item:nested").endpoint_id,
		CHARACTER_ID,
		"ancestry and root holder derive after restore",
	)
	_assert_eq(state.inventory.direct_parent(&"item:unparented"), null, "unparented remains unparented")
	_assert_true(
		state.inventory.is_direct_child(&"world:ground", _world(&"world:logical_market")),
		"logical world endpoint reconstructs without a scene",
	)
	_assert_eq(state.combined_stacks.stack_state(&"stack:money").amount, 25, "stack amount round-trips")
	_assert_eq(state.equipment_state(CHARACTER_ID).primary_weapon().instance_id, &"weapon:primary_instance", "primary ref restores")
	_assert_eq(state.equipment_state(CHARACTER_ID).secondary_weapon().instance_id, &"weapon:secondary_instance", "secondary ref restores")
	_assert_eq(state.armor_state(CHARACTER_ID).item_instance_id_in_slot(&"boots"), &"armor:boots_instance", "armor slot restores")
	_assert_eq(state.armor_state(CHARACTER_ID).aggregate_numeric_modifiers().armor, 4, "armor aggregate derives from current definition")

	var recaptured_items: Array[ItemInstance] = []
	for item_instance_id: StringName in state.item_instance_ids():
		recaptured_items.append(state.item_instance(item_instance_id))
	var recaptured_equipment: Array[NativeCharacterEquipmentSource] = []
	for character_id: StringName in state.equipment_character_ids():
		recaptured_equipment.append(EquipmentSourceScript.new(
			character_id,
			state.equipment_state(character_id),
		))
	var recaptured_armor: Array[NativeCharacterArmorSource] = []
	for character_id: StringName in state.armor_character_ids():
		recaptured_armor.append(ArmorSourceScript.new(
			character_id,
			state.armor_state(character_id),
		))
	var recapture: CaptureResultScript = CaptureScript.capture(
		recaptured_items,
		state.inventory,
		state.combined_stacks,
		recaptured_equipment,
		recaptured_armor,
		definitions,
	)
	_assert_true(recapture.succeeded, "restored representative state can be captured again")
	_assert_eq(
		_snapshot_facts(recapture.snapshot),
		_snapshot_facts(snapshot),
		"capture restore capture is canonical for every schema v1 persisted fact",
	)

	var independent_restore: RestoreResultScript = RestorerScript.restore(snapshot, definitions)
	_assert_true(independent_restore.succeeded, "representative snapshot restores independently twice")
	state.combined_stacks._apply_amount(&"stack:money", 1)
	state.equipment_state(CHARACTER_ID).unwield(&"weapon:primary_instance")
	state.armor_state(CHARACTER_ID).remove(&"armor:boots_instance")
	_assert_eq(independent_restore.reconstructed_state.combined_stacks.stack_state(&"stack:money").amount, 25, "fresh CombinedStack collections do not share mutation")
	_assert_eq(independent_restore.reconstructed_state.equipment_state(CHARACTER_ID).primary_weapon().instance_id, &"weapon:primary_instance", "fresh Equipment states do not share mutation")
	_assert_true(independent_restore.reconstructed_state.armor_state(CHARACTER_ID).is_slot_occupied(&"boots"), "fresh Armor states do not share mutation")


func _test_schema_item_and_parent_failures() -> void:
	var definitions: DefinitionProjectionsScript = _definitions()
	_assert_restore_failure(
		_snapshot([], [], [], [], 0),
		ValidationResultScript.Outcome.INVALID_SCHEMA_VERSION,
		"schema version zero rejects",
		definitions,
	)
	_assert_restore_failure(
		_snapshot([], [], [], [], -1),
		ValidationResultScript.Outcome.INVALID_SCHEMA_VERSION,
		"negative schema version rejects",
		definitions,
	)
	_assert_restore_failure(
		_snapshot([], [], [], [], 2),
		ValidationResultScript.Outcome.INVALID_SCHEMA_VERSION,
		"unknown positive schema rejects",
		definitions,
	)
	_assert_restore_failure(
		_snapshot([_item_record(&"duplicate", DEF_PLAIN), _item_record(&"duplicate", DEF_PLAIN)]),
		ValidationResultScript.Outcome.DUPLICATE_ITEM_INSTANCE_ID,
		"duplicate item instance rejects",
		definitions,
	)
	_assert_restore_failure(
		_snapshot([_item_record(&"unknown", &"definition:missing")]),
		ValidationResultScript.Outcome.UNKNOWN_ITEM_DEFINITION,
		"unknown item definition rejects",
		definitions,
	)
	_assert_restore_failure(
		_snapshot([ItemRecordScript.new(&"", DEF_PLAIN, 0)]),
		ValidationResultScript.Outcome.MALFORMED_ITEM_RECORD,
		"empty instance authority rejects",
		definitions,
	)
	_assert_restore_failure(
		_snapshot([ItemRecordScript.new(&"item:empty_def", &"", 0)]),
		ValidationResultScript.Outcome.MALFORMED_ITEM_RECORD,
		"empty definition authority rejects",
		definitions,
	)
	_assert_restore_failure(
		_snapshot([_item_record(&"item:bad_parent", DEF_PLAIN, EndpointScript.new(EndpointScript.Kind.WORLD, &""))]),
		ValidationResultScript.Outcome.INVALID_PARENT_ENDPOINT,
		"malformed empty endpoint rejects",
		definitions,
	)
	_assert_restore_failure(
		_snapshot([_item_record(&"item:orphan", DEF_PLAIN, _item_endpoint(&"item:missing"))]),
		ValidationResultScript.Outcome.MISSING_PARENT_ITEM,
		"missing item parent rejects",
		definitions,
	)
	_assert_restore_failure(
		_snapshot([_item_record(&"item:self", DEF_PLAIN, _item_endpoint(&"item:self"))]),
		ValidationResultScript.Outcome.CONTAINMENT_CYCLE,
		"self-cycle rejects",
		definitions,
	)
	_assert_restore_failure(
		_snapshot([
			_item_record(&"item:a", DEF_PLAIN, _item_endpoint(&"item:b")),
			_item_record(&"item:b", DEF_PLAIN, _item_endpoint(&"item:a")),
		]),
		ValidationResultScript.Outcome.CONTAINMENT_CYCLE,
		"two-item cycle rejects",
		definitions,
	)
	_assert_restore_failure(
		_snapshot([
			_item_record(&"item:a", DEF_PLAIN, _item_endpoint(&"item:b")),
			_item_record(&"item:b", DEF_PLAIN, _item_endpoint(&"item:c")),
			_item_record(&"item:c", DEF_PLAIN, _item_endpoint(&"item:a")),
		]),
		ValidationResultScript.Outcome.CONTAINMENT_CYCLE,
		"deeper cycle rejects",
		definitions,
	)


func _test_stack_failures_and_exact_weight_restore() -> void:
	var definitions: DefinitionProjectionsScript = _definitions()
	_assert_restore_failure(
		_snapshot([_item_record(&"stack:state_missing", DEF_STACK)]),
		ValidationResultScript.Outcome.MISSING_STACK_STATE,
		"stack-capable live item without amount state rejects",
		definitions,
	)
	_assert_restore_failure(
		_snapshot([], [StackRecordScript.new(&"stack:missing", 1)]),
		ValidationResultScript.Outcome.MISSING_STACK_ITEM,
		"stack missing item rejects",
		definitions,
	)
	_assert_restore_failure(
		_snapshot([_item_record(&"plain", DEF_PLAIN)], [StackRecordScript.new(&"plain", 1)]),
		ValidationResultScript.Outcome.NON_STACK_DEFINITION,
		"non-stack definition rejects stack state",
		definitions,
	)
	_assert_restore_failure(
		_snapshot([_item_record(&"stack", DEF_STACK)], [StackRecordScript.new(&"stack", -1)]),
		ValidationResultScript.Outcome.NEGATIVE_STACK_AMOUNT,
		"negative stack amount rejects",
		definitions,
	)
	_assert_restore_failure(
		_snapshot(
			[_item_record(&"stack", DEF_STACK)],
			[StackRecordScript.new(&"stack", 1), StackRecordScript.new(&"stack", 2)],
		),
		ValidationResultScript.Outcome.DUPLICATE_STACK_RECORD,
		"duplicate stack record rejects",
		definitions,
	)
	_assert_restore_failure(
		_snapshot([_item_record(&"stack", DEF_STACK)], [StackRecordScript.new(&"", 1)]),
		ValidationResultScript.Outcome.MALFORMED_STACK_RECORD,
		"empty stack instance authority rejects",
		definitions,
	)

	## Raw static amount zero is a live stack and its independently authoritative
	## Inventory own weight is not amount * current base_weight.
	var raw_zero: SnapshotScript = _snapshot(
		[_item_record(&"stack:raw_zero", DEF_STACK, null, 77)],
		[StackRecordScript.new(&"stack:raw_zero", 0)],
	)
	var changed_stack_definition: DefinitionProjectionsScript = _definitions(4, 999)
	var raw_restore: RestoreResultScript = RestorerScript.restore(raw_zero, changed_stack_definition)
	_assert_true(raw_restore.succeeded, "raw-zero stack restore succeeds")
	_assert_eq(raw_restore.reconstructed_state.combined_stacks.stack_state(&"stack:raw_zero").amount, 0, "raw-zero amount remains zero")
	_assert_eq(raw_restore.reconstructed_state.inventory.own_weight(&"stack:raw_zero"), 77, "raw-zero unusual own weight restores exactly")

	var changed_weight: SnapshotScript = _snapshot(
		[_item_record(&"stack:changed_weight", DEF_STACK, null, 13)],
		[StackRecordScript.new(&"stack:changed_weight", 7)],
	)
	var changed_weight_restore: RestoreResultScript = RestorerScript.restore(
		changed_weight,
		changed_stack_definition,
	)
	_assert_true(changed_weight_restore.succeeded, "positive stack restores after current base weight changes")
	_assert_eq(changed_weight_restore.reconstructed_state.combined_stacks.stack_state(&"stack:changed_weight").amount, 7, "positive saved amount remains authoritative")
	_assert_eq(changed_weight_restore.reconstructed_state.inventory.own_weight(&"stack:changed_weight"), 13, "positive stack saved own weight is not recomputed")

	## std/item/combined.c leaves the old positive amount/weight observable in
	## the one-second set_amount(0) window; schema v1 intentionally omits callout.
	var pending_window: SnapshotScript = _snapshot(
		[_item_record(&"stack:pending", DEF_STACK, _character(CHARACTER_ID), 5)],
		[StackRecordScript.new(&"stack:pending", 5)],
	)
	var pending_restore: RestoreResultScript = RestorerScript.restore(pending_window, definitions)
	_assert_true(pending_restore.succeeded, "pending-window observable state restores")
	_assert_eq(pending_restore.reconstructed_state.combined_stacks.stack_state(&"stack:pending").amount, 5, "old visible amount survives reload")
	_assert_eq(pending_restore.reconstructed_state.inventory.own_weight(&"stack:pending"), 5, "old visible weight survives reload")
	_assert_false(_has_property(pending_restore.reconstructed_state, &"pending_destruction"), "restore creates no pending runtime intent")


func _test_equipment_failures_and_historical_shapes() -> void:
	var definitions: DefinitionProjectionsScript = _definitions()
	_assert_restore_failure(
		_snapshot([], [], [EquipmentRecordScript.new(CHARACTER_ID, &"weapon:missing")]),
		ValidationResultScript.Outcome.MISSING_EQUIPMENT_ITEM,
		"equipment missing item rejects",
		definitions,
	)
	_assert_restore_failure(
		_snapshot([
			_item_record(&"bag", DEF_BAG, _character(CHARACTER_ID)),
			_item_record(&"weapon", DEF_PRIMARY, _item_endpoint(&"bag")),
		], [], [EquipmentRecordScript.new(CHARACTER_ID, &"weapon")]),
		ValidationResultScript.Outcome.EQUIPMENT_ITEM_NOT_DIRECT,
		"nested equipment item rejects",
		definitions,
	)
	_assert_restore_failure(
		_snapshot(
			[_item_record(&"weapon", DEF_PRIMARY, _character(CHARACTER_ID))],
			[],
			[EquipmentRecordScript.new(CHARACTER_ID, &"weapon", &"weapon")],
		),
		ValidationResultScript.Outcome.DUPLICATE_HAND_INSTANCE,
		"same primary and secondary instance rejects",
		definitions,
	)
	_assert_restore_failure(
		_snapshot(
			[_item_record(&"plain", DEF_PLAIN, _character(CHARACTER_ID))],
			[],
			[EquipmentRecordScript.new(CHARACTER_ID, &"plain")],
		),
		ValidationResultScript.Outcome.EQUIPMENT_DEFINITION_MISMATCH,
		"non-weapon hand definition rejects",
		definitions,
	)
	_assert_restore_failure(
		_snapshot(
			[_item_record(&"primary_only", DEF_PRIMARY, _character(CHARACTER_ID))],
			[],
			[EquipmentRecordScript.new(CHARACTER_ID, &"", &"primary_only")],
		),
		ValidationResultScript.Outcome.EQUIPMENT_DEFINITION_MISMATCH,
		"non-secondary-capable definition cannot occupy secondary structurally",
		definitions,
	)
	_assert_restore_failure(
		_snapshot([], [], [EquipmentRecordScript.new(&"")]),
		ValidationResultScript.Outcome.MALFORMED_EQUIPMENT_RECORD,
		"empty equipment character authority rejects",
		definitions,
	)
	_assert_restore_failure(
		_snapshot(
			[],
			[],
			[
				EquipmentRecordScript.new(CHARACTER_ID),
				EquipmentRecordScript.new(CHARACTER_ID),
			],
		),
		ValidationResultScript.Outcome.DUPLICATE_EQUIPMENT_CHARACTER,
		"duplicate Equipment authority for one character rejects",
		definitions,
	)
	_assert_restore_failure(
		_snapshot(
			[_item_record(&"weapon:shared", DEF_PRIMARY, _character(&"character:a"))],
			[],
			[
				EquipmentRecordScript.new(&"character:a", &"weapon:shared"),
				EquipmentRecordScript.new(&"character:z", &"weapon:shared"),
			],
		),
		ValidationResultScript.Outcome.EQUIPMENT_ITEM_NOT_DIRECT,
		"one hand instance cannot be authoritative for two characters",
		definitions,
	)
	_assert_restore_failure(
		_snapshot(
			[_item_record(&"weapon:combined_secondary", DEF_COMBINED_FLAGS, _character(CHARACTER_ID))],
			[],
			[EquipmentRecordScript.new(CHARACTER_ID, &"", &"weapon:combined_secondary")],
		),
		ValidationResultScript.Outcome.EQUIPMENT_DEFINITION_MISMATCH,
		"TWO_HANDED plus SECONDARY definition cannot occupy secondary slot",
		definitions,
	)

	var empty_slots: RestoreResultScript = RestorerScript.restore(
		_snapshot(
			[],
			[],
			[EquipmentRecordScript.new(CHARACTER_ID)],
			[ArmorRecordScript.new(CHARACTER_ID)],
		),
		definitions,
	)
	_assert_true(empty_slots.succeeded, "explicit empty Equipment and Armor records are valid")
	_assert_true(empty_slots.reconstructed_state.equipment_state(CHARACTER_ID).are_both_hands_empty(), "empty Equipment record restores empty hands")
	_assert_true(empty_slots.reconstructed_state.armor_state(CHARACTER_ID).occupied_slots().is_empty(), "empty Armor record restores no slots")

	var secondary_only: SnapshotScript = _snapshot(
		[_item_record(&"weapon:secondary", DEF_SECONDARY, _character(CHARACTER_ID))],
		[],
		[EquipmentRecordScript.new(CHARACTER_ID, &"", &"weapon:secondary")],
	)
	var secondary_restore: RestoreResultScript = RestorerScript.restore(secondary_only, definitions)
	_assert_true(secondary_restore.succeeded, "secondary-only structural state restores")
	_assert_true(secondary_restore.reconstructed_state.equipment_state(CHARACTER_ID).is_primary_hand_empty(), "secondary-only does not promote")
	_assert_eq(secondary_restore.reconstructed_state.equipment_state(CHARACTER_ID).secondary_weapon().instance_id, &"weapon:secondary", "secondary exact slot preserved")

	var combined_primary: SnapshotScript = _snapshot(
		[
			_item_record(&"weapon:combined", DEF_COMBINED_FLAGS, _character(CHARACTER_ID)),
			_item_record(&"weapon:secondary_after", DEF_SECONDARY, _character(CHARACTER_ID)),
		],
		[],
		[EquipmentRecordScript.new(
			CHARACTER_ID,
			&"weapon:combined",
			&"weapon:secondary_after",
		)],
	)
	var combined_primary_restore: RestoreResultScript = RestorerScript.restore(
		combined_primary,
		definitions,
	)
	_assert_true(combined_primary_restore.succeeded, "TWO_HANDED plus SECONDARY definition remains valid in primary")
	_assert_eq(combined_primary_restore.reconstructed_state.equipment_state(CHARACTER_ID).primary_weapon().instance_id, &"weapon:combined", "combined-flag primary exact slot preserved")

	## feature/equip.c checks shield only when wielding. Wearing shield after a
	## two-handed weapon is source-reachable and must not be normalized on load.
	var historical: SnapshotScript = _snapshot(
		[
			_item_record(&"weapon:two", DEF_TWO_HANDED, _character(CHARACTER_ID)),
			_item_record(&"armor:shield", DEF_SHIELD, _character(CHARACTER_ID)),
		],
		[],
		[EquipmentRecordScript.new(CHARACTER_ID, &"weapon:two")],
		[ArmorRecordScript.new(CHARACTER_ID, [ArmorSlotRecordScript.new(&"shield", &"armor:shield")])],
	)
	var historical_restore: RestoreResultScript = RestorerScript.restore(historical, definitions)
	_assert_true(historical_restore.succeeded, "two-handed plus later shield restores")
	_assert_eq(historical_restore.reconstructed_state.equipment_state(CHARACTER_ID).primary_weapon().instance_id, &"weapon:two", "two-handed primary preserved")
	_assert_true(historical_restore.reconstructed_state.armor_state(CHARACTER_ID).is_slot_occupied(&"shield"), "shield occupancy preserved without wield gate")

	var current_weapon_definitions: DefinitionProjectionsScript = _definitions(
		4,
		1,
		&"blade",
		true,
		true,
	)
	var current_weapon_restore: RestoreResultScript = RestorerScript.restore(
		_snapshot(
			[_item_record(&"weapon:changed", DEF_PRIMARY, _character(CHARACTER_ID))],
			[],
			[EquipmentRecordScript.new(CHARACTER_ID, &"weapon:changed")],
		),
		current_weapon_definitions,
	)
	_assert_true(current_weapon_restore.succeeded, "compatible current weapon definition change restores")
	var changed_weapon: EquippedWeaponRefScript = current_weapon_restore.reconstructed_state.equipment_state(CHARACTER_ID).primary_weapon()
	_assert_eq(changed_weapon.skill_type, &"blade", "restored weapon skill type comes from current definition")
	_assert_true(changed_weapon.can_wield_as_secondary, "restored weapon SECONDARY fact comes from current definition")
	_assert_true(changed_weapon.is_two_handed, "restored weapon TWO_HANDED fact comes from current definition")


func _test_armor_failures_custom_slots_and_definition_changes() -> void:
	var definitions: DefinitionProjectionsScript = _definitions()
	_assert_restore_failure(
		_snapshot([], [], [], [ArmorRecordScript.new(CHARACTER_ID, [ArmorSlotRecordScript.new(&"boots", &"missing")])]),
		ValidationResultScript.Outcome.MISSING_ARMOR_ITEM,
		"armor missing item rejects",
		definitions,
	)
	_assert_restore_failure(
		_snapshot([
			_item_record(&"bag", DEF_BAG, _character(CHARACTER_ID)),
			_item_record(&"boots", DEF_BOOTS, _item_endpoint(&"bag")),
		], [], [], [ArmorRecordScript.new(CHARACTER_ID, [ArmorSlotRecordScript.new(&"boots", &"boots")])]),
		ValidationResultScript.Outcome.ARMOR_ITEM_NOT_DIRECT,
		"nested armor item rejects",
		definitions,
	)
	_assert_restore_failure(
		_snapshot(
			[_item_record(&"boots:a", DEF_BOOTS, _character(CHARACTER_ID)), _item_record(&"boots:b", DEF_BOOTS, _character(CHARACTER_ID))],
			[], [],
			[ArmorRecordScript.new(CHARACTER_ID, [ArmorSlotRecordScript.new(&"boots", &"boots:a"), ArmorSlotRecordScript.new(&"boots", &"boots:b")])],
		),
		ValidationResultScript.Outcome.DUPLICATE_ARMOR_SLOT,
		"duplicate exact armor slot rejects",
		definitions,
	)
	_assert_restore_failure(
		_snapshot(
			[_item_record(&"boots", DEF_BOOTS, _character(CHARACTER_ID))],
			[], [],
			[ArmorRecordScript.new(CHARACTER_ID, [ArmorSlotRecordScript.new(&"boots", &"boots"), ArmorSlotRecordScript.new(&"feet", &"boots")])],
		),
		ValidationResultScript.Outcome.DUPLICATE_ARMOR_INSTANCE,
		"same armor instance in two slots rejects before repair",
		definitions,
	)
	_assert_restore_failure(
		_snapshot(
			[_item_record(&"boots", DEF_BOOTS, _character(CHARACTER_ID))],
			[], [],
			[ArmorRecordScript.new(CHARACTER_ID, [ArmorSlotRecordScript.new(&"feet", &"boots")])],
		),
		ValidationResultScript.Outcome.ARMOR_SLOT_MISMATCH,
		"saved slot must exactly match current armor definition",
		definitions,
	)
	_assert_restore_failure(
		_snapshot(
			[_item_record(&"plain", DEF_PLAIN, _character(CHARACTER_ID))],
			[], [],
			[ArmorRecordScript.new(CHARACTER_ID, [ArmorSlotRecordScript.new(&"boots", &"plain")])],
		),
		ValidationResultScript.Outcome.ARMOR_DEFINITION_MISMATCH,
		"non-armor definition rejects armor ref",
		definitions,
	)
	_assert_restore_failure(
		_snapshot([], [], [], [ArmorRecordScript.new(&"")]),
		ValidationResultScript.Outcome.MALFORMED_ARMOR_RECORD,
		"empty armor character authority rejects",
		definitions,
	)
	_assert_restore_failure(
		_snapshot(
			[],
			[],
			[],
			[
				ArmorRecordScript.new(CHARACTER_ID),
				ArmorRecordScript.new(CHARACTER_ID),
			],
		),
		ValidationResultScript.Outcome.DUPLICATE_ARMOR_CHARACTER,
		"duplicate Armor authority for one character rejects",
		definitions,
	)
	_assert_restore_failure(
		_snapshot(
			[_item_record(&"armor:shared", DEF_BOOTS, _character(&"character:a"))],
			[],
			[],
			[
				ArmorRecordScript.new(&"character:a", [ArmorSlotRecordScript.new(&"boots", &"armor:shared")]),
				ArmorRecordScript.new(&"character:z", [ArmorSlotRecordScript.new(&"boots", &"armor:shared")]),
			],
		),
		ValidationResultScript.Outcome.DUPLICATE_ARMOR_INSTANCE,
		"one Armor instance cannot be authoritative for two characters",
		definitions,
	)
	_assert_restore_failure(
		_snapshot(
			[_item_record(&"boots", DEF_BOOTS, _character(CHARACTER_ID))],
			[], [],
			[ArmorRecordScript.new(CHARACTER_ID, [ArmorSlotRecordScript.new(&"", &"boots")])],
		),
		ValidationResultScript.Outcome.INVALID_ARMOR_SLOT,
		"empty exact armor slot rejects",
		definitions,
	)
	_assert_restore_failure(
		_snapshot(
			[_item_record(&"hybrid", DEF_HYBRID, _character(CHARACTER_ID))],
			[],
			[EquipmentRecordScript.new(CHARACTER_ID, &"hybrid")],
			[ArmorRecordScript.new(CHARACTER_ID, [ArmorSlotRecordScript.new(&"shield", &"hybrid")])],
		),
		ValidationResultScript.Outcome.HAND_ARMOR_INSTANCE_CONFLICT,
		"same instance cannot be hand and armor authority",
		definitions,
	)

	var custom_slots: SnapshotScript = _snapshot(
		[
			_item_record(&"armor:boots", DEF_BOOTS, _character(CHARACTER_ID)),
			_item_record(&"armor:feet", DEF_FEET, _character(CHARACTER_ID)),
			_item_record(&"armor:bandage", DEF_BANDAGE, _character(CHARACTER_ID)),
			_item_record(&"armor:custom", DEF_CUSTOM_ARMOR, _character(CHARACTER_ID)),
		], [], [],
		[ArmorRecordScript.new(CHARACTER_ID, [
			ArmorSlotRecordScript.new(&"bandage", &"armor:bandage"),
			ArmorSlotRecordScript.new(&"feet", &"armor:feet"),
			ArmorSlotRecordScript.new(&"boots", &"armor:boots"),
			ArmorSlotRecordScript.new(&"custom:tail", &"armor:custom"),
		])],
	)
	var custom_restore: RestoreResultScript = RestorerScript.restore(custom_slots, definitions)
	_assert_true(custom_restore.succeeded, "open custom armor slots restore")
	_assert_eq(custom_restore.reconstructed_state.armor_state(CHARACTER_ID).occupied_slots(), [&"bandage", &"boots", &"custom:tail", &"feet"], "exact open slots remain sorted and distinct")
	_assert_eq(custom_restore.reconstructed_state.armor_state(CHARACTER_ID).item_instance_id_in_slot(&"custom:tail"), &"armor:custom", "arbitrary non-empty Armor slot round-trips exactly")
	_assert_eq(custom_restore.reconstructed_state.armor_state(CHARACTER_ID).aggregate_numeric_modifiers().armor, 7, "boots and feet modifiers both contribute")
	_assert_eq(custom_restore.reconstructed_state.armor_state(CHARACTER_ID).aggregate_numeric_modifiers().attack, -10, "bandage current definition modifier contributes")

	## Schema v1 stores only the slot/ref. Current immutable content rebuilds the
	## EquippedArmorRef modifier snapshot, while saved own weight remains exact.
	var modifier_snapshot: SnapshotScript = _snapshot(
		[_item_record(&"armor:changed", DEF_BOOTS, _character(CHARACTER_ID), 123)],
		[], [],
		[ArmorRecordScript.new(CHARACTER_ID, [ArmorSlotRecordScript.new(&"boots", &"armor:changed")])],
	)
	var changed_definitions: DefinitionProjectionsScript = _definitions(99, 1)
	var changed_restore: RestoreResultScript = RestorerScript.restore(modifier_snapshot, changed_definitions)
	_assert_true(changed_restore.succeeded, "compatible changed definition restores")
	_assert_eq(changed_restore.reconstructed_state.armor_state(CHARACTER_ID).aggregate_numeric_modifiers().armor, 99, "current armor modifier projection wins")
	_assert_eq(changed_restore.reconstructed_state.inventory.own_weight(&"armor:changed"), 123, "definition change does not rewrite saved own weight")


func _test_all_or_nothing_independence_and_capture_boundaries() -> void:
	var definitions: DefinitionProjectionsScript = _definitions()
	var over_capacity: SnapshotScript = _snapshot([
		_item_record(&"heavy:a", DEF_PLAIN, _character(CHARACTER_ID), 2_000_000_000),
		_item_record(&"heavy:b", DEF_PLAIN, _character(CHARACTER_ID), 2_000_000_000),
	])
	var over_restore: RestoreResultScript = RestorerScript.restore(over_capacity, definitions)
	_assert_true(over_restore.succeeded, "structurally valid over-capacity-style state restores")
	_assert_eq(over_restore.reconstructed_state.inventory.contents_weight(_character(CHARACTER_ID)), 4_000_000_000, "restore does not apply gameplay capacity gate")

	var valid: SnapshotScript = _snapshot([
		_item_record(&"item:independent", DEF_PLAIN, _character(CHARACTER_ID), 10),
	])
	var first: RestoreResultScript = RestorerScript.restore(valid, definitions)
	var second: RestoreResultScript = RestorerScript.restore(valid, definitions)
	_assert_true(first.succeeded and second.succeeded, "same snapshot restores into two fresh bundles")
	first.reconstructed_state.inventory.update_own_weight(&"item:independent", 999)
	_assert_eq(second.reconstructed_state.inventory.own_weight(&"item:independent"), 10, "fresh Inventory states do not share mutation")
	var returned_item: ItemInstanceScript = first.reconstructed_state.item_instance(&"item:independent")
	returned_item._item_definition_id = &"mutated"
	_assert_eq(first.reconstructed_state.item_instance(&"item:independent").item_definition_id, DEF_PLAIN, "bundle item getter is defensive")

	var corrupt: SnapshotScript = _snapshot([
		_item_record(&"item:a", DEF_PLAIN, _item_endpoint(&"item:b")),
		_item_record(&"item:b", DEF_PLAIN, _item_endpoint(&"item:a")),
	])
	var failed: RestoreResultScript = RestorerScript.restore(corrupt, definitions)
	_assert_false(failed.succeeded, "corrupt restore fails")
	_assert_eq(failed.reconstructed_state, null, "failure exposes no partial reconstructed aggregate")

	var inventory: InventoryStateScript = InventoryStateScript.new()
	var stacks: StackCollectionScript = StackCollectionScript.new()
	var represented: ItemInstanceScript = _item(&"item:represented", DEF_PLAIN)
	var omitted: ItemInstanceScript = _item(&"item:omitted", DEF_PLAIN)
	inventory.register_item(represented, 1)
	inventory.register_item(omitted, 2)
	var missing_capture: CaptureResultScript = CaptureScript.capture(
		[represented], inventory, stacks, [], [], definitions
	)
	_assert_false(missing_capture.succeeded, "capture refuses live inventory item absent from explicit item collection")
	_assert_eq(missing_capture.validation_result.outcome, ValidationResultScript.Outcome.UNREPRESENTED_REGISTERED_ITEM, "capture missing-item failure is typed")
	_assert_eq(missing_capture.snapshot, null, "failed capture exposes no snapshot")

	var unrelated_inventory: InventoryStateScript = InventoryStateScript.new()
	var unregistered_capture: CaptureResultScript = CaptureScript.capture(
		[represented], unrelated_inventory, stacks, [], [], definitions
	)
	_assert_eq(unregistered_capture.validation_result.outcome, ValidationResultScript.Outcome.ITEM_INSTANCE_NOT_REGISTERED, "capture rejects supplied non-live item")

	var duplicate_inventory: InventoryStateScript = InventoryStateScript.new()
	duplicate_inventory.register_item(represented, 1)
	var duplicate_item_capture: CaptureResultScript = CaptureScript.capture(
		[represented, represented],
		duplicate_inventory,
		StackCollectionScript.new(),
		[],
		[],
		definitions,
	)
	_assert_eq(duplicate_item_capture.validation_result.outcome, ValidationResultScript.Outcome.DUPLICATE_ITEM_INSTANCE_ID, "capture rejects duplicate explicit ItemInstance identity")

	var incomplete_stack_inventory: InventoryStateScript = InventoryStateScript.new()
	var incomplete_stack_item: ItemInstanceScript = _item(&"stack:incomplete", DEF_STACK)
	incomplete_stack_inventory.register_item(incomplete_stack_item, 41)
	var incomplete_stack_capture: CaptureResultScript = CaptureScript.capture(
		[incomplete_stack_item],
		incomplete_stack_inventory,
		StackCollectionScript.new(),
		[],
		[],
		definitions,
	)
	_assert_eq(incomplete_stack_capture.validation_result.outcome, ValidationResultScript.Outcome.MISSING_STACK_STATE, "capture cannot omit amount authority for stack-capable item")
	_assert_eq(incomplete_stack_capture.snapshot, null, "incomplete stack capture emits no snapshot")

	var empty_inventory: InventoryStateScript = InventoryStateScript.new()
	var duplicate_equipment_capture: CaptureResultScript = CaptureScript.capture(
		[],
		empty_inventory,
		StackCollectionScript.new(),
		[
			EquipmentSourceScript.new(CHARACTER_ID, EquipmentStateScript.new()),
			EquipmentSourceScript.new(CHARACTER_ID, EquipmentStateScript.new()),
		],
		[],
		definitions,
	)
	_assert_eq(duplicate_equipment_capture.validation_result.outcome, ValidationResultScript.Outcome.DUPLICATE_EQUIPMENT_CHARACTER, "capture rejects duplicate Equipment source character")
	var duplicate_armor_capture: CaptureResultScript = CaptureScript.capture(
		[],
		empty_inventory,
		StackCollectionScript.new(),
		[],
		[
			ArmorSourceScript.new(CHARACTER_ID, ArmorStateScript.new()),
			ArmorSourceScript.new(CHARACTER_ID, ArmorStateScript.new()),
		],
		definitions,
	)
	_assert_eq(duplicate_armor_capture.validation_result.outcome, ValidationResultScript.Outcome.DUPLICATE_ARMOR_CHARACTER, "capture rejects duplicate Armor source character")

	var unknown_inventory: InventoryStateScript = InventoryStateScript.new()
	var unknown_item: ItemInstanceScript = _item(&"item:unknown_definition", &"definition:missing")
	unknown_inventory.register_item(unknown_item, 0)
	var unknown_capture: CaptureResultScript = CaptureScript.capture(
		[unknown_item],
		unknown_inventory,
		StackCollectionScript.new(),
		[],
		[],
		definitions,
	)
	_assert_eq(unknown_capture.validation_result.outcome, ValidationResultScript.Outcome.UNKNOWN_ITEM_DEFINITION, "capture requires explicit definition projection for every ItemInstance")

	var mismatched_inventory: InventoryStateScript = InventoryStateScript.new()
	var plain_item: ItemInstanceScript = _item(&"item:mismatched_ref", DEF_PLAIN)
	mismatched_inventory.register_item(plain_item, 1)
	_place(mismatched_inventory, plain_item.item_instance_id, _character(CHARACTER_ID))
	var mismatched_equipment: EquipmentStateScript = EquipmentStateScript.new()
	mismatched_equipment._restore_weapons(
		EquippedWeaponRefScript.new(
			plain_item.item_instance_id,
			definitions.weapon_definition(DEF_PRIMARY),
		),
		null,
	)
	var mismatched_capture: CaptureResultScript = CaptureScript.capture(
		[plain_item],
		mismatched_inventory,
		StackCollectionScript.new(),
		[EquipmentSourceScript.new(CHARACTER_ID, mismatched_equipment)],
		[],
		definitions,
	)
	_assert_eq(mismatched_capture.validation_result.outcome, ValidationResultScript.Outcome.EQUIPMENT_DEFINITION_MISMATCH, "capture never normalizes mismatched live equipment identity")


func _definitions(
	boots_armor: int = 4,
	stack_base_weight: int = 1,
	primary_skill_type: StringName = &"sword",
	primary_can_secondary: bool = false,
	primary_two_handed: bool = false,
) -> DefinitionProjectionsScript:
	var item_definitions: Array[ItemDefinition] = []
	for definition_id: StringName in [
		DEF_PLAIN,
		DEF_BAG,
		DEF_PRIMARY,
		DEF_SECONDARY,
		DEF_TWO_HANDED,
		DEF_COMBINED_FLAGS,
		DEF_BOOTS,
		DEF_FEET,
		DEF_BANDAGE,
		DEF_SHIELD,
		DEF_CUSTOM_ARMOR,
		DEF_STACK,
		DEF_HYBRID,
	]:
		item_definitions.append(ItemDefinitionScript.new(definition_id))
	return DefinitionProjectionsScript.new(
		item_definitions,
		[
			WeaponDefinitionScript.new(
				DEF_PRIMARY,
				primary_skill_type,
				primary_can_secondary,
				primary_two_handed,
			),
			WeaponDefinitionScript.new(DEF_SECONDARY, &"dagger", true, false),
			WeaponDefinitionScript.new(DEF_TWO_HANDED, &"staff", false, true),
			WeaponDefinitionScript.new(DEF_COMBINED_FLAGS, &"axe", true, true),
			WeaponDefinitionScript.new(DEF_HYBRID, &"sword", false, false),
		],
		[
			ArmorDefinitionScript.new(DEF_BOOTS, &"boots", ArmorModifiersScript.new(boots_armor)),
			ArmorDefinitionScript.new(DEF_FEET, &"feet", ArmorModifiersScript.new(3)),
			ArmorDefinitionScript.new(DEF_BANDAGE, &"bandage", ArmorModifiersScript.new(0, 0, -10)),
			ArmorDefinitionScript.new(DEF_SHIELD, &"shield", ArmorModifiersScript.new(2)),
			ArmorDefinitionScript.new(DEF_CUSTOM_ARMOR, &"custom:tail"),
			ArmorDefinitionScript.new(DEF_HYBRID, &"shield", ArmorModifiersScript.new(1)),
		],
		[
			StackDefinitionScript.new(DEF_STACK, &"legacy:/obj/money/coin", stack_base_weight),
		],
	)


func _snapshot(
	items: Array[NativeItemRecord] = [],
	stacks: Array[NativeCombinedStackRecord] = [],
	equipment: Array[NativeCharacterEquipmentRecord] = [],
	armor: Array[NativeCharacterArmorRecord] = [],
	schema_version: int = SnapshotScript.CURRENT_SCHEMA_VERSION,
) -> SnapshotScript:
	return SnapshotScript.new(schema_version, items, stacks, equipment, armor)


func _item_record(
	instance_id: StringName,
	definition_id: StringName,
	parent: EndpointScript = null,
	own_weight: int = 0,
) -> ItemRecordScript:
	return ItemRecordScript.new(instance_id, definition_id, own_weight, parent)


func _item(instance_id: StringName, definition_id: StringName) -> ItemInstanceScript:
	return ItemInstanceScript.new(instance_id, definition_id)


func _record(snapshot: SnapshotScript, instance_id: StringName) -> ItemRecordScript:
	for record: NativeItemRecord in snapshot.item_records:
		if record.item_instance_id == instance_id:
			return record
	return null


func _snapshot_facts(snapshot: SnapshotScript) -> Array[String]:
	var facts: Array[String] = ["schema|%d" % snapshot.schema_version]
	for record: NativeItemRecord in snapshot.item_records:
		var parent: EndpointScript = record.direct_parent
		facts.append("item|%s|%s|%d|%d|%s" % [
			String(record.item_instance_id),
			String(record.item_definition_id),
			record.own_weight,
			-1 if parent == null else parent.kind,
			"" if parent == null else String(parent.endpoint_id),
		])
	for record: NativeCombinedStackRecord in snapshot.combined_stack_records:
		facts.append("stack|%s|%d" % [String(record.item_instance_id), record.amount])
	for record: NativeCharacterEquipmentRecord in snapshot.character_equipment_records:
		facts.append("equipment|%s|%s|%s" % [
			String(record.character_id),
			String(record.primary_item_instance_id),
			String(record.secondary_item_instance_id),
		])
	for record: NativeCharacterArmorRecord in snapshot.character_armor_records:
		facts.append("armor|%s" % String(record.character_id))
		for slot: NativeArmorSlotRecord in record.slots:
			facts.append("slot|%s|%s" % [
				String(slot.armor_type),
				String(slot.item_instance_id),
			])
	return facts


func _place(
	inventory: InventoryStateScript,
	instance_id: StringName,
	parent: EndpointScript,
) -> void:
	_assert_true(inventory._apply_reparent(instance_id, parent), "fixture parent applies")


func _character(character_id: StringName) -> EndpointScript:
	return EndpointScript.new(EndpointScript.Kind.CHARACTER, character_id)


func _item_endpoint(item_instance_id: StringName) -> EndpointScript:
	return EndpointScript.new(EndpointScript.Kind.ITEM, item_instance_id)


func _world(world_id: StringName) -> EndpointScript:
	return EndpointScript.new(EndpointScript.Kind.WORLD, world_id)


func _item_record_ids(records: Array[NativeItemRecord]) -> Array[StringName]:
	var result: Array[StringName] = []
	for record: NativeItemRecord in records:
		result.append(record.item_instance_id)
	return result


func _stack_record_ids(records: Array[NativeCombinedStackRecord]) -> Array[StringName]:
	var result: Array[StringName] = []
	for record: NativeCombinedStackRecord in records:
		result.append(record.item_instance_id)
	return result


func _equipment_character_ids(
	records: Array[NativeCharacterEquipmentRecord],
) -> Array[StringName]:
	var result: Array[StringName] = []
	for record: NativeCharacterEquipmentRecord in records:
		result.append(record.character_id)
	return result


func _armor_character_ids(
	records: Array[NativeCharacterArmorRecord],
) -> Array[StringName]:
	var result: Array[StringName] = []
	for record: NativeCharacterArmorRecord in records:
		result.append(record.character_id)
	return result


func _assert_restore_failure(
	snapshot: SnapshotScript,
	expected_outcome: int,
	label: String,
	definitions: DefinitionProjectionsScript,
) -> void:
	var validation: ValidationResultScript = ValidatorScript.validate(snapshot, definitions)
	_assert_eq(validation.outcome, expected_outcome, label + " validator outcome")
	var result: RestoreResultScript = RestorerScript.restore(snapshot, definitions)
	_assert_false(result.succeeded, label + " restore fails")
	_assert_eq(result.validation_result.outcome, expected_outcome, label + " restore outcome")
	_assert_eq(result.reconstructed_state, null, label + " has no partial bundle")


func _has_property(value: Object, property_name: StringName) -> bool:
	for property: Dictionary in value.get_property_list():
		if StringName(property["name"]) == property_name:
			return true
	return false


func _assert_true(condition: bool, label: String) -> void:
	_assertion_count += 1
	if not condition:
		_failures.append(label + ": expected true")


func _assert_false(condition: bool, label: String) -> void:
	_assertion_count += 1
	if condition:
		_failures.append(label + ": expected false")


func _assert_eq(actual: Variant, expected: Variant, label: String) -> void:
	_assertion_count += 1
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])
