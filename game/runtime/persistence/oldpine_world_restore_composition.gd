class_name OldPineWorldRestoreComposition
extends RefCounted

const Values := preload("res://core/persistence/game_save_value_types.gd")
const Result := preload(
	"res://runtime/persistence/oldpine_world_restore_result.gd"
)
const CORPSE_DEFINITION_ID: StringName = CorpseState.ITEM_DEFINITION_ID
## Preparing reads only the snapshot and the content catalog: a validate() that succeeds
## keeps its preparation on the snapshot (GameSaveSnapshot.keep_derived(): it follows an
## exact copy and goes when the content changes), unseen, and the next prepare() or
## validate() of that content takes it instead of preparing again (Save checks the
## captured snapshot twice; Continue checks the snapshot it read, then builds from it).
## Anything that copies the snapshot in between (GameSaveResult, the validator, encode)
## carries it off: the next prepare() then just prepares, as before.


## The snapshot's restored state, ready for a session to be built from.
static func prepare(snapshot: GameSaveSnapshot) -> OldPineWorldRestoreResult:
	var kept: OldPineWorldRestoreResult = _take_kept(snapshot)
	return kept if kept != null else _prepare(snapshot)


## Whether prepare() would succeed: its outcome, path and detail, never its preparation.
static func validate(snapshot: GameSaveSnapshot) -> OldPineWorldRestoreResult:
	var result: OldPineWorldRestoreResult = _take_kept(snapshot)
	if result == null:
		result = _prepare(snapshot)
		if result.outcome == Result.Outcome.SUCCESS:
			snapshot.keep_derived(result)
	if result.outcome == Result.Outcome.SUCCESS:
		return OldPineWorldRestoreResult.new(Result.Outcome.SUCCESS, "", "", null, null)
	return Result.failure(result.outcome, result.path, result.detail)


static func _take_kept(snapshot: GameSaveSnapshot) -> OldPineWorldRestoreResult:
	return null if snapshot == null else snapshot.take_derived() as OldPineWorldRestoreResult


static func _prepare(snapshot: GameSaveSnapshot) -> OldPineWorldRestoreResult:
	var root_validation: GameSaveResult = GameSaveSnapshotValidator.validate(snapshot)
	if not root_validation.succeeded():
		return Result.failure(
			Result.Outcome.INVALID_SNAPSHOT,
			root_validation.path,
			root_validation.detail,
		)
	# The snapshot's getters return deep copies: read each one once.
	var saved_player: Values.PlayerRuntimeSnapshot = snapshot.player
	var npc_states: Array[Values.NpcSpawnStateSnapshot] = snapshot.npc_spawn_states
	if saved_player.character_id != WorldSessionController.PLAYER_ID:
		return Result.failure(
			Result.Outcome.UNKNOWN_CONTENT_ID,
			"player.character_id",
		)
	if not _player_location_is_current(saved_player.world_location, snapshot.world_content_revision):
		return Result.failure(
			Result.Outcome.INVALID_WORLD_LOCATION,
			"player.world_location",
		)

	var item_restore: NativeItemRestoreCompositionResult = (
		NativeItemPersistenceComposition.restore(
			snapshot.items,
			GameContent.catalog().native_item_projections(),
			snapshot.item_id_allocator,
		)
	)
	if not item_restore.succeeded:
		return Result.failure(
			Result.Outcome.ITEM_RESTORE_FAILED,
			"items",
			"item or allocator reconstruction rejected",
		)
	var domain: NativeItemDomainState = item_restore.domain_state
	# One NPC per authored spawn point, whatever generation room resets have made
	# of it; a missing or foreign record is the ledger's failure below.
	var saved_ids: Dictionary[StringName, StringName] = {}
	for npc: Values.NpcSpawnStateSnapshot in npc_states:
		saved_ids[npc.spawn_point_id] = npc.character_id
	var character_ids: Array[StringName] = [saved_player.character_id]
	for spawn: NpcSpawnDefinition in _world_spawns(snapshot.world_content_revision):
		for point_id: StringName in spawn.spawn_point_ids():
			var saved_id: StringName = saved_ids.get(point_id, &"")
			character_ids.append(saved_id if NpcGeneration.of(saved_id, point_id) > 0 else NpcGeneration.character_id(point_id, 1))
	if not _character_aggregate_ids_match(domain, character_ids):
		return Result.failure(
			Result.Outcome.ITEM_RESTORE_FAILED,
			"items.character_equipment",
			"Equipment/Armor character records do not match the current ledger",
		)

	var player_equipment: EquipmentState = domain.equipment_state(
		saved_player.character_id
	)
	var player_armor: ArmorState = domain.armor_state(saved_player.character_id)
	var player_state: CharacterState = CharacterStateSnapshotRestorer.restore(
		saved_player.character,
		player_equipment,
	)
	if player_state == null or player_armor == null:
		return Result.failure(
			Result.Outcome.CHARACTER_RESTORE_FAILED,
			"player.character",
		)
	var player_life: int = _life_status(saved_player.life_status)
	if player_life < 0:
		return Result.failure(
			Result.Outcome.CHARACTER_RESTORE_FAILED,
			"player.life_status",
		)
	var player: WorldPlayerRuntimeState = WorldPlayerRuntimeState.new(
		saved_player.character_id,
		player_state,
		CombatRelationshipState.new(saved_player.character_id),
		ActionBusyState.new(),
		player_armor,
		_location(saved_player.world_location),
		player_life,
		saved_player.exists_in_world,
		saved_player.combat_available,
		PlayerBodyFacts.new(saved_player.body_facts.body_weight, saved_player.body_facts.maximum_encumbrance),
		PlayerIdentityFacts.new(saved_player.identity.display_name, saved_player.identity.title, saved_player.identity.age),
	)
	if not player.is_valid():
		return Result.failure(
			Result.Outcome.RECONSTRUCTION_FAILED,
			"player",
		)
	player.restore_temps(saved_player.temps)
	player.busy.restore(saved_player.busy_value, saved_player.busy_interrupt)

	var npc_result: OldPineWorldRestoreResult = _restore_npc_ledger(
		snapshot,
		domain,
		item_restore.item_index,
		npc_states,
	)
	if npc_result.outcome != Result.Outcome.SUCCESS:
		return npc_result
	var npc_entries: Array[OldPineRestoredNpcEntry] = []
	npc_entries.assign(npc_result.preparation.npc_entries())

	var items: NativeItemStateSnapshot = snapshot.items
	var corpse_result: OldPineWorldRestoreResult = _restore_corpses(
		snapshot,
		domain,
		saved_player,
		npc_states,
		items,
	)
	if corpse_result.outcome != Result.Outcome.SUCCESS:
		return corpse_result
	var corpse_entries: Array[OldPineRestoredCorpseEntry] = []
	corpse_entries.assign(corpse_result.preparation.corpse_entries())
	var floor_failure: OldPineWorldRestoreResult = _check_floor_items(snapshot, corpse_entries, items)
	if floor_failure != null:
		return floor_failure

	var npc_random: GodotNpcInitializationRandomSource = (
		GodotNpcInitializationRandomSource.new(0, true)
	)
	var combat_random: GodotCombatRandomSource = GodotCombatRandomSource.new(0, true)
	var world_random: GodotWorldInteractionRandomSource = (
		GodotWorldInteractionRandomSource.new(0, true)
	)
	if (
		not npc_random.restore_random_state(snapshot.npc_initialization_rng)
		or not combat_random.restore_random_state(snapshot.combat_rng)
		or not world_random.restore_random_state(snapshot.world_interaction_rng)
	):
		return Result.failure(
			Result.Outcome.INVALID_RANDOM_STREAM,
			"rng",
		)
	var preparation: OldPineWorldRestorePreparation = (
		OldPineWorldRestorePreparation.new(
			player,
			Vector2(saved_player.map_position.x, saved_player.map_position.y),
			domain,
			item_restore.item_index,
			item_restore.allocator,
			npc_random,
			combat_random,
			world_random,
			npc_entries,
			corpse_entries,
			snapshot.world_content_revision,
		)
	)
	preparation.floor_items = snapshot.floor_items
	# A note maze's note: a note_maze landmark and one of its notes.
	for landmark_id: StringName in snapshot.maze_notes:
		var maze: WorldLandmarkDefinition = GameContent.catalog().landmark(landmark_id)
		if maze == null or maze.policy != &"note_maze" or snapshot.maze_notes[landmark_id] >= maze.notes.size():
			return Result.failure(Result.Outcome.INVALID_SNAPSHOT, "maze_notes.%s" % String(landmark_id), "no such note")
	preparation.maze_notes = snapshot.maze_notes
	# What each map was owed: one of the world's maps, not the player's (it owes nothing).
	var world_maps: Array[StringName] = WorldSessionController.world_map_ids_for(snapshot.world_content_revision)
	for map_id: StringName in snapshot.away_ms:
		if not world_maps.has(map_id) or map_id == saved_player.world_location.map_id:
			return Result.failure(Result.Outcome.INVALID_SNAPSHOT, "away_ms.%s" % String(map_id), "no such map away from the player")
	preparation.away_ms = snapshot.away_ms
	if not preparation.is_valid():
		return Result.failure(
			Result.Outcome.RECONSTRUCTION_FAILED,
			"preparation",
		)
	return OldPineWorldRestoreResult.new(
		Result.Outcome.SUCCESS,
		"",
		"",
		null,
		preparation,
	)


static func _restore_npc_ledger(
	snapshot: GameSaveSnapshot,
	domain: NativeItemDomainState,
	item_index: WorldItemInstanceIndex,
	npc_states: Array[Values.NpcSpawnStateSnapshot],
) -> OldPineWorldRestoreResult:
	var saved_by_point: Dictionary[StringName, Values.NpcSpawnStateSnapshot] = {}
	var scope: StringName = snapshot.item_id_allocator.scope
	for saved: Values.NpcSpawnStateSnapshot in npc_states:
		if saved_by_point.has(saved.spawn_point_id):
			return Result.failure(
				Result.Outcome.INCONSISTENT_SPAWN_STATE,
				"npc_spawn_states",
				"duplicate authored spawn point",
			)
		saved_by_point[saved.spawn_point_id] = saved
	var entries: Array[OldPineRestoredNpcEntry] = []
	var referenced_loadout_ids: Dictionary[StringName, bool] = {}
	var item_ids: PackedStringArray = PackedStringArray(item_index.snapshot_ids())
	for spawn: NpcSpawnDefinition in _world_spawns(snapshot.world_content_revision):
		var definition: NpcDefinition = GameContent.catalog().npc(
			spawn.npc_definition_id
		)
		if definition == null:
			return Result.failure(
				Result.Outcome.UNKNOWN_CONTENT_ID,
				"npc_spawn_states.npc_definition_id",
			)
		for point_id: StringName in spawn.spawn_point_ids():
			if not saved_by_point.has(point_id):
				return Result.failure(
					Result.Outcome.INCONSISTENT_SPAWN_STATE,
					"npc_spawn_states",
					"missing authored spawn slot",
				)
			var saved: Values.NpcSpawnStateSnapshot = saved_by_point[point_id]
			var path: String = "npc_spawn_states.%s" % String(point_id)
			# One that drew its name is saved as that named form (NpcDefinition.named()).
			var made: NpcDefinition = GameContent.catalog().npc(saved.npc_definition_id)
			if (
				saved.spawn_id != spawn.spawn_id
				or made == null
				or NpcDefinition.unnamed_id(saved.npc_definition_id) != spawn.npc_definition_id
				or (saved.npc_definition_id != spawn.npc_definition_id and definition.name_pick().is_empty())
				or NpcGeneration.of(saved.character_id, point_id) == 0
				or not _location_is_current(saved.world_location)
				# One that follows the player every way (小娟, owner 黑松山 plan F2) may stand on another map,
				# and one that went through a door next to its home (a wanderer, one called over, one
				# that walked out of a fight).
				or (
					saved.world_location.map_id != spawn.map_id
					and (definition.hooks() == null or not definition.hooks().follows_every_way)
					and not _wandered_to(definition, spawn.zone_id, saved.world_location.zone_id)
				)
				# Alive and not in the world: only a summoned or drawn spawn's NPC waiting for its room.
				or (not saved.exists_in_world and saved.life_status != &"dead" and not spawn.starts_absent)
			):
				return Result.failure(
					Result.Outcome.INCONSISTENT_SPAWN_STATE,
					path,
				)
			var age_roll: NpcRandomInteger = definition.age_roll()
			if (
				(age_roll != null and not age_roll.admits(saved.age))
				or (age_roll == null and definition.has_authored_age and saved.age != definition.age)
			):
				return Result.failure(
					Result.Outcome.INCONSISTENT_SPAWN_STATE,
					path + ".age",
				)
			var expected_body: NpcBodyFacts = NpcBodyFacts.derive(
				definition, saved.character.attributes.strength,
			)
			if (
				expected_body == null
				or not expected_body.matches_saved(saved.body_weight, saved.maximum_encumbrance)
			):
				return Result.failure(
					Result.Outcome.INCONSISTENT_SPAWN_STATE,
					path + ".derived_character_facts",
				)
			if not _loadout_matches(
				saved,
				definition,
				item_index,
				referenced_loadout_ids,
				scope,
				item_ids,
			):
				return Result.failure(
					Result.Outcome.INCONSISTENT_SPAWN_STATE,
					path + ".live_loadout_item_ids",
				)
			var equipment: EquipmentState = domain.equipment_state(saved.character_id)
			var armor: ArmorState = domain.armor_state(saved.character_id)
			var state: CharacterState = CharacterStateSnapshotRestorer.restore(
				saved.character,
				equipment,
			)
			var life: int = _life_status(saved.life_status)
			if state == null or armor == null or life < 0:
				return Result.failure(
					Result.Outcome.CHARACTER_RESTORE_FAILED,
					path + ".character",
				)
			var loadout: Array[ItemInstance] = []
			for item_id: StringName in saved.live_loadout_item_ids:
				loadout.append(item_index.resolve(item_id))
			var runtime: NpcRuntimeState = NpcRuntimeState.new(
				saved.character_id,
				made,
				saved.spawn_id,
				saved.spawn_point_id,
				state,
				CombatRelationshipState.new(saved.character_id),
				ActionBusyState.new(),
				armor,
				_location(saved.world_location),
				life,
				saved.combat_available,
				saved.exists_in_world,
				saved.age,
				saved.body_weight,
				saved.maximum_encumbrance,
				loadout,
			)
			if not runtime.is_valid():
				return Result.failure(
					Result.Outcome.RECONSTRUCTION_FAILED,
					path,
				)
			runtime.set_revive_in_ms(saved.revive_in_ms)
			runtime.busy.restore(saved.busy_value, saved.busy_interrupt)
			# What it remembered; a saved NPC that remembered nothing keeps create()'s flags.
			if saved.has_memory():
				runtime.restore_memory_flags(saved.flags)
				runtime.combat_chat_chance = saved.combat_chat_chance
				runtime.chat_chance = saved.chat_chance
				runtime.pills_left = saved.pills_left
				runtime.times_caught = saved.times_caught
				runtime.chant_stage = saved.chant_stage
				runtime.chant_left = saved.chant_left_ms / 1000.0
				# A chant under way is one of its NPC's stages (sword_soul.c chant_sword()).
				var hooks: NpcHooks = definition.hooks()
				if saved.chant_stage >= 0 and (hooks == null or saved.chant_stage >= hooks.chant_stages.size()):
					return Result.failure(Result.Outcome.INVALID_SNAPSHOT, path + ".memory.chant", "not one of its chant's stages")
			entries.append(OldPineRestoredNpcEntry.new(
				runtime,
				Vector2(saved.map_position.x, saved.map_position.y),
			))
	if saved_by_point.size() != entries.size():
		return Result.failure(
			Result.Outcome.INCONSISTENT_SPAWN_STATE,
			"npc_spawn_states",
			"unknown authored spawn slot",
		)
	return OldPineWorldRestoreResult.new(
		Result.Outcome.SUCCESS,
		"",
		"",
		null,
		OldPineWorldRestorePreparation.new(
			null, Vector2.ZERO, null, null, null, null, null, null, entries,
		),
	)


static func _restore_corpses(
	snapshot: GameSaveSnapshot,
	domain: NativeItemDomainState,
	saved_player: Values.PlayerRuntimeSnapshot,
	npc_states: Array[Values.NpcSpawnStateSnapshot],
	items: NativeItemStateSnapshot,
) -> OldPineWorldRestoreResult:
	var item_records: Dictionary[StringName, NativeItemRecord] = {}
	for item: NativeItemRecord in items.item_records:
		item_records[item.item_instance_id] = item
	var character_facts: Dictionary[StringName, Variant] = {
		saved_player.character_id: saved_player,
	}
	for npc: Values.NpcSpawnStateSnapshot in npc_states:
		character_facts[npc.character_id] = npc
	var entries: Array[OldPineRestoredCorpseEntry] = []
	for saved: Values.CorpseSnapshot in snapshot.corpses:
		var path: String = "corpses.%s" % String(saved.corpse_item_instance_id)
		var known: bool = character_facts.has(saved.victim_character_id)
		var replaced: NpcDefinition = null if known else _replaced_npc_definition(npc_states, saved.victim_character_id)
		if not known and replaced == null:
			# A summoned, conjured or raised NPC that fell (SummonedNpc): its ID names its definition.
			replaced = GameContent.catalog().npc(SummonedNpc.definition_id_of(saved.victim_character_id))
			if replaced != null and replaced.summoning() == null and replaced.conjuring() == null and replaced.raising() == null:
				replaced = null
		if (
			not item_records.has(saved.corpse_item_instance_id)
			or (not known and replaced == null)
			or not _location_is_current(saved.world_location)
			or saved.decay_stage < CorpseState.Stage.FRESH
			or saved.decay_stage > CorpseState.Stage.FINAL
		):
			return Result.failure(
				Result.Outcome.INCONSISTENT_CORPSE_STATE,
				path,
			)
		var record: NativeItemRecord = item_records[saved.corpse_item_instance_id]
		var parent: ContainmentEndpoint = record.direct_parent
		if (
			record.item_definition_id != CORPSE_DEFINITION_ID
			or parent == null
			or parent.kind != ContainmentEndpoint.Kind.WORLD
			or parent.endpoint_id != saved.world_location.combat_location_id
		):
			return Result.failure(
				Result.Outcome.INCONSISTENT_CORPSE_STATE,
				path + ".item_cross_reference",
			)
		if not known:
			# An NPC its room has since replaced (room.c reset()), or a summoned one: its own
			# record went with it, so the corpse keeps what its definition allows.
			# A raised NPC was named after its own corpse's victim (流氓的僵尸): any name.
			if (
				(saved.victim_display_name != replaced.display_name and not replaced.name_pick().has(saved.victim_display_name) and replaced.raising() == null)
				or (replaced.age_roll() != null and not replaced.age_roll().admits(saved.victim_age))
				or (replaced.age_roll() == null and replaced.has_authored_age and saved.victim_age != replaced.age)
				or (replaced.gender_roll() != null and not replaced.gender_roll().admits(saved.victim_gender))
				or (replaced.gender_roll() == null and replaced.has_authored_gender and saved.victim_gender != replaced.gender)
			):
				return Result.failure(
					Result.Outcome.INCONSISTENT_CORPSE_STATE,
					path + ".victim_facts",
				)
		else:
			var victim: Variant = character_facts[saved.victim_character_id]
			var victim_character: Values.CharacterStateSnapshot = victim.character
			var victim_life: StringName = victim.life_status
			var victim_exists: bool = victim.exists_in_world
			var expected_name: String = saved_player.identity.display_name
			var expected_age: int = saved_player.identity.age
			var expected_weight: int = saved_player.body_facts.body_weight
			# Player capacity is a stored body fact, not current str * 5000.
			var expected_capacity: int = saved_player.body_facts.maximum_encumbrance
			if victim is Values.NpcSpawnStateSnapshot:
				var victim_npc: Values.NpcSpawnStateSnapshot = victim
				var definition: NpcDefinition = GameContent.catalog().npc(
					victim_npc.npc_definition_id
				)
				if definition == null:
					return Result.failure(Result.Outcome.UNKNOWN_CONTENT_ID, path)
				expected_name = definition.display_name
				expected_age = victim_npc.age
				expected_weight = victim_npc.body_weight
				# Preserve the existing NPC validation policy (not a Player body change).
				expected_capacity = CharacterDerivedValues.maximum_encumbrance(victim_character.attributes.strength)
			# wgargoyle.c reincarnate(): the player lives on and their former body stays
			# where they fell, so a player's corpse may outlive the death. An NPC's may not.
			var victim_is_player: bool = not victim is Values.NpcSpawnStateSnapshot
			if (
				(not victim_is_player and (victim_life != &"dead" or victim_exists))
				or saved.victim_display_name != expected_name
				or saved.victim_gender != victim_character.gender
				or saved.victim_age != expected_age
				or saved.maximum_contents_encumbrance != expected_capacity
				or record.own_weight != expected_weight
			):
				return Result.failure(
					Result.Outcome.INCONSISTENT_CORPSE_STATE,
					path + ".victim_facts",
				)
		var corpse: CorpseState = CorpseState.new(
			saved.corpse_item_instance_id,
			saved.victim_character_id,
			saved.victim_display_name,
			saved.victim_gender,
			saved.victim_age,
			saved.maximum_contents_encumbrance,
		)
		for worn: Values.CorpseWornItemSnapshot in saved.worn_items:
			if not item_records.has(worn.item_instance_id):
				return Result.failure(
					Result.Outcome.INCONSISTENT_CORPSE_STATE,
					path + ".worn_items",
				)
			var worn_record: NativeItemRecord = item_records[worn.item_instance_id]
			var worn_parent: ContainmentEndpoint = worn_record.direct_parent
			var armor_definition: ArmorDefinition = (
				GameContent.catalog().native_item_projections().armor_definition(
					worn_record.item_definition_id
				)
			)
			if (
				worn_parent == null
				or worn_parent.kind != ContainmentEndpoint.Kind.ITEM
				or worn_parent.endpoint_id != saved.corpse_item_instance_id
				or armor_definition == null
				or armor_definition.armor_type != worn.armor_type
				or not corpse._try_wear(
					worn.armor_type,
					worn.item_instance_id,
					domain.inventory,
				)
			):
				return Result.failure(
					Result.Outcome.INCONSISTENT_CORPSE_STATE,
					path + ".worn_items",
				)
		for stage: int in range(CorpseState.Stage.ROTTEN, saved.decay_stage + 1):
			if not corpse._apply_next_decay_stage(stage):
				return Result.failure(
					Result.Outcome.RECONSTRUCTION_FAILED,
					path + ".decay_stage",
				)
		var entry := OldPineRestoredCorpseEntry.new(
			corpse,
			_location(saved.world_location),
			Vector2(saved.map_position.x, saved.map_position.y),
		)
		entry.age_ms = saved.age_ms
		entries.append(entry)
	return OldPineWorldRestoreResult.new(
		Result.Outcome.SUCCESS,
		"",
		"",
		null,
		OldPineWorldRestorePreparation.new(
			null, Vector2.ZERO, null, null, null, null, null, null, [], entries,
		),
	)


## Every item lying on a floor (WORLD parent) is a corpse, a floor-spawn item in
## its own zone (on its marker), or a dropped item with a place (floor_items);
## a dropped item's place is the zone its record names.
static func _check_floor_items(snapshot: GameSaveSnapshot, corpse_entries: Array[OldPineRestoredCorpseEntry], items: NativeItemStateSnapshot) -> OldPineWorldRestoreResult:
	var dropped: Dictionary[StringName, Values.FloorItemSnapshot] = {}
	for record: Values.FloorItemSnapshot in snapshot.floor_items:
		if record == null or dropped.has(record.item_instance_id) or not _location_is_current(record.world_location) or not record.map_position.has_finite_coordinates():
			return Result.failure(Result.Outcome.INVALID_SNAPSHOT, "floor_items", "invalid or duplicate record")
		dropped[record.item_instance_id] = record
	var corpse_ids: Dictionary[StringName, bool] = {}
	for entry: OldPineRestoredCorpseEntry in corpse_entries:
		corpse_ids[entry.state.corpse_item_instance_id] = true
	var spawn_zones: Dictionary[StringName, StringName] = {}
	var scope: StringName = snapshot.item_id_allocator.scope
	for spawn: ItemSpawnDefinition in GameContent.catalog().item_spawns():
		for point_id: StringName in spawn.spawn_point_ids():
			spawn_zones[ItemSpawnDefinition.item_instance_id(scope, point_id)] = spawn.zone_id
	for record: NativeItemRecord in items.item_records:
		var parent: ContainmentEndpoint = record.direct_parent
		var id: StringName = record.item_instance_id
		if dropped.has(id):
			if parent == null or parent.kind != ContainmentEndpoint.Kind.WORLD or parent.endpoint_id != dropped[id].world_location.combat_location_id:
				return Result.failure(Result.Outcome.INVALID_SNAPSHOT, "floor_items.%s" % String(id), "not on that floor")
			dropped.erase(id)
		elif parent != null and parent.kind == ContainmentEndpoint.Kind.WORLD and not corpse_ids.has(id):
			var zone: ZoneDefinition = GameContent.catalog().zone(spawn_zones.get(id, &""))
			if zone == null or zone.combat_location_id != parent.endpoint_id:
				return Result.failure(Result.Outcome.INVALID_SNAPSHOT, "items.%s" % String(id), "on a floor without a place")
	if not dropped.is_empty():
		return Result.failure(Result.Outcome.INVALID_SNAPSHOT, "floor_items", "names an item that does not exist")
	return null


## The definition of the spawn whose saved NPC is a later generation than
## `victim_id` (NpcGeneration), or null.
static func _replaced_npc_definition(npc_states: Array[Values.NpcSpawnStateSnapshot], victim_id: StringName) -> NpcDefinition:
	for npc: Values.NpcSpawnStateSnapshot in npc_states:
		var earlier: int = NpcGeneration.of(victim_id, npc.spawn_point_id)
		if earlier > 0 and earlier < NpcGeneration.of(npc.character_id, npc.spawn_point_id):
			# Of a spawn whose NPC draws its name: the replacement may have drawn another.
			return GameContent.catalog().npc(NpcDefinition.unnamed_id(npc.npc_definition_id))
	return null


static func _loadout_matches(
	saved: Values.NpcSpawnStateSnapshot,
	definition: NpcDefinition,
	item_index: WorldItemInstanceIndex,
	global_ids: Dictionary[StringName, bool],
	snapshot_scope: StringName,
	item_ids: PackedStringArray,
) -> bool:
	var expected_counts: Dictionary[StringName, int] = {}
	# Either side of a carry choice may have been drawn (worker2.c's hammer or rope).
	for authored: NpcLoadoutEntry in definition.loadout_entries():
		for entry: NpcLoadoutEntry in authored.possible_entries():
			var content: ItemContentDefinition = (
				GameContent.catalog().item(entry.item_definition_id)
			)
			if content == null:
				return false
			var instance_count: int = 1 if content.stack_definition() != null else entry.quantity
			expected_counts[entry.item_definition_id] = (
				expected_counts.get(entry.item_definition_id, 0) + instance_count
			)
	var resolved_ids: Array[StringName] = []
	for item_id: StringName in saved.live_loadout_item_ids:
		if global_ids.has(item_id):
			return false
		var item: ItemInstance = item_index.resolve(item_id)
		if item == null:
			return false
		# A weapon bash_weapon() broke is still the loadout's object (断掉的); a book is its
		# item whichever name it drew (book.c).
		var kind: StringName = ItemContentDefinition.unnamed_id(ItemContentDefinition.unbroken_id(item.item_definition_id))
		var remaining: int = expected_counts.get(kind, 0)
		if remaining <= 0:
			return false
		expected_counts[kind] = remaining - 1
		resolved_ids.append(item_id)
	# Only the represented surviving subset is required: a dead spawn's items may
	# have been looted or destroyed, and a living NPC gives and drops things too
	# (drunk.c drops its emptied wineskin, which may then be sold). A living NPC
	# lists every loadout item that still exists, as the capture does.
	var prefix: String = ("" if snapshot_scope.is_empty() else String(snapshot_scope) + ".") + String(saved.character_id) + ".loadout."
	# `item_ids` is item_index.snapshot_ids(), sorted: the ids with this prefix lie together.
	if saved.life_status != &"dead":
		var at: int = item_ids.bsearch(prefix)
		while at < item_ids.size() and item_ids[at].begins_with(prefix):
			if not resolved_ids.has(StringName(item_ids[at])):
				return false
			at += 1
	for item_id: StringName in resolved_ids:
		global_ids[item_id] = true
	return true


static func _character_aggregate_ids_match(
	domain: NativeItemDomainState,
	expected_ids: Array[StringName],
) -> bool:
	var expected: Array[StringName] = expected_ids.duplicate()
	expected.sort_custom(_string_name_less_than)
	return (
		domain.equipment_character_ids() == expected
		and domain.armor_character_ids() == expected
	)


## The spawns of the saved world: the technical fixture world has Old Pine's
## maps only (WorldSessionController.world_map_ids_for).
static func _world_spawns(revision: WorldContentRevision.Value) -> Array[NpcSpawnDefinition]:
	var map_ids: Array[StringName] = WorldSessionController.world_map_ids_for(revision)
	var result: Array[NpcSpawnDefinition] = []
	for spawn: NpcSpawnDefinition in GameContent.catalog().spawns():
		if map_ids.has(spawn.map_id):
			result.append(spawn)
	return result


static func _player_location_is_current(value: Values.WorldLocationSnapshot, revision: WorldContentRevision.Value) -> bool:
	if value == null or (revision != WorldContentRevision.CURRENT_PUBLIC and value.region_id != OldPineWorldDefinitions.REGION_ID):
		return false
	return _location_is_current(value)


## A zone of the current content, on its own map and region.
## Whether an NPC of `definition` living in `home_zone_id` can have come to `zone_id` on
## another map: it can leave home — it wanders (random_move, in a mood too: 刘老农 in his
## grief), walks out of a fight (go.c) or is called over (a COMES act: the 瓜农 out of his
## 瓜棚, a map of its own since the remap) — the zone is home or next door, and a portal leads
## into it from home or next door.
static func _wandered_to(definition: NpcDefinition, home_zone_id: StringName, zone_id: StringName) -> bool:
	var catalog: ContentCatalog = GameContent.catalog()
	var talks: Array[NpcTalk] = [definition.talk()]
	if definition.hooks() != null:
		for mood: NpcMood in definition.hooks().moods.values():
			if mood.talk != null:
				talks.append(mood.talk)
	var leaves: bool = catalog.called_over(definition.definition_id)
	for talk: NpcTalk in talks:
		leaves = leaves or talk.chat_entries().has(NpcTalk.RANDOM_MOVE) or talk.combat_chat_entries().has(NpcTalk.RANDOM_MOVE)
	if not leaves:
		return false
	if zone_id != home_zone_id and not catalog.zones_adjacent(home_zone_id, zone_id):
		return false
	for portal: PortalDefinition in catalog.portals():
		if portal.destination_zone_id == zone_id and (portal.source_zone_id == home_zone_id or catalog.zones_adjacent(home_zone_id, portal.source_zone_id)):
			return true
	return false


static func _location_is_current(value: Values.WorldLocationSnapshot) -> bool:
	var zone: ZoneDefinition = null if value == null else GameContent.catalog().zone(value.zone_id)
	var map: MapDefinition = null if zone == null else GameContent.catalog().map(zone.map_id)
	return (
		map != null
		and map.region_id == value.region_id
		and zone.map_id == value.map_id
		and zone.combat_location_id == value.combat_location_id
	)


static func _location(value: Values.WorldLocationSnapshot) -> WorldLocationState:
	return WorldLocationState.new(
		value.region_id,
		value.map_id,
		value.zone_id,
		value.combat_location_id,
	)


static func _life_status(value: StringName) -> int:
	match value:
		&"active":
			return CharacterRuntimeLifeStatus.Value.ACTIVE
		&"unconscious":
			return CharacterRuntimeLifeStatus.Value.UNCONSCIOUS
		&"dead":
			return CharacterRuntimeLifeStatus.Value.DEAD
	return -1


static func _string_name_less_than(left: StringName, right: StringName) -> bool:
	return String(left) < String(right)
