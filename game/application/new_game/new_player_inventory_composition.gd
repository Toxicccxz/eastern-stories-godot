class_name NewPlayerInventoryComposition
extends RefCounted

## One-shot fresh-player composition for a future NEW_GAME Session.
## Not connected to the current technical New Game or any restore path.
var _player: NewPlayerInitialization
var _inventory: InventoryState
var _stacks: CombinedStackCollection
var _item_index: WorldItemInstanceIndex
var _cloth: ItemInstance

var player: NewPlayerInitialization:
	get: return _player
var inventory: InventoryState:
	get: return _inventory
var stacks: CombinedStackCollection:
	get: return _stacks
var item_index: WorldItemInstanceIndex:
	get: return _item_index
var cloth: ItemInstance:
	get: return _cloth


func initialize(
	character_id: StringName, selected_gender: StringName, display_name: String,
	allocator: SessionItemIdAllocator,
) -> bool:
	if _player != null or character_id.is_empty() or allocator == null or not allocator.is_valid():
		return false
	var fresh: NewPlayerInitialization = NewPlayerInitializationPolicy.create(selected_gender, display_name)
	if fresh == null:
		return false
	var inventory_state: InventoryState = InventoryState.new()
	var allocation: SessionItemIdAllocationResult = allocator.allocate(inventory_state)
	if not allocation.succeeded:
		return false
	var definition: ItemDefinition = SourcePlayerCloth.item_definition()
	var item: ItemInstance = ItemInstance.new(allocation.item_instance_id, definition.item_definition_id)
	var index: WorldItemInstanceIndex = WorldItemInstanceIndex.new()
	if not inventory_state.register_item(item, SourcePlayerCloth.OWN_WEIGHT) or not index.register_snapshot(item):
		return false
	var owner: ContainmentEndpoint = ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, character_id)
	var destination: InventoryTransferDestination = InventoryTransferDestination.new(
		owner, true, true, fresh.maximum_encumbrance,
	)
	if not InventoryTransferService.new().transfer(inventory_state, item.item_instance_id, destination).succeeded:
		return false
	if not ArmorService.wear(fresh.armor, inventory_state, owner, item, SourcePlayerCloth.armor_definition()).succeeded:
		return false
	_player = fresh
	_inventory = inventory_state
	_stacks = CombinedStackCollection.new()
	_item_index = index
	_cloth = item
	return true
