class_name OldPineEquipmentInteractionAdapter
extends RefCounted

const SHIELD_SLOT: StringName = &"shield"


func wield(
	player: WorldPlayerRuntimeState,
	item_instance_id: StringName,
	inventory: InventoryState,
	item_index: WorldItemInstanceIndex,
) -> OldPineEquipmentInteractionResult:
	var validation: OldPineEquipmentInteractionResult = _validate_common(
		OldPineEquipmentInteractionResult.Action.WIELD,
		player,
		item_instance_id,
		inventory,
		item_index,
	)
	if validation != null:
		return validation
	var item: ItemInstance = item_index.resolve(item_instance_id)
	var content: OldPineItemContentDefinition = (
		OldPineItemContentDefinitions.content_by_id(item.item_definition_id)
	)
	if content.category != OldPineItemContentDefinitions.CATEGORY_WEAPON:
		return _result(
			OldPineEquipmentInteractionResult.Action.WIELD,
			OldPineEquipmentInteractionResult.Outcome.ITEM_NOT_A_WEAPON,
			item_instance_id,
		)
	var definition: WeaponDefinition = WeaponDefinition.new(
		content.item_definition_id,
		content.weapon_skill_type,
		content.can_wield_secondary,
		content.is_two_handed,
		content.legacy_source_paths()[0],
	)
	var reference: EquippedWeaponRef = EquippedWeaponRef.new(
		item_instance_id,
		definition,
	)
	if reference.weapon_id != item.item_definition_id:
		return _result(
			OldPineEquipmentInteractionResult.Action.WIELD,
			OldPineEquipmentInteractionResult.Outcome.WEAPON_DEFINITION_MISMATCH,
			item_instance_id,
		)
	var transition: EquipmentTransitionResult = player.state.equipment.wield(
		reference,
		player.armor.is_slot_occupied(SHIELD_SLOT),
	)
	return OldPineEquipmentInteractionResult.new(
		OldPineEquipmentInteractionResult.Action.WIELD,
		OldPineEquipmentInteractionResult.Outcome.EQUIPMENT_TRANSITION,
		item_instance_id,
		transition,
	)


func unwield(
	player: WorldPlayerRuntimeState,
	item_instance_id: StringName,
	inventory: InventoryState,
) -> OldPineEquipmentInteractionResult:
	var validation: OldPineEquipmentInteractionResult = _validate_ownership(
		OldPineEquipmentInteractionResult.Action.UNWIELD,
		player,
		item_instance_id,
		inventory,
	)
	if validation != null:
		return validation
	var primary: EquippedWeaponRef = player.state.equipment.primary_weapon()
	var secondary: EquippedWeaponRef = player.state.equipment.secondary_weapon()
	if (
		(primary == null or primary.instance_id != item_instance_id)
		and (secondary == null or secondary.instance_id != item_instance_id)
	):
		return _result(
			OldPineEquipmentInteractionResult.Action.UNWIELD,
			OldPineEquipmentInteractionResult.Outcome.ITEM_NOT_WIELDED,
			item_instance_id,
		)
	var transition: EquipmentTransitionResult = (
		player.state.equipment.unwield(item_instance_id)
	)
	return OldPineEquipmentInteractionResult.new(
		OldPineEquipmentInteractionResult.Action.UNWIELD,
		OldPineEquipmentInteractionResult.Outcome.EQUIPMENT_TRANSITION,
		item_instance_id,
		transition,
	)


func _validate_common(
	action: int,
	player: WorldPlayerRuntimeState,
	item_instance_id: StringName,
	inventory: InventoryState,
	item_index: WorldItemInstanceIndex,
) -> OldPineEquipmentInteractionResult:
	if item_index == null:
		return _result(
			action,
			OldPineEquipmentInteractionResult.Outcome.INVALID_REQUEST,
			item_instance_id,
		)
	var ownership_validation: OldPineEquipmentInteractionResult = _validate_ownership(
		action,
		player,
		item_instance_id,
		inventory,
	)
	if ownership_validation != null:
		return ownership_validation
	var item: ItemInstance = item_index.resolve(item_instance_id)
	if item == null:
		return _result(
			action,
			OldPineEquipmentInteractionResult.Outcome.ITEM_CONTENT_UNAVAILABLE,
			item_instance_id,
		)
	var content: OldPineItemContentDefinition = (
		OldPineItemContentDefinitions.content_by_id(item.item_definition_id)
	)
	if content == null:
		return _result(
			action,
			OldPineEquipmentInteractionResult.Outcome.ITEM_CONTENT_UNAVAILABLE,
			item_instance_id,
		)
	return null


func _validate_ownership(
	action: int,
	player: WorldPlayerRuntimeState,
	item_instance_id: StringName,
	inventory: InventoryState,
) -> OldPineEquipmentInteractionResult:
	if (
		player == null
		or inventory == null
		or item_instance_id.is_empty()
	):
		return _result(
			action,
			OldPineEquipmentInteractionResult.Outcome.INVALID_REQUEST,
			item_instance_id,
		)
	if not player.is_valid() or not player.exists_in_world:
		return _result(
			action,
			OldPineEquipmentInteractionResult.Outcome.PLAYER_NOT_AVAILABLE,
			item_instance_id,
		)
	if player.life_status != CharacterRuntimeLifeStatus.Value.ACTIVE:
		return _result(
			action,
			OldPineEquipmentInteractionResult.Outcome.PLAYER_NOT_ACTIVE,
			item_instance_id,
		)
	if not inventory.is_registered(item_instance_id):
		return _result(
			action,
			OldPineEquipmentInteractionResult.Outcome.ITEM_NOT_REGISTERED,
			item_instance_id,
		)
	var player_endpoint: ContainmentEndpoint = ContainmentEndpoint.new(
		ContainmentEndpoint.Kind.CHARACTER,
		player.character_id,
	)
	if not inventory.is_direct_child(item_instance_id, player_endpoint):
		return _result(
			action,
			OldPineEquipmentInteractionResult.Outcome.ITEM_NOT_DIRECTLY_OWNED,
			item_instance_id,
		)
	return null


func _result(
	action: int,
	outcome: int,
	item_instance_id: StringName,
) -> OldPineEquipmentInteractionResult:
	return OldPineEquipmentInteractionResult.new(
		action,
		outcome,
		item_instance_id,
	)
