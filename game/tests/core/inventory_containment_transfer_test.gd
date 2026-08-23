extends RefCounted

const ContainmentEndpointScript := preload(
	"res://core/inventory/containment_endpoint.gd"
)
const EquipmentStateScript := preload("res://core/equipment/equipment_state.gd")
const EquippedWeaponRefScript := preload("res://core/equipment/equipped_weapon_ref.gd")
const InventoryStateScript := preload("res://core/inventory/inventory_state.gd")
const TransferDestinationScript := preload(
	"res://core/inventory/inventory_transfer_destination.gd"
)
const TransferResultScript := preload(
	"res://core/inventory/inventory_transfer_result.gd"
)
const TransferServiceScript := preload(
	"res://core/inventory/inventory_transfer_service.gd"
)
const ItemInstanceScript := preload("res://core/items/item_instance.gd")
const SkillIdsScript := preload("res://core/skills/skill_ids.gd")
const WeaponDefinitionScript := preload("res://core/equipment/weapon_definition.gd")

const LARGE_CAPACITY: int = 1_000_000

var _assertion_count: int = 0
var _failures: Array[String] = []


func run_all() -> Dictionary[String, Variant]:
	_test_registration_unparented_and_boundary_validation()
	_test_endpoint_identity_shapes()
	_test_direct_nested_ancestry_and_defensive_queries()
	_test_cycle_prevention()
	_test_weight_propagation_and_ancestor_exception()
	_test_capacity_boundaries_and_legacy_numeric_edges()
	_test_equipment_detach_before_failures()
	_test_equipment_direct_ownership_boundary()
	_test_independent_state_and_result_snapshots()
	return {
		"assertions": _assertion_count,
		"failures": _failures.duplicate(),
	}


func _test_registration_unparented_and_boundary_validation() -> void:
	var inventory: InventoryStateScript = InventoryStateScript.new()
	var service: TransferServiceScript = TransferServiceScript.new()
	var item: ItemInstanceScript = _item(&"item:unparented")
	_assert_true(inventory.register_item(item, 7), "resolved live item registers")
	_assert_true(inventory.is_registered(item.item_instance_id), "registered ID is live")
	_assert_eq(inventory.direct_parent(item.item_instance_id), null, "live clone may be unparented")
	_assert_false(inventory.has_direct_parent(item.item_instance_id), "unparented has no parent fact")
	_assert_eq(inventory.root_holder(item.item_instance_id), null, "unparented has no root holder")
	_assert_eq(inventory.own_weight(item.item_instance_id), 7, "registered own weight")
	_assert_eq(inventory.subtree_weight(item.item_instance_id), 7, "unparented subtree is own weight")
	_assert_false(inventory.register_item(item, 9), "duplicate aggregate ID is rejected")
	_assert_eq(inventory.own_weight(item.item_instance_id), 7, "duplicate does not replace weight")
	_assert_false(
		inventory.register_item(ItemInstanceScript.new(&"", &"definition:test"), 1),
		"empty live instance ID is rejected",
	)

	var character: ContainmentEndpointScript = _character(&"character:owner")
	var invalid_id: TransferResultScript = service.transfer(
		inventory,
		&"",
		_destination(character),
	)
	_assert_transfer(
		invalid_id,
		TransferResultScript.Outcome.INVALID_ITEM_ID,
		false,
		false,
		false,
		"empty transfer item ID",
	)
	var not_registered: TransferResultScript = service.transfer(
		inventory,
		&"item:not_live",
		_destination(character),
	)
	_assert_transfer(
		not_registered,
		TransferResultScript.Outcome.ITEM_NOT_REGISTERED,
		false,
		false,
		false,
		"non-live transfer item",
	)
	var invalid_destination: TransferResultScript = service.transfer(
		inventory,
		item.item_instance_id,
		_destination(ContainmentEndpointScript.new(
			ContainmentEndpointScript.Kind.CHARACTER,
			&"",
		)),
	)
	_assert_transfer(
		invalid_destination,
		TransferResultScript.Outcome.INVALID_DESTINATION,
		false,
		false,
		false,
		"empty destination ID",
	)
	_assert_eq(inventory.direct_parent(item.item_instance_id), null, "invalid destination leaves unparented")
	_assert_true(inventory is RefCounted, "inventory is pure RefCounted state")
	_assert_true(service is RefCounted, "transfer service is pure RefCounted")
	var inventory_variant: Variant = inventory
	var service_variant: Variant = service
	_assert_false(inventory_variant is Node, "inventory has no Node dependency")
	_assert_false(service_variant is Node, "transfer service has no Node dependency")
	_assert_false(
		_has_property(item, &"parent") or _has_property(item, &"direct_parent"),
		"ItemInstance does not duplicate authoritative containment",
	)


func _test_endpoint_identity_shapes() -> void:
	var character: ContainmentEndpointScript = _character(&"holder:same")
	var world: ContainmentEndpointScript = _world(&"holder:same")
	var item: ContainmentEndpointScript = _item_endpoint(&"holder:same")
	_assert_true(character.same_identity(_character(&"holder:same")), "same kind and ID match")
	_assert_false(character.same_identity(world), "same scalar ID in different kinds does not match")
	_assert_false(character.same_identity(item), "item and character namespaces remain distinct")
	_assert_true(item.is_valid(), "corpse/item containment endpoint is representable")
	_assert_endpoint(
		_item_endpoint(&"corpse:legacy_victim"),
		ContainmentEndpointScript.Kind.ITEM,
		&"corpse:legacy_victim",
		"legacy corpse uses item parent shape",
	)


func _test_direct_nested_ancestry_and_defensive_queries() -> void:
	var inventory: InventoryStateScript = InventoryStateScript.new()
	var character: ContainmentEndpointScript = _character(&"character:c")
	var bag_endpoint: ContainmentEndpointScript = _item_endpoint(&"item:bag")
	_register(inventory, &"item:bag", 10)
	_register(inventory, &"item:inside", 3)
	_register(inventory, &"item:direct", 2)
	_place(inventory, &"item:bag", character)
	_place(inventory, &"item:inside", bag_endpoint)
	_place(inventory, &"item:direct", character)

	_assert_true(inventory.is_direct_child(&"item:bag", character), "bag is direct child of C")
	_assert_true(inventory.is_direct_child(&"item:direct", character), "other item is direct child of C")
	_assert_true(inventory.is_direct_child(&"item:inside", bag_endpoint), "inside item direct parent is bag")
	_assert_false(inventory.is_direct_child(&"item:inside", character), "nested item is not direct child of C")
	_assert_true(inventory.is_descendant_of(&"item:inside", character), "nested item descends from C")
	_assert_true(inventory.is_ancestor(character, &"item:inside"), "C is an ancestor of nested item")
	_assert_true(inventory.is_ancestor(bag_endpoint, &"item:inside"), "bag is immediate ancestor")
	_assert_eq(inventory.contents_weight(bag_endpoint), 3, "bag contents exclude bag own weight")

	var direct_children: Array[StringName] = inventory.direct_children(character)
	_assert_eq(direct_children, [&"item:bag", &"item:direct"], "direct children are stable and sorted")
	direct_children.clear()
	_assert_eq(inventory.direct_children(character).size(), 2, "returned children array is defensive")

	var lineage: Array[ContainmentEndpoint] = inventory.ancestry(&"item:inside")
	_assert_eq(lineage.size(), 2, "nested item has item and character ancestors")
	_assert_endpoint(lineage[0], ContainmentEndpointScript.Kind.ITEM, &"item:bag", "direct lineage")
	_assert_endpoint(lineage[1], ContainmentEndpointScript.Kind.CHARACTER, &"character:c", "root lineage")
	var root: ContainmentEndpointScript = inventory.root_holder(&"item:inside")
	_assert_endpoint(root, ContainmentEndpointScript.Kind.CHARACTER, &"character:c", "nested root holder")

	var returned_parent: ContainmentEndpointScript = inventory.direct_parent(&"item:inside")
	returned_parent._endpoint_id = &"item:caller_mutation"
	_assert_endpoint(
		inventory.direct_parent(&"item:inside"),
		ContainmentEndpointScript.Kind.ITEM,
		&"item:bag",
		"parent query is a defensive snapshot",
	)
	root._endpoint_id = &"character:caller_mutation"
	_assert_endpoint(
		inventory.root_holder(&"item:inside"),
		ContainmentEndpointScript.Kind.CHARACTER,
		&"character:c",
		"root query is a defensive snapshot",
	)


func _test_cycle_prevention() -> void:
	var inventory: InventoryStateScript = InventoryStateScript.new()
	var world: ContainmentEndpointScript = _world(&"world:room")
	_register(inventory, &"item:a", 1)
	_register(inventory, &"item:b", 2)
	_register(inventory, &"item:c", 3)
	_register(inventory, &"item:d", 4)
	_place(inventory, &"item:a", world)
	_place(inventory, &"item:b", _item_endpoint(&"item:a"))
	_place(inventory, &"item:c", _item_endpoint(&"item:b"))
	_place(inventory, &"item:d", _item_endpoint(&"item:c"))
	var service: TransferServiceScript = TransferServiceScript.new()

	var self_cycle: TransferResultScript = service.transfer(
		inventory,
		&"item:a",
		_destination(_item_endpoint(&"item:a")),
	)
	_assert_transfer(
		self_cycle,
		TransferResultScript.Outcome.CONTAINMENT_CYCLE,
		false,
		false,
		false,
		"self containment",
	)
	var child_cycle: TransferResultScript = service.transfer(
		inventory,
		&"item:a",
		_destination(_item_endpoint(&"item:b")),
	)
	_assert_eq(child_cycle.outcome, TransferResultScript.Outcome.CONTAINMENT_CYCLE, "A into child B rejects")
	var deep_cycle: TransferResultScript = service.transfer(
		inventory,
		&"item:a",
		_destination(_item_endpoint(&"item:c")),
	)
	_assert_eq(deep_cycle.outcome, TransferResultScript.Outcome.CONTAINMENT_CYCLE, "A into descendant C rejects")
	var deeper_cycle: TransferResultScript = service.transfer(
		inventory,
		&"item:a",
		_destination(_item_endpoint(&"item:d")),
	)
	_assert_eq(deeper_cycle.outcome, TransferResultScript.Outcome.CONTAINMENT_CYCLE, "A into descendant D rejects")
	_assert_true(inventory.is_direct_child(&"item:a", world), "cycle failures keep A in room")
	_assert_true(inventory.is_direct_child(&"item:b", _item_endpoint(&"item:a")), "cycle failures keep B in A")
	_assert_true(inventory.is_direct_child(&"item:c", _item_endpoint(&"item:b")), "cycle failures keep C in B")
	_assert_true(inventory.is_direct_child(&"item:d", _item_endpoint(&"item:c")), "cycle failures keep D in C")
	_assert_eq(inventory.contents_weight(world), 10, "cycle failures preserve full subtree weight")

	var missing_item_destination: TransferResultScript = service.transfer(
		inventory,
		&"item:c",
		_destination(_item_endpoint(&"item:not_registered")),
	)
	_assert_eq(
		missing_item_destination.outcome,
		TransferResultScript.Outcome.INVALID_DESTINATION,
		"unregistered item endpoint is invalid",
	)
	_assert_true(inventory.is_direct_child(&"item:c", _item_endpoint(&"item:b")), "invalid item endpoint does not mutate")


func _test_weight_propagation_and_ancestor_exception() -> void:
	var inventory: InventoryStateScript = InventoryStateScript.new()
	var c1: ContainmentEndpointScript = _character(&"character:c1")
	var c2: ContainmentEndpointScript = _character(&"character:c2")
	var room: ContainmentEndpointScript = _world(&"world:room")
	var bag_endpoint: ContainmentEndpointScript = _item_endpoint(&"item:bag")
	var outer_endpoint: ContainmentEndpointScript = _item_endpoint(&"item:outer")
	_register(inventory, &"item:bag", 10)
	_register(inventory, &"item:inside", 3)
	_register(inventory, &"item:outer", 5)
	_place(inventory, &"item:bag", c1)
	_place(inventory, &"item:inside", bag_endpoint)
	_assert_eq(inventory.subtree_weight(&"item:bag"), 13, "bag subtree counts nested weight once")
	_assert_eq(inventory.contents_weight(c1), 13, "C1 carries bag plus nested item")

	var service: TransferServiceScript = TransferServiceScript.new()
	var promote_inside: TransferResultScript = service.transfer(
		inventory,
		&"item:inside",
		_destination(c1, -100),
	)
	_assert_true(promote_inside.succeeded, "bag to existing ancestor skips even negative capacity")
	_assert_eq(inventory.contents_weight(c1), 13, "bag to C keeps root total")
	_assert_eq(inventory.subtree_weight(&"item:bag"), 10, "bag loses direct child contribution")
	_assert_true(inventory.is_direct_child(&"item:inside", c1), "inside item is now direct child of C1")

	var back_into_bag: TransferResultScript = service.transfer(
		inventory,
		&"item:inside",
		_destination(bag_endpoint, 3),
	)
	_assert_true(back_into_bag.succeeded, "C to bag exact capacity allows")
	_assert_eq(inventory.contents_weight(c1), 13, "C to carried bag keeps root total")

	_place(inventory, &"item:outer", c1)
	_assert_eq(inventory.contents_weight(c1), 18, "outer own weight adds once")
	var bag_into_outer: TransferResultScript = service.transfer(
		inventory,
		&"item:bag",
		_destination(outer_endpoint, 13),
	)
	_assert_true(bag_into_outer.succeeded, "whole bag enters sibling container at exact capacity")
	_assert_eq(inventory.contents_weight(c1), 18, "same-root subtree move preserves root total")
	_assert_eq(inventory.subtree_weight(&"item:outer"), 18, "outer subtree includes bag subtree exactly once")

	_register(inventory, &"item:sibling_target", 1)
	_place(inventory, &"item:sibling_target", c1)
	var sibling_capacity_failure: TransferResultScript = service.transfer(
		inventory,
		&"item:bag",
		_destination(_item_endpoint(&"item:sibling_target"), 12),
	)
	_assert_eq(
		sibling_capacity_failure.outcome,
		TransferResultScript.Outcome.CAPACITY_EXCEEDED,
		"ancestor exception does not apply to a sibling container",
	)
	_assert_true(
		inventory.is_direct_child(&"item:bag", outer_endpoint),
		"sibling capacity rejection preserves the old item parent",
	)

	var bag_to_room: TransferResultScript = service.transfer(
		inventory,
		&"item:bag",
		_destination(room),
	)
	_assert_true(bag_to_room.succeeded, "whole bag moves to room")
	_assert_eq(inventory.contents_weight(c1), 6, "C1 loses full bag subtree")
	_assert_eq(inventory.contents_weight(room), 13, "room gains full bag subtree")

	var bag_to_c2: TransferResultScript = service.transfer(
		inventory,
		&"item:bag",
		_destination(c2),
	)
	_assert_true(bag_to_c2.succeeded, "room to other character succeeds")
	_assert_eq(inventory.contents_weight(room), 0, "room loses subtree")
	_assert_eq(inventory.contents_weight(c2), 13, "C2 gains subtree")
	_assert_eq(inventory.root_holder(&"item:inside").endpoint_id, &"character:c2", "nested root changes to C2")

	_assert_true(inventory.update_own_weight(&"item:inside", 4), "own weight has narrow controlled update")
	_assert_eq(inventory.subtree_weight(&"item:bag"), 14, "updated child weight propagates through bag")
	_assert_eq(inventory.contents_weight(c2), 14, "updated child weight propagates to root")
	_assert_false(inventory.update_own_weight(&"item:missing", 9), "unknown own-weight update rejects")

	var leaf_cross_root: TransferResultScript = service.transfer(
		inventory,
		&"item:inside",
		_destination(c1),
	)
	_assert_true(leaf_cross_root.succeeded, "nested leaf moves between roots")
	_assert_eq(inventory.contents_weight(c2), 10, "old root loses leaf weight once")
	_assert_eq(inventory.contents_weight(c1), 10, "new root gains leaf weight once")
	_assert_eq(inventory.subtree_weight(&"item:bag"), 10, "source bag loses leaf subtree")


func _test_capacity_boundaries_and_legacy_numeric_edges() -> void:
	var inventory: InventoryStateScript = InventoryStateScript.new()
	var source: ContainmentEndpointScript = _world(&"world:source")
	var target: ContainmentEndpointScript = _character(&"character:capacity")
	_register(inventory, &"item:existing", 4)
	_register(inventory, &"item:six", 6)
	_register(inventory, &"item:one", 1)
	_place(inventory, &"item:existing", target)
	_place(inventory, &"item:six", source)
	_place(inventory, &"item:one", source)
	var service: TransferServiceScript = TransferServiceScript.new()

	var exact: TransferResultScript = service.transfer(
		inventory,
		&"item:six",
		_destination(target, 10),
	)
	_assert_transfer(exact, TransferResultScript.Outcome.TRANSFERRED, true, true, false, "exact capacity")
	_assert_eq(inventory.contents_weight(target), 10, "exact capacity reaches cap")
	var over: TransferResultScript = service.transfer(
		inventory,
		&"item:one",
		_destination(target, 10),
	)
	_assert_transfer(over, TransferResultScript.Outcome.CAPACITY_EXCEEDED, false, false, false, "over capacity")
	_assert_true(inventory.is_direct_child(&"item:one", source), "over-cap item remains at source")

	var zero_target: ContainmentEndpointScript = _world(&"world:zero")
	_register(inventory, &"item:positive", 1)
	_register(inventory, &"item:zero", 0)
	var positive_zero_cap: TransferResultScript = service.transfer(
		inventory,
		&"item:positive",
		_destination(zero_target, 0),
	)
	_assert_eq(positive_zero_cap.outcome, TransferResultScript.Outcome.CAPACITY_EXCEEDED, "positive into zero cap rejects")
	var zero_zero_cap: TransferResultScript = service.transfer(
		inventory,
		&"item:zero",
		_destination(zero_target, 0),
	)
	_assert_true(zero_zero_cap.succeeded, "zero weight into explicit zero-cap destination is allowed")
	_assert_eq(inventory.contents_weight(zero_target), 0, "zero-weight child contributes zero")

	var empty_negative_target: ContainmentEndpointScript = _world(&"world:negative_empty")
	_register(inventory, &"item:zero_two", 0)
	var zero_negative_cap: TransferResultScript = service.transfer(
		inventory,
		&"item:zero_two",
		_destination(empty_negative_target, -1),
	)
	_assert_eq(zero_negative_cap.outcome, TransferResultScript.Outcome.CAPACITY_EXCEEDED, "zero exceeds negative cap")

	var negative_target: ContainmentEndpointScript = _world(&"world:negative_weight")
	_register(inventory, &"item:negative", -3)
	var negative_weight: TransferResultScript = service.transfer(
		inventory,
		&"item:negative",
		_destination(negative_target, -2),
	)
	_assert_true(negative_weight.succeeded, "legacy negative weight is not normalized")
	_assert_eq(inventory.contents_weight(negative_target), -3, "negative contents remain observable")

	_register(inventory, &"item:availability", 0)
	var unavailable: TransferResultScript = service.transfer(
		inventory,
		&"item:availability",
		_destination(_world(&"world:unavailable"), 0, false, true),
	)
	_assert_eq(unavailable.outcome, TransferResultScript.Outcome.DESTINATION_UNAVAILABLE, "unavailable destination result")
	var not_capable: TransferResultScript = service.transfer(
		inventory,
		&"item:availability",
		_destination(_world(&"world:not_capable"), 0, true, false),
	)
	_assert_eq(
		not_capable.outcome,
		TransferResultScript.Outcome.DESTINATION_NOT_CONTAINMENT_CAPABLE,
		"explicit containment capability projection rejects",
	)


func _test_equipment_detach_before_failures() -> void:
	var inventory: InventoryStateScript = InventoryStateScript.new()
	var character: ContainmentEndpointScript = _character(&"character:equipped")
	var destination: ContainmentEndpointScript = _world(&"world:too_small")
	_register(inventory, &"weapon:primary", 5)
	_register(inventory, &"item:ordinary", 5)
	_place(inventory, &"weapon:primary", character)
	_place(inventory, &"item:ordinary", character)
	var equipment: EquipmentStateScript = EquipmentStateScript.new()
	equipment.wield(_weapon(&"weapon:primary", &"weapon:def.primary", SkillIdsScript.SWORD), false)
	var service: TransferServiceScript = TransferServiceScript.new()

	var capacity_failure: TransferResultScript = service.transfer(
		inventory,
		&"weapon:primary",
		_destination(destination, 4),
		equipment,
	)
	_assert_transfer(
		capacity_failure,
		TransferResultScript.Outcome.CAPACITY_EXCEEDED,
		false,
		false,
		true,
		"equipped capacity failure preserves partial detach",
	)
	_assert_true(equipment.is_primary_hand_empty(), "capacity failure leaves weapon unequipped")
	_assert_true(inventory.is_direct_child(&"weapon:primary", character), "capacity failure keeps containment")
	_assert_endpoint(capacity_failure.previous_parent, ContainmentEndpointScript.Kind.CHARACTER, &"character:equipped", "failure previous parent")
	_assert_endpoint(capacity_failure.resulting_parent, ContainmentEndpointScript.Kind.CHARACTER, &"character:equipped", "failure resulting parent")

	var ordinary_failure: TransferResultScript = service.transfer(
		inventory,
		&"item:ordinary",
		_destination(destination, 4),
		equipment,
	)
	_assert_transfer(
		ordinary_failure,
		TransferResultScript.Outcome.CAPACITY_EXCEEDED,
		false,
		false,
		false,
		"unwielded capacity failure has no equipment mutation",
	)

	equipment.wield(_weapon(&"weapon:primary", &"weapon:def.primary", SkillIdsScript.SWORD), false)
	var invalid_failure: TransferResultScript = service.transfer(
		inventory,
		&"weapon:primary",
		null,
		equipment,
	)
	_assert_transfer(
		invalid_failure,
		TransferResultScript.Outcome.INVALID_DESTINATION,
		false,
		false,
		true,
		"invalid destination occurs after detach",
	)
	_assert_true(equipment.is_primary_hand_empty(), "invalid destination leaves weapon unequipped")
	_assert_true(inventory.is_direct_child(&"weapon:primary", character), "invalid destination keeps parent")

	equipment.wield(_weapon(&"weapon:primary", &"weapon:def.primary", SkillIdsScript.SWORD), false)
	var unavailable_failure: TransferResultScript = service.transfer(
		inventory,
		&"weapon:primary",
		_destination(_world(&"world:unavailable"), LARGE_CAPACITY, false),
		equipment,
	)
	_assert_transfer(
		unavailable_failure,
		TransferResultScript.Outcome.DESTINATION_UNAVAILABLE,
		false,
		false,
		true,
		"unavailable destination occurs after detach",
	)
	_assert_true(equipment.is_primary_hand_empty(), "unavailable destination leaves weapon unequipped")
	_assert_true(inventory.is_direct_child(&"weapon:primary", character), "unavailable keeps parent")

	## A same-parent low-level move still performs the legacy unequip first.
	equipment.wield(_weapon(&"weapon:primary", &"weapon:def.primary", SkillIdsScript.SWORD), false)
	var same_parent: TransferResultScript = service.transfer(
		inventory,
		&"weapon:primary",
		_destination(character, -999),
		equipment,
	)
	_assert_transfer(
		same_parent,
		TransferResultScript.Outcome.ALREADY_AT_DESTINATION,
		true,
		false,
		true,
		"same-parent move detaches and skips ancestor capacity",
	)
	_assert_true(equipment.is_primary_hand_empty(), "same-parent move leaves weapon unwielded")


func _test_equipment_direct_ownership_boundary() -> void:
	var inventory: InventoryStateScript = InventoryStateScript.new()
	var character: ContainmentEndpointScript = _character(&"character:hands")
	var room: ContainmentEndpointScript = _world(&"world:outside")
	_register(inventory, &"weapon:sword", 4)
	_register(inventory, &"weapon:dagger", 2)
	_register(inventory, &"item:bag", 1)
	_register(inventory, &"weapon:nested", 3)
	_register(inventory, &"weapon:packed", 3)
	_place(inventory, &"weapon:sword", character)
	_place(inventory, &"weapon:dagger", character)
	_place(inventory, &"item:bag", character)
	_place(inventory, &"weapon:nested", _item_endpoint(&"item:bag"))
	_place(inventory, &"weapon:packed", character)
	var equipment: EquipmentStateScript = EquipmentStateScript.new()
	equipment.wield(_weapon(&"weapon:sword", &"weapon:def.sword", SkillIdsScript.SWORD), false)
	equipment.wield(_weapon(&"weapon:dagger", &"weapon:def.dagger", SkillIdsScript.DAGGER, true), false)
	_assert_eq(
		inventory.contents_weight(character),
		13,
		"wielded status does not reduce direct or nested carried weight",
	)
	var service: TransferServiceScript = TransferServiceScript.new()

	var primary_move: TransferResultScript = service.transfer(
		inventory,
		&"weapon:sword",
		_destination(room),
		equipment,
	)
	_assert_true(primary_move.succeeded, "direct equipped primary transfers")
	_assert_true(primary_move.equipment_detached, "direct primary detach is reported")
	_assert_true(equipment.is_primary_hand_empty(), "primary clears")
	_assert_false(equipment.is_secondary_hand_empty(), "secondary is not promoted or cleared")
	_assert_eq(equipment.secondary_weapon().instance_id, &"weapon:dagger", "secondary identity remains")
	_assert_false(equipment.has_weapon_instance(&"weapon:sword"), "successful transfer leaves no primary ref")

	var bag_move: TransferResultScript = service.transfer(
		inventory,
		&"item:bag",
		_destination(room),
		equipment,
	)
	_assert_true(bag_move.succeeded, "bag containing nested weapon transfers")
	_assert_false(bag_move.equipment_detached, "ordinary bag does not detach equipment")
	_assert_true(equipment.has_weapon_instance(&"weapon:dagger"), "nested bag move does not touch direct equipped dagger")
	_assert_eq(inventory.root_holder(&"weapon:nested").endpoint_id, &"world:outside", "nested weapon follows bag root")
	_assert_false(inventory.is_direct_child(&"weapon:nested", room), "nested weapon remains non-direct")

	var secondary_move: TransferResultScript = service.transfer(
		inventory,
		&"weapon:dagger",
		_destination(room),
		equipment,
	)
	_assert_true(secondary_move.succeeded, "direct equipped secondary transfers")
	_assert_true(secondary_move.equipment_detached, "secondary detach is reported")
	_assert_true(equipment.are_both_hands_empty(), "secondary clears without hand normalization")

	equipment.wield(_weapon(&"weapon:packed", &"weapon:def.packed", SkillIdsScript.SWORD), false)
	var character_to_bag: TransferResultScript = service.transfer(
		inventory,
		&"weapon:packed",
		_destination(_item_endpoint(&"item:bag")),
		equipment,
	)
	_assert_true(character_to_bag.succeeded, "character to bag transfer succeeds")
	_assert_true(character_to_bag.equipment_detached, "character to bag detaches equipped item")
	_assert_true(equipment.are_both_hands_empty(), "character to bag clears hand reference")

	var room_to_character: TransferResultScript = service.transfer(
		inventory,
		&"weapon:sword",
		_destination(character),
		equipment,
	)
	_assert_true(room_to_character.succeeded, "room to character transfer succeeds")
	_assert_true(equipment.are_both_hands_empty(), "room to character does not auto-equip")
	var bag_to_character: TransferResultScript = service.transfer(
		inventory,
		&"weapon:nested",
		_destination(character),
		equipment,
	)
	_assert_true(bag_to_character.succeeded, "bag to character transfer succeeds")
	_assert_true(equipment.are_both_hands_empty(), "bag to character does not auto-equip")


func _test_independent_state_and_result_snapshots() -> void:
	var first: InventoryStateScript = InventoryStateScript.new()
	var second: InventoryStateScript = InventoryStateScript.new()
	var shared_identity_first: ItemInstanceScript = _item(&"item:same_id")
	var shared_identity_second: ItemInstanceScript = _item(&"item:same_id")
	_assert_true(first.register_item(shared_identity_first, 1), "first aggregate registers ID")
	_assert_true(second.register_item(shared_identity_second, 9), "second aggregate independently registers same ID")
	var first_world: ContainmentEndpointScript = _world(&"world:first")
	var second_world: ContainmentEndpointScript = _world(&"world:second")
	var first_result: TransferResultScript = TransferServiceScript.new().transfer(
		first,
		&"item:same_id",
		_destination(first_world),
	)
	_place(second, &"item:same_id", second_world)
	_assert_eq(first.contents_weight(first_world), 1, "first aggregate own weight isolated")
	_assert_eq(second.contents_weight(second_world), 9, "second aggregate own weight isolated")
	_assert_eq(first.root_holder(&"item:same_id").endpoint_id, &"world:first", "first root isolated")
	_assert_eq(second.root_holder(&"item:same_id").endpoint_id, &"world:second", "second root isolated")

	var returned_result_parent: ContainmentEndpointScript = first_result.resulting_parent
	returned_result_parent._endpoint_id = &"world:caller_changed"
	_assert_eq(first_result.resulting_parent.endpoint_id, &"world:first", "result parent getter is defensive")
	_assert_eq(first.root_holder(&"item:same_id").endpoint_id, &"world:first", "result mutation cannot change inventory")
	_assert_true(first_result is RefCounted, "transfer result is pure snapshot object")
	var result_variant: Variant = first_result
	_assert_false(result_variant is Node, "transfer result has no Node dependency")


func _register(inventory: InventoryStateScript, item_instance_id: StringName, weight: int) -> void:
	_assert_true(inventory.register_item(_item(item_instance_id), weight), "register %s" % item_instance_id)


func _place(
	inventory: InventoryStateScript,
	item_instance_id: StringName,
	endpoint: ContainmentEndpointScript,
) -> void:
	var result: TransferResultScript = TransferServiceScript.new().transfer(
		inventory,
		item_instance_id,
		_destination(endpoint),
	)
	_assert_true(result.succeeded, "place %s" % item_instance_id)


func _item(item_instance_id: StringName) -> ItemInstanceScript:
	return ItemInstanceScript.new(item_instance_id, &"definition:test")


func _character(endpoint_id: StringName) -> ContainmentEndpointScript:
	return ContainmentEndpointScript.new(ContainmentEndpointScript.Kind.CHARACTER, endpoint_id)


func _item_endpoint(endpoint_id: StringName) -> ContainmentEndpointScript:
	return ContainmentEndpointScript.new(ContainmentEndpointScript.Kind.ITEM, endpoint_id)


func _world(endpoint_id: StringName) -> ContainmentEndpointScript:
	return ContainmentEndpointScript.new(ContainmentEndpointScript.Kind.WORLD, endpoint_id)


func _destination(
	endpoint: ContainmentEndpointScript,
	maximum_contents_weight: int = LARGE_CAPACITY,
	is_available: bool = true,
	is_containment_capable: bool = true,
) -> TransferDestinationScript:
	return TransferDestinationScript.new(
		endpoint,
		is_available,
		is_containment_capable,
		maximum_contents_weight,
	)


func _weapon(
	instance_id: StringName,
	weapon_id: StringName,
	skill_type: StringName,
	can_wield_as_secondary: bool = false,
) -> EquippedWeaponRefScript:
	return EquippedWeaponRefScript.new(
		instance_id,
		WeaponDefinitionScript.new(
			weapon_id,
			skill_type,
			can_wield_as_secondary,
			false,
			"reference/es2/mudlib/test-fixture",
		),
	)


func _assert_endpoint(
	endpoint: ContainmentEndpointScript,
	expected_kind: int,
	expected_id: StringName,
	label: String,
) -> void:
	_assert_true(endpoint != null, label + " exists")
	if endpoint == null:
		return
	_assert_eq(endpoint.kind, expected_kind, label + " kind")
	_assert_eq(endpoint.endpoint_id, expected_id, label + " ID")


func _assert_transfer(
	result: TransferResultScript,
	expected_outcome: int,
	expected_succeeded: bool,
	expected_containment_changed: bool,
	expected_equipment_detached: bool,
	label: String,
) -> void:
	_assert_eq(result.outcome, expected_outcome, label + " outcome")
	_assert_eq(result.succeeded, expected_succeeded, label + " succeeded")
	_assert_eq(result.containment_changed, expected_containment_changed, label + " containment changed")
	_assert_eq(result.equipment_detached, expected_equipment_detached, label + " equipment detached")


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


func _has_property(value: Object, property_name: StringName) -> bool:
	for property: Dictionary in value.get_property_list():
		if StringName(property["name"]) == property_name:
			return true
	return false
