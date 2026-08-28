class_name CombatSliceDeathAdapter
extends RefCounted

const CORPSE_DEFINITION_ID: StringName = &"es2:obj/corpse"
const CORPSE_LEGACY_SOURCE: String = "obj/corpse.c"
const BODY_OWN_WEIGHT: int = 60000
const MAXIMUM_ENCUMBRANCE: int = 100000


func execute(
	victim: CombatSliceCharacterBinding,
	killer: CombatSliceCharacterBinding,
	inventory: InventoryState,
	stacks: CombinedStackCollection,
	corpse_item_instance_id: StringName,
	arena_destination: InventoryTransferDestination,
	item_facts: Array[DeathItemFacts],
	policy_registry: DeathItemPolicyRegistry,
	rewear_registry: DeathRewearPolicyRegistry,
	context_override: DeathContext = null,
) -> CombatSliceDeathExecutionResult:
	if (
		victim == null
		or not victim.is_valid()
		or inventory == null
		or stacks == null
		or corpse_item_instance_id == &""
		or arena_destination == null
		or policy_registry == null
		or rewear_registry == null
	):
		return CombatSliceDeathExecutionResult.new()
	var owner: ItemLifecycleOwnerContext = ItemLifecycleOwnerContext.new(
		victim.character_id,
		victim.state.equipment,
		victim.armor,
	)
	var arena_endpoint: ContainmentEndpoint = arena_destination.endpoint
	var context: DeathContext = context_override
	if context == null:
		context = DeathContext.new(
			victim.character_id,
			false,
			false,
			arena_destination,
			owner,
			_display_name(victim),
			victim.state.gender,
			20,
			BODY_OWN_WEIGHT,
			MAXIMUM_ENCUMBRANCE,
			false,
			arena_endpoint if killer != null else null,
			victim.state.gender,
			killer != null,
		)
	elif not _override_matches_authorities(
		context,
		victim,
		arena_destination,
	):
		return CombatSliceDeathExecutionResult.new()
	var corpse_definition: ItemDefinition = ItemDefinition.new(
		CORPSE_DEFINITION_ID,
		CORPSE_LEGACY_SOURCE,
	)
	var corpse_item: ItemInstance = ItemInstance.new(
		corpse_item_instance_id,
		CORPSE_DEFINITION_ID,
	)
	var death_result: DeathInventoryResult = DeathInventoryService.process(
		context,
		inventory,
		stacks,
		item_facts,
		policy_registry,
		rewear_registry,
		corpse_item,
		corpse_definition,
	)
	var second_placement: InventoryTransferResult = null
	if death_result.corpse_state != null:
		## feature/damage.c moves the corpse again after chard.c already placed it.
		## InventoryTransferService records the same-endpoint no-op explicitly.
		second_placement = InventoryTransferService.new().transfer(
			inventory,
			death_result.corpse_item_instance_id,
			arena_destination,
		)
	return CombatSliceDeathExecutionResult.new(death_result, second_placement)


func _display_name(binding: CombatSliceCharacterBinding) -> String:
	return "Player" if binding.is_user else "Human Swordfighter"


func _override_matches_authorities(
	context: DeathContext,
	victim: CombatSliceCharacterBinding,
	destination: InventoryTransferDestination,
) -> bool:
	if context == null or not context.is_valid() or destination == null:
		return false
	var owner: ItemLifecycleOwnerContext = context.victim_owner
	var context_destination: InventoryTransferDestination = context.victim_environment
	var context_endpoint: ContainmentEndpoint = context_destination.endpoint
	var destination_endpoint: ContainmentEndpoint = destination.endpoint
	return (
		context.victim_character_id == victim.character_id
		and owner.equipment_state == victim.state.equipment
		and owner.armor_state == victim.armor
		and context_endpoint != null
		and context_endpoint.same_identity(destination_endpoint)
		and context_destination.is_available == destination.is_available
		and context_destination.is_containment_capable == destination.is_containment_capable
		and context_destination.maximum_contents_weight == destination.maximum_contents_weight
	)
