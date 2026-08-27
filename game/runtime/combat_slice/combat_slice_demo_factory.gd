class_name CombatSliceDemoFactory
extends RefCounted

const ARENA_ID: StringName = &"combat_vertical_slice_arena"
const PLAYER_ID: StringName = &"combat-slice-player"
const ENEMY_ID: StringName = &"combat-slice-enemy"


static func create_player() -> CombatSliceCharacterBinding:
	return _create_binding(PLAYER_ID, true)


static func create_enemy() -> CombatSliceCharacterBinding:
	return _create_binding(ENEMY_ID, false)


static func create_participants() -> Array[CombatSliceCharacterBinding]:
	return [create_player(), create_enemy()]


static func create_inventory_for(
	participants: Array[CombatSliceCharacterBinding],
) -> InventoryState:
	var inventory: InventoryState = InventoryState.new()
	var transfer_service: InventoryTransferService = InventoryTransferService.new()
	for participant: CombatSliceCharacterBinding in participants:
		if participant == null or not participant.is_valid():
			return null
		var item: ItemInstance = ItemInstance.new(
			_long_sword_instance_id(participant.character_id),
			CombatSliceContentProfile.LONG_SWORD_ID,
		)
		if not inventory.register_item(item, CombatSliceContentProfile.LONG_SWORD_WEIGHT):
			return null
		var destination: InventoryTransferDestination = InventoryTransferDestination.new(
			ContainmentEndpoint.new(
				ContainmentEndpoint.Kind.CHARACTER,
				participant.character_id,
			),
			true,
			true,
			100000,
		)
		var transfer: InventoryTransferResult = transfer_service.transfer(
			inventory,
			item.item_instance_id,
			destination,
		)
		if not transfer.succeeded:
			return null
	return inventory


static func _create_binding(
	character_id: StringName,
	is_user: bool,
) -> CombatSliceCharacterBinding:
	var state: CharacterState = CharacterState.new()
	state.attributes = CharacterBaseAttributes.new(20, 20, 20, 20, 20, 20, 20, 20)
	state.essence = CharacterResourceState.new(220, 220, 220)
	state.vitality = CharacterResourceState.new(220, 220, 220)
	state.spirit = CharacterResourceState.new(100, 100, 100)
	state.progression.combat_experience = 10
	for skill_id: StringName in [&"sword", &"dodge", &"parry", &"unarmed"]:
		state.skills.set_raw_level(skill_id, 10)
	state.skills.set_raw_level(&"force", 0)
	state.skills.set_raw_level(&"perception", 0)
	var definition: WeaponDefinition = WeaponDefinition.new(
		CombatSliceContentProfile.LONG_SWORD_ID,
		CombatSliceContentProfile.LONG_SWORD_SKILL_ID,
		false,
		false,
		CombatSliceContentProfile.LONG_SWORD_SOURCE,
	)
	var weapon: EquippedWeaponRef = EquippedWeaponRef.new(
		_long_sword_instance_id(character_id),
		definition,
	)
	state.equipment.wield(weapon, false)
	return CombatSliceCharacterBinding.new(
		character_id,
		state,
		CombatRelationshipState.new(character_id),
		ActionBusyState.new(),
		ArmorState.new(),
		CombatSliceContentProfile.new(),
		ARENA_ID,
		true,
		CombatSliceLifeStatus.Value.ACTIVE,
		is_user,
		true,
	)


static func _long_sword_instance_id(character_id: StringName) -> StringName:
	return StringName("%s-long-sword" % String(character_id))
