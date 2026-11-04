class_name HeldSupplies
extends RefCounted
## 吃 and 喝 from the 背包 (owner, 2026-11-04: 随身补给 folded into the item read beside the
## list): one carried food or drink container by its id, feature/food.c do_eat() and
## feature/liquid.c do_drink() / do_fill() in their words. Session view only: the food and
## liquid collections, the player and the inventory stay authoritative.

var _session: WorldSessionController
## The last use's result (tests).
var last_food: FoodUseResult
var last_liquid: LiquidUseResult


func _init(session: WorldSessionController) -> void:
	_session = session


func is_food(id: StringName) -> bool:
	return _live() and _session.food_collection().state(id) != null


func is_liquid(id: StringName) -> bool:
	return _live() and _session.liquid_collection().state(id) != null


## Food can be eaten now: the world runs, the player walks the map, alive and not fighting.
func food_available() -> bool:
	if not _live() or not _session.world_simulation_gate().is_open():
		return false
	var map: WorldResidentMapController = _session.active_map()
	var player: WorldPlayerRuntimeState = _session.player_runtime()
	return (
		map != null and map.is_map_initialized() and map.runtime_player_body() != null
		and map.runtime_player_body().player_controlled and player.exists_in_world
		and player.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE and not player.relationship.is_fighting()
	)


## A drink can be had (or a container filled) now: not in a fight.
func liquid_available() -> bool:
	return (
		_live() and _session.liquid_interaction_available()
		and not _session.combat_encounter_coordinator().has_active_encounter()
		and not _session.player_runtime().relationship.is_fighting()
	)


## There is water here to fill a container from.
func can_fill() -> bool:
	return _live() and _session.fill_water_available()


## What is left of a food: portions and its value now (feature/food.c).
func food_status(id: StringName) -> String:
	var state: FoodState = _session.food_collection().state(id) if _live() else null
	if state == null:
		return ""
	# TRANSLATORS: a carried food in the 背包: {portions} portions left, {value} its value in coins.
	return tr("还剩 {portions} 份 · 价值 {value} 文").format({"portions": state.remaining_portions, "value": state.current_value})


## What a container holds and how much of the most it holds.
func liquid_status(id: StringName) -> String:
	var state: LiquidState = _session.liquid_collection().state(id) if _live() else null
	if state == null:
		return ""
	if state.remaining <= 0:
		# TRANSLATORS: an empty drink container in the 背包.
		return tr("里面是空的 · 最多装 {maximum} 份").format({"maximum": _maximum_portions(id)})
	# TRANSLATORS: a carried drink container in the 背包: {liquid} what it holds (清水, 红酒), {portions} left of {maximum}.
	return tr("装着{liquid} · {portions}/{maximum} 份").format({
		"liquid": tr(_liquid_name(id, state.content)), "portions": state.remaining, "maximum": _maximum_portions(id),
	})


## The drink button: one portion of what the container holds.
func drink_label(id: StringName) -> String:
	var state: LiquidState = _session.liquid_collection().state(id) if _live() else null
	# TRANSLATORS: drink one portion of what the selected container holds ({liquid}: 红酒, 清水).
	return tr("喝一份{liquid}").format({"liquid": "" if state == null else tr(_liquid_name(id, state.content))})


func eat(id: StringName) -> String:
	if not is_food(id):
		return ""
	var player: WorldPlayerRuntimeState = _session.player_runtime()
	var food_name: String = tr(_item_name(id))
	last_food = HeldFoodUseService.eat(player, _context(), _session.food_collection(), GameContent.catalog().native_item_projections(), id, food_available())
	# feature/food.c do_eat(), in its words.
	match last_food.outcome:
		FoodUseResult.Outcome.ATE:
			var finished: bool = last_food.cleanup != null or not last_food.leftover_id.is_empty()
			return (tr("你将剩下的%s吃得乾乾净净。") if finished else tr("你拿起%s咬了几口。")) % food_name
		FoodUseResult.Outcome.GHOST:
			return tr("你已经是鬼了，不能吃东西！")
		FoodUseResult.Outcome.TOO_FULL:
			return tr("你已经吃太饱了，再也塞不下任何东西了。")
		FoodUseResult.Outcome.TOO_BLOATED:
			return tr("你肚子太涨了，再也撑不下任何东东了。!")
		FoodUseResult.Outcome.NOT_DIRECT_HELD:
			return tr("只能吃自己直接携带的食物。")
		FoodUseResult.Outcome.COMBAT_BLOCKED:
			return tr("战斗中暂不能吃东西。")
		FoodUseResult.Outcome.BUSY:
			return tr("你上一个动作还没有完成。")
		FoodUseResult.Outcome.AUTHORITY_FAILURE:
			return tr("物品状态异常，请停止操作。")
	return tr("现在不能吃这个物品。")


func drink(id: StringName) -> String:
	return _use(id, false)


func fill(id: StringName) -> String:
	return _use(id, true)


func _use(id: StringName, filling: bool) -> String:
	if not is_liquid(id):
		return ""
	var player: WorldPlayerRuntimeState = _session.player_runtime()
	var definitions: NativeItemDefinitionProjections = GameContent.catalog().native_item_projections()
	var encounter: bool = _session.combat_encounter_coordinator().has_active_encounter()
	var vessel: String = tr(_item_name(id))
	var held: LiquidState = _session.liquid_collection().state(id)
	var words: Dictionary = {"container": vessel, "liquid": tr(_liquid_name(id, held.content))}
	last_liquid = (
		HeldLiquidUseService.fill(player, _context(), _session.liquid_collection(), definitions, id, _session.liquid_interaction_available(), _session.fill_water_available(), encounter)
		if filling
		else HeldLiquidUseService.drink(player, _context(), _session.liquid_collection(), definitions, id, _session.liquid_interaction_available(), encounter)
	)
	# feature/liquid.c do_drink() and do_fill(), in their words.
	match last_liquid.outcome:
		LiquidUseResult.Outcome.FILLED:
			var filled: String = tr("你将%s装满清水。") % vessel
			if last_liquid.remaining_before > 0:
				return "\n".join([tr("你将{container}里剩下的{liquid}倒掉。").format(words), filled])
			return filled
		LiquidUseResult.Outcome.DRANK:
			var drank: String = tr("你拿起{container}咕噜噜地喝了几口{liquid}。").format(words)
			if last_liquid.remaining_after == 0:
				return "\n".join([drank, tr("你已经将{container}里的{liquid}喝得一滴也不剩了。").format(words)])
			return drank
		LiquidUseResult.Outcome.GHOST:
			return tr("你已经是鬼了，不能喝东西！")
		LiquidUseResult.Outcome.TOO_FULL:
			return tr("你已经喝太多了，再也灌不下一滴水了。")
		LiquidUseResult.Outcome.EMPTY:
			# liquid.c has no full stop on this line.
			return tr("%s已经被喝得一滴也不剩了") % vessel
		LiquidUseResult.Outcome.NO_WATER_SOURCE:
			return tr("这里没有地方可以装水。")
		LiquidUseResult.Outcome.BUSY:
			return tr("你上一个动作还没有完成。")
		LiquidUseResult.Outcome.COMBAT_BLOCKED:
			return tr("战斗中暂不能装水或饮用。")
		LiquidUseResult.Outcome.AUTHORITY_FAILURE:
			return tr("物品状态异常，请停止操作。")
	return tr("现在不能使用这个酒袋。")


func _live() -> bool:
	return _session != null and _session.is_initialized()


func _context() -> MoneyInventoryContext:
	var player: WorldPlayerRuntimeState = _session.player_runtime()
	return MoneyInventoryContext.new(ItemLifecycleOwnerContext.new(player.character_id, player.state.equipment, player.armor), _session.inventory_state(), _session.stack_collection(), _session.item_instance_index())


func _maximum_portions(id: StringName) -> int:
	var content: ItemContentDefinition = _content(id)
	return 0 if content == null or content.liquid_definition() == null else content.liquid_definition().maximum_portions


func _liquid_name(id: StringName, held: LiquidState.Content) -> String:
	var content: ItemContentDefinition = _content(id)
	return LiquidState.content_name(held) if content == null else content.liquid_name(held)


func _item_name(id: StringName) -> String:
	var content: ItemContentDefinition = _content(id)
	return "" if content == null else content.display_name


func _content(id: StringName) -> ItemContentDefinition:
	var item: ItemInstance = _session.item_instance_index().resolve(id)
	return null if item == null else GameContent.catalog().item(item.item_definition_id)

