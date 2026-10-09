class_name WorldMapFloorItems
extends RefCounted
## Items lying on the map: spawned, restored and dropped ones, their views, the
## selected one's pickup; eating, drinking, pouring and using what the player holds;
## give, drop and put (give.c, drop.c, put.c) and containers. Code moved from
## WorldMapController as it was; the map is `_map`.

var _map: WorldMapController
var item_views: Dictionary[StringName, WorldFloorItemView] = {}
## Items lying away from any spawn marker (dropped), with their place; saved.
var _dropped: Dictionary[StringName, WorldLocationState] = {}
var landmark_use_counts: Dictionary[StringName, int] = {}

# The map's authorities, read as the controller reads them.
var session: WorldSessionController:
	get: return _map.session
var player_body: WorldCharacterBody2D:
	get: return _map.player_body
var map: StringName:
	get: return _map.map
var _player: WorldPlayerRuntimeState:
	get: return _map.player_runtime()
var _inventory: InventoryState:
	get: return _map.inventory_state()
var _stacks: CombinedStackCollection:
	get: return _map.stack_collection()
var _foods: FoodCollection:
	get: return _map.food_collection()
var _liquids: LiquidCollection:
	get: return _map.liquid_collection()
var _item_index: WorldItemInstanceIndex:
	get: return _map.item_instance_index()
var _item_id_allocator: SessionItemIdAllocator:
	get: return _map.item_id_allocator()
var _world_interaction_random: WorldInteractionRandomSource:
	get: return _map.world_interaction_random_source()


func _init(controller: WorldMapController) -> void:
	_map = controller


## A new world lays each item spawn's item on its marker (room.c reset() ->
## make_inventory()). Its identity follows from the spawn point, so nothing
## draws from a random source or the dynamic ID sequence.
func spawn_floor_items() -> bool:
	for spawn: ItemSpawnDefinition in GameContent.catalog().item_spawns_for_map(map):
		for point_id: StringName in spawn.spawn_point_ids():
			if not place_floor_item(spawn, point_id):
				return false
	return true


func place_floor_item(spawn: ItemSpawnDefinition, point_id: StringName) -> bool:
	var content: ItemContentDefinition = GameContent.catalog().item(spawn.item_definition_id)
	var location: WorldLocationState = _map.location_for_zone(spawn.zone_id)
	if content == null or location == null:
		return false
	var item: ItemInstance = ItemInstance.new(ItemSpawnDefinition.item_instance_id(_item_id_allocator.scope, point_id), content.item_definition_id)
	if (
		not _inventory.register_item(item, 0 if content.is_stack else content.own_weight)
		or not _item_index.register_snapshot(item)
		or not ItemRoleStates.register_fresh(content, item.item_instance_id, _foods, _liquids)
	):
		return false
	# combined.c: each one a room's objects make comes with create()'s set_amount() (桃符纸: one 张).
	if content.is_stack and not CombinedStackService.register_stack(_stacks, _inventory, item, content.stack_definition(), content.default_amount).accepted:
		return false
	var placed: InventoryTransferResult = InventoryTransferService.new().transfer(
		_inventory,
		item.item_instance_id,
		InventoryTransferDestination.new(floor_endpoint(location), true, true, _map.WORLD_CAPACITY),
	)
	return placed.succeeded and _add_floor_item_view(item.item_instance_id, content, point_id)


## Continue: a dropped item lies where the save says; an item still in its spawn's
## zone and not dropped lies on its marker; one taken away is wherever its record
## says (OldPineWorldRestoreComposition checks that every floor item has a place).
func restore_floor_items() -> bool:
	var catalog: ContentCatalog = GameContent.catalog()
	var dropped_anywhere: Dictionary[StringName, bool] = {}
	for record: GameSaveValueTypes.FloorItemSnapshot in session.restored_floor_items():
		dropped_anywhere[record.item_instance_id] = true
		if record.world_location.map_id != map:
			continue
		var location: WorldLocationState = _map.location_for_zone(record.world_location.zone_id)
		if location == null or not add_dropped_item_view(record.item_instance_id, location, Vector2(record.map_position.x, record.map_position.y)):
			return false
	for spawn: ItemSpawnDefinition in catalog.item_spawns_for_map(map):
		var content: ItemContentDefinition = catalog.item(spawn.item_definition_id)
		var location: WorldLocationState = _map.location_for_zone(spawn.zone_id)
		if content == null or location == null:
			return false
		for point_id: StringName in spawn.spawn_point_ids():
			var id: StringName = ItemSpawnDefinition.item_instance_id(_item_id_allocator.scope, point_id)
			var parent: ContainmentEndpoint = _inventory.direct_parent(id) if _inventory.is_registered(id) else null
			# A dropped one lies where its record says, maybe on another map.
			if parent == null or parent.kind != ContainmentEndpoint.Kind.WORLD or dropped_anywhere.has(id):
				continue
			if parent.endpoint_id != location.combat_location_id or not _add_floor_item_view(id, content, point_id):
				return false
	return true


func _add_floor_item_view(item_id: StringName, content: ItemContentDefinition, point_id: StringName) -> bool:
	var marker: WorldSpawnMarker2D = _map.resolve_spawn_marker(point_id)
	var view: WorldFloorItemView = WorldFloorItemView.new()
	if marker == null or not view.configure(item_id, content.display_name):
		view.free()
		return false
	view.position = marker.position
	marker.get_parent().add_child(view)
	item_views[item_id] = view
	view.selection_requested.connect(select_floor_item)
	return true


## A view for an item lying in `location` at `position` (dropped there), kept in
## the save (dropped_item_ids()).
func add_dropped_item_view(item_id: StringName, location: WorldLocationState, position: Vector2) -> bool:
	var item: ItemInstance = _item_index.resolve(item_id)
	var content: ItemContentDefinition = null if item == null else GameContent.catalog().item(item.item_definition_id)
	var view: WorldFloorItemView = WorldFloorItemView.new()
	if content == null or location == null or item_views.has(item_id) or not view.configure(item_id, content.display_name):
		view.free()
		return false
	var parent: Node = _map.get_node_or_null("SpawnPoints")
	(_map if parent == null else parent).add_child(view)
	view.global_position = position
	item_views[item_id] = view
	_dropped[item_id] = location.duplicate_snapshot()
	view.selection_requested.connect(select_floor_item)
	return true


## Where something dropped by a body standing at `origin` lies: just in front of its feet,
## where the body does not hide it, on the nearest spot a save accepts (Continue checks
## it); where it stands only when no spot nearby is one (a doorway footprint is not).
## `apart` passes over spots where something already lies (the casino's piles);
## `distances` are tried in order (a body coming in beside one tries those clear of it first).
func at_feet(location: WorldLocationState, origin: Vector2, apart: bool = false, distances: Array[int] = [28, 44, 64, 96]) -> Vector2:
	for distance: int in distances:
		for direction: Vector2 in [Vector2.DOWN, Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			var spot: Vector2 = origin + direction.normalized() * distance
			if apart and item_views.values().any(func(view: WorldFloorItemView) -> bool: return view.global_position.distance_to(spot) < 16.0):
				continue
			if MapPlacementValidator.is_valid_character_position(_map, location.zone_id, spot):
				return spot.round()
	push_warning("no free spot near %s in %s to drop on" % [origin, location.zone_id])
	return origin


## bamboo_pipe.c do_play(): the player plays a carried item; the room's trap
## listening for its sound hears it (environment()->pipe_notify()).
func play_item(item_id: StringName) -> bool:
	if _player == null or not _map.can_act(false):
		return false
	var item: ItemInstance = _item_index.resolve(item_id)
	var content: ItemContentDefinition = null if item == null else GameContent.catalog().item(item.item_definition_id)
	var carried: ContainmentEndpoint = ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, _player.character_id)
	if content == null or content.play.is_empty() or not _inventory.is_descendant_of(item_id, carried):
		return false
	# TRANSLATORS: bamboo_pipe.c: "$N拿起一根" + name() + "呜嘟嘟地吹了起来。" (竹管).
	_map.hud().append_log_lines([tr("你拿起一根%s呜嘟嘟地吹了起来。") % tr(content.display_name)])
	if session != null:
		session.room_traps().hear(content.play, _player.world_location().zone_id)
	return true


## rope.c hang_self(): environment(this_player())->query("outdoors") refuses.
func can_hang_here() -> bool:
	return _player != null and not zone_outdoors(_player.world_location().zone_id)


## Whether a zone counts as under the open sky for rope.c: any of its rooms set("outdoors").
## A zone that merges rooms which disagree (the pine's canopy: tree1 and tree2 inside its
## boughs, tree3 at the open top) does not know which one the player stands in, so a deadly
## hang is refused in all of it rather than allowed where rope.c would refuse it.
static func zone_outdoors(zone_id: StringName) -> bool:
	var zone: ZoneDefinition = GameContent.catalog().zone(zone_id)
	if zone == null:
		return true
	for room_id: StringName in zone.room_ids():
		var room: RoomDefinition = GameContent.catalog().room(room_id)
		if room == null or room.outdoors:
			return true
	return false


## rope.c hang_self() with the carried rope: under the open sky the rope finds nothing
## to hang from; indoors the player's line, then die(). Nobody hurt the player: an old
## last_damage_from is not a killer here (DECISIONS 青石村 A).
func hang_with(item_id: StringName) -> bool:
	if _player == null or not _map.can_act(false):
		return false
	var item: ItemInstance = _item_index.resolve(item_id)
	var content: ItemContentDefinition = null if item == null else GameContent.catalog().item(item.item_definition_id)
	var carried: ContainmentEndpoint = ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, _player.character_id)
	if content == null or not content.hang or not _inventory.is_descendant_of(item_id, carried):
		return false
	if not can_hang_here():
		_map.hud().append_log_lines([tr("你四处看看, 实在找不到地方挂绳子说...")])
		return false
	_map.hud().close_inventory()
	_map.hud().append_log_lines([tr("你把绳子一端挂好, 另一端往脖子上一套.....")])
	_player.relationship.clear_last_damage_from()
	_player.state.vitality.apply_wound(_player.state.vitality.effective + 1)
	_map.combat_lifecycle.player_fall_below_zero()
	return true


## The item of `item_definition_id` lying in `zone_id` (present(id, room)), or empty.
func floor_item_of(item_definition_id: StringName, zone_id: StringName) -> StringName:
	var location: WorldLocationState = _map.location_for_zone(zone_id)
	if location == null:
		return &""
	for item_id: StringName in item_views:
		var item: ItemInstance = _item_index.resolve(item_id)
		if item != null and item.item_definition_id == item_definition_id and _inventory.is_direct_child(item_id, floor_endpoint(location)):
			return item_id
	return &""


## destruct() of something on the floor (cave5.c moves the buried skeleton to
## /obj/void); a spawn's item comes back with its room's reset.
func destroy_floor_item(item_id: StringName) -> bool:
	if not item_views.has(item_id):
		return false
	var removal: ItemLifecycleResult = ItemLifecycleService.destroy_item(_inventory, _stacks, item_id, ItemLifecycleResult.ChildDisposition.REQUIRE_LEAF)
	if not (
		removal.succeeded
		and _foods.forget_removed(removal.removed_instance_ids, _inventory)
		and _liquids.forget_removed(removal.removed_instance_ids, _inventory)
		and _item_index.forget_destroyed_snapshots(removal.removed_instance_ids, _inventory)
	):
		return false
	if _map.selection.selected_target != null and _map.selection.selected_target.kind == WorldInteractionTarget.Kind.ITEM and _map.selection.selected_target.target_id == item_id:
		_map.selection.selected_target = null
		_map.hud().set_selected_target(null)
	_forget_floor_item(item_id)
	return true


## new(item)->move(room): a new item lying at the player's feet in their zone
## (cave5.c's book falling from the roof); kept in the save as a dropped one.
func place_new_floor_item(item_definition_id: StringName) -> StringName:
	var content: ItemContentDefinition = GameContent.catalog().item(item_definition_id)
	var location: WorldLocationState = null if _player == null else _player.world_location()
	if content == null or location == null or location.map_id != map:
		return &""
	var allocation: SessionItemIdAllocationResult = _item_id_allocator.allocate(_inventory)
	if not allocation.succeeded:
		return &""
	var item: ItemInstance = ItemInstance.new(allocation.item_instance_id, content.item_definition_id)
	if (
		not _inventory.register_item(item, 0 if content.is_stack else content.own_weight)
		or not _item_index.register_snapshot(item)
		or not ItemRoleStates.register_fresh(content, item.item_instance_id, _foods, _liquids)
	):
		return &""
	# combined.c: a new one comes with create()'s set_amount() (蒙汗药: one 包).
	if content.is_stack and not CombinedStackService.register_stack(_stacks, _inventory, item, content.stack_definition(), content.default_amount).accepted:
		return &""
	var placed: InventoryTransferResult = InventoryTransferService.new().transfer(
		_inventory,
		item.item_instance_id,
		InventoryTransferDestination.new(floor_endpoint(location), true, true, _map.WORLD_CAPACITY),
	)
	if not placed.succeeded or not add_dropped_item_view(item.item_instance_id, location, at_feet(location, player_body.global_position)):
		return &""
	return item.item_instance_id


## new(item)->move(me): a new item in the player's hands (water.c's 追风剑); when
## they cannot carry it, it lies at their feet. A combined item merges into the
## player's own stack (combined.c). Empty when nothing was made.
func give_new_item_to_player(item_definition_id: StringName) -> StringName:
	var item_id: StringName = place_new_floor_item(item_definition_id)
	if item_id.is_empty():
		return &""
	var carried := ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, _player.character_id)
	var destination := InventoryTransferDestination.new(carried, true, true, _player.maximum_encumbrance)
	if _stacks.has_stack(item_id):
		var owner := ItemLifecycleOwnerContext.new(_player.character_id, _player.state.equipment, _player.armor)
		var merged: CombinedStackMergeResult = CombinedStackService.transfer_and_merge(_stacks, _inventory, item_id, destination, null, null, owner)
		if merged.inventory_transfer != null and merged.inventory_transfer.succeeded:
			_forget_floor_item(item_id)
			_item_index.forget_destroyed_snapshots(merged.absorbed_instance_ids, _inventory)
		return item_id
	var taken: InventoryTransferResult = InventoryTransferService.new().transfer(_inventory, item_id, destination)
	if taken.succeeded:
		_forget_floor_item(item_id)
	return item_id


## How many times a `look_spawn` landmark called something in since its room's reset
## (house3.c num_of_spider). Not saved, as doors are not.
func landmark_uses(landmark_id: StringName) -> int:
	return landmark_use_counts.get(landmark_id, 0)


func count_landmark_use(landmark_id: StringName) -> void:
	landmark_use_counts[landmark_id] = landmark_uses(landmark_id) + 1


## Items dropped on this map's floor (not on a spawn marker), for the save.
func dropped_item_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	result.assign(_dropped.keys())
	return result


func dropped_item_location(item_id: StringName) -> WorldLocationState:
	var location: WorldLocationState = _dropped.get(item_id)
	return null if location == null else location.duplicate_snapshot()


func _forget_floor_item(item_id: StringName) -> void:
	var view: WorldFloorItemView = item_views.get(item_id)
	item_views.erase(item_id)
	_dropped.erase(item_id)
	if view != null:
		view.queue_free()


static func floor_endpoint(location: WorldLocationState) -> ContainmentEndpoint:
	return ContainmentEndpoint.new(ContainmentEndpoint.Kind.WORLD, location.combat_location_id)


## Item IDs lying on this map's floor, in spawn order.
func floor_item_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	result.assign(item_views.keys())
	return result


func floor_item_view(item_id: StringName) -> WorldFloorItemView:
	return item_views.get(item_id)


func selected_floor_item() -> WorldFloorItemView:
	if _map.selection.selected_target == null or _map.selection.selected_target.kind != WorldInteractionTarget.Kind.ITEM:
		return null
	return item_views.get(_map.selection.selected_target.target_id)


func floor_item_content(view: WorldFloorItemView) -> ItemContentDefinition:
	var item: ItemInstance = null if view == null else _item_index.resolve(view.item_instance_id)
	return null if item == null else GameContent.catalog().item(item.item_definition_id)


## look.c sees what lies in the player's own room.
func floor_item_in_player_zone(view: WorldFloorItemView) -> bool:
	var location: WorldLocationState = null if _player == null else _player.world_location()
	return view != null and location != null and _inventory.is_direct_child(view.item_instance_id, floor_endpoint(location))


func refresh_selected_floor_item() -> void:
	var view: WorldFloorItemView = selected_floor_item()
	if view != null:
		_map.hud().set_selected_floor_item(view.display_name, view.is_body_in_reach(player_body), false)


func select_floor_item(item_id: StringName) -> bool:
	if not _map.gameplay_open() or session == null:
		return false
	var view: WorldFloorItemView = item_views.get(item_id)
	if view == null:
		return false
	_map.selection.selected_target = WorldInteractionTarget.item(item_id)
	_map.hud().set_selected_floor_item(view.display_name, view.is_body_in_reach(player_body))
	return true


## get.c on the selected floor item, with its lines in the log.
func take_selected_floor_item() -> FloorItemPickup.Outcome:
	var view: WorldFloorItemView = selected_floor_item() if _map.gameplay_open() and session != null else null
	var content: ItemContentDefinition = floor_item_content(view)
	var location: WorldLocationState = null if _player == null else _player.world_location()
	if view == null or content == null or location == null:
		return FloorItemPickup.Outcome.INVALID_REQUEST
	var taken: Array[int] = []
	var outcome: FloorItemPickup.Outcome = FloorItemPickup.take(
		_player, view.item_instance_id, floor_endpoint(location), view.is_body_in_reach(player_body), _inventory, _item_index, _stacks,
		_item_id_allocator, taken,
	)
	match outcome:
		FloorItemPickup.Outcome.TAKEN_PART:
			_map.hud().append_log_lines([
				tr("你捡起%s。") % HeldItemFacts.counted(content, taken[0]),
				tr("%s对你而言太重了。") % HeldItemFacts.short_name(view.item_instance_id, content, _stacks),
			])
			if _map.hud().inventory_is_open():
				_map.hud().show_inventory(session.player_inventory_rows())
		FloorItemPickup.Outcome.TAKEN:
			_forget_floor_item(view.item_instance_id)
			_map.selection.selected_target = null
			_map.hud().set_selected_target(null)
			_map.hud().append_log_lines([tr("你捡起%s。") % HeldItemFacts.one_unit(content)])
			if _map.hud().inventory_is_open():
				_map.hud().show_inventory(session.player_inventory_rows())
		FloorItemPickup.Outcome.BUSY:
			_map.hud().append_log_lines([tr("你上一个动作还没有完成！")])
		FloorItemPickup.Outcome.NOT_HERE:
			_map.hud().append_log_lines([tr("你附近没有这样东西。")])
		FloorItemPickup.Outcome.NO_GET:
			_map.hud().append_log_lines([tr("这个东西拿不起来。")])
		FloorItemPickup.Outcome.TOO_HEAVY:
			_map.hud().append_log_lines([tr("%s对你而言太重了。") % tr(content.display_name)])
	return outcome


## combined.c add_amount(-1) (a stack at 0 is destructed) or destruct() of a carried item.
func use_up_one(item_id: StringName, owner: ItemLifecycleOwnerContext) -> bool:
	if _stacks.has_stack(item_id) and _stacks.stack_state(item_id).amount > 1:
		return CombinedStackService.set_amount(_stacks, _inventory, item_id, _stacks.stack_state(item_id).amount - 1).accepted
	var removal: ItemLifecycleResult = ItemLifecycleService.destroy_item(_inventory, _stacks, item_id, ItemLifecycleResult.ChildDisposition.REQUIRE_LEAF, owner)
	return (
		removal.succeeded
		and _foods.forget_removed(removal.removed_instance_ids, _inventory)
		and _liquids.forget_removed(removal.removed_instance_ids, _inventory)
		and _item_index.forget_destroyed_snapshots(removal.removed_instance_ids, _inventory)
	)


## apply <item>: the item's own do_apply() (ItemApplyFunctions), on the player.
func apply_item(item_id: StringName) -> bool:
	if not can_handle_items():
		return false
	var item: ItemInstance = _item_index.resolve(item_id)
	var content: ItemContentDefinition = null if item == null else GameContent.catalog().item(item.item_definition_id)
	var carried := ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, _player.character_id)
	if content == null or content.apply.is_empty() or not _inventory.is_direct_child(item_id, carried):
		return false
	var result: ItemApplyFunctions.Result = ItemApplyFunctions.apply(content.apply, _player.state, _player.relationship.is_fighting())
	_map.hud().append_log_lines(result.lines)
	if result.used_up and not use_up_one(item_id, ItemLifecycleOwnerContext.new(_player.character_id, _player.state.equipment, _player.armor)):
		push_error("using up %s failed: the item state is inconsistent" % item_id)
	if _map.hud().inventory_is_open():
		_map.hud().show_inventory(session.player_inventory_rows())
	return result.accepted


## A carried item's own command (bracelet.c pray, book.c dancing home, letter.c fire):
## the branch for the player, asked first as a room's command is (ActService). False
## when the item has none or cannot be used now.
func act_with_item(item_id: StringName) -> bool:
	if not can_handle_items():
		return false
	var item: ItemInstance = _item_index.resolve(item_id)
	var content: ItemContentDefinition = null if item == null else GameContent.catalog().item(item.item_definition_id)
	var carried := ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, _player.character_id)
	if content == null or content.act == null or not _inventory.is_direct_child(item_id, carried):
		return false
	var act: ScriptedAct = content.act.act_for(_player.state.gender, _player.state.affiliation.class_id, _map.acts.facts())
	if act == null:
		return false
	var still_carried: Callable = func() -> bool: return can_handle_items() and _inventory.is_direct_child(item_id, carried)
	ActService.ask_first_or_run(_map, act, tr(content.act.verb), _run_item_act.bind(act, still_carried), still_carried)
	return true


func _run_item_act(act: ScriptedAct, still_carried: Callable) -> void:
	if not still_carried.call():
		return
	if act.moves_player():
		_map.hud().close_inventory()
	_map.acts.run(act, null, _world_interaction_random.legacy_random)


## The containers a powder can be poured into: the liquid containers the player
## carries directly (do_pour()'s present(what, this_player())), in carried order.
func pour_targets() -> Array[StringName]:
	var targets: Array[StringName] = []
	if _player == null:
		return targets
	var carried := ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, _player.character_id)
	for id: StringName in _inventory.direct_children(carried):
		if _liquids.state(id) != null:
			targets.append(id)
	return targets


## pour <powder> in <container> (std/medicine/powder.c, obj/toy/poison_dust.c
## do_pour()): an empty container refuses; else the drink now carries the powder's
## effect (LiquidDrinkEffects) and one of the powder is used up. Both are carried.
func pour_into(powder_id: StringName, container_id: StringName) -> bool:
	if not can_handle_items():
		return false
	var item: ItemInstance = _item_index.resolve(powder_id)
	var powder: ItemContentDefinition = null if item == null else GameContent.catalog().item(item.item_definition_id)
	var carried := ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, _player.character_id)
	if powder == null or powder.pour == null or not _inventory.is_direct_child(powder_id, carried) or not pour_targets().has(container_id):
		return false
	var liquid: LiquidState = _liquids.state(container_id)
	var vessel: String = _map.combat_lifecycle.item_name(container_id)
	if liquid.remaining <= 0:
		_map.hud().append_log_lines([tr("{container}里什麽也没有，先装些水酒才能溶化药粉。").format({"container": vessel})])
		return false
	LiquidDrinkEffects.pour(liquid, powder)
	_map.hud().append_log_lines([tr("你将一些{powder}倒进{container}，摇晃了几下。").format({"powder": tr(powder.display_name), "container": vessel})])
	if not use_up_one(powder_id, ItemLifecycleOwnerContext.new(_player.character_id, _player.state.equipment, _player.armor)):
		push_error("using up %s failed: the item state is inconsistent" % powder_id)
	if _map.hud().inventory_is_open():
		_map.hud().show_inventory(session.player_inventory_rows())
	return true


## A new item the player could not carry lies at their feet (give_new_item_to_player()):
## the line that says so, in its place among the giver's lines (deviation: in ES2 the
## giver kept it, as give.c's move() failed); "" when it is in their hands.
func at_feet_line(item_id: StringName, content: ItemContentDefinition) -> String:
	if _inventory.is_direct_child(item_id, ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, _player.character_id)):
		return ""
	return tr(ItemHandlingService.WINNINGS_AT_FEET).format({"item": HeldItemFacts.one_unit(content)})


## F_UNIQUE violate_unique(): the item is unique and one already exists somewhere in
## the world (carried, lying about, held by an NPC, in a corpse or the pawnshop).
func violates_unique(item_definition_id: StringName) -> bool:
	var content: ItemContentDefinition = GameContent.catalog().item(item_definition_id)
	if content == null or not content.unique:
		return false
	for id: StringName in _item_index.snapshot_ids():
		var item: ItemInstance = _item_index.resolve(id)
		if item != null and item.item_definition_id == item_definition_id and _inventory.is_registered(id):
			return true
	return false


func item_authorities() -> ItemHandlingService.Authorities:
	var owner := ItemLifecycleOwnerContext.new(_player.character_id, _player.state.equipment, _player.armor)
	return ItemHandlingService.Authorities.new(
		MoneyInventoryContext.new(owner, _inventory, _stacks, _item_index), _foods, _liquids, _item_id_allocator,
	)


## give.c, drop.c and put.c are typed by an active player outside a fight.
func can_handle_items() -> bool:
	return _map.gameplay_open() and session != null and _player != null and _map.can_act(false)


## The selected NPC can be given things: present() and living(who).
func selected_npc_takes_gifts() -> bool:
	var npc: NpcRuntimeState = _map.selection.selected_npc()
	return (
		npc != null and npc.exists_in_map and npc.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE
		and npc.world_location().shares_combat_location(_player.world_location())
	)


## give <item> to <selected npc>; `amount` 0 gives the whole object.
func give_to_selected(item_id: StringName, amount: int = 0) -> ItemHandlingResult:
	var npc: NpcRuntimeState = _map.selection.selected_npc()
	if not can_handle_items() or npc == null:
		return ItemHandlingResult.new()
	var location: WorldLocationState = _player.world_location()
	var result: ItemHandlingResult = ItemHandlingService.give(
		_player, npc, selected_npc_takes_gifts(), item_id, amount, item_authorities(), _world_interaction_random, floor_endpoint(location),
	)
	for dropped: StringName in result.dropped_item_ids:
		if not add_dropped_item_view(dropped, location, at_feet(location, player_body.global_position, true)):
			push_error("winnings %s on the floor have no view" % dropped)
	var attacks: bool = result.rule != null and result.rule.kill and not npc.relationship.is_fighting()
	# shaowei.c accept_object(): call_out("make_stage", 2, who, 0).
	if result.done() and result.rule != null and result.rule.make != null:
		_map.npc_life.start_making(npc, result.rule.make)
	# shen.c accept_object(): drug->move(this_player()), told by the rule's own line.
	if result.done() and result.rule != null and not result.rule.gives.is_empty():
		var gift: StringName = give_new_item_to_player(result.rule.gives)
		var gift_content: ItemContentDefinition = GameContent.catalog().item(result.rule.gives)
		var at_feet: String = "" if gift.is_empty() or gift_content == null else at_feet_line(gift, gift_content)
		if not at_feet.is_empty():
			result.lines.append(at_feet)
	if not attacks:
		_report_item_handling(result)
		return result
	# gangster.c accept_object(): too little, and kill_passenger() kill_ob()s the giver,
	# this one NPC, wherever in the room the player stands. Its say() and kill_ob()'s
	# warning come first; the refusal (X没有收下。) prints last.
	var refusal: String = result.lines.pop_back()
	_report_item_handling(result)
	var participants: Array[CombatSliceCharacterBinding] = _map.combat_lifecycle.build_participants()
	var started: CombatSliceInitiationResult = session.combat_encounter_coordinator().start_production(
		CombatSliceProjectionBuilder.find_binding(participants, npc.character_id),
		CombatSliceProjectionBuilder.find_binding(participants, _player.character_id),
		CombatTriggerCause.Value.NPC_AGGRESSION,
	)
	if started.outcome == CombatSliceInitiationResult.Outcome.COMPLETED:
		_map.hostilities.announce_fight([])
	_map.hud().append_log_lines([refusal])
	return result


## drop <item>: it lies at the player's feet.
func drop_item(item_id: StringName, amount: int = 0) -> ItemHandlingResult:
	if not can_handle_items():
		return ItemHandlingResult.new()
	var location: WorldLocationState = _player.world_location()
	var result: ItemHandlingResult = ItemHandlingService.drop(_player, item_id, amount, floor_endpoint(location), item_authorities())
	if result.done() and not result.destroyed and not add_dropped_item_view(result.item_id, location, at_feet(location, player_body.global_position)):
		push_error("dropped %s has no view" % result.item_id)
	_report_item_handling(result)
	return result


## A container lying in the player's place within reach (feature/move.c
## max_encumbrance), the selected one first; empty when none is.
func container_in_reach() -> StringName:
	var selected: WorldFloorItemView = selected_floor_item()
	if selected != null and is_container(selected.item_instance_id) and floor_item_in_player_zone(selected) and selected.is_body_in_reach(player_body):
		return selected.item_instance_id
	for item_id: StringName in item_views:
		var view: WorldFloorItemView = item_views[item_id]
		if is_container(item_id) and floor_item_in_player_zone(view) and view.is_body_in_reach(player_body):
			return item_id
	return &""


## put <item> in <container in reach>.
func put_in_container(item_id: StringName, amount: int = 0) -> ItemHandlingResult:
	var container_id: StringName = container_in_reach()
	if not can_handle_items() or container_id.is_empty():
		return ItemHandlingResult.new()
	var result: ItemHandlingResult = ItemHandlingService.put(_player, item_id, amount, container_id, item_authorities())
	_report_item_handling(result)
	if result.done() and _map.hud().loot_is_open():
		show_container(item_views[container_id])
	return result


## get <item> from <selected container>.
func take_from_selected_container(item_id: StringName) -> ItemHandlingResult:
	var view: WorldFloorItemView = selected_floor_item()
	if not can_handle_items() or view == null or not is_container(view.item_instance_id) or not floor_item_in_player_zone(view) or not view.is_body_in_reach(player_body):
		return ItemHandlingResult.new()
	var result: ItemHandlingResult = ItemHandlingService.take_from(_player, view.item_instance_id, item_id, item_authorities())
	_report_item_handling(result)
	show_container(view)
	return result


func is_container(item_id: StringName) -> bool:
	var item: ItemInstance = _item_index.resolve(item_id)
	var content: ItemContentDefinition = null if item == null else GameContent.catalog().item(item.item_definition_id)
	return content != null and content.max_encumbrance > 0


## The container's contents as loot rows; get.c takes them one by one.
func show_container(view: WorldFloorItemView) -> bool:
	if not floor_item_in_player_zone(view) or not view.is_body_in_reach(player_body):
		_map.hud().close_loot()
		return false
	var rows: Array[WorldItemRowProjection] = []
	for item_id: StringName in _inventory.direct_children(ContainmentEndpoint.new(ContainmentEndpoint.Kind.ITEM, view.item_instance_id)):
		var item: ItemInstance = _item_index.resolve(item_id)
		var content: ItemContentDefinition = null if item == null else GameContent.catalog().item(item.item_definition_id)
		if content == null:
			continue
		var amount: int = _stacks.stack_state(item_id).amount if _stacks.has_stack(item_id) else 1
		rows.append(WorldItemRowProjection.new(item_id, item.item_definition_id, content.display_name, content.shown_description(), amount, content.category, true, false, false))
	_map.hud().show_loot(tr(view.display_name), rows)
	return true


func _report_item_handling(result: ItemHandlingResult) -> void:
	if result.outcome == ItemHandlingResult.Outcome.AUTHORITY_FAILURE:
		push_error("item handling failed: the item state is inconsistent")
	if not result.lines.is_empty():
		_map.hud().append_colored_lines(result.colored_lines())
	if _map.hud().inventory_is_open():
		_map.hud().show_inventory(session.player_inventory_rows())
