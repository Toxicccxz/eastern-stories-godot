class_name HeldFoodUseService
extends RefCounted

## Map independent. The caller supplies present world availability, not a timer.
static func eat(player: WorldPlayerRuntimeState, context: MoneyInventoryContext,
	foods: FoodCollection, definitions: NativeItemDefinitionProjections,
	id: StringName, world_available: bool) -> FoodUseResult:
	var result: FoodUseResult = FoodUseResult.new()
	result.item_id = id
	if player == null or not player.is_valid() or context == null or not context.is_valid() or foods == null or definitions == null or not definitions.is_valid:
		return result
	if context.owner.character_id != player.character_id or context.owner.equipment_state != player.state.equipment or context.owner.armor_state != player.armor:
		return result
	if not world_available or not player.exists_in_world or player.life_status != CharacterRuntimeLifeStatus.Value.ACTIVE:
		result.outcome = FoodUseResult.Outcome.INTERACTION_BLOCKED
		return result
	if player.relationship.is_fighting():
		result.outcome = FoodUseResult.Outcome.COMBAT_BLOCKED
		return result
	if player.busy.is_busy():
		result.outcome = FoodUseResult.Outcome.BUSY
		return result
	var parent: ContainmentEndpoint = context.inventory.direct_parent(id)
	if parent == null or not parent.same_identity(context.endpoint()):
		result.outcome = FoodUseResult.Outcome.NOT_DIRECT_HELD
		return result
	var item: ItemInstance = context.index.resolve(id)
	var state: FoodState = foods.state(id)
	if item == null or state == null or not context.inventory.is_registered(id):
		return result
	var definition: FoodDefinition = definitions.food_definition(item.item_definition_id)
	if definition == null or not definition.accepts_live_state(state.remaining_portions, state.current_value) or context.inventory.own_weight(id) != definition.own_weight:
		return result
	result.food_before = player.state.recovery.food
	result.food_after = result.food_before
	if result.food_before >= CharacterRecovery.maximum_food_capacity(player.body_facts.body_weight):
		result.outcome = FoodUseResult.Outcome.TOO_FULL
		return result
	# feature/food.c: add food, clear value, decrement portions, then destruct.
	player.state.recovery.food += definition.food_supply
	result.food_after = player.state.recovery.food
	state.consume_portion()
	result.accepted_bite = true
	if state.remaining_portions == 0:
		result.cleanup = FoodItemLifecycle.remove(context, foods, id)
		if not result.cleanup.succeeded():
			return result
	result.outcome = FoodUseResult.Outcome.ATE
	return result
