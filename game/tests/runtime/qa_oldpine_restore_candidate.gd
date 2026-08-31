extends Node

const SessionScene := preload(
	"res://scenes/world/oldpine/oldpine_world_session.tscn"
)
const Fixture := preload(
	"res://tests/support/oldpine_world_save_fixture.gd"
)
const Values := preload("res://core/persistence/game_save_value_types.gd")


func _ready() -> void:
	call_deferred("_run_qa")


func _run_qa() -> void:
	var source: OldPineWorldSessionController = SessionScene.instantiate()
	source.deterministic_npc_seed = true
	source.npc_seed = 10_031
	source.deterministic_combat_seed = true
	source.combat_seed = 10_032
	source.deterministic_world_interaction_seed = true
	source.world_interaction_seed = 10_033
	add_child(source)
	var pine_location := Values.WorldLocationSnapshot.new(
		OldPineWorldDefinitions.REGION_ID,
		OldPineWorldDefinitions.OUTDOOR_MAP_ID,
		OldPineWorldDefinitions.PINE_ENTRANCE_ZONE_ID,
		OldPineWorldDefinitions.PINE_ENTRANCE_ZONE_ID,
	)
	var base: GameSaveSnapshot = Fixture.from_new_game(
		source,
		pine_location,
		Values.MapPositionSnapshot.new(-300.0, 400.0),
	)
	var snapshot: GameSaveSnapshot = Fixture.with_fat_bandit_corpse(base)
	remove_child(source)
	source.free()
	await get_tree().process_frame

	var restored: OldPineWorldRestoreResult = (
		OldPineWorldRestoreService.build_candidate(snapshot, self)
	)
	if not restored.succeeded():
		push_error(
			"PHASE10B3_QA restore failed: %s %s"
			% [restored.path, restored.detail]
		)
		return
	var candidate: OldPineWorldSessionController = restored.candidate
	candidate.name = "RestoredOldPineWorldSession"
	var rng_unchanged: bool = (
		_same_random(candidate.combat_random_source().capture_random_state(), snapshot.combat_rng)
		and _same_random(candidate.npc_random_source().capture_random_state(), snapshot.npc_initialization_rng)
		and _same_random(candidate.world_interaction_random_source().capture_random_state(), snapshot.world_interaction_rng)
	)
	if (
		candidate.inventory_state().registered_item_ids().size() != 13
		or candidate.outdoor_map().npc_runtimes().size() != 5
		or candidate.outdoor_map().corpse_states().size() != 1
		or candidate.active_map_id() != OldPineWorldDefinitions.OUTDOOR_MAP_ID
		or candidate.cave_map().get_parent() != null
		or not rng_unchanged
	):
		push_error("PHASE10B3_QA staged authority invariant failed")
		return
	if not candidate.activate_restore_candidate():
		push_error("PHASE10B3_QA candidate activation failed")
		return
	var corpse: CorpseState = candidate.outdoor_map().corpse_states()[0]
	var corpse_view: CombatSliceCorpseView = (
		candidate.outdoor_map().corpse_view_for(corpse.corpse_item_instance_id)
	)
	print(
		(
			"PHASE10B3_QA_READY active=%s items=%d npcs=%d corpses=%d "
			+ "player_position=%s corpse_position=%s rng_unchanged=%s"
		) % [
			candidate.active_map_id(),
			candidate.inventory_state().registered_item_ids().size(),
			candidate.outdoor_map().npc_runtimes().size(),
			candidate.outdoor_map().corpse_states().size(),
			candidate.outdoor_map().player_body.global_position,
			corpse_view.global_position,
			rng_unchanged,
		]
	)


func _same_random(actual: RandomStreamSnapshot, expected: RandomStreamSnapshot) -> bool:
	return (
		actual.adapter_id == expected.adapter_id
		and actual.seed == expected.seed
		and actual.state == expected.state
	)
