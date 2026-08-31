class_name OldPineWorldSaveCapture
extends RefCounted

const Values := preload("res://core/persistence/game_save_value_types.gd")
const Result := preload(
	"res://runtime/persistence/oldpine_world_capture_result.gd"
)

var _failure_path: String = ""
var _failure_detail: String = ""


func capture(
	session: OldPineWorldSessionController,
	storage_profile: StringName,
	saved_at_utc: String,
	build_commit: Values.OptionalText = null,
) -> OldPineWorldCaptureResult:
	_failure_path = ""
	_failure_detail = ""
	if (
		session == null
		or not session.is_inside_tree()
		or not session.is_initialized()
		or session.player_runtime() == null
		or session.outdoor_map() == null
		or session.active_map() == null
		or session.item_id_allocator() == null
		or saved_at_utc.is_empty()
	):
		return Result.failure(Result.Outcome.INVALID_SESSION, "session")

	var player: WorldPlayerRuntimeState = session.player_runtime()
	var outdoor: OldPineOutdoorController = session.outdoor_map()
	var player_character: Values.CharacterStateSnapshot = _character_snapshot(
		player.state,
		"player.character",
	)
	if player_character == null:
		return _character_failure()

	var equipment_sources: Array[NativeCharacterEquipmentSource] = [
		NativeCharacterEquipmentSource.new(
			player.character_id,
			player.state.equipment,
		),
	]
	var armor_sources: Array[NativeCharacterArmorSource] = [
		NativeCharacterArmorSource.new(player.character_id, player.armor),
	]
	for npc: NpcRuntimeState in outdoor.npc_runtimes():
		equipment_sources.append(
			NativeCharacterEquipmentSource.new(
				npc.character_id,
				npc.character_state.equipment,
			)
		)
		armor_sources.append(
			NativeCharacterArmorSource.new(npc.character_id, npc.armor)
		)
	var item_capture: NativeItemSnapshotCaptureResult = (
		NativeItemPersistenceComposition.capture(
			session.inventory_state(),
			session.stack_collection(),
			session.item_instance_index(),
			equipment_sources,
			armor_sources,
			OldPineNativeItemDefinitionProjections.create(),
		)
	)
	if not item_capture.succeeded:
		var validation: NativeItemStateValidationResult = (
			item_capture.validation_result
		)
		return Result.failure(
			Result.Outcome.ITEM_CAPTURE_FAILED,
			"items",
			"outcome=%d subject=%s related=%s" % [
				validation.outcome,
				String(validation.subject_id),
				String(validation.related_id),
			],
		)

	var player_body: WorldCharacterBody2D = (
		session.active_map().runtime_player_body()
	)
	if player_body == null or player_body.character_id != player.character_id:
		return Result.failure(
			Result.Outcome.BODY_BINDING_MISSING,
			"player.map_position",
		)
	var player_snapshot: Values.PlayerRuntimeSnapshot = (
		Values.PlayerRuntimeSnapshot.new(
			player.character_id,
			player_character,
			_life_text(player.life_status),
			player.exists_in_world,
			player.combat_available,
			player.maximum_encumbrance,
			_location_snapshot(player.world_location()),
			_position_snapshot(player_body.global_position),
		)
	)

	var npc_snapshots: Array[Values.NpcSpawnStateSnapshot] = []
	for npc: NpcRuntimeState in outdoor.npc_runtimes():
		var character: Values.CharacterStateSnapshot = _character_snapshot(
			npc.character_state,
			"npc_spawn_states[%s].character" % String(npc.character_id),
		)
		if character == null:
			return _character_failure()
		var body: WorldCharacterBody2D = outdoor.runtime_body_for_character(
			npc.character_id
		)
		if body == null or body.character_id != npc.character_id:
			return Result.failure(
				Result.Outcome.BODY_BINDING_MISSING,
				"npc_spawn_states[%s].map_position" % String(npc.character_id),
			)
		var live_loadout_ids: Array[StringName] = []
		for item: ItemInstance in npc.loadout_items():
			if session.inventory_state().is_registered(item.item_instance_id):
				live_loadout_ids.append(item.item_instance_id)
		npc_snapshots.append(
			Values.NpcSpawnStateSnapshot.new(
				npc.spawn_id,
				npc.spawn_point_id,
				npc.definition_id,
				npc.character_id,
				npc.exists_in_map,
				_life_text(npc.life_status),
				npc.combat_available,
				character,
				npc.age,
				npc.body_weight,
				npc.maximum_encumbrance,
				_location_snapshot(npc.world_location()),
				_position_snapshot(body.global_position),
				live_loadout_ids,
			)
		)

	var corpse_snapshots: Array[Values.CorpseSnapshot] = []
	for corpse: CorpseState in outdoor.corpse_states():
		var view: CombatSliceCorpseView = outdoor.corpse_view_for(
			corpse.corpse_item_instance_id
		)
		var location: WorldLocationState = outdoor.corpse_world_location(
			corpse.corpse_item_instance_id
		)
		if view == null or location == null:
			return Result.failure(
				Result.Outcome.CORPSE_BINDING_MISSING,
				"corpses[%s]" % String(corpse.corpse_item_instance_id),
			)
		var worn: Array[Values.CorpseWornItemSnapshot] = []
		for armor_type: StringName in corpse.occupied_worn_slots():
			worn.append(
				Values.CorpseWornItemSnapshot.new(
					armor_type,
					corpse.worn_item_in_slot(armor_type),
				)
			)
		corpse_snapshots.append(
			Values.CorpseSnapshot.new(
				corpse.corpse_item_instance_id,
				corpse.victim_character_id,
				corpse.victim_display_name,
				corpse.victim_gender,
				corpse.victim_age,
				corpse.decay_stage,
				corpse.maximum_contents_encumbrance,
				worn,
				_location_snapshot(location),
				_position_snapshot(view.global_position),
			)
		)

	var snapshot: GameSaveSnapshot = GameSaveSnapshot.new(
		Values.GameSaveMetadata.new(
			GameSaveSnapshot.FORMAT_ID,
			GameSaveSnapshot.CURRENT_SCHEMA_VERSION,
			saved_at_utc,
			Values.OptionalText.none() if build_commit == null else build_commit,
			storage_profile,
			GameSaveSnapshot.FIXED_SLOT_ID,
		),
		GameSaveSnapshot.SESSION_KIND_OLDPINE,
		session.item_id_allocator().snapshot(),
		player_snapshot,
		npc_snapshots,
		corpse_snapshots,
		item_capture.snapshot,
		session.combat_random_source().capture_random_state(),
		session.npc_random_source().capture_random_state(),
		session.world_interaction_random_source().capture_random_state(),
	)
	var root_validation: GameSaveResult = GameSaveSnapshotValidator.validate(snapshot)
	if not root_validation.succeeded():
		return Result.failure(
			Result.Outcome.INVALID_CAPTURED_SNAPSHOT,
			root_validation.path,
			root_validation.detail,
		)
	var complete_validation: OldPineWorldRestoreResult = (
		OldPineWorldRestoreComposition.prepare(snapshot)
	)
	if (
		complete_validation.outcome
		!= OldPineWorldRestoreResult.Outcome.SUCCESS
		or complete_validation.preparation == null
	):
		return Result.failure(
			Result.Outcome.INVALID_CAPTURED_SNAPSHOT,
			complete_validation.path,
			complete_validation.detail,
		)
	return Result.success(snapshot)


func _character_snapshot(
	state: CharacterState,
	path: String,
) -> Values.CharacterStateSnapshot:
	if state == null or _has_unrepresented_modifiers(state.attributes):
		_failure_path = path + ".attributes"
		_failure_detail = "unrepresented temporary attribute modifier"
		return null
	var raw_levels: Array[Values.SkillValueSnapshot] = []
	for skill_id: StringName in state.skills.raw_skill_ids():
		raw_levels.append(
			Values.SkillValueSnapshot.new(skill_id, state.skills.raw_level(skill_id))
		)
	var learned: Array[Values.SkillValueSnapshot] = []
	for skill_id: StringName in state.skills.learned_skill_ids():
		learned.append(
			Values.SkillValueSnapshot.new(
				skill_id,
				state.skills.learned_progress(skill_id),
			)
		)
	var mappings: Array[Values.SkillMappingSnapshot] = []
	for use_id: StringName in state.skills.enabled_use_ids():
		mappings.append(
			Values.SkillMappingSnapshot.new(
				use_id,
				state.skills.mapped_skill(use_id),
			)
		)
	var conditions: Array[Values.ConditionSnapshot] = []
	for condition_id: StringName in state.conditions.sorted_condition_ids():
		var payload: ConditionPayload = state.conditions.get_condition(condition_id)
		if payload is DurationConditionPayload:
			var duration: DurationConditionPayload = payload as DurationConditionPayload
			conditions.append(
				Values.ConditionSnapshot.duration(condition_id, duration.remaining)
			)
		elif payload is PoisonConditionPayload:
			var poison: PoisonConditionPayload = payload as PoisonConditionPayload
			conditions.append(
				Values.ConditionSnapshot.poison(
					condition_id,
					poison.damage,
					poison.remaining,
					poison.legacy_message,
				)
			)
		else:
			_failure_path = path + ".conditions[%s]" % String(condition_id)
			_failure_detail = "unsupported typed condition payload"
			return null
	return Values.CharacterStateSnapshot.new(
		state.gender,
		Values.BaseAttributesSnapshot.new(
			state.attributes.strength,
			state.attributes.courage,
			state.attributes.intelligence,
			state.attributes.spirituality,
			state.attributes.composure,
			state.attributes.personality,
			state.attributes.constitution,
			state.attributes.karma,
			state.attributes.force_factor,
			state.attributes.bellicosity,
		),
		_track(state.essence),
		_track(state.vitality),
		_track(state.spirit),
		Values.InternalResourcesSnapshot.new(
			state.recovery.inner_force.current,
			state.recovery.inner_force.maximum,
			state.recovery.mana.current,
			state.recovery.mana.maximum,
			state.recovery.atman.current,
			state.recovery.atman.maximum,
			state.recovery.food,
			state.recovery.water,
		),
		Values.ProgressionSnapshot.new(
			state.progression.combat_experience,
			state.progression.potential,
			state.progression.potential_spent,
		),
		Values.SkillStateSnapshot.new(
			state.skills.has_skills_mapping(),
			state.skills.has_learned_mapping(),
			raw_levels,
			learned,
			mappings,
		),
		conditions,
		Values.FamilySnapshot.new(
			state.family.family_id,
			state.family.generation,
		),
		Values.ApprenticeshipSnapshot.new(
			state.apprenticeship.master_teacher_id,
			state.apprenticeship.legacy_master_name,
			state.apprenticeship.betrayer_count,
		),
	)


func _character_failure() -> OldPineWorldCaptureResult:
	return Result.failure(
		Result.Outcome.UNREPRESENTED_CHARACTER_STATE,
		_failure_path,
		_failure_detail,
	)


static func _track(value: CharacterResourceState) -> Values.ResourceTrackSnapshot:
	return Values.ResourceTrackSnapshot.new(
		value.current,
		value.effective,
		value.maximum,
	)


static func _location_snapshot(
	value: WorldLocationState,
) -> Values.WorldLocationSnapshot:
	return Values.WorldLocationSnapshot.new(
		value.region_id,
		value.map_id,
		value.zone_id,
		value.combat_location_id,
	)


static func _position_snapshot(value: Vector2) -> Values.MapPositionSnapshot:
	return Values.MapPositionSnapshot.new(value.x, value.y)


static func _life_text(value: int) -> StringName:
	match value:
		CharacterRuntimeLifeStatus.Value.UNCONSCIOUS:
			return &"unconscious"
		CharacterRuntimeLifeStatus.Value.DEAD:
			return &"dead"
	return &"active"


static func _has_unrepresented_modifiers(
	attributes: CharacterBaseAttributes,
) -> bool:
	return (
		attributes == null
		or attributes.strength_modifier != 0
		or attributes.courage_modifier != 0
		or attributes.intelligence_modifier != 0
		or attributes.spirituality_modifier != 0
		or attributes.composure_modifier != 0
		or attributes.personality_modifier != 0
		or attributes.constitution_modifier != 0
		or attributes.karma_modifier != 0
	)
