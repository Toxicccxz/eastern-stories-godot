extends RefCounted

class InventoryFixture extends RefCounted:
	var player: WorldPlayerRuntimeState
	var inventory: InventoryState = InventoryState.new()
	var stacks: CombinedStackCollection = CombinedStackCollection.new()
	var index: WorldItemInstanceIndex = WorldItemInstanceIndex.new()
	var projection: PlayerInventoryProjection = PlayerInventoryProjection.new()
	var adapter: OldPineEquipmentInteractionAdapter = (
		OldPineEquipmentInteractionAdapter.new()
	)
	var resolver: OldPineWeaponContentResolver = OldPineWeaponContentResolver.new()
	var long_id: StringName = &"item:long"
	var short_id: StringName = &"item:short"
	var silver_id: StringName = &"item:silver"

var _assertion_count: int = 0
var _failures: Array[String] = []


func run_all() -> Dictionary[String, Variant]:
	_test_live_projection_and_inspect_facts()
	_test_wield_validation_and_exact_hand_rules()
	_test_unwield_validation_and_no_promotion()
	_test_current_weapon_content_resolution()
	_test_content_profile_additive_seam()
	_test_independent_authorities()
	return {"assertions": _assertion_count, "failures": _failures.duplicate()}


func _test_live_projection_and_inspect_facts() -> void:
	var fresh: InventoryFixture = _make_fixture(false, false)
	var rows: Array[PlayerInventoryRowProjection] = fresh.projection.project_rows(
		fresh.player, fresh.inventory, fresh.stacks, fresh.index
	)
	_assert_eq(rows.size(), 1, "fresh player projection contains only prototype long sword")
	_assert_eq(rows[0].item_instance_id, fresh.long_id, "fresh projection keeps exact long sword instance")
	_assert_eq(rows[0].display_name, "长剑", "long sword name comes from Old Pine content")
	_assert_eq(rows[0].equipment_slot, PlayerInventoryRowProjection.EquipmentSlot.PRIMARY, "long sword projects PRIMARY")
	_assert_true(rows[0].can_unwield, "primary long sword exposes Unwield")
	_assert_false(rows[0].can_wield, "already-wielded long sword does not expose Wield")

	var looted: InventoryFixture = _make_fixture(true, true)
	_assert_true(looted.index.register_snapshot(ItemInstance.new(&"stale:metadata", OldPineItemContentDefinitions.SHORT_SWORD_ITEM_ID)), "fixture registers metadata-only stale ID")
	rows = looted.projection.project_rows(
		looted.player, looted.inventory, looted.stacks, looted.index
	)
	_assert_eq(_row_ids(rows), [looted.long_id, looted.short_id, looted.silver_id], "projection order is stable direct-child identity order")
	var long_row: PlayerInventoryRowProjection = _row_for(rows, looted.long_id)
	var short_row: PlayerInventoryRowProjection = _row_for(rows, looted.short_id)
	var silver_row: PlayerInventoryRowProjection = _row_for(rows, looted.silver_id)
	_assert_eq(long_row.weapon_skill_type, &"sword", "long inspect projects sword skill")
	_assert_eq(long_row.weapon_damage, 25, "long inspect projects source damage 25")
	_assert_eq(short_row.display_name, "短剑", "short inspect projects authored name")
	_assert_true(short_row.description.contains("粗制滥造的短剑"), "short inspect projects authored description")
	_assert_eq(short_row.weapon_skill_type, &"sword", "short inspect projects sword skill")
	_assert_eq(short_row.weapon_damage, 15, "short inspect projects source damage 15")
	_assert_eq(short_row.equipment_slot, PlayerInventoryRowProjection.EquipmentSlot.NONE, "looted short sword remains unequipped")
	_assert_true(short_row.can_wield, "owned unequipped short sword exposes Wield")
	_assert_eq(silver_row.display_name, "银子", "silver inspect projects authored name")
	_assert_eq(silver_row.amount, 3, "silver inspect reads live amount three")
	_assert_eq(silver_row.total_value, 300, "silver inspect derives authored 100 times amount three")
	_assert_false(_row_ids(rows).has(&"stale:metadata"), "metadata-only stale ID never enters player inventory projection")
	_assert_true(looted.projection.project_item(looted.player, looted.inventory, looted.stacks, looted.index, &"stale:metadata") == null, "Inspect cannot resolve metadata-only stale ID")
	_assert_true(CombinedStackService.set_amount(looted.stacks, looted.inventory, looted.silver_id, 8).accepted, "fixture applies closed stack amount transition to eight")
	rows = looted.projection.project_rows(
		looted.player, looted.inventory, looted.stacks, looted.index
	)
	var merged_silver_rows: Array[PlayerInventoryRowProjection] = []
	for row: PlayerInventoryRowProjection in rows:
		if row.item_definition_id == OldPineItemContentDefinitions.SILVER_ITEM_ID:
			merged_silver_rows.append(row)
	_assert_eq(merged_silver_rows.size(), 1, "live projection emits one silver survivor row despite stale metadata")
	_assert_eq(merged_silver_rows[0].amount, 8, "live projection reads merged silver amount eight")
	_assert_eq(merged_silver_rows[0].total_value, 800, "merged silver presentation uses source base value 100 times eight")
	var primary_before: EquippedWeaponRef = looted.player.state.equipment.primary_weapon()
	var amount_before: int = looted.stacks.stack_state(looted.silver_id).amount
	_assert_true(looted.projection.project_item(looted.player, looted.inventory, looted.stacks, looted.index, looted.short_id) != null, "Inspect resolves exact live ItemInstanceId")
	_assert_eq(looted.player.state.equipment.primary_weapon().instance_id, primary_before.instance_id, "Inspect mutates no equipment")
	_assert_eq(looted.stacks.stack_state(looted.silver_id).amount, amount_before, "Inspect mutates no stack amount")


func _test_wield_validation_and_exact_hand_rules() -> void:
	var fixture: InventoryFixture = _make_fixture(true, true)
	var nested: InventoryFixture = _make_fixture(true, false)
	var container: ItemInstance = _add_owned_item(
		nested, &"item:container", &"test:container", 100
	)
	_move(
		nested,
		nested.short_id,
		ContainmentEndpoint.new(ContainmentEndpoint.Kind.ITEM, container.item_instance_id),
	)
	var nested_short: OldPineEquipmentInteractionResult = nested.adapter.wield(
		nested.player, nested.short_id, nested.inventory, nested.index
	)
	_assert_eq(nested_short.outcome, OldPineEquipmentInteractionResult.Outcome.ITEM_NOT_DIRECTLY_OWNED, "root-owned nested short is not accepted as direct player inventory")
	_assert_true(nested.projection.project_item(nested.player, nested.inventory, nested.stacks, nested.index, nested.short_id) == null, "root-owned nested short is absent from direct Inventory projection")
	var world_short: ItemInstance = ItemInstance.new(&"world:short", OldPineItemContentDefinitions.SHORT_SWORD_ITEM_ID)
	fixture.inventory.register_item(world_short, 3000)
	fixture.index.register_snapshot(world_short)
	_move(fixture, world_short.item_instance_id, ContainmentEndpoint.new(ContainmentEndpoint.Kind.WORLD, &"zone"))
	var not_owned: OldPineEquipmentInteractionResult = fixture.adapter.wield(
		fixture.player, world_short.item_instance_id, fixture.inventory, fixture.index
	)
	_assert_eq(not_owned.outcome, OldPineEquipmentInteractionResult.Outcome.ITEM_NOT_DIRECTLY_OWNED, "Wield rejects registered non-owned item")
	var stale: OldPineEquipmentInteractionResult = fixture.adapter.wield(
		fixture.player, &"stale", fixture.inventory, fixture.index
	)
	_assert_eq(stale.outcome, OldPineEquipmentInteractionResult.Outcome.ITEM_NOT_REGISTERED, "Wield rejects stale item before metadata lookup")
	var missing_metadata: ItemInstance = ItemInstance.new(
		&"item:missing-metadata",
		OldPineItemContentDefinitions.SHORT_SWORD_ITEM_ID,
	)
	fixture.inventory.register_item(missing_metadata, 3000)
	_move(fixture, missing_metadata.item_instance_id, _player_endpoint())
	var missing_content: OldPineEquipmentInteractionResult = fixture.adapter.wield(
		fixture.player,
		missing_metadata.item_instance_id,
		fixture.inventory,
		fixture.index,
	)
	_assert_eq(missing_content.outcome, OldPineEquipmentInteractionResult.Outcome.ITEM_CONTENT_UNAVAILABLE, "Wield rejects live item when immutable metadata is unavailable")
	var non_weapon: OldPineEquipmentInteractionResult = fixture.adapter.wield(
		fixture.player, fixture.silver_id, fixture.inventory, fixture.index
	)
	_assert_eq(non_weapon.outcome, OldPineEquipmentInteractionResult.Outcome.ITEM_NOT_A_WEAPON, "Wield rejects directly-owned currency")
	fixture.player.set_life_status(CharacterRuntimeLifeStatus.Value.UNCONSCIOUS)
	var inactive: OldPineEquipmentInteractionResult = fixture.adapter.wield(
		fixture.player, fixture.short_id, fixture.inventory, fixture.index
	)
	_assert_eq(inactive.outcome, OldPineEquipmentInteractionResult.Outcome.PLAYER_NOT_ACTIVE, "non-ACTIVE player cannot Wield")
	fixture.player.set_life_status(CharacterRuntimeLifeStatus.Value.ACTIVE)

	var secondary: OldPineEquipmentInteractionResult = fixture.adapter.wield(
		fixture.player, fixture.short_id, fixture.inventory, fixture.index
	)
	_assert_true(secondary.succeeded and secondary.changed, "long primary plus short Wield succeeds")
	_assert_eq(secondary.equipment_transition.outcome, EquipmentTransitionResult.Outcome.WIELDED_SECONDARY, "closed hand rule puts short in secondary")
	_assert_eq(fixture.player.state.equipment.primary_weapon().instance_id, fixture.long_id, "long remains primary")
	_assert_eq(fixture.player.state.equipment.secondary_weapon().instance_id, fixture.short_id, "short becomes secondary")
	var already: OldPineEquipmentInteractionResult = fixture.adapter.wield(
		fixture.player, fixture.short_id, fixture.inventory, fixture.index
	)
	_assert_true(already.succeeded and not already.changed, "already-wielded short preserves LPC recognition success")
	_assert_eq(already.equipment_transition.outcome, EquipmentTransitionResult.Outcome.ALREADY_WIELDED, "already-wielded result remains exact")
	var third_long: ItemInstance = _add_owned_item(
		fixture, &"item:third-long", OldPineItemContentDefinitions.LONG_SWORD_ITEM_ID, 7000
	)
	var full_hands: OldPineEquipmentInteractionResult = fixture.adapter.wield(
		fixture.player, third_long.item_instance_id, fixture.inventory, fixture.index
	)
	_assert_eq(full_hands.equipment_transition.outcome, EquipmentTransitionResult.Outcome.NO_FREE_HAND, "full hands preserve exact EquipmentState failure")

	var empty: InventoryFixture = _make_fixture(true, false)
	empty.adapter.unwield(empty.player, empty.long_id, empty.inventory)
	var primary_short: OldPineEquipmentInteractionResult = empty.adapter.wield(
		empty.player, empty.short_id, empty.inventory, empty.index
	)
	_assert_eq(primary_short.equipment_transition.outcome, EquipmentTransitionResult.Outcome.WIELDED_PRIMARY, "empty hands plus short Wield makes primary")
	_assert_eq(empty.player.state.equipment.primary_weapon().instance_id, empty.short_id, "short is exact primary identity")


func _test_unwield_validation_and_no_promotion() -> void:
	var fixture: InventoryFixture = _make_fixture(true, false)
	fixture.adapter.wield(fixture.player, fixture.short_id, fixture.inventory, fixture.index)
	var remove_primary: OldPineEquipmentInteractionResult = fixture.adapter.unwield(
		fixture.player, fixture.long_id, fixture.inventory
	)
	_assert_eq(remove_primary.equipment_transition.outcome, EquipmentTransitionResult.Outcome.UNWIELDED_PRIMARY, "Unwield removes exact primary")
	_assert_true(fixture.player.state.equipment.primary_weapon() == null, "primary becomes empty")
	_assert_eq(fixture.player.state.equipment.secondary_weapon().instance_id, fixture.short_id, "secondary short remains secondary without promotion")
	var remove_secondary: OldPineEquipmentInteractionResult = fixture.adapter.unwield(
		fixture.player, fixture.short_id, fixture.inventory
	)
	_assert_eq(remove_secondary.equipment_transition.outcome, EquipmentTransitionResult.Outcome.UNWIELDED_SECONDARY, "Unwield removes exact secondary")
	var not_wielded: OldPineEquipmentInteractionResult = fixture.adapter.unwield(
		fixture.player, fixture.short_id, fixture.inventory
	)
	_assert_eq(not_wielded.outcome, OldPineEquipmentInteractionResult.Outcome.ITEM_NOT_WIELDED, "Unwield rejects directly-owned non-wielded item")
	_move(fixture, fixture.short_id, ContainmentEndpoint.new(ContainmentEndpoint.Kind.WORLD, &"zone"))
	var stale_ownership: OldPineEquipmentInteractionResult = fixture.adapter.unwield(
		fixture.player, fixture.short_id, fixture.inventory
	)
	_assert_eq(stale_ownership.outcome, OldPineEquipmentInteractionResult.Outcome.ITEM_NOT_DIRECTLY_OWNED, "Unwield rechecks current direct ownership")


func _test_current_weapon_content_resolution() -> void:
	var fixture: InventoryFixture = _make_fixture(true, false)
	var long_resolution: OldPineWeaponContentResolution = fixture.resolver.resolve(
		fixture.player, fixture.inventory, fixture.index
	)
	_assert_eq(long_resolution.outcome, OldPineWeaponContentResolution.Outcome.LONG_SWORD, "fresh primary resolves exact long profile")
	_assert_eq(long_resolution.content_profile.projected_apply_damage(fixture.player.state.equipment.primary_weapon()), 25, "long profile projects damage 25")
	fixture.adapter.wield(fixture.player, fixture.short_id, fixture.inventory, fixture.index)
	var long_with_secondary: OldPineWeaponContentResolution = fixture.resolver.resolve(
		fixture.player, fixture.inventory, fixture.index
	)
	_assert_eq(long_with_secondary.outcome, OldPineWeaponContentResolution.Outcome.LONG_SWORD, "long primary plus short secondary still resolves long")
	fixture.adapter.unwield(fixture.player, fixture.long_id, fixture.inventory)
	var secondary_only: OldPineWeaponContentResolution = fixture.resolver.resolve(
		fixture.player, fixture.inventory, fixture.index
	)
	_assert_eq(secondary_only.outcome, OldPineWeaponContentResolution.Outcome.UNARMED, "secondary-only resolves primary action as unarmed")
	_assert_true(secondary_only.content_profile.is_valid(), "unarmed-only profile is valid runtime content")
	_assert_eq(secondary_only.content_profile.projected_apply_damage(null), 0, "unarmed profile projects zero weapon damage")
	fixture.adapter.unwield(fixture.player, fixture.short_id, fixture.inventory)
	fixture.adapter.wield(fixture.player, fixture.short_id, fixture.inventory, fixture.index)
	var short_resolution: OldPineWeaponContentResolution = fixture.resolver.resolve(
		fixture.player, fixture.inventory, fixture.index
	)
	_assert_eq(short_resolution.outcome, OldPineWeaponContentResolution.Outcome.SHORT_SWORD, "short primary resolves exact short profile")
	_assert_eq(short_resolution.content_profile.projected_apply_damage(fixture.player.state.equipment.primary_weapon()), 15, "short profile projects damage 15")
	fixture.adapter.unwield(fixture.player, fixture.short_id, fixture.inventory)
	var unarmed: OldPineWeaponContentResolution = fixture.resolver.resolve(
		fixture.player, fixture.inventory, fixture.index
	)
	_assert_eq(unarmed.outcome, OldPineWeaponContentResolution.Outcome.UNARMED, "empty primary resolves unarmed")

	var unsupported_definition: WeaponDefinition = WeaponDefinition.new(
		&"test:unsupported", &"sword", false, false, "test/unsupported.c"
	)
	var unsupported_item: ItemInstance = _add_owned_item(
		fixture, &"item:unsupported", unsupported_definition.weapon_id, 100
	)
	fixture.player.state.equipment.wield(
		EquippedWeaponRef.new(unsupported_item.item_instance_id, unsupported_definition),
		false,
	)
	var unsupported: OldPineWeaponContentResolution = fixture.resolver.resolve(
		fixture.player, fixture.inventory, fixture.index
	)
	_assert_eq(unsupported.outcome, OldPineWeaponContentResolution.Outcome.UNSUPPORTED_PRIMARY, "unsupported live primary is explicit")
	_assert_true(unsupported.content_profile == null, "unsupported primary has no silent long/short profile")
	_assert_true(WorldCombatBindingAdapter.from_player(fixture.player, unsupported.content_profile) == null, "unsupported primary cannot become an accidental unarmed player binding")

	var unavailable: InventoryFixture = _make_fixture(false, false)
	unavailable.adapter.unwield(unavailable.player, unavailable.long_id, unavailable.inventory)
	var unavailable_definition: WeaponDefinition = WeaponDefinition.new(
		&"test:unavailable", &"sword", false, false, "test/unavailable.c"
	)
	var unavailable_item: ItemInstance = ItemInstance.new(
		&"item:unavailable", unavailable_definition.weapon_id
	)
	unavailable.inventory.register_item(unavailable_item, 100)
	unavailable.index.register_snapshot(unavailable_item)
	_move(
		unavailable,
		unavailable_item.item_instance_id,
		ContainmentEndpoint.new(ContainmentEndpoint.Kind.WORLD, &"zone"),
	)
	unavailable.player.state.equipment.wield(
		EquippedWeaponRef.new(unavailable_item.item_instance_id, unavailable_definition),
		false,
	)
	var unavailable_resolution: OldPineWeaponContentResolution = unavailable.resolver.resolve(
		unavailable.player, unavailable.inventory, unavailable.index
	)
	_assert_eq(unavailable_resolution.outcome, OldPineWeaponContentResolution.Outcome.PRIMARY_ITEM_NOT_AVAILABLE, "non-owned primary reference is explicit unavailable, not unarmed")
	_assert_true(unavailable_resolution.content_profile == null, "non-owned primary reference exposes no fallback profile")

	var mismatched: InventoryFixture = _make_fixture(false, false)
	mismatched.adapter.unwield(mismatched.player, mismatched.long_id, mismatched.inventory)
	mismatched.player.state.equipment.wield(
		_weapon_ref(mismatched.long_id, OldPineItemContentDefinitions.SHORT_SWORD_ITEM_ID),
		false,
	)
	var mismatch_resolution: OldPineWeaponContentResolution = mismatched.resolver.resolve(
		mismatched.player, mismatched.inventory, mismatched.index
	)
	_assert_eq(mismatch_resolution.outcome, OldPineWeaponContentResolution.Outcome.PRIMARY_DEFINITION_MISMATCH, "instance/ref definition mismatch is explicit")
	_assert_true(mismatch_resolution.content_profile == null, "definition mismatch exposes no unarmed fallback")

	var missing: InventoryFixture = _make_fixture(false, false)
	missing.adapter.unwield(missing.player, missing.long_id, missing.inventory)
	var missing_primary: ItemInstance = ItemInstance.new(
		&"item:missing-primary-metadata",
		OldPineItemContentDefinitions.SHORT_SWORD_ITEM_ID,
	)
	missing.inventory.register_item(missing_primary, 3000)
	_move(missing, missing_primary.item_instance_id, _player_endpoint())
	missing.player.state.equipment.wield(
		_weapon_ref(missing_primary.item_instance_id, missing_primary.item_definition_id),
		false,
	)
	var missing_resolution: OldPineWeaponContentResolution = missing.resolver.resolve(
		missing.player, missing.inventory, missing.index
	)
	_assert_eq(missing_resolution.outcome, OldPineWeaponContentResolution.Outcome.PRIMARY_CONTENT_UNAVAILABLE, "live primary with missing immutable metadata is explicit unavailable")
	_assert_true(missing_resolution.content_profile == null, "missing primary metadata exposes no fallback profile")


func _test_content_profile_additive_seam() -> void:
	var historical_default: CombatSliceContentProfile = CombatSliceContentProfile.new()
	_assert_true(historical_default.is_valid(), "historical default weapon profile remains valid")
	_assert_eq(historical_default.projected_apply_damage(_weapon_ref(&"default:long", OldPineItemContentDefinitions.LONG_SWORD_ITEM_ID)), 25, "historical default profile still projects long damage 25")
	_assert_true(historical_default.has_attack_skill_definition(&"sword"), "historical default profile still exposes sword skill")
	_assert_true(historical_default.has_attack_skill_definition(&"unarmed"), "historical default profile still exposes unarmed fallback skill")
	var short_profile: CombatSliceContentProfile = CombatSliceContentProfile.new(
		OldPineItemContentDefinitions.SHORT_SWORD_ITEM_ID,
		&"sword",
		15,
	)
	_assert_true(short_profile.is_valid(), "ordinary verified short profile remains valid")
	_assert_eq(short_profile.projected_apply_damage(_weapon_ref(&"default:short", OldPineItemContentDefinitions.SHORT_SWORD_ITEM_ID)), 15, "ordinary short profile projects source damage 15")
	var unarmed: CombatSliceContentProfile = CombatSliceContentProfile.new(&"", &"", 0)
	_assert_true(unarmed.is_valid(), "only exact empty-ID zero-damage profile enables unarmed-only seam")
	_assert_true(unarmed.has_attack_skill_definition(&"unarmed"), "unarmed-only seam exposes unarmed skill")
	_assert_false(unarmed.has_attack_skill_definition(&"sword"), "unarmed-only seam does not manufacture sword content")
	_assert_eq(unarmed.projected_apply_damage(null), 0, "unarmed-only seam projects zero weapon damage")
	_assert_false(CombatSliceContentProfile.new(&"", &"sword", 0).is_valid(), "half-empty weapon profile remains invalid")
	_assert_false(CombatSliceContentProfile.new(&"test:weapon", &"", 0).is_valid(), "weapon profile without skill remains invalid")
	_assert_false(CombatSliceContentProfile.new(&"", &"", 1).is_valid(), "empty IDs with positive damage remain invalid")


func _test_independent_authorities() -> void:
	var left: InventoryFixture = _make_fixture(true, false)
	var right: InventoryFixture = _make_fixture(true, false)
	left.adapter.unwield(left.player, left.long_id, left.inventory)
	left.adapter.wield(left.player, left.short_id, left.inventory, left.index)
	_assert_eq(left.player.state.equipment.primary_weapon().instance_id, left.short_id, "left character equips short")
	_assert_eq(right.player.state.equipment.primary_weapon().instance_id, right.long_id, "right character keeps independent long primary")
	var left_profile: CombatSliceContentProfile = left.resolver.resolve(left.player, left.inventory, left.index).content_profile
	var right_profile: CombatSliceContentProfile = right.resolver.resolve(right.player, right.inventory, right.index).content_profile
	_assert_true(left_profile != right_profile, "characters do not share mutable content profile instances")


func _make_fixture(include_short: bool, include_silver: bool) -> InventoryFixture:
	var fixture: InventoryFixture = InventoryFixture.new()
	var player_id: StringName = &"player"
	fixture.player = WorldPlayerRuntimeState.new(
		player_id,
		CharacterState.new(),
		CombatRelationshipState.new(player_id),
		ActionBusyState.new(),
		ArmorState.new(),
		WorldLocationState.new(&"oldpine", &"outdoor", &"zone", &"zone"),
		CharacterRuntimeLifeStatus.Value.ACTIVE,
		true,
		true,
		100_000,
	)
	_add_owned_item(fixture, fixture.long_id, OldPineItemContentDefinitions.LONG_SWORD_ITEM_ID, 7000)
	fixture.player.state.equipment.wield(
		_weapon_ref(fixture.long_id, OldPineItemContentDefinitions.LONG_SWORD_ITEM_ID),
		false,
	)
	if include_short:
		_add_owned_item(fixture, fixture.short_id, OldPineItemContentDefinitions.SHORT_SWORD_ITEM_ID, 3000)
	if include_silver:
		var silver: ItemInstance = ItemInstance.new(
			fixture.silver_id, OldPineItemContentDefinitions.SILVER_ITEM_ID
		)
		fixture.inventory.register_item(silver, 0)
		fixture.index.register_snapshot(silver)
		CombinedStackService.register_stack(
			fixture.stacks,
			fixture.inventory,
			silver,
			OldPineNpcDefinitions.silver_content().stack_definition(),
			3,
		)
		_move(fixture, silver.item_instance_id, _player_endpoint())
	return fixture


func _add_owned_item(
	fixture: InventoryFixture,
	instance_id: StringName,
	definition_id: StringName,
	weight: int,
) -> ItemInstance:
	var item: ItemInstance = ItemInstance.new(instance_id, definition_id)
	fixture.inventory.register_item(item, weight)
	fixture.index.register_snapshot(item)
	_move(fixture, instance_id, _player_endpoint())
	return item


func _move(
	fixture: InventoryFixture,
	item_id: StringName,
	endpoint: ContainmentEndpoint,
) -> bool:
	return InventoryTransferService.new().transfer(
		fixture.inventory,
		item_id,
		InventoryTransferDestination.new(endpoint, true, true, 100_000),
	).succeeded


func _weapon_ref(
	instance_id: StringName,
	definition_id: StringName,
) -> EquippedWeaponRef:
	var content: OldPineItemContentDefinition = (
		OldPineItemContentDefinitions.content_by_id(definition_id)
	)
	return EquippedWeaponRef.new(
		instance_id,
		WeaponDefinition.new(
			definition_id,
			content.weapon_skill_type,
			content.can_wield_secondary,
			content.is_two_handed,
			content.legacy_source_paths()[0],
		),
	)


func _player_endpoint() -> ContainmentEndpoint:
	return ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, &"player")


func _row_ids(rows: Array[PlayerInventoryRowProjection]) -> Array[StringName]:
	var result: Array[StringName] = []
	for row: PlayerInventoryRowProjection in rows:
		result.append(row.item_instance_id)
	return result


func _row_for(
	rows: Array[PlayerInventoryRowProjection],
	item_id: StringName,
) -> PlayerInventoryRowProjection:
	for row: PlayerInventoryRowProjection in rows:
		if row.item_instance_id == item_id:
			return row
	return null


func _assert_true(value: bool, message: String) -> void:
	_assertion_count += 1
	if not value:
		_failures.append(message)


func _assert_false(value: bool, message: String) -> void:
	_assert_true(not value, message)


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	_assertion_count += 1
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [message, expected, actual])
