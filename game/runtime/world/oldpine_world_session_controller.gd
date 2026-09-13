class_name OldPineWorldSessionController
extends WorldResidentMapCoordinator

const PLAYER_ID: StringName = &"oldpine.player"
## Retained internal Old Pine/CXR regression bootstrap, not public New Game
## or an LPC formula. SOURCE_ENTRY and RESTORE never enter this initializer.
const NEW_GAME_COMBAT_EXPERIENCE: int = 600
const OUTDOOR_SCENE: PackedScene = preload(
	"res://scenes/world/oldpine/oldpine_outdoor.tscn"
)
const CAVE_SCENE: PackedScene = preload(
	"res://scenes/world/oldpine/oldpine_cave.tscn"
)
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
var _item_index: WorldItemInstanceIndex
var _npc_random: NpcInitializationRandomSource
var _combat_random: CombatRandomSource
var _world_interaction_random: WorldInteractionRandomSource
var _item_instance_scope: StringName = &""
var _item_id_allocator: SessionItemIdAllocator
var _combat_encounter_coordinator: CombatEncounterCoordinator
var _last_passage_exit_handoff: OldPineMapHandoffResult
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


func _ready() -> void:
	if initialize_session() and _world_content_revision == WorldContentRevision.Value.SOURCE_ENTRY_V1:
		var food_ui: HeldFoodPanel = HeldFoodPanel.new()
		food_ui.name = "HeldFoodUI"
		food_ui.configure(self)
		add_child(food_ui)


func food_collection() -> FoodCollection:
	return _foods


func _process(delta: float) -> void:
	# Inspect before combat advances: a combat-ending frame is not world time.
	advance_player_recovery(delta)
	if _initialized and _combat_encounter_coordinator != null:
		_combat_encounter_coordinator.advance_scheduler(delta)


## One transient authority across every resident. Injection is pre-initialization only.
func configure_recovery_random_source(value: RecoveryCadenceRandomSource) -> bool:
	if value == null or _player_recovery_cadence != null or _initialized:
		return false
	_recovery_random = value
	return true


func player_recovery_cadence() -> PlayerRecoveryCadence:
	return _player_recovery_cadence


func _initialize_player_recovery() -> bool:
	if _world_content_revision != WorldContentRevision.Value.SOURCE_ENTRY_V1:
		return true
	if _player_recovery_cadence == null:
		if _recovery_random == null:
			_recovery_random = GodotRecoveryCadenceRandomSource.new()
		_player_recovery_cadence = PlayerRecoveryCadence.new(_recovery_random)
	return _player_recovery_cadence.is_valid()


## S5B staged path: no combat/conditions/lifecycle execution. Busy is NOT a time gate.
func player_recovery_time_allowed() -> bool:
	if (
		_world_content_revision != WorldContentRevision.Value.SOURCE_ENTRY_V1
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
	var cave: OldPineResidentMapController = (
		CAVE_SCENE.instantiate() as OldPineResidentMapController
	)
	var outdoor: OldPineResidentMapController = (
		OUTDOOR_SCENE.instantiate() as OldPineResidentMapController
	)
	if cave == null or outdoor == null:
		return false
	if not _register_and_configure_map(cave) or not _register_and_configure_map(outdoor):
		return false

	if _bootstrap_mode == BootstrapMode.RESTORE:
		return _initialize_restore_residents(cave, outdoor)
	if _bootstrap_mode == BootstrapMode.SOURCE_ENTRY:
		return _initialize_source_residents(cave, outdoor)

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
	_world_content_revision = WorldContentRevision.Value.SOURCE_ENTRY_V1
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


func encounter_opportunity_interval_seconds() -> float:
	var map: WorldResidentMapController = active_map()
	return 0.0 if map == null else map.encounter_opportunity_interval_seconds()


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


func outdoor_map() -> OldPineOutdoorController:
	return _resident_maps.get(OldPineWorldDefinitions.OUTDOOR_MAP_ID)


func cave_map() -> OldPineCavePassageController:
	return _resident_maps.get(OldPineWorldDefinitions.CAVE_MAP_ID)


func resident_map(map_id: StringName) -> WorldResidentMapController:
	return _resident_maps.get(map_id)


func is_session_swap_suspended() -> bool:
	return _session_swap_suspended


func last_passage_exit_handoff_result() -> OldPineMapHandoffResult:
	return _last_passage_exit_handoff


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


func request_passage_south_exit() -> OldPineMapHandoffResult:
	var portal: PortalDefinition = OldPineWorldDefinitions.portal_by_id(
		OldPineWorldDefinitions.PASSAGE_SOUTH_PORTAL_ID
	)
	var result: OldPineMapHandoffResult = OldPineMapHandoffResult.new()
	if _world_simulation_gate != null and _world_simulation_gate.is_frozen():
		result._outcome = OldPineMapHandoffResult.Outcome.WORLD_SIMULATION_FROZEN
		return result
	if portal == null:
		return result
	var source_zone: ZoneDefinition = OldPineWorldDefinitions.zone_by_id(
		portal.source_zone_id
	)
	var destination_zone: ZoneDefinition = OldPineWorldDefinitions.zone_by_id(
		portal.destination_zone_id
	)
	if source_zone == null or destination_zone == null:
		return result
	result._source_map_id = _active_map_id
	result._destination_map_id = portal.destination_map_id
	result._destination_zone_id = portal.destination_zone_id
	result._destination_combat_location_id = destination_zone.combat_location_id
	result._destination_spawn_point_id = portal.destination_spawn_point_id
	var location: WorldLocationState = null if _player == null else _player.world_location()
	if (
		not _initialized
		or _transitioning
		or _active_map_id != portal.source_map_id
		or location == null
		or location.region_id != OldPineWorldDefinitions.REGION_ID
		or location.map_id != portal.source_map_id
		or location.zone_id != portal.source_zone_id
		or location.combat_location_id != source_zone.combat_location_id
	):
		result._outcome = OldPineMapHandoffResult.Outcome.SOURCE_LOCATION_INVALID
		return result
	return handoff_to(
		portal.destination_map_id,
		portal.destination_zone_id,
		destination_zone.combat_location_id,
		portal.destination_spawn_point_id,
	)


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
	var start_zone: ZoneDefinition = OldPineWorldDefinitions.zone_by_id(
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
	_item_index = _restore_preparation.item_index
	_item_id_allocator = _restore_preparation.item_allocator
	_item_instance_scope = _item_id_allocator.scope
	_npc_random = _restore_preparation.npc_random
	_combat_random = _restore_preparation.combat_random
	_world_interaction_random = _restore_preparation.world_interaction_random
	return true


func _initialize_source_residents(
	cave: OldPineResidentMapController, outdoor: OldPineResidentMapController,
) -> bool:
	if not _register_source_maps(outdoor):
		return false
	var inn: WorldResidentMapController = _resident_maps[SnowWorldDefinitions.INN_MAP_ID]
	var snow: WorldResidentMapController = _resident_maps[SnowWorldDefinitions.OUTDOOR_MAP_ID]
	# Four maps bind the same authority graph. Fresh source entry alone starts in Inn.
	for map: WorldResidentMapController in [cave, outdoor, snow, inn]:
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


func _register_source_maps(outdoor: WorldResidentMapController) -> bool:
	var inn: SnowInnController = (load(SnowWorldDefinitions.INN_SCENE) as PackedScene).instantiate() as SnowInnController
	var snow: SnowOutdoorController = (load(SnowWorldDefinitions.OUTDOOR_SCENE) as PackedScene).instantiate() as SnowOutdoorController
	for map: WorldResidentMapController in [inn, snow]:
		if not map.configure_world_authorities(_player, _inventory, _stacks, _item_index,
			_npc_random, _combat_random, _world_interaction_random, _item_id_allocator, _world_simulation_gate, _foods) or not register_resident_map(map):
			return false
		map.tree_exiting.connect(_on_resident_map_tree_exiting.bind(map.map_id()))
	if not snow.configure_passage(SnowOldPineConnectionDefinitions.to_oldpine()) or not outdoor.configure_passage(SnowOldPineConnectionDefinitions.to_snow()):
		return false
	return true


func _initialize_restore_residents(
	cave: OldPineResidentMapController,
	outdoor: OldPineResidentMapController,
) -> bool:
	var residents: Array[WorldResidentMapController] = [cave, outdoor]
	if _world_content_revision == WorldContentRevision.Value.SOURCE_ENTRY_V1:
		if not _register_source_maps(outdoor):
			return false
		residents.append(_resident_maps[SnowWorldDefinitions.INN_MAP_ID])
		residents.append(_resident_maps[SnowWorldDefinitions.OUTDOOR_MAP_ID])
	for resident: WorldResidentMapController in residents:
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
	if not OldPineMapPlacementValidator.is_valid_character_position(
		player_map,
		player_location.zone_id,
		_restore_preparation.player_position,
	):
		return false
	for entry: OldPineRestoredNpcEntry in _restore_preparation.npc_entries():
		var location: WorldLocationState = entry.runtime.world_location()
		if not OldPineMapPlacementValidator.is_valid_character_position(
			_resident_maps.get(location.map_id),
			location.zone_id,
			entry.map_position,
		):
			return false
	for entry: OldPineRestoredCorpseEntry in _restore_preparation.corpse_entries():
		if not OldPineMapPlacementValidator.is_valid_corpse_position(
			_resident_maps.get(entry.world_location.map_id),
			entry.world_location.zone_id,
			entry.map_position,
		):
			return false
	return true


func _register_and_configure_map(map: OldPineResidentMapController) -> bool:
	if map == null or map.map_id().is_empty() or _resident_maps.has(map.map_id()):
		return false
	if not map.configure_session_authorities(
		self,
		_player,
		_inventory,
		_stacks,
		_item_index,
		_npc_random,
		_combat_random,
		_world_interaction_random,
		_item_id_allocator,
		_world_simulation_gate,
	):
		return false
	if not register_resident_map(map):
		return false
	map.tree_exiting.connect(_on_resident_map_tree_exiting.bind(map.map_id()))
	if map is OldPineCavePassageController:
		var cave: OldPineCavePassageController = map as OldPineCavePassageController
		cave.map_exit_requested.connect(_on_cave_map_exit_requested)
	return true


func _new_item_instance_scope() -> StringName:
	## The scope is durable data, not a Node ObjectID or a gameplay-RNG draw.
	## Platform cryptographic entropy remains independent across fresh processes;
	## save/load preserves this exact value thereafter.
	return SessionItemIdScopeFactoryType.create_old_pine_scope()


func _on_cave_map_exit_requested(portal_id: StringName) -> void:
	if portal_id != OldPineWorldDefinitions.PASSAGE_SOUTH_PORTAL_ID:
		return
	call_deferred("_execute_cave_map_exit_request", portal_id)


func _execute_cave_map_exit_request(portal_id: StringName) -> void:
	if portal_id != OldPineWorldDefinitions.PASSAGE_SOUTH_PORTAL_ID:
		return
	_last_passage_exit_handoff = request_passage_south_exit()
	var cave: OldPineCavePassageController = cave_map()
	if cave != null:
		cave.complete_exit_request(_last_passage_exit_handoff)


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
