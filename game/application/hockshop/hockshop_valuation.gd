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
	var catalog: ContentCatalog = GameContent.catalog()
	if catalog.denomination_of(item.item_definition_id) != CurrencyDenomination.Value.UNSUPPORTED:
		result.outcome = HockshopValuationResult.Outcome.MONEY_REJECTED
		return result
	result.outcome = HockshopValuationResult.Outcome.UNSUPPORTED_ITEM
	if not context.inventory.direct_children(ContainmentEndpoint.new(ContainmentEndpoint.Kind.ITEM, id)).is_empty():
		return result
	# Only authored items have a value; rule-created ones (a corpse) do not.
	var content: ItemContentDefinition = catalog.item(item.item_definition_id)
	if content == null:
		return result
	result.outcome = HockshopValuationResult.Outcome.INVALID_ITEM_STATE
	# A combined item (蛇药) is valued as hockshop.c asks it: query("value"), whatever
	# the amount; 飞刀 has none (一文不值).
	if context.stacks.has_stack(id) != content.is_stack:
		return result
	var food: FoodState = foods.state(id)
	var liquid: LiquidState = liquids.state(id)
	var food_definition: FoodDefinition = content.food_definition()
	var liquid_definition: LiquidDefinition = content.liquid_definition()
	if food_definition != null:
		if food == null or liquid != null or not food_definition.accepts_live_state(food.remaining_portions, food.current_value) or context.inventory.own_weight(id) != food_definition.own_weight:
			return result
		result.source_value = food.current_value
	elif liquid_definition != null:
		if liquid == null or food != null or not liquid_definition.accepts_live_state(liquid.content, liquid.remaining) or context.inventory.own_weight(id) != liquid_definition.own_weight:
			return result
		result.source_value = liquid_definition.value
	else:
		if food != null or liquid != null or context.inventory.own_weight(id) < 0:
			return result
		result.source_value = content.value
	if result.source_value == 0:
		result.outcome = HockshopValuationResult.Outcome.WORTHLESS
		return result
	result.actual_payout = sell_payout(result.source_value)
	if result.actual_payout < 0:
		return result
	result.outcome = HockshopValuationResult.Outcome.SELLABLE
	return result
