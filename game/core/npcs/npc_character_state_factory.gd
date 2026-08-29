class_name NpcCharacterStateFactory
extends RefCounted

const HUMAN_RACE_ID: StringName = &"human"
const INVALID_RANDOM_DRAW: int = -2_147_483_648

const NpcDefinitionType := preload("res://core/npcs/npc_definition.gd")
const NpcSpawnDefinitionType := preload("res://core/npcs/npc_spawn_definition.gd")
const AttributeOverridesType := preload(
	"res://core/npcs/npc_base_attribute_overrides.gd"
)
const ResourceOverridesType := preload("res://core/npcs/npc_resource_overrides.gd")
const ResourceTrackOverrideType := preload(
	"res://core/npcs/npc_resource_track_override.gd"
)
const LoadoutEntryType := preload("res://core/npcs/npc_loadout_entry.gd")
const LoadoutItemDefinitionType := preload(
	"res://core/npcs/npc_loadout_item_definition.gd"
)
const RandomSourceType := preload(
	"res://core/npcs/npc_initialization_random_source.gd"
)
const NpcRuntimeStateType := preload("res://core/npcs/npc_runtime_state.gd")
const RuntimeLifeStatusType := preload(
	"res://runtime/characters/character_runtime_life_status.gd"
)
const CharacterStateType := preload("res://core/characters/character_state.gd")
const CharacterAttributesType := preload(
	"res://core/characters/character_base_attributes.gd"
)
const CharacterResourceStateType := preload(
	"res://core/characters/character_resource_state.gd"
)
const CharacterDerivedValuesType := preload(
	"res://core/characters/character_derived_values.gd"
)
const RelationshipStateType := preload(
	"res://core/combat/relationship/combat_relationship_state.gd"
)
const BusyStateType := preload("res://core/combat/busy/action_busy_state.gd")
const ArmorStateType := preload("res://core/armor/armor_state.gd")
const ArmorServiceType := preload("res://core/armor/armor_service.gd")
const WorldLocationStateType := preload("res://core/world/world_location_state.gd")
const InventoryStateType := preload("res://core/inventory/inventory_state.gd")
const ContainmentEndpointType := preload(
	"res://core/inventory/containment_endpoint.gd"
)
const TransferDestinationType := preload(
	"res://core/inventory/inventory_transfer_destination.gd"
)
const TransferServiceType := preload(
	"res://core/inventory/inventory_transfer_service.gd"
)
const ItemInstanceType := preload("res://core/items/item_instance.gd")
const EquippedWeaponRefType := preload(
	"res://core/equipment/equipped_weapon_ref.gd"
)
const StackCollectionType := preload(
	"res://core/items/combined/combined_stack_collection.gd"
)
const StackServiceType := preload(
	"res://core/items/combined/combined_stack_service.gd"
)


func create_spawn_instances(
	spawn: NpcSpawnDefinitionType,
	definition: NpcDefinitionType,
	location: WorldLocationStateType,
	inventory: InventoryStateType,
	stacks: StackCollectionType,
	random_source: RandomSourceType,
	loadout_content: Array[NpcLoadoutItemDefinition],
	item_instance_scope: StringName = &"",
) -> Array[NpcRuntimeState]:
	var result: Array[NpcRuntimeState] = []
	if (
		spawn == null
		or not spawn.is_valid()
		or definition == null
		or not definition.is_valid()
		or spawn.npc_definition_id != definition.definition_id
		or location == null
		or not location.is_valid()
		or location.map_id != spawn.map_id
		or location.zone_id != spawn.zone_id
		or inventory == null
		or stacks == null
		or random_source == null
		or not _loadout_content_resolves(definition, loadout_content)
	):
		return result
	var spawn_points: Array[StringName] = spawn.spawn_point_ids()
	for spawn_point_id: StringName in spawn_points:
		var character_id: StringName = StringName(
			"%s.character" % String(spawn_point_id)
		)
		var runtime: NpcRuntimeStateType = create_one(
			definition,
			character_id,
			spawn.spawn_id,
			spawn_point_id,
			location,
			inventory,
			stacks,
			random_source,
			loadout_content,
			item_instance_scope,
		)
		if runtime == null:
			return []
		result.append(runtime)
	return result


func create_one(
	definition: NpcDefinitionType,
	character_id: StringName,
	spawn_id: StringName,
	spawn_point_id: StringName,
	location: WorldLocationStateType,
	inventory: InventoryStateType,
	stacks: StackCollectionType,
	random_source: RandomSourceType,
	loadout_content: Array[NpcLoadoutItemDefinition],
	item_instance_scope: StringName = &"",
) -> NpcRuntimeStateType:
	if (
		definition == null
		or not definition.is_valid()
		or definition.race_id != HUMAN_RACE_ID
		or character_id.is_empty()
		or spawn_id.is_empty()
		or spawn_point_id.is_empty()
		or location == null
		or not location.is_valid()
		or inventory == null
		or stacks == null
		or random_source == null
		or not _loadout_content_resolves(definition, loadout_content)
	):
		return null

	var age: int = definition.age
	if not definition.has_authored_age:
		age = _draw_with_offset(random_source, 30, 15)
		if age == INVALID_RANDOM_DRAW:
			return null

	var authored: AttributeOverridesType = definition.base_attribute_overrides()
	var resolved_values: Array[int] = []
	var authored_presence: Array[bool] = [
		authored.has_strength(),
		authored.has_courage(),
		authored.has_intelligence(),
		authored.has_spirituality(),
		authored.has_composure(),
		authored.has_personality(),
		authored.has_constitution(),
		authored.has_karma(),
	]
	var authored_values: Array[int] = [
		authored.strength(),
		authored.courage(),
		authored.intelligence(),
		authored.spirituality(),
		authored.composure(),
		authored.personality(),
		authored.constitution(),
		authored.karma(),
	]
	for index: int in range(authored_presence.size()):
		if authored_presence[index]:
			resolved_values.append(authored_values[index])
			continue
		var default_value: int = _draw_with_offset(random_source, 21, 10)
		if default_value == INVALID_RANDOM_DRAW:
			return null
		resolved_values.append(default_value)

	var attributes: CharacterAttributesType = CharacterAttributesType.new(
		resolved_values[0],
		resolved_values[1],
		resolved_values[2],
		resolved_values[3],
		resolved_values[4],
		resolved_values[5],
		resolved_values[6],
		resolved_values[7],
	)
	var state: CharacterStateType = CharacterStateType.new(attributes)
	state.gender = (
		definition.gender
		if definition.has_authored_gender
		else CharacterStateType.GENDER_MALE
	)
	var resource_overrides: ResourceOverridesType = definition.resource_overrides()
	state.essence = _create_resource_track(
		resource_overrides.essence(),
		CharacterDerivedValuesType.human_maximum_essence(
			age,
			state.recovery.atman.maximum,
		),
	)
	state.vitality = _create_resource_track(
		resource_overrides.vitality(),
		CharacterDerivedValuesType.human_maximum_vitality(
			age,
			state.recovery.inner_force.maximum,
		),
	)
	state.spirit = _create_resource_track(
		resource_overrides.spirit(),
		CharacterDerivedValuesType.human_maximum_spirit(
			age,
			state.recovery.mana.maximum,
		),
	)
	state.progression.combat_experience = definition.combat_experience
	for skill: NpcSkillLevelDefinition in definition.skill_levels():
		state.skills.set_raw_level(skill.skill_id, skill.raw_level)

	var body_weight: int = CharacterDerivedValuesType.human_weight(attributes.strength)
	var maximum_encumbrance: int = (
		CharacterDerivedValuesType.maximum_encumbrance(attributes.strength)
	)
	var armor_state: ArmorStateType = ArmorStateType.new()
	var loadout_items: Array[ItemInstance] = _apply_loadout(
		definition,
		character_id,
		state,
		armor_state,
		maximum_encumbrance,
		inventory,
		stacks,
		loadout_content,
		item_instance_scope,
	)
	if loadout_items.size() != _expected_live_item_count(definition, loadout_content):
		return null

	return NpcRuntimeStateType.new(
		character_id,
		definition,
		spawn_id,
		spawn_point_id,
		state,
		RelationshipStateType.new(character_id),
		BusyStateType.new(),
		armor_state,
		location,
		RuntimeLifeStatusType.Value.ACTIVE,
		true,
		true,
		age,
		body_weight,
		maximum_encumbrance,
		loadout_items,
	)


static func _create_resource_track(
	override: ResourceTrackOverrideType,
	derived_maximum: int,
) -> CharacterResourceStateType:
	var maximum: int = override.maximum() if override.has_maximum() else derived_maximum
	var effective: int = override.effective() if override.has_effective() else maximum
	var current: int = override.current() if override.has_current() else maximum
	return CharacterResourceStateType.new(current, effective, maximum)


static func _draw_with_offset(
	random_source: RandomSourceType,
	exclusive_upper_bound: int,
	offset: int,
) -> int:
	var draw: int = random_source.next_below(exclusive_upper_bound)
	if draw < 0 or draw >= exclusive_upper_bound:
		return INVALID_RANDOM_DRAW
	return draw + offset


func _apply_loadout(
	definition: NpcDefinitionType,
	character_id: StringName,
	state: CharacterStateType,
	armor_state: ArmorStateType,
	maximum_encumbrance: int,
	inventory: InventoryStateType,
	stacks: StackCollectionType,
	loadout_content: Array[NpcLoadoutItemDefinition],
	item_instance_scope: StringName,
) -> Array[ItemInstance]:
	var created: Array[ItemInstance] = []
	var entries: Array[NpcLoadoutEntry] = definition.loadout_entries()
	var owner_endpoint: ContainmentEndpointType = ContainmentEndpointType.new(
		ContainmentEndpointType.Kind.CHARACTER,
		character_id,
	)
	var destination: TransferDestinationType = TransferDestinationType.new(
		owner_endpoint,
		true,
		true,
		maximum_encumbrance,
	)
	for entry_index: int in range(entries.size()):
		var entry: LoadoutEntryType = entries[entry_index]
		var content: LoadoutItemDefinitionType = _find_content(
			entry.item_definition_id,
			loadout_content,
		)
		if content == null:
			return []
		var unit_count: int = 1 if content.stack_definition() != null else entry.quantity
		for unit_index: int in range(unit_count):
			var identity_owner: String = String(character_id)
			if not item_instance_scope.is_empty():
				identity_owner = "%s.%s" % [String(item_instance_scope), identity_owner]
			var instance_id: StringName = StringName(
				"%s.loadout.%d.%d" % [identity_owner, entry_index, unit_index]
			)
			var item_definition: ItemDefinition = content.item_definition()
			var item: ItemInstanceType = ItemInstanceType.new(
				instance_id,
				item_definition.item_definition_id,
			)
			var initial_weight: int = 0 if content.stack_definition() != null else content.own_weight
			if not inventory.register_item(item, initial_weight):
				return []
			if content.stack_definition() != null:
				var stack_registration: CombinedStackAmountResult = (
					StackServiceType.register_stack(
						stacks,
						inventory,
						item,
						content.stack_definition(),
						entry.quantity,
					)
				)
				if not stack_registration.accepted:
					return []
			var transfer: InventoryTransferResult = TransferServiceType.new().transfer(
				inventory,
				item.item_instance_id,
				destination,
			)
			if not transfer.succeeded:
				return []
			if entry.equipment_intent == LoadoutEntryType.EquipmentIntent.WIELD_PRIMARY:
				var weapon_definition: WeaponDefinition = content.weapon_definition()
				if weapon_definition == null:
					return []
				var wield_result: EquipmentTransitionResult = state.equipment.wield(
					EquippedWeaponRefType.new(item.item_instance_id, weapon_definition),
					false,
				)
				if (
					not wield_result.succeeded
					or state.equipment.primary_weapon() == null
					or state.equipment.primary_weapon().instance_id != item.item_instance_id
				):
					return []
			elif entry.equipment_intent == LoadoutEntryType.EquipmentIntent.WEAR:
				var armor_definition: ArmorDefinition = content.armor_definition()
				if (
					armor_definition == null
					or armor_definition.item_definition_id != item.item_definition_id
				):
					return []
				var wear_result: ArmorTransitionResult = ArmorServiceType.wear(
					armor_state,
					inventory,
					owner_endpoint,
					item,
					armor_definition,
				)
				if (
					not wear_result.succeeded
					or not armor_state.is_worn(item.item_instance_id)
				):
					return []
			created.append(item)
	return created


static func _find_content(
	item_definition_id: StringName,
	loadout_content: Array[NpcLoadoutItemDefinition],
) -> LoadoutItemDefinitionType:
	var found: LoadoutItemDefinitionType = null
	for content: LoadoutItemDefinitionType in loadout_content:
		if (
			content != null
			and content.is_valid()
			and content.item_definition().item_definition_id == item_definition_id
		):
			if found != null:
				return null
			found = content
	return found


static func _loadout_content_resolves(
	definition: NpcDefinitionType,
	loadout_content: Array[NpcLoadoutItemDefinition],
) -> bool:
	if definition == null:
		return false
	for entry: LoadoutEntryType in definition.loadout_entries():
		if _find_content(entry.item_definition_id, loadout_content) == null:
			return false
	return true


static func _expected_live_item_count(
	definition: NpcDefinitionType,
	loadout_content: Array[NpcLoadoutItemDefinition],
) -> int:
	var result: int = 0
	for entry: LoadoutEntryType in definition.loadout_entries():
		var content: LoadoutItemDefinitionType = _find_content(
			entry.item_definition_id,
			loadout_content,
		)
		if content == null:
			return -1
		result += 1 if content.stack_definition() != null else entry.quantity
	return result
