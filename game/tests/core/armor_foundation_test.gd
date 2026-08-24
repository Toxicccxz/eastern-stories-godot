extends RefCounted

const ArmorNumericModifiersScript := preload(
	"res://core/armor/armor_numeric_modifiers.gd"
)
const ArmorDefinitionScript := preload("res://core/armor/armor_definition.gd")
const EquippedArmorRefScript := preload("res://core/armor/equipped_armor_ref.gd")
const ArmorTransitionResultScript := preload(
	"res://core/armor/armor_transition_result.gd"
)
const ArmorStateScript := preload("res://core/armor/armor_state.gd")
const ArmorServiceScript := preload("res://core/armor/armor_service.gd")
const EquipmentStateScript := preload("res://core/equipment/equipment_state.gd")
const EquipmentTransitionResultScript := preload(
	"res://core/equipment/equipment_transition_result.gd"
)
const EquippedWeaponRefScript := preload("res://core/equipment/equipped_weapon_ref.gd")
const WeaponDefinitionScript := preload("res://core/equipment/weapon_definition.gd")
const ItemInstanceScript := preload("res://core/items/item_instance.gd")
const InventoryStateScript := preload("res://core/inventory/inventory_state.gd")
const EndpointScript := preload("res://core/inventory/containment_endpoint.gd")
const DestinationScript := preload(
	"res://core/inventory/inventory_transfer_destination.gd"
)
const TransferResultScript := preload(
	"res://core/inventory/inventory_transfer_result.gd"
)
const TransferServiceScript := preload(
	"res://core/inventory/inventory_transfer_service.gd"
)
const SkillIdsScript := preload("res://core/skills/skill_ids.gd")

const LARGE_CAPACITY: int = 1_000_000

var _assertion_count: int = 0
var _failures: Array[String] = []


func run_all() -> Dictionary[String, Variant]:
	_test_definition_modifier_shape_and_defensive_snapshots()
	_test_open_slots_collisions_and_same_instance_guard()
	_test_direct_ownership_definition_alignment_and_already_worn()
	_test_modifier_aggregation_negative_values_and_remove()
	_test_shield_projection_and_source_asymmetry()
	_test_transfer_success_and_same_root_bag_detach()
	_test_transfer_failures_preserve_detach_partial_mutation()
	_test_move_into_character_nested_bag_and_weapon_regression()
	_test_independent_states_and_result_snapshots()
	return {
		"assertions": _assertion_count,
		"failures": _failures.duplicate(),
	}


func _test_definition_modifier_shape_and_defensive_snapshots() -> void:
	var source: ArmorNumericModifiersScript = ArmorNumericModifiersScript.new(
		10, 20, 3, 4, -2, 5, 6, 7, 8, 9, 11, 12, 13, 14
	)
	var definition: ArmorDefinitionScript = ArmorDefinitionScript.new(
		&"armor:def.full",
		&"head",
		source,
	)
	_assert_eq(definition.item_definition_id, &"armor:def.full", "armor definition identity")
	_assert_eq(definition.armor_type, &"head", "armor definition exact slot")
	_assert_modifiers(
		definition.numeric_modifiers,
		[10, 20, 3, 4, -2, 5, 6, 7, 8, 9, 11, 12, 13, 14],
		"definition modifier snapshot",
	)
	## GDScript underscore fields are conventional privacy. Mutating caller
	## objects proves definitions and refs retain scalar snapshots.
	source._armor = 999
	source._dodge = 999
	_assert_eq(definition.numeric_modifiers.armor, 10, "definition detached from source modifier")
	_assert_eq(definition.numeric_modifiers.dodge, -2, "definition keeps negative source value")
	var returned: ArmorNumericModifiersScript = definition.numeric_modifiers
	returned._armor = 500
	_assert_eq(definition.numeric_modifiers.armor, 10, "definition getter is defensive")

	var reference: EquippedArmorRefScript = EquippedArmorRefScript.new(
		&"armor:instance.full",
		definition,
	)
	_assert_true(reference.is_valid(), "equipped armor ref has all stable identities")
	_assert_eq(reference.item_instance_id, &"armor:instance.full", "ref instance identity")
	_assert_eq(reference.item_definition_id, definition.item_definition_id, "ref definition identity")
	_assert_eq(reference.armor_type, &"head", "ref exact slot")
	definition._armor_type = &"caller-mutated"
	definition._numeric_modifiers._armor = 700
	_assert_eq(reference.armor_type, &"head", "ref snapshots slot")
	_assert_eq(reference.numeric_modifiers.armor, 10, "ref snapshots modifiers")
	_assert_false(EquippedArmorRefScript.new().is_valid(), "empty armor ref invalid")

	var state: ArmorStateScript = ArmorStateScript.new()
	_assert_true(state is RefCounted, "armor state is pure RefCounted")
	var state_variant: Variant = state
	_assert_false(state_variant is Node, "armor state has no Node dependency")
	_assert_eq(state.occupied_slots(), [], "new armor state has no slots")
	_assert_modifiers(state.aggregate_numeric_modifiers(), _zeros(), "new aggregate is zero")
	_assert_false(_has_property(definition, &"display_name"), "definition has no display metadata")
	_assert_false(_has_property(definition, &"legacy_source_path"), "armor definition is minimal")
	_assert_false(_has_property(reference, &"item_instance"), "armor ref stores no mutable item")


func _test_open_slots_collisions_and_same_instance_guard() -> void:
	var inventory: InventoryStateScript = InventoryStateScript.new()
	var owner: EndpointScript = _character(&"character:slots")
	var state: ArmorStateScript = ArmorStateScript.new()
	var boots_a: ItemInstanceScript = _register_place(
		inventory, &"armor:boots_a", &"armor:def.boots_a", owner, 10
	)
	var boots_b: ItemInstanceScript = _register_place(
		inventory, &"armor:boots_b", &"armor:def.boots_b", owner, 10
	)
	var feet: ItemInstanceScript = _register_place(
		inventory, &"armor:feet", &"armor:def.feet", owner, 10
	)
	var first: ArmorTransitionResultScript = ArmorServiceScript.wear(
		state,
		inventory,
		owner,
		boots_a,
		_definition(boots_a.item_definition_id, &"boots", _mods(5, -2)),
	)
	_assert_transition(first, ArmorTransitionResultScript.Outcome.WORN, true, true, "boots A wear")
	var collision: ArmorTransitionResultScript = ArmorServiceScript.wear(
		state,
		inventory,
		owner,
		boots_b,
		_definition(boots_b.item_definition_id, &"boots", _mods(100, 20)),
	)
	_assert_transition(
		collision,
		ArmorTransitionResultScript.Outcome.SLOT_OCCUPIED,
		false,
		false,
		"second exact boots slot rejected",
	)
	_assert_eq(state.item_instance_id_in_slot(&"boots"), boots_a.item_instance_id, "boots A remains authority")
	_assert_eq(state.aggregate_numeric_modifiers().armor, 5, "rejected boots B adds no modifier")

	var feet_result: ArmorTransitionResultScript = ArmorServiceScript.wear(
		state,
		inventory,
		owner,
		feet,
		_definition(feet.item_definition_id, &"feet", _mods(2, 3)),
	)
	_assert_true(feet_result.succeeded, "authored feet slot accepted")
	_assert_true(state.is_slot_occupied(&"boots"), "boots occupied")
	_assert_true(state.is_slot_occupied(&"feet"), "feet independently occupied")

	var duplicate_other_slot: ArmorTransitionResultScript = ArmorServiceScript.wear(
		state,
		inventory,
		owner,
		boots_a,
		_definition(boots_a.item_definition_id, &"custom-other-slot", _mods(999, 999)),
	)
	_assert_transition(
		duplicate_other_slot,
		ArmorTransitionResultScript.Outcome.ALREADY_WORN,
		true,
		false,
		"same instance cannot occupy another slot",
	)
	_assert_false(state.is_slot_occupied(&"custom-other-slot"), "duplicate did not create second slot")
	_assert_eq(state.aggregate_numeric_modifiers().armor, 7, "duplicate did not reapply modifiers")

	var open_slots: Array[StringName] = [&"bandage", &"mask", &"custom-slot"]
	for slot: StringName in open_slots:
		var instance_id: StringName = StringName("armor:" + String(slot))
		var definition_id: StringName = StringName("armor:def." + String(slot))
		var item: ItemInstanceScript = _register_place(
			inventory, instance_id, definition_id, owner, 1
		)
		var result: ArmorTransitionResultScript = ArmorServiceScript.wear(
			state,
			inventory,
			owner,
			item,
			_definition(definition_id, slot, ArmorNumericModifiersScript.new()),
		)
		_assert_true(result.succeeded, "open slot accepted: " + String(slot))
		_assert_true(state.is_slot_occupied(slot), "open slot occupied: " + String(slot))
	_assert_true(state.slot_for_instance(&"armor:mask") == &"mask", "mask is not normalized to head")
	_assert_true(state.slot_for_instance(&"armor:bandage") == &"bandage", "bandage is not normalized to cloth")


func _test_direct_ownership_definition_alignment_and_already_worn() -> void:
	var inventory: InventoryStateScript = InventoryStateScript.new()
	var owner: EndpointScript = _character(&"character:ownership")
	var bag: EndpointScript = _item_endpoint(&"item:bag")
	var world: EndpointScript = _world(&"world:room")
	_register_place(inventory, bag.endpoint_id, &"item:def.bag", owner, 2)
	var direct: ItemInstanceScript = _register_place(
		inventory, &"armor:direct", &"armor:def.direct", owner, 4
	)
	var nested: ItemInstanceScript = _register_place(
		inventory, &"armor:nested", &"armor:def.nested", bag, 4
	)
	var grounded: ItemInstanceScript = _register_place(
		inventory, &"armor:ground", &"armor:def.ground", world, 4
	)
	var state: ArmorStateScript = ArmorStateScript.new()

	var direct_result: ArmorTransitionResultScript = ArmorServiceScript.wear(
		state, inventory, owner, direct, _definition(direct.item_definition_id, &"cloth", _mods(1, 0))
	)
	_assert_true(direct_result.succeeded, "direct character child may wear")
	var nested_result: ArmorTransitionResultScript = ArmorServiceScript.wear(
		state, inventory, owner, nested, _definition(nested.item_definition_id, &"head", _mods(1, 0))
	)
	_assert_eq(nested_result.outcome, ArmorTransitionResultScript.Outcome.ITEM_NOT_DIRECTLY_OWNED, "nested armor rejects")
	var ground_result: ArmorTransitionResultScript = ArmorServiceScript.wear(
		state, inventory, owner, grounded, _definition(grounded.item_definition_id, &"head", _mods(1, 0))
	)
	_assert_eq(ground_result.outcome, ArmorTransitionResultScript.Outcome.ITEM_NOT_DIRECTLY_OWNED, "world armor rejects")

	var mismatch_item: ItemInstanceScript = _register_place(
		inventory, &"armor:mismatch", &"armor:def.actual", owner, 1
	)
	var mismatch: ArmorTransitionResultScript = ArmorServiceScript.wear(
		state,
		inventory,
		owner,
		mismatch_item,
		_definition(&"armor:def.wrong", &"head", _mods(100, 0)),
	)
	_assert_eq(mismatch.outcome, ArmorTransitionResultScript.Outcome.DEFINITION_MISMATCH, "definition mismatch rejects")
	_assert_false(state.is_worn(mismatch_item.item_instance_id), "mismatch mutates no slot")
	_assert_eq(state.aggregate_numeric_modifiers().armor, 1, "mismatch mutates no aggregate")

	var empty_item: ItemInstanceScript = _register_place(
		inventory, &"armor:empty_slot", &"armor:def.empty_slot", owner, 1
	)
	var empty_slot: ArmorTransitionResultScript = ArmorServiceScript.wear(
		state,
		inventory,
		owner,
		empty_item,
		_definition(empty_item.item_definition_id, &"", _mods(5, 0)),
	)
	_assert_eq(empty_slot.outcome, ArmorTransitionResultScript.Outcome.INVALID_ARMOR_SLOT, "empty slot rejects at mutation boundary")

	var already: ArmorTransitionResultScript = ArmorServiceScript.wear(
		state,
		inventory,
		owner,
		direct,
		_definition(direct.item_definition_id, &"", _mods(999, 999)),
	)
	_assert_transition(already, ArmorTransitionResultScript.Outcome.ALREADY_WORN, true, false, "already worn short-circuits")
	_assert_eq(already.armor_type, &"cloth", "already result reports stored slot")
	_assert_eq(state.aggregate_numeric_modifiers().armor, 1, "already does not apply twice")


func _test_modifier_aggregation_negative_values_and_remove() -> void:
	var inventory: InventoryStateScript = InventoryStateScript.new()
	var owner: EndpointScript = _character(&"character:modifiers")
	var state: ArmorStateScript = ArmorStateScript.new()
	var a: ItemInstanceScript = _register_place(
		inventory, &"armor:mod_a", &"armor:def.mod_a", owner, 1
	)
	var b: ItemInstanceScript = _register_place(
		inventory, &"armor:mod_b", &"armor:def.mod_b", owner, 1
	)
	var a_mods: ArmorNumericModifiersScript = ArmorNumericModifiersScript.new(
		10, 20, 3, 4, -2, 5, 6, 7, 8, 9, 10, 11, 12, 13
	)
	var b_mods: ArmorNumericModifiersScript = ArmorNumericModifiersScript.new(
		5, -4, -1, 2, -3, -2, 1, -7, 3, -9, 4, -1, 8, -3
	)
	var baseline_weight: int = inventory.contents_weight(owner)
	_assert_modifiers(state.aggregate_numeric_modifiers(), _zeros(), "modifier baseline")
	ArmorServiceScript.wear(state, inventory, owner, a, _definition(a.item_definition_id, &"armor", a_mods))
	ArmorServiceScript.wear(state, inventory, owner, b, _definition(b.item_definition_id, &"surcoat", b_mods))
	_assert_eq(inventory.contents_weight(owner), baseline_weight, "wear does not change inventory weight")
	_assert_modifiers(
		state.aggregate_numeric_modifiers(),
		[15, 16, 2, 6, -5, 3, 7, 0, 11, 0, 14, 10, 20, 10],
		"two-slot exact aggregate",
	)
	var removed: ArmorTransitionResultScript = state.remove(a.item_instance_id)
	_assert_transition(removed, ArmorTransitionResultScript.Outcome.REMOVED, true, true, "remove worn armor")
	_assert_modifiers(removed.applied_modifiers, [10, 20, 3, 4, -2, 5, 6, 7, 8, 9, 10, 11, 12, 13], "remove result snapshot")
	_assert_modifiers(state.aggregate_numeric_modifiers(), [5, -4, -1, 2, -3, -2, 1, -7, 3, -9, 4, -1, 8, -3], "remove exact reversal")
	_assert_true(inventory.is_direct_child(a.item_instance_id, owner), "remove does not move item")
	_assert_eq(inventory.contents_weight(owner), baseline_weight, "remove does not change carried weight")
	var not_worn: ArmorTransitionResultScript = state.remove(a.item_instance_id)
	_assert_transition(not_worn, ArmorTransitionResultScript.Outcome.NOT_WORN, false, false, "remove twice rejects")
	_assert_eq(state.aggregate_numeric_modifiers().dodge, -3, "negative dodge remains unclamped")
	var removed_b: ArmorTransitionResultScript = state.remove(b.item_instance_id)
	_assert_transition(removed_b, ArmorTransitionResultScript.Outcome.REMOVED, true, true, "remove second armor")
	_assert_modifiers(state.aggregate_numeric_modifiers(), _zeros(), "wear A and B then remove A and B returns exact baseline")
	_assert_eq(inventory.contents_weight(owner), baseline_weight, "full armor reversal leaves inventory weight unchanged")


func _test_shield_projection_and_source_asymmetry() -> void:
	var inventory: InventoryStateScript = InventoryStateScript.new()
	var owner: EndpointScript = _character(&"character:shield")
	var shield: ItemInstanceScript = _register_place(
		inventory, &"armor:shield", &"armor:def.shield", owner, 7_000
	)
	var armor: ArmorStateScript = ArmorStateScript.new()
	ArmorServiceScript.wear(
		armor, inventory, owner, shield, _definition(shield.item_definition_id, &"shield", _mods(5, -2))
	)
	_assert_true(armor.is_slot_occupied(&"shield"), "shield fact derives from exact slot")
	_assert_false(_has_property(armor, &"shield_equipped"), "no duplicate shield boolean authority")

	var equipment: EquipmentStateScript = EquipmentStateScript.new()
	var two_handed: EquippedWeaponRefScript = _weapon(&"weapon:two_handed", true)
	var blocked: EquipmentTransitionResultScript = equipment.wield(
		two_handed,
		armor.is_slot_occupied(&"shield"),
	)
	_assert_false(blocked.succeeded, "ArmorState shield projection blocks two-handed wield")
	armor.remove(shield.item_instance_id)
	_assert_false(armor.is_slot_occupied(&"shield"), "remove clears shield fact")
	var wielded: EquipmentTransitionResultScript = equipment.wield(
		two_handed,
		armor.is_slot_occupied(&"shield"),
	)
	_assert_true(wielded.succeeded, "two-handed wield succeeds after shield remove")

	## Source checks shield only during wield(). wear() has no symmetric weapon
	## gate, so wearing a shield after a two-handed weapon remains reachable.
	var later_shield: ArmorStateScript = ArmorStateScript.new()
	var asymmetric: ArmorTransitionResultScript = ArmorServiceScript.wear(
		later_shield,
		inventory,
		owner,
		shield,
		_definition(shield.item_definition_id, &"shield", _mods(5, -2)),
	)
	_assert_true(asymmetric.succeeded, "shield may be worn after two-handed weapon")
	_assert_true(equipment.has_weapon_instance(two_handed.instance_id), "shield wear does not unwield existing weapon")
	_assert_true(later_shield.is_slot_occupied(&"shield"), "asymmetric shield state remains worn")


func _test_transfer_success_and_same_root_bag_detach() -> void:
	var service: TransferServiceScript = TransferServiceScript.new()
	var inventory: InventoryStateScript = InventoryStateScript.new()
	var owner: EndpointScript = _character(&"character:transfer_success")
	var world: EndpointScript = _world(&"world:transfer_success")
	var armor: ArmorStateScript = ArmorStateScript.new()
	var equipment: EquipmentStateScript = EquipmentStateScript.new()
	var item: ItemInstanceScript = _register_place(
		inventory, &"armor:move_world", &"armor:def.move_world", owner, 10
	)
	ArmorServiceScript.wear(
		armor,
		inventory,
		owner,
		item,
		_definition(item.item_definition_id, &"head", _mods(8, -1)),
	)
	var moved: TransferResultScript = service.transfer(
		inventory, item.item_instance_id, _destination(world), equipment, armor
	)
	_assert_transfer(moved, TransferResultScript.Outcome.TRANSFERRED, true, false, true, true, "worn character to world")
	_assert_true(inventory.is_direct_child(item.item_instance_id, world), "successful worn item parent changes")
	_assert_false(armor.is_worn(item.item_instance_id), "successful transfer clears worn slot")
	_assert_eq(armor.aggregate_numeric_modifiers().armor, 0, "successful transfer removes modifier")

	var bag: ItemInstanceScript = _register_place(
		inventory, &"item:bag_transfer", &"item:def.bag_transfer", owner, 2
	)
	var item_to_bag: ItemInstanceScript = _register_place(
		inventory, &"armor:move_bag", &"armor:def.move_bag", owner, 5
	)
	ArmorServiceScript.wear(armor, inventory, owner, item_to_bag, _definition(item_to_bag.item_definition_id, &"neck", _mods(3, 0)))
	var to_bag: TransferResultScript = service.transfer(
		inventory,
		item_to_bag.item_instance_id,
		_destination(_item_endpoint(bag.item_instance_id)),
		equipment,
		armor,
	)
	_assert_transfer(to_bag, TransferResultScript.Outcome.TRANSFERRED, true, false, true, true, "worn character to carried bag")
	_assert_endpoint(inventory.root_holder(item_to_bag.item_instance_id), EndpointScript.Kind.CHARACTER, owner.endpoint_id, "bag move retains character root")
	_assert_false(armor.is_worn(item_to_bag.item_instance_id), "same-root nesting still detaches")


func _test_transfer_failures_preserve_detach_partial_mutation() -> void:
	var service: TransferServiceScript = TransferServiceScript.new()
	var owner: EndpointScript = _character(&"character:transfer_fail")
	var full_bag_endpoint: EndpointScript = _item_endpoint(&"item:full_bag")
	var inventory: InventoryStateScript = InventoryStateScript.new()
	_register_place(inventory, full_bag_endpoint.endpoint_id, &"item:def.full_bag", owner, 1)
	var armor: ArmorStateScript = ArmorStateScript.new()
	var item: ItemInstanceScript = _register_place(
		inventory, &"armor:capacity_fail", &"armor:def.capacity_fail", owner, 20
	)
	ArmorServiceScript.wear(armor, inventory, owner, item, _definition(item.item_definition_id, &"armor", _mods(12, -4)))
	var capacity_fail: TransferResultScript = service.transfer(
		inventory,
		item.item_instance_id,
		_destination(full_bag_endpoint, true, true, 19),
		EquipmentStateScript.new(),
		armor,
	)
	_assert_transfer(capacity_fail, TransferResultScript.Outcome.CAPACITY_EXCEEDED, false, false, true, false, "worn capacity failure")
	_assert_true(inventory.is_direct_child(item.item_instance_id, owner), "capacity failure keeps containment")
	_assert_false(armor.is_worn(item.item_instance_id), "capacity failure keeps armor detached")
	_assert_eq(armor.aggregate_numeric_modifiers().armor, 0, "capacity failure keeps modifiers removed")

	var invalid_item: ItemInstanceScript = _register_place(
		inventory, &"armor:invalid_dest", &"armor:def.invalid_dest", owner, 1
	)
	ArmorServiceScript.wear(armor, inventory, owner, invalid_item, _definition(invalid_item.item_definition_id, &"wrists", _mods(4, 0)))
	var invalid_destination: TransferResultScript = service.transfer(
		inventory,
		invalid_item.item_instance_id,
		DestinationScript.new(null, false, false, 0),
		null,
		armor,
	)
	_assert_transfer(invalid_destination, TransferResultScript.Outcome.INVALID_DESTINATION, false, false, true, false, "invalid destination after armor detach")
	_assert_true(inventory.is_direct_child(invalid_item.item_instance_id, owner), "invalid destination keeps parent")
	_assert_false(armor.is_worn(invalid_item.item_instance_id), "invalid destination does not rollback armor")

	var unavailable_item: ItemInstanceScript = _register_place(
		inventory, &"armor:unavailable_dest", &"armor:def.unavailable_dest", owner, 1
	)
	ArmorServiceScript.wear(
		armor,
		inventory,
		owner,
		unavailable_item,
		_definition(unavailable_item.item_definition_id, &"hands", _mods(6, -2)),
	)
	var unavailable_destination: TransferResultScript = service.transfer(
		inventory,
		unavailable_item.item_instance_id,
		_destination(_world(&"world:unavailable"), false, true, LARGE_CAPACITY),
		null,
		armor,
	)
	_assert_transfer(
		unavailable_destination,
		TransferResultScript.Outcome.DESTINATION_UNAVAILABLE,
		false,
		false,
		true,
		false,
		"unavailable destination after armor detach",
	)
	_assert_true(
		inventory.is_direct_child(unavailable_item.item_instance_id, owner),
		"unavailable destination keeps parent",
	)
	_assert_false(
		armor.is_worn(unavailable_item.item_instance_id),
		"unavailable destination does not rollback armor",
	)

	var unworn: ItemInstanceScript = _register_place(
		inventory, &"armor:unworn_fail", &"armor:def.unworn_fail", owner, 20
	)
	var unworn_fail: TransferResultScript = service.transfer(
		inventory,
		unworn.item_instance_id,
		_destination(full_bag_endpoint, true, true, 19),
		EquipmentStateScript.new(),
		armor,
	)
	_assert_transfer(unworn_fail, TransferResultScript.Outcome.CAPACITY_EXCEEDED, false, false, false, false, "unworn capacity failure")
	_assert_true(inventory.is_direct_child(unworn.item_instance_id, owner), "unworn failure keeps parent")


func _test_move_into_character_nested_bag_and_weapon_regression() -> void:
	var service: TransferServiceScript = TransferServiceScript.new()
	var inventory: InventoryStateScript = InventoryStateScript.new()
	var world: EndpointScript = _world(&"world:incoming")
	var owner: EndpointScript = _character(&"character:incoming")
	var armor: ArmorStateScript = ArmorStateScript.new()
	var incoming: ItemInstanceScript = _register_place(
		inventory, &"armor:incoming", &"armor:def.incoming", world, 1
	)
	var incoming_result: TransferResultScript = service.transfer(
		inventory, incoming.item_instance_id, _destination(owner), null, armor
	)
	_assert_transfer(incoming_result, TransferResultScript.Outcome.TRANSFERRED, true, false, false, true, "move into character")
	_assert_false(armor.is_worn(incoming.item_instance_id), "move into character does not auto-wear")

	var bag: ItemInstanceScript = _register_place(
		inventory, &"item:nested_bag", &"item:def.nested_bag", owner, 3
	)
	var bag_incoming: ItemInstanceScript = _register_place(
		inventory,
		&"armor:bag_incoming",
		&"armor:def.bag_incoming",
		_item_endpoint(bag.item_instance_id),
		1,
	)
	var bag_incoming_result: TransferResultScript = service.transfer(
		inventory,
		bag_incoming.item_instance_id,
		_destination(owner),
		null,
		armor,
	)
	_assert_transfer(
		bag_incoming_result,
		TransferResultScript.Outcome.TRANSFERRED,
		true,
		false,
		false,
		true,
		"bag to character does not auto-wear",
	)
	_assert_false(armor.is_worn(bag_incoming.item_instance_id), "bag item stays unworn after direct carry")

	var nested: ItemInstanceScript = _register_place(
		inventory,
		&"armor:nested_child",
		&"armor:def.nested_child",
		_item_endpoint(bag.item_instance_id),
		2,
	)
	var bag_move: TransferResultScript = service.transfer(
		inventory, bag.item_instance_id, _destination(world), null, armor
	)
	_assert_true(bag_move.succeeded, "bag with nested armor moves")
	_assert_false(bag_move.armor_detached, "nested child does not trigger recursive detach")
	_assert_true(inventory.is_direct_child(nested.item_instance_id, _item_endpoint(bag.item_instance_id)), "nested armor parent stays bag")

	var weapon_item: ItemInstanceScript = _register_place(
		inventory, &"weapon:regression", &"weapon:def.regression", owner, 5
	)
	var equipment: EquipmentStateScript = EquipmentStateScript.new()
	equipment.wield(_weapon(weapon_item.item_instance_id), false)
	var invalid: TransferResultScript = service.transfer(
		inventory,
		weapon_item.item_instance_id,
		DestinationScript.new(null, false, false, 0),
		equipment,
		armor,
	)
	_assert_transfer(invalid, TransferResultScript.Outcome.INVALID_DESTINATION, false, true, false, false, "weapon detach regression")
	_assert_false(equipment.has_weapon_instance(weapon_item.item_instance_id), "weapon still detaches before failure")
	_assert_true(inventory.is_direct_child(weapon_item.item_instance_id, owner), "weapon failure keeps containment")

	## Active authored content has no item using both protocols. This deliberately
	## malformed native state proves the transfer result does not hide either
	## ordered detach if an outer integration boundary is violated.
	var dual_item: ItemInstanceScript = _register_place(
		inventory, &"item:dual_corrupt", &"item:def.dual_corrupt", owner, 1
	)
	equipment.wield(_weapon(dual_item.item_instance_id), false)
	ArmorServiceScript.wear(
		armor,
		inventory,
		owner,
		dual_item,
		_definition(dual_item.item_definition_id, &"custom-dual", _mods(2, -1)),
	)
	var dual_failure: TransferResultScript = service.transfer(
		inventory,
		dual_item.item_instance_id,
		DestinationScript.new(null, false, false, 0),
		equipment,
		armor,
	)
	_assert_transfer(
		dual_failure,
		TransferResultScript.Outcome.INVALID_DESTINATION,
		false,
		true,
		true,
		false,
		"malformed hand and armor state reports both ordered detaches",
	)
	_assert_false(equipment.has_weapon_instance(dual_item.item_instance_id), "malformed dual state clears hand ref")
	_assert_false(armor.is_worn(dual_item.item_instance_id), "malformed dual state clears armor ref")
	_assert_true(inventory.is_direct_child(dual_item.item_instance_id, owner), "malformed dual failure keeps containment")


func _test_independent_states_and_result_snapshots() -> void:
	var first: ArmorStateScript = ArmorStateScript.new()
	var second: ArmorStateScript = ArmorStateScript.new()
	var inventory: InventoryStateScript = InventoryStateScript.new()
	var owner: EndpointScript = _character(&"character:independent")
	var item: ItemInstanceScript = _register_place(
		inventory,
		&"armor:independent",
		&"armor:def.independent",
		owner,
		1,
	)
	var definition: ArmorDefinitionScript = _definition(
		item.item_definition_id,
		&"head",
		_mods(9, -2),
	)
	var result: ArmorTransitionResultScript = ArmorServiceScript.wear(
		first, inventory, owner, item, definition
	)
	_assert_true(first.is_worn(item.item_instance_id), "first state mutates")
	_assert_false(second.is_worn(item.item_instance_id), "second state has no shared slots")
	definition._armor_type = &"caller:changed"
	definition._numeric_modifiers._armor = 100
	_assert_true(first.is_worn(&"armor:independent"), "state defensively snapshots definition identity")
	_assert_eq(first.aggregate_numeric_modifiers().armor, 9, "state aggregate resists definition mutation")
	var returned_ref: EquippedArmorRefScript = first.equipped_ref_in_slot(&"head")
	returned_ref._item_instance_id = &"returned:changed"
	returned_ref._numeric_modifiers._armor = 200
	_assert_true(first.is_worn(&"armor:independent"), "slot query ref is defensive")
	_assert_eq(first.aggregate_numeric_modifiers().armor, 9, "slot query modifier is defensive")
	var result_modifiers: ArmorNumericModifiersScript = result.applied_modifiers
	result_modifiers._armor = 300
	_assert_eq(result.applied_modifiers.armor, 9, "transition result modifier is defensive")


func _definition(
	definition_id: StringName,
	armor_type: StringName,
	modifiers: ArmorNumericModifiersScript,
) -> ArmorDefinitionScript:
	return ArmorDefinitionScript.new(definition_id, armor_type, modifiers)


func _mods(armor_value: int, dodge_value: int) -> ArmorNumericModifiersScript:
	return ArmorNumericModifiersScript.new(armor_value, 0, 0, 0, dodge_value)


func _weapon(instance_id: StringName, two_handed: bool = false) -> EquippedWeaponRefScript:
	return EquippedWeaponRefScript.new(
		instance_id,
		WeaponDefinitionScript.new(
			&"weapon:def.test",
			SkillIdsScript.SWORD,
			false,
			two_handed,
		),
	)


func _register_place(
	inventory: InventoryStateScript,
	instance_id: StringName,
	definition_id: StringName,
	parent: EndpointScript,
	weight: int,
) -> ItemInstanceScript:
	var item: ItemInstanceScript = ItemInstanceScript.new(instance_id, definition_id)
	if not inventory.register_item(item, weight):
		_failures.append("test setup failed to register " + String(instance_id))
	if not inventory._apply_reparent(instance_id, parent):
		_failures.append("test setup failed to place " + String(instance_id))
	return item


func _destination(
	endpoint: EndpointScript,
	available: bool = true,
	containment_capable: bool = true,
	capacity: int = LARGE_CAPACITY,
) -> DestinationScript:
	return DestinationScript.new(endpoint, available, containment_capable, capacity)


func _character(id: StringName) -> EndpointScript:
	return EndpointScript.new(EndpointScript.Kind.CHARACTER, id)


func _item_endpoint(id: StringName) -> EndpointScript:
	return EndpointScript.new(EndpointScript.Kind.ITEM, id)


func _world(id: StringName) -> EndpointScript:
	return EndpointScript.new(EndpointScript.Kind.WORLD, id)


func _zeros() -> Array[int]:
	return [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]


func _assert_modifiers(
	actual: ArmorNumericModifiersScript,
	expected: Array[int],
	label: String,
) -> void:
	var values: Array[int] = [
		actual.armor,
		actual.armor_vs_force,
		actual.attack,
		actual.defense,
		actual.dodge,
		actual.composure,
		actual.courage,
		actual.intelligence,
		actual.karma,
		actual.personality,
		actual.magic,
		actual.move,
		actual.spells,
		actual.unarmed,
	]
	_assert_eq(values, expected, label)


func _assert_transition(
	result: ArmorTransitionResultScript,
	outcome: int,
	succeeded: bool,
	changed: bool,
	label: String,
) -> void:
	_assert_eq(result.outcome, outcome, label + " outcome")
	_assert_eq(result.succeeded, succeeded, label + " succeeded")
	_assert_eq(result.changed, changed, label + " changed")


func _assert_transfer(
	result: TransferResultScript,
	outcome: int,
	succeeded: bool,
	weapon_detached: bool,
	armor_detached: bool,
	containment_changed: bool,
	label: String,
) -> void:
	_assert_eq(result.outcome, outcome, label + " outcome")
	_assert_eq(result.succeeded, succeeded, label + " succeeded")
	_assert_eq(result.weapon_detached, weapon_detached, label + " weapon detach")
	_assert_eq(result.armor_detached, armor_detached, label + " armor detach")
	_assert_eq(result.equipment_detached, weapon_detached or armor_detached, label + " aggregate detach")
	_assert_eq(result.containment_changed, containment_changed, label + " containment change")


func _assert_endpoint(
	actual: EndpointScript,
	kind: int,
	id: StringName,
	label: String,
) -> void:
	_assert_true(actual != null, label + " exists")
	if actual == null:
		return
	_assert_eq(actual.kind, kind, label + " kind")
	_assert_eq(actual.endpoint_id, id, label + " ID")


func _assert_true(value: bool, label: String) -> void:
	_assertion_count += 1
	if not value:
		_failures.append(label + ": expected true")


func _assert_false(value: bool, label: String) -> void:
	_assertion_count += 1
	if value:
		_failures.append(label + ": expected false")


func _assert_eq(actual: Variant, expected: Variant, label: String) -> void:
	_assertion_count += 1
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])


func _has_property(value: Object, property_name: StringName) -> bool:
	for property: Dictionary in value.get_property_list():
		if StringName(property["name"]) == property_name:
			return true
	return false
