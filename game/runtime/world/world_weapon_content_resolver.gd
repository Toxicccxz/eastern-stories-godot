class_name WorldWeaponContentResolver
extends RefCounted


func resolve(
	player: WorldPlayerRuntimeState,
	inventory: InventoryState,
	item_index: WorldItemInstanceIndex,
) -> WorldWeaponContentResolution:
	if player == null or not player.is_valid() or inventory == null or item_index == null:
		return WorldWeaponContentResolution.new()
	var primary: EquippedWeaponRef = player.state.equipment.primary_weapon()
	if primary == null:
		return WorldWeaponContentResolution.new(
			WorldWeaponContentResolution.Outcome.UNARMED,
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
		return WorldWeaponContentResolution.new(
			WorldWeaponContentResolution.Outcome.PRIMARY_ITEM_NOT_AVAILABLE,
			primary.instance_id,
			primary.weapon_id,
		)
	var item: ItemInstance = item_index.resolve(primary.instance_id)
	if item == null:
		return WorldWeaponContentResolution.new(
			WorldWeaponContentResolution.Outcome.PRIMARY_CONTENT_UNAVAILABLE,
			primary.instance_id,
			primary.weapon_id,
		)
	if item.item_definition_id != primary.weapon_id:
		return WorldWeaponContentResolution.new(
			WorldWeaponContentResolution.Outcome.PRIMARY_DEFINITION_MISMATCH,
			primary.instance_id,
			item.item_definition_id,
		)
	var content: ItemContentDefinition = GameContent.catalog().item(item.item_definition_id)
	if content == null or content.weapon_definition() == null:
		return WorldWeaponContentResolution.new(
			WorldWeaponContentResolution.Outcome.UNSUPPORTED_PRIMARY,
			primary.instance_id,
			item.item_definition_id,
		)
	if content.weapon_skill_type != primary.skill_type:
		return WorldWeaponContentResolution.new(
			WorldWeaponContentResolution.Outcome.PRIMARY_DEFINITION_MISMATCH,
			primary.instance_id,
			item.item_definition_id,
		)
	return WorldWeaponContentResolution.new(
		WorldWeaponContentResolution.Outcome.WEAPON,
		primary.instance_id,
		item.item_definition_id,
		CombatSliceContentProfile.new(
			content.item_definition_id,
			content.weapon_skill_type,
			content.weapon_damage,
		),
	)
