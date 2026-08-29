class_name PlayerInventoryProjection
extends RefCounted


func project_rows(
	player: WorldPlayerRuntimeState,
	inventory: InventoryState,
	stacks: CombinedStackCollection,
	item_index: WorldItemInstanceIndex,
) -> Array[PlayerInventoryRowProjection]:
	var rows: Array[PlayerInventoryRowProjection] = []
	if (
		player == null
		or not player.is_valid()
		or inventory == null
		or stacks == null
		or item_index == null
	):
		return rows
	var endpoint: ContainmentEndpoint = _player_endpoint(player.character_id)
	var primary: EquippedWeaponRef = player.state.equipment.primary_weapon()
	var secondary: EquippedWeaponRef = player.state.equipment.secondary_weapon()
	var player_active: bool = (
		player.exists_in_world
		and player.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE
	)
	for item_id: StringName in inventory.direct_children(endpoint):
		if not inventory.is_registered(item_id):
			continue
		var item: ItemInstance = item_index.resolve(item_id)
		if item == null:
			continue
		var content: OldPineItemContentDefinition = (
			OldPineItemContentDefinitions.content_by_id(item.item_definition_id)
		)
		if content == null:
			continue
		var amount: int = 1
		if stacks.has_stack(item_id):
			amount = stacks.stack_state(item_id).amount
		var slot: int = PlayerInventoryRowProjection.EquipmentSlot.NONE
		if primary != null and primary.instance_id == item_id:
			slot = PlayerInventoryRowProjection.EquipmentSlot.PRIMARY
		elif secondary != null and secondary.instance_id == item_id:
			slot = PlayerInventoryRowProjection.EquipmentSlot.SECONDARY
		elif player.armor.is_worn(item_id):
			slot = PlayerInventoryRowProjection.EquipmentSlot.WORN
		var is_weapon: bool = (
			content.category == OldPineItemContentDefinitions.CATEGORY_WEAPON
		)
		var armor_definition: ArmorDefinition = content.armor_definition()
		var is_armor: bool = (
			content.category == OldPineItemContentDefinitions.CATEGORY_ARMOR
			and armor_definition != null
		)
		rows.append(
			PlayerInventoryRowProjection.new(
				item_id,
				item.item_definition_id,
				content.display_name,
				content.description,
				amount,
				content.category,
				slot,
				content.weapon_skill_type,
				content.weapon_damage,
				content.currency_base_value * amount,
				player_active
				and is_weapon
				and slot == PlayerInventoryRowProjection.EquipmentSlot.NONE,
				player_active
				and is_weapon
				and slot != PlayerInventoryRowProjection.EquipmentSlot.NONE,
				&"" if armor_definition == null else armor_definition.armor_type,
				null if armor_definition == null else armor_definition.numeric_modifiers,
				player_active
				and is_armor
				and slot == PlayerInventoryRowProjection.EquipmentSlot.NONE,
				player_active
				and is_armor
				and slot == PlayerInventoryRowProjection.EquipmentSlot.WORN,
			)
		)
	return rows


func project_item(
	player: WorldPlayerRuntimeState,
	inventory: InventoryState,
	stacks: CombinedStackCollection,
	item_index: WorldItemInstanceIndex,
	item_instance_id: StringName,
) -> PlayerInventoryRowProjection:
	for row: PlayerInventoryRowProjection in project_rows(
		player, inventory, stacks, item_index
	):
		if row.item_instance_id == item_instance_id:
			return row
	return null


func _player_endpoint(character_id: StringName) -> ContainmentEndpoint:
	return ContainmentEndpoint.new(
		ContainmentEndpoint.Kind.CHARACTER,
		character_id,
	)
