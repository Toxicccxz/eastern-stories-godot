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
	var context: DeathContext = DeathContext.new(
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
