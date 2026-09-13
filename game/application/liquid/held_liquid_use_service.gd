class_name HeldLiquidUseService
extends RefCounted

## Current availability/source facts are supplied by the runtime. No scene or RNG.
static func drink(player: WorldPlayerRuntimeState, context: MoneyInventoryContext,
	liquids: LiquidCollection, definitions: NativeItemDefinitionProjections,
	id: StringName, world_available: bool, encounter_active: bool = false) -> LiquidUseResult:
	var result: LiquidUseResult = _admit(player, context, liquids, definitions, id,
		world_available, encounter_active, false)
	if result.outcome != LiquidUseResult.Outcome.ADMITTED:
		return result
	var state: LiquidState = liquids.state(id)
	# Deliberate staged omission: no hydration, portion or condition mutation.
	if state.content == LiquidState.Content.RED_WINE:
		result.outcome = LiquidUseResult.Outcome.ALCOHOL_DEFERRED
		return result
	if state.remaining == 0:
		result.outcome = LiquidUseResult.Outcome.EMPTY
		return result
	if result.water_before >= CharacterRecovery.maximum_water_capacity(player.body_facts.body_weight):
		result.outcome = LiquidUseResult.Outcome.TOO_FULL
		return result
	state.remaining -= 1
	player.state.recovery.water += SourceWineskin.HYDRATION
	result.remaining_after = state.remaining
	result.water_after = player.state.recovery.water
	result.outcome = LiquidUseResult.Outcome.DRANK
	return result


static func fill(player: WorldPlayerRuntimeState, context: MoneyInventoryContext,
	liquids: LiquidCollection, definitions: NativeItemDefinitionProjections,
	id: StringName, world_available: bool, source_available: bool,
	encounter_active: bool = false) -> LiquidUseResult:
	var result: LiquidUseResult = _admit(player, context, liquids, definitions, id,
		world_available, encounter_active, true, source_available)
	if result.outcome != LiquidUseResult.Outcome.ADMITTED:
		return result
	var state: LiquidState = liquids.state(id)
	result.discarded_wine = state.content == LiquidState.Content.RED_WINE and state.remaining > 0
	state.content = LiquidState.Content.CLEAR_WATER
	state.remaining = SourceWineskin.MAXIMUM
	result.remaining_after = state.remaining
	result.outcome = LiquidUseResult.Outcome.FILLED
	return result


static func _admit(player: WorldPlayerRuntimeState, context: MoneyInventoryContext,
	liquids: LiquidCollection, definitions: NativeItemDefinitionProjections, id: StringName,
	world_available: bool, encounter_active: bool, is_fill: bool,
	source_available: bool = false) -> LiquidUseResult:
	var result: LiquidUseResult = LiquidUseResult.new()
	result.item_id = id
	if player == null or not player.is_valid() or context == null or not context.is_valid() or liquids == null or definitions == null or not definitions.is_valid:
		return result
	if context.owner.character_id != player.character_id or context.owner.equipment_state != player.state.equipment or context.owner.armor_state != player.armor:
		return result
	if not world_available or not player.exists_in_world or player.life_status != CharacterRuntimeLifeStatus.Value.ACTIVE:
		result.outcome = LiquidUseResult.Outcome.INTERACTION_BLOCKED
		return result
	# Owner-approved order differs between Fill and Drink.
	if not is_fill and player.busy.is_busy():
		result.outcome = LiquidUseResult.Outcome.BUSY
		return result
	var parent: ContainmentEndpoint = context.inventory.direct_parent(id)
	if parent == null or not parent.same_identity(context.endpoint()):
		result.outcome = LiquidUseResult.Outcome.NOT_DIRECT_HELD
		return result
	if player.busy.is_busy():
		result.outcome = LiquidUseResult.Outcome.BUSY
		return result
	if player.relationship.is_fighting() or encounter_active:
		result.outcome = LiquidUseResult.Outcome.COMBAT_BLOCKED
		return result
	if is_fill and not source_available:
		result.outcome = LiquidUseResult.Outcome.NO_WATER_SOURCE
		return result
	var item: ItemInstance = context.index.resolve(id)
	var state: LiquidState = liquids.state(id)
	if item == null or item.item_definition_id != SourceWineskin.DEFINITION_ID or state == null or not context.inventory.is_registered(id):
		return result
	var definition: LiquidDefinition = definitions.liquid_definition(item.item_definition_id)
	if not SourceWineskin.is_canonical(definition) or not definition.accepts_live_state(state.content, state.remaining) or context.inventory.own_weight(id) != definition.own_weight:
		return result
	result.water_before = player.state.recovery.water
	result.water_after = result.water_before
	result.remaining_before = state.remaining
	result.remaining_after = state.remaining
	result.outcome = LiquidUseResult.Outcome.ADMITTED
	return result
