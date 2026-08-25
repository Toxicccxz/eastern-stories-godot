extends RefCounted

const ItemDefinitionScript := preload("res://core/items/item_definition.gd")
const ItemInstanceScript := preload("res://core/items/item_instance.gd")
const EndpointScript := preload("res://core/inventory/containment_endpoint.gd")
const DestinationScript := preload(
	"res://core/inventory/inventory_transfer_destination.gd"
)
const InventoryScript := preload("res://core/inventory/inventory_state.gd")
const EquipmentScript := preload("res://core/equipment/equipment_state.gd")
const WeaponDefinitionScript := preload(
	"res://core/equipment/weapon_definition.gd"
)
const WeaponRefScript := preload("res://core/equipment/equipped_weapon_ref.gd")
const ArmorModifiersScript := preload(
	"res://core/armor/armor_numeric_modifiers.gd"
)
const ArmorDefinitionScript := preload("res://core/armor/armor_definition.gd")
const ArmorScript := preload("res://core/armor/armor_state.gd")
const ArmorServiceScript := preload("res://core/armor/armor_service.gd")
const StackCollectionScript := preload(
	"res://core/items/combined/combined_stack_collection.gd"
)
const StackDefinitionScript := preload(
	"res://core/items/combined/combined_stack_definition.gd"
)
const StackServiceScript := preload(
	"res://core/items/combined/combined_stack_service.gd"
)
const StackAmountResultScript := preload(
	"res://core/items/combined/combined_stack_amount_result.gd"
)
const OwnerContextScript := preload(
	"res://core/items/lifecycle/item_lifecycle_owner_context.gd"
)
const LifecycleResultScript := preload(
	"res://core/items/lifecycle/item_lifecycle_result.gd"
)
const FailingArmorStateScript := preload(
	"res://tests/support/failing_lifecycle_armor_state.gd"
)
const DeathContextScript := preload("res://core/death/death_context.gd")
const DeathFactsScript := preload("res://core/death/death_item_facts.gd")
const DeathPolicyRegistryScript := preload(
	"res://core/death/death_item_policy_registry.gd"
)
const DestroyPolicyScript := preload(
	"res://core/death/destroy_death_item_policy.gd"
)
const WindspringPolicyScript := preload(
	"res://core/death/windspring_death_item_policy.gd"
)
const PolicyResultScript := preload(
	"res://core/death/death_item_policy_result.gd"
)
const RewearRegistryScript := preload(
	"res://core/death/death_rewear_policy_registry.gd"
)
const RewearResultScript := preload("res://core/death/death_rewear_result.gd")
const DeathResultScript := preload("res://core/death/death_inventory_result.gd")
const DeathServiceScript := preload("res://core/death/death_inventory_service.gd")
const CorpseStateScript := preload("res://core/corpses/corpse_state.gd")
const DecayIntentScript := preload(
	"res://core/corpses/corpse_decay_schedule_intent.gd"
)
const ContentTransferResultScript := preload(
	"res://core/corpses/corpse_content_transfer_result.gd"
)
const ContentTransferServiceScript := preload(
	"res://core/corpses/corpse_content_transfer_service.gd"
)
const DecayResultScript := preload("res://core/corpses/corpse_decay_result.gd")
const DecayServiceScript := preload("res://core/corpses/corpse_decay_service.gd")

const CHARACTER_ID: StringName = &"character:dead"
const WORLD_ID: StringName = &"world:death_place"
const CORPSE_DEF: StringName = &"item:corpse"
const MAILBOX_DEF: StringName = &"item:mailbox"
const ROOMMAKER_DEF: StringName = &"item:roommaker"
const WINDSPRING_DEF: StringName = &"item:windspring"
const BANDAGE_DEF: StringName = &"item:bandage"
const SKIRT_DEF: StringName = &"item:latemoon_skirt"
const PLAIN_DEF: StringName = &"item:plain"
const BAG_DEF: StringName = &"item:bag"
const WEAPON_DEF: StringName = &"item:weapon"
const ARMOR_DEF: StringName = &"item:armor"

var _assertion_count: int = 0
var _failures: Array[String] = []


func run_all() -> Dictionary[String, Variant]:
	_test_direct_snapshot_default_and_container_subtree()
	_test_destroy_policies_and_windspring_boundary()
	_test_ghost_precedence_and_equipment_failure()
	_test_normal_and_wizard_corpse_creation()
	_test_normal_weapon_container_and_partial_failure()
	_test_worn_rewear_paths_and_custom_policies()
	_test_corpse_worn_release_and_lock()
	_test_decay_timing_final_scatter_and_no_environment()
	_test_stack_cleanup_and_independent_state()
	_test_fact_binding_and_policy_lifecycle_failure()
	_test_blocked_processing_is_not_restartable()
	_test_capacity_placement_and_decay_boundaries()
	return {
		"assertions": _assertion_count,
		"failures": _failures.duplicate(),
	}


func _test_direct_snapshot_default_and_container_subtree() -> void:
	var inventory: InventoryScript = InventoryScript.new()
	var owner: OwnerContextScript = _owner()
	var character: EndpointScript = _character_endpoint()
	var bag: ItemInstanceScript = _register(inventory, &"b_bag", BAG_DEF, 2, character)
	var nested: ItemInstanceScript = _register(
		inventory,
		&"nested",
		MAILBOX_DEF,
		3,
		EndpointScript.new(EndpointScript.Kind.ITEM, bag.item_instance_id),
	)
	var sword: ItemInstanceScript = _register(
		inventory, &"a_sword", WEAPON_DEF, 4, character
	)
	var nested_policy_registry: DeathPolicyRegistryScript = DeathPolicyRegistryScript.new()
	nested_policy_registry.register_policy(MAILBOX_DEF, DestroyPolicyScript.new())
	var result: DeathResultScript = DeathServiceScript.process(
		_context(owner, true, false),
		inventory,
		StackCollectionScript.new(),
		[_facts(bag), _facts(nested), _facts(sword)],
		nested_policy_registry,
		RewearRegistryScript.new(),
	)
	_assert_eq(result.branch, DeathResultScript.Branch.GHOST, "ghost branch")
	_assert_eq(result.direct_snapshot_ids, [&"a_sword", &"b_bag"], "direct-only stable snapshot")
	_assert_eq(result.policy_results.size(), 2, "nested item receives no death policy")
	_assert_eq(result.survivor_transfer_results[0].item_instance_id, &"b_bag", "reverse survivor order starts bag")
	_assert_eq(result.survivor_transfer_results[1].item_instance_id, &"a_sword", "reverse survivor order ends sword")
	_assert_true(inventory.is_direct_child(&"b_bag", _world_endpoint()), "bag transferred once")
	_assert_true(inventory.is_direct_child(&"nested", EndpointScript.new(EndpointScript.Kind.ITEM, &"b_bag")), "nested item follows bag subtree")
	_assert_true(inventory.is_registered(&"nested"), "nested mailbox hook is not evaluated")
	_assert_eq(result.corpse_state, null, "ghost creates no corpse")


func _test_destroy_policies_and_windspring_boundary() -> void:
	var inventory: InventoryScript = InventoryScript.new()
	var owner: OwnerContextScript = _owner()
	var character: EndpointScript = _character_endpoint()
	var mailbox: ItemInstanceScript = _register(inventory, &"mailbox", MAILBOX_DEF, 1, character)
	_register(inventory, &"mail_child", PLAIN_DEF, 1, EndpointScript.new(EndpointScript.Kind.ITEM, mailbox.item_instance_id))
	var roommaker: ItemInstanceScript = _register(inventory, &"roommaker", ROOMMAKER_DEF, 1, character)
	var registry: DeathPolicyRegistryScript = DeathPolicyRegistryScript.new()
	_assert_true(registry.register_policy(MAILBOX_DEF, DestroyPolicyScript.new()), "register mailbox policy")
	_assert_true(registry.register_policy(ROOMMAKER_DEF, DestroyPolicyScript.new()), "register roommaker policy")
	var result: DeathResultScript = DeathServiceScript.process(
		_context(owner, true, false), inventory, StackCollectionScript.new(),
		[_facts(mailbox), _facts(roommaker)], registry, RewearRegistryScript.new()
	)
	_assert_eq(result.outcome, DeathResultScript.Outcome.COMPLETED, "destroy policies complete")
	_assert_eq(result.destroyed_instance_ids, [&"mail_child", &"mailbox", &"roommaker"], "mailbox subtree and roommaker removed")
	_assert_false(inventory.is_registered(&"mailbox"), "mailbox is no longer live")
	_assert_false(inventory.is_registered(&"mail_child"), "mailbox child follows subtree destruction")
	_assert_eq(result.survivor_transfer_results.size(), 0, "destroyed items are not survivors")

	var keep_inventory: InventoryScript = InventoryScript.new()
	var keep_owner: OwnerContextScript = _owner()
	var windspring: ItemInstanceScript = _register(
		keep_inventory, &"windspring", WINDSPRING_DEF, 1, _character_endpoint()
	)
	var wind_registry: DeathPolicyRegistryScript = DeathPolicyRegistryScript.new()
	wind_registry.register_policy(WINDSPRING_DEF, WindspringPolicyScript.new())
	var keep_result: DeathResultScript = DeathServiceScript.process(
		_context(keep_owner, true, false, true), keep_inventory,
		StackCollectionScript.new(), [_facts(windspring)], wind_registry,
		RewearRegistryScript.new()
	)
	_assert_eq(keep_result.policy_results[0].outcome, PolicyResultScript.Outcome.KEEP, "sword-soul owner keeps windspring")
	_assert_true(keep_inventory.is_direct_child(&"windspring", _world_endpoint()), "kept windspring follows ghost transfer")

	var defer_inventory: InventoryScript = InventoryScript.new()
	var defer_owner: OwnerContextScript = _owner()
	var deferred_sword: ItemInstanceScript = _register(
		defer_inventory, &"windspring", WINDSPRING_DEF, 1, _character_endpoint()
	)
	var defer_result: DeathResultScript = DeathServiceScript.process(
		_context(defer_owner, true, false), defer_inventory,
		StackCollectionScript.new(), [_facts(deferred_sword)], wind_registry,
		RewearRegistryScript.new()
	)
	_assert_eq(defer_result.outcome, DeathResultScript.Outcome.DEFERRED_RUNTIME_EFFECT, "windspring does not fake NPC completion")
	_assert_eq(defer_result.deferred_effects.size(), 1, "one typed spawn intent")
	_assert_eq(defer_result.deferred_effects[0].npc_definition_id, &"", "no invented native NPC definition ID")
	_assert_eq(defer_result.deferred_effects[0].legacy_npc_source_path, "reference/es2/mudlib/daemon/class/scholar/sword_soul.c", "legacy NPC source retained")
	_assert_true(defer_inventory.is_direct_child(&"windspring", _character_endpoint()), "deferred sword remains with owner until spawn path completes")
	var killer_endpoint: EndpointScript = EndpointScript.new(
		EndpointScript.Kind.WORLD, &"world:killer_location"
	)
	var killer_context: DeathContextScript = DeathContextScript.new(
		CHARACTER_ID, true, false, _world_destination(), defer_owner, "Dead One",
		&"男性", 20, 100, 1000, false, killer_endpoint, &"", true
	)
	var killer_policy: PolicyResultScript = wind_registry.evaluate(
		killer_context, _facts(deferred_sword)
	)
	_assert_true(killer_policy.spawn_intent.world_endpoint.same_identity(killer_endpoint), "present killer endpoint wins over owner fallback")
	var missing_killer_context: DeathContextScript = DeathContextScript.new(
		CHARACTER_ID, true, false, _world_destination(), defer_owner, "Dead One",
		&"男性", 20, 100, 1000, false, null, &"", true
	)
	var missing_killer_policy: PolicyResultScript = wind_registry.evaluate(
		missing_killer_context, _facts(deferred_sword)
	)
	_assert_eq(missing_killer_policy.outcome, PolicyResultScript.Outcome.DEPENDENCY_UNAVAILABLE, "present killer without environment does not fall back to owner")
	var missing_inventory: InventoryScript = InventoryScript.new()
	var missing_sword: ItemInstanceScript = _register(
		missing_inventory,
		&"missing_windspring",
		WINDSPRING_DEF,
		1,
		_character_endpoint(),
	)
	var missing_process: DeathResultScript = DeathServiceScript.process(
		missing_killer_context,
		missing_inventory,
		StackCollectionScript.new(),
		[_facts(missing_sword)],
		wind_registry,
		RewearRegistryScript.new(),
	)
	_assert_eq(missing_process.outcome, DeathResultScript.Outcome.POLICY_DEPENDENCY_UNAVAILABLE, "missing target is not mislabeled as a deferred effect")
	_assert_eq(missing_process.deferred_effects, [], "missing target produces no executable spawn intent")
	_assert_eq(missing_process.restart_disposition, DeathResultScript.RestartDisposition.DO_NOT_RESTART_FROM_BEGINNING, "missing dependency is an explicit non-restartable boundary")


func _test_ghost_precedence_and_equipment_failure() -> void:
	var inventory: InventoryScript = InventoryScript.new()
	var equipment: EquipmentScript = EquipmentScript.new()
	var armor: ArmorScript = ArmorScript.new()
	var owner: OwnerContextScript = OwnerContextScript.new(CHARACTER_ID, equipment, armor)
	var sword: ItemInstanceScript = _register(inventory, &"b_sword", WEAPON_DEF, 10, _character_endpoint())
	var weapon_definition: WeaponDefinitionScript = WeaponDefinitionScript.new(WEAPON_DEF, &"sword", 0)
	_assert_true(equipment.wield(WeaponRefScript.new(sword.item_instance_id, weapon_definition), false).succeeded, "setup wielded sword")
	var armor_item: ItemInstanceScript = _register(inventory, &"a_armor", ARMOR_DEF, 10, _character_endpoint())
	var armor_definition: ArmorDefinitionScript = _armor_definition(ARMOR_DEF, &"cloth")
	_assert_true(ArmorServiceScript.wear(armor, inventory, _character_endpoint(), armor_item, armor_definition).succeeded, "setup worn armor")
	var result: DeathResultScript = DeathServiceScript.process(
		_context(owner, true, true, false, &"", 0), inventory,
		StackCollectionScript.new(), [_facts(sword), _facts(armor_item, armor_definition)],
		DeathPolicyRegistryScript.new(), RewearRegistryScript.new()
	)
	_assert_eq(result.branch, DeathResultScript.Branch.GHOST, "ghost wins over wizard")
	_assert_eq(result.survivor_transfer_results.size(), 2, "ghost continues after ordinary move failures")
	_assert_false(result.survivor_transfer_results[0].succeeded, "first capacity transfer fails")
	_assert_false(result.survivor_transfer_results[1].succeeded, "second capacity transfer fails")
	_assert_true(inventory.is_direct_child(sword.item_instance_id, _character_endpoint()), "failed sword stays with victim")
	_assert_true(inventory.is_direct_child(armor_item.item_instance_id, _character_endpoint()), "failed armor stays with victim")
	_assert_false(equipment.has_weapon_instance(sword.item_instance_id), "failed ghost transfer leaves sword detached")
	_assert_false(armor.is_worn(armor_item.item_instance_id), "ghost branch does not rewear failed armor")
	_assert_eq(result.corpse_item_instance_id, &"", "ghost+wizard still has no corpse")


func _test_normal_and_wizard_corpse_creation() -> void:
	var inventory: InventoryScript = InventoryScript.new()
	var owner: OwnerContextScript = _owner()
	var item: ItemInstanceScript = _register(inventory, &"ordinary", PLAIN_DEF, 2, _character_endpoint())
	var corpse_item: ItemInstanceScript = ItemInstanceScript.new(&"corpse", CORPSE_DEF)
	var wizard_result: DeathResultScript = DeathServiceScript.process(
		_context(owner, false, true, false, &"女性", 100000, 77, 456, 9000),
		inventory, StackCollectionScript.new(), [],
		DeathPolicyRegistryScript.new(), RewearRegistryScript.new(), corpse_item,
		ItemDefinitionScript.new(CORPSE_DEF, "reference/es2/mudlib/obj/corpse.c")
	)
	_assert_eq(wizard_result.branch, DeathResultScript.Branch.WIZARD, "wizard branch")
	_assert_true(inventory.is_registered(&"corpse"), "corpse registered before wizard return")
	_assert_eq(inventory.own_weight(&"corpse"), 456, "corpse own weight comes from victim query_weight snapshot")
	_assert_true(inventory.is_direct_child(&"corpse", _world_endpoint()), "corpse placement attempted before wizard return")
	_assert_true(inventory.is_direct_child(&"ordinary", _character_endpoint()), "wizard inventory is untouched")
	_assert_eq(wizard_result.policy_results.size(), 0, "wizard runs no death item policies")
	_assert_eq(wizard_result.direct_snapshot_ids.size(), 0, "wizard takes no death-inventory snapshot")
	_assert_eq(wizard_result.corpse_state.maximum_contents_encumbrance, 9000, "corpse capacity snapshots victim maximum")
	_assert_eq(wizard_result.corpse_state.victim_display_name, "Dead One", "corpse stores victim display snapshot")
	_assert_eq(wizard_result.corpse_state.victim_gender, &"男性", "corpse stores gender snapshot")
	_assert_eq(wizard_result.corpse_state.victim_age, 77, "corpse stores age snapshot")
	_assert_eq(wizard_result.corpse_state.decay_stage, CorpseStateScript.Stage.FRESH, "new corpse starts stage zero")
	_assert_eq(wizard_result.initial_decay_intent.delay_seconds, 120, "wizard corpse gets initial decay intent")
	_assert_eq(wizard_result.initial_decay_intent.expected_stage, CorpseStateScript.Stage.FRESH, "initial intent expected stage")
	_assert_eq(wizard_result.initial_decay_intent.next_stage, CorpseStateScript.Stage.ROTTEN, "initial intent next stage")

	var placement_inventory: InventoryScript = InventoryScript.new()
	var placement_owner: OwnerContextScript = _owner()
	var placement_failure: DeathResultScript = DeathServiceScript.process(
		_context(placement_owner, false, true, false, &"", 0, 10, 5, 10),
		placement_inventory,
		StackCollectionScript.new(),
		[],
		DeathPolicyRegistryScript.new(),
		RewearRegistryScript.new(),
		ItemInstanceScript.new(&"unplaced_corpse", CORPSE_DEF),
		ItemDefinitionScript.new(CORPSE_DEF),
	)
	_assert_false(placement_failure.corpse_placement_result.succeeded, "corpse placement failure is recorded and ignored")
	_assert_true(placement_inventory.is_registered(&"unplaced_corpse"), "failed placement corpse remains live")
	_assert_false(placement_inventory.has_direct_parent(&"unplaced_corpse"), "failed placement invents no fallback parent")
	_assert_eq(placement_failure.initial_decay_intent.delay_seconds, 120, "unplaced corpse still exposes source decay intent")


func _test_normal_weapon_container_and_partial_failure() -> void:
	var inventory: InventoryScript = InventoryScript.new()
	var equipment: EquipmentScript = EquipmentScript.new()
	var owner: OwnerContextScript = OwnerContextScript.new(CHARACTER_ID, equipment, ArmorScript.new())
	var bag: ItemInstanceScript = _register(inventory, &"a_bag", BAG_DEF, 2, _character_endpoint())
	_register(inventory, &"nested", PLAIN_DEF, 3, EndpointScript.new(EndpointScript.Kind.ITEM, bag.item_instance_id))
	var sword: ItemInstanceScript = _register(inventory, &"b_sword", WEAPON_DEF, 4, _character_endpoint())
	equipment.wield(WeaponRefScript.new(sword.item_instance_id, WeaponDefinitionScript.new(WEAPON_DEF, &"sword", 0)), false)
	var result: DeathResultScript = DeathServiceScript.process(
		_context(owner), inventory, StackCollectionScript.new(), [_facts(bag), _facts(sword)],
		DeathPolicyRegistryScript.new(), RewearRegistryScript.new(),
		ItemInstanceScript.new(&"corpse", CORPSE_DEF), ItemDefinitionScript.new(CORPSE_DEF)
	)
	var corpse_endpoint: EndpointScript = EndpointScript.new(EndpointScript.Kind.ITEM, &"corpse")
	_assert_eq(result.outcome, DeathResultScript.Outcome.COMPLETED, "normal death completes")
	_assert_eq(result.survivor_transfer_results[0].item_instance_id, &"b_sword", "normal survivors processed descending")
	_assert_true(inventory.is_direct_child(&"b_sword", corpse_endpoint), "wielded sword moves to corpse")
	_assert_false(equipment.has_weapon_instance(&"b_sword"), "wielded sword is detached")
	_assert_true(inventory.is_direct_child(&"a_bag", corpse_endpoint), "bag moves once")
	_assert_true(inventory.is_direct_child(&"nested", EndpointScript.new(EndpointScript.Kind.ITEM, &"a_bag")), "nested child follows bag")

	var fail_inventory: InventoryScript = InventoryScript.new()
	var fail_owner: OwnerContextScript = _owner()
	var first: ItemInstanceScript = _register(fail_inventory, &"a_heavy", PLAIN_DEF, 5, _character_endpoint())
	var second: ItemInstanceScript = _register(fail_inventory, &"b_zero", PLAIN_DEF, 0, _character_endpoint())
	var fail_result: DeathResultScript = DeathServiceScript.process(
		_context(fail_owner, false, false, false, &"", 100000, 10, 0, 0),
		fail_inventory, StackCollectionScript.new(), [_facts(first), _facts(second)],
		DeathPolicyRegistryScript.new(), RewearRegistryScript.new(),
		ItemInstanceScript.new(&"corpse2", CORPSE_DEF), ItemDefinitionScript.new(CORPSE_DEF)
	)
	var corpse2: EndpointScript = EndpointScript.new(EndpointScript.Kind.ITEM, &"corpse2")
	_assert_true(fail_result.survivor_transfer_results[0].succeeded, "zero-weight later ID succeeds first")
	_assert_false(fail_result.survivor_transfer_results[1].succeeded, "later heavy item failure does not rollback first")
	_assert_true(fail_inventory.is_direct_child(&"b_zero", corpse2), "earlier successful transfer remains")
	_assert_true(fail_inventory.is_direct_child(&"a_heavy", _character_endpoint()), "failed item remains victim direct")

	var weapon_fail_inventory: InventoryScript = InventoryScript.new()
	var weapon_fail_equipment: EquipmentScript = EquipmentScript.new()
	var weapon_fail_owner: OwnerContextScript = OwnerContextScript.new(
		CHARACTER_ID, weapon_fail_equipment, ArmorScript.new()
	)
	var failed_sword: ItemInstanceScript = _register(
		weapon_fail_inventory, &"sword", WEAPON_DEF, 5, _character_endpoint()
	)
	weapon_fail_equipment.wield(
		WeaponRefScript.new(
			failed_sword.item_instance_id,
			WeaponDefinitionScript.new(WEAPON_DEF, &"sword", 0),
		),
		false,
	)
	var weapon_fail: DeathResultScript = DeathServiceScript.process(
		_context(weapon_fail_owner, false, false, false, &"", 100000, 10, 0, 0),
		weapon_fail_inventory, StackCollectionScript.new(), [_facts(failed_sword)],
		DeathPolicyRegistryScript.new(), RewearRegistryScript.new(),
		ItemInstanceScript.new(&"corpse3", CORPSE_DEF), ItemDefinitionScript.new(CORPSE_DEF)
	)
	_assert_false(weapon_fail.survivor_transfer_results[0].succeeded, "normal wielded move failure is retained")
	_assert_true(weapon_fail_inventory.is_direct_child(&"sword", _character_endpoint()), "failed normal wielded item stays victim direct")
	_assert_false(weapon_fail_equipment.has_weapon_instance(&"sword"), "failed normal wielded move remains unwielded")


func _test_worn_rewear_paths_and_custom_policies() -> void:
	var success_inventory: InventoryScript = InventoryScript.new()
	var success_owner: OwnerContextScript = _owner()
	var armor_item: ItemInstanceScript = _register(success_inventory, &"armor", ARMOR_DEF, 4, _character_endpoint())
	var armor_definition: ArmorDefinitionScript = _armor_definition(ARMOR_DEF, &"feet")
	ArmorServiceScript.wear(success_owner.armor_state, success_inventory, _character_endpoint(), armor_item, armor_definition)
	var success: DeathResultScript = DeathServiceScript.process(
		_context(success_owner), success_inventory, StackCollectionScript.new(),
		[_facts(armor_item, armor_definition)], DeathPolicyRegistryScript.new(),
		RewearRegistryScript.new(), ItemInstanceScript.new(&"corpse", CORPSE_DEF),
		ItemDefinitionScript.new(CORPSE_DEF)
	)
	_assert_false(success_owner.armor_state.is_worn(&"armor"), "victim armor authority detached")
	_assert_eq(success.corpse_state.worn_item_in_slot(&"feet"), &"armor", "corpse rewear stores exact open slot")
	_assert_eq(success.rewear_results[0].outcome, RewearResultScript.Outcome.WORN_ON_CORPSE, "generic armor reworn on corpse")

	var fail_inventory: InventoryScript = InventoryScript.new()
	var fail_owner: OwnerContextScript = _owner()
	var failed_armor: ItemInstanceScript = _register(fail_inventory, &"armor", ARMOR_DEF, 4, _character_endpoint())
	ArmorServiceScript.wear(fail_owner.armor_state, fail_inventory, _character_endpoint(), failed_armor, armor_definition)
	var fail: DeathResultScript = DeathServiceScript.process(
		_context(fail_owner, false, false, false, &"", 100000, 10, 0, 0),
		fail_inventory, StackCollectionScript.new(), [_facts(failed_armor, armor_definition)],
		DeathPolicyRegistryScript.new(), RewearRegistryScript.new(),
		ItemInstanceScript.new(&"corpse", CORPSE_DEF), ItemDefinitionScript.new(CORPSE_DEF)
	)
	_assert_false(fail.survivor_transfer_results[0].succeeded, "worn move can fail after detach")
	_assert_true(fail_owner.armor_state.is_worn(&"armor"), "failed move then generic low-level rewear restores victim armor")
	_assert_true(fail_inventory.is_direct_child(&"armor", _character_endpoint()), "reworn item remains victim direct")

	var bandage_inventory: InventoryScript = InventoryScript.new()
	var bandage_owner: OwnerContextScript = _owner()
	var bandage: ItemInstanceScript = _register(bandage_inventory, &"bandage", BANDAGE_DEF, 1, _character_endpoint())
	var bandage_definition: ArmorDefinitionScript = _armor_definition(BANDAGE_DEF, &"bandage")
	ArmorServiceScript.wear(bandage_owner.armor_state, bandage_inventory, _character_endpoint(), bandage, bandage_definition)
	var custom: RewearRegistryScript = RewearRegistryScript.new()
	custom.register_bandage(BANDAGE_DEF)
	custom.register_latemoon_skirt(SKIRT_DEF)
	var bandage_result: DeathResultScript = DeathServiceScript.process(
		_context(bandage_owner), bandage_inventory, StackCollectionScript.new(),
		[_facts(bandage, bandage_definition)], DeathPolicyRegistryScript.new(), custom,
		ItemInstanceScript.new(&"corpse", CORPSE_DEF), ItemDefinitionScript.new(CORPSE_DEF)
	)
	_assert_eq(bandage_result.rewear_results[0].outcome, RewearResultScript.Outcome.FALLBACK_TRANSFERRED, "bandage fixed wear failure triggers fallback")
	_assert_true(bandage_inventory.is_direct_child(&"bandage", _world_endpoint()), "bandage falls to victim environment")
	_assert_false(bandage_result.corpse_state.is_worn(&"bandage"), "bandage is never generically corpse-worn")

	var skirt_inventory: InventoryScript = InventoryScript.new()
	var skirt_owner: OwnerContextScript = _owner()
	var skirt: ItemInstanceScript = _register(skirt_inventory, &"skirt", SKIRT_DEF, 1, _character_endpoint())
	var skirt_definition: ArmorDefinitionScript = _armor_definition(SKIRT_DEF, &"waist")
	ArmorServiceScript.wear(skirt_owner.armor_state, skirt_inventory, _character_endpoint(), skirt, skirt_definition)
	var skirt_result: DeathResultScript = DeathServiceScript.process(
		_context(skirt_owner, false, false, false, &"女性"), skirt_inventory,
		StackCollectionScript.new(), [_facts(skirt, skirt_definition)],
		DeathPolicyRegistryScript.new(), custom,
		ItemInstanceScript.new(&"corpse", CORPSE_DEF), ItemDefinitionScript.new(CORPSE_DEF)
	)
	_assert_eq(skirt_result.rewear_results[0].outcome, RewearResultScript.Outcome.WORN_ON_CORPSE, "female this_player skirt calls base wear")

	var nonfemale_inventory: InventoryScript = InventoryScript.new()
	var nonfemale_owner: OwnerContextScript = _owner()
	var nonfemale_skirt: ItemInstanceScript = _register(
		nonfemale_inventory, &"skirt", SKIRT_DEF, 1, _character_endpoint()
	)
	ArmorServiceScript.wear(
		nonfemale_owner.armor_state,
		nonfemale_inventory,
		_character_endpoint(),
		nonfemale_skirt,
		skirt_definition,
	)
	var nonfemale: DeathResultScript = DeathServiceScript.process(
		_context(nonfemale_owner, false, false, false, &"男性"),
		nonfemale_inventory,
		StackCollectionScript.new(),
		[_facts(nonfemale_skirt, skirt_definition)],
		DeathPolicyRegistryScript.new(),
		custom,
		ItemInstanceScript.new(&"corpse", CORPSE_DEF),
		ItemDefinitionScript.new(CORPSE_DEF),
	)
	_assert_eq(nonfemale.rewear_results[0].outcome, RewearResultScript.Outcome.FALLBACK_TRANSFERRED, "nonfemale dynamic actor rejects skirt wear")
	_assert_true(nonfemale_inventory.is_direct_child(&"skirt", _world_endpoint()), "rejected skirt falls to victim environment")

	var missing_inventory: InventoryScript = InventoryScript.new()
	var missing_owner: OwnerContextScript = _owner()
	var missing_skirt: ItemInstanceScript = _register(missing_inventory, &"skirt", SKIRT_DEF, 1, _character_endpoint())
	ArmorServiceScript.wear(missing_owner.armor_state, missing_inventory, _character_endpoint(), missing_skirt, skirt_definition)
	var missing: DeathResultScript = DeathServiceScript.process(
		_context(missing_owner), missing_inventory, StackCollectionScript.new(),
		[_facts(missing_skirt, skirt_definition)], DeathPolicyRegistryScript.new(), custom,
		ItemInstanceScript.new(&"corpse", CORPSE_DEF), ItemDefinitionScript.new(CORPSE_DEF)
	)
	_assert_eq(missing.outcome, DeathResultScript.Outcome.REWEAR_DEPENDENCY_UNAVAILABLE, "missing dynamic this_player gender is explicit")
	_assert_true(missing_inventory.is_direct_child(&"skirt", EndpointScript.new(EndpointScript.Kind.ITEM, &"corpse")), "dependency result preserves completed move")
	_assert_false(missing.corpse_state.is_worn(&"skirt"), "dependency does not fake generic wear")

	var collision_inventory: InventoryScript = InventoryScript.new()
	_register(collision_inventory, &"collision_corpse", CORPSE_DEF, 0, _world_endpoint())
	_register(
		collision_inventory,
		&"blocker",
		ARMOR_DEF,
		1,
		EndpointScript.new(EndpointScript.Kind.ITEM, &"collision_corpse"),
	)
	var collision_corpse: CorpseStateScript = CorpseStateScript.new(&"collision_corpse")
	_assert_true(
		collision_corpse._try_wear(&"waist", &"blocker", collision_inventory),
		"setup exact-slot collision",
	)
	var collision_skirt: ItemInstanceScript = _register(collision_inventory, &"skirt", SKIRT_DEF, 1, EndpointScript.new(EndpointScript.Kind.ITEM, &"collision_corpse"))
	var collision_result: RewearResultScript = DeathServiceScript._attempt_rewear(
		_context(_owner(), false, false, false, &"女性"), collision_inventory,
		collision_corpse, _facts(collision_skirt, skirt_definition), custom
	)
	_assert_eq(collision_result.outcome, RewearResultScript.Outcome.CUSTOM_SUCCESS_WITHOUT_WEAR, "skirt ignores base slot collision and suppresses fallback")
	_assert_true(collision_inventory.is_direct_child(&"skirt", EndpointScript.new(EndpointScript.Kind.ITEM, &"collision_corpse")), "collision skirt stays corpse-contained but unworn")
	var generic_collision: ItemInstanceScript = _register(
		collision_inventory,
		&"generic_waist",
		ARMOR_DEF,
		1,
		EndpointScript.new(EndpointScript.Kind.ITEM, &"collision_corpse"),
	)
	var generic_collision_result: RewearResultScript = DeathServiceScript._attempt_rewear(
		_context(_owner()), collision_inventory, collision_corpse,
		_facts(generic_collision, _armor_definition(ARMOR_DEF, &"waist")),
		RewearRegistryScript.new(),
	)
	_assert_eq(generic_collision_result.outcome, RewearResultScript.Outcome.FALLBACK_TRANSFERRED, "generic exact-slot collision triggers room fallback")
	_assert_true(collision_inventory.is_direct_child(&"generic_waist", _world_endpoint()), "generic collision item reaches victim environment")
	_register(collision_inventory, &"boots_item", ARMOR_DEF, 1, EndpointScript.new(EndpointScript.Kind.ITEM, &"collision_corpse"))
	_register(collision_inventory, &"feet_item", ARMOR_DEF, 1, EndpointScript.new(EndpointScript.Kind.ITEM, &"collision_corpse"))
	_assert_true(collision_corpse._try_wear(&"boots", &"boots_item", collision_inventory), "boots is an exact corpse slot")
	_assert_true(collision_corpse._try_wear(&"feet", &"feet_item", collision_inventory), "feet remains independent from boots")


func _test_corpse_worn_release_and_lock() -> void:
	var fresh_inventory: InventoryScript = InventoryScript.new()
	_register(fresh_inventory, &"corpse", CORPSE_DEF, 1, _world_endpoint())
	_register(fresh_inventory, &"armor", ARMOR_DEF, 1, EndpointScript.new(EndpointScript.Kind.ITEM, &"corpse"))
	var fresh: CorpseStateScript = CorpseStateScript.new(&"corpse")
	fresh._try_wear(&"boots", &"armor", fresh_inventory)
	var released: ContentTransferResultScript = ContentTransferServiceScript.transfer_out(
		fresh, fresh_inventory, &"armor", _world_destination()
	)
	_assert_true(released.succeeded, "stage0 corpse-worn item can transfer")
	_assert_true(released.corpse_worn_released, "stage0 projection clears before transfer")
	_assert_false(fresh.is_worn(&"armor"), "fresh projection removed")

	var locked_inventory: InventoryScript = InventoryScript.new()
	_register(locked_inventory, &"corpse", CORPSE_DEF, 1, _world_endpoint())
	_register(locked_inventory, &"armor", ARMOR_DEF, 1, EndpointScript.new(EndpointScript.Kind.ITEM, &"corpse"))
	var locked: CorpseStateScript = CorpseStateScript.new(&"corpse")
	locked._try_wear(&"boots", &"armor", locked_inventory)
	var stage1: DecayResultScript = DecayServiceScript.advance(
		locked, DecayServiceScript.initial_intent(locked), locked_inventory,
		StackCollectionScript.new()
	)
	_assert_true(stage1.succeeded, "fresh to rotten transition")
	var blocked: ContentTransferResultScript = ContentTransferServiceScript.transfer_out(
		locked, locked_inventory, &"armor", _world_destination()
	)
	_assert_eq(blocked.outcome, ContentTransferResultScript.Outcome.CORPSE_WORN_LOCKED, "stage1 worn marker cannot unequip from non-character corpse")
	_assert_true(locked.is_worn(&"armor"), "locked projection persists")
	_assert_true(locked_inventory.is_direct_child(&"armor", EndpointScript.new(EndpointScript.Kind.ITEM, &"corpse")), "locked item remains corpse child")


func _test_decay_timing_final_scatter_and_no_environment() -> void:
	var inventory: InventoryScript = InventoryScript.new()
	var stacks: StackCollectionScript = StackCollectionScript.new()
	_register(inventory, &"corpse", CORPSE_DEF, 2, _world_endpoint())
	_register(inventory, &"ordinary", PLAIN_DEF, 3, EndpointScript.new(EndpointScript.Kind.ITEM, &"corpse"))
	_register(inventory, &"worn", ARMOR_DEF, 4, EndpointScript.new(EndpointScript.Kind.ITEM, &"corpse"))
	var corpse: CorpseStateScript = CorpseStateScript.new(&"corpse", CHARACTER_ID, "Dead", &"男性", 10, 50)
	corpse._try_wear(&"boots", &"worn", inventory)
	var initial: DecayIntentScript = DecayServiceScript.initial_intent(corpse)
	_assert_eq(initial.delay_seconds, 120, "stage0 waits 120")
	var invalid_intent: DecayResultScript = DecayServiceScript.advance(
		corpse,
		DecayIntentScript.new(&"wrong_corpse", 0, 1, 120),
		inventory,
		stacks,
	)
	_assert_eq(invalid_intent.outcome, DecayResultScript.Outcome.INVALID_INTENT, "corpse ID mismatch is rejected")
	_assert_eq(corpse.decay_stage, CorpseStateScript.Stage.FRESH, "invalid intent does not mutate stage")
	var rotten: DecayResultScript = DecayServiceScript.advance(corpse, initial, inventory, stacks)
	_assert_eq(rotten.current_stage, CorpseStateScript.Stage.ROTTEN, "stage0 to stage1")
	_assert_eq(rotten.next_intent.delay_seconds, 120, "stage1 waits another 120")
	_assert_true(corpse.is_legacy_corpse(), "rotten stage still qualifies as corpse")
	_assert_false(corpse.is_legacy_character_for_equipment(), "rotten stage stops being character")
	var skeleton: DecayResultScript = DecayServiceScript.advance(corpse, rotten.next_intent, inventory, stacks)
	_assert_eq(skeleton.current_stage, CorpseStateScript.Stage.SKELETON, "stage1 to stage2")
	_assert_eq(skeleton.next_intent.delay_seconds, 60, "stage2 waits 60")
	_assert_false(corpse.is_legacy_corpse(), "skeleton no longer qualifies as corpse")
	var final: DecayResultScript = DecayServiceScript.advance(
		corpse, skeleton.next_intent, inventory, stacks, _world_destination()
	)
	_assert_eq(final.outcome, DecayResultScript.Outcome.FINALIZED, "stage2 finalizes corpse")
	_assert_eq(final.scatter_results.size(), 2, "final scatter attempts direct snapshot only")
	_assert_true(inventory.is_direct_child(&"ordinary", _world_endpoint()), "ordinary content scatters and survives")
	_assert_false(inventory.is_registered(&"worn"), "locked corpse-worn item dies with corpse")
	_assert_false(inventory.is_registered(&"corpse"), "corpse liveness removed")
	_assert_eq(final.lifecycle_result.removed_instance_ids, [&"worn", &"corpse"], "final subtree removal is post-order exact")
	_assert_eq(corpse.decay_stage, CorpseStateScript.Stage.FINAL, "state reached final stage without destroyed flag")
	var stale_advance: DecayResultScript = DecayServiceScript.advance(
		corpse,
		skeleton.next_intent,
		inventory,
		stacks,
	)
	_assert_eq(stale_advance.outcome, DecayResultScript.Outcome.INVALID_DOMAIN_STATE, "stale corpse state cannot advance after liveness removal")

	var fail_inventory: InventoryScript = InventoryScript.new()
	var fail_stacks: StackCollectionScript = StackCollectionScript.new()
	_register(fail_inventory, &"corpse", CORPSE_DEF, 0, _world_endpoint())
	_register(fail_inventory, &"ordinary", PLAIN_DEF, 1, EndpointScript.new(EndpointScript.Kind.ITEM, &"corpse"))
	var fail_corpse: CorpseStateScript = CorpseStateScript.new(&"corpse")
	var fail_i1: DecayResultScript = DecayServiceScript.advance(fail_corpse, DecayServiceScript.initial_intent(fail_corpse), fail_inventory, fail_stacks)
	var fail_i2: DecayResultScript = DecayServiceScript.advance(fail_corpse, fail_i1.next_intent, fail_inventory, fail_stacks)
	var unavailable: DestinationScript = DestinationScript.new(_world_endpoint(), false, true, 100)
	var failed_final: DecayResultScript = DecayServiceScript.advance(fail_corpse, fail_i2.next_intent, fail_inventory, fail_stacks, unavailable)
	_assert_false(failed_final.scatter_results[0].succeeded, "ignored ordinary scatter failure is recorded")
	_assert_false(fail_inventory.is_registered(&"ordinary"), "failed scatter remains child then subtree destruction removes it")
	_assert_eq(failed_final.lifecycle_result.removed_instance_ids, [&"ordinary", &"corpse"], "failed scatter subtree removed")

	var orphan_inventory: InventoryScript = InventoryScript.new()
	var orphan_stacks: StackCollectionScript = StackCollectionScript.new()
	_register(orphan_inventory, &"corpse", CORPSE_DEF, 0, null)
	_register(orphan_inventory, &"child", PLAIN_DEF, 1, EndpointScript.new(EndpointScript.Kind.ITEM, &"corpse"))
	var orphan: CorpseStateScript = CorpseStateScript.new(&"corpse")
	var orphan1: DecayResultScript = DecayServiceScript.advance(orphan, DecayServiceScript.initial_intent(orphan), orphan_inventory, orphan_stacks)
	var orphan2: DecayResultScript = DecayServiceScript.advance(orphan, orphan1.next_intent, orphan_inventory, orphan_stacks)
	var orphan_final: DecayResultScript = DecayServiceScript.advance(orphan, orphan2.next_intent, orphan_inventory, orphan_stacks)
	_assert_eq(orphan_final.scatter_results.size(), 0, "no-environment corpse skips scatter")
	_assert_false(orphan_inventory.is_registered(&"child"), "no-environment contents destroyed")
	_assert_false(orphan_inventory.is_registered(&"corpse"), "no-environment corpse destroyed")


func _test_stack_cleanup_and_independent_state() -> void:
	var inventory: InventoryScript = InventoryScript.new()
	var stacks: StackCollectionScript = StackCollectionScript.new()
	_register(inventory, &"corpse", CORPSE_DEF, 0, null)
	var stack_item: ItemInstanceScript = _register(inventory, &"stack", &"item:stack", 99, EndpointScript.new(EndpointScript.Kind.ITEM, &"corpse"))
	var stack_definition: StackDefinitionScript = StackDefinitionScript.new(&"item:stack", &"legacy:stack", 5)
	StackServiceScript.register_stack(stacks, inventory, stack_item, stack_definition, 3)
	var pending: StackAmountResultScript = StackServiceScript.set_amount(
		stacks, inventory, &"stack", 0
	)
	_assert_eq(
		pending.lifecycle_action,
		pending.LifecycleAction.DELAYED_DESTRUCTION,
		"explicit zero remains pending live state",
	)
	_assert_eq(stacks.stack_state(&"stack").amount, 3, "pending zero retains old amount")
	_assert_eq(inventory.own_weight(&"stack"), 15, "pending zero retains old weight")
	var corpse: CorpseStateScript = CorpseStateScript.new(&"corpse")
	var one: DecayResultScript = DecayServiceScript.advance(corpse, DecayServiceScript.initial_intent(corpse), inventory, stacks)
	var two: DecayResultScript = DecayServiceScript.advance(corpse, one.next_intent, inventory, stacks)
	DecayServiceScript.advance(corpse, two.next_intent, inventory, stacks)
	_assert_false(inventory.is_registered(&"stack"), "final lifecycle removes pending stack")
	_assert_false(stacks.has_stack(&"stack"), "final lifecycle cleans stack association")

	var first: CorpseStateScript = CorpseStateScript.new(&"first")
	var second: CorpseStateScript = CorpseStateScript.new(&"second")
	var projection_inventory: InventoryScript = InventoryScript.new()
	_register(projection_inventory, &"first", CORPSE_DEF, 0, null)
	_register(projection_inventory, &"one", ARMOR_DEF, 0, EndpointScript.new(EndpointScript.Kind.ITEM, &"first"))
	first._try_wear(&"boots", &"one", projection_inventory)
	_assert_true(first.is_worn(&"one"), "first corpse owns its projection")
	_assert_false(second.is_worn(&"one"), "corpse projections are not shared")


func _test_fact_binding_and_policy_lifecycle_failure() -> void:
	var bound_item: ItemInstanceScript = ItemInstanceScript.new(&"bound", MAILBOX_DEF)
	var bound: DeathFactsScript = DeathFactsScript.new(bound_item)
	_assert_eq(bound.item_instance_id, &"bound", "facts bind one immutable instance ID")
	_assert_eq(bound.item_definition_id, MAILBOX_DEF, "facts derive definition from same instance")
	_assert_false(DeathFactsScript.new(null).has_valid_identity(), "null instance cannot create valid facts")

	var inventory: InventoryScript = InventoryScript.new()
	var equipment: EquipmentScript = EquipmentScript.new()
	var failing_armor: ArmorScript = FailingArmorStateScript.new(&"hybrid")
	var owner: OwnerContextScript = OwnerContextScript.new(
		CHARACTER_ID,
		equipment,
		failing_armor,
	)
	var hybrid: ItemInstanceScript = _register(
		inventory,
		&"hybrid",
		MAILBOX_DEF,
		1,
		_character_endpoint(),
	)
	equipment.wield(
		WeaponRefScript.new(
			hybrid.item_instance_id,
			WeaponDefinitionScript.new(MAILBOX_DEF, &"sword", 0),
		),
		false,
	)
	var policies: DeathPolicyRegistryScript = DeathPolicyRegistryScript.new()
	policies.register_policy(MAILBOX_DEF, DestroyPolicyScript.new())
	var result: DeathResultScript = DeathServiceScript.process(
		_context(owner, true),
		inventory,
		StackCollectionScript.new(),
		[_facts(hybrid)],
		policies,
		RewearRegistryScript.new(),
	)
	_assert_eq(result.outcome, DeathResultScript.Outcome.POLICY_DESTRUCTION_FAILED, "policy lifecycle failure is top-level exact")
	_assert_eq(result.policy_lifecycle_results.size(), 1, "failed lifecycle evidence is retained")
	_assert_eq(result.policy_lifecycle_results[0].outcome, LifecycleResultScript.Outcome.ARMOR_DETACH_FAILED, "exact lifecycle failure is observable")
	_assert_true(result.policy_lifecycle_results[0].weapon_detached, "partial hand cleanup is observable")
	var lifecycle_copy: Array[LifecycleResultScript] = result.policy_lifecycle_results
	lifecycle_copy.clear()
	_assert_eq(result.policy_lifecycle_results.size(), 1, "lifecycle result array is defensive")
	_assert_true(equipment.are_both_hands_empty(), "partial lifecycle cleanup remains authoritative")
	_assert_true(inventory.is_registered(&"hybrid"), "failed destruction leaves item live")
	_assert_eq(result.destroyed_instance_ids, [], "failed policy is not reported destroyed")
	_assert_eq(result.survivor_transfer_results, [], "failed policy is not treated as survivor")
	_assert_eq(result.completion_status, DeathResultScript.CompletionStatus.BLOCKED_INCOMPLETE, "partial failure is incomplete")
	_assert_eq(result.restart_disposition, DeathResultScript.RestartDisposition.DO_NOT_RESTART_FROM_BEGINNING, "partial failure forbids blind restart")


func _test_blocked_processing_is_not_restartable() -> void:
	var wind_inventory: InventoryScript = InventoryScript.new()
	var wind_owner: OwnerContextScript = _owner()
	var first: ItemInstanceScript = _register(wind_inventory, &"a_keep", PLAIN_DEF, 1, _character_endpoint())
	var wind: ItemInstanceScript = _register(wind_inventory, &"b_wind", WINDSPRING_DEF, 1, _character_endpoint())
	var later_mail: ItemInstanceScript = _register(wind_inventory, &"c_mail", MAILBOX_DEF, 1, _character_endpoint())
	var wind_policies: DeathPolicyRegistryScript = DeathPolicyRegistryScript.new()
	wind_policies.register_policy(WINDSPRING_DEF, WindspringPolicyScript.new())
	wind_policies.register_policy(MAILBOX_DEF, DestroyPolicyScript.new())
	var blocked: DeathResultScript = DeathServiceScript.process(
		_context(wind_owner), wind_inventory, StackCollectionScript.new(),
		[_facts(first), _facts(wind), _facts(later_mail)], wind_policies,
		RewearRegistryScript.new(), ItemInstanceScript.new(&"wind_corpse", CORPSE_DEF),
		ItemDefinitionScript.new(CORPSE_DEF),
	)
	_assert_eq(blocked.outcome, DeathResultScript.Outcome.DEFERRED_RUNTIME_EFFECT, "windspring blocks at source order boundary")
	_assert_eq(blocked.policy_results.size(), 2, "later policy is not evaluated after deferred effect")
	_assert_true(wind_inventory.is_registered(&"c_mail"), "later mailbox remains live and unevaluated")
	_assert_eq(blocked.survivor_transfer_results, [], "survivor movement has not begun")
	_assert_eq(blocked.completion_status, DeathResultScript.CompletionStatus.BLOCKED_INCOMPLETE, "windspring result says incomplete")
	_assert_eq(blocked.restart_disposition, DeathResultScript.RestartDisposition.DO_NOT_RESTART_FROM_BEGINNING, "created corpse and policy work cannot be replayed")

	var skirt_inventory: InventoryScript = InventoryScript.new()
	var skirt_owner: OwnerContextScript = _owner()
	var later: ItemInstanceScript = _register(skirt_inventory, &"a_later", PLAIN_DEF, 1, _character_endpoint())
	var skirt: ItemInstanceScript = _register(skirt_inventory, &"z_skirt", SKIRT_DEF, 1, _character_endpoint())
	var skirt_definition: ArmorDefinitionScript = _armor_definition(SKIRT_DEF, &"waist")
	ArmorServiceScript.wear(skirt_owner.armor_state, skirt_inventory, _character_endpoint(), skirt, skirt_definition)
	var rewear: RewearRegistryScript = RewearRegistryScript.new()
	rewear.register_latemoon_skirt(SKIRT_DEF)
	var skirt_blocked: DeathResultScript = DeathServiceScript.process(
		_context(skirt_owner), skirt_inventory, StackCollectionScript.new(),
		[_facts(later), _facts(skirt, skirt_definition)], DeathPolicyRegistryScript.new(),
		rewear, ItemInstanceScript.new(&"skirt_corpse", CORPSE_DEF),
		ItemDefinitionScript.new(CORPSE_DEF),
	)
	_assert_eq(skirt_blocked.outcome, DeathResultScript.Outcome.REWEAR_DEPENDENCY_UNAVAILABLE, "missing dynamic actor blocks in source order")
	_assert_eq(skirt_blocked.survivor_transfer_results.size(), 1, "only skirt move completed before dependency")
	_assert_true(skirt_inventory.is_direct_child(&"a_later", _character_endpoint()), "later survivor is not processed")
	_assert_eq(skirt_blocked.restart_disposition, DeathResultScript.RestartDisposition.DO_NOT_RESTART_FROM_BEGINNING, "skirt dependency cannot replay earlier move")

	var timing_inventory: InventoryScript = InventoryScript.new()
	var timing_owner: OwnerContextScript = _owner()
	var invalid_armor: ItemInstanceScript = _register(timing_inventory, &"a_bad", ARMOR_DEF, 1, _character_endpoint())
	var earlier_move: ItemInstanceScript = _register(timing_inventory, &"z_first", PLAIN_DEF, 1, _character_endpoint())
	ArmorServiceScript.wear(timing_owner.armor_state, timing_inventory, _character_endpoint(), invalid_armor, _armor_definition(ARMOR_DEF, &"cloth"))
	var timing: DeathResultScript = DeathServiceScript.process(
		_context(timing_owner), timing_inventory, StackCollectionScript.new(),
		[_facts(invalid_armor), _facts(earlier_move)], DeathPolicyRegistryScript.new(),
		RewearRegistryScript.new(), ItemInstanceScript.new(&"timing_corpse", CORPSE_DEF),
		ItemDefinitionScript.new(CORPSE_DEF),
	)
	_assert_eq(timing.outcome, DeathResultScript.Outcome.INVALID_ITEM_FACTS, "worn facts validate when loop reaches item")
	_assert_eq(timing.survivor_transfer_results.size(), 1, "prior reverse-loop transfer remains recorded")
	_assert_true(timing_inventory.is_direct_child(&"z_first", EndpointScript.new(EndpointScript.Kind.ITEM, &"timing_corpse")), "prior transfer occurs before later worn validation")


func _test_capacity_placement_and_decay_boundaries() -> void:
	var exact_inventory: InventoryScript = InventoryScript.new()
	var exact_owner: OwnerContextScript = _owner()
	var exact_item: ItemInstanceScript = _register(exact_inventory, &"exact", PLAIN_DEF, 5, _character_endpoint())
	var exact: DeathResultScript = DeathServiceScript.process(
		_context(exact_owner, false, false, false, &"", 1000, 10, 100, 5),
		exact_inventory, StackCollectionScript.new(), [_facts(exact_item)],
		DeathPolicyRegistryScript.new(), RewearRegistryScript.new(),
		ItemInstanceScript.new(&"exact_corpse", CORPSE_DEF), ItemDefinitionScript.new(CORPSE_DEF),
	)
	_assert_true(exact.survivor_transfer_results[0].succeeded, "equal corpse contents capacity succeeds")
	_assert_eq(exact_inventory.contents_weight(EndpointScript.new(EndpointScript.Kind.ITEM, &"exact_corpse")), 5, "corpse own weight is excluded from contents capacity")

	var unplaced_inventory: InventoryScript = InventoryScript.new()
	var unplaced_owner: OwnerContextScript = _owner()
	var unplaced_item: ItemInstanceScript = _register(unplaced_inventory, &"inside", PLAIN_DEF, 2, _character_endpoint())
	var unplaced_result: DeathResultScript = DeathServiceScript.process(
		_context(unplaced_owner, false, false, false, &"", 0, 10, 5, 10),
		unplaced_inventory, StackCollectionScript.new(), [_facts(unplaced_item)],
		DeathPolicyRegistryScript.new(), RewearRegistryScript.new(),
		ItemInstanceScript.new(&"unplaced_normal", CORPSE_DEF), ItemDefinitionScript.new(CORPSE_DEF),
	)
	_assert_false(unplaced_result.corpse_placement_result.succeeded, "normal placement failure is retained")
	_assert_true(unplaced_inventory.is_direct_child(&"inside", EndpointScript.new(EndpointScript.Kind.ITEM, &"unplaced_normal")), "normal processing continues into unparented corpse")
	var u1: DecayResultScript = DecayServiceScript.advance(unplaced_result.corpse_state, unplaced_result.initial_decay_intent, unplaced_inventory, StackCollectionScript.new())
	var u2: DecayResultScript = DecayServiceScript.advance(unplaced_result.corpse_state, u1.next_intent, unplaced_inventory, StackCollectionScript.new())
	var u3: DecayResultScript = DecayServiceScript.advance(unplaced_result.corpse_state, u2.next_intent, unplaced_inventory, StackCollectionScript.new())
	_assert_eq(u3.outcome, DecayResultScript.Outcome.FINALIZED, "unparented corpse completes decay")
	_assert_false(unplaced_inventory.is_registered(&"inside"), "unparented final destruction removes contents")

	var release_inventory: InventoryScript = InventoryScript.new()
	_register(release_inventory, &"release_corpse", CORPSE_DEF, 1, _world_endpoint())
	_register(release_inventory, &"release_armor", ARMOR_DEF, 1, EndpointScript.new(EndpointScript.Kind.ITEM, &"release_corpse"))
	var release_corpse: CorpseStateScript = CorpseStateScript.new(&"release_corpse")
	_assert_true(release_corpse._try_wear(&"boots", &"release_armor", release_inventory), "valid direct content can enter projection")
	var release_failure: ContentTransferResultScript = ContentTransferServiceScript.transfer_out(
		release_corpse, release_inventory, &"release_armor",
		DestinationScript.new(_world_endpoint(), false, true, 100),
	)
	_assert_false(release_failure.succeeded, "stage0 released transfer can fail")
	_assert_true(release_failure.corpse_worn_released, "failed move records prior projection release")
	_assert_false(release_corpse.is_worn(&"release_armor"), "failed move does not restore legacy marker")
	_assert_true(release_inventory.is_direct_child(&"release_armor", EndpointScript.new(EndpointScript.Kind.ITEM, &"release_corpse")), "failed move keeps containment")
	_assert_false(release_corpse._try_wear(&"mask", &"missing", release_inventory), "projection rejects non-live item")

	var intent_inventory: InventoryScript = InventoryScript.new()
	_register(intent_inventory, &"intent_corpse", CORPSE_DEF, 0, null)
	var intent_corpse: CorpseStateScript = CorpseStateScript.new(&"intent_corpse")
	var invalid_intents: Array[DecayIntentScript] = [
		DecayIntentScript.new(&"intent_corpse", 1, 2, 120),
		DecayIntentScript.new(&"intent_corpse", 0, 2, 120),
		DecayIntentScript.new(&"intent_corpse", 0, 1, 119),
	]
	for invalid: DecayIntentScript in invalid_intents:
		var rejected: DecayResultScript = DecayServiceScript.advance(intent_corpse, invalid, intent_inventory, StackCollectionScript.new())
		_assert_eq(rejected.outcome, DecayResultScript.Outcome.INVALID_INTENT, "wrong stage/skip/delay intent rejected")
		_assert_eq(intent_corpse.decay_stage, CorpseStateScript.Stage.FRESH, "rejected intent cannot mutate")

	var destination_inventory: InventoryScript = InventoryScript.new()
	_register(destination_inventory, &"destination_corpse", CORPSE_DEF, 0, _world_endpoint())
	var destination_corpse: CorpseStateScript = CorpseStateScript.new(&"destination_corpse")
	var d1: DecayResultScript = DecayServiceScript.advance(destination_corpse, DecayServiceScript.initial_intent(destination_corpse), destination_inventory, StackCollectionScript.new())
	var d2: DecayResultScript = DecayServiceScript.advance(destination_corpse, d1.next_intent, destination_inventory, StackCollectionScript.new())
	var missing_destination: DecayResultScript = DecayServiceScript.advance(destination_corpse, d2.next_intent, destination_inventory, StackCollectionScript.new())
	_assert_eq(missing_destination.outcome, DecayResultScript.Outcome.DESTINATION_CONTEXT_REQUIRED, "parented final requires exact destination projection")
	_assert_eq(destination_corpse.decay_stage, CorpseStateScript.Stage.SKELETON, "missing destination cannot advance stage")
	var mismatched_destination: DecayResultScript = DecayServiceScript.advance(
		destination_corpse,
		d2.next_intent,
		destination_inventory,
		StackCollectionScript.new(),
		DestinationScript.new(EndpointScript.new(EndpointScript.Kind.WORLD, &"world:wrong"), true, true, 100),
	)
	_assert_eq(mismatched_destination.outcome, DecayResultScript.Outcome.DESTINATION_MISMATCH, "wrong parent projection is rejected")
	_assert_eq(destination_corpse.decay_stage, CorpseStateScript.Stage.SKELETON, "destination mismatch cannot advance stage")

	var final_inventory: InventoryScript = InventoryScript.new()
	_register(final_inventory, &"final_corpse", CORPSE_DEF, 0, _character_endpoint())
	_register(final_inventory, &"scattered", PLAIN_DEF, 1, EndpointScript.new(EndpointScript.Kind.ITEM, &"final_corpse"))
	var final_corpse: CorpseStateScript = CorpseStateScript.new(&"final_corpse")
	var f1: DecayResultScript = DecayServiceScript.advance(final_corpse, DecayServiceScript.initial_intent(final_corpse), final_inventory, StackCollectionScript.new())
	var f2: DecayResultScript = DecayServiceScript.advance(final_corpse, f1.next_intent, final_inventory, StackCollectionScript.new())
	var character_destination: DestinationScript = DestinationScript.new(_character_endpoint(), true, true, 100)
	var final_failure: DecayResultScript = DecayServiceScript.advance(final_corpse, f2.next_intent, final_inventory, StackCollectionScript.new(), character_destination)
	_assert_eq(final_failure.outcome, DecayResultScript.Outcome.FINAL_DESTRUCTION_FAILED, "final lifecycle failure is not hidden")
	_assert_eq(final_failure.lifecycle_result.outcome, LifecycleResultScript.Outcome.OWNER_CONTEXT_REQUIRED, "final exact lifecycle dependency is retained")
	_assert_eq(final_corpse.decay_stage, CorpseStateScript.Stage.FINAL, "final stage mutation precedes failed destruction")
	_assert_true(final_inventory.is_registered(&"final_corpse"), "failed final destruction keeps corpse live")
	_assert_true(final_inventory.is_direct_child(&"scattered", _character_endpoint()), "successful scatter is not rolled back")


func _context(
	owner: OwnerContextScript,
	is_ghost: bool = false,
	is_wizard: bool = false,
	is_sword_soul: bool = false,
	rewear_actor_gender: StringName = &"",
	world_capacity: int = 100000,
	age: int = 20,
	body_weight: int = 100,
	maximum_encumbrance: int = 1000,
) -> DeathContextScript:
	return DeathContextScript.new(
		CHARACTER_ID,
		is_ghost,
		is_wizard,
		_world_destination(world_capacity),
		owner,
		"Dead One",
		&"男性",
		age,
		body_weight,
		maximum_encumbrance,
		is_sword_soul,
		null,
		rewear_actor_gender,
	)


func _owner() -> OwnerContextScript:
	return OwnerContextScript.new(
		CHARACTER_ID,
		EquipmentScript.new(),
		ArmorScript.new(),
	)


func _register(
	inventory: InventoryScript,
	instance_id: StringName,
	definition_id: StringName,
	weight: int,
	parent: EndpointScript,
) -> ItemInstanceScript:
	var item: ItemInstanceScript = ItemInstanceScript.new(instance_id, definition_id)
	_assert_true(inventory.register_item(item, weight), "register %s" % instance_id)
	if parent != null:
		_assert_true(inventory._apply_reparent(instance_id, parent), "parent %s" % instance_id)
	return item


func _facts(
	item: ItemInstanceScript,
	armor_definition: ArmorDefinitionScript = null,
) -> DeathFactsScript:
	return DeathFactsScript.new(
		item,
		armor_definition,
	)


func _armor_definition(
	definition_id: StringName,
	armor_type: StringName,
) -> ArmorDefinitionScript:
	return ArmorDefinitionScript.new(
		definition_id,
		armor_type,
		ArmorModifiersScript.new(),
	)


func _character_endpoint() -> EndpointScript:
	return EndpointScript.new(EndpointScript.Kind.CHARACTER, CHARACTER_ID)


func _world_endpoint() -> EndpointScript:
	return EndpointScript.new(EndpointScript.Kind.WORLD, WORLD_ID)


func _world_destination(capacity: int = 100000) -> DestinationScript:
	return DestinationScript.new(_world_endpoint(), true, true, capacity)


func _assert_true(value: bool, label: String) -> void:
	_assertion_count += 1
	if not value:
		_failures.append("%s: expected true" % label)


func _assert_false(value: bool, label: String) -> void:
	_assertion_count += 1
	if value:
		_failures.append("%s: expected false" % label)


func _assert_eq(actual: Variant, expected: Variant, label: String) -> void:
	_assertion_count += 1
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [label, expected, actual])
