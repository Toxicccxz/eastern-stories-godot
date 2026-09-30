class_name OldPineWorldSessionController
extends WorldResidentMapCoordinator

const PLAYER_ID: StringName = &"oldpine.player"
## Retained internal Old Pine/CXR regression bootstrap, not public New Game
## or an LPC formula. SOURCE_ENTRY and RESTORE never enter this initializer.
const NEW_GAME_COMBAT_EXPERIENCE: int = 600
const WorldPlayerRuntimeType := preload(
	"res://runtime/characters/world_player_runtime_state.gd"
)
const SessionItemIdScopeFactoryType := preload(
	"res://core/persistence/session_item_id_scope_factory.gd"
)

enum BootstrapMode {
	NEW_GAME,
	RESTORE,
	SOURCE_ENTRY,
}

@export var deterministic_npc_seed: bool = false
@export var npc_seed: int = 7_021
@export var deterministic_combat_seed: bool = false
@export var combat_seed: int = 5_232
@export var deterministic_world_interaction_seed: bool = false
@export var world_interaction_seed: int = 93_232


var _inventory: InventoryState
var _stacks: CombinedStackCollection
var _foods: FoodCollection = FoodCollection.new()
var _liquids: LiquidCollection = LiquidCollection.new()
var _item_index: WorldItemInstanceIndex
var _npc_random: NpcInitializationRandomSource
var _combat_random: CombatRandomSource
var _world_interaction_random: WorldInteractionRandomSource
var _item_instance_scope: StringName = &""
var _item_id_allocator: SessionItemIdAllocator
var _combat_encounter_coordinator: CombatEncounterCoordinator
var _bootstrap_mode: int = BootstrapMode.NEW_GAME
var _world_content_revision: WorldContentRevision.Value = WorldContentRevision.Value.LEGACY_OLDPINE_V1
var _restore_preparation: OldPineWorldRestorePreparation
var _restore_failure_outcome: int = OldPineWorldRestoreResult.Outcome.SUCCESS
var _restore_candidate_staged: bool = false
var _session_swap_suspended: bool = false
var _session_swap_reparenting: bool = false
var _source_name: String = ""
var _source_gender: StringName = &""
var _recovery_random: RecoveryCadenceRandomSource
var _player_recovery_cadence: PlayerRecoveryCadence
var _life_flow: PlayerLifeFlow = PlayerLifeFlow.new()
var _last_revival_handoff: OldPineMapHandoffResult


func _ready() -> void:
	if initialize_session():
		shared_ui().configure(player_runtime())
		shared_ui().initialize_supplies()


func shared_ui() -> SharedGameplayUI:
	return get_node("SharedGameplayUI") as SharedGameplayUI


func liquid_interaction_available() -> bool:
	if not application_gameplay_allows_encounter_advance() or not can_process() or _restore_candidate_staged or _session_swap_reparenting or _transitioning:
		return false
	var map: WorldResidentMapController = active_map()
	return _world_content_revision == WorldContentRevision.CURRENT_PUBLIC and world_simulation_gate().is_open() and map != null and map.is_map_initialized() and map.runtime_player_body() != null and map.runtime_player_body().player_controlled and _player.exists_in_world and _player.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE


## A water service (resource/water) of the active map is within reach.
func fill_water_available() -> bool:
	var map: WorldMapController = active_map() as WorldMapController
	return liquid_interaction_available() and map != null and map.water_available()


func food_collection() -> FoodCollection:
	return _foods


func liquid_collection() -> LiquidCollection:
	return _liquids


func _process(delta: float) -> void:
	# Inspect before combat advances: a combat-ending frame is not world time.
	advance_player_recovery(delta)
	if _initialized and _combat_encounter_coordinator != null:
		_combat_encounter_coordinator.advance_scheduler(delta)
	_advance_life_flow(delta)


## One transient authority across every resident. Injection is pre-initialization only.
func configure_recovery_random_source(value: RecoveryCadenceRandomSource) -> bool:
	if value == null or _player_recovery_cadence != null or _initialized:
		return false
	_recovery_random = value
	return true


func player_recovery_cadence() -> PlayerRecoveryCadence:
	return _player_recovery_cadence


func _initialize_player_recovery() -> bool:
	if _world_content_revision != WorldContentRevision.CURRENT_PUBLIC:
		return true
	if _player_recovery_cadence == null:
		if _recovery_random == null:
			_recovery_random = GodotRecoveryCadenceRandomSource.new()
		_player_recovery_cadence = PlayerRecoveryCadence.new(_recovery_random)
	return _player_recovery_cadence.is_valid()


## S5B staged path: no combat/conditions/lifecycle execution. Busy is NOT a time gate.
func player_recovery_time_allowed() -> bool:
	if (
		_world_content_revision != WorldContentRevision.CURRENT_PUBLIC
		or not application_gameplay_allows_encounter_advance()
		or not can_process() or _restore_candidate_staged
		or _session_swap_reparenting or _transitioning
		or _player_recovery_cadence == null or _player == null
		or not _player.exists_in_world
		or _player.life_status != CharacterRuntimeLifeStatus.Value.ACTIVE
	):
		return false
	# Separate documented omissions, not a claim gate.is_open alone means eligibility.
	if _combat_encounter_coordinator.has_active_encounter() or _player.relationship.is_fighting():
		return false
	if _player.state.conditions.size() != 0 or not _world_simulation_gate.is_open():
		return false
	if _last_map_handoff != null and not _last_map_handoff.succeeded():
		if _last_map_handoff.location_committed or (_last_map_handoff.source_detached and not _last_map_handoff.source_restored):
			return false
	var map: WorldResidentMapController = active_map()
	var location: WorldLocationState = _player.world_location()
	return (
		map != null and map.is_inside_tree() and map.can_process()
		and map.get_parent() == active_map_slot and active_map_child_count() == 1
		and location != null and location.map_id == _active_map_id
		and map.runtime_player_body() != null and map.runtime_player_body().is_inside_tree()
	)


func advance_player_recovery(delta: float) -> PlayerRecoveryCadenceResult:
	if not player_recovery_time_allowed():
		var frozen: PlayerRecoveryCadenceResult = PlayerRecoveryCadenceResult.new()
		frozen.outcome = PlayerRecoveryCadenceResult.Outcome.FROZEN
		return frozen
	return _player_recovery_cadence.advance(delta, _player.state, _player.busy)


func _exit_tree() -> void:
	if _session_swap_reparenting:
		return
	for map_id: StringName in _resident_maps.keys():
		var value: Variant = _resident_maps.get(map_id)
		if not is_instance_valid(value):
			continue
		var resident: WorldResidentMapController = (
			value as WorldResidentMapController
		)
		if resident != null and resident.get_parent() == null:
			resident.free()
	_resident_maps.clear()


func initialize_session() -> bool:
	if _initialized:
		return true
	if active_map_slot == null:
		return false
	# No world is built on unreadable or inconsistent content data.
	if not GameContent.load_errors().is_empty():
		return false
	if _bootstrap_mode == BootstrapMode.RESTORE:
		if not _initialize_restore_authorities():
			_restore_failure_outcome = OldPineWorldRestoreResult.Outcome.RECONSTRUCTION_FAILED
			return false
	elif not _initialize_authorities():
		return false
	_world_simulation_gate = WorldSimulationGate.new()
	_combat_encounter_coordinator = CombatEncounterCoordinator.new(
		self,
		_world_simulation_gate,
	)
	# The technical fixture world is Old Pine alone; the public world adds Snow.
	var map_ids: Array[StringName] = [OldPineWorldDefinitions.CAVE_MAP_ID, OldPineWorldDefinitions.OUTDOOR_MAP_ID]
	if _world_content_revision == WorldContentRevision.CURRENT_PUBLIC:
		map_ids.append_array([SnowWorldDefinitions.INN_MAP_ID, SnowWorldDefinitions.OUTDOOR_MAP_ID])
	for map_id: StringName in map_ids:
		if not _register_map(map_id):
			return false
	var cave: WorldResidentMapController = _resident_maps[OldPineWorldDefinitions.CAVE_MAP_ID]
	var outdoor: WorldResidentMapController = _resident_maps[OldPineWorldDefinitions.OUTDOOR_MAP_ID]

	if _bootstrap_mode == BootstrapMode.RESTORE:
		return _initialize_restore_residents()
	if _bootstrap_mode == BootstrapMode.SOURCE_ENTRY:
		return _initialize_source_residents()

	# Ready-time binding is performed once for both resident maps. The inactive
	# cave is then detached without being freed or simulated.
	cave.process_mode = Node.PROCESS_MODE_DISABLED
	active_map_slot.add_child(cave)
	if not cave.initialize_map():
		return false
	cave.prepare_for_deactivation()
	active_map_slot.remove_child(cave)
	cave.process_mode = Node.PROCESS_MODE_INHERIT

	active_map_slot.add_child(outdoor)
	if not outdoor.initialize_map() or not outdoor.complete_activation():
		return false
	_active_map_id = outdoor.map_id()
	_initialized = true
	return _reconcile_active_residents()


## Public ApplicationShell/Host selects SOURCE_ENTRY before tree attachment.
func configure_source_entry(display_name: String, gender: StringName) -> bool:
	if is_inside_tree() or _initialized or _bootstrap_mode != BootstrapMode.NEW_GAME:
		return false
	if display_name.strip_edges().is_empty() or gender not in [CharacterState.GENDER_MALE, CharacterState.GENDER_FEMALE]:
		return false
	_source_name = display_name
	_source_gender = gender
	_bootstrap_mode = BootstrapMode.SOURCE_ENTRY
	_world_content_revision = WorldContentRevision.CURRENT_PUBLIC
	return true


func configure_restore(preparation: OldPineWorldRestorePreparation) -> bool:
	if (
		is_inside_tree()
		or _initialized
		or _bootstrap_mode != BootstrapMode.NEW_GAME
		or preparation == null
		or not preparation.is_valid()
	):
		return false
	_bootstrap_mode = BootstrapMode.RESTORE
	_restore_preparation = preparation
	_world_content_revision = preparation.world_content_revision
	process_mode = Node.PROCESS_MODE_DISABLED
	return true


func world_content_revision() -> WorldContentRevision.Value:
	return _world_content_revision


func bootstrap_mode() -> int:
	return _bootstrap_mode


func is_initialized() -> bool:
	return _initialized


func is_restore_candidate_staged() -> bool:
	return _restore_candidate_staged


func restore_failure_outcome() -> int:
	return _restore_failure_outcome


func restored_player_position() -> Vector2:
	return Vector2.ZERO if _restore_preparation == null else _restore_preparation.player_position


func restored_npc_entries() -> Array[OldPineRestoredNpcEntry]:
	return [] if _restore_preparation == null else _restore_preparation.npc_entries()


func restored_corpse_entries() -> Array[OldPineRestoredCorpseEntry]:
	return [] if _restore_preparation == null else _restore_preparation.corpse_entries()


func activate_restore_candidate() -> bool:
	if (
		_bootstrap_mode != BootstrapMode.RESTORE
		or not _initialized
		or not _restore_candidate_staged
	):
		return false
	var map: WorldResidentMapController = active_map()
	if map == null:
		return false
	process_mode = Node.PROCESS_MODE_INHERIT
	map.set_restore_staging(false)
	if not map.complete_activation() or not _reconcile_active_residents():
		map.prepare_for_deactivation()
		map.set_restore_staging(true)
		process_mode = Node.PROCESS_MODE_DISABLED
		_restore_failure_outcome = OldPineWorldRestoreResult.Outcome.ACTIVATION_FAILED
		return false
	map.resume_after_relationship_reconciliation()
	if not _initialize_player_recovery():
		map.prepare_for_deactivation()
		map.set_restore_staging(true)
		process_mode = Node.PROCESS_MODE_DISABLED
		return false
	_restore_candidate_staged = false
	_resume_restored_life_flow()
	return true


func player_runtime() -> WorldPlayerRuntimeType:
	return _player


func inventory_state() -> InventoryState:
	return _inventory


func stack_collection() -> CombinedStackCollection:
	return _stacks


func item_instance_index() -> WorldItemInstanceIndex:
	return _item_index


func npc_random_source() -> NpcInitializationRandomSource:
	return _npc_random


func combat_random_source() -> CombatRandomSource:
	return _combat_random


func world_interaction_random_source() -> WorldInteractionRandomSource:
	return _world_interaction_random


func item_instance_scope() -> StringName:
	return _item_instance_scope


func item_id_allocator() -> SessionItemIdAllocator:
	return _item_id_allocator


func world_simulation_gate() -> WorldSimulationGate:
	return _world_simulation_gate


func combat_encounter_coordinator() -> CombatEncounterCoordinator:
	return _combat_encounter_coordinator


func encounter_combat_bindings(
	encounter: CombatEncounter,
) -> Array[CombatSliceCharacterBinding]:
	var map: WorldResidentMapController = active_map()
	return [] if map == null else map.encounter_combat_bindings(encounter)


## Content presentation lookup; semantic IDs remain independent of scene names.
func encounter_display_name(character_id: StringName) -> String:
	if _player != null and character_id == _player.character_id:
		return _player.facts.display_name
	var npc: NpcRuntimeState = _find_resident_npc(character_id)
	return String(character_id) if npc == null else npc.definition().display_name


func encounter_skill_effect_registry() -> SkillImprovementEffectRegistry:
	var map: WorldResidentMapController = active_map()
	return null if map == null else map.encounter_skill_effect_registry()


## One combat round per ES2 heart_beat, on every map (common/pacing.json).
func encounter_opportunity_interval_seconds() -> float:
	return GameContent.catalog().pacing().combat_round_seconds


func application_gameplay_allows_encounter_advance() -> bool:
	var tree: SceneTree = get_tree() if is_inside_tree() else null
	return (
		_initialized
		and not _session_swap_suspended
		and process_mode != Node.PROCESS_MODE_DISABLED
		and tree != null
		and not tree.paused
	)


func resolve_encounter_binding(
	character_id: StringName,
) -> CombatEncounterAuthorityBinding:
	if not _initialized or character_id.is_empty():
		return null
	if _player != null and character_id == _player.character_id:
		return CombatEncounterAuthorityBinding.new(
			character_id,
			_player.state,
			_player.relationship,
			_player.busy,
			_player.armor,
		)
	var npc: NpcRuntimeState = _find_resident_npc(character_id)
	if npc == null:
		return null
	return CombatEncounterAuthorityBinding.new(
		character_id,
		npc.character_state,
		npc.relationship,
		npc.busy,
		npc.armor,
	)


func resolve_encounter_location(character_id: StringName) -> WorldLocationState:
	return _location_for_character(character_id)


func encounter_participant_is_available(character_id: StringName) -> bool:
	if _player != null and character_id == _player.character_id:
		return (
			_player.exists_in_world
			and _player.combat_available
			and _player.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE
		)
	var npc: NpcRuntimeState = _find_resident_npc(character_id)
	return (
		npc != null
		and npc.exists_in_map
		and npc.combat_available
		and npc.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE
	)


func freeze_world_for_encounter(encounter_id: StringName) -> bool:
	var map: WorldResidentMapController = active_map()
	return (
		_initialized
		and not _transitioning
		and _world_simulation_gate != null
		and _world_simulation_gate.freeze_owner_id() == encounter_id
		and map != null
		and map.freeze_world_gameplay(encounter_id)
	)


func thaw_world_after_encounter(encounter_id: StringName) -> bool:
	var map: WorldResidentMapController = active_map()
	return (
		_initialized
		and _world_simulation_gate != null
		and _world_simulation_gate.freeze_owner_id() == encounter_id
		and map != null
		and map.thaw_world_gameplay(encounter_id)
	)


func active_map() -> WorldResidentMapController:
	return _resident_maps.get(_active_map_id)


func resident_map(map_id: StringName) -> WorldResidentMapController:
	return _resident_maps.get(map_id)


func world_map_of(map_id: StringName) -> WorldMapController:
	return _resident_maps.get(map_id) as WorldMapController


## Every resident map, in content order (stable for saves).
func world_maps() -> Array[WorldMapController]:
	var result: Array[WorldMapController] = []
	for definition: MapDefinition in GameContent.catalog().maps():
		var map: WorldMapController = world_map_of(definition.map_id)
		if map != null:
			result.append(map)
	return result


## Every resident NPC, map by map in spawn order.
func world_npcs() -> Array[NpcRuntimeState]:
	var result: Array[NpcRuntimeState] = []
	for map: WorldMapController in world_maps():
		result.append_array(map.npc_runtimes())
	return result


func is_session_swap_suspended() -> bool:
	return _session_swap_suspended


func configure_combat_random_source(value: CombatRandomSource) -> bool:
	if value == null:
		return false
	_combat_random = value
	for map: WorldResidentMapController in _resident_maps.values():
		if not map.replace_combat_random_source(value):
			return false
	return true


func configure_world_interaction_random_source(
	value: WorldInteractionRandomSource,
) -> bool:
	if value == null:
		return false
	_world_interaction_random = value
	for map: WorldResidentMapController in _resident_maps.values():
		if not map.replace_world_interaction_random_source(value):
			return false
	return true


func suspend_for_session_swap() -> bool:
	if (
		not _initialized
		or _transitioning
		or _session_swap_suspended
		or active_map_slot == null
		or active_map_slot.get_child_count() != 1
	):
		return false
	var map: WorldResidentMapController = active_map()
	if map == null or not map.suspend_for_session_swap():
		return false
	map.set_restore_staging(true)
	process_mode = Node.PROCESS_MODE_DISABLED
	_session_swap_suspended = true
	return true


func resume_after_failed_session_swap() -> bool:
	if not _session_swap_suspended:
		return false
	var map: WorldResidentMapController = active_map()
	if map == null:
		return false
	process_mode = Node.PROCESS_MODE_INHERIT
	map.set_restore_staging(false)
	if not map.resume_after_session_swap_rollback():
		map.set_restore_staging(true)
		process_mode = Node.PROCESS_MODE_DISABLED
		return false
	_session_swap_suspended = false
	return true


func begin_session_swap_reparent() -> bool:
	if (
		_bootstrap_mode != BootstrapMode.RESTORE
		or not _initialized
		or _session_swap_reparenting
	):
		return false
	_session_swap_reparenting = true
	return true


func complete_session_swap_reparent() -> void:
	_session_swap_reparenting = false


func _initialize_authorities() -> bool:
	_item_instance_scope = _new_item_instance_scope()
	_item_id_allocator = SessionItemIdAllocator.new(_item_instance_scope)
	if not _item_id_allocator.is_valid():
		return false
	_npc_random = GodotNpcInitializationRandomSource.new(
		npc_seed,
		deterministic_npc_seed,
	)
	_combat_random = GodotCombatRandomSource.new(
		combat_seed,
		deterministic_combat_seed,
	)
	_world_interaction_random = GodotWorldInteractionRandomSource.new(
		world_interaction_seed,
		deterministic_world_interaction_seed,
	)
	if _bootstrap_mode == BootstrapMode.SOURCE_ENTRY:
		var birth: NewPlayerInventoryComposition = NewPlayerInventoryComposition.new()
		if not birth.initialize(PLAYER_ID, _source_gender, _source_name, _item_id_allocator):
			return false
		_inventory = birth.inventory
		_stacks = birth.stacks
		_item_index = birth.item_index
		_player = NewPlayerRuntimeComposition.create(PLAYER_ID, birth.player, SnowWorldDefinitions.birth_location())
		return _player != null
	_inventory = InventoryState.new()
	_stacks = CombinedStackCollection.new()
	_item_index = WorldItemInstanceIndex.new()
	var prototype: CombatSliceCharacterBinding = CombatSliceDemoFactory.create_player()
	var start_zone: ZoneDefinition = GameContent.catalog().zone(
		OldPineWorldDefinitions.CENTRAL_CLEARING_ZONE_ID
	)
	if prototype == null or start_zone == null:
		return false
	prototype.state.progression.combat_experience = NEW_GAME_COMBAT_EXPERIENCE
	_player = WorldPlayerRuntimeType.new(
		PLAYER_ID,
		prototype.state,
		CombatRelationshipState.new(PLAYER_ID),
		ActionBusyState.new(),
		ArmorState.new(),
		WorldLocationState.new(
			OldPineWorldDefinitions.REGION_ID,
			OldPineWorldDefinitions.OUTDOOR_MAP_ID,
			start_zone.zone_id,
			start_zone.combat_location_id,
		),
		CharacterRuntimeLifeStatus.Value.ACTIVE,
		true,
		true,
		PlayerBodyFacts.fresh_human(
			prototype.state.attributes.strength
		),
	)
	var demo_primary: EquippedWeaponRef = _player.state.equipment.primary_weapon()
	if demo_primary == null:
		return false
	if not _player.state.equipment.unwield(demo_primary.instance_id).succeeded:
		return false
	var definition: WeaponDefinition = WeaponDefinition.new(
		CombatSliceContentProfile.LONG_SWORD_ID,
		CombatSliceContentProfile.LONG_SWORD_SKILL_ID,
		false,
		false,
		CombatSliceContentProfile.LONG_SWORD_SOURCE,
	)
	var primary: EquippedWeaponRef = EquippedWeaponRef.new(
		StringName("%s.player-long-sword" % String(_item_instance_scope)),
		definition,
	)
	if not _player.state.equipment.wield(primary, false).succeeded:
		return false
	var player_item: ItemInstance = ItemInstance.new(primary.instance_id, primary.weapon_id)
	if (
		not _inventory.register_item(
			player_item,
			CombatSliceContentProfile.LONG_SWORD_WEIGHT,
		)
		or not _item_index.register_snapshot(player_item)
	):
		return false
	var destination: InventoryTransferDestination = InventoryTransferDestination.new(
		ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, PLAYER_ID),
		true,
		true,
		_player.maximum_encumbrance,
	)
	return InventoryTransferService.new().transfer(
		_inventory,
		player_item.item_instance_id,
		destination,
	).succeeded


func _initialize_restore_authorities() -> bool:
	if _restore_preparation == null or not _restore_preparation.is_valid():
		return false
	_player = _restore_preparation.player
	_inventory = _restore_preparation.item_domain.inventory
	_stacks = _restore_preparation.item_domain.combined_stacks
	_foods = _restore_preparation.item_domain.food_collection
	_liquids = _restore_preparation.item_domain.liquid_collection
	_item_index = _restore_preparation.item_index
	_item_id_allocator = _restore_preparation.item_allocator
	_item_instance_scope = _item_id_allocator.scope
	_npc_random = _restore_preparation.npc_random
	_combat_random = _restore_preparation.combat_random
	_world_interaction_random = _restore_preparation.world_interaction_random
	return true


func _initialize_source_residents() -> bool:
	var inn: WorldResidentMapController = _resident_maps[SnowWorldDefinitions.INN_MAP_ID]
	# Four maps bind the same authority graph. Fresh source entry alone starts in Inn.
	for map: WorldResidentMapController in _residents_in_initialization_order():
		map.set_restore_staging(true)
		active_map_slot.add_child(map)
		if not map.initialize_map():
			return false
		map.prepare_for_deactivation()
		map.set_restore_staging(true)
		active_map_slot.remove_child(map)
	_active_map_id = inn.map_id()
	inn.set_restore_staging(false)
	active_map_slot.add_child(inn)
	if not inn.complete_activation():
		return false
	_initialized = true
	return _reconcile_active_residents() and _initialize_player_recovery()


func _instantiate_map(map_id: StringName) -> Node:
	var map: MapDefinition = GameContent.catalog().map(map_id)
	var scene: PackedScene = null if map == null else load(map.scene_path) as PackedScene
	return null if scene == null else scene.instantiate()


## Every map of the session shares one authority graph; passages open toward
## the maps registered here.
func _register_map(map_id: StringName) -> bool:
	var map: WorldMapController = _instantiate_map(map_id) as WorldMapController
	if map == null or not map.configure_session(self) or not map.configure_world_authorities(_player, _inventory, _stacks, _item_index,
		_npc_random, _combat_random, _world_interaction_random, _item_id_allocator, _world_simulation_gate, _foods, _liquids) or not register_resident_map(map):
		return false
	map.tree_exiting.connect(_on_resident_map_tree_exiting.bind(map.map_id()))
	return true


## Old Pine first: its spawns draw from the NPC random source in this order.
func _residents_in_initialization_order() -> Array[WorldResidentMapController]:
	var result: Array[WorldResidentMapController] = []
	for map_id: StringName in [OldPineWorldDefinitions.CAVE_MAP_ID, OldPineWorldDefinitions.OUTDOOR_MAP_ID, SnowWorldDefinitions.OUTDOOR_MAP_ID, SnowWorldDefinitions.INN_MAP_ID]:
		if _resident_maps.has(map_id):
			result.append(_resident_maps[map_id])
	return result


func _initialize_restore_residents() -> bool:
	for resident: WorldResidentMapController in _residents_in_initialization_order():
		resident.set_restore_staging(true)
		active_map_slot.add_child(resident)
		if not resident.initialize_map():
			_restore_failure_outcome = OldPineWorldRestoreResult.Outcome.BODY_BINDING_FAILED
			return false
		# Runtime binding may create fresh interaction Areas (for example CorpseView).
		# Re-apply staging after initialization so the candidate remains fully inert.
		resident.set_restore_staging(true)
		active_map_slot.remove_child(resident)
	var player_location: WorldLocationState = _player.world_location()
	if player_location == null or player_location.map_id not in _resident_maps:
		_restore_failure_outcome = OldPineWorldRestoreResult.Outcome.INVALID_WORLD_LOCATION
		return false
	_active_map_id = player_location.map_id
	var active: WorldResidentMapController = _resident_maps[_active_map_id]
	active_map_slot.add_child(active)
	# Restore is exact placement, never a spawn lookup or an initial Inn activation.
	active.runtime_player_body().global_position = _restore_preparation.player_position
	if not _validate_restore_positions():
		_restore_failure_outcome = OldPineWorldRestoreResult.Outcome.INVALID_PHYSICAL_POSITION
		return false
	_initialized = true
	_restore_candidate_staged = true
	return active_map_slot.get_child_count() == 1


func _validate_restore_positions() -> bool:
	var player_location: WorldLocationState = _player.world_location()
	var player_map: WorldResidentMapController = _resident_maps.get(
		player_location.map_id
	)
	if not MapPlacementValidator.is_valid_character_position(
		player_map,
		player_location.zone_id,
		_restore_preparation.player_position,
	):
		return false
	for entry: OldPineRestoredNpcEntry in _restore_preparation.npc_entries():
		var location: WorldLocationState = entry.runtime.world_location()
		if not MapPlacementValidator.is_valid_character_position(
			_resident_maps.get(location.map_id),
			location.zone_id,
			entry.map_position,
		):
			return false
	for entry: OldPineRestoredCorpseEntry in _restore_preparation.corpse_entries():
		if not MapPlacementValidator.is_valid_corpse_position(
			_resident_maps.get(entry.world_location.map_id),
			entry.world_location.zone_id,
			entry.map_position,
		):
			return false
	return true


func _new_item_instance_scope() -> StringName:
	## The scope is durable data, not a Node ObjectID or a gameplay-RNG draw.
	## Platform cryptographic entropy remains independent across fresh processes;
	## save/load preserves this exact value thereafter.
	return SessionItemIdScopeFactoryType.create_old_pine_scope()


func _on_resident_map_tree_exiting(map_id: StringName) -> void:
	if (
		_initialized
		and not _transitioning
		and not _session_swap_reparenting
		and map_id == _active_map_id
		and not is_queued_for_deletion()
	):
		call_deferred("queue_free")


func _reconcile_active_residents() -> bool:
	if not _reconcile_relationship(_player.relationship):
		return false
	var map: WorldResidentMapController = active_map()
	if map == null:
		return false
	for npc: NpcRuntimeState in map.resident_npcs():
		if not _reconcile_relationship(npc.relationship):
			return false
	return true


func _reconcile_relationship(relationship: CombatRelationshipState) -> bool:
	if relationship == null or not relationship.is_valid():
		return false
	var facts: Array[CombatOpponentAvailabilityFacts] = []
	for opponent_id: StringName in relationship.opponent_ids():
		facts.append(_availability_facts(opponent_id, relationship.owner_character_id))
	var result: CombatOpponentSelectionResult = CombatOpponentSelectionService.prepare(
		relationship,
		facts,
		_combat_random,
	)
	return result.outcome not in [
		CombatOpponentSelectionResult.Outcome.INVALID_AVAILABILITY_PROJECTION,
		CombatOpponentSelectionResult.Outcome.CLEANUP_INVARIANT_FAILURE,
		CombatOpponentSelectionResult.Outcome.RANDOM_SOURCE_MISSING,
		CombatOpponentSelectionResult.Outcome.RANDOM_DRAW_OUT_OF_RANGE,
		CombatOpponentSelectionResult.Outcome.LAST_OPPONENT_INVARIANT_FAILURE,
	]


func _availability_facts(
	opponent_id: StringName,
	owner_id: StringName,
) -> CombatOpponentAvailabilityFacts:
	var opponent_location: WorldLocationState
	var opponent_exists: bool = false
	var opponent_living: bool = false
	if opponent_id == _player.character_id:
		opponent_location = _player.world_location()
		opponent_exists = _player.exists_in_world
		opponent_living = _player.life_status != CharacterRuntimeLifeStatus.Value.DEAD
	else:
		var npc: NpcRuntimeState = _find_resident_npc(opponent_id)
		if npc != null:
			opponent_location = npc.world_location()
			opponent_exists = npc.exists_in_map
			opponent_living = npc.life_status != CharacterRuntimeLifeStatus.Value.DEAD
	var owner_location: WorldLocationState = _location_for_character(owner_id)
	return CombatOpponentAvailabilityFacts.new(
		opponent_id,
		opponent_exists,
		owner_location != null
		and opponent_location != null
		and owner_location.shares_combat_location(opponent_location),
		opponent_living,
	)


func _location_for_character(character_id: StringName) -> WorldLocationState:
	if character_id == _player.character_id:
		return _player.world_location()
	var npc: NpcRuntimeState = _find_resident_npc(character_id)
	return null if npc == null else npc.world_location()


func _find_resident_npc(character_id: StringName) -> NpcRuntimeState:
	for map: WorldResidentMapController in _resident_maps.values():
		var npc: NpcRuntimeState = map.find_resident_npc(character_id)
		if npc != null:
			return npc
	return null


## Portable interaction composition: the current Session and active body own the
## permission, never an inactive Outdoor controller or the displayed row.
func portable_inventory_available() -> bool:
	if not _initialized or not can_process() or not application_gameplay_allows_encounter_advance() or _restore_candidate_staged or _session_swap_suspended or _transitioning:
		return false
	var map: WorldResidentMapController = active_map()
	return map != null and map.is_inside_tree() and map.is_map_initialized() and map.runtime_player_body().player_controlled and _world_simulation_gate.is_open() and not _combat_encounter_coordinator.has_active_encounter() and _player.exists_in_world and _player.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE and not _player.relationship.is_fighting()


func player_inventory_rows() -> Array[PlayerInventoryRowProjection]:
	return PlayerInventoryProjection.new().project_rows(_player, _inventory, _stacks, _item_index)


func wield_player_item(id: StringName) -> OldPineEquipmentInteractionResult:
	if not portable_inventory_available(): return OldPineEquipmentInteractionResult.new()
	_last_portable_equipment = OldPineEquipmentInteractionAdapter.new().wield(_player, id, _inventory, _item_index)
	return _last_portable_equipment


func unwield_player_item(id: StringName) -> OldPineEquipmentInteractionResult:
	if not portable_inventory_available(): return OldPineEquipmentInteractionResult.new()
	_last_portable_equipment = OldPineEquipmentInteractionAdapter.new().unwield(_player, id, _inventory)
	return _last_portable_equipment


func wear_player_item(id: StringName) -> OldPineArmorInteractionResult:
	if not portable_inventory_available(): return OldPineArmorInteractionResult.new()
	_last_portable_armor = OldPineArmorInteractionAdapter.new().wear(_player, id, _inventory, _item_index)
	return _last_portable_armor


func remove_player_item(id: StringName) -> OldPineArmorInteractionResult:
	if not portable_inventory_available(): return OldPineArmorInteractionResult.new()
	_last_portable_armor = OldPineArmorInteractionAdapter.new().remove(_player, id, _inventory, _item_index)
	return _last_portable_armor


var _last_portable_equipment: OldPineEquipmentInteractionResult
var _last_portable_armor: OldPineArmorInteractionResult


func last_equipment_interaction() -> OldPineEquipmentInteractionResult:
	return _last_portable_equipment


func last_armor_interaction() -> OldPineArmorInteractionResult:
	return _last_portable_armor


func player_life_flow() -> PlayerLifeFlow:
	return _life_flow


func last_revival_handoff() -> OldPineMapHandoffResult:
	return _last_revival_handoff


## The map reports a completed combat lifecycle of the player. Only the public
## world runs the ES2 unconscious/death flow; the technical fixture keeps its
## terminal defeat.
func on_player_lifecycle(lifecycle: CombatSliceLifecycleResult, has_killer: bool, location: WorldLocationState) -> void:
	if lifecycle == null or _player == null or _world_content_revision != WorldContentRevision.CURRENT_PUBLIC:
		return
	match lifecycle.outcome:
		CombatSliceLifecycleResult.Outcome.UNCONSCIOUS_COMPLETE:
			_life_flow.begin_unconscious(UnconsciousReviveDelay.seconds(_player.state.attributes.constitution, _combat_random))
		CombatSliceLifecycleResult.Outcome.DEATH_COMPLETE:
			_life_flow.begin_death(PlayerDeathRules.die(_player.state, has_killer), place_name(location))


## "老松岭 · 南坡林道" for a world location.
func place_name(location: WorldLocationState) -> String:
	if location == null:
		return ""
	var catalog: ContentCatalog = GameContent.catalog()
	var zone: ZoneDefinition = catalog.zone(location.zone_id)
	var map: MapDefinition = null if zone == null else catalog.map(zone.map_id)
	var region: RegionDefinition = null if map == null else catalog.region(map.region_id)
	if region == null:
		return ""
	return "%s · %s" % [region.display_name, zone.display_name]


## Presentation convenience: show the next white-gargoyle line now.
func skip_death_message() -> void:
	if _life_flow.phase == PlayerLifeFlow.Phase.DEATH_SEQUENCE and application_gameplay_allows_encounter_advance():
		_handle_life_event(_life_flow.skip_to_next_message())


## A save made while the player lay unconscious or dead (before this flow
## existed) continues where ES2 would: waking up, or the way back from death.
## Penalties are not applied again.
func _resume_restored_life_flow() -> void:
	if _player == null or _world_content_revision != WorldContentRevision.CURRENT_PUBLIC:
		return
	match _player.life_status:
		CharacterRuntimeLifeStatus.Value.UNCONSCIOUS:
			_life_flow.begin_unconscious(UnconsciousReviveDelay.seconds(_player.state.attributes.constitution, _combat_random))
		CharacterRuntimeLifeStatus.Value.DEAD:
			_life_flow.begin_death(PlayerDeathResult.new(), "")


func _advance_life_flow(delta: float) -> void:
	if not _life_flow.is_active() or _transitioning or _restore_candidate_staged or not application_gameplay_allows_encounter_advance():
		return
	_handle_life_event(_life_flow.advance(delta))


func _handle_life_event(event: PlayerLifeFlow.Event) -> void:
	match event:
		PlayerLifeFlow.Event.REVIVE_DUE:
			_revive_from_unconscious()
		PlayerLifeFlow.Event.REINCARNATE_DUE:
			_reincarnate_at_revive_room()


## feature/damage.c revive(): the player gets up where they fell. While a
## killer is still at them the encounter decides first.
func _revive_from_unconscious() -> void:
	if _player.life_status != CharacterRuntimeLifeStatus.Value.UNCONSCIOUS:
		_life_flow.finish()
		return
	if _combat_encounter_coordinator != null and _combat_encounter_coordinator.has_active_encounter():
		return
	_player.set_life_status(CharacterRuntimeLifeStatus.Value.ACTIVE)
	var map: WorldResidentMapController = active_map()
	if map != null and map.runtime_player_body() != null:
		map.runtime_player_body().refresh_runtime_state()
	_life_flow.finish()


## d/death/npc/wgargoyle.c death_stage(): reincarnate() and move to
## REVIVE_ROOM (/d/snow/temple).
## If the move cannot happen now the player stays a ghost and it is retried
## next frame, so the world never holds a living player without a body.
func _reincarnate_at_revive_room() -> void:
	var previous_life: int = _player.life_status
	var previous_exists: bool = _player.exists_in_world
	_player.set_life_status(CharacterRuntimeLifeStatus.Value.ACTIVE)
	_player.set_exists_in_world(true)
	_last_revival_handoff = handoff_to(
		SnowWorldDefinitions.OUTDOOR_MAP_ID,
		SnowWorldDefinitions.TEMPLE_ZONE_ID,
		SnowWorldDefinitions.TEMPLE_ZONE_ID,
		SnowWorldDefinitions.REVIVE_SPAWN_ID,
	)
	if not _last_revival_handoff.succeeded():
		_player.set_life_status(previous_life)
		_player.set_exists_in_world(previous_exists)
		_life_flow.retry_reincarnation()
		return
	PlayerDeathRules.reincarnate(_player.state)
	_life_flow.finish()
