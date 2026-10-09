class_name ItemHandlingService
extends RefCounted

## cmds/std/give.c, drop.c, put.c and get.c `get <item> from <container>`, for the
## player's own items (present(item, me): direct children only). An amount hands
## over part of a stack (`give 5 silver to wey`); the part is split off only once
## nothing can refuse it any more, so a refusal never costs the player the part
## (ES2 lost it: its new object had no environment; DECISIONS 4E). The runtime
## decides presence and reach, and prints the returned lines.

## give.c's notify_fail on a refusal, 你只能把东西送给其他玩家操纵的人物。, speaks of other
## players; deviation (owner, modern fixes): the player reads that the NPC did not take it.
# TRANSLATORS: give: the NPC ({npc}) did not take what the player offered (it stays with the player).
const NOT_TAKEN: String = "{npc}没有收下。"
## judge.c pay_player(): a win the player cannot carry was lost (move() failed). Deviation
## (owner, 3D): the player takes what they can carry and the rest lands at their feet, and
## they read so. The first part is move.c's.
# TRANSLATORS: winnings too heavy to carry ({item}: 二百两银子) land on the floor by the player.
const WINNINGS_AT_FEET: String = "{item}对你而言太重了，掉在你的脚边。"


## The authorities one command borrows: the player's MoneyInventoryContext
## (inventory, stacks, index, owner), the role states and the dynamic ID allocator.
class Authorities:
	extends RefCounted
	var context: MoneyInventoryContext
	var foods: FoodCollection
	var liquids: LiquidCollection
	var allocator: SessionItemIdAllocator

	func _init(p_context: MoneyInventoryContext, p_foods: FoodCollection, p_liquids: LiquidCollection, p_allocator: SessionItemIdAllocator) -> void:
		context = p_context
		foods = p_foods
		liquids = p_liquids
		allocator = p_allocator

	func is_valid() -> bool:
		return context != null and context.is_valid() and foods != null and liquids != null and allocator != null


## give.c: `npc_here` is present(target) and living(who). The NPC's accept_object()
## rules decide; money (the only object with a value(), std/money.c) is then
## destructed, anything else is moved to the NPC (combined.c merges a stack into a
## living holder). Money taken as a bet (`effect: wager`) is then rolled for; winnings
## the player cannot carry land on `floor` (`dropped_item_ids`).
static func give(
	player: WorldPlayerRuntimeState,
	npc: NpcRuntimeState,
	npc_here: bool,
	id: StringName,
	amount: int,
	authorities: Authorities,
	random: WorldInteractionRandomSource,
	floor: ContainmentEndpoint = null,
) -> ItemHandlingResult:
	var result := ItemHandlingResult.new()
	if player == null or npc == null or authorities == null or not authorities.is_valid() or random == null:
		return result
	if not npc_here:
		return _refused(result, ItemHandlingResult.Outcome.NOT_HERE, TranslationServer.translate("这里没有这个人。"))
	var content: ItemContentDefinition = _carried(result, authorities, id, amount)
	if content == null:
		return result
	if content.no_drop:
		return _refused(result, ItemHandlingResult.Outcome.REFUSED, TranslationServer.translate("这样东西不能随便给人。"))
	var name: String = npc.definition().display_name
	var offer := NpcObjectRule.Offer.new(
		_portion_money(authorities, id, content, amount), &"", 0, npc.flags(), player.state.marks,
	)
	offer.giver_gender = player.state.gender
	offer.giver_per = player.state.attributes.personality
	offer.item_name = content.display_name
	offer.item_aliases = content.aliases()
	offer.giver_family = player.state.family.family_id
	var liquid: LiquidState = authorities.liquids.state(id)
	if liquid != null:
		offer.liquid_type = LiquidState.legacy_type(liquid.content)
		offer.liquid_remaining = liquid.remaining
	result.rule = NpcObjectRule.decide(npc.definition().dealings().object_rules, offer)
	var respect: String = RankWords.query_respect(player.state.gender, player.facts.age, player.state.affiliation.class_id)
	if result.rule != null:
		for line: NpcLine in result.rule.lines:
			if line.whisper:
				result.line_colors[result.lines.size()] = line.color()
			result.lines.append(line.sentence(name, respect))
		# delete_temp(): shen.c's 想骗我啊? deletes the giver's flags even as it refuses.
		for mark: String in result.rule.unmark_giver:
			player.state.marks.erase(mark)
	if result.rule == null or not result.rule.accept:
		result.lines.append(TranslationServer.translate(NOT_TAKEN).format({"npc": TranslationServer.translate(name)}))
		result.outcome = ItemHandlingResult.Outcome.REFUSED
		return result
	_apply_acceptance(result.rule, player, npc, offer.value, random)
	var portion: StringName = _split_portion(result, authorities, id, content, amount)
	if portion.is_empty():
		return result
	if offer.value != 0:
		result.lines.append(TranslationServer.translate("你拿出{item}给{npc}。").format({
			"item": HeldItemFacts.short_name(portion, content, authorities.context.stacks), "npc": TranslationServer.translate(name),
		}))
		if not _destroy(authorities, portion):
			result.outcome = ItemHandlingResult.Outcome.AUTHORITY_FAILURE
			return result
		result.destroyed = true
		if result.rule.effect == NpcObjectRule.EFFECT_WAGER and not _settle_wager(result, player, npc, offer.value, respect, authorities, random, floor):
			result.outcome = ItemHandlingResult.Outcome.AUTHORITY_FAILURE
			return result
	else:
		var holder := ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, npc.character_id)
		var npc_owner := ItemLifecycleOwnerContext.new(npc.character_id, npc.character_state.equipment, npc.armor)
		var moved: InventoryTransferResult = _move(authorities, portion, InventoryTransferDestination.new(holder, true, true, npc.maximum_encumbrance), npc_owner)
		if moved == null or not moved.succeeded:
			_return_portion(authorities, id, portion)
			return _too_heavy(result, moved, TranslationServer.translate("{item}对{holder}而言太重了。").format({
				"item": TranslationServer.translate(content.display_name), "holder": TranslationServer.translate(name),
			}))
		result.lines.append(TranslationServer.translate("你给{npc}{item}。").format({"npc": TranslationServer.translate(name), "item": HeldItemFacts.one_unit(content)}))
	result.item_id = portion
	result.outcome = ItemHandlingResult.Outcome.DONE
	return result


## ob->move(npc) of something the player carries (u/cloud thief.c through steal.c):
## the whole object, merged into the NPC's own stack. False when it is too heavy.
static func hand_over(npc: NpcRuntimeState, id: StringName, authorities: Authorities) -> bool:
	if npc == null or authorities == null or not authorities.is_valid():
		return false
	var holder := ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, npc.character_id)
	var npc_owner := ItemLifecycleOwnerContext.new(npc.character_id, npc.character_state.equipment, npc.armor)
	var moved: InventoryTransferResult = _move(authorities, id, InventoryTransferDestination.new(holder, true, true, npc.maximum_encumbrance), npc_owner)
	return moved != null and moved.succeeded


## command("give <id> to <player>") by an NPC (chess_player.c play_chess()): `amount` of
## the stack `id` it carries (all of it for 0) goes to `receiver`, merged into what they
## hold. `authorities` are the NPC's (its owner context). Empty when it could not be
## moved (too heavy: it stays with the NPC); else the id the receiver now holds.
static func npc_hands_over(id: StringName, amount: int, receiver: ItemLifecycleOwnerContext, capacity: int, authorities: Authorities) -> StringName:
	if authorities == null or not authorities.is_valid() or receiver == null:
		return &""
	var item: ItemInstance = authorities.context.index.resolve(id)
	var content: ItemContentDefinition = null if item == null else GameContent.catalog().item(item.item_definition_id)
	if content == null:
		return &""
	var result := ItemHandlingResult.new()
	var portion: StringName = _split_portion(result, authorities, id, content, amount)
	if portion.is_empty():
		return &""
	var destination := InventoryTransferDestination.new(
		ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, receiver.character_id), true, true, capacity,
	)
	var moved: InventoryTransferResult = _move(authorities, portion, destination, receiver)
	if moved == null or not moved.succeeded:
		_return_portion(authorities, id, portion)
		return &""
	return portion


## drop.c: onto the floor of the player's place (`floor`); something worth
## nothing is destructed at once, as nobody would notice it.
## drop.c: set("no_drop") refuses (its own line when it is a string).
static func drop(player: WorldPlayerRuntimeState, id: StringName, amount: int, floor: ContainmentEndpoint, authorities: Authorities) -> ItemHandlingResult:
	var result := ItemHandlingResult.new()
	if player == null or floor == null or floor.kind != ContainmentEndpoint.Kind.WORLD or authorities == null or not authorities.is_valid():
		return result
	var content: ItemContentDefinition = _carried(result, authorities, id, amount)
	if content == null:
		return result
	if content.no_drop:
		var line: String = TranslationServer.translate("这样东西不能随意丢弃。") if content.no_drop_line.is_empty() else TranslationServer.translate(content.no_drop_line)
		return _refused(result, ItemHandlingResult.Outcome.REFUSED, line)
	var portion: StringName = _split_portion(result, authorities, id, content, amount)
	if portion.is_empty():
		return result
	var moved: InventoryTransferResult = _move(authorities, portion, InventoryTransferDestination.new(floor, true, true, WorldMapController.WORLD_CAPACITY))
	if moved == null or not moved.succeeded:
		result.outcome = ItemHandlingResult.Outcome.AUTHORITY_FAILURE
		return result
	result.item_id = portion
	result.lines.append(TranslationServer.translate("你丢下%s。") % HeldItemFacts.one_unit(content))
	# !query("value") && !value(): a bitten dumpling's value is 0, money's value() is not.
	if HeldItemFacts.value_of(portion, content, authorities.context.stacks, authorities.foods) == 0:
		result.lines.append(TranslationServer.translate("因为这样东西并不值钱，所以人们并不会注意到它的存在。"))
		if not _destroy(authorities, portion):
			result.outcome = ItemHandlingResult.Outcome.AUTHORITY_FAILURE
			return result
		result.destroyed = true
	result.outcome = ItemHandlingResult.Outcome.DONE
	return result


## put.c: into a container (feature/move.c set_max_encumbrance()) where the player
## is; it takes what fits under its capacity.
static func put(player: WorldPlayerRuntimeState, id: StringName, amount: int, container_id: StringName, authorities: Authorities) -> ItemHandlingResult:
	var result := ItemHandlingResult.new()
	if player == null or authorities == null or not authorities.is_valid():
		return result
	var container: ItemContentDefinition = _content(authorities, container_id)
	if container == null or container.max_encumbrance <= 0 or container_id == id:
		return _refused(result, ItemHandlingResult.Outcome.NOT_HERE, TranslationServer.translate("这里没有这样东西。"))
	var content: ItemContentDefinition = _carried(result, authorities, id, amount)
	if content == null:
		return result
	if content.no_drop:
		return _refused(result, ItemHandlingResult.Outcome.REFUSED, TranslationServer.translate("这个东西还是小心保管的好，不必放在别处。"))
	var inside := ContainmentEndpoint.new(ContainmentEndpoint.Kind.ITEM, container_id)
	var weight: int = _portion_weight(authorities, id, content, amount)
	if authorities.context.inventory.contents_weight(inside) + weight > container.max_encumbrance:
		return _refused(result, ItemHandlingResult.Outcome.TOO_HEAVY, TranslationServer.translate("{item}对{holder}而言太重了。").format({
			"item": TranslationServer.translate(content.display_name), "holder": TranslationServer.translate(container.display_name),
		}))
	var portion: StringName = _split_portion(result, authorities, id, content, amount)
	if portion.is_empty():
		return result
	var moved: InventoryTransferResult = _move(authorities, portion, InventoryTransferDestination.new(inside, true, true, container.max_encumbrance))
	if moved == null or not moved.succeeded:
		_return_portion(authorities, id, portion)
		return _too_heavy(result, moved, TranslationServer.translate("{item}对{holder}而言太重了。").format({
			"item": TranslationServer.translate(content.display_name), "holder": TranslationServer.translate(container.display_name),
		}))
	result.item_id = portion
	result.lines.append(TranslationServer.translate("你将{item}放进{container}。").format({
		"item": HeldItemFacts.one_unit(content), "container": TranslationServer.translate(container.display_name),
	}))
	result.outcome = ItemHandlingResult.Outcome.DONE
	return result


## get.c `get <item> from <container>`: the whole object, merged into a stack the
## player holds; busy(1) when taken in a fight.
static func take_from(player: WorldPlayerRuntimeState, container_id: StringName, id: StringName, authorities: Authorities) -> ItemHandlingResult:
	var result := ItemHandlingResult.new()
	if player == null or authorities == null or not authorities.is_valid():
		return result
	if player.busy.is_busy():
		return _refused(result, ItemHandlingResult.Outcome.REFUSED, TranslationServer.translate("你上一个动作还没有完成！"))
	var container: ItemContentDefinition = _content(authorities, container_id)
	var content: ItemContentDefinition = _content(authorities, id)
	var inside := ContainmentEndpoint.new(ContainmentEndpoint.Kind.ITEM, container_id)
	if container == null or content == null or not authorities.context.inventory.is_direct_child(id, inside):
		return _refused(result, ItemHandlingResult.Outcome.NOT_HERE, TranslationServer.translate("这里没有这样东西。"))
	if content.no_get:
		return _refused(result, ItemHandlingResult.Outcome.REFUSED, TranslationServer.translate("这个东西拿不起来。"))
	var moved: InventoryTransferResult = _move(authorities, id, InventoryTransferDestination.new(authorities.context.endpoint(), true, true, player.maximum_encumbrance))
	if moved == null or not moved.succeeded:
		return _too_heavy(result, moved, TranslationServer.translate("%s对你而言太重了。") % TranslationServer.translate(content.display_name))
	if player.relationship.is_fighting():
		player.busy.start_busy(1)
	result.item_id = id
	result.lines.append(TranslationServer.translate("你从{container}中拿出{item}。").format({
		"container": TranslationServer.translate(container.display_name), "item": HeldItemFacts.one_unit(content),
	}))
	result.outcome = ItemHandlingResult.Outcome.DONE
	return result


# --- Shared steps ----------------------------------------------------------------

static func _content(authorities: Authorities, id: StringName) -> ItemContentDefinition:
	var item: ItemInstance = authorities.context.index.resolve(id)
	return null if item == null else GameContent.catalog().item(item.item_definition_id)


## present(item, me) and the amount checks of give.c/drop.c/put.c; null (with the
## refusal in `result`) when the player cannot hand it over.
static func _carried(result: ItemHandlingResult, authorities: Authorities, id: StringName, amount: int) -> ItemContentDefinition:
	var content: ItemContentDefinition = _content(authorities, id)
	if content == null or not authorities.context.inventory.is_direct_child(id, authorities.context.endpoint()):
		_refused(result, ItemHandlingResult.Outcome.NOT_CARRIED, TranslationServer.translate("你身上没有这样东西。"))
		return null
	if amount > 0 and authorities.context.stacks.has_stack(id) and amount > authorities.context.stacks.stack_state(id).amount:
		_refused(result, ItemHandlingResult.Outcome.NOT_ENOUGH, TranslationServer.translate("你没有那麽多的%s。") % TranslationServer.translate(content.display_name))
		return null
	return content


## Whether `amount` asks for part of a stack (otherwise the whole object goes).
static func _partial(authorities: Authorities, id: StringName, amount: int) -> bool:
	return amount > 0 and authorities.context.stacks.has_stack(id) and amount < authorities.context.stacks.stack_state(id).amount


## value() of what is handed over: money only (std/money.c).
static func _portion_money(authorities: Authorities, id: StringName, content: ItemContentDefinition, amount: int) -> int:
	if _partial(authorities, id, amount):
		return amount * content.currency_base_value
	return HeldItemFacts.money_value(id, content, authorities.context.stacks)


## A part split off for a move that then failed goes back into the stack it came from,
## so nothing is lost (DECISIONS 4E).
static func _return_portion(authorities: Authorities, source_id: StringName, portion: StringName) -> void:
	if portion == source_id or not authorities.context.inventory.is_registered(portion):
		return
	var back: InventoryTransferResult = _move(authorities, portion, InventoryTransferDestination.new(authorities.context.endpoint(), true, true, WorldMapController.WORLD_CAPACITY))
	if back == null or not back.succeeded:
		push_error("a split-off part %s could not be returned" % portion)


static func _portion_weight(authorities: Authorities, id: StringName, content: ItemContentDefinition, amount: int) -> int:
	if _partial(authorities, id, amount):
		return amount * content.stack_base_weight
	return authorities.context.inventory.subtree_weight(id)


## The object the command acts on: `id`, or a new stack of `amount` split off it
## (new(base_name(obj)) with set_amount()). Empty on failure, recorded in `result`.
static func _split_portion(result: ItemHandlingResult, authorities: Authorities, id: StringName, content: ItemContentDefinition, amount: int) -> StringName:
	if not _partial(authorities, id, amount):
		return id
	result.outcome = ItemHandlingResult.Outcome.AUTHORITY_FAILURE
	var allocation: SessionItemIdAllocationResult = authorities.allocator.allocate(authorities.context.inventory)
	if not allocation.succeeded:
		return &""
	var part := ItemInstance.new(allocation.item_instance_id, content.item_definition_id)
	var split: CombinedStackSplitResult = CombinedStackService.split(authorities.context.stacks, authorities.context.inventory, id, amount, part)
	if not split.succeeded or not authorities.context.index.register_snapshot(part):
		return &""
	return part.item_instance_id


## feature/move.c, with combined.c merging a stack into a living holder. `owner` is
## another holder's authorities (an NPC given a stack); the player's are the default.
static func _move(authorities: Authorities, id: StringName, destination: InventoryTransferDestination, owner: ItemLifecycleOwnerContext = null) -> InventoryTransferResult:
	var context: MoneyInventoryContext = authorities.context
	if not context.stacks.has_stack(id):
		return InventoryTransferService.new().transfer(context.inventory, id, destination, context.owner.equipment_state, context.owner.armor_state)
	# Merging destroys the holder's own stacks of the kind: the holder's authorities.
	var holder: ItemLifecycleOwnerContext = owner
	if holder == null and destination.endpoint.kind == ContainmentEndpoint.Kind.CHARACTER and destination.endpoint.endpoint_id == context.owner.character_id:
		holder = context.owner
	var merged: CombinedStackMergeResult = CombinedStackService.transfer_and_merge(
		context.stacks, context.inventory, id, destination, context.owner.equipment_state, context.owner.armor_state, holder,
	)
	if not context.index.forget_destroyed_snapshots(merged.absorbed_instance_ids, context.inventory):
		return null
	if merged.inventory_transfer != null and merged.inventory_transfer.succeeded and not merged.succeeded:
		return null
	return merged.inventory_transfer


## destruct(obj), with its role states and index entry.
static func _destroy(authorities: Authorities, id: StringName) -> bool:
	var context: MoneyInventoryContext = authorities.context
	var removal: ItemLifecycleResult = ItemLifecycleService.destroy_item(
		context.inventory, context.stacks, id, ItemLifecycleResult.ChildDisposition.REQUIRE_LEAF, context.owner,
	)
	return (
		removal.succeeded
		and authorities.foods.forget_removed(removal.removed_instance_ids, context.inventory)
		and authorities.liquids.forget_removed(removal.removed_instance_ids, context.inventory)
		and context.index.forget_destroyed_snapshots(removal.removed_instance_ids, context.inventory)
	)


## What an accepted gift changes: marks/<name> on the giver, an object variable of
## the NPC, and keeper.c's donation, which may lower the giver's bellicosity.
@warning_ignore("integer_division")
static func _apply_acceptance(rule: NpcObjectRule, player: WorldPlayerRuntimeState, npc: NpcRuntimeState, value: int, random: WorldInteractionRandomSource) -> void:
	if not rule.mark_giver.is_empty():
		player.state.marks[rule.mark_giver] = 1
	if not rule.set_npc_flag.is_empty():
		npc.set_flag(rule.set_npc_flag, true)
	if rule.effect == NpcObjectRule.EFFECT_TEMPLE_DONATION and value > 100:
		var attributes: CharacterBaseAttributes = player.state.attributes
		if attributes.bellicosity > 0 and random.legacy_random(value / 10) > attributes.karma:
			attributes.bellicosity -= random.legacy_random(attributes.karma) + value / 1000


## judge.c accept_object() after the stake is gone: the house rolls (NpcWager); a win
## pays pay_player(val * 2) in silver and coins. False on an authority failure.
@warning_ignore("integer_division")
static func _settle_wager(
	result: ItemHandlingResult,
	player: WorldPlayerRuntimeState,
	npc: NpcRuntimeState,
	stake: int,
	respect: String,
	authorities: Authorities,
	random: WorldInteractionRandomSource,
	floor: ContainmentEndpoint,
) -> bool:
	var wager: NpcWager = npc.definition().dealings().wager
	if wager == null:
		return false
	var won: bool = wager.wins(random)
	for line: NpcLine in wager.win_lines if won else wager.lose_lines:
		result.lines.append(line.sentence(npc.definition().display_name, respect))
	if not won:
		return true
	var winnings: int = wager.winnings(stake)
	var contents: int = authorities.context.checked_contents_weight()
	if winnings < 1 or contents < 0:
		return false
	# pay_player(): silver, then coins. Of each, what still fits under max_encumbrance is the
	# player's; the rest falls at their feet in one pile.
	var room: int = player.maximum_encumbrance - contents
	var carried: int = 0
	var fallen: Dictionary[CurrencyDenomination.Value, int] = {}
	for denomination: CurrencyDenomination.Value in [CurrencyDenomination.Value.SILVER, CurrencyDenomination.Value.COIN]:
		var content: ItemContentDefinition = GameContent.catalog().currency_item(denomination)
		var quantity: int = winnings / 100 if denomination == CurrencyDenomination.Value.SILVER else winnings % 100
		var fit: int = quantity if content.stack_base_weight <= 0 else clampi(room / content.stack_base_weight, 0, quantity)
		room -= fit * content.stack_base_weight
		carried += fit * content.currency_base_value
		fallen[denomination] = quantity - fit
	if carried > 0:
		var payout: HockshopPayoutResult = HockshopPayoutService.pay(authorities.context, authorities.allocator, player.maximum_encumbrance, carried)
		if payout.outcome != HockshopPayoutResult.Outcome.COMPLETE or payout.delivered_value != carried:
			return false
	for denomination: CurrencyDenomination.Value in fallen:
		if fallen[denomination] == 0:
			continue
		var dropped: StringName = _mint_on_floor(authorities, denomination, fallen[denomination], floor)
		if dropped.is_empty():
			return false
		result.dropped_item_ids.append(dropped)
		result.lines.append(TranslationServer.translate(WINNINGS_AT_FEET).format({
			"item": HeldItemFacts.short_name(dropped, _content(authorities, dropped), authorities.context.stacks),
		}))
	return true


## new(SILVER_OB) with set_amount(`quantity`), straight onto `floor`. Empty on failure.
static func _mint_on_floor(authorities: Authorities, denomination: CurrencyDenomination.Value, quantity: int, floor: ContainmentEndpoint) -> StringName:
	var context: MoneyInventoryContext = authorities.context
	var content: ItemContentDefinition = GameContent.catalog().currency_item(denomination)
	if floor == null or floor.kind != ContainmentEndpoint.Kind.WORLD or content == null:
		return &""
	var allocation: SessionItemIdAllocationResult = authorities.allocator.allocate(context.inventory)
	if not allocation.succeeded:
		return &""
	var item := ItemInstance.new(allocation.item_instance_id, content.item_definition_id)
	if (
		not context.inventory.register_item(item, 0) or not context.index.register_snapshot(item)
		or not CombinedStackService.register_stack(context.stacks, context.inventory, item, content.stack_definition(), quantity).accepted
	):
		return &""
	var moved: InventoryTransferResult = InventoryTransferService.new().transfer(
		context.inventory, item.item_instance_id, InventoryTransferDestination.new(floor, true, true, WorldMapController.WORLD_CAPACITY),
	)
	return item.item_instance_id if moved != null and moved.succeeded else &""


static func _refused(result: ItemHandlingResult, outcome: ItemHandlingResult.Outcome, line: String) -> ItemHandlingResult:
	result.outcome = outcome
	result.lines.append(line)
	return result


## move()'s notify_fail when the holder cannot take the weight; anything else is a fault.
static func _too_heavy(result: ItemHandlingResult, moved: InventoryTransferResult, line: String) -> ItemHandlingResult:
	if moved != null and moved.outcome == InventoryTransferResult.Outcome.CAPACITY_EXCEEDED:
		return _refused(result, ItemHandlingResult.Outcome.TOO_HEAVY, line)
	result.outcome = ItemHandlingResult.Outcome.AUTHORITY_FAILURE
	return result
