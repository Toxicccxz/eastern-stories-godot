class_name NpcDrinkService
extends RefCounted

## d/snow/npc/drunk.c do_drink() (NpcDrinkAction) for one chat beat. The NPC
## drinks with feature/liquid.c do_drink() from the first alcohol it carries and,
## once it is empty, drops it with cmds/std/drop.c; the runtime lays the dropped
## item where the NPC stands. Lines are as the player in its room reads them.
enum Outcome { SATED, DRANK, COULD_NOT_DRINK, DRY, AUTHORITY_FAILURE }


class Result:
	extends RefCounted
	var outcome: Outcome = Outcome.AUTHORITY_FAILURE
	var lines: Array[String] = []
	## The empty container it dropped, now in `floor`.
	var dropped_item_id: StringName = &""


static func drink(
	npc: NpcRuntimeState,
	action: NpcDrinkAction,
	floor: ContainmentEndpoint,
	inventory: InventoryState,
	index: WorldItemInstanceIndex,
	liquids: LiquidCollection,
) -> Result:
	var result := Result.new()
	if npc == null or action == null or floor == null or inventory == null or index == null or liquids == null:
		return result
	var name: String = TranslationServer.translate(npc.definition().display_name)
	var recovery: CharacterRecoveryState = npc.character_state.recovery
	if recovery.water >= action.sated_water:
		result.outcome = Outcome.SATED # command("sing"): prints nothing.
		return result
	var holder := ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, npc.character_id)
	var container_id: StringName = &""
	for id: StringName in inventory.direct_children(holder):
		var state: LiquidState = liquids.state(id)
		if state != null and LiquidState.legacy_type(state.content) == &"alcohol":
			container_id = id
			break
	if container_id.is_empty():
		if not action.dry_clears.is_empty():
			npc.set_flag(action.dry_clears, false)
		result.lines.append(TranslationServer.translate("{npc}说道：{line}").format({"npc": name, "line": NpcTalk.line(action.dry_say)}))
		result.outcome = Outcome.DRY
		return result
	var item: ItemInstance = index.resolve(container_id)
	var content: ItemContentDefinition = null if item == null else GameContent.catalog().item(item.item_definition_id)
	var liquid: LiquidState = liquids.state(container_id)
	if content == null or content.liquid_definition() == null:
		return result
	result.outcome = Outcome.COULD_NOT_DRINK
	# liquid.c do_drink(): busy, empty or too full refuse quietly (notify_fail to the drinker).
	if not npc.busy.is_busy() and liquid.remaining > 0 and recovery.water < CharacterRecovery.maximum_water_capacity(npc.body_weight):
		liquid.remaining -= 1
		recovery.water += content.liquid_definition().hydration
		result.lines.append(TranslationServer.translate("{npc}拿起{container}咕噜噜地喝了几口{liquid}。").format({
			"npc": name, "container": TranslationServer.translate(content.display_name),
			"liquid": TranslationServer.translate(LiquidState.content_name(liquid.content)),
		}))
		result.outcome = Outcome.DRANK
	if liquid.remaining == 0:
		var dropped: InventoryTransferResult = InventoryTransferService.new().transfer(
			inventory, container_id, InventoryTransferDestination.new(floor, true, true, WorldMapController.WORLD_CAPACITY),
			npc.character_state.equipment, npc.armor,
		)
		if not dropped.succeeded:
			result.outcome = Outcome.AUTHORITY_FAILURE
			return result
		result.lines.append(TranslationServer.translate("{npc}丢下{item}。").format({"npc": name, "item": HeldItemFacts.one_unit(content)}))
		result.dropped_item_id = container_id
	return result
