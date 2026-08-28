class_name OldPineWeaponContentResolver
extends RefCounted


func resolve(
	player: WorldPlayerRuntimeState,
	inventory: InventoryState,
	item_index: WorldItemInstanceIndex,
) -> OldPineWeaponContentResolution:
	if player == null or not player.is_valid() or inventory == null or item_index == null:
		return OldPineWeaponContentResolution.new()
	var primary: EquippedWeaponRef = player.state.equipment.primary_weapon()
	if primary == null:
		return OldPineWeaponContentResolution.new(
			OldPineWeaponContentResolution.Outcome.UNARMED,
			&"",
			&"",
			CombatSliceContentProfile.new(&"", &"", 0),
		)
	var player_endpoint: ContainmentEndpoint = ContainmentEndpoint.new(
		ContainmentEndpoint.Kind.CHARACTER,
		player.character_id,
	)
	if (
		not inventory.is_registered(primary.instance_id)
		or not inventory.is_direct_child(primary.instance_id, player_endpoint)
	):
		return OldPineWeaponContentResolution.new(
			OldPineWeaponContentResolution.Outcome.PRIMARY_ITEM_NOT_AVAILABLE,
			primary.instance_id,
			primary.weapon_id,
		)
	var item: ItemInstance = item_index.resolve(primary.instance_id)
	if item == null:
		return OldPineWeaponContentResolution.new(
			OldPineWeaponContentResolution.Outcome.PRIMARY_CONTENT_UNAVAILABLE,
			primary.instance_id,
			primary.weapon_id,
		)
	if item.item_definition_id != primary.weapon_id:
		return OldPineWeaponContentResolution.new(
			OldPineWeaponContentResolution.Outcome.PRIMARY_DEFINITION_MISMATCH,
			primary.instance_id,
			item.item_definition_id,
		)
	if item.item_definition_id not in [
		OldPineItemContentDefinitions.LONG_SWORD_ITEM_ID,
		OldPineItemContentDefinitions.SHORT_SWORD_ITEM_ID,
	]:
		return OldPineWeaponContentResolution.new(
			OldPineWeaponContentResolution.Outcome.UNSUPPORTED_PRIMARY,
			primary.instance_id,
			item.item_definition_id,
		)
	var content: OldPineItemContentDefinition = (
		OldPineItemContentDefinitions.content_by_id(item.item_definition_id)
	)
	if content == null:
		return OldPineWeaponContentResolution.new(
			OldPineWeaponContentResolution.Outcome.PRIMARY_CONTENT_UNAVAILABLE,
			primary.instance_id,
			item.item_definition_id,
		)
	if (
		content.category != OldPineItemContentDefinitions.CATEGORY_WEAPON
		or content.weapon_skill_type != primary.skill_type
	):
		return OldPineWeaponContentResolution.new(
			OldPineWeaponContentResolution.Outcome.PRIMARY_DEFINITION_MISMATCH,
			primary.instance_id,
			item.item_definition_id,
		)
	var outcome: int
	match item.item_definition_id:
		OldPineItemContentDefinitions.LONG_SWORD_ITEM_ID:
			outcome = OldPineWeaponContentResolution.Outcome.LONG_SWORD
		OldPineItemContentDefinitions.SHORT_SWORD_ITEM_ID:
			outcome = OldPineWeaponContentResolution.Outcome.SHORT_SWORD
		_:
			return OldPineWeaponContentResolution.new()
	return OldPineWeaponContentResolution.new(
		outcome,
		primary.instance_id,
		item.item_definition_id,
		CombatSliceContentProfile.new(
			content.item_definition_id,
			content.weapon_skill_type,
			content.weapon_damage,
		),
	)
