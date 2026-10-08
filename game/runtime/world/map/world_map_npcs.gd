class_name WorldMapNpcs
extends RefCounted
## The NPCs standing on this map: spawned or restored in authored order, each with a
## body and its services; summoned ones, respawns and reset_room(); what they wield.
## Code moved from WorldMapController as it was; the map is `_map`.

var _map: WorldMapController
var map_characters: MapCharacterRuntimeState
var residents: Array[NpcRuntimeState] = []
var _npc_bodies: Dictionary[StringName, WorldCharacterBody2D] = {}
## The spawn each summoned NPC here came by (SummonedNpc), by spawn ID: none is in the catalog.
var _summon_spawns: Dictionary[StringName, NpcSpawnDefinition] = {}
## How far from its caller a summoned NPC comes in: clear of both bodies, diagonals too.
const BESIDE: int = 48
## Who called each summoned NPC still here (set("possessed", who)): its character ID.
var summoners: Dictionary[StringName, StringName] = {}
var npc_presence: Dictionary[StringName, Area2D] = {}
var _registered_npc_content: Dictionary[StringName, CombatSliceContentProfile] = {}

# The map's authorities, read as the controller reads them.
var session: WorldSessionController:
	get: return _map.session
var player_body: WorldCharacterBody2D:
	get: return _map.player_body
var map: StringName:
	get: return _map.map
var _initialized: bool:
	get: return _map.is_map_initialized()
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
var _npc_random: NpcInitializationRandomSource:
	get: return _map.npc_random_source()
var _world_simulation_gate: WorldSimulationGate:
	get: return _map.world_simulation_gate()


func _init(controller: WorldMapController) -> void:
	_map = controller


## Spawns are created in authored order: it fixes each NPC's random draws and
## loadout item identities.
func spawn_actors() -> bool:
	var catalog: ContentCatalog = GameContent.catalog()
	var loadout_content: Array[NpcLoadoutItemDefinition] = catalog.loadout_item_definitions()
	for spawn: NpcSpawnDefinition in catalog.spawns_for_map(map):
		var created: Array[NpcRuntimeState] = NpcCharacterStateFactory.new().create_spawn_instances(
			spawn,
			catalog.npc(spawn.npc_definition_id),
			_map.location_for_zone(spawn.zone_id),
			_inventory,
			_stacks,
			_npc_random,
			loadout_content,
			_item_id_allocator.scope,
		)
		if created.size() != spawn.quantity:
			push_error("spawn %s could not be created; check its npc, map and zone" % spawn.spawn_id)
			return false
		for npc: NpcRuntimeState in created:
			if not _register_loadout(npc):
				return false
		for npc: NpcRuntimeState in created:
			var marker: WorldSpawnMarker2D = _map.resolve_spawn_marker(npc.spawn_point_id)
			if marker == null or not _add_npc_body(npc, marker.global_position):
				return false
			if spawn.starts_absent:
				npc.set_exists_in_map(false)
				_npc_bodies[npc.character_id].refresh_runtime_state()
	# road2.c: create() → setup() → reset() puts the first draw on duty.
	for group: StringName in _draw_groups(""):
		_draw_on_duty(group, false)
	return _map.floor_items.spawn_floor_items()


func _register_loadout(npc: NpcRuntimeState) -> bool:
	for item: ItemInstance in npc.loadout_items():
		if not _item_index.register_snapshot(item):
			return false
		# The drunk's wineskin starts full, as a bought one does.
		var content: ItemContentDefinition = GameContent.catalog().item(item.item_definition_id)
		if content != null and not ItemRoleStates.register_fresh(content, item.item_instance_id, _foods, _liquids):
			return false
	return true


## Restore places the saved NPCs and corpses of this map, exactly where they were.
func restore_actors() -> bool:
	for entry: OldPineRestoredNpcEntry in session.restored_npc_entries():
		var npc: NpcRuntimeState = entry.runtime
		if npc.world_location().map_id != map:
			continue
		# register_npc() is a live-spawn API and marks existence true. Restore
		# immediately reapplies the persisted tombstone fact before any frame.
		var saved_exists: bool = npc.exists_in_map
		if not _add_npc_body(npc, entry.map_position):
			return false
		npc.set_exists_in_map(saved_exists)
		_npc_bodies[npc.character_id].refresh_runtime_state()
	for entry: OldPineRestoredCorpseEntry in session.restored_corpse_entries():
		if entry.world_location.map_id == map and not _map.corpses.publish_corpse_view(entry.state, entry.map_position, entry.world_location):
			return false
	var authored_npc_count: int = 0
	for spawn: NpcSpawnDefinition in GameContent.catalog().spawns_for_map(map):
		authored_npc_count += spawn.quantity
	return residents.size() == authored_npc_count and _map.floor_items.restore_floor_items()


## A body for `npc` at `position`; `at` keeps a respawned NPC in its spawn order.
func _add_npc_body(npc: NpcRuntimeState, position: Vector2, at: int = -1) -> bool:
	var spawn: NpcSpawnDefinition = GameContent.catalog().spawn(npc.spawn_id)
	if spawn == null:
		spawn = _summon_spawns.get(npc.spawn_id)
	if spawn == null or not map_characters.register_npc(npc):
		return false
	var body: WorldNpcBody2D = _map.NpcBodyScene.instantiate() as WorldNpcBody2D
	body.name = String(npc.spawn_point_id).replace(".", "_")
	body.configure_npc(spawn, npc.definition())
	# Enter the physics space already at the spawn point, never at the origin.
	var parent: Node = _characters_node()
	body.position = (parent as Node2D).to_local(position) if parent is Node2D else position
	parent.add_child(body)
	if at < 0 or at > residents.size():
		residents.append(npc)
	else:
		residents.insert(at, npc)
	if not body.bind_world_simulation_gate(_world_simulation_gate) or not body.bind_npc(npc):
		return false
	_connect_npc_body(npc.character_id, body, body.presence())
	_bind_npc_services(npc)
	return true


## What the NPC offers from its body: its goods (`vendor`), its teaching and its quests.
func _bind_npc_services(npc: NpcRuntimeState) -> void:
	var services: Array[NpcService] = []
	if not npc.definition().dealings().vendor_id.is_empty():
		services.append(VendorService.new())
	if npc.definition().dealings().quest_giver:
		services.append(QuestService.new())
	if npc.definition().dealings().shop_front != null:
		services.append(ShopFrontService.new())
	if not NpcTeacher.teachable_skills(npc.definition(), GameContent.catalog()).is_empty():
		services.append(TeacherService.new())
	for service: NpcService in services:
		service.bind_npc(_map, npc)
		_map.add_child(service)
		_map.service_nodes.append(service)


func _unbind_npc_services(character_id: StringName) -> void:
	for service: WorldService in _map.service_nodes.duplicate():
		if service is NpcService and (service as NpcService).npc.character_id == character_id:
			_map.service_nodes.erase(service)
			service.name = "%s_replaced" % service.name
			service.queue_free()


func _characters_node() -> Node:
	var node: Node = _map.get_node_or_null("Characters")
	return _map if node == null else node


func _connect_npc_body(character_id: StringName, body: WorldCharacterBody2D, presence: Area2D) -> void:
	_npc_bodies[character_id] = body
	npc_presence[character_id] = presence
	body.selection_requested.connect(_map.selection.on_npc_selection_requested)
	presence.body_entered.connect(_map.hostilities.on_presence_entered.bind(character_id))
	presence.body_exited.connect(_map.hostilities.on_presence_exited.bind(character_id))


## Binds an already-created NPC to a caller-owned physical body. This does not
## author a spawn, initialize a character, or establish combat relationships.
func register_npc_body(npc: NpcRuntimeState, body: WorldCharacterBody2D, presence: Area2D, content: CombatSliceContentProfile) -> bool:
	if (
		not _initialized or not _map.gameplay_open()
		or npc == null or not npc.is_valid() or not npc.exists_in_map
		or npc.character_id == _player.character_id or find_resident_npc(npc.character_id) != null
		or not is_instance_valid(body) or not _map.is_ancestor_of(body)
		or not body.character_id.is_empty() or body.player_controlled
		or not body.get_node_or_null("CollisionShape2D") is CollisionShape2D
		or not is_instance_valid(presence) or not body.is_ancestor_of(presence)
		or npc.world_location().map_id != map
		or map_characters.has_character(npc.character_id)
		or WorldCombatBindingAdapter.from_npc(npc, content) == null
	):
		return false
	if not map_characters.register_npc(npc):
		return false
	if not body.bind_world_simulation_gate(_world_simulation_gate) or not body.bind_npc(npc):
		map_characters.remove_character(npc.character_id)
		return false
	_registered_npc_content[npc.character_id] = content
	residents.append(npc)
	_connect_npc_body(npc.character_id, body, presence)
	return true


## Caller owns physical-node removal. Never detach a live Encounter participant.
func unregister_npc_body(character_id: StringName) -> bool:
	if not _map.gameplay_open() or not _registered_npc_content.has(character_id):
		return false
	var npc: NpcRuntimeState = find_resident_npc(character_id)
	if npc == null or npc.relationship.is_fighting():
		return false
	var body: WorldCharacterBody2D = _npc_bodies[character_id]
	if is_instance_valid(body):
		body.selection_requested.disconnect(_map.selection.on_npc_selection_requested)
	var area: Area2D = npc_presence[character_id]
	if is_instance_valid(area):
		area.body_entered.disconnect(_map.hostilities.on_presence_entered.bind(character_id))
		area.body_exited.disconnect(_map.hostilities.on_presence_exited.bind(character_id))
	_npc_bodies.erase(character_id)
	npc_presence.erase(character_id)
	_registered_npc_content.erase(character_id)
	residents.erase(npc)
	map_characters.remove_character(character_id)
	_map.hostilities.aggression.clear_npc(character_id)
	if _map.selection.selected_character_id() == character_id:
		_map.selection.selected_target = null
	return true


func npc_runtimes() -> Array[NpcRuntimeState]:
	return residents.duplicate()


func resident_npcs() -> Array[NpcRuntimeState]:
	return residents.duplicate()


func find_resident_npc(character_id: StringName) -> NpcRuntimeState:
	for npc: NpcRuntimeState in residents:
		if npc.character_id == character_id:
			return npc
	return null


## The combat content a binding of this NPC gets now (_npc_content(), with its race and
## authored facts), or null when it is not here.
func npc_combat_content(character_id: StringName) -> CombatSliceContentProfile:
	var npc: NpcRuntimeState = find_resident_npc(character_id)
	return null if npc == null else npc_content(npc).for_npc_definition(npc.definition())


## command("wield <type>") / command("unwield <type>") for an NPC: wield.c takes the
## first carried weapon of that skill type into a free hand (present(), inventory
## order); unwield.c puts the wielded one of that type away. False when nothing
## changed (none carried, hands full, none held).
func npc_wield_by_type(character_id: StringName, skill_type: StringName, on: bool) -> bool:
	var npc: NpcRuntimeState = find_resident_npc(character_id)
	if npc == null:
		return false
	var equipment: EquipmentState = npc.character_state.equipment
	if not on:
		var held: EquippedWeaponRef = equipment.primary_weapon()
		return held != null and held.skill_type == skill_type and equipment.unwield(held.instance_id).succeeded
	for item_id: StringName in _inventory.direct_children(ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, character_id)):
		var item: ItemInstance = _item_index.resolve(item_id)
		var content: ItemContentDefinition = null if item == null else GameContent.catalog().item(item.item_definition_id)
		var weapon: WeaponDefinition = null if content == null else content.weapon_definition()
		if weapon != null and weapon.skill_type == skill_type and not equipment.has_weapon_instance(item_id):
			return equipment.wield(EquippedWeaponRef.new(item_id, weapon), npc.armor.is_slot_occupied(OldPineEquipmentInteractionAdapter.SHIELD_SLOT)).succeeded
	return false


## command("wield <id>") for an NPC: a carried, not yet wielded item of that kind.
func npc_wield_item(character_id: StringName, item_definition_id: StringName) -> bool:
	var npc: NpcRuntimeState = find_resident_npc(character_id)
	if npc == null:
		return false
	var equipment: EquipmentState = npc.character_state.equipment
	for item_id: StringName in _inventory.direct_children(ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, character_id)):
		var item: ItemInstance = _item_index.resolve(item_id)
		var content: ItemContentDefinition = null if item == null or item.item_definition_id != item_definition_id else GameContent.catalog().item(item.item_definition_id)
		var weapon: WeaponDefinition = null if content == null else content.weapon_definition()
		if weapon != null and not equipment.has_weapon_instance(item_id):
			return equipment.wield(EquippedWeaponRef.new(item_id, weapon), npc.armor.is_slot_occupied(OldPineEquipmentInteractionAdapter.SHIELD_SLOT)).succeeded
	return false


## present(<partner>, environment(npc)): an NPC of `definition_id` in the same room,
## standing (living()) and not fighting; null when there is none.
func idle_npc_beside(character_id: StringName, definition_id: StringName) -> NpcRuntimeState:
	var npc: NpcRuntimeState = find_resident_npc(character_id)
	if npc == null:
		return null
	for other: NpcRuntimeState in residents:
		if (
			other != npc and other.definition().definition_id == definition_id and other.exists_in_map
			and other.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE and not other.relationship.is_fighting()
			and other.world_location().zone_id == npc.world_location().zone_id
		):
			return other
	return null


## Where a save puts an NPC: its body, or the end of the walk it is on.
func npc_rest_position(character_id: StringName) -> Vector2:
	var body: WorldCharacterBody2D = runtime_body_for_character(character_id)
	return Vector2.INF if body == null else _map.npc_life.npc_walker().rest_position(character_id, body)


func runtime_body_for_character(character_id: StringName) -> WorldCharacterBody2D:
	if _player != null and character_id == _player.character_id:
		return player_body
	return _npc_bodies.get(character_id)


## The body of the NPC spawned at `spawn_point_id` (a spawns[] point).
func runtime_body_for_spawn_point(spawn_point_id: StringName) -> WorldCharacterBody2D:
	for npc: NpcRuntimeState in residents:
		if npc.spawn_point_id == spawn_point_id:
			return _npc_bodies.get(npc.character_id)
	return null


func character_bodies() -> Array[WorldCharacterBody2D]:
	var result: Array[WorldCharacterBody2D] = [player_body]
	result.append_array(_npc_bodies.values())
	return result


## The weapon an NPC is authored to wield, as its verified combat weapon.
## The NPC's combat content: its registered (loadout) profile, unless the weapon now in
## its hand is another one (萧辟尘 takes up his carried sword mid-fight, consider()): then
## that weapon's, so its blows are the sword's after the draw and after Continue.
func npc_content(npc: NpcRuntimeState) -> CombatSliceContentProfile:
	var registered: CombatSliceContentProfile = _registered_npc_content.get(npc.character_id, _authored_weapon_profile(npc.definition()))
	var held: EquippedWeaponRef = npc.character_state.equipment.primary_weapon()
	if held == null or registered.is_verified_primary(held):
		return registered
	var item: ItemInstance = _item_index.resolve(held.instance_id)
	var content: ItemContentDefinition = null if item == null else GameContent.catalog().item(item.item_definition_id)
	if content == null or content.weapon_definition() == null:
		return registered
	return CombatSliceContentProfile.new(content.item_definition_id, content.weapon_skill_type, content.weapon_damage)


static func _authored_weapon_profile(definition: NpcDefinition) -> CombatSliceContentProfile:
	for entry: NpcLoadoutEntry in definition.loadout_entries():
		# A drawn weapon (worker2.c's hammer) is the weapon in hand, if it was drawn.
		if entry.is_choice() or entry.equipment_intent != NpcLoadoutEntry.EquipmentIntent.WIELD_PRIMARY:
			continue
		var content: ItemContentDefinition = GameContent.catalog().item(entry.item_definition_id)
		if content != null and content.weapon_definition() != null:
			return CombatSliceContentProfile.new(content.item_definition_id, content.weapon_skill_type, content.weapon_damage)
	return CombatSliceContentProfile.new(&"", &"", 0)


## std/room.c reset() for one ES2 room's set("objects") on this map: a new NPC
## where one died (make_inventory() for a destructed object), the others called
## home (npc.c return_home()), and an item laid down again once the one it put
## there is gone from the world (owner, DECISIONS 4D).
func reset_room(legacy_room: String) -> void:
	if not _initialized or session == null:
		return
	var catalog: ContentCatalog = GameContent.catalog()
	# house3.c reset(): num_of_spider = 3.
	for landmark: WorldLandmarkDefinition in catalog.landmarks_for_map(map):
		if landmark.legacy_source_path == legacy_room:
			_map.floor_items.landmark_use_counts.erase(landmark.landmark_id)
	for spawn: NpcSpawnDefinition in catalog.spawns_for_map(map):
		if spawn.legacy_source_room_path != legacy_room or spawn.starts_absent:
			continue
		for point_id: StringName in spawn.spawn_point_ids():
			var npc: NpcRuntimeState = _npc_at_point(point_id)
			if npc == null:
				continue
			if npc.life_status == CharacterRuntimeLifeStatus.Value.DEAD:
				_respawn_npc(spawn, npc)
			elif npc.world_location().zone_id != spawn.zone_id:
				return_home(npc)
	for spawn: ItemSpawnDefinition in catalog.item_spawns_for_map(map):
		if spawn.legacy_source_room_path != legacy_room:
			continue
		for point_id: StringName in spawn.spawn_point_ids():
			if not _inventory.is_registered(ItemSpawnDefinition.item_instance_id(_item_id_allocator.scope, point_id)):
				if not _map.floor_items.place_floor_item(spawn, point_id):
					push_error("room reset could not lay %s on %s" % [spawn.item_definition_id, point_id])
	for group: StringName in _draw_groups(legacy_room):
		_draw_on_duty(group, true)


## The draw groups of this map's spawns, in authored order; of one room's, unless "".
func _draw_groups(legacy_room: String) -> Array[StringName]:
	var groups: Array[StringName] = []
	for spawn: NpcSpawnDefinition in GameContent.catalog().spawns_for_map(map):
		if spawn.drawn and not groups.has(spawn.draw_group) and (legacy_room.is_empty() or spawn.legacy_source_room_path == legacy_room):
			groups.append(spawn.draw_group)
	return groups


## d/temple/road2.c reset(): one spawn of `group` is drawn ("guard_taoist" +
## (random(3)+1), on the world's interaction stream as room resets draw) and
## std/room.c's reset() makes its NPC anew where it died, brings an absent one in or
## calls one away home; the group's others stay as they are. road2.c sets the objects
## after ::reset(), so ES2 put on duty the draw of the reset before: the same odds, one
## reset apart. `arrive`: the room sees it come (not while the world is being made).
func _draw_on_duty(group: StringName, arrive: bool) -> void:
	var spawns: Array[NpcSpawnDefinition] = []
	for spawn: NpcSpawnDefinition in GameContent.catalog().spawns_for_map(map):
		if spawn.draw_group == group:
			spawns.append(spawn)
	if spawns.is_empty():
		return
	var drawn: NpcSpawnDefinition = spawns[clampi(_map.world_interaction_random_source().legacy_random(spawns.size()), 0, spawns.size() - 1)]
	for point_id: StringName in drawn.spawn_point_ids():
		var npc: NpcRuntimeState = _npc_at_point(point_id)
		if npc == null:
			continue
		if npc.life_status == CharacterRuntimeLifeStatus.Value.DEAD:
			_respawn_npc(drawn, npc)
		elif not npc.exists_in_map:
			_appear(npc, drawn, arrive)
		elif npc.world_location().zone_id != drawn.zone_id:
			return_home(npc)


## An absent NPC of a summoned or drawn spawn appears on its marker; `arrive`: as one
## that comes into the room (its init() for whoever is there).
func _appear(npc: NpcRuntimeState, spawn: NpcSpawnDefinition, arrive: bool = true) -> bool:
	var marker: WorldSpawnMarker2D = _map.resolve_spawn_marker(npc.spawn_point_id)
	var body: WorldCharacterBody2D = runtime_body_for_character(npc.character_id)
	if marker == null or body == null:
		return false
	body.global_position = marker.global_position
	npc.set_world_location(_map.location_for_zone(spawn.zone_id))
	npc.set_exists_in_map(true)
	body.refresh_runtime_state()
	if arrive:
		_map.npc_life.npc_arrived(npc)
	return true


## One NPC of a summoned spawn comes in (house3.c call_spider(): new(...)->move(room)):
## the first whose point is free, absent or dead (made anew). Null when every one
## stands here already.
func summon_one(spawn_id: StringName) -> NpcRuntimeState:
	var spawn: NpcSpawnDefinition = GameContent.catalog().spawn(spawn_id)
	if not _initialized or spawn == null or not spawn.summoned or spawn.map_id != map:
		return null
	for point_id: StringName in spawn.spawn_point_ids():
		var npc: NpcRuntimeState = _npc_at_point(point_id)
		if npc == null:
			continue
		if npc.life_status == CharacterRuntimeLifeStatus.Value.DEAD:
			return _npc_at_point(point_id) if _respawn_npc(spawn, npc) else null
		if not npc.exists_in_map:
			return npc if _appear(npc, spawn) else null
	return null


## A summoned spawn's NPCs come in on their markers (keep2.c valid_leave()'s
## new(...)->move(this_object())): an absent one appears, a dead one is made anew
## as a room reset would; one already here stays. Returns those that came.
func summon(spawn_id: StringName) -> Array[NpcRuntimeState]:
	var came: Array[NpcRuntimeState] = []
	var spawn: NpcSpawnDefinition = GameContent.catalog().spawn(spawn_id)
	if not _initialized or spawn == null or not spawn.summoned or spawn.map_id != map:
		return came
	for point_id: StringName in spawn.spawn_point_ids():
		var npc: NpcRuntimeState = _npc_at_point(point_id)
		if npc == null:
			continue
		if npc.life_status == CharacterRuntimeLifeStatus.Value.DEAD:
			if _respawn_npc(spawn, npc):
				came.append(_npc_at_point(point_id))
		elif not npc.exists_in_map and _appear(npc, spawn):
			came.append(npc)
	return came


func _npc_at_point(point_id: StringName) -> NpcRuntimeState:
	for npc: NpcRuntimeState in residents:
		if npc.spawn_point_id == point_id:
			return npc
	return null


## make_inventory() where an NPC died: a new one, its create() drawn afresh from
## the NPC stream, on its marker and in its old place in spawn order.
func _respawn_npc(spawn: NpcSpawnDefinition, dead: NpcRuntimeState) -> bool:
	var catalog: ContentCatalog = GameContent.catalog()
	var marker: WorldSpawnMarker2D = _map.resolve_spawn_marker(dead.spawn_point_id)
	if marker == null or catalog.npc(spawn.npc_definition_id) == null:
		push_error("room reset has no marker or NPC for %s" % dead.spawn_point_id)
		return false
	var fresh: NpcRuntimeState = NpcCharacterStateFactory.new().create_one(
		catalog.npc(spawn.npc_definition_id),
		NpcGeneration.next(dead.character_id, dead.spawn_point_id),
		spawn.spawn_id,
		dead.spawn_point_id,
		_map.location_for_zone(spawn.zone_id),
		_inventory,
		_stacks,
		_npc_random,
		catalog.loadout_item_definitions(),
		_item_id_allocator.scope,
	)
	if fresh == null or not _register_loadout(fresh):
		push_error("room reset could not make a new NPC at %s" % dead.spawn_point_id)
		return false
	var at: int = residents.find(dead)
	_drop_npc(dead)
	if not _add_npc_body(fresh, marker.global_position, at):
		return false
	_map.npc_life.npc_arrived(fresh)
	return true


## new(<summoned NPC>)->move(environment(caster)) (saveme.c): one of `definition_id`
## comes into the place of `caster_id` (an NPC here, or the player), on a free spot
## beside them, drawn afresh from the NPC stream like any new NPC. Returns its character
## ID, or "" when it could not come (no such summoned NPC, nobody to stand beside).
func summon_beside(caster_id: StringName, definition_id: StringName) -> StringName:
	var definition: NpcDefinition = GameContent.catalog().npc(definition_id)
	if definition == null or definition.summoning() == null:
		return &""
	var npc: NpcRuntimeState = _new_beside(caster_id, definition)
	if npc == null:
		return &""
	summoners[npc.character_id] = caster_id
	return npc.character_id


## necromancy.c practice_skill(): new("/obj/npc/mind_bug")->move(environment(me)) beside
## the player practising, its create() reading this_player() (NpcConjuring: combat_exp
## from their raw level of the skill, their bellicosity) and its kill_ob(me) kept as
## attack.c's hatred (FLAG_HUNTS_PLAYER). Null when it could not come.
func conjure_beside_player(definition_id: StringName) -> NpcRuntimeState:
	var definition: NpcDefinition = GameContent.catalog().npc(definition_id)
	if definition == null or definition.conjuring() == null or _player == null:
		return null
	var npc: NpcRuntimeState = _new_beside(_player.character_id, definition)
	if npc == null:
		return null
	npc.character_state.progression.combat_experience = definition.conjuring().combat_experience(_player.state.skills.raw_level(definition.conjuring().skill_id))
	npc.character_state.attributes.bellicosity = _player.state.attributes.bellicosity
	npc.set_flag(NpcDefinition.FLAG_HUNTS_PLAYER, true)
	return npc


## One NPC of `definition`, no room's, made beside `caster_id` (SummonedNpc). Null when
## it could not come.
func _new_beside(caster_id: StringName, definition: NpcDefinition) -> NpcRuntimeState:
	var catalog: ContentCatalog = GameContent.catalog()
	var definition_id: StringName = definition.definition_id
	var caster: NpcRuntimeState = find_resident_npc(caster_id)
	var location: WorldLocationState = null
	if caster != null:
		location = caster.world_location()
	elif _player != null and caster_id == _player.character_id:
		location = _player.world_location()
	var body: WorldCharacterBody2D = runtime_body_for_character(caster_id)
	if not _initialized or location == null or body == null or location.map_id != map:
		return null
	var allocation: SessionItemIdAllocationResult = _item_id_allocator.allocate(_inventory)
	if not allocation.succeeded:
		return null
	var number: int = String(allocation.item_instance_id).get_slice(SessionItemIdAllocator.DYNAMIC_SEPARATOR, 1).to_int()
	var point_id: StringName = SummonedNpc.point_id(number, definition_id)
	var spawn: NpcSpawnDefinition = SummonedNpc.spawn(point_id, definition_id, map, location.zone_id)
	var npc: NpcRuntimeState = NpcCharacterStateFactory.new().create_one(
		definition, NpcGeneration.character_id(point_id, 1), spawn.spawn_id, point_id,
		_map.location_for_zone(location.zone_id), _inventory, _stacks, _npc_random,
		catalog.loadout_item_definitions(), _item_id_allocator.scope,
	)
	if npc == null:
		push_error("could not summon %s beside %s" % [definition_id, caster_id])
		return null
	if not _register_loadout(npc):
		push_error("could not summon %s beside %s" % [definition_id, caster_id])
		_take_away(npc)
		return null
	_summon_spawns[spawn.spawn_id] = spawn
	# Clear of the caller's body (34 px), so neither is pushed when the world moves again.
	if not _add_npc_body(npc, _map.floor_items.at_feet(location, body.global_position, false, BESIDE)):
		push_error("could not summon %s beside %s" % [definition_id, caster_id])
		_take_away(npc)
		_summon_spawns.erase(spawn.spawn_id)
		if residents.has(npc):
			_drop_npc(npc)
		return null
	return npc


## Who called the summoned NPC `character_id` (set("possessed", who)), or "".
func summoner_of(character_id: StringName) -> StringName:
	return summoners.get(character_id, &"")


## heaven_soldier.c heal_up() once it is not fighting: call_out("leave", 1), its leave
## lines where the player is (and can read them), then destruct() with all it carries.
## Here every summoned NPC still standing leaves as the fight it came into ends (its
## lines after the fight's result, unless the player left it by a spell: gone before
## it says them); a dead one is forgotten and its corpse stays. A conjured one (the
## 观想虫) stays until it dies, as in ES2.
func dismiss_summoned() -> void:
	var departing: bool = session != null and session.combat_encounter_coordinator() != null and session.combat_encounter_coordinator().player_departing()
	for npc: NpcRuntimeState in residents.duplicate():
		if not SummonedNpc.is_summoned(npc.character_id):
			continue
		if npc.definition().conjuring() != null and npc.life_status != CharacterRuntimeLifeStatus.Value.DEAD:
			continue
		if npc.life_status != CharacterRuntimeLifeStatus.Value.DEAD:
			var summoning: NpcSummoning = npc.definition().summoning()
			if summoning != null and _map.npc_life.player_hears(npc) and session != null and not departing:
				var lines: Array[ColoredLine] = []
				for text: String in summoning.leave:
					lines.append(ColoredLine.new(tr(text).replace("$N", tr(npc.definition().display_name)), summoning.color))
				session.shared_ui().append_after_fight(lines)
			_take_away(npc)
		_summon_spawns.erase(npc.spawn_id)
		summoners.erase(npc.character_id)
		_drop_npc(npc)


## destruct(): what a summoned NPC carries goes with it.
func _take_away(npc: NpcRuntimeState) -> void:
	var owner := ItemLifecycleOwnerContext.new(npc.character_id, npc.character_state.equipment, npc.armor)
	for item_id: StringName in _inventory.direct_children(ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, npc.character_id)):
		var removal: ItemLifecycleResult = ItemLifecycleService.destroy_item(_inventory, _stacks, item_id, ItemLifecycleResult.ChildDisposition.DESTROY_SUBTREE, owner)
		if not (
			removal.succeeded
			and _foods.forget_removed(removal.removed_instance_ids, _inventory)
			and _liquids.forget_removed(removal.removed_instance_ids, _inventory)
			and _item_index.forget_destroyed_snapshots(removal.removed_instance_ids, _inventory)
		):
			push_error("%s could not take %s away" % [npc.character_id, item_id])


## Forgets a dead NPC the room has replaced; its corpse stays.
func _drop_npc(npc: NpcRuntimeState) -> void:
	var character_id: StringName = npc.character_id
	var body: WorldCharacterBody2D = _npc_bodies.get(character_id)
	if is_instance_valid(body):
		body.selection_requested.disconnect(_map.selection.on_npc_selection_requested)
		body.name = "%s_replaced" % body.name
		body.queue_free()
	_npc_bodies.erase(character_id)
	npc_presence.erase(character_id)
	residents.erase(npc)
	map_characters.remove_character(character_id)
	_map.hostilities.aggression.clear_npc(character_id)
	_unbind_npc_services(character_id)
	if _map.npc_life.ambience != null:
		_map.npc_life.ambience.cancel_greeting(character_id)
		_map.npc_life.ambience.cancel_call(character_id)
	_map.npc_life.pending_steals.erase(character_id)
	if _map.npc_life.walker != null:
		_map.npc_life.walker.cancel(character_id)
	if _map.npc_life.npc_heartbeat != null:
		_map.npc_life.npc_heartbeat.forget(character_id)
	if _map.selection.selected_character_id() == character_id:
		_map.selection.selected_target = null
		if _map.hud() != null:
			_map.hud().set_selected_target(null)


## npc.c return_home(): a conscious NPC that is not fighting leaves for home
## (急急忙忙地离开了。 where it was); move() says nothing where it arrives. The body
## walks home on the map the player is on and is simply there elsewhere.
func return_home(npc: NpcRuntimeState) -> bool:
	var catalog: ContentCatalog = GameContent.catalog()
	var spawn: NpcSpawnDefinition = catalog.spawn(npc.spawn_id)
	var from_zone_id: StringName = npc.world_location().zone_id
	if spawn == null or from_zone_id == spawn.zone_id:
		return true
	var zone: ZoneDefinition = catalog.zone(from_zone_id)
	if (
		npc.life_status != CharacterRuntimeLifeStatus.Value.ACTIVE or npc.relationship.is_fighting()
		or zone == null or catalog.room(zone.room_ids()[0]).exits().is_empty()
	):
		return false
	var seen: bool = _map.npc_life.player_hears(npc)
	var body: WorldCharacterBody2D = runtime_body_for_character(npc.character_id)
	var marker: WorldSpawnMarker2D = _map.resolve_spawn_marker(npc.spawn_point_id)
	if body == null or marker == null:
		return false
	_map.npc_life.npc_walker().cancel(npc.character_id)
	var watched: bool = session != null and session.active_map() == _map
	if not watched or not _map.npc_life.npc_walker().walk_to(npc.character_id, body, _map.physical_zone(from_zone_id), _map.physical_zone(spawn.zone_id), marker.global_position):
		body.global_position = marker.global_position
	npc.set_world_location(_map.location_for_zone(spawn.zone_id))
	if seen:
		_map.hud().append_log_lines([tr("%s急急忙忙地离开了。") % tr(npc.definition().display_name)])
	_map.npc_life.npc_arrived(npc)
	return true
