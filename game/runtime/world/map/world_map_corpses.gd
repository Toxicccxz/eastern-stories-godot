class_name WorldMapCorpses
extends RefCounted
## The map's corpses: their views and places, the selected corpse's loot panel,
## 化尸粉 (dust.c) on one, and killed_enemy()'s dissolve call_outs. Code moved from
## WorldMapController as it was; the map is `_map`.

var _map: WorldMapController
var _corpse_states: Array[CorpseState] = []
var _corpse_views: Dictionary[StringName, CombatSliceCorpseView] = {}
var _corpse_locations: Dictionary[StringName, WorldLocationState] = {}
## killed_enemy()'s call_out("dissolve", 1), one per kill: [NPC id, ms of world time
## left] (transient).
var _pending_dissolves: Array[Array] = []
var _loot: CorpseLootAdapter = CorpseLootAdapter.new()
var _last_loot_transfer_result: CorpseLootTransferResult

# The map's authorities, read as the controller reads them.
var session: OldPineWorldSessionController:
	get: return _map.session
var player_body: WorldCharacterBody2D:
	get: return _map.player_body
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


func _init(map: WorldMapController) -> void:
	_map = map


## combatd.c killer_reward(): the killer's killed_enemy() (spy.c: say, then
## call_out("dissolve", 1)). A dying player still hears it (`heard`): die() revives
## the body first and moves the ghost away only after killer_reward().
func killed_enemy(killer: NpcRuntimeState, heard: bool) -> void:
	var hook: NpcKilledEnemy = null if killer == null else killer.definition().killed_enemy()
	if hook == null:
		return
	if not hook.say.is_empty() and heard:
		_map.hud().append_log_lines([NpcLine.new(false, hook.say).sentence(killer.definition().display_name, "")])
	if hook.dissolve_after_ms > 0:
		_pending_dissolves.append([killer.character_id, float(hook.dissolve_after_ms)])


func advance_pending_dissolves(delta: float) -> void:
	var due: Array[StringName] = []
	for index: int in range(_pending_dissolves.size() - 1, -1, -1):
		_pending_dissolves[index][1] -= delta * 1000.0
		if _pending_dissolves[index][1] <= 0.0:
			due.push_front(_pending_dissolves[index][0])
			_pending_dissolves.remove_at(index)
	for character_id: StringName in due:
		_npc_dissolves_corpse(_map.npcs.find_resident_npc(character_id))


## command("dissolve corpse"): obj/dust.c's add_action works only while the NPC carries
## 化尸粉 and stands (living()); present("corpse") finds the corpse that came into its
## room last.
func _npc_dissolves_corpse(npc: NpcRuntimeState) -> void:
	if npc == null or not npc.exists_in_map or npc.life_status != CharacterRuntimeLifeStatus.Value.ACTIVE:
		return
	var dust: StringName = _carried_dissolver(ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, npc.character_id))
	var corpse: CorpseState = _newest_corpse_in(npc.world_location())
	if dust.is_empty() or corpse == null:
		return
	var heard: bool = _map.npc_life.player_hears(npc)
	var victim_name: String = corpse.victim_display_name
	var owner := ItemLifecycleOwnerContext.new(npc.character_id, npc.character_state.equipment, npc.armor)
	if not _dissolve_corpse(corpse, dust, owner):
		push_error("dissolving %s failed: the item state is inconsistent" % corpse.corpse_item_instance_id)
		return
	if heard:
		_map.hud().append_log_lines([_dissolve_line(tr(npc.definition().display_name), victim_name)])


## dissolve <corpse> by the player with the 化尸粉 `dust_id` they carry, on the selected
## corpse lying in their place (present(arg, environment(me))).
func dissolve_selected_corpse(dust_id: StringName) -> bool:
	if not _map.floor_items.can_handle_items():
		return false
	var carried := ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, _player.character_id)
	var item: ItemInstance = _item_index.resolve(dust_id)
	var content: ItemContentDefinition = null if item == null else GameContent.catalog().item(item.item_definition_id)
	if content == null or not content.dissolves or not _inventory.is_direct_child(dust_id, carried):
		return false
	var corpse: CorpseState = _selected_corpse()
	if corpse == null or not corpse_is_live_in_world(corpse) or not _corpse_in_location(corpse, _player.world_location()):
		_map.hud().append_log_lines([tr("这里没有这样东西。")])
		return false
	var victim_name: String = corpse.victim_display_name
	var owner := ItemLifecycleOwnerContext.new(_player.character_id, _player.state.equipment, _player.armor)
	if not _dissolve_corpse(corpse, dust_id, owner):
		push_error("dissolving %s failed: the item state is inconsistent" % corpse.corpse_item_instance_id)
		return false
	_map.hud().append_log_lines([_dissolve_line(tr("你"), victim_name)])
	if _map.hud().inventory_is_open():
		_map.hud().show_inventory(session.player_inventory_rows())
	return true


## The selected corpse's name when it lies in the player's place, else "" (what the
## 化尸粉 row offers to dissolve).
func dissolvable_corpse_name() -> String:
	var corpse: CorpseState = _selected_corpse()
	if _player == null or corpse == null or not corpse_is_live_in_world(corpse) or not _corpse_in_location(corpse, _player.world_location()):
		return ""
	return corpse.victim_display_name


## How many things lie in the corpse 化尸粉 would dissolve (dust.c destructs it whole).
func dissolvable_corpse_contents() -> int:
	return 0 if dissolvable_corpse_name().is_empty() else corpse_content_count(_selected_corpse())


## The 化尸粉 a character carries directly (present(), first found), or empty.
func _carried_dissolver(holder: ContainmentEndpoint) -> StringName:
	for item_id: StringName in _inventory.direct_children(holder):
		var item: ItemInstance = _item_index.resolve(item_id)
		var content: ItemContentDefinition = null if item == null else GameContent.catalog().item(item.item_definition_id)
		if content != null and content.dissolves:
			return item_id
	return &""


## The corpse made last among those lying in `location`'s room.
func _newest_corpse_in(location: WorldLocationState) -> CorpseState:
	for index: int in range(_corpse_states.size() - 1, -1, -1):
		var corpse: CorpseState = _corpse_states[index]
		if corpse_is_live_in_world(corpse) and _corpse_in_location(corpse, location):
			return corpse
	return null


func _corpse_in_location(corpse: CorpseState, location: WorldLocationState) -> bool:
	var at: WorldLocationState = _corpse_locations.get(corpse.corpse_item_instance_id)
	return at != null and location != null and at.shares_combat_location(location)


## obj/dust.c: $N用指甲挑了一点化尸粉在$n上……$n只剩下一滩黄水。
func _dissolve_line(who: String, victim_name: String) -> String:
	# TRANSLATORS: dust.c: {who} (你 or an NPC) dissolves a corpse ({corpse}, e.g. 狼狗的尸体) with 化尸粉.
	return tr("{who}用指甲挑了一点化尸粉在{corpse}上，只听见一阵「嗤嗤」声响带著一股可怕的恶臭，{corpse}只剩下一滩黄水。").format({
		"who": who, "corpse": tr("%s的尸体") % tr(victim_name),
	})


## destruct(corpse) with all it holds, then add_amount(-1) on the 化尸粉.
func _dissolve_corpse(corpse: CorpseState, dust_id: StringName, dust_owner: ItemLifecycleOwnerContext) -> bool:
	var corpse_id: StringName = corpse.corpse_item_instance_id
	var removal: ItemLifecycleResult = ItemLifecycleService.destroy_item(_inventory, _stacks, corpse_id, ItemLifecycleResult.ChildDisposition.DESTROY_SUBTREE)
	if not (
		removal.succeeded
		and _foods.forget_removed(removal.removed_instance_ids, _inventory)
		and _liquids.forget_removed(removal.removed_instance_ids, _inventory)
		and _item_index.forget_destroyed_snapshots(removal.removed_instance_ids, _inventory)
	):
		return false
	_corpse_states.erase(corpse)
	_corpse_locations.erase(corpse_id)
	var view: CombatSliceCorpseView = _corpse_views.get(corpse_id)
	_corpse_views.erase(corpse_id)
	if view != null:
		view.queue_free()
	if _map.selection.selected_target != null and _map.selection.selected_target.kind == WorldInteractionTarget.Kind.ITEM and _map.selection.selected_target.target_id == corpse_id:
		_map.selection.selected_target = null
		_map.hud().set_selected_corpse("", 0, false, true)
		if _map.hud().loot_is_open():
			_map.hud().close_loot()
	return _map.floor_items.use_up_one(dust_id, dust_owner)


## A corpse lies where its body fell. It is wider than the body, so beside a wall it is
## shifted (sideways first, at most 40 px, same zone) until it fits; Continue validates it.
func corpse_position(death_position: Vector2, death_location: WorldLocationState) -> Vector2:
	if death_location == null or MapPlacementValidator.is_valid_corpse_position(_map, death_location.zone_id, death_position):
		return death_position
	for distance: int in range(8, 41, 8):
		for offset: Vector2 in [Vector2(distance, 0), Vector2(-distance, 0), Vector2(0, distance), Vector2(0, -distance)]:
			if MapPlacementValidator.is_valid_corpse_position(_map, death_location.zone_id, death_position + offset):
				return death_position + offset
	return death_position


## A restored corpse is already indexed and interactive.
func publish_corpse_view(corpse: CorpseState, position: Vector2, location: WorldLocationState) -> bool:
	var view: CombatSliceCorpseView = add_corpse_view(corpse, position, location)
	if view == null:
		return false
	make_corpse_interactive(view)
	return true


func add_corpse_view(corpse: CorpseState, position: Vector2, location: WorldLocationState) -> CombatSliceCorpseView:
	_corpse_states.append(corpse)
	if location != null:
		_corpse_locations[corpse.corpse_item_instance_id] = location.duplicate_snapshot()
	var view: CombatSliceCorpseView = CombatSliceCorpseView.new()
	if not view.configure(corpse):
		view.free()
		return null
	view.global_position = position
	_corpse_layer().add_child(view)
	return view


func make_corpse_interactive(view: CombatSliceCorpseView) -> void:
	_corpse_views[view.corpse_item_instance_id] = view
	view.selection_requested.connect(select_corpse)
	view.loot_range_changed.connect(_on_corpse_loot_range_changed)


func _corpse_layer() -> Node2D:
	var layer: Node2D = _map.get_node_or_null("CorpseLayer") as Node2D
	if layer == null:
		layer = Node2D.new()
		layer.name = "CorpseLayer"
		_map.add_child(layer)
	return layer


func corpse_states() -> Array[CorpseState]:
	return _corpse_states.duplicate()


func corpse_view_for(corpse_id: StringName) -> CombatSliceCorpseView:
	return _corpse_views.get(corpse_id)


func corpse_world_location(corpse_id: StringName) -> WorldLocationState:
	var location: WorldLocationState = _corpse_locations.get(corpse_id)
	return null if location == null else location.duplicate_snapshot()


func last_loot_transfer_result() -> CorpseLootTransferResult:
	return _last_loot_transfer_result


func find_corpse(corpse_id: StringName) -> CorpseState:
	for corpse: CorpseState in _corpse_states:
		if corpse.corpse_item_instance_id == corpse_id:
			return corpse
	return null


func _selected_corpse() -> CorpseState:
	if _map.selection.selected_target == null or _map.selection.selected_target.kind != WorldInteractionTarget.Kind.ITEM:
		return null
	return find_corpse(_map.selection.selected_target.target_id)


func corpse_is_live_in_world(corpse: CorpseState) -> bool:
	if (
		corpse == null
		or not _inventory.is_registered(corpse.corpse_item_instance_id)
		or not _item_index.has_snapshot(corpse.corpse_item_instance_id)
		or not _corpse_views.has(corpse.corpse_item_instance_id)
	):
		return false
	var parent: ContainmentEndpoint = _inventory.direct_parent(corpse.corpse_item_instance_id)
	return parent != null and parent.kind == ContainmentEndpoint.Kind.WORLD


func corpse_content_count(corpse: CorpseState) -> int:
	if corpse == null:
		return 0
	return _inventory.direct_children(ContainmentEndpoint.new(ContainmentEndpoint.Kind.ITEM, corpse.corpse_item_instance_id)).size()


func _player_is_in_corpse_loot_range(corpse_id: StringName) -> bool:
	var view: CombatSliceCorpseView = _corpse_views.get(corpse_id)
	return view != null and view.is_body_in_loot_range(player_body)


func refresh_selected_corpse() -> void:
	var corpse: CorpseState = _selected_corpse()
	if corpse == null or not corpse_is_live_in_world(corpse):
		if _map.selection.selected_target != null and _map.selection.selected_target.kind == WorldInteractionTarget.Kind.ITEM:
			_map.selection.selected_target = null
		_map.hud().set_selected_corpse("", 0, false, true)
		return
	_map.hud().set_selected_corpse(corpse.victim_display_name, corpse_content_count(corpse), _player_is_in_corpse_loot_range(corpse.corpse_item_instance_id), false)


func _on_corpse_loot_range_changed(corpse_id: StringName, body: Node2D, _is_inside: bool) -> void:
	if _map.gameplay_open() and body == player_body and _map.selection.selected_target != null and _map.selection.selected_target.kind == WorldInteractionTarget.Kind.ITEM and _map.selection.selected_target.target_id == corpse_id:
		refresh_selected_corpse()


func _refresh_loot_panel(corpse: CorpseState) -> void:
	_map.hud().show_loot(tr("%s的尸体") % tr(corpse.victim_display_name), _loot.project_rows(corpse, _inventory, _stacks, _item_index))


func select_corpse(corpse_id: StringName) -> bool:
	if not _map.gameplay_open() or session == null:
		return false
	var corpse: CorpseState = find_corpse(corpse_id)
	if corpse == null or not corpse_is_live_in_world(corpse):
		return false
	_map.selection.selected_target = WorldInteractionTarget.item(corpse_id)
	_map.hud().set_selected_corpse(corpse.victim_display_name, corpse_content_count(corpse), _player_is_in_corpse_loot_range(corpse_id))
	return true


func open_selected_loot() -> bool:
	if not _map.gameplay_open() or session == null:
		return false
	_map.hud().close_inventory()
	var floor_view: WorldFloorItemView = _map.floor_items.selected_floor_item()
	if floor_view != null and _map.floor_items.is_container(floor_view.item_instance_id):
		return _map.floor_items.show_container(floor_view)
	if floor_view != null:
		_map.hud().close_loot()
		return _map.floor_items.take_selected_floor_item() in [FloorItemPickup.Outcome.TAKEN, FloorItemPickup.Outcome.TAKEN_PART]
	var corpse: CorpseState = _selected_corpse()
	if corpse == null:
		_map.hud().close_loot()
		return false
	var validation: int = _loot.validate_open(_player, corpse, _inventory, _item_index, _player_is_in_corpse_loot_range(corpse.corpse_item_instance_id))
	if validation != CorpseLootAdapter.OpenValidation.READY:
		_map.hud().close_loot()
		refresh_selected_corpse()
		return false
	_refresh_loot_panel(corpse)
	return true


func take_selected_loot_item(item_instance_id: StringName) -> CorpseLootTransferResult:
	var floor_view: WorldFloorItemView = _map.floor_items.selected_floor_item() if _map.gameplay_open() and session != null else null
	if floor_view != null and _map.floor_items.is_container(floor_view.item_instance_id):
		_map.floor_items.take_from_selected_container(item_instance_id)
		return CorpseLootTransferResult.new(CorpseLootTransferResult.Outcome.INVALID_REQUEST, false, _player.character_id, &"", item_instance_id)
	if not _map.gameplay_open() or session == null:
		return CorpseLootTransferResult.new(CorpseLootTransferResult.Outcome.INVALID_REQUEST, false, &"" if _player == null else _player.character_id, &"", item_instance_id)
	var corpse: CorpseState = _selected_corpse()
	if corpse == null:
		_last_loot_transfer_result = CorpseLootTransferResult.new(CorpseLootTransferResult.Outcome.CORPSE_NOT_AVAILABLE, false, _player.character_id, &"", item_instance_id)
		_map.hud().close_loot()
		return _last_loot_transfer_result
	_last_loot_transfer_result = _loot.take(_player, corpse, item_instance_id, _player_is_in_corpse_loot_range(corpse.corpse_item_instance_id), _inventory, _stacks, _item_index)
	refresh_selected_corpse()
	if _map.hud().loot_is_open():
		if corpse_is_live_in_world(corpse):
			_refresh_loot_panel(corpse)
		else:
			_map.hud().close_loot()
	if _map.hud().inventory_is_open():
		_map.hud().show_inventory(session.player_inventory_rows())
	return _last_loot_transfer_result
