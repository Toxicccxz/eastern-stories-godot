extends RefCounted

const ItemDefinitionScript := preload("res://core/items/item_definition.gd")
const ItemInstanceScript := preload("res://core/items/item_instance.gd")
const EndpointScript := preload("res://core/inventory/containment_endpoint.gd")
const DestinationScript := preload(
	"res://core/inventory/inventory_transfer_destination.gd"
)
const InventoryStateScript := preload("res://core/inventory/inventory_state.gd")
const WeaponDefinitionScript := preload(
	"res://core/equipment/weapon_definition.gd"
)
const EquippedWeaponRefScript := preload(
	"res://core/equipment/equipped_weapon_ref.gd"
)
const EquipmentStateScript := preload("res://core/equipment/equipment_state.gd")
const ArmorModifiersScript := preload(
	"res://core/armor/armor_numeric_modifiers.gd"
)
const ArmorDefinitionScript := preload("res://core/armor/armor_definition.gd")
const EquippedArmorRefScript := preload(
	"res://core/armor/equipped_armor_ref.gd"
)
const ArmorStateScript := preload("res://core/armor/armor_state.gd")
const StackDefinitionScript := preload(
	"res://core/items/combined/combined_stack_definition.gd"
)
const StackCollectionScript := preload(
	"res://core/items/combined/combined_stack_collection.gd"
)
const StackStateScript := preload(
	"res://core/items/combined/combined_stack_state.gd"
)
const StackAmountResultScript := preload(
	"res://core/items/combined/combined_stack_amount_result.gd"
)
const StackMergeResultScript := preload(
	"res://core/items/combined/combined_stack_merge_result.gd"
)
const StackServiceScript := preload(
	"res://core/items/combined/combined_stack_service.gd"
)
const OwnerContextScript := preload(
	"res://core/items/lifecycle/item_lifecycle_owner_context.gd"
)
const LifecycleResultScript := preload(
	"res://core/items/lifecycle/item_lifecycle_result.gd"
)
const LifecycleServiceScript := preload(
	"res://core/items/lifecycle/item_lifecycle_service.gd"
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
const CaptureScript := preload(
	"res://core/persistence/native_item_state_capture.gd"
)
const CaptureResultScript := preload(
	"res://core/persistence/native_item_snapshot_capture_result.gd"
)
const ValidationResultScript := preload(
	"res://core/persistence/native_item_state_validation_result.gd"
)
const FailingEquipmentStateScript := preload(
	"res://tests/support/failing_lifecycle_equipment_state.gd"
)
const FailingArmorStateScript := preload(
	"res://tests/support/failing_lifecycle_armor_state.gd"
)

const CHARACTER_ID: StringName = &"character:lifecycle"
const OTHER_CHARACTER_ID: StringName = &"character:other"
const DEF_PLAIN: StringName = &"item:lifecycle_plain"
const DEF_BAG: StringName = &"item:lifecycle_bag"
const DEF_STACK: StringName = &"item:lifecycle_stack"
const DEF_WEAPON: StringName = &"item:lifecycle_weapon"
const DEF_SECONDARY: StringName = &"item:lifecycle_secondary"
const DEF_ARMOR: StringName = &"item:lifecycle_armor"
const DEF_HYBRID: StringName = &"item:lifecycle_hybrid"

var _assertion_count: int = 0
var _failures: Array[String] = []


func run_all() -> Dictionary[String, Variant]:
	_test_invalid_identity_owner_context_and_repeat()
	_test_leaf_locations_and_weight()
	_test_equipment_armor_and_defensive_cleanup()
	_test_leaf_guard_subtree_order_and_siblings()
	_test_stack_and_zero_intent_cleanup()
	_test_merge_lifecycle_integration()
	_test_multi_sibling_merge_failure_preserves_quantity()
	_test_persistence_interaction_and_stale_identity()
	return {
		"assertions": _assertion_count,
		"failures": _failures.duplicate(),
	}


func _test_invalid_identity_owner_context_and_repeat() -> void:
	var inventory: InventoryStateScript = InventoryStateScript.new()
	var stacks: StackCollectionScript = StackCollectionScript.new()
	var invalid_id: LifecycleResultScript = LifecycleServiceScript.destroy_item(
		inventory,
		stacks,
		&"",
	)
	_assert_eq(invalid_id.outcome, LifecycleResultScript.Outcome.INVALID_ITEM_ID, "empty lifecycle ID rejects")
	_assert_eq(inventory.registered_item_ids(), [], "empty ID causes no mutation")
	var unknown: LifecycleResultScript = LifecycleServiceScript.destroy_item(
		inventory,
		stacks,
		&"item:unknown",
	)
	_assert_eq(unknown.outcome, LifecycleResultScript.Outcome.ITEM_NOT_LIVE, "unknown lifecycle ID rejects")

	var direct: ItemInstanceScript = _register(
		inventory,
		&"item:direct",
		DEF_PLAIN,
		4,
	)
	_place(inventory, direct.item_instance_id, _character(CHARACTER_ID))
	var missing_owner: LifecycleResultScript = LifecycleServiceScript.destroy_item(
		inventory,
		stacks,
		direct.item_instance_id,
	)
	_assert_eq(missing_owner.outcome, LifecycleResultScript.Outcome.OWNER_CONTEXT_REQUIRED, "direct character item requires scoped owner context")
	_assert_true(inventory.is_registered(direct.item_instance_id), "missing context preserves live item")
	var incomplete_equipment: LifecycleResultScript = LifecycleServiceScript.destroy_item(
		inventory,
		stacks,
		direct.item_instance_id,
		LifecycleResultScript.ChildDisposition.REQUIRE_LEAF,
		OwnerContextScript.new(
			CHARACTER_ID,
			EquipmentStateScript.new(),
			null,
		),
	)
	_assert_eq(incomplete_equipment.outcome, LifecycleResultScript.Outcome.OWNER_CONTEXT_INCOMPLETE, "missing Armor authority rejects")
	_assert_true(inventory.is_registered(direct.item_instance_id), "incomplete Equipment-only context preserves item")
	var incomplete_armor: LifecycleResultScript = LifecycleServiceScript.destroy_item(
		inventory,
		stacks,
		direct.item_instance_id,
		LifecycleResultScript.ChildDisposition.REQUIRE_LEAF,
		OwnerContextScript.new(
			CHARACTER_ID,
			null,
			ArmorStateScript.new(),
		),
	)
	_assert_eq(incomplete_armor.outcome, LifecycleResultScript.Outcome.OWNER_CONTEXT_INCOMPLETE, "missing Equipment authority rejects")
	_assert_true(inventory.is_registered(direct.item_instance_id), "incomplete Armor-only context preserves item")
	var empty_owner_id: LifecycleResultScript = LifecycleServiceScript.destroy_item(
		inventory,
		stacks,
		direct.item_instance_id,
		LifecycleResultScript.ChildDisposition.REQUIRE_LEAF,
		OwnerContextScript.new(
			&"",
			EquipmentStateScript.new(),
			ArmorStateScript.new(),
		),
	)
	_assert_eq(empty_owner_id.outcome, LifecycleResultScript.Outcome.OWNER_CONTEXT_INCOMPLETE, "empty owner identity rejects as incomplete")
	_assert_true(inventory.is_registered(direct.item_instance_id), "empty owner identity causes no mutation")
	var wrong_owner: LifecycleResultScript = LifecycleServiceScript.destroy_item(
		inventory,
		stacks,
		direct.item_instance_id,
		LifecycleResultScript.ChildDisposition.REQUIRE_LEAF,
		_context(OTHER_CHARACTER_ID),
	)
	_assert_eq(wrong_owner.outcome, LifecycleResultScript.Outcome.OWNER_CONTEXT_MISMATCH, "wrong character context rejects")
	_assert_true(inventory.is_registered(direct.item_instance_id), "owner mismatch causes no mutation")
	var removed: LifecycleResultScript = LifecycleServiceScript.destroy_item(
		inventory,
		stacks,
		direct.item_instance_id,
		LifecycleResultScript.ChildDisposition.REQUIRE_LEAF,
		_context(CHARACTER_ID),
	)
	_assert_true(removed.succeeded, "direct item removes with matching context")
	var repeated: LifecycleResultScript = LifecycleServiceScript.destroy_item(
		inventory,
		stacks,
		direct.item_instance_id,
	)
	_assert_eq(repeated.outcome, LifecycleResultScript.Outcome.ITEM_NOT_LIVE, "already removed ID is not silently idempotent")
	_assert_eq(repeated.removed_instance_ids, [], "repeated destruction reports no removal")


func _test_leaf_locations_and_weight() -> void:
	var inventory: InventoryStateScript = InventoryStateScript.new()
	var stacks: StackCollectionScript = StackCollectionScript.new()
	var unparented: ItemInstanceScript = _register(
		inventory,
		&"item:unparented",
		DEF_PLAIN,
		-7,
	)
	var unparented_result: LifecycleResultScript = LifecycleServiceScript.destroy_item(
		inventory,
		stacks,
		unparented.item_instance_id,
		LifecycleResultScript.ChildDisposition.REQUIRE_LEAF,
		_context(OTHER_CHARACTER_ID),
	)
	_assert_true(unparented_result.succeeded, "live unparented leaf destroys")
	_assert_eq(unparented_result.previous_parent, null, "unparented result has no previous parent")
	_assert_eq(unparented_result.previous_root, null, "unparented result has no previous root")
	_assert_eq(unparented_result.removed_instance_ids, [&"item:unparented"], "unparented removed IDs exact")
	_assert_false(inventory.is_registered(unparented.item_instance_id), "unparented registration is removed")
	_assert_eq(inventory.direct_parent(unparented.item_instance_id), null, "removed unparented item has no current parent")
	_assert_eq(inventory.root_holder(unparented.item_instance_id), null, "removed unparented item has no current root")

	var world_item: ItemInstanceScript = _register(
		inventory,
		&"item:world",
		DEF_PLAIN,
		9,
	)
	_place(inventory, world_item.item_instance_id, _world(&"world:logical"))
	var stray_equipment: EquipmentStateScript = EquipmentStateScript.new()
	stray_equipment._restore_weapons(
		_weapon_ref(world_item.item_instance_id, DEF_WEAPON),
		null,
	)
	var world_result: LifecycleResultScript = LifecycleServiceScript.destroy_item(
		inventory,
		stacks,
		world_item.item_instance_id,
		LifecycleResultScript.ChildDisposition.REQUIRE_LEAF,
		_context(CHARACTER_ID, stray_equipment),
	)
	_assert_true(world_result.succeeded, "WORLD-parented item destroys without World runtime")
	_assert_eq(world_result.previous_parent.endpoint_id, &"world:logical", "logical WORLD parent reported")
	_assert_false(inventory.is_registered(world_item.item_instance_id), "WORLD item registration disappears")
	_assert_eq(inventory.direct_parent(world_item.item_instance_id), null, "WORLD logical parent disappears")
	_assert_false(world_result.weapon_detached, "WORLD item never consults character equipment")
	_assert_true(stray_equipment.has_weapon_instance(world_item.item_instance_id), "irrelevant owner context remains untouched")

	var bag: ItemInstanceScript = _register(inventory, &"bag:leaf_parent", DEF_BAG, 10)
	var leaf: ItemInstanceScript = _register(inventory, &"item:nested_leaf", DEF_PLAIN, 3)
	_place(inventory, bag.item_instance_id, _character(CHARACTER_ID))
	_place(inventory, leaf.item_instance_id, _item_endpoint(bag.item_instance_id))
	_assert_eq(inventory.contents_weight(_character(CHARACTER_ID)), 13, "nested leaf fixture load is 13")
	var nested_result: LifecycleResultScript = LifecycleServiceScript.destroy_item(
		inventory,
		stacks,
		leaf.item_instance_id,
		LifecycleResultScript.ChildDisposition.REQUIRE_LEAF,
		_context(OTHER_CHARACTER_ID),
	)
	_assert_true(nested_result.succeeded, "ITEM-parented leaf destroys")
	_assert_true(inventory.is_registered(bag.item_instance_id), "parent bag remains live")
	_assert_false(inventory.is_registered(leaf.item_instance_id), "nested leaf registration removed")
	_assert_eq(inventory.ancestry(leaf.item_instance_id), [], "removed nested leaf has no ancestry")
	_assert_eq(inventory.contents_weight(_character(CHARACTER_ID)), 10, "root load loses leaf weight exactly once")
	_assert_eq(inventory.direct_children(_item_endpoint(bag.item_instance_id)), [], "bag has no stale child relation")

	var ordinary: ItemInstanceScript = _register(inventory, &"item:ordinary", DEF_PLAIN, 6)
	_place(inventory, ordinary.item_instance_id, _character(CHARACTER_ID))
	var ordinary_before: int = inventory.contents_weight(_character(CHARACTER_ID))
	var ordinary_result: LifecycleResultScript = LifecycleServiceScript.destroy_item(
		inventory,
		stacks,
		ordinary.item_instance_id,
		LifecycleResultScript.ChildDisposition.REQUIRE_LEAF,
		_context(CHARACTER_ID),
	)
	_assert_true(ordinary_result.succeeded, "character direct unequipped item destroys")
	_assert_eq(inventory.contents_weight(_character(CHARACTER_ID)), ordinary_before - 6, "direct load loses exact own weight")
	_assert_false(ordinary_result.weapon_detached, "ordinary item reports no weapon detach")
	_assert_false(ordinary_result.armor_detached, "ordinary item reports no Armor detach")


func _test_equipment_armor_and_defensive_cleanup() -> void:
	var inventory: InventoryStateScript = InventoryStateScript.new()
	var stacks: StackCollectionScript = StackCollectionScript.new()
	var primary: ItemInstanceScript = _register(inventory, &"weapon:primary", DEF_WEAPON, 5)
	_place(inventory, primary.item_instance_id, _character(CHARACTER_ID))
	var primary_equipment: EquipmentStateScript = EquipmentStateScript.new()
	primary_equipment._restore_weapons(
		_weapon_ref(primary.item_instance_id, DEF_WEAPON),
		null,
	)
	var primary_result: LifecycleResultScript = LifecycleServiceScript.destroy_item(
		inventory,
		stacks,
		primary.item_instance_id,
		LifecycleResultScript.ChildDisposition.REQUIRE_LEAF,
		_context(CHARACTER_ID, primary_equipment),
	)
	_assert_true(primary_result.weapon_detached, "destroying primary reports exact hand detach")
	_assert_true(primary_equipment.are_both_hands_empty(), "destroying primary clears hand authority")

	var retained_primary: ItemInstanceScript = _register(inventory, &"weapon:retained", DEF_WEAPON, 5)
	var secondary: ItemInstanceScript = _register(inventory, &"weapon:secondary", DEF_SECONDARY, 2)
	_place(inventory, retained_primary.item_instance_id, _character(CHARACTER_ID))
	_place(inventory, secondary.item_instance_id, _character(CHARACTER_ID))
	var secondary_equipment: EquipmentStateScript = EquipmentStateScript.new()
	secondary_equipment._restore_weapons(
		_weapon_ref(retained_primary.item_instance_id, DEF_WEAPON),
		_weapon_ref(secondary.item_instance_id, DEF_SECONDARY, true),
	)
	var secondary_result: LifecycleResultScript = LifecycleServiceScript.destroy_item(
		inventory,
		stacks,
		secondary.item_instance_id,
		LifecycleResultScript.ChildDisposition.REQUIRE_LEAF,
		_context(CHARACTER_ID, secondary_equipment),
	)
	_assert_true(secondary_result.weapon_detached, "destroying secondary reports detach")
	_assert_eq(secondary_equipment.primary_weapon().instance_id, retained_primary.item_instance_id, "secondary removal does not promote or replace primary")
	_assert_true(secondary_equipment.is_secondary_hand_empty(), "secondary slot clears exactly")

	var armor_item: ItemInstanceScript = _register(inventory, &"armor:worn", DEF_ARMOR, 4)
	_place(inventory, armor_item.item_instance_id, _character(CHARACTER_ID))
	var armor: ArmorStateScript = ArmorStateScript.new()
	armor._restore_equipped_refs([
		EquippedArmorRefScript.new(armor_item.item_instance_id, _armor_definition()),
	])
	_assert_eq(armor.aggregate_numeric_modifiers().armor, 4, "Armor fixture contributes modifier")
	var armor_result: LifecycleResultScript = LifecycleServiceScript.destroy_item(
		inventory,
		stacks,
		armor_item.item_instance_id,
		LifecycleResultScript.ChildDisposition.REQUIRE_LEAF,
		_context(CHARACTER_ID, null, armor),
	)
	_assert_true(armor_result.armor_detached, "destroying worn item reports Armor detach")
	_assert_true(armor.occupied_slots().is_empty(), "destroying worn item clears exact Armor slot")
	_assert_eq(armor.aggregate_numeric_modifiers().armor, 0, "Armor aggregate contribution disappears")

	var hybrid: ItemInstanceScript = _register(inventory, &"item:hybrid", DEF_HYBRID, 1)
	_place(inventory, hybrid.item_instance_id, _character(CHARACTER_ID))
	var malformed_equipment: EquipmentStateScript = EquipmentStateScript.new()
	malformed_equipment._restore_weapons(
		_weapon_ref(hybrid.item_instance_id, DEF_HYBRID),
		null,
	)
	var malformed_armor: ArmorStateScript = ArmorStateScript.new()
	malformed_armor._restore_equipped_refs([
		EquippedArmorRefScript.new(hybrid.item_instance_id, _armor_definition(DEF_HYBRID)),
	])
	var malformed_result: LifecycleResultScript = LifecycleServiceScript.destroy_item(
		inventory,
		stacks,
		hybrid.item_instance_id,
		LifecycleResultScript.ChildDisposition.REQUIRE_LEAF,
		_context(CHARACTER_ID, malformed_equipment, malformed_armor),
	)
	_assert_true(malformed_result.weapon_detached, "malformed hand plus Armor cleans hand first")
	_assert_true(malformed_result.armor_detached, "malformed hand plus Armor also cleans Armor")
	_assert_true(malformed_equipment.are_both_hands_empty(), "malformed hand ref removed")
	_assert_true(malformed_armor.occupied_slots().is_empty(), "malformed Armor ref removed")

	var failing_item: ItemInstanceScript = _register(inventory, &"item:detach_failure", DEF_PLAIN, 2)
	_place(inventory, failing_item.item_instance_id, _character(CHARACTER_ID))
	var failing_equipment: EquipmentStateScript = FailingEquipmentStateScript.new(
		failing_item.item_instance_id
	)
	var failure_result: LifecycleResultScript = LifecycleServiceScript.destroy_item(
		inventory,
		stacks,
		failing_item.item_instance_id,
		LifecycleResultScript.ChildDisposition.REQUIRE_LEAF,
		_context(CHARACTER_ID, failing_equipment),
	)
	_assert_eq(failure_result.outcome, LifecycleResultScript.Outcome.EQUIPMENT_DETACH_FAILED, "unexpected detach failure is typed")
	_assert_true(inventory.is_registered(failing_item.item_instance_id), "detach failure preserves liveness instead of creating dangling authority")
	_assert_eq(failure_result.removed_instance_ids, [], "detach failure reports no structural removal")

	var partial_item: ItemInstanceScript = _register(
		inventory,
		&"stack:partial_detach_failure",
		DEF_STACK,
		0,
	)
	_register_stack(inventory, stacks, partial_item, 4)
	_place(inventory, partial_item.item_instance_id, _character(CHARACTER_ID))
	var partial_equipment: EquipmentStateScript = EquipmentStateScript.new()
	partial_equipment._restore_weapons(
		_weapon_ref(partial_item.item_instance_id, DEF_STACK),
		null,
	)
	var failing_armor: ArmorStateScript = FailingArmorStateScript.new(
		partial_item.item_instance_id
	)
	var partial_result: LifecycleResultScript = LifecycleServiceScript.destroy_item(
		inventory,
		stacks,
		partial_item.item_instance_id,
		LifecycleResultScript.ChildDisposition.REQUIRE_LEAF,
		_context(CHARACTER_ID, partial_equipment, failing_armor),
	)
	_assert_eq(partial_result.outcome, LifecycleResultScript.Outcome.ARMOR_DETACH_FAILED, "Armor failure after hand cleanup is typed")
	_assert_true(partial_result.weapon_detached, "partial failure reports completed hand detach")
	_assert_false(partial_result.armor_detached, "partial failure does not claim Armor detach")
	_assert_eq(partial_result.removed_instance_ids, [], "partial detach failure has no structural removals")
	_assert_true(partial_equipment.are_both_hands_empty(), "completed hand cleanup is not rolled back")
	_assert_true(failing_armor.is_worn(partial_item.item_instance_id), "failed Armor authority remains referenced")
	_assert_true(inventory.is_registered(partial_item.item_instance_id), "partial detach failure keeps Inventory liveness")
	_assert_true(stacks.has_stack(partial_item.item_instance_id), "partial detach failure keeps stack association")
	_assert_eq(stacks.stack_state(partial_item.item_instance_id).amount, 4, "partial detach failure preserves amount")


func _test_leaf_guard_subtree_order_and_siblings() -> void:
	var inventory: InventoryStateScript = InventoryStateScript.new()
	var stacks: StackCollectionScript = StackCollectionScript.new()
	var bag: ItemInstanceScript = _register(inventory, &"bag:guard", DEF_BAG, 10)
	var child: ItemInstanceScript = _register(inventory, &"item:guard_child", DEF_PLAIN, 3)
	_place(inventory, bag.item_instance_id, _character(CHARACTER_ID))
	_place(inventory, child.item_instance_id, _item_endpoint(bag.item_instance_id))
	var guard_equipment: EquipmentStateScript = EquipmentStateScript.new()
	guard_equipment._restore_weapons(
		_weapon_ref(bag.item_instance_id, DEF_BAG),
		null,
	)
	var load_before: int = inventory.contents_weight(_character(CHARACTER_ID))
	var guarded: LifecycleResultScript = LifecycleServiceScript.destroy_item(
		inventory,
		stacks,
		bag.item_instance_id,
		LifecycleResultScript.ChildDisposition.REQUIRE_LEAF,
		_context(CHARACTER_ID, guard_equipment),
	)
	_assert_eq(guarded.outcome, LifecycleResultScript.Outcome.NOT_LEAF, "REQUIRE_LEAF rejects contained children")
	_assert_true(inventory.is_registered(bag.item_instance_id), "leaf guard preserves parent")
	_assert_true(inventory.is_registered(child.item_instance_id), "leaf guard preserves child")
	_assert_eq(inventory.contents_weight(_character(CHARACTER_ID)), load_before, "leaf guard preserves weight")
	_assert_true(guard_equipment.has_weapon_instance(bag.item_instance_id), "structural prevalidation occurs before detach")

	var subtree_inventory: InventoryStateScript = InventoryStateScript.new()
	var subtree_stacks: StackCollectionScript = StackCollectionScript.new()
	var root: ItemInstanceScript = _register(subtree_inventory, &"bag:b", DEF_BAG, 10)
	var plain: ItemInstanceScript = _register(subtree_inventory, &"item:i", DEF_PLAIN, 3)
	var stack: ItemInstanceScript = _register(subtree_inventory, &"stack:s", DEF_STACK, 0)
	_place(subtree_inventory, root.item_instance_id, _character(CHARACTER_ID))
	_place(subtree_inventory, plain.item_instance_id, _item_endpoint(root.item_instance_id))
	_place(subtree_inventory, stack.item_instance_id, _item_endpoint(root.item_instance_id))
	_register_stack(subtree_inventory, subtree_stacks, stack, 8)
	var root_equipment: EquipmentStateScript = EquipmentStateScript.new()
	root_equipment._restore_weapons(
		_weapon_ref(root.item_instance_id, DEF_BAG),
		null,
	)
	var root_armor: ArmorStateScript = ArmorStateScript.new()
	root_armor._restore_equipped_refs([
		EquippedArmorRefScript.new(
			root.item_instance_id,
			_armor_definition(DEF_BAG),
		),
	])
	_assert_eq(subtree_inventory.contents_weight(_character(CHARACTER_ID)), 21, "subtree fixture load equals 10 + 3 + 8")
	var subtree_result: LifecycleResultScript = LifecycleServiceScript.destroy_item(
		subtree_inventory,
		subtree_stacks,
		root.item_instance_id,
		LifecycleResultScript.ChildDisposition.DESTROY_SUBTREE,
		_context(CHARACTER_ID, root_equipment, root_armor),
	)
	_assert_true(subtree_result.succeeded, "valid subtree destruction succeeds")
	_assert_true(subtree_result.weapon_detached, "direct-character subtree root hand ref is cleaned")
	_assert_true(subtree_result.armor_detached, "direct-character subtree root Armor ref is cleaned")
	_assert_true(root_equipment.are_both_hands_empty(), "subtree root hand authority clears")
	_assert_true(root_armor.occupied_slots().is_empty(), "subtree root Armor authority clears")
	_assert_eq(subtree_result.removed_instance_ids, [&"item:i", &"stack:s", &"bag:b"], "stable child order produces deterministic post-order")
	_assert_eq(subtree_inventory.contents_weight(_character(CHARACTER_ID)), 0, "subtree root load disappears exactly once")
	for removed_id: StringName in [&"bag:b", &"item:i", &"stack:s"]:
		_assert_false(subtree_inventory.is_registered(removed_id), "subtree member is no longer live")
		_assert_eq(subtree_inventory.direct_parent(removed_id), null, "subtree member has no stale parent")
	_assert_false(subtree_stacks.has_stack(&"stack:s"), "subtree stack association disappears")
	var returned_ids: Array[StringName] = subtree_result.removed_instance_ids
	returned_ids.clear()
	_assert_eq(subtree_result.removed_instance_ids, [&"item:i", &"stack:s", &"bag:b"], "removed IDs getter is defensive")
	var returned_parent: EndpointScript = subtree_result.previous_parent
	returned_parent._endpoint_id = &"mutated"
	_assert_eq(subtree_result.previous_parent.endpoint_id, CHARACTER_ID, "previous parent getter is defensive")

	var deep_inventory: InventoryStateScript = InventoryStateScript.new()
	var deep_stacks: StackCollectionScript = StackCollectionScript.new()
	for deep_id: StringName in [&"tree:a", &"tree:b", &"tree:c", &"tree:d"]:
		_register(deep_inventory, deep_id, DEF_PLAIN, 1)
	_place(deep_inventory, &"tree:b", _item_endpoint(&"tree:a"))
	_place(deep_inventory, &"tree:c", _item_endpoint(&"tree:b"))
	_place(deep_inventory, &"tree:d", _item_endpoint(&"tree:c"))
	var deep_result: LifecycleResultScript = LifecycleServiceScript.destroy_item(
		deep_inventory,
		deep_stacks,
		&"tree:a",
		LifecycleResultScript.ChildDisposition.DESTROY_SUBTREE,
	)
	_assert_eq(deep_result.removed_instance_ids, [&"tree:d", &"tree:c", &"tree:b", &"tree:a"], "deep subtree uses deterministic post-order")

	var branch_inventory: InventoryStateScript = InventoryStateScript.new()
	var branch_stacks: StackCollectionScript = StackCollectionScript.new()
	for branch_id: StringName in [&"branch:a", &"branch:b", &"branch:c", &"branch:d"]:
		_register(branch_inventory, branch_id, DEF_PLAIN, 1)
	_place(branch_inventory, &"branch:b", _item_endpoint(&"branch:a"))
	_place(branch_inventory, &"branch:c", _item_endpoint(&"branch:a"))
	_place(branch_inventory, &"branch:d", _item_endpoint(&"branch:b"))
	var branch_result: LifecycleResultScript = LifecycleServiceScript.destroy_item(
		branch_inventory,
		branch_stacks,
		&"branch:a",
		LifecycleResultScript.ChildDisposition.DESTROY_SUBTREE,
	)
	_assert_eq(branch_result.removed_instance_ids, [&"branch:d", &"branch:b", &"branch:c", &"branch:a"], "branched subtree is stable depth-first post-order")

	var mixed_inventory: InventoryStateScript = InventoryStateScript.new()
	var mixed_stacks: StackCollectionScript = StackCollectionScript.new()
	_register(mixed_inventory, &"mixed:root", DEF_BAG, 4)
	_register(mixed_inventory, &"mixed:inner", DEF_BAG, 2)
	var mixed_a: ItemInstanceScript = _register(
		mixed_inventory,
		&"stack:mixed_a",
		DEF_STACK,
		0,
	)
	var mixed_b: ItemInstanceScript = _register(
		mixed_inventory,
		&"stack:mixed_b",
		DEF_STACK,
		0,
	)
	var outside: ItemInstanceScript = _register(
		mixed_inventory,
		&"stack:mixed_outside",
		DEF_STACK,
		0,
	)
	_register_stack(mixed_inventory, mixed_stacks, mixed_a, 2)
	_register_stack(mixed_inventory, mixed_stacks, mixed_b, 3)
	_register_stack(mixed_inventory, mixed_stacks, outside, 4)
	_place(mixed_inventory, &"mixed:inner", _item_endpoint(&"mixed:root"))
	_place(mixed_inventory, mixed_a.item_instance_id, _item_endpoint(&"mixed:root"))
	_place(mixed_inventory, mixed_b.item_instance_id, _item_endpoint(&"mixed:inner"))
	var mixed_result: LifecycleResultScript = LifecycleServiceScript.destroy_item(
		mixed_inventory,
		mixed_stacks,
		&"mixed:root",
		LifecycleResultScript.ChildDisposition.DESTROY_SUBTREE,
	)
	_assert_eq(mixed_result.removed_instance_ids, [&"stack:mixed_b", &"mixed:inner", &"stack:mixed_a", &"mixed:root"], "mixed subtree removes every descendant stack in stable post-order")
	_assert_false(mixed_stacks.has_stack(mixed_a.item_instance_id), "first removed descendant stack association disappears")
	_assert_false(mixed_stacks.has_stack(mixed_b.item_instance_id), "deep removed descendant stack association disappears")
	_assert_true(mixed_inventory.is_registered(outside.item_instance_id), "outside stack remains Inventory-live")
	_assert_true(mixed_stacks.has_stack(outside.item_instance_id), "outside stack association remains complete")
	_assert_eq(mixed_stacks.stack_state(outside.item_instance_id).amount, 4, "outside stack amount remains exact")

	var sibling_inventory: InventoryStateScript = InventoryStateScript.new()
	var sibling_stacks: StackCollectionScript = StackCollectionScript.new()
	_register(sibling_inventory, &"bag:siblings", DEF_BAG, 1)
	_register(sibling_inventory, &"item:a", DEF_PLAIN, 2)
	_register(sibling_inventory, &"item:b", DEF_PLAIN, 3)
	_place(sibling_inventory, &"bag:siblings", _character(CHARACTER_ID))
	_place(sibling_inventory, &"item:a", _item_endpoint(&"bag:siblings"))
	_place(sibling_inventory, &"item:b", _item_endpoint(&"bag:siblings"))
	_assert_eq(sibling_inventory.contents_weight(_character(CHARACTER_ID)), 6, "sibling fixture root load includes bag and both children")
	LifecycleServiceScript.destroy_item(
		sibling_inventory,
		sibling_stacks,
		&"item:a",
		LifecycleResultScript.ChildDisposition.DESTROY_SUBTREE,
	)
	_assert_false(sibling_inventory.is_registered(&"item:a"), "selected sibling removed")
	_assert_true(sibling_inventory.is_registered(&"item:b"), "unselected sibling survives")
	_assert_true(sibling_inventory.is_direct_child(&"item:b", _item_endpoint(&"bag:siblings")), "surviving sibling parent unchanged")
	_assert_eq(sibling_inventory.contents_weight(_character(CHARACTER_ID)), 4, "selected leaf weight alone disappears")


func _test_stack_and_zero_intent_cleanup() -> void:
	var inventory: InventoryStateScript = InventoryStateScript.new()
	var stacks: StackCollectionScript = StackCollectionScript.new()
	var ordinary_stack: ItemInstanceScript = _register(inventory, &"stack:ordinary", DEF_STACK, 0)
	_register_stack(inventory, stacks, ordinary_stack, 5)
	var visible_before: StackStateScript = stacks.stack_state(
		ordinary_stack.item_instance_id
	)
	var stack_result: LifecycleResultScript = LifecycleServiceScript.destroy_item(
		inventory,
		stacks,
		ordinary_stack.item_instance_id,
	)
	_assert_true(stack_result.succeeded, "stack leaf destroys through lifecycle")
	_assert_eq(visible_before.amount, 5, "destruction does not mutate amount to zero first")
	_assert_false(stacks.has_stack(ordinary_stack.item_instance_id), "destroyed stack association removed")

	var pending: ItemInstanceScript = _register(inventory, &"stack:pending", DEF_STACK, 0)
	_register_stack(inventory, stacks, pending, 1)
	var intent: StackAmountResultScript = StackServiceScript.set_amount(
		stacks,
		inventory,
		pending.item_instance_id,
		0,
	)
	_assert_eq(intent.lifecycle_action, StackAmountResultScript.LifecycleAction.DELAYED_DESTRUCTION, "set_amount zero emits external intent")
	_assert_eq(stacks.stack_state(pending.item_instance_id).amount, 1, "pending window keeps old amount")
	_assert_eq(inventory.own_weight(pending.item_instance_id), 1, "pending window keeps old weight")
	var pending_result: LifecycleResultScript = LifecycleServiceScript.destroy_item(
		inventory,
		stacks,
		pending.item_instance_id,
	)
	_assert_true(pending_result.succeeded, "future intent adapter can call ordinary lifecycle transition")
	_assert_false(inventory.is_registered(pending.item_instance_id), "pending stack liveness removed")
	_assert_false(stacks.has_stack(pending.item_instance_id), "pending stack state removed without scheduler")

	var raw_zero: ItemInstanceScript = _register(inventory, &"stack:raw_zero", DEF_STACK, 77)
	_register_stack(inventory, stacks, raw_zero, 0)
	_assert_eq(inventory.own_weight(raw_zero.item_instance_id), 77, "raw-zero unusual weight remains before destruction")
	var raw_result: LifecycleResultScript = LifecycleServiceScript.destroy_item(
		inventory,
		stacks,
		raw_zero.item_instance_id,
	)
	_assert_true(raw_result.succeeded, "raw-zero stack destroys normally")
	_assert_false(stacks.has_stack(raw_zero.item_instance_id), "raw-zero association removed")

	var survivors: Array[ItemInstanceScript] = []
	for stack_id: StringName in [&"stack:a", &"stack:b", &"stack:c"]:
		var survivor: ItemInstanceScript = _register(inventory, stack_id, DEF_STACK, 0)
		_register_stack(inventory, stacks, survivor, 2)
		survivors.append(survivor)
	LifecycleServiceScript.destroy_item(inventory, stacks, &"stack:b")
	_assert_true(inventory.is_registered(&"stack:a") and stacks.has_stack(&"stack:a"), "first surviving stack remains complete")
	_assert_false(inventory.is_registered(&"stack:b") or stacks.has_stack(&"stack:b"), "selected stack disappears from both authorities")
	_assert_true(inventory.is_registered(&"stack:c") and stacks.has_stack(&"stack:c"), "second surviving stack remains complete")
	var survivor_definitions: DefinitionProjectionsScript = DefinitionProjectionsScript.new(
		[ItemDefinitionScript.new(DEF_STACK)],
		[],
		[],
		[_stack_definition()],
	)
	var survivor_capture: CaptureResultScript = CaptureScript.capture(
		[survivors[0], survivors[2]],
		inventory,
		stacks,
		[],
		[],
		survivor_definitions,
	)
	_assert_true(survivor_capture.succeeded, "Phase 4B5A validator proves surviving stack completeness")

	var corrupt_inventory: InventoryStateScript = InventoryStateScript.new()
	var corrupt_stacks: StackCollectionScript = StackCollectionScript.new()
	var corrupt_item: ItemInstanceScript = _register(
		corrupt_inventory,
		&"stack:corrupt_association",
		DEF_STACK,
		0,
	)
	_register_stack(corrupt_inventory, corrupt_stacks, corrupt_item, 3)
	corrupt_stacks._definitions.erase(corrupt_item.item_instance_id)
	var corrupt_result: LifecycleResultScript = LifecycleServiceScript.destroy_item(
		corrupt_inventory,
		corrupt_stacks,
		corrupt_item.item_instance_id,
	)
	_assert_eq(corrupt_result.outcome, LifecycleResultScript.Outcome.INVALID_STACK_ASSOCIATION, "invalid stack association fails during prevalidation")
	_assert_true(corrupt_inventory.is_registered(corrupt_item.item_instance_id), "invalid association cannot remove Inventory first")
	_assert_true(corrupt_stacks.has_stack(corrupt_item.item_instance_id), "invalid association cannot remove stack state first")


func _test_merge_lifecycle_integration() -> void:
	var inventory: InventoryStateScript = InventoryStateScript.new()
	var stacks: StackCollectionScript = StackCollectionScript.new()
	var moved: ItemInstanceScript = _register(inventory, &"stack:moved", DEF_STACK, 0)
	var existing: ItemInstanceScript = _register(inventory, &"stack:existing", DEF_STACK, 0)
	_register_stack(inventory, stacks, moved, 2)
	_register_stack(inventory, stacks, existing, 5)
	_place(inventory, moved.item_instance_id, _world(&"world:source"))
	_place(inventory, existing.item_instance_id, _character(CHARACTER_ID))
	var merged: StackMergeResultScript = StackServiceScript.transfer_and_merge(
		stacks,
		inventory,
		moved.item_instance_id,
		_destination(_character(CHARACTER_ID)),
		null,
		null,
		_context(CHARACTER_ID),
	)
	_assert_true(merged.succeeded, "merge succeeds through lifecycle absorption")
	_assert_eq(merged.amount_after, 7, "merge keeps LPC 2 + 5 amount")
	_assert_true(inventory.is_registered(moved.item_instance_id), "moved stack survives")
	_assert_false(inventory.is_registered(existing.item_instance_id), "absorbed stack lifecycle liveness removed")
	_assert_false(stacks.has_stack(existing.item_instance_id), "absorbed stack association removed")
	_assert_eq(inventory.own_weight(moved.item_instance_id), 7, "survivor weight updates without double counting")

	var equipped_inventory: InventoryStateScript = InventoryStateScript.new()
	var equipped_stacks: StackCollectionScript = StackCollectionScript.new()
	var equipped_moved: ItemInstanceScript = _register(equipped_inventory, &"stack:new", DEF_STACK, 0)
	var equipped_old: ItemInstanceScript = _register(equipped_inventory, &"stack:old", DEF_STACK, 0)
	var retained: ItemInstanceScript = _register(equipped_inventory, &"weapon:retained_merge", DEF_WEAPON, 1)
	_register_stack(equipped_inventory, equipped_stacks, equipped_moved, 2)
	_register_stack(equipped_inventory, equipped_stacks, equipped_old, 5)
	_place(equipped_inventory, equipped_moved.item_instance_id, _world(&"world:merge_source"))
	_place(equipped_inventory, equipped_old.item_instance_id, _character(CHARACTER_ID))
	_place(equipped_inventory, retained.item_instance_id, _character(CHARACTER_ID))
	var equipment: EquipmentStateScript = EquipmentStateScript.new()
	equipment._restore_weapons(
		_weapon_ref(retained.item_instance_id, DEF_WEAPON),
		_weapon_ref(equipped_old.item_instance_id, DEF_STACK, true),
	)
	var malformed_armor: ArmorStateScript = ArmorStateScript.new()
	malformed_armor._restore_equipped_refs([
		EquippedArmorRefScript.new(
			equipped_old.item_instance_id,
			_armor_definition(DEF_STACK),
		),
	])
	var equipped_merge: StackMergeResultScript = StackServiceScript.transfer_and_merge(
		equipped_stacks,
		equipped_inventory,
		equipped_moved.item_instance_id,
		_destination(_character(CHARACTER_ID)),
		null,
		null,
		_context(CHARACTER_ID, equipment, malformed_armor),
	)
	_assert_true(equipped_merge.succeeded, "equipped absorbed stack uses lifecycle service")
	_assert_eq(equipped_merge.equipment_detached_instance_ids, [&"stack:old"], "merge preserves equipment detach evidence")
	_assert_eq(equipment.primary_weapon().instance_id, retained.item_instance_id, "absorbed secondary does not alter primary")
	_assert_true(equipment.is_secondary_hand_empty(), "absorbed secondary clears without promotion")
	_assert_false(equipment.has_weapon_instance(equipped_moved.item_instance_id), "survivor is not auto-equipped")
	_assert_true(malformed_armor.occupied_slots().is_empty(), "malformed stack Armor ref is cleaned by lifecycle")

	var guarded_inventory: InventoryStateScript = InventoryStateScript.new()
	var guarded_stacks: StackCollectionScript = StackCollectionScript.new()
	var guarded_moved: ItemInstanceScript = _register(guarded_inventory, &"stack:guard_moved", DEF_STACK, 0)
	var guarded_old: ItemInstanceScript = _register(guarded_inventory, &"stack:guard_old", DEF_STACK, 0)
	_register_stack(guarded_inventory, guarded_stacks, guarded_moved, 2)
	_register_stack(guarded_inventory, guarded_stacks, guarded_old, 5)
	_register(guarded_inventory, &"item:guarded_child", DEF_PLAIN, 1)
	_place(guarded_inventory, guarded_moved.item_instance_id, _world(&"world:guard"))
	_place(guarded_inventory, guarded_old.item_instance_id, _character(CHARACTER_ID))
	_place(guarded_inventory, &"item:guarded_child", _item_endpoint(guarded_old.item_instance_id))
	var guarded_equipment: EquipmentStateScript = EquipmentStateScript.new()
	guarded_equipment._restore_weapons(
		_weapon_ref(guarded_old.item_instance_id, DEF_STACK),
		null,
	)
	var guarded_merge: StackMergeResultScript = StackServiceScript.transfer_and_merge(
		guarded_stacks,
		guarded_inventory,
		guarded_moved.item_instance_id,
		_destination(_character(CHARACTER_ID)),
		null,
		null,
		_context(CHARACTER_ID, guarded_equipment),
	)
	_assert_eq(guarded_merge.outcome, StackMergeResultScript.Outcome.ABSORBED_STACK_HAS_CONTENTS, "absorbed stack child guard remains exact")
	_assert_true(guarded_merge.inventory_transfer.succeeded, "transfer still occurs before contained-stack guard")
	_assert_true(guarded_inventory.is_registered(guarded_old.item_instance_id), "guarded absorbed stack remains live")
	_assert_true(guarded_stacks.has_stack(guarded_old.item_instance_id), "guarded absorbed stack state remains")
	_assert_true(guarded_equipment.has_weapon_instance(guarded_old.item_instance_id), "contained-stack guard still occurs before detach")
	_assert_true(guarded_inventory.is_direct_child(&"item:guarded_child", _item_endpoint(guarded_old.item_instance_id)), "guard never orphans child")


func _test_multi_sibling_merge_failure_preserves_quantity() -> void:
	var inventory: InventoryStateScript = InventoryStateScript.new()
	var stacks: StackCollectionScript = StackCollectionScript.new()
	var moved: ItemInstanceScript = _register(
		inventory,
		&"stack:a_moved",
		DEF_STACK,
		0,
	)
	var first: ItemInstanceScript = _register(
		inventory,
		&"stack:b_success",
		DEF_STACK,
		0,
	)
	var second: ItemInstanceScript = _register(
		inventory,
		&"stack:c_failure",
		DEF_STACK,
		0,
	)
	_register_stack(inventory, stacks, moved, 5)
	_register_stack(inventory, stacks, first, 2)
	_register_stack(inventory, stacks, second, 3)
	_place(inventory, moved.item_instance_id, _world(&"world:multi_failure"))
	_place(inventory, first.item_instance_id, _character(CHARACTER_ID))
	_place(inventory, second.item_instance_id, _character(CHARACTER_ID))
	var failing_equipment: EquipmentStateScript = FailingEquipmentStateScript.new(
		second.item_instance_id
	)
	var result: StackMergeResultScript = StackServiceScript.transfer_and_merge(
		stacks,
		inventory,
		moved.item_instance_id,
		_destination(_character(CHARACTER_ID)),
		null,
		null,
		_context(CHARACTER_ID, failing_equipment),
	)
	_assert_eq(result.outcome, StackMergeResultScript.Outcome.ABSORBED_LIFECYCLE_FAILED, "later sibling detach failure remains typed")
	_assert_false(result.succeeded, "partial multi-sibling merge is not reported successful")
	_assert_true(result.merge_applied, "result reports the first completed absorption")
	_assert_eq(result.amount_before, 5, "partial merge preserves original amount evidence")
	_assert_eq(result.amount_after, 7, "survivor commits the successfully absorbed quantity")
	_assert_eq(result.total_absorbed_amount, 2, "failed sibling quantity is not reported absorbed")
	_assert_eq(result.absorbed_instance_ids, [&"stack:b_success"], "only destroyed sibling is reported absorbed")
	_assert_false(inventory.is_registered(first.item_instance_id), "first sibling was lifecycle-removed")
	_assert_false(stacks.has_stack(first.item_instance_id), "first sibling stack association was removed")
	_assert_true(inventory.is_registered(second.item_instance_id), "failing sibling remains Inventory-live")
	_assert_true(stacks.has_stack(second.item_instance_id), "failing sibling keeps stack association")
	_assert_eq(stacks.stack_state(second.item_instance_id).amount, 3, "failing sibling keeps its exact amount")
	_assert_eq(stacks.stack_state(moved.item_instance_id).amount, 7, "survivor holds original plus completed absorption")
	_assert_eq(inventory.contents_weight(_character(CHARACTER_ID)), 10, "partial failure conserves total quantity weight")

	var missing_inventory: InventoryStateScript = InventoryStateScript.new()
	var missing_stacks: StackCollectionScript = StackCollectionScript.new()
	var missing_moved: ItemInstanceScript = _register(
		missing_inventory,
		&"stack:missing_moved",
		DEF_STACK,
		0,
	)
	var missing_existing: ItemInstanceScript = _register(
		missing_inventory,
		&"stack:missing_existing",
		DEF_STACK,
		0,
	)
	_register_stack(missing_inventory, missing_stacks, missing_moved, 2)
	_register_stack(missing_inventory, missing_stacks, missing_existing, 5)
	_place(missing_inventory, missing_moved.item_instance_id, _world(&"world:missing_context"))
	_place(missing_inventory, missing_existing.item_instance_id, _character(CHARACTER_ID))
	var missing_result: StackMergeResultScript = StackServiceScript.transfer_and_merge(
		missing_stacks,
		missing_inventory,
		missing_moved.item_instance_id,
		_destination(_character(CHARACTER_ID)),
	)
	_assert_eq(missing_result.outcome, StackMergeResultScript.Outcome.ABSORBED_LIFECYCLE_FAILED, "merge cannot omit destination owner authorities")
	_assert_false(missing_result.merge_applied, "missing context completes no absorption")
	_assert_eq(missing_result.amount_after, 2, "missing context preserves survivor amount")
	_assert_true(missing_inventory.is_registered(missing_existing.item_instance_id), "missing context preserves sibling liveness")
	_assert_eq(missing_stacks.stack_state(missing_existing.item_instance_id).amount, 5, "missing context preserves sibling quantity")
	var wrong_result: StackMergeResultScript = StackServiceScript.transfer_and_merge(
		missing_stacks,
		missing_inventory,
		missing_moved.item_instance_id,
		_destination(_character(CHARACTER_ID)),
		null,
		null,
		_context(OTHER_CHARACTER_ID),
	)
	_assert_eq(wrong_result.outcome, StackMergeResultScript.Outcome.ABSORBED_LIFECYCLE_FAILED, "merge forwards wrong owner identity for lifecycle rejection")
	_assert_false(wrong_result.merge_applied, "wrong owner context completes no absorption")
	_assert_true(missing_inventory.is_registered(missing_existing.item_instance_id), "wrong owner context cannot remove C1 sibling")
	_assert_eq(missing_stacks.stack_state(missing_moved.item_instance_id).amount, 2, "wrong owner context preserves survivor amount")


func _test_persistence_interaction_and_stale_identity() -> void:
	var inventory: InventoryStateScript = InventoryStateScript.new()
	var stacks: StackCollectionScript = StackCollectionScript.new()
	var alive: ItemInstanceScript = _register(inventory, &"item:alive", DEF_PLAIN, 1)
	var destroyed: ItemInstanceScript = _register(inventory, &"item:destroyed", DEF_PLAIN, 2)
	var result: LifecycleResultScript = LifecycleServiceScript.destroy_item(
		inventory,
		stacks,
		destroyed.item_instance_id,
	)
	_assert_true(result.succeeded, "persistence fixture destroys one runtime item")
	_assert_eq(destroyed.item_instance_id, &"item:destroyed", "stale immutable ItemInstance reference retains identity")
	_assert_eq(destroyed.item_definition_id, DEF_PLAIN, "stale ItemInstance definition identity is not mutated")
	_assert_false(inventory.is_registered(destroyed.item_instance_id), "stale identity object is not live authority")
	var definitions: DefinitionProjectionsScript = DefinitionProjectionsScript.new([
		ItemDefinitionScript.new(DEF_PLAIN),
	])
	var capture_live: CaptureResultScript = CaptureScript.capture(
		[alive],
		inventory,
		stacks,
		[],
		[],
		definitions,
	)
	_assert_true(capture_live.succeeded, "capture succeeds with only currently live ItemInstances")
	_assert_eq(capture_live.snapshot.schema_version, 1, "Phase 4B5B leaves schema v1 unchanged")
	_assert_false(_has_property(capture_live.snapshot, &"destroyed_ids"), "schema gains no lifecycle field")
	var capture_stale: CaptureResultScript = CaptureScript.capture(
		[alive, destroyed],
		inventory,
		stacks,
		[],
		[],
		definitions,
	)
	_assert_eq(capture_stale.validation_result.outcome, ValidationResultScript.Outcome.ITEM_INSTANCE_NOT_REGISTERED, "capture rejects stale destroyed ItemInstance reference")


func _register(
	inventory: InventoryStateScript,
	instance_id: StringName,
	definition_id: StringName,
	own_weight: int,
) -> ItemInstanceScript:
	var item: ItemInstanceScript = ItemInstanceScript.new(instance_id, definition_id)
	_assert_true(inventory.register_item(item, own_weight), "fixture item registers")
	return item


func _register_stack(
	inventory: InventoryStateScript,
	stacks: StackCollectionScript,
	item: ItemInstanceScript,
	amount: int,
) -> void:
	var result: StackAmountResultScript = StackServiceScript.register_stack(
		stacks,
		inventory,
		item,
		_stack_definition(),
		amount,
	)
	_assert_true(result.accepted, "fixture stack registers")


func _place(
	inventory: InventoryStateScript,
	instance_id: StringName,
	parent: EndpointScript,
) -> void:
	_assert_true(inventory._apply_reparent(instance_id, parent), "fixture parent applies")


func _context(
	character_id: StringName,
	equipment: EquipmentStateScript = null,
	armor: ArmorStateScript = null,
) -> OwnerContextScript:
	var resolved_equipment: EquipmentStateScript = (
		EquipmentStateScript.new() if equipment == null else equipment
	)
	var resolved_armor: ArmorStateScript = (
		ArmorStateScript.new() if armor == null else armor
	)
	return OwnerContextScript.new(
		character_id,
		resolved_equipment,
		resolved_armor,
	)


func _character(character_id: StringName) -> EndpointScript:
	return EndpointScript.new(EndpointScript.Kind.CHARACTER, character_id)


func _item_endpoint(item_instance_id: StringName) -> EndpointScript:
	return EndpointScript.new(EndpointScript.Kind.ITEM, item_instance_id)


func _world(world_id: StringName) -> EndpointScript:
	return EndpointScript.new(EndpointScript.Kind.WORLD, world_id)


func _destination(endpoint: EndpointScript) -> DestinationScript:
	return DestinationScript.new(endpoint, true, true, 1_000_000)


func _weapon_ref(
	instance_id: StringName,
	definition_id: StringName,
	can_secondary: bool = false,
) -> EquippedWeaponRefScript:
	return EquippedWeaponRefScript.new(
		instance_id,
		WeaponDefinitionScript.new(
			definition_id,
			&"throwing" if definition_id == DEF_STACK else &"sword",
			can_secondary,
		),
	)


func _armor_definition(
	definition_id: StringName = DEF_ARMOR,
) -> ArmorDefinitionScript:
	return ArmorDefinitionScript.new(
		definition_id,
		&"custom:lifecycle",
		ArmorModifiersScript.new(4),
	)


func _stack_definition() -> StackDefinitionScript:
	return StackDefinitionScript.new(DEF_STACK, &"legacy:/stack/lifecycle", 1)


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
