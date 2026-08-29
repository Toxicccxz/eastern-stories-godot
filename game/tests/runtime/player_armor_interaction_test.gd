extends RefCounted

const PLAYER_ID: StringName = &"player"
const LEATHER_ID: StringName = &"item:leather"

class ArmorFixture extends RefCounted:
	var player: WorldPlayerRuntimeState
	var inventory: InventoryState = InventoryState.new()
	var stacks: CombinedStackCollection = CombinedStackCollection.new()
	var index: WorldItemInstanceIndex = WorldItemInstanceIndex.new()
	var projection: PlayerInventoryProjection = PlayerInventoryProjection.new()
	var adapter: OldPineArmorInteractionAdapter = OldPineArmorInteractionAdapter.new()

var _assertion_count: int = 0
var _failures: Array[String] = []


func run_all() -> Dictionary[String, Variant]:
	_test_live_projection_wear_remove_and_weapon_independence()
	_test_slot_occupancy_uses_closed_armor_result()
	_test_stale_wear_and_remove_rows_are_rejected()
	_test_non_active_player_is_rejected()
	_test_wear_remove_preserve_fighting_and_busy()
	_test_independent_player_armor_authorities()
	return {"assertions": _assertion_count, "failures": _failures.duplicate()}


func _test_live_projection_wear_remove_and_weapon_independence() -> void:
	var fixture: ArmorFixture = _make_fixture()
	var row: PlayerInventoryRowProjection = _leather_row(fixture)
	_assert_eq(row.display_name, "皮衣", "leather row name")
	_assert_eq(row.description, "皮衣(Leather)。\n", "leather row description")
	_assert_eq(row.category, OldPineItemContentDefinitions.CATEGORY_ARMOR, "leather row category")
	_assert_eq(row.equipment_slot, PlayerInventoryRowProjection.EquipmentSlot.NONE, "taken leather starts NONE")
	_assert_eq(row.armor_type, &"cloth", "leather row cloth slot")
	_assert_eq(row.armor_modifiers.armor, 5, "leather row armor +5")
	_assert_eq(row.armor_modifiers.dodge, -2, "leather row dodge -2")
	_assert_true(row.can_wear, "active owned unworn leather offers Wear")
	_assert_false(row.can_remove, "unworn leather offers no Remove")
	var weapon_before: EquippedWeaponRef = fixture.player.state.equipment.primary_weapon()
	var wear: OldPineArmorInteractionResult = fixture.adapter.wear(
		fixture.player, LEATHER_ID, fixture.inventory, fixture.index
	)
	_assert_true(wear.succeeded and wear.changed, "Wear delegates to ArmorService")
	_assert_eq(wear.armor_transition.outcome, ArmorTransitionResult.Outcome.WORN, "exact ArmorService WORN result")
	_assert_eq(fixture.player.armor.item_instance_id_in_slot(&"cloth"), LEATHER_ID, "live cloth slot owns exact instance")
	row = _leather_row(fixture)
	_assert_eq(row.equipment_slot, PlayerInventoryRowProjection.EquipmentSlot.WORN, "projection derives WORN from live ArmorState")
	_assert_false(row.can_wear, "worn leather offers no Wear")
	_assert_true(row.can_remove, "worn leather offers Remove")
	_assert_eq(fixture.player.state.equipment.primary_weapon().instance_id, weapon_before.instance_id, "armor does not alter weapon authority")
	var remove: OldPineArmorInteractionResult = fixture.adapter.remove(
		fixture.player, LEATHER_ID, fixture.inventory, fixture.index
	)
	_assert_true(remove.succeeded and remove.changed, "Remove delegates to ArmorState")
	_assert_eq(remove.armor_transition.outcome, ArmorTransitionResult.Outcome.REMOVED, "exact ArmorState REMOVED result")
	_assert_true(fixture.inventory.is_direct_child(LEATHER_ID, _player_endpoint()), "Remove performs no transfer")
	row = _leather_row(fixture)
	_assert_eq(row.equipment_slot, PlayerInventoryRowProjection.EquipmentSlot.NONE, "next projection returns to NONE")
	_assert_true(row.can_wear and not row.can_remove, "next projection refreshes action availability")


func _test_slot_occupancy_uses_closed_armor_result() -> void:
	var fixture: ArmorFixture = _make_fixture()
	_assert_true(fixture.adapter.wear(fixture.player, LEATHER_ID, fixture.inventory, fixture.index).succeeded, "first cloth wear succeeds")
	var second_id: StringName = &"item:second-leather"
	_add_owned(fixture, second_id, OldPineItemContentDefinitions.LEATHER_ITEM_ID, 6000)
	var occupied: OldPineArmorInteractionResult = fixture.adapter.wear(
		fixture.player, second_id, fixture.inventory, fixture.index
	)
	_assert_false(occupied.succeeded, "second cloth armor is not auto-swapped")
	_assert_eq(occupied.armor_transition.outcome, ArmorTransitionResult.Outcome.SLOT_OCCUPIED, "closed slot-occupied result preserved")
	_assert_eq(fixture.player.armor.item_instance_id_in_slot(&"cloth"), LEATHER_ID, "first exact item remains worn")


func _test_stale_wear_and_remove_rows_are_rejected() -> void:
	var fixture: ArmorFixture = _make_fixture()
	var stale_row: PlayerInventoryRowProjection = _leather_row(fixture)
	_assert_true(stale_row.can_wear, "fixture captures actionable stale row")
	_assert_true(InventoryTransferService.new().transfer(
		fixture.inventory,
		LEATHER_ID,
		InventoryTransferDestination.new(ContainmentEndpoint.new(ContainmentEndpoint.Kind.WORLD, &"zone"), true, true, 100000),
	).succeeded, "fixture moves leather after row projection")
	var stale: OldPineArmorInteractionResult = fixture.adapter.wear(
		fixture.player, stale_row.item_instance_id, fixture.inventory, fixture.index
	)
	_assert_eq(stale.outcome, OldPineArmorInteractionResult.Outcome.ITEM_NOT_DIRECTLY_OWNED, "stale Wear revalidates live direct ownership")
	_assert_true(fixture.player.armor.occupied_slots().is_empty(), "stale Wear mutates no armor")

	var stale_remove: ArmorFixture = _make_fixture()
	_assert_true(stale_remove.adapter.wear(stale_remove.player, LEATHER_ID, stale_remove.inventory, stale_remove.index).succeeded, "stale Remove fixture wears first leather")
	var stale_remove_row: PlayerInventoryRowProjection = _leather_row(stale_remove)
	_assert_true(stale_remove_row.can_remove, "fixture captures actionable stale Remove row")
	_assert_true(stale_remove.player.armor.remove(LEATHER_ID).succeeded, "authority removes first leather before stale action")
	var replacement_id: StringName = &"item:replacement-leather"
	var replacement: ItemInstance = _add_owned(
		stale_remove,
		replacement_id,
		OldPineItemContentDefinitions.LEATHER_ITEM_ID,
		6000,
	)
	var replacement_definition: ArmorDefinition = (
		OldPineItemContentDefinitions.content_by_id(
			replacement.item_definition_id
		).armor_definition()
	)
	_assert_true(ArmorService.wear(
		stale_remove.player.armor,
		stale_remove.inventory,
		_player_endpoint(),
		replacement,
		replacement_definition,
	).succeeded, "replacement exact item now occupies cloth")
	var stale_remove_result: OldPineArmorInteractionResult = stale_remove.adapter.remove(
		stale_remove.player,
		stale_remove_row.item_instance_id,
		stale_remove.inventory,
		stale_remove.index,
	)
	_assert_eq(stale_remove_result.outcome, OldPineArmorInteractionResult.Outcome.ITEM_NOT_WORN, "stale Remove revalidates exact current slot identity")
	_assert_eq(stale_remove.player.armor.item_instance_id_in_slot(&"cloth"), replacement_id, "stale Remove cannot remove replacement armor")


func _test_non_active_player_is_rejected() -> void:
	var inactive: ArmorFixture = _make_fixture()

	inactive.player.set_life_status(CharacterRuntimeLifeStatus.Value.UNCONSCIOUS)
	var inactive_wear: OldPineArmorInteractionResult = inactive.adapter.wear(
		inactive.player, LEATHER_ID, inactive.inventory, inactive.index
	)
	_assert_eq(inactive_wear.outcome, OldPineArmorInteractionResult.Outcome.PLAYER_NOT_ACTIVE, "unconscious player cannot Wear")
	inactive.player.set_life_status(CharacterRuntimeLifeStatus.Value.ACTIVE)
	_assert_true(inactive.adapter.wear(inactive.player, LEATHER_ID, inactive.inventory, inactive.index).succeeded, "fixture wears while active")
	inactive.player.set_life_status(CharacterRuntimeLifeStatus.Value.DEAD)
	var inactive_remove: OldPineArmorInteractionResult = inactive.adapter.remove(
		inactive.player, LEATHER_ID, inactive.inventory, inactive.index
	)
	_assert_eq(inactive_remove.outcome, OldPineArmorInteractionResult.Outcome.PLAYER_NOT_ACTIVE, "dead player cannot Remove")
	_assert_true(inactive.player.armor.is_worn(LEATHER_ID), "failed inactive Remove preserves armor")


func _test_wear_remove_preserve_fighting_and_busy() -> void:
	var fixture: ArmorFixture = _make_fixture()
	_assert_true(fixture.player.relationship.mark_lethal_target(&"test.enemy"), "fixture establishes active combat relationship")
	_assert_true(fixture.player.busy.start_busy(4), "fixture starts existing busy state")
	var wear: OldPineArmorInteractionResult = fixture.adapter.wear(
		fixture.player, LEATHER_ID, fixture.inventory, fixture.index
	)
	_assert_true(wear.succeeded, "source-permitted Wear succeeds while fighting and busy")
	_assert_true(fixture.player.relationship.has_lethal_target(&"test.enemy"), "Wear preserves lethal relationship")
	_assert_true(fixture.player.relationship.is_fighting(), "Wear preserves fighting state")
	_assert_eq(fixture.player.busy.busy_value, 4, "Wear does not advance or replace busy")
	var remove: OldPineArmorInteractionResult = fixture.adapter.remove(
		fixture.player, LEATHER_ID, fixture.inventory, fixture.index
	)
	_assert_true(remove.succeeded, "source-permitted Remove succeeds while fighting and busy")
	_assert_true(fixture.player.relationship.has_lethal_target(&"test.enemy"), "Remove preserves lethal relationship")
	_assert_true(fixture.player.relationship.is_fighting(), "Remove preserves fighting state")
	_assert_eq(fixture.player.busy.busy_value, 4, "Remove does not advance or replace busy")


func _test_independent_player_armor_authorities() -> void:
	var left: ArmorFixture = _make_fixture()
	var right: ArmorFixture = _make_fixture()
	_assert_true(left.adapter.wear(left.player, LEATHER_ID, left.inventory, left.index).succeeded, "left wears leather")
	_assert_true(left.player.armor.is_worn(LEATHER_ID), "left ArmorState changed")
	_assert_false(right.player.armor.is_worn(LEATHER_ID), "right ArmorState remains independent")


func _make_fixture() -> ArmorFixture:
	var fixture: ArmorFixture = ArmorFixture.new()
	fixture.player = WorldPlayerRuntimeState.new(
		PLAYER_ID,
		CharacterState.new(),
		CombatRelationshipState.new(PLAYER_ID),
		ActionBusyState.new(),
		ArmorState.new(),
		WorldLocationState.new(&"oldpine", &"outdoor", &"zone", &"zone"),
		CharacterRuntimeLifeStatus.Value.ACTIVE,
		true,
		true,
		100000,
	)
	_add_owned(fixture, LEATHER_ID, OldPineItemContentDefinitions.LEATHER_ITEM_ID, 6000)
	var sword: ItemInstance = _add_owned(
		fixture,
		&"item:long-sword",
		OldPineItemContentDefinitions.LONG_SWORD_ITEM_ID,
		7000,
	)
	var sword_content: OldPineItemContentDefinition = OldPineItemContentDefinitions.content_by_id(sword.item_definition_id)
	fixture.player.state.equipment.wield(
		EquippedWeaponRef.new(
			sword.item_instance_id,
			WeaponDefinition.new(sword.item_definition_id, sword_content.weapon_skill_type, sword_content.can_wield_secondary, sword_content.is_two_handed, sword_content.legacy_source_paths()[0]),
		),
		false,
	)
	return fixture


func _add_owned(
	fixture: ArmorFixture,
	instance_id: StringName,
	definition_id: StringName,
	weight: int,
) -> ItemInstance:
	var item: ItemInstance = ItemInstance.new(instance_id, definition_id)
	fixture.inventory.register_item(item, weight)
	fixture.index.register_snapshot(item)
	InventoryTransferService.new().transfer(
		fixture.inventory,
		instance_id,
		InventoryTransferDestination.new(_player_endpoint(), true, true, 100000),
	)
	return item


func _leather_row(fixture: ArmorFixture) -> PlayerInventoryRowProjection:
	return fixture.projection.project_item(
		fixture.player,
		fixture.inventory,
		fixture.stacks,
		fixture.index,
		LEATHER_ID,
	)


func _player_endpoint() -> ContainmentEndpoint:
	return ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, PLAYER_ID)


func _assert_true(value: bool, label: String) -> void:
	_assertion_count += 1
	if not value:
		_failures.append(label)


func _assert_false(value: bool, label: String) -> void:
	_assert_true(not value, label)


func _assert_eq(actual: Variant, expected: Variant, label: String) -> void:
	_assertion_count += 1
	if actual != expected:
		_failures.append("%s (actual=%s expected=%s)" % [label, actual, expected])
