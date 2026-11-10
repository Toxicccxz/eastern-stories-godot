class_name WorldStoryPresence
extends RefCounted

## Native (主线 A, 剧情总纲 §8 第 3 步; DECISIONS「剧情演出」): who and what the story puts on
## a map now. A spawn with `present` / `until` (NpcSpawnDefinition, ItemSpawnDefinition) is on
## the stage while its `present` holds and its `until` does not; both are journal `when`s
## read against the player's state (a quest ledger key, a mark, a milestone). The stage is
## judged only when the player comes onto the map (a handoff, the first map, a Continue),
## never in front of them: an NPC on the stage and absent appears on its marker, one off the
## stage and standing leaves for good (as an act's `leave`: not made anew); a `phase` condition (关北 C:
## the 工地's night watch) is read the same way, by the clock as the player comes on; an item on the
## stage and never made lies down on its marker, one off the stage and still lying untouched
## on its marker is gone (one the player took and dropped is theirs, wherever it lies). What the player took, killed or was given stays as it is.
## Native (第八章 B; DECISIONS「舞台道具」): a thing of the map's picture may carry `present` / `until` too — a
## layout furnishing's look, a voxel config's prop (the farmhouse's charred roof, the burnt boats) — and
## is on or off the stage by the same rule (`look_on_stage()`; the scene's Furnishing nodes keep it as
## `staged_off`, the view shows and hides theirs). And as the day's phase turns on the player's own map
## (`phase_turn`), the spawns whose conditions read the phase are judged again where they stand (the
## 鬼卒 come up out of the lake as night falls), the things of the picture too; every other spawn waits
## for the player's next coming onto the map, as before.


static func stage(session: WorldSessionController, map: WorldMapController, phase_turn: bool = false) -> void:
	var player: WorldPlayerRuntimeState = session.player_runtime() as WorldPlayerRuntimeState
	if player == null or player.state == null or map == null or not map.is_map_initialized():
		return
	var catalog: ContentCatalog = GameContent.catalog()
	var held: Dictionary[StringName, bool] = session.player_held_item_ids()
	var worn: Dictionary[StringName, bool] = session.player_worn_item_ids()
	var phase_id: StringName = session.day_phase_id()
	for spawn: NpcSpawnDefinition in catalog.spawns_for_map(map.map_id()):
		if not spawn.staged or (phase_turn and not (_comes_round(spawn.present) or _comes_round(spawn.until))):
			continue
		var on: bool = on_stage(spawn.present, spawn.until, player, held, worn, phase_id)
		for point_id: StringName in spawn.spawn_point_ids():
			var npc: NpcRuntimeState = map.npcs.npc_at_point(point_id)
			if npc == null or npc.life_status == CharacterRuntimeLifeStatus.Value.DEAD or npc.has_flag(NpcDefinition.FLAG_GONE):
				continue
			if on and not npc.exists_in_map:
				map.npcs.appear(npc, spawn)
			elif not on and npc.exists_in_map:
				# A stage the day brings round again (a `phase` in its conditions, 关北 C: the 工地's
				# officers in their tents by night) only withdraws its people; any other is left for good.
				if _comes_round(spawn.present) or _comes_round(spawn.until):
					map.npcs.withdraw(npc)
				else:
					map.npcs.leave_for_good(npc)
	for spawn: ItemSpawnDefinition in catalog.item_spawns_for_map(map.map_id()):
		if not spawn.staged or (phase_turn and not (_comes_round(spawn.present) or _comes_round(spawn.until))):
			continue
		var on: bool = on_stage(spawn.present, spawn.until, player, held, worn, phase_id)
		for point_id: StringName in spawn.spawn_point_ids():
			var item_id: StringName = map.floor_items.spawn_item_id(point_id)
			var made: bool = map.inventory_state().is_registered(item_id)
			if on and not made:
				if not map.floor_items.place_floor_item(spawn, point_id):
					push_error("the story could not lay %s on %s" % [spawn.item_definition_id, point_id])
			# Only the untouched one on its marker goes; one the player took and dropped is theirs
			# (saved where they dropped it: the Save/Continue policy).
			elif not on and made and map.floor_items.item_views.has(item_id) and not map.floor_items.dropped_item_ids().has(item_id):
				map.floor_items.destroy_floor_item(item_id)
	stage_props(session, map)


## The things of the map's picture that carry `present` / `until` (DECISIONS「舞台道具」): each Furnishing
## node of the scene keeps whether it is off the stage (`staged_off`), and the voxel view, once built,
## shows and hides its staged props (restage()).
static func stage_props(session: WorldSessionController, map: WorldMapController) -> void:
	var player: WorldPlayerRuntimeState = session.player_runtime() as WorldPlayerRuntimeState
	if player == null or player.state == null or map == null:
		return
	var held: Dictionary[StringName, bool] = session.player_held_item_ids()
	var worn: Dictionary[StringName, bool] = session.player_worn_item_ids()
	var phase_id: StringName = session.day_phase_id()
	var furnishings: Node = map.get_node_or_null("Furnishings")
	if furnishings != null:
		for node: Node in furnishings.get_children():
			var look: Dictionary = node.get_meta("look", {})
			if is_staged_look(look):
				node.set_meta("staged_off", not look_on_stage(look, player, held, worn, phase_id))
	var view: Node = map.get_node_or_null("MapView")
	if view != null and view.has_method("restage"):
		view.call("restage")


## Whether a look (a furnishing's, a voxel prop's) is on the stage only sometimes.
static func is_staged_look(look: Dictionary) -> bool:
	return look.has("present") or look.has("until")


## Whether a staged look is on the stage for this player now (its `present` holding, its `until` not).
static func look_on_stage(look: Dictionary, player: WorldPlayerRuntimeState, held: Dictionary[StringName, bool], worn: Dictionary[StringName, bool] = {}, phase_id: StringName = &"") -> bool:
	return on_stage(_look_when(look, "present"), _look_when(look, "until"), player, held, worn, phase_id)


## The parsed conditions of looks, by their JSON: a look is read once however many times it is judged.
static var _look_whens: Dictionary[String, JournalEntryDefinition] = {}


static func _look_when(look: Dictionary, key: String) -> JournalEntryDefinition:
	if not look.has(key):
		return null
	var text: String = JSON.stringify(look[key])
	if _look_whens.has(text):
		return _look_whens[text]
	var errors: Array[String] = []
	var definition := JournalEntryDefinition.new()
	JournalEntryDefinition.read_when(ContentRecordReader.new({key: look[key]}, "stage prop look", errors), definition, key)
	# A look is read after the catalog was built: a `cond` in it is linked here (DECISIONS「具名条件」).
	JournalEntryDefinition.link_named(GameContent.catalog().conditions(), errors)
	if not errors.is_empty():
		push_error("a stage prop's %s: %s" % [key, errors])
	_look_whens[text] = definition
	return definition


## Whether a condition reads the day's phase anywhere (a stage that comes round again).
static func _comes_round(condition: JournalEntryDefinition) -> bool:
	if condition == null:
		return false
	if condition.when == JournalEntryDefinition.When.PHASE:
		return true
	return condition.parts.any(func(part: JournalEntryDefinition) -> bool: return _comes_round(part))


## Whether a spawn with these conditions is on the stage for this player.
static func on_stage(present: JournalEntryDefinition, until: JournalEntryDefinition, player: WorldPlayerRuntimeState, held: Dictionary[StringName, bool], worn: Dictionary[StringName, bool] = {}, phase_id: StringName = &"") -> bool:
	if present != null and not JournalLog.holds(present, player.state, player.temp_marks, held, &"", worn, phase_id):
		return false
	return until == null or not JournalLog.holds(until, player.state, player.temp_marks, held, &"", worn, phase_id)
