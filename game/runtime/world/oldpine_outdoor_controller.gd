class_name OldPineOutdoorController
extends Node2D

const PLAYER_ID: StringName = &"oldpine.player"
const WORLD_CAPACITY: int = 1_000_000
const WorldPlayerRuntimeType := preload(
	"res://runtime/characters/world_player_runtime_state.gd"
)
const WorldCombatBindingAdapterType := preload(
	"res://runtime/characters/world_combat_binding_adapter.gd"
)
const GodotNpcRandomType := preload(
	"res://runtime/npcs/godot_npc_initialization_random_source.gd"
)
const WorldCharacterBodyType := preload(
	"res://runtime/world/world_character_body_2d.gd"
)
const WorldSpawnMarkerType := preload(
	"res://runtime/world/world_spawn_marker_2d.gd"
)
const OldPineHudType := preload(
	"res://runtime/world/oldpine_outdoor_hud.gd"
)
const WorldInteractionTargetType := preload(
	"res://runtime/world/world_interaction_target.gd"
)
const PortalTraversalAdapterType := preload(
	"res://runtime/world/oldpine_portal_traversal_adapter.gd"
)
const AggressionAdapterType := preload(
	"res://runtime/world/oldpine_bandit_aggression_adapter.gd"
)

@export var deterministic_npc_seed: bool = false
@export var npc_seed: int = 7_021
@export var deterministic_combat_seed: bool = false
@export var combat_seed: int = 5_232

@onready var player_body: WorldCharacterBodyType = %Player
@onready var bandit_bodies: Array[WorldCharacterBodyType] = [
	%Bandit01,
	%Bandit02,
	%Bandit03,
]
@onready var tall_bandit_body: WorldCharacterBodyType = %TallBandit
@onready var spawn_points: Node2D = %SpawnPoints
@onready var corpse_layer: Node2D = %CorpseLayer
@onready var opportunity_timer: Timer = %OpportunityTimer
@onready var hud: OldPineHudType = %HUD

var _player: WorldPlayerRuntimeType
var _map_characters: MapCharacterRuntimeState
var _all_npcs: Array[NpcRuntimeState] = []
var _inventory: InventoryState
var _stacks: CombinedStackCollection
var _item_index: WorldItemInstanceIndex
var _npc_random: GodotNpcRandomType
var _combat_random: CombatRandomSource
var _effects: SkillImprovementEffectRegistry
var _bandit_content: CombatSliceContentProfile
var _tall_bandit_content: CombatSliceContentProfile
var _selected_target: WorldInteractionTargetType
var _corpse_states: Array[CorpseState] = []
var _corpse_views: Dictionary[StringName, CombatSliceCorpseView] = {}
var _corpse_sequence: int = 0
var _last_tick_order: Array[StringName] = []
var _last_lifecycle_results: Array[CombatSliceLifecycleResult] = []
var _lifecycle_failed: bool = false
var _presenter: CombatSlicePresenter = CombatSlicePresenter.new()
var _item_instance_scope: StringName = &""
var _initialized: bool = false
var _portal_adapter: PortalTraversalAdapterType = PortalTraversalAdapterType.new()
var _aggression_adapter: AggressionAdapterType = AggressionAdapterType.new()
var _last_aggression_decisions: Array[OldPineAggressionDecision] = []
var _last_aggression_initiations: Array[CombatSliceInitiationResult] = []
var _loot_adapter: OldPineCorpseLootAdapter = OldPineCorpseLootAdapter.new()
var _last_loot_transfer_result: CorpseLootTransferResult
var _inventory_projection: PlayerInventoryProjection = PlayerInventoryProjection.new()
var _equipment_adapter: OldPineEquipmentInteractionAdapter = (
	OldPineEquipmentInteractionAdapter.new()
)
var _weapon_content_resolver: OldPineWeaponContentResolver = (
	OldPineWeaponContentResolver.new()
)
var _last_equipment_interaction: OldPineEquipmentInteractionResult
var _last_player_content_resolution: OldPineWeaponContentResolution


func _ready() -> void:
	initialize_world()


func _process(_delta: float) -> void:
	if _initialized and _aggression_adapter.pending_count() > 0:
		process_pending_aggression()
	if (
		_initialized
		and _selected_target != null
		and _selected_target.kind == WorldInteractionTarget.Kind.ITEM
	):
		_refresh_selected_corpse()


func initialize_world() -> bool:
	if _initialized:
		return true
	_item_instance_scope = StringName("oldpine-outdoor-%d" % get_instance_id())
	_inventory = InventoryState.new()
	_stacks = CombinedStackCollection.new()
	_item_index = WorldItemInstanceIndex.new()
	_map_characters = MapCharacterRuntimeState.new(OldPineWorldDefinitions.OUTDOOR_MAP_ID)
	_npc_random = GodotNpcRandomType.new(
		npc_seed,
		deterministic_npc_seed,
	)
	_combat_random = GodotCombatRandomSource.new(
		combat_seed,
		deterministic_combat_seed,
	)
	_effects = SkillImprovementEffectRegistry.new()
	_effects.register_legacy_defaults()
	_bandit_content = CombatSliceContentProfile.new(
		OldPineNpcDefinitions.SHORT_SWORD_ITEM_ID,
		&"sword",
		OldPineNpcDefinitions.SHORT_SWORD_DAMAGE,
	)
	var tall_weapon_content: OldPineItemContentDefinition = (
		OldPineItemContentDefinitions.content_by_id(
			OldPineNpcDefinitions.LONG_SWORD_ITEM_ID
		)
	)
	if tall_weapon_content == null:
		return false
	_tall_bandit_content = CombatSliceContentProfile.new(
		tall_weapon_content.item_definition_id,
		tall_weapon_content.weapon_skill_type,
		tall_weapon_content.weapon_damage,
	)
	if (
		not _initialize_player()
		or not _initialize_bandits()
		or not _initialize_tall_bandit()
	):
		return false
	hud.configure(_player)
	opportunity_timer.stop()
	_initialized = true
	return true


func player_runtime() -> WorldPlayerRuntimeType:
	return _player


func npc_runtimes() -> Array[NpcRuntimeState]:
	return _all_npcs.duplicate()


func map_character_state() -> MapCharacterRuntimeState:
	return _map_characters


func inventory_state() -> InventoryState:
	return _inventory


func stack_collection() -> CombinedStackCollection:
	return _stacks


func item_instance_index() -> WorldItemInstanceIndex:
	return _item_index


func selected_character_id() -> StringName:
	if (
		_selected_target == null
		or _selected_target.kind != WorldInteractionTarget.Kind.CHARACTER
	):
		return &""
	return _selected_target.target_id


func selected_interaction_target() -> WorldInteractionTargetType:
	return _selected_target


func selected_npc() -> NpcRuntimeState:
	return _find_npc(selected_character_id())


func last_aggression_decisions() -> Array[OldPineAggressionDecision]:
	return _last_aggression_decisions.duplicate()


func last_aggression_initiations() -> Array[CombatSliceInitiationResult]:
	return _last_aggression_initiations.duplicate()


func aggression_adapter() -> AggressionAdapterType:
	return _aggression_adapter


func corpse_states() -> Array[CorpseState]:
	return _corpse_states.duplicate()


func corpse_view_for(corpse_id: StringName) -> CombatSliceCorpseView:
	return _corpse_views.get(corpse_id)


func last_loot_transfer_result() -> CorpseLootTransferResult:
	return _last_loot_transfer_result


func last_equipment_interaction() -> OldPineEquipmentInteractionResult:
	return _last_equipment_interaction


func last_player_content_resolution() -> OldPineWeaponContentResolution:
	return _last_player_content_resolution


func last_tick_order() -> Array[StringName]:
	return _last_tick_order.duplicate()


func last_lifecycle_results() -> Array[CombatSliceLifecycleResult]:
	return _last_lifecycle_results.duplicate()


func lifecycle_is_pending() -> bool:
	return _lifecycle_failed


func npc_random_source() -> NpcInitializationRandomSource:
	return _npc_random


func combat_random_source() -> CombatRandomSource:
	return _combat_random


func configure_combat_random_source(value: CombatRandomSource) -> bool:
	if value == null:
		return false
	_combat_random = value
	return true


func select_npc(character_id: StringName) -> bool:
	var npc: NpcRuntimeState = _find_npc(character_id)
	if (
		npc == null
		or not npc.exists_in_map
		or npc.life_status == CharacterRuntimeLifeStatus.Value.DEAD
	):
		return false
	_selected_target = WorldInteractionTargetType.character(character_id)
	hud.set_selected_target(npc)
	return true


func select_landmark(landmark_id: StringName) -> bool:
	var landmark: WorldLandmarkDefinition = (
		OldPineLandmarkDefinitions.definition_by_id(landmark_id)
	)
	if landmark == null:
		return false
	_selected_target = WorldInteractionTargetType.landmark(landmark_id)
	hud.set_selected_landmark(
		landmark,
		_landmark_source_is_current(landmark),
	)
	return true


func select_corpse(corpse_id: StringName) -> bool:
	var corpse: CorpseState = _find_corpse(corpse_id)
	if corpse == null or not _corpse_is_live_in_world(corpse):
		return false
	_selected_target = WorldInteractionTargetType.item(corpse_id)
	hud.set_selected_corpse(
		corpse.victim_display_name,
		_corpse_content_count(corpse),
		_player_is_in_corpse_loot_range(corpse_id),
	)
	return true


func inspect_selected() -> bool:
	if (
		_selected_target != null
		and _selected_target.kind == WorldInteractionTarget.Kind.ITEM
	):
		var corpse: CorpseState = _find_corpse(_selected_target.target_id)
		if corpse == null or not _corpse_is_live_in_world(corpse):
			return false
		hud.show_corpse_inspection(
			corpse.victim_display_name,
			_corpse_content_count(corpse),
		)
		return true
	if (
		_selected_target != null
		and _selected_target.kind == WorldInteractionTarget.Kind.LANDMARK
	):
		var landmark: WorldLandmarkDefinition = (
			OldPineLandmarkDefinitions.definition_by_id(_selected_target.target_id)
		)
		if landmark == null:
			return false
		hud.show_landmark_inspection(landmark)
		return true
	var npc: NpcRuntimeState = selected_npc()
	if npc == null or not npc.exists_in_map:
		return false
	hud.show_inspection(npc.definition())
	return true


func open_selected_loot() -> bool:
	hud.close_inventory()
	var corpse: CorpseState = _selected_corpse()
	if corpse == null:
		hud.close_loot()
		return false
	var validation: int = _loot_adapter.validate_open(
		_player,
		corpse,
		_inventory,
		_item_index,
		_player_is_in_corpse_loot_range(corpse.corpse_item_instance_id),
	)
	if validation != OldPineCorpseLootAdapter.OpenValidation.READY:
		hud.close_loot()
		_refresh_selected_corpse()
		return false
	_refresh_loot_panel(corpse)
	return true


func take_selected_loot_item(
	item_instance_id: StringName,
) -> CorpseLootTransferResult:
	var corpse: CorpseState = _selected_corpse()
	if corpse == null:
		_last_loot_transfer_result = CorpseLootTransferResult.new(
			CorpseLootTransferResult.Outcome.CORPSE_NOT_AVAILABLE,
			false,
			_player.character_id,
			&"",
			item_instance_id,
		)
		hud.close_loot()
		return _last_loot_transfer_result
	_last_loot_transfer_result = _loot_adapter.take(
		_player,
		corpse,
		item_instance_id,
		_player_is_in_corpse_loot_range(corpse.corpse_item_instance_id),
		_inventory,
		_stacks,
		_item_index,
	)
	_refresh_selected_corpse()
	if hud.loot_is_open():
		if _corpse_is_live_in_world(corpse):
			_refresh_loot_panel(corpse)
		else:
			hud.close_loot()
	if hud.inventory_is_open():
		_refresh_inventory_panel()
	return _last_loot_transfer_result


func open_player_inventory() -> bool:
	if (
		_player == null
		or not _player.is_valid()
		or not _player.exists_in_world
		or _player.life_status != CharacterRuntimeLifeStatus.Value.ACTIVE
	):
		hud.close_inventory()
		return false
	_refresh_inventory_panel()
	return true


func inspect_player_item(item_instance_id: StringName) -> bool:
	var row: PlayerInventoryRowProjection = _inventory_projection.project_item(
		_player,
		_inventory,
		_stacks,
		_item_index,
		item_instance_id,
	)
	if row == null:
		if hud.inventory_is_open():
			_refresh_inventory_panel()
		return false
	hud.show_inventory_inspection(row)
	return true


func wield_player_item(
	item_instance_id: StringName,
) -> OldPineEquipmentInteractionResult:
	_last_equipment_interaction = _equipment_adapter.wield(
		_player,
		item_instance_id,
		_inventory,
		_item_index,
	)
	if hud.inventory_is_open():
		_refresh_inventory_panel()
	return _last_equipment_interaction


func unwield_player_item(
	item_instance_id: StringName,
) -> OldPineEquipmentInteractionResult:
	_last_equipment_interaction = _equipment_adapter.unwield(
		_player,
		item_instance_id,
		_inventory,
	)
	if hud.inventory_is_open():
		_refresh_inventory_panel()
	return _last_equipment_interaction


func attack_selected() -> CombatSliceInitiationResult:
	var target: NpcRuntimeState = selected_npc()
	if target == null:
		return CombatSliceInitiationResult.new()
	return _initiate_lethal_combat(
		_player.character_id,
		target.character_id,
		"Attack initiated against %s" % target.definition().display_name,
	)


func traverse_selected_portal() -> WorldPortalTraversalResult:
	if (
		_selected_target == null
		or _selected_target.kind != WorldInteractionTarget.Kind.LANDMARK
	):
		return WorldPortalTraversalResult.new()
	var landmark: WorldLandmarkDefinition = (
		OldPineLandmarkDefinitions.definition_by_id(_selected_target.target_id)
	)
	if landmark == null:
		return WorldPortalTraversalResult.new()
	var portal: PortalDefinition = OldPineWorldDefinitions.portal_by_id(
		landmark.portal_id
	)
	var marker: WorldSpawnMarkerType = (
		null
		if portal == null
		else _find_spawn_marker(portal.destination_spawn_point_id)
	)
	var destination: WorldLocationState = (
		null
		if portal == null
		else _location_for_zone(portal.destination_zone_id)
	)
	var result: WorldPortalTraversalResult = _portal_adapter.traverse(
		_player,
		player_body,
		portal,
		marker,
		destination,
	)
	if result.completed():
		hud.append_log_lines(
			["%s: %s" % [landmark.action_label, landmark.display_name]]
		)
		_refresh_selected_landmark_source()
	return result


func process_pending_aggression() -> Array[CombatSliceInitiationResult]:
	_last_aggression_decisions = _aggression_adapter.resolve_pending(
		_all_npcs,
		_player,
		_current_location_allows_combat(),
	)
	_last_aggression_initiations.clear()
	for decision: OldPineAggressionDecision in _last_aggression_decisions:
		if decision.outcome != OldPineAggressionDecision.Outcome.READY:
			continue
		var npc: NpcRuntimeState = _find_npc(decision.npc_id)
		if npc == null:
			continue
		var initiation: CombatSliceInitiationResult = _initiate_lethal_combat(
			npc.character_id,
			_player.character_id,
			"%s attacks on sight" % npc.definition().display_name,
		)
		_last_aggression_initiations.append(initiation)
	return _last_aggression_initiations.duplicate()


func _initiate_lethal_combat(
	initiator_id: StringName,
	target_id: StringName,
	log_line: String,
) -> CombatSliceInitiationResult:
	var participants: Array[CombatSliceCharacterBinding] = _build_participants()
	var initiator_binding: CombatSliceCharacterBinding = _binding_for(
		participants,
		initiator_id,
	)
	var target_binding: CombatSliceCharacterBinding = _binding_for(
		participants,
		target_id,
	)
	var result: CombatSliceInitiationResult = (
		CombatSliceOpportunityExecutor.initiate_lethal_combat(
			initiator_binding,
			target_binding,
		)
	)
	if result.outcome == CombatSliceInitiationResult.Outcome.COMPLETED:
		if opportunity_timer.is_stopped():
			opportunity_timer.start()
		hud.append_log_lines([log_line])
	return result


func process_cadence_tick() -> Array[CombatSliceOpportunityResult]:
	var results: Array[CombatSliceOpportunityResult] = []
	_last_tick_order.clear()
	_last_lifecycle_results.clear()
	if _lifecycle_failed:
		return results
	var participants: Array[CombatSliceCharacterBinding] = _build_participants()
	for actor: CombatSliceCharacterBinding in participants:
		if not actor.exists_in_encounter or not actor.relationship.is_fighting():
			continue
		_last_tick_order.append(actor.character_id)
		var opportunity: CombatSliceOpportunityResult = (
			CombatSliceOpportunityExecutor.execute_opportunity(
				actor,
				participants,
				_combat_random,
				_effects,
			)
		)
		results.append(opportunity)
		if opportunity.outcome in [
			CombatSliceOpportunityResult.Outcome.LIFECYCLE_REQUIRED_UNCONSCIOUS,
			CombatSliceOpportunityResult.Outcome.LIFECYCLE_REQUIRED_DEATH,
		]:
			var lifecycle: CombatSliceLifecycleResult = _execute_lifecycle(
				actor,
				opportunity,
				participants,
			)
			_last_lifecycle_results.append(lifecycle)
			if not lifecycle.completed():
				_lifecycle_failed = true
				opportunity_timer.stop()
			hud.append_log_lines(
				_presenter.describe_lifecycle(lifecycle, _display_name(actor.character_id))
			)
			if _lifecycle_failed:
				break
		else:
			var victim_id: StringName = _selected_opponent_id(opportunity, actor)
			hud.append_log_lines(
				_presenter.describe_opportunity(
					opportunity,
					_display_name(actor.character_id),
					_display_name(victim_id),
				)
			)
	if not _has_active_relationships():
		opportunity_timer.stop()
	hud.refresh_live_state()
	return results


func reset_world() -> void:
	get_tree().reload_current_scene()


func _initialize_player() -> bool:
	var prototype: CombatSliceCharacterBinding = CombatSliceDemoFactory.create_player()
	var start_location: WorldLocationState = _location_for_zone(
		OldPineWorldDefinitions.CENTRAL_CLEARING_ZONE_ID
	)
	_player = WorldPlayerRuntimeType.new(
		PLAYER_ID,
		prototype.state,
		CombatRelationshipState.new(PLAYER_ID),
		ActionBusyState.new(),
		ArmorState.new(),
		start_location,
		CharacterRuntimeLifeStatus.Value.ACTIVE,
		true,
		true,
		CharacterDerivedValues.maximum_encumbrance(
			prototype.state.attributes.strength
		),
	)
	var demo_primary: EquippedWeaponRef = _player.state.equipment.primary_weapon()
	if demo_primary == null:
		return false
	if not _player.state.equipment.unwield(demo_primary.instance_id).succeeded:
		return false
	var player_weapon_definition: WeaponDefinition = WeaponDefinition.new(
		CombatSliceContentProfile.LONG_SWORD_ID,
		CombatSliceContentProfile.LONG_SWORD_SKILL_ID,
		false,
		false,
		CombatSliceContentProfile.LONG_SWORD_SOURCE,
	)
	var primary: EquippedWeaponRef = EquippedWeaponRef.new(
		StringName("%s.player-long-sword" % String(_item_instance_scope)),
		player_weapon_definition,
	)
	if not _player.state.equipment.wield(primary, false).succeeded:
		return false
	var player_item: ItemInstance = ItemInstance.new(
		primary.instance_id,
		primary.weapon_id,
	)
	if not _inventory.register_item(player_item, CombatSliceContentProfile.LONG_SWORD_WEIGHT):
		return false
	if not _item_index.register_snapshot(player_item):
		return false
	var player_destination: InventoryTransferDestination = _character_destination(
		_player.character_id,
		_player.maximum_encumbrance,
	)
	if not InventoryTransferService.new().transfer(
		_inventory,
		player_item.item_instance_id,
		player_destination,
	).succeeded:
		return false
	var marker: WorldSpawnMarkerType = %PlayerStart
	if marker == null or not marker.is_configured():
		return false
	player_body.global_position = marker.global_position
	player_body.player_controlled = true
	return player_body.bind_player(_player)


func _initialize_bandits() -> bool:
	var spawn: NpcSpawnDefinition = OldPineSpawnDefinitions.spath1_bandit_spawn()
	var definition: NpcDefinition = OldPineNpcDefinitions.bandit_definition()
	var created: Array[NpcRuntimeState] = NpcCharacterStateFactory.new().create_spawn_instances(
		spawn,
		definition,
		_location_for_zone(OldPineWorldDefinitions.SOUTH_SLOPE_ZONE_ID),
		_inventory,
		_stacks,
		_npc_random,
		OldPineNpcDefinitions.loadout_item_definitions(),
		_item_instance_scope,
	)
	if created.size() != spawn.quantity or created.size() != bandit_bodies.size():
		return false
	for npc: NpcRuntimeState in created:
		for item: ItemInstance in npc.loadout_items():
			if not _item_index.register_snapshot(item):
				return false
	var point_ids: Array[StringName] = spawn.spawn_point_ids()
	for index: int in range(created.size()):
		var npc: NpcRuntimeState = created[index]
		var marker: WorldSpawnMarkerType = _find_spawn_marker(point_ids[index])
		if marker == null or not _map_characters.register_npc(npc):
			return false
		_all_npcs.append(npc)
		var body: WorldCharacterBodyType = bandit_bodies[index]
		body.global_position = marker.global_position
		body.player_controlled = false
		if not body.bind_npc(npc):
			return false
	return true


func _initialize_tall_bandit() -> bool:
	var spawn: NpcSpawnDefinition = (
		OldPineSpawnDefinitions.pine1_tall_bandit_spawn()
	)
	var definition: NpcDefinition = OldPineNpcDefinitions.tall_bandit_definition()
	var created: Array[NpcRuntimeState] = (
		NpcCharacterStateFactory.new().create_spawn_instances(
			spawn,
			definition,
			_location_for_zone(OldPineWorldDefinitions.PINE_ENTRANCE_ZONE_ID),
			_inventory,
			_stacks,
			_npc_random,
			OldPineNpcDefinitions.loadout_item_definitions(),
			_item_instance_scope,
		)
	)
	if created.size() != 1:
		return false
	var npc: NpcRuntimeState = created[0]
	for item: ItemInstance in npc.loadout_items():
		if not _item_index.register_snapshot(item):
			return false
	var point_ids: Array[StringName] = spawn.spawn_point_ids()
	var marker: WorldSpawnMarkerType = _find_spawn_marker(point_ids[0])
	if marker == null or not _map_characters.register_npc(npc):
		return false
	_all_npcs.append(npc)
	tall_bandit_body.global_position = marker.global_position
	tall_bandit_body.player_controlled = false
	return tall_bandit_body.bind_npc(npc)


func _find_spawn_marker(spawn_point_id: StringName) -> WorldSpawnMarkerType:
	for child: Node in spawn_points.get_children():
		var marker: WorldSpawnMarkerType = child as WorldSpawnMarkerType
		if marker != null and marker.spawn_point_id == spawn_point_id:
			return marker
	return null


func _build_participants() -> Array[CombatSliceCharacterBinding]:
	var result: Array[CombatSliceCharacterBinding] = []
	_last_player_content_resolution = _weapon_content_resolver.resolve(
		_player,
		_inventory,
		_item_index,
	)
	var player_binding: CombatSliceCharacterBinding = (
		WorldCombatBindingAdapterType.from_player(
			_player,
			(
				_last_player_content_resolution.content_profile
				if _last_player_content_resolution.succeeded
				else null
			),
		)
	)
	if player_binding != null:
		result.append(player_binding)
	for npc: NpcRuntimeState in _all_npcs:
		if not npc.exists_in_map:
			continue
		var npc_content: CombatSliceContentProfile = _bandit_content
		if npc.definition().definition_id == OldPineNpcDefinitions.TALL_BANDIT_DEFINITION_ID:
			npc_content = _tall_bandit_content
		var binding: CombatSliceCharacterBinding = (
			WorldCombatBindingAdapterType.from_npc(npc, npc_content)
		)
		if binding != null:
			result.append(binding)
	return result


func _execute_lifecycle(
	victim: CombatSliceCharacterBinding,
	opportunity: CombatSliceOpportunityResult,
	participants: Array[CombatSliceCharacterBinding],
) -> CombatSliceLifecycleResult:
	var body: WorldCharacterBodyType = _body_for(victim.character_id)
	var death_position: Vector2 = Vector2.ZERO if body == null else body.global_position
	var killer: CombatSliceCharacterBinding = _find_killer(victim, participants)
	var destination: InventoryTransferDestination = _world_destination_for(victim.character_id)
	_corpse_sequence += 1
	var corpse_id: StringName = StringName(
		"oldpine-outdoor-corpse-%d-%d" % [get_instance_id(), _corpse_sequence]
	)
	var context: DeathContext = _death_context_for(victim, killer, destination)
	var lifecycle: CombatSliceLifecycleResult = CombatSliceLifecycleAdapter.new().execute(
		opportunity,
		victim,
		participants,
		killer,
		_inventory,
		_stacks,
		corpse_id,
		destination,
		_death_item_facts_for(victim.character_id),
		DeathItemPolicyRegistry.new(),
		DeathRewearPolicyRegistry.new(),
		context,
	)
	if lifecycle.completed():
		_sync_binding(victim)
		if body != null:
			body.refresh_runtime_state()
	if lifecycle.death_inventory_result != null:
		var corpse: CorpseState = lifecycle.death_inventory_result.corpse_state
		if corpse != null:
			_corpse_states.append(corpse)
			var view: CombatSliceCorpseView = CombatSliceCorpseView.new()
			if view.configure(corpse):
				view.global_position = death_position
				corpse_layer.add_child(view)
				## Phase 6B3 preserves a partial corpse mutation/view even when
				## death cannot complete. Phase 8B1 must not turn that evidence
				## into an ordinary loot interaction.
				if (
					lifecycle.outcome
					== CombatSliceLifecycleResult.Outcome.DEATH_COMPLETE
					and _item_index.register_snapshot(
						ItemInstance.new(
							corpse.corpse_item_instance_id,
							CombatSliceDeathAdapter.CORPSE_DEFINITION_ID,
						)
					)
				):
					view.selection_requested.connect(_on_corpse_selection_requested)
					view.loot_range_changed.connect(_on_corpse_loot_range_changed)
					_corpse_views[corpse.corpse_item_instance_id] = view
	return lifecycle


func _death_context_for(
	victim: CombatSliceCharacterBinding,
	killer: CombatSliceCharacterBinding,
	destination: InventoryTransferDestination,
) -> DeathContext:
	var display_name: String = "Player"
	var age: int = 20
	var strength: int = victim.state.attributes.strength
	var body_weight: int = CharacterDerivedValues.human_weight(strength)
	var maximum_encumbrance: int = CharacterDerivedValues.maximum_encumbrance(strength)
	var npc: NpcRuntimeState = _find_npc(victim.character_id)
	if npc != null:
		display_name = npc.definition().display_name
		age = npc.age
	var owner: ItemLifecycleOwnerContext = ItemLifecycleOwnerContext.new(
		victim.character_id,
		victim.state.equipment,
		victim.armor,
	)
	return DeathContext.new(
		victim.character_id,
		false,
		false,
		destination,
		owner,
		display_name,
		victim.state.gender,
		age,
		body_weight,
		maximum_encumbrance,
		false,
		destination.endpoint if killer != null else null,
		victim.state.gender,
		killer != null,
	)


func _death_item_facts_for(character_id: StringName) -> Array[DeathItemFacts]:
	var facts: Array[DeathItemFacts] = []
	var endpoint: ContainmentEndpoint = ContainmentEndpoint.new(
		ContainmentEndpoint.Kind.CHARACTER,
		character_id,
	)
	var npc: NpcRuntimeState = _find_npc(character_id)
	if npc != null:
		for item: ItemInstance in npc.loadout_items():
			if _inventory.is_direct_child(item.item_instance_id, endpoint):
				facts.append(DeathItemFacts.new(item))
		return facts
	var primary: EquippedWeaponRef = _player.state.equipment.primary_weapon()
	if primary != null and _inventory.is_direct_child(primary.instance_id, endpoint):
		facts.append(
			DeathItemFacts.new(ItemInstance.new(primary.instance_id, primary.weapon_id))
		)
	return facts


func _sync_binding(binding: CombatSliceCharacterBinding) -> void:
	if binding.character_id == _player.character_id:
		WorldCombatBindingAdapterType.sync_player(binding, _player)
	else:
		var npc: NpcRuntimeState = _find_npc(binding.character_id)
		if npc != null:
			WorldCombatBindingAdapterType.sync_npc(binding, npc)


func _update_body_zone(body: Node2D, zone_id: StringName) -> void:
	var character_body: WorldCharacterBodyType = body as WorldCharacterBodyType
	if character_body != null:
		var updated: bool = character_body.set_world_location(
			_location_for_zone(zone_id)
		)
		if updated and character_body == player_body:
			_refresh_selected_landmark_source()


func _location_for_zone(zone_id: StringName) -> WorldLocationState:
	var zone: ZoneDefinition = OldPineWorldDefinitions.zone_by_id(zone_id)
	if zone == null:
		return null
	return WorldLocationState.new(
		OldPineWorldDefinitions.REGION_ID,
		OldPineWorldDefinitions.OUTDOOR_MAP_ID,
		zone.zone_id,
		zone.combat_location_id,
	)


func _world_destination_for(character_id: StringName) -> InventoryTransferDestination:
	var location: WorldLocationState = (
		_player.world_location()
		if character_id == _player.character_id
		else _find_npc(character_id).world_location()
	)
	return InventoryTransferDestination.new(
		ContainmentEndpoint.new(
			ContainmentEndpoint.Kind.WORLD,
			location.combat_location_id,
		),
		true,
		true,
		WORLD_CAPACITY,
	)


func _character_destination(
	character_id: StringName,
	capacity: int,
) -> InventoryTransferDestination:
	return InventoryTransferDestination.new(
		ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, character_id),
		true,
		true,
		capacity,
	)


func _find_npc(character_id: StringName) -> NpcRuntimeState:
	for npc: NpcRuntimeState in _all_npcs:
		if npc.character_id == character_id:
			return npc
	return null


func _find_corpse(corpse_id: StringName) -> CorpseState:
	for corpse: CorpseState in _corpse_states:
		if corpse.corpse_item_instance_id == corpse_id:
			return corpse
	return null


func _selected_corpse() -> CorpseState:
	if (
		_selected_target == null
		or _selected_target.kind != WorldInteractionTarget.Kind.ITEM
	):
		return null
	return _find_corpse(_selected_target.target_id)


func _corpse_is_live_in_world(corpse: CorpseState) -> bool:
	if (
		corpse == null
		or not _inventory.is_registered(corpse.corpse_item_instance_id)
		or not _item_index.has_snapshot(corpse.corpse_item_instance_id)
		or not _corpse_views.has(corpse.corpse_item_instance_id)
	):
		return false
	var parent: ContainmentEndpoint = _inventory.direct_parent(
		corpse.corpse_item_instance_id
	)
	return parent != null and parent.kind == ContainmentEndpoint.Kind.WORLD


func _corpse_content_count(corpse: CorpseState) -> int:
	if corpse == null:
		return 0
	return _inventory.direct_children(
		ContainmentEndpoint.new(
			ContainmentEndpoint.Kind.ITEM,
			corpse.corpse_item_instance_id,
		)
	).size()


func _player_is_in_corpse_loot_range(corpse_id: StringName) -> bool:
	var view: CombatSliceCorpseView = _corpse_views.get(corpse_id)
	return view != null and view.is_body_in_loot_range(player_body)


func _refresh_selected_corpse() -> void:
	var corpse: CorpseState = _selected_corpse()
	if corpse == null or not _corpse_is_live_in_world(corpse):
		_clear_selected_corpse_target()
		return
	hud.set_selected_corpse(
		corpse.victim_display_name,
		_corpse_content_count(corpse),
		_player_is_in_corpse_loot_range(corpse.corpse_item_instance_id),
		false,
	)


func _clear_selected_corpse_target() -> void:
	if (
		_selected_target != null
		and _selected_target.kind == WorldInteractionTarget.Kind.ITEM
	):
		_selected_target = null
	hud.set_selected_corpse("", 0, false, true)


func _refresh_loot_panel(corpse: CorpseState) -> void:
	var rows: Array[WorldItemRowProjection] = _loot_adapter.project_rows(
		corpse,
		_inventory,
		_stacks,
		_item_index,
	)
	hud.show_loot("Corpse of %s" % corpse.victim_display_name, rows)


func _refresh_inventory_panel() -> void:
	var rows: Array[PlayerInventoryRowProjection] = _inventory_projection.project_rows(
		_player,
		_inventory,
		_stacks,
		_item_index,
	)
	hud.show_inventory(rows)


func _body_for(character_id: StringName) -> WorldCharacterBodyType:
	if character_id == _player.character_id:
		return player_body
	for body: WorldCharacterBodyType in bandit_bodies:
		if body.character_id == character_id:
			return body
	if tall_bandit_body.character_id == character_id:
		return tall_bandit_body
	return null


func _binding_for(
	participants: Array[CombatSliceCharacterBinding],
	character_id: StringName,
) -> CombatSliceCharacterBinding:
	return CombatSliceProjectionBuilder.find_binding(participants, character_id)


func _find_killer(
	victim: CombatSliceCharacterBinding,
	participants: Array[CombatSliceCharacterBinding],
) -> CombatSliceCharacterBinding:
	for candidate: CombatSliceCharacterBinding in participants:
		if candidate != victim and (
			candidate.relationship.has_lethal_target(victim.character_id)
			or victim.relationship.has_lethal_target(candidate.character_id)
		):
			return candidate
	return null


func _selected_opponent_id(
	result: CombatSliceOpportunityResult,
	actor: CombatSliceCharacterBinding,
) -> StringName:
	var selection: CombatOpponentSelectionResult = result.opponent_selection_result
	if selection != null and selection.has_selected_opponent:
		return selection.selected_opponent_id
	var ids: Array[StringName] = actor.relationship.opponent_ids()
	return &"" if ids.is_empty() else ids[0]


func _display_name(character_id: StringName) -> String:
	if character_id == _player.character_id:
		return "Player"
	var npc: NpcRuntimeState = _find_npc(character_id)
	return "Unknown" if npc == null else npc.definition().display_name


func _has_active_relationships() -> bool:
	if _player.exists_in_world and _player.relationship.is_fighting():
		return true
	for npc: NpcRuntimeState in _all_npcs:
		if npc.exists_in_map and npc.relationship.is_fighting():
			return true
	return false


func _current_location_allows_combat() -> bool:
	# Neither clearing.c, spath1.c nor tree1.c authors a no_fight room fact.
	var location: WorldLocationState = _player.world_location()
	return (
		location != null
		and location.map_id == OldPineWorldDefinitions.OUTDOOR_MAP_ID
	)


func _landmark_source_is_current(landmark: WorldLandmarkDefinition) -> bool:
	if landmark == null or _player == null:
		return false
	var portal: PortalDefinition = OldPineWorldDefinitions.portal_by_id(
		landmark.portal_id
	)
	var location: WorldLocationState = _player.world_location()
	return (
		portal != null
		and location != null
		and location.map_id == portal.source_map_id
		and location.zone_id == portal.source_zone_id
	)


func _refresh_selected_landmark_source() -> void:
	if (
		_selected_target == null
		or _selected_target.kind != WorldInteractionTarget.Kind.LANDMARK
	):
		return
	var landmark: WorldLandmarkDefinition = (
		OldPineLandmarkDefinitions.definition_by_id(_selected_target.target_id)
	)
	hud.set_selected_landmark_source_available(
		_landmark_source_is_current(landmark)
	)


func _queue_bandit_presence(
	npc_index: int,
	body: Node2D,
) -> OldPineAggressionDecision:
	if body != player_body or npc_index < 0 or npc_index >= _all_npcs.size():
		return OldPineAggressionDecision.new()
	return _aggression_adapter.enter_player_presence(
		_all_npcs[npc_index],
		_player,
		_current_location_allows_combat(),
	)


func _leave_bandit_presence(npc_index: int, body: Node2D) -> void:
	if body == player_body and npc_index >= 0 and npc_index < _all_npcs.size():
		_aggression_adapter.leave_player_presence(_all_npcs[npc_index].character_id)


func _on_bandit_selection_requested(character_id: StringName) -> void:
	select_npc(character_id)


func _on_landmark_selection_requested(landmark_id: StringName) -> void:
	select_landmark(landmark_id)


func _on_corpse_selection_requested(corpse_id: StringName) -> void:
	select_corpse(corpse_id)


func _on_corpse_loot_range_changed(
	corpse_id: StringName,
	body: Node2D,
	_is_inside: bool,
) -> void:
	if (
		body == player_body
		and _selected_target != null
		and _selected_target.kind == WorldInteractionTarget.Kind.ITEM
		and _selected_target.target_id == corpse_id
	):
		_refresh_selected_corpse()


func _on_inspect_button_pressed() -> void:
	inspect_selected()


func _on_attack_button_pressed() -> void:
	attack_selected()


func _on_portal_button_pressed() -> void:
	traverse_selected_portal()


func _on_open_loot_button_pressed() -> void:
	open_selected_loot()


func _on_inventory_button_pressed() -> void:
	open_player_inventory()


func _on_loot_take_requested(item_instance_id: StringName) -> void:
	take_selected_loot_item(item_instance_id)


func _on_inventory_inspect_requested(item_instance_id: StringName) -> void:
	inspect_player_item(item_instance_id)


func _on_inventory_wield_requested(item_instance_id: StringName) -> void:
	wield_player_item(item_instance_id)


func _on_inventory_unwield_requested(item_instance_id: StringName) -> void:
	unwield_player_item(item_instance_id)


func _on_opportunity_timer_timeout() -> void:
	process_cadence_tick()


func _on_reset_button_pressed() -> void:
	reset_world()


func _on_central_clearing_body_entered(body: Node2D) -> void:
	_update_body_zone(body, OldPineWorldDefinitions.CENTRAL_CLEARING_ZONE_ID)


func _on_south_slope_body_entered(body: Node2D) -> void:
	_update_body_zone(body, OldPineWorldDefinitions.SOUTH_SLOPE_ZONE_ID)


func _on_north_approach_body_entered(body: Node2D) -> void:
	_update_body_zone(body, OldPineWorldDefinitions.NORTH_APPROACH_ZONE_ID)


func _on_east_bridge_body_entered(body: Node2D) -> void:
	_update_body_zone(body, OldPineWorldDefinitions.EAST_BRIDGE_ZONE_ID)


func _on_tree_canopy_body_entered(body: Node2D) -> void:
	_update_body_zone(body, OldPineWorldDefinitions.TREE_CANOPY_ZONE_ID)


func _on_pine_entrance_body_entered(body: Node2D) -> void:
	_update_body_zone(body, OldPineWorldDefinitions.PINE_ENTRANCE_ZONE_ID)


func _on_pine_deep_body_entered(body: Node2D) -> void:
	_update_body_zone(body, OldPineWorldDefinitions.PINE_DEEP_ZONE_ID)


func _on_pine_cliff_edge_body_entered(body: Node2D) -> void:
	_update_body_zone(body, OldPineWorldDefinitions.PINE_CLIFF_EDGE_ZONE_ID)


func _on_bandit_01_presence_entered(body: Node2D) -> void:
	_queue_bandit_presence(0, body)


func _on_bandit_01_presence_exited(body: Node2D) -> void:
	_leave_bandit_presence(0, body)


func _on_bandit_02_presence_entered(body: Node2D) -> void:
	_queue_bandit_presence(1, body)


func _on_bandit_02_presence_exited(body: Node2D) -> void:
	_leave_bandit_presence(1, body)


func _on_bandit_03_presence_entered(body: Node2D) -> void:
	_queue_bandit_presence(2, body)


func _on_bandit_03_presence_exited(body: Node2D) -> void:
	_leave_bandit_presence(2, body)


func _on_tall_bandit_presence_entered(body: Node2D) -> void:
	_queue_bandit_presence(3, body)


func _on_tall_bandit_presence_exited(body: Node2D) -> void:
	_leave_bandit_presence(3, body)
