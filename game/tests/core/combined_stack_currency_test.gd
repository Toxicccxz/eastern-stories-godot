extends RefCounted

const StackDefinitionScript := preload(
	"res://core/items/combined/combined_stack_definition.gd"
)
const StackStateScript := preload(
	"res://core/items/combined/combined_stack_state.gd"
)
const StackCollectionScript := preload(
	"res://core/items/combined/combined_stack_collection.gd"
)
const AmountResultScript := preload(
	"res://core/items/combined/combined_stack_amount_result.gd"
)
const SplitResultScript := preload(
	"res://core/items/combined/combined_stack_split_result.gd"
)
const MergeResultScript := preload(
	"res://core/items/combined/combined_stack_merge_result.gd"
)
const StackServiceScript := preload(
	"res://core/items/combined/combined_stack_service.gd"
)
const CurrencyDefinitionScript := preload(
	"res://core/items/combined/currency_definition.gd"
)
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
const EquipmentStateScript := preload("res://core/equipment/equipment_state.gd")
const EquippedWeaponRefScript := preload("res://core/equipment/equipped_weapon_ref.gd")
const WeaponDefinitionScript := preload("res://core/equipment/weapon_definition.gd")
const SkillIdsScript := preload("res://core/skills/skill_ids.gd")

const LARGE_CAPACITY: int = 1_000_000

var _assertion_count: int = 0
var _failures: Array[String] = []


func run_all() -> Dictionary[String, Variant]:
	_test_definition_state_and_initial_zero()
	_test_set_amount_positive_negative_zero()
	_test_add_amount_boundaries_and_throwing_final_unit()
	_test_nested_stack_weight_projection()
	_test_independent_instances_and_exact_compatibility()
	_test_split_semantics_and_boundaries()
	_test_character_merge_survivor_weight_and_multiple_siblings()
	_test_merge_destination_direct_only_and_incompatible()
	_test_merge_equipment_cleanup_and_identity()
	_test_merge_transfer_failure_and_contained_stack_guard()
	_test_currency_and_generic_combined_value_boundary()
	return {
		"assertions": _assertion_count,
		"failures": _failures.duplicate(),
	}


func _test_definition_state_and_initial_zero() -> void:
	var definition: StackDefinitionScript = _definition(&"item:def.coin", &"/obj/money/coin", 1)
	_assert_eq(definition.item_definition_id, &"item:def.coin", "definition ID exact")
	_assert_eq(definition.stack_compatibility_id, &"/obj/money/coin", "compatibility ID exact")
	_assert_eq(definition.base_weight, 1, "base weight exact")

	var inventory: InventoryStateScript = InventoryStateScript.new()
	var stacks: StackCollectionScript = StackCollectionScript.new()
	var item: ItemInstanceScript = _item(&"stack:raw_zero", definition.item_definition_id)
	_assert_true(inventory.register_item(item, 99), "raw zero live item registers")
	var registration: AmountResultScript = StackServiceScript.register_stack(
		stacks,
		inventory,
		item,
		definition,
		0,
	)
	_assert_eq(registration.outcome, AmountResultScript.Outcome.REGISTERED, "raw zero registers")
	_assert_true(registration.accepted, "raw zero registration accepted")
	_assert_eq(stacks.stack_state(item.item_instance_id).amount, 0, "raw static amount may be zero")
	_assert_eq(inventory.own_weight(item.item_instance_id), 99, "raw zero does not invent set_amount weight mutation")
	_assert_eq(registration.lifecycle_action, AmountResultScript.LifecycleAction.NONE, "construction zero is no lifecycle request")

	var zero_request: AmountResultScript = StackServiceScript.set_amount(
		stacks,
		inventory,
		item.item_instance_id,
		0,
	)
	_assert_eq(zero_request.outcome, AmountResultScript.Outcome.DELAYED_DESTRUCTION_REQUESTED, "explicit zero requests lifecycle")
	_assert_eq(zero_request.lifecycle_delay_seconds, 1, "explicit zero delay is one second")
	_assert_true(inventory.is_registered(item.item_instance_id), "zero request leaves item live")
	_assert_eq(stacks.stack_state(item.item_instance_id).amount, 0, "raw zero remains observable")
	_assert_eq(inventory.own_weight(item.item_instance_id), 99, "explicit raw zero preserves old weight")

	var raw_move_item: ItemInstanceScript = _item(&"stack:raw_zero_move", definition.item_definition_id)
	_assert_true(inventory.register_item(raw_move_item, 0), "second raw zero live item registers")
	StackServiceScript.register_stack(stacks, inventory, raw_move_item, definition, 0)
	var world: EndpointScript = _world(&"world:raw_zero")
	var character: EndpointScript = _character(&"character:raw_zero")
	_place(inventory, raw_move_item.item_instance_id, world)
	var living_move: MergeResultScript = StackServiceScript.transfer_and_merge(
		stacks,
		inventory,
		raw_move_item.item_instance_id,
		_destination(character),
		null,
		EquipmentStateScript.new(),
	)
	_assert_eq(living_move.outcome, MergeResultScript.Outcome.MOVED_NO_COMPATIBLE_STACK, "raw zero still completes living move")
	_assert_eq(living_move.lifecycle_action, AmountResultScript.LifecycleAction.DELAYED_DESTRUCTION, "living move calls set_amount zero")
	_assert_eq(living_move.lifecycle_delay_seconds, 1, "living raw-zero merge delay")
	_assert_eq(stacks.stack_state(raw_move_item.item_instance_id).amount, 0, "living raw zero remains observable")
	_assert_true(inventory.is_direct_child(raw_move_item.item_instance_id, character), "raw zero remains live at character until runtime destruction")
	_assert_true(stacks is RefCounted, "stack aggregate is pure RefCounted")
	var stacks_variant: Variant = stacks
	_assert_false(stacks_variant is Node, "stack aggregate has no Node dependency")

	var plain_same_definition: ItemInstanceScript = _item(
		&"item:plain_same_definition",
		definition.item_definition_id,
	)
	_assert_true(inventory.register_item(plain_same_definition, 7), "plain same-definition item registers")
	var plain_stack_attempt: AmountResultScript = StackServiceScript.set_amount(
		stacks,
		inventory,
		plain_same_definition.item_instance_id,
		3,
	)
	_assert_eq(plain_stack_attempt.outcome, AmountResultScript.Outcome.INVALID_INSTANCE, "plain item has no implicit stack capability")
	_assert_eq(inventory.own_weight(plain_same_definition.item_instance_id), 7, "rejected plain item stack transition leaves weight")


func _test_set_amount_positive_negative_zero() -> void:
	var inventory: InventoryStateScript = InventoryStateScript.new()
	var stacks: StackCollectionScript = StackCollectionScript.new()
	var definition: StackDefinitionScript = _definition(&"item:def.weighted", &"/stack/weighted", 3)
	_register_stack(inventory, stacks, &"stack:set", definition, 2)
	var one: AmountResultScript = StackServiceScript.set_amount(stacks, inventory, &"stack:set", 1)
	_assert_eq(one.amount_after, 1, "positive set one stores amount")
	_assert_eq(inventory.own_weight(&"stack:set"), 3, "positive set one weight")

	var five: AmountResultScript = StackServiceScript.set_amount(stacks, inventory, &"stack:set", 5)
	_assert_eq(five.outcome, AmountResultScript.Outcome.UPDATED, "positive set outcome")
	_assert_eq(five.amount_before, 1, "positive amount before")
	_assert_eq(five.amount_after, 5, "positive amount after")
	_assert_eq(five.own_weight_after, 15, "positive weight result")
	_assert_eq(inventory.own_weight(&"stack:set"), 15, "inventory weight synchronized")

	var character: EndpointScript = _character(&"character:set_owner")
	_place(inventory, &"stack:set", character)
	var negative: AmountResultScript = StackServiceScript.set_amount(stacks, inventory, &"stack:set", -1)
	_assert_eq(negative.outcome, AmountResultScript.Outcome.LEGACY_NEGATIVE_AMOUNT_ERROR, "negative typed legacy error")
	_assert_false(negative.accepted, "negative request rejected")
	_assert_eq(stacks.stack_state(&"stack:set").amount, 5, "negative leaves amount")
	_assert_eq(inventory.own_weight(&"stack:set"), 15, "negative leaves weight")
	_assert_eq(negative.lifecycle_action, AmountResultScript.LifecycleAction.NONE, "negative has no lifecycle intent")
	_assert_true(inventory.is_direct_child(&"stack:set", character), "negative leaves containment")
	_assert_eq(inventory.root_holder(&"stack:set").endpoint_id, character.endpoint_id, "negative leaves root")

	var zero: AmountResultScript = StackServiceScript.set_amount(stacks, inventory, &"stack:set", 0)
	_assert_true(zero.accepted, "zero request accepted as lifecycle intent")
	_assert_false(zero.amount_changed, "zero does not store amount")
	_assert_eq(zero.amount_before, 5, "zero amount before")
	_assert_eq(zero.amount_after, 5, "zero amount remains old")
	_assert_eq(zero.own_weight_before, 15, "zero weight before")
	_assert_eq(zero.own_weight_after, 15, "zero weight remains old")
	_assert_eq(zero.lifecycle_action, AmountResultScript.LifecycleAction.DELAYED_DESTRUCTION, "zero lifecycle kind")
	_assert_eq(zero.lifecycle_delay_seconds, 1, "zero exact delay")
	_assert_true(inventory.is_direct_child(&"stack:set", character), "zero leaves containment")
	_assert_eq(inventory.contents_weight(character), 15, "zero leaves ancestor load")
	var root_after_first_zero: EndpointScript = inventory.root_holder(&"stack:set")
	_assert_eq(root_after_first_zero.kind, EndpointScript.Kind.CHARACTER, "zero leaves root kind")
	_assert_eq(root_after_first_zero.endpoint_id, character.endpoint_id, "zero leaves root identity")

	var repeated_zero: AmountResultScript = StackServiceScript.set_amount(
		stacks,
		inventory,
		&"stack:set",
		0,
	)
	_assert_eq(repeated_zero.outcome, AmountResultScript.Outcome.DELAYED_DESTRUCTION_REQUESTED, "repeated zero emits another intent")
	_assert_eq(repeated_zero.amount_after, 5, "repeated zero preserves observable amount")
	_assert_eq(repeated_zero.own_weight_after, 15, "repeated zero preserves observable weight")
	_assert_eq(repeated_zero.lifecycle_delay_seconds, 1, "repeated zero keeps one-second delay")
	_assert_true(inventory.is_direct_child(&"stack:set", character), "repeated zero leaves parent")
	_assert_eq(inventory.contents_weight(character), 15, "repeated zero leaves root load")


func _test_add_amount_boundaries_and_throwing_final_unit() -> void:
	var inventory: InventoryStateScript = InventoryStateScript.new()
	var stacks: StackCollectionScript = StackCollectionScript.new()
	var definition: StackDefinitionScript = _definition(&"item:def.throw", &"/obj/weapon/dart", 40)
	_register_stack(inventory, stacks, &"stack:add", definition, 5)

	var plus_two: AmountResultScript = StackServiceScript.add_amount(stacks, inventory, &"stack:add", 2)
	_assert_eq(plus_two.amount_after, 7, "add positive delegates to set")
	_assert_eq(inventory.own_weight(&"stack:add"), 280, "add positive weight")
	var minus_two: AmountResultScript = StackServiceScript.add_amount(stacks, inventory, &"stack:add", -2)
	_assert_eq(minus_two.amount_after, 5, "add negative delta positive result")
	_assert_eq(inventory.own_weight(&"stack:add"), 200, "subtract weight")
	var exact_zero: AmountResultScript = StackServiceScript.add_amount(stacks, inventory, &"stack:add", -5)
	_assert_eq(exact_zero.outcome, AmountResultScript.Outcome.DELAYED_DESTRUCTION_REQUESTED, "add exact zero lifecycle")
	_assert_eq(stacks.stack_state(&"stack:add").amount, 5, "add exact zero retains old amount")
	_assert_eq(inventory.own_weight(&"stack:add"), 200, "add exact zero retains old weight")
	var below_zero: AmountResultScript = StackServiceScript.add_amount(stacks, inventory, &"stack:add", -6)
	_assert_eq(below_zero.outcome, AmountResultScript.Outcome.LEGACY_NEGATIVE_AMOUNT_ERROR, "add below zero error")
	_assert_eq(stacks.stack_state(&"stack:add").amount, 5, "add below zero leaves amount")

	_register_stack(inventory, stacks, &"stack:last_throw", definition, 1)
	var final_unit: AmountResultScript = StackServiceScript.add_amount(
		stacks,
		inventory,
		&"stack:last_throw",
		-1,
	)
	_assert_eq(final_unit.outcome, AmountResultScript.Outcome.DELAYED_DESTRUCTION_REQUESTED, "throwing final unit schedules destruction")
	_assert_eq(stacks.stack_state(&"stack:last_throw").amount, 1, "throwing final unit remains one")
	_assert_eq(inventory.own_weight(&"stack:last_throw"), 40, "throwing final unit keeps weight")
	_assert_eq(final_unit.lifecycle_delay_seconds, 1, "throwing final delay")


func _test_nested_stack_weight_projection() -> void:
	var inventory: InventoryStateScript = InventoryStateScript.new()
	var stacks: StackCollectionScript = StackCollectionScript.new()
	var definition: StackDefinitionScript = _definition(&"item:def.nested_weight", &"/obj/nested_weight", 3)
	var character: EndpointScript = _character(&"character:nested_weight")
	_register_plain_item(inventory, &"container:weighted_bag", 10)
	_register_stack(inventory, stacks, &"stack:nested_weight", definition, 2)
	_place(inventory, &"container:weighted_bag", character)
	_place(inventory, &"stack:nested_weight", _item_endpoint(&"container:weighted_bag"))
	_assert_eq(inventory.subtree_weight(&"container:weighted_bag"), 16, "nested initial bag subtree")
	_assert_eq(inventory.contents_weight(character), 16, "nested initial character load")

	var update: AmountResultScript = StackServiceScript.set_amount(
		stacks,
		inventory,
		&"stack:nested_weight",
		4,
	)
	_assert_eq(update.amount_after, 4, "nested positive amount updates")
	_assert_eq(inventory.own_weight(&"stack:nested_weight"), 12, "nested stack own weight updates once")
	_assert_eq(inventory.subtree_weight(&"container:weighted_bag"), 22, "nested bag subtree derives new weight")
	_assert_eq(inventory.contents_weight(character), 22, "nested character load derives new weight")


func _test_independent_instances_and_exact_compatibility() -> void:
	var inventory: InventoryStateScript = InventoryStateScript.new()
	var stacks: StackCollectionScript = StackCollectionScript.new()
	var same_a: StackDefinitionScript = _definition(&"item:def.same", &"/Obj/Exact.Path", 2)
	var same_b: StackDefinitionScript = _definition(&"item:def.same", &"/Obj/Exact.Path", 2)
	var different_case: StackDefinitionScript = _definition(&"item:def.same", &"/obj/exact.path", 2)
	_register_stack(inventory, stacks, &"stack:a", same_a, 2)
	_register_stack(inventory, stacks, &"stack:b", same_b, 5)
	_register_stack(inventory, stacks, &"stack:c", different_case, 2)
	_assert_true(stacks.are_compatible(&"stack:a", &"stack:b"), "exact compatibility IDs match")
	_assert_false(stacks.are_compatible(&"stack:a", &"stack:c"), "compatibility is case-sensitive and exact")
	StackServiceScript.set_amount(stacks, inventory, &"stack:a", 4)
	_assert_eq(stacks.stack_state(&"stack:a").amount, 4, "A amount mutates")
	_assert_eq(stacks.stack_state(&"stack:b").amount, 5, "B state is independent")
	var returned_state: StackStateScript = stacks.stack_state(&"stack:a")
	returned_state._amount = 999
	_assert_eq(stacks.stack_state(&"stack:a").amount, 4, "state query is defensive snapshot")

	var second_collection: StackCollectionScript = StackCollectionScript.new()
	var second_inventory: InventoryStateScript = InventoryStateScript.new()
	_register_stack(second_inventory, second_collection, &"stack:a", same_a, 9)
	_assert_eq(second_collection.stack_state(&"stack:a").amount, 9, "collections do not share state")
	_assert_eq(stacks.stack_state(&"stack:a").amount, 4, "first collection remains independent")


func _test_split_semantics_and_boundaries() -> void:
	var inventory: InventoryStateScript = InventoryStateScript.new()
	var stacks: StackCollectionScript = StackCollectionScript.new()
	var definition: StackDefinitionScript = _definition(&"item:def.split", &"/obj/split", 3)
	_register_stack(inventory, stacks, &"stack:source", definition, 10)
	var character: EndpointScript = _character(&"character:split")
	_place(inventory, &"stack:source", character)
	var split_item: ItemInstanceScript = _item(&"stack:new", definition.item_definition_id)
	var result: SplitResultScript = StackServiceScript.split(
		stacks,
		inventory,
		&"stack:source",
		4,
		split_item,
	)
	_assert_eq(result.outcome, SplitResultScript.Outcome.SPLIT, "partial split succeeds")
	_assert_true(result.succeeded, "split success flag")
	_assert_eq(result.source_amount_before, 10, "split source before")
	_assert_eq(result.source_amount_after, 6, "split source after")
	_assert_eq(result.new_amount, 4, "split new amount")
	_assert_eq(result.source_weight_after, 18, "split source weight")
	_assert_eq(result.new_weight, 12, "split new weight")
	_assert_eq(inventory.contents_weight(character), 18, "unparented new stack not yet in root load")
	_assert_eq(inventory.own_weight(&"stack:new"), 12, "new own weight registered")
	_assert_false(inventory.has_direct_parent(&"stack:new"), "new split clone starts unparented")
	_assert_eq(stacks.stack_definition(&"stack:new").item_definition_id, definition.item_definition_id, "split preserves definition identity")
	_assert_eq(stacks.stack_definition(&"stack:new").stack_compatibility_id, definition.stack_compatibility_id, "split preserves compatibility identity")
	_assert_false(result.source_instance_id == result.new_instance_id, "split uses distinct caller ID")
	_assert_eq(inventory.own_weight(&"stack:source") + inventory.own_weight(&"stack:new"), 30, "split conserves combined own weight")

	for invalid_amount: int in [0, -1]:
		var invalid_nonpositive: SplitResultScript = StackServiceScript.split(
			stacks,
			inventory,
			&"stack:source",
			invalid_amount,
			_item(&"stack:invalid_%s" % invalid_amount, definition.item_definition_id),
		)
		_assert_eq(invalid_nonpositive.outcome, SplitResultScript.Outcome.REQUEST_NOT_POSITIVE, "nonpositive split rejects")
	for invalid_amount: int in [6, 7]:
		var invalid_partial: SplitResultScript = StackServiceScript.split(
			stacks,
			inventory,
			&"stack:source",
			invalid_amount,
			_item(&"stack:too_many_%s" % invalid_amount, definition.item_definition_id),
		)
		_assert_eq(invalid_partial.outcome, SplitResultScript.Outcome.REQUEST_NOT_PARTIAL, "equal/over split is not primitive split")
	var duplicate: SplitResultScript = StackServiceScript.split(
		stacks,
		inventory,
		&"stack:source",
		1,
		_item(&"stack:new", definition.item_definition_id),
	)
	_assert_eq(duplicate.outcome, SplitResultScript.Outcome.NEW_INSTANCE_ALREADY_REGISTERED, "duplicate new ID rejects")
	var mismatch: SplitResultScript = StackServiceScript.split(
		stacks,
		inventory,
		&"stack:source",
		1,
		_item(&"stack:mismatch", &"item:def.other"),
	)
	_assert_eq(mismatch.outcome, SplitResultScript.Outcome.DEFINITION_MISMATCH, "split definition mismatch rejects")
	_assert_eq(stacks.stack_state(&"stack:source").amount, 6, "invalid splits leave source")

	var unrelated_inventory: InventoryStateScript = InventoryStateScript.new()
	var wrong_aggregate: SplitResultScript = StackServiceScript.split(
		stacks,
		unrelated_inventory,
		&"stack:source",
		1,
		_item(&"stack:wrong_aggregate", definition.item_definition_id),
	)
	_assert_eq(wrong_aggregate.outcome, SplitResultScript.Outcome.INVALID_SOURCE_INSTANCE, "split rejects source absent from supplied inventory")
	_assert_eq(stacks.stack_state(&"stack:source").amount, 6, "wrong aggregate cannot mutate source amount")
	_assert_eq(inventory.own_weight(&"stack:source"), 18, "wrong aggregate cannot desynchronize source weight")
	_assert_false(unrelated_inventory.is_registered(&"stack:wrong_aggregate"), "wrong aggregate creates no new live stack")


func _test_character_merge_survivor_weight_and_multiple_siblings() -> void:
	var inventory: InventoryStateScript = InventoryStateScript.new()
	var stacks: StackCollectionScript = StackCollectionScript.new()
	var definition: StackDefinitionScript = _definition(&"item:def.merge", &"/obj/merge", 3)
	_register_stack(inventory, stacks, &"stack:moved", definition, 2)
	_register_stack(inventory, stacks, &"stack:b", definition, 5)
	_register_stack(inventory, stacks, &"stack:c", definition, 4)
	var room: EndpointScript = _world(&"world:merge_source")
	var character: EndpointScript = _character(&"character:merge")
	_place(inventory, &"stack:moved", room)
	_place(inventory, &"stack:b", character)
	_place(inventory, &"stack:c", character)
	_assert_eq(inventory.contents_weight(character), 27, "pre-merge sibling weight")
	var result: MergeResultScript = StackServiceScript.transfer_and_merge(
		stacks,
		inventory,
		&"stack:moved",
		_destination(character),
		null,
		EquipmentStateScript.new(),
	)
	_assert_eq(result.outcome, MergeResultScript.Outcome.MERGED, "character move merges")
	_assert_true(result.succeeded, "merge succeeds")
	_assert_true(result.merge_applied, "merge applied")
	_assert_eq(result.surviving_instance_id, &"stack:moved", "moved instance survives")
	_assert_eq(result.amount_before, 2, "merge moved amount before")
	_assert_eq(result.total_absorbed_amount, 9, "multiple sibling amount absorbed")
	_assert_eq(result.amount_after, 11, "merge final amount")
	_assert_eq(result.absorbed_instance_ids, [&"stack:b", &"stack:c"], "absorbed IDs deterministic")
	_assert_true(stacks.has_stack(&"stack:moved"), "moved state remains live")
	_assert_false(stacks.has_stack(&"stack:b"), "first sibling state removed")
	_assert_false(stacks.has_stack(&"stack:c"), "second sibling state removed")
	_assert_true(inventory.is_registered(&"stack:moved"), "moved inventory instance remains")
	_assert_false(inventory.is_registered(&"stack:b"), "absorbed inventory instance removed")
	_assert_false(inventory.is_registered(&"stack:c"), "all absorbed inventory instances removed")
	_assert_eq(inventory.own_weight(&"stack:moved"), 33, "survivor weight includes all amounts")
	_assert_eq(inventory.contents_weight(character), 33, "character weight has no double counting")
	_assert_eq(inventory.direct_children(character), [&"stack:moved"], "only survivor remains direct")
	var returned_ids: Array[StringName] = result.absorbed_instance_ids
	returned_ids.clear()
	_assert_eq(result.absorbed_instance_ids.size(), 2, "merge result IDs are defensive")


func _test_merge_destination_direct_only_and_incompatible() -> void:
	var definition: StackDefinitionScript = _definition(&"item:def.dest", &"/obj/dest", 2)
	for endpoint_kind: int in [EndpointScript.Kind.WORLD, EndpointScript.Kind.ITEM]:
		var inventory: InventoryStateScript = InventoryStateScript.new()
		var stacks: StackCollectionScript = StackCollectionScript.new()
		_register_stack(inventory, stacks, &"stack:a", definition, 2)
		_register_stack(inventory, stacks, &"stack:b", definition, 5)
		var destination_endpoint: EndpointScript
		if endpoint_kind == EndpointScript.Kind.WORLD:
			destination_endpoint = _world(&"world:no_merge")
		else:
			_register_plain_item(inventory, &"container:bag", 1)
			destination_endpoint = _item_endpoint(&"container:bag")
		_place(inventory, &"stack:b", destination_endpoint)
		var result: MergeResultScript = StackServiceScript.transfer_and_merge(
			stacks,
			inventory,
			&"stack:a",
			_destination(destination_endpoint),
		)
		_assert_eq(result.outcome, MergeResultScript.Outcome.MOVED_NO_MERGE_DESTINATION, "non-character destination never merges")
		_assert_eq(stacks.stack_state(&"stack:a").amount, 2, "moved amount unchanged outside living")
		_assert_eq(stacks.stack_state(&"stack:b").amount, 5, "existing stack remains outside living")

	## Corpse is an ITEM endpoint and follows the same no-merge rule.
	var corpse_inventory: InventoryStateScript = InventoryStateScript.new()
	var corpse_stacks: StackCollectionScript = StackCollectionScript.new()
	_register_stack(corpse_inventory, corpse_stacks, &"stack:corpse_a", definition, 1)
	_register_stack(corpse_inventory, corpse_stacks, &"stack:corpse_b", definition, 2)
	_register_plain_item(corpse_inventory, &"corpse:victim", 0)
	var corpse: EndpointScript = _item_endpoint(&"corpse:victim")
	_place(corpse_inventory, &"stack:corpse_b", corpse)
	var corpse_result: MergeResultScript = StackServiceScript.transfer_and_merge(
		corpse_stacks,
		corpse_inventory,
		&"stack:corpse_a",
		_destination(corpse),
	)
	_assert_eq(corpse_result.outcome, MergeResultScript.Outcome.MOVED_NO_MERGE_DESTINATION, "corpse item endpoint does not merge")

	var direct_inventory: InventoryStateScript = InventoryStateScript.new()
	var direct_stacks: StackCollectionScript = StackCollectionScript.new()
	var character: EndpointScript = _character(&"character:direct_only")
	_register_plain_item(direct_inventory, &"container:nested", 1)
	_place(direct_inventory, &"container:nested", character)
	_register_stack(direct_inventory, direct_stacks, &"stack:nested", definition, 5)
	_register_stack(direct_inventory, direct_stacks, &"stack:moving", definition, 2)
	_place(direct_inventory, &"stack:nested", _item_endpoint(&"container:nested"))
	var direct_result: MergeResultScript = StackServiceScript.transfer_and_merge(
		direct_stacks,
		direct_inventory,
		&"stack:moving",
		_destination(character),
		null,
		EquipmentStateScript.new(),
	)
	_assert_eq(direct_result.outcome, MergeResultScript.Outcome.MOVED_NO_COMPATIBLE_STACK, "nested compatible stack is ignored")
	_assert_eq(direct_stacks.stack_state(&"stack:moving").amount, 2, "direct moved stack unchanged")
	_assert_eq(direct_stacks.stack_state(&"stack:nested").amount, 5, "nested stack remains independent")

	var incompatible: StackDefinitionScript = _definition(&"item:def.dest", &"/obj/other_exact", 2)
	_register_stack(direct_inventory, direct_stacks, &"stack:incompatible", incompatible, 3)
	_place(direct_inventory, &"stack:incompatible", character)
	var second_moved: ItemInstanceScript = _item(&"stack:second_moved", definition.item_definition_id)
	_assert_true(direct_inventory.register_item(second_moved, 0), "second moved item register")
	StackServiceScript.register_stack(direct_stacks, direct_inventory, second_moved, definition, 1)
	var incompatible_result: MergeResultScript = StackServiceScript.transfer_and_merge(
		direct_stacks,
		direct_inventory,
		&"stack:second_moved",
		_destination(character),
		null,
		EquipmentStateScript.new(),
	)
	_assert_eq(incompatible_result.outcome, MergeResultScript.Outcome.MERGED, "second moved merges only exact compatible direct stack")
	_assert_true(direct_stacks.has_stack(&"stack:incompatible"), "same definition but different key not absorbed")
	_assert_eq(direct_stacks.stack_state(&"stack:incompatible").amount, 3, "incompatible amount unchanged")


func _test_merge_equipment_cleanup_and_identity() -> void:
	var inventory: InventoryStateScript = InventoryStateScript.new()
	var stacks: StackCollectionScript = StackCollectionScript.new()
	var definition: StackDefinitionScript = _definition(&"item:def.equipped_throw", &"/obj/weapon/dart", 40)
	_register_stack(inventory, stacks, &"stack:moved_throw", definition, 2)
	_register_stack(inventory, stacks, &"stack:equipped_old", definition, 5)
	var room: EndpointScript = _world(&"world:throw_source")
	var character: EndpointScript = _character(&"character:thrower")
	_place(inventory, &"stack:moved_throw", room)
	_place(inventory, &"stack:equipped_old", character)
	var equipment: EquipmentStateScript = EquipmentStateScript.new()
	equipment.wield(_weapon(&"stack:equipped_old"), false)
	var result: MergeResultScript = StackServiceScript.transfer_and_merge(
		stacks,
		inventory,
		&"stack:moved_throw",
		_destination(character),
		null,
		equipment,
	)
	_assert_true(result.succeeded, "equipped sibling merge succeeds")
	_assert_eq(result.surviving_instance_id, &"stack:moved_throw", "equipped sibling does not become survivor")
	_assert_eq(result.equipment_detached_instance_ids, [&"stack:equipped_old"], "absorbed equipped stack detach reported")
	var returned_detached_ids: Array[StringName] = result.equipment_detached_instance_ids
	returned_detached_ids.clear()
	_assert_eq(result.equipment_detached_instance_ids, [&"stack:equipped_old"], "equipment detach IDs are defensive")
	_assert_true(equipment.are_both_hands_empty(), "absorbed throwing stack is unwielded")
	_assert_false(equipment.has_weapon_instance(&"stack:moved_throw"), "equipment is not transferred to survivor")

	## Moving an already-equipped surviving stack within the same character is
	## first detached by feature/move.c semantics, then remains the survivor.
	_register_stack(inventory, stacks, &"stack:other", definition, 1)
	_place(inventory, &"stack:other", character)
	equipment.wield(_weapon(&"stack:moved_throw"), false)
	var same_character: MergeResultScript = StackServiceScript.transfer_and_merge(
		stacks,
		inventory,
		&"stack:moved_throw",
		_destination(character),
		equipment,
		equipment,
	)
	_assert_true(same_character.inventory_transfer.equipment_detached, "moved survivor detached before same-parent merge")
	_assert_true(equipment.are_both_hands_empty(), "moved stack stays unequipped")
	_assert_eq(same_character.surviving_instance_id, &"stack:moved_throw", "same-parent moved identity survives")


func _test_merge_transfer_failure_and_contained_stack_guard() -> void:
	var inventory: InventoryStateScript = InventoryStateScript.new()
	var stacks: StackCollectionScript = StackCollectionScript.new()
	var definition: StackDefinitionScript = _definition(&"item:def.failure", &"/obj/failure", 3)
	_register_stack(inventory, stacks, &"stack:moved", definition, 2)
	_register_stack(inventory, stacks, &"stack:existing", definition, 5)
	var room: EndpointScript = _world(&"world:failure_source")
	var character: EndpointScript = _character(&"character:failure")
	_place(inventory, &"stack:moved", room)
	_place(inventory, &"stack:existing", character)
	var failed: MergeResultScript = StackServiceScript.transfer_and_merge(
		stacks,
		inventory,
		&"stack:moved",
		_destination(character, 16),
		null,
		EquipmentStateScript.new(),
	)
	_assert_eq(failed.outcome, MergeResultScript.Outcome.TRANSFER_FAILED, "failed move never merges")
	_assert_eq(failed.inventory_transfer.outcome, TransferResultScript.Outcome.CAPACITY_EXCEEDED, "merge exposes transfer failure")
	_assert_eq(stacks.stack_state(&"stack:moved").amount, 2, "failed move leaves moved amount")
	_assert_eq(stacks.stack_state(&"stack:existing").amount, 5, "failed move leaves sibling amount")

	_register_plain_item(inventory, &"item:illegal_child", 1)
	_place(inventory, &"item:illegal_child", _item_endpoint(&"stack:existing"))
	var guarded: MergeResultScript = StackServiceScript.transfer_and_merge(
		stacks,
		inventory,
		&"stack:moved",
		_destination(character, LARGE_CAPACITY),
		null,
		EquipmentStateScript.new(),
	)
	_assert_eq(guarded.outcome, MergeResultScript.Outcome.ABSORBED_STACK_HAS_CONTENTS, "contained absorbed stack is explicit unsupported boundary")
	_assert_false(guarded.succeeded, "guarded merge reports incomplete operation")
	_assert_true(guarded.inventory_transfer.succeeded, "move completed before merge guard")
	_assert_true(stacks.has_stack(&"stack:existing"), "guard does not remove stack parent")
	_assert_true(inventory.is_direct_child(&"item:illegal_child", _item_endpoint(&"stack:existing")), "guard does not orphan child")
	_assert_true(inventory.is_direct_child(&"stack:moved", character), "moved stack remains after post-move guard")


func _test_currency_and_generic_combined_value_boundary() -> void:
	var denominations: Array[Array] = [
		[&"money:coin", 1, 1],
		[&"money:silver", 100, 37],
		[&"money:gold", 10_000, 37],
		[&"money:thousand_cash", 100_000, 3],
	]
	for facts: Array in denominations:
		var definition_id: StringName = facts[0]
		var base_value: int = facts[1]
		var base_weight: int = facts[2]
		var stack_definition: StackDefinitionScript = _definition(
			definition_id,
			StringName("/obj/" + String(definition_id)),
			base_weight,
		)
		var currency: CurrencyDefinitionScript = CurrencyDefinitionScript.new(
			definition_id,
			base_value,
		)
		_assert_eq(currency.value_for_amount(3), base_value * 3, "currency amount-scaled value %s" % definition_id)
		_assert_eq(stack_definition.own_weight_for_amount(3), base_weight * 3, "currency amount-scaled weight %s" % definition_id)
		_assert_eq(currency.item_definition_id, stack_definition.item_definition_id, "currency aligns with stack definition %s" % definition_id)

	var coin_definition: StackDefinitionScript = _definition(
		&"money:coin",
		&"/obj/money/coin",
		1,
	)
	var coin_currency: CurrencyDefinitionScript = CurrencyDefinitionScript.new(&"money:coin", 1)
	var coin_inventory: InventoryStateScript = InventoryStateScript.new()
	var coin_stacks: StackCollectionScript = StackCollectionScript.new()
	_register_stack(coin_inventory, coin_stacks, &"stack:coin_value", coin_definition, 5)
	_assert_eq(coin_currency.value_for_amount(coin_stacks.stack_state(&"stack:coin_value").amount), 5, "money value reads observable amount")
	var coin_zero: AmountResultScript = StackServiceScript.set_amount(
		coin_stacks,
		coin_inventory,
		&"stack:coin_value",
		0,
	)
	_assert_eq(coin_zero.outcome, AmountResultScript.Outcome.DELAYED_DESTRUCTION_REQUESTED, "money zero requests delayed destruction")
	_assert_eq(coin_currency.value_for_amount(coin_stacks.stack_state(&"stack:coin_value").amount), 5, "money value remains old during destruction delay")
	_assert_eq(coin_inventory.own_weight(&"stack:coin_value"), 5, "money weight remains old during destruction delay")

	var ordinary: StackDefinitionScript = _definition(&"item:def.ordinary", &"/obj/ordinary", 4)
	_assert_false(_has_property(ordinary, &"base_value"), "ordinary combined definition has no money value fact")
	_assert_false(_has_method(ordinary, &"value_for_amount"), "ordinary combined has no amount-scaled value method")
	var typo_weight: StackDefinitionScript = _definition(&"item:def.snake_fixture", &"/obj/drug/snake_drug", 0)
	_assert_eq(typo_weight.own_weight_for_amount(1), 0, "snake_drug effective base_weight zero")
	_assert_eq(typo_weight.own_weight_for_amount(20), 0, "zero base weight remains zero at positive amount")


func _register_stack(
	inventory: InventoryStateScript,
	stacks: StackCollectionScript,
	instance_id: StringName,
	definition: StackDefinitionScript,
	amount: int,
) -> void:
	var item: ItemInstanceScript = _item(instance_id, definition.item_definition_id)
	_assert_true(inventory.register_item(item, 0), "register live item %s" % instance_id)
	var result: AmountResultScript = StackServiceScript.register_stack(
		stacks,
		inventory,
		item,
		definition,
		amount,
	)
	_assert_eq(result.outcome, AmountResultScript.Outcome.REGISTERED, "register stack state %s" % instance_id)


func _register_plain_item(
	inventory: InventoryStateScript,
	instance_id: StringName,
	weight: int,
) -> void:
	_assert_true(
		inventory.register_item(_item(instance_id, &"item:def.plain"), weight),
		"register plain item %s" % instance_id,
	)


func _place(
	inventory: InventoryStateScript,
	instance_id: StringName,
	endpoint: EndpointScript,
) -> void:
	var result: TransferResultScript = TransferServiceScript.new().transfer(
		inventory,
		instance_id,
		_destination(endpoint),
	)
	_assert_true(result.succeeded, "fixture place %s" % instance_id)


func _definition(
	definition_id: StringName,
	compatibility_id: StringName,
	base_weight: int,
) -> StackDefinitionScript:
	return StackDefinitionScript.new(definition_id, compatibility_id, base_weight)


func _item(instance_id: StringName, definition_id: StringName) -> ItemInstanceScript:
	return ItemInstanceScript.new(instance_id, definition_id)


func _character(endpoint_id: StringName) -> EndpointScript:
	return EndpointScript.new(EndpointScript.Kind.CHARACTER, endpoint_id)


func _item_endpoint(endpoint_id: StringName) -> EndpointScript:
	return EndpointScript.new(EndpointScript.Kind.ITEM, endpoint_id)


func _world(endpoint_id: StringName) -> EndpointScript:
	return EndpointScript.new(EndpointScript.Kind.WORLD, endpoint_id)


func _destination(
	endpoint: EndpointScript,
	maximum_contents_weight: int = LARGE_CAPACITY,
) -> DestinationScript:
	return DestinationScript.new(endpoint, true, true, maximum_contents_weight)


func _weapon(instance_id: StringName) -> EquippedWeaponRefScript:
	return EquippedWeaponRefScript.new(
		instance_id,
		WeaponDefinitionScript.new(
			&"item:def.equipped_throw",
			SkillIdsScript.THROWING,
			true,
			false,
			"reference/es2/mudlib/obj/weapon/dart.c",
		),
	)


func _has_property(value: Object, property_name: StringName) -> bool:
	for property: Dictionary in value.get_property_list():
		if StringName(property["name"]) == property_name:
			return true
	return false


func _has_method(value: Object, method_name: StringName) -> bool:
	return value.has_method(method_name)


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
