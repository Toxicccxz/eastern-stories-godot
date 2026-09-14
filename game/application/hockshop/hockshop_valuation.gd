class_name HockshopValuation
extends RefCounted


## Checked positive-value arithmetic; -1 is internal failure, never a price.
@warning_ignore("integer_division")
static func sell_payout(source_value: int) -> int:
	if source_value <= 0:
		return -1
	var product: int = CurrencyArithmetic.multiply(source_value, 80)
	if product < 0:
		return -1
	return maxi(1, product / 100)


## Read-only, exact current identity. A returned quote is NEVER execution authority.
static func appraise(context: MoneyInventoryContext, foods: FoodCollection,
	liquids: LiquidCollection, id: StringName) -> HockshopValuationResult:
	var result: HockshopValuationResult = HockshopValuationResult.new()
	result.item_id = id
	if context == null or not context.is_valid() or foods == null or liquids == null:
		return result
	result.outcome = HockshopValuationResult.Outcome.ITEM_NOT_FOUND
	if id == &"" or not context.inventory.is_registered(id):
		return result
	var item: ItemInstance = context.index.resolve(id)
	if item == null or item.item_instance_id != id:
		result.outcome = HockshopValuationResult.Outcome.AUTHORITY_FAILURE
		return result
	result.definition_id = item.item_definition_id
	if not context.inventory.is_direct_child(id, context.endpoint()):
		result.outcome = HockshopValuationResult.Outcome.NOT_DIRECTLY_HELD
		return result
	if SourceCurrencyDefinitions.identify(item.item_definition_id) != CurrencyDenomination.Value.UNSUPPORTED:
		result.outcome = HockshopValuationResult.Outcome.MONEY_REJECTED
		return result
	result.outcome = HockshopValuationResult.Outcome.UNSUPPORTED_ITEM
	if not context.inventory.direct_children(ContainmentEndpoint.new(ContainmentEndpoint.Kind.ITEM, id)).is_empty():
		return result
	if not HockshopStaticValues.VALUES.has(item.item_definition_id) and item.item_definition_id not in [SourceDumpling.DEFINITION_ID, SourceWineskin.DEFINITION_ID]:
		return result
	result.outcome = HockshopValuationResult.Outcome.INVALID_ITEM_STATE
	# Bounded catalog roles, not a universal exclusivity rule for all future items.
	if context.stacks.has_stack(id):
		return result
	var food: FoodState = foods.state(id)
	var liquid: LiquidState = liquids.state(id)
	if item.item_definition_id == SourceDumpling.DEFINITION_ID:
		var definition: FoodDefinition = SourceDumpling.food_definition()
		if food == null or liquid != null or not definition.accepts_live_state(food.remaining_portions, food.current_value) or context.inventory.own_weight(id) != definition.own_weight:
			return result
		result.source_value = food.current_value
	elif item.item_definition_id == SourceWineskin.DEFINITION_ID:
		var definition: LiquidDefinition = SourceWineskin.liquid_definition()
		if liquid == null or food != null or not definition.accepts_live_state(liquid.content, liquid.remaining) or context.inventory.own_weight(id) != definition.own_weight:
			return result
		result.source_value = definition.value
	else:
		if food != null or liquid != null or context.inventory.own_weight(id) < 0:
			return result
		result.source_value = HockshopStaticValues.VALUES[item.item_definition_id]
	if result.source_value == 0:
		result.outcome = HockshopValuationResult.Outcome.WORTHLESS
		return result
	result.actual_payout = sell_payout(result.source_value)
	if result.actual_payout < 0:
		return result
	result.outcome = HockshopValuationResult.Outcome.SELLABLE
	return result
