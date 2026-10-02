class_name FloorItemPickup
extends RefCounted

## cmds/std/get.c `get <item>` for an item lying in the player's room: busy
## first, then whether it is there, then no_get, then feature/move.c's
## encumbrance check. Taking it in a fight starts busy(1).
enum Outcome {
	TAKEN,
	INVALID_REQUEST,
	PLAYER_NOT_AVAILABLE,
	BUSY,
	NOT_HERE,
	NO_GET,
	TOO_HEAVY,
	TRANSFER_FAILED,
}


static func take(
	player: WorldPlayerRuntimeState,
	item_instance_id: StringName,
	world_endpoint: ContainmentEndpoint,
	player_in_reach: bool,
	inventory: InventoryState,
	item_index: WorldItemInstanceIndex,
) -> Outcome:
	if player == null or inventory == null or item_index == null or world_endpoint == null or item_instance_id.is_empty():
		return Outcome.INVALID_REQUEST
	if not player.is_valid() or not player.exists_in_world or player.life_status != CharacterRuntimeLifeStatus.Value.ACTIVE:
		return Outcome.PLAYER_NOT_AVAILABLE
	if player.busy.is_busy():
		return Outcome.BUSY
	var item: ItemInstance = item_index.resolve(item_instance_id)
	var content: ItemContentDefinition = null if item == null else GameContent.catalog().item(item.item_definition_id)
	if content == null or not player_in_reach or not inventory.is_direct_child(item_instance_id, world_endpoint):
		return Outcome.NOT_HERE
	if content.no_get:
		return Outcome.NO_GET
	var transfer: InventoryTransferResult = InventoryTransferService.new().transfer(
		inventory,
		item_instance_id,
		InventoryTransferDestination.new(
			ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, player.character_id),
			true,
			true,
			player.maximum_encumbrance,
		),
	)
	if not transfer.succeeded:
		return Outcome.TOO_HEAVY if transfer.outcome == InventoryTransferResult.Outcome.CAPACITY_EXCEEDED else Outcome.TRANSFER_FAILED
	if player.relationship.is_fighting():
		player.busy.start_busy(1)
	return Outcome.TAKEN
