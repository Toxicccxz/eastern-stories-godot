class_name OldPineArmorInteractionAdapter
extends RefCounted


func wear(
	player: WorldPlayerRuntimeState,
	item_instance_id: StringName,
	inventory: InventoryState,
	item_index: WorldItemInstanceIndex,
) -> OldPineArmorInteractionResult:
	var validation: OldPineArmorInteractionResult = _validate_content(
		OldPineArmorInteractionResult.Action.WEAR,
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
	if content.category != OldPineItemContentDefinitions.CATEGORY_ARMOR:
		return _result(
			OldPineArmorInteractionResult.Action.WEAR,
			OldPineArmorInteractionResult.Outcome.ITEM_NOT_ARMOR,
			item_instance_id,
		)
	var definition: ArmorDefinition = content.armor_definition()
	if definition == null:
		return _result(
			OldPineArmorInteractionResult.Action.WEAR,
			OldPineArmorInteractionResult.Outcome.ITEM_CONTENT_UNAVAILABLE,
			item_instance_id,
		)
	if definition.item_definition_id != item.item_definition_id:
		return _result(
			OldPineArmorInteractionResult.Action.WEAR,
			OldPineArmorInteractionResult.Outcome.ARMOR_DEFINITION_MISMATCH,
			item_instance_id,
		)
	var transition: ArmorTransitionResult = ArmorService.wear(
		player.armor,
		inventory,
		_player_endpoint(player.character_id),
		item,
		definition,
	)
	return OldPineArmorInteractionResult.new(
		OldPineArmorInteractionResult.Action.WEAR,
		OldPineArmorInteractionResult.Outcome.ARMOR_TRANSITION,
		item_instance_id,
		transition,
	)


func remove(
	player: WorldPlayerRuntimeState,
	item_instance_id: StringName,
	inventory: InventoryState,
	item_index: WorldItemInstanceIndex,
) -> OldPineArmorInteractionResult:
	var validation: OldPineArmorInteractionResult = _validate_content(
		OldPineArmorInteractionResult.Action.REMOVE,
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
	if content.category != OldPineItemContentDefinitions.CATEGORY_ARMOR:
		return _result(
			OldPineArmorInteractionResult.Action.REMOVE,
			OldPineArmorInteractionResult.Outcome.ITEM_NOT_ARMOR,
			item_instance_id,
		)
	var definition: ArmorDefinition = content.armor_definition()
	if definition == null:
		return _result(
			OldPineArmorInteractionResult.Action.REMOVE,
			OldPineArmorInteractionResult.Outcome.ITEM_CONTENT_UNAVAILABLE,
			item_instance_id,
		)
	if definition.item_definition_id != item.item_definition_id:
		return _result(
			OldPineArmorInteractionResult.Action.REMOVE,
			OldPineArmorInteractionResult.Outcome.ARMOR_DEFINITION_MISMATCH,
			item_instance_id,
		)
	var worn: EquippedArmorRef = player.armor.equipped_ref_in_slot(
		definition.armor_type
	)
	if worn == null or worn.item_instance_id != item_instance_id:
		return _result(
			OldPineArmorInteractionResult.Action.REMOVE,
			OldPineArmorInteractionResult.Outcome.ITEM_NOT_WORN,
			item_instance_id,
		)
	if worn.item_definition_id != item.item_definition_id:
		return _result(
			OldPineArmorInteractionResult.Action.REMOVE,
			OldPineArmorInteractionResult.Outcome.ARMOR_DEFINITION_MISMATCH,
			item_instance_id,
		)
	var transition: ArmorTransitionResult = player.armor.remove(item_instance_id)
	return OldPineArmorInteractionResult.new(
		OldPineArmorInteractionResult.Action.REMOVE,
		OldPineArmorInteractionResult.Outcome.ARMOR_TRANSITION,
		item_instance_id,
		transition,
	)


func _validate_content(
	action: int,
	player: WorldPlayerRuntimeState,
	item_instance_id: StringName,
	inventory: InventoryState,
	item_index: WorldItemInstanceIndex,
) -> OldPineArmorInteractionResult:
	if item_index == null:
		return _result(
			action,
			OldPineArmorInteractionResult.Outcome.INVALID_REQUEST,
			item_instance_id,
		)
	var ownership: OldPineArmorInteractionResult = _validate_ownership(
		action,
		player,
		item_instance_id,
		inventory,
	)
	if ownership != null:
		return ownership
	var item: ItemInstance = item_index.resolve(item_instance_id)
	if (
		item == null
		or OldPineItemContentDefinitions.content_by_id(item.item_definition_id) == null
	):
		return _result(
			action,
			OldPineArmorInteractionResult.Outcome.ITEM_CONTENT_UNAVAILABLE,
			item_instance_id,
		)
	return null


func _validate_ownership(
	action: int,
	player: WorldPlayerRuntimeState,
	item_instance_id: StringName,
	inventory: InventoryState,
) -> OldPineArmorInteractionResult:
	if player == null or inventory == null or item_instance_id.is_empty():
		return _result(
			action,
			OldPineArmorInteractionResult.Outcome.INVALID_REQUEST,
			item_instance_id,
		)
	if not player.is_valid() or not player.exists_in_world:
		return _result(
			action,
			OldPineArmorInteractionResult.Outcome.PLAYER_NOT_AVAILABLE,
			item_instance_id,
		)
	if player.life_status != CharacterRuntimeLifeStatus.Value.ACTIVE:
		return _result(
			action,
			OldPineArmorInteractionResult.Outcome.PLAYER_NOT_ACTIVE,
			item_instance_id,
		)
	if not inventory.is_registered(item_instance_id):
		return _result(
			action,
			OldPineArmorInteractionResult.Outcome.ITEM_NOT_REGISTERED,
			item_instance_id,
		)
	if not inventory.is_direct_child(
		item_instance_id,
		_player_endpoint(player.character_id),
	):
		return _result(
			action,
			OldPineArmorInteractionResult.Outcome.ITEM_NOT_DIRECTLY_OWNED,
			item_instance_id,
		)
	return null


func _player_endpoint(character_id: StringName) -> ContainmentEndpoint:
	return ContainmentEndpoint.new(
		ContainmentEndpoint.Kind.CHARACTER,
		character_id,
	)


func _result(
	action: int,
	outcome: int,
	item_instance_id: StringName,
) -> OldPineArmorInteractionResult:
	return OldPineArmorInteractionResult.new(action, outcome, item_instance_id)
