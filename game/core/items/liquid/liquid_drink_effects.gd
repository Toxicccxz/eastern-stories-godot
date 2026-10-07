class_name LiquidDrinkEffects
extends RefCounted

## What one sip does besides quenching thirst (feature/liquid.c do_drink() after the
## water): query("liquid/drink_func") runs the powder poured in (dbase.c query()
## evaluates a function value) and, as it returns 0, alcohol then adds its drunk_apply
## to the drunk condition. `catalog` names the poured powder's PourDefinition.
static func apply(character: CharacterState, liquid: LiquidState, definition: LiquidDefinition, catalog: ContentCatalog) -> void:
	if character == null or liquid == null or definition == null:
		return
	if not liquid.drink_func.is_empty() and catalog != null:
		var powder: ItemContentDefinition = catalog.item(liquid.drink_func)
		if powder != null and powder.pour != null:
			add_to(character, powder.pour.condition, powder.pour.dose_from(liquid))
	if LiquidState.legacy_type(liquid.content) == &"alcohol":
		add_to(character, ConditionIds.DRUNK, definition.drunk_apply)


## apply_condition(id, query_condition(id) + amount).
static func add_to(character: CharacterState, condition_id: StringName, amount: int) -> void:
	var current: DurationConditionPayload = character.conditions.get_condition(condition_id) as DurationConditionPayload
	character.conditions.add_or_replace_duration(condition_id, (0 if current == null else current.remaining) + amount)


## pour <powder> in <container>: the drink now runs the powder's effect
## (set("liquid/drink_func")) and poison_dust.c adds to liquid/slumber_effect.
static func pour(liquid: LiquidState, powder: ItemContentDefinition) -> void:
	liquid.drink_func = powder.item_definition_id
	liquid.slumber_effect += powder.pour.adds_to_liquid
