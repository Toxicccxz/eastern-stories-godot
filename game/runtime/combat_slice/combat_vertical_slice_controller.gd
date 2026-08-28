class_name CombatVerticalSliceController
extends Node2D

const PLAYER_NAME: String = "Player"
const ENEMY_NAME: String = "Human Swordfighter"

@onready var player_body: CombatSliceCharacterBody = $Player
@onready var enemy_body: CombatSliceCharacterBody = $Enemy
@onready var opportunity_timer: Timer = $OpportunityTimer
@onready var corpse_layer: Node2D = $CorpseLayer
@onready var hud: CombatSliceHud = $HUD

var player_binding: CombatSliceCharacterBinding
var enemy_binding: CombatSliceCharacterBinding
var inventory_state: InventoryState
var stack_collection: CombinedStackCollection
var _participants: Array[CombatSliceCharacterBinding] = []
var _selected_target: CombatSliceCharacterBinding
var _random_source: CombatRandomSource
var _presenter: CombatSlicePresenter = CombatSlicePresenter.new()
var _effect_registry: SkillImprovementEffectRegistry
var _lifecycle_failed: bool = false
var _last_tick_order: Array[StringName] = []
var _last_lifecycle_results: Array[CombatSliceLifecycleResult] = []
var _corpse_states: Array[CorpseState] = []
var _corpse_decay_intents: Array[CorpseDecayScheduleIntent] = []
var _corpse_sequence: int = 0
var _encounter_identity: StringName = &""


func _ready() -> void:
	_initialize_encounter()


func configure_random_source(value: CombatRandomSource) -> bool:
	if value == null or not opportunity_timer.is_stopped():
		return false
	_random_source = value
	return true


func select_enemy() -> bool:
	if enemy_binding == null or not enemy_binding.is_valid():
		return false
	_selected_target = enemy_binding
	hud.set_target_selected(true)
	return true


func initiate_selected_combat() -> CombatSliceInitiationResult:
	if _selected_target == null:
		return CombatSliceInitiationResult.new()
	var result: CombatSliceInitiationResult = (
		CombatSliceOpportunityExecutor.initiate_lethal_combat(
			player_binding,
			_selected_target,
		)
	)
	if result.outcome == CombatSliceInitiationResult.Outcome.COMPLETED:
		if opportunity_timer.is_stopped():
			opportunity_timer.start()
		hud.set_combat_started(true)
		hud.append_log_lines(["Combat initiated"])
	return result


func process_cadence_tick() -> Array[CombatSliceOpportunityResult]:
	var results: Array[CombatSliceOpportunityResult] = []
	_last_tick_order.clear()
	_last_lifecycle_results.clear()
	if _lifecycle_failed:
		return results
	for actor: CombatSliceCharacterBinding in _participants:
		if not actor.exists_in_encounter or not actor.relationship.is_fighting():
			continue
		_last_tick_order.append(actor.character_id)
		var result: CombatSliceOpportunityResult = (
			CombatSliceOpportunityExecutor.execute_opportunity(
				actor,
				_participants,
				_random_source,
				_effect_registry,
			)
		)
		results.append(result)
		if result.outcome in [
			CombatSliceOpportunityResult.Outcome.LIFECYCLE_REQUIRED_UNCONSCIOUS,
			CombatSliceOpportunityResult.Outcome.LIFECYCLE_REQUIRED_DEATH,
		]:
			var lifecycle: CombatSliceLifecycleResult = _execute_lifecycle(actor, result)
			_last_lifecycle_results.append(lifecycle)
			_present_lifecycle(actor, lifecycle)
			if not lifecycle.completed():
				_lifecycle_failed = true
				opportunity_timer.stop()
				break
		else:
			_present(actor, result)
	if not _has_active_relationships():
		opportunity_timer.stop()
		hud.set_combat_started(false)
	hud.refresh_live_state()
	return results


func last_tick_order() -> Array[StringName]:
	return _last_tick_order.duplicate()


func lifecycle_is_pending() -> bool:
	return _lifecycle_failed


func last_lifecycle_results() -> Array[CombatSliceLifecycleResult]:
	return _last_lifecycle_results.duplicate()


func corpse_states() -> Array[CorpseState]:
	return _corpse_states.duplicate()


func corpse_decay_intents() -> Array[CorpseDecayScheduleIntent]:
	return _corpse_decay_intents.duplicate()


func _initialize_encounter() -> void:
	_encounter_identity = StringName("combat-slice-encounter-%d" % get_instance_id())
	var created: Array[CombatSliceCharacterBinding] = (
		CombatSliceDemoFactory.create_participants()
	)
	player_binding = created[0]
	enemy_binding = created[1]
	_participants.assign(created)
	inventory_state = CombatSliceDemoFactory.create_inventory_for(_participants)
	stack_collection = CombinedStackCollection.new()
	_random_source = GodotCombatRandomSource.new()
	_effect_registry = SkillImprovementEffectRegistry.new()
	_effect_registry.register_legacy_defaults()
	player_body.player_controlled = true
	player_body.display_name = PLAYER_NAME
	enemy_body.player_controlled = false
	enemy_body.display_name = ENEMY_NAME
	player_body.bind_character(player_binding)
	enemy_body.bind_character(enemy_binding)
	hud.configure(player_binding, enemy_binding)
	opportunity_timer.stop()


func _execute_lifecycle(
	victim: CombatSliceCharacterBinding,
	opportunity: CombatSliceOpportunityResult,
) -> CombatSliceLifecycleResult:
	var corpse_position: Vector2 = _body_for(victim).position
	var killer: CombatSliceCharacterBinding = _other_participant(victim)
	_corpse_sequence += 1
	var corpse_id: StringName = StringName(
		"%s-corpse-%d" % [String(_encounter_identity), _corpse_sequence]
	)
	var arena_destination: InventoryTransferDestination = (
		InventoryTransferDestination.new(
			ContainmentEndpoint.new(
				ContainmentEndpoint.Kind.WORLD,
				CombatSliceDemoFactory.ARENA_ID,
			),
			true,
			true,
			1000000,
		)
	)
	var lifecycle: CombatSliceLifecycleResult = CombatSliceLifecycleAdapter.new().execute(
		opportunity,
		victim,
		_participants,
		killer,
		inventory_state,
		stack_collection,
		corpse_id,
		arena_destination,
		CombatSliceDemoFactory.create_death_item_facts_for(victim, inventory_state),
		DeathItemPolicyRegistry.new(),
		DeathRewearPolicyRegistry.new(),
	)
	var body: CombatSliceCharacterBody = _body_for(victim)
	body.refresh_runtime_state()
	if lifecycle.death_inventory_result != null:
		var corpse: CorpseState = lifecycle.death_inventory_result.corpse_state
		if corpse != null and _remember_corpse(corpse):
			_spawn_corpse_view(corpse, corpse_position)
		var intent: CorpseDecayScheduleIntent = (
			lifecycle.death_inventory_result.initial_decay_intent
		)
		if intent != null:
			_corpse_decay_intents.append(intent)
	if victim == enemy_binding:
		hud.set_target_terminal_status(victim.life_status)
	return lifecycle


func _remember_corpse(corpse: CorpseState) -> bool:
	for existing: CorpseState in _corpse_states:
		if existing.corpse_item_instance_id == corpse.corpse_item_instance_id:
			return false
	_corpse_states.append(corpse)
	return true


func _spawn_corpse_view(corpse: CorpseState, corpse_position: Vector2) -> void:
	var view: CombatSliceCorpseView = CombatSliceCorpseView.new()
	if not view.configure(corpse):
		return
	view.position = corpse_position
	corpse_layer.add_child(view)


func _body_for(binding: CombatSliceCharacterBinding) -> CombatSliceCharacterBody:
	return player_body if binding == player_binding else enemy_body


func _other_participant(
	binding: CombatSliceCharacterBinding,
) -> CombatSliceCharacterBinding:
	for participant: CombatSliceCharacterBinding in _participants:
		if participant != binding:
			return participant
	return null


func _present(
	actor: CombatSliceCharacterBinding,
	result: CombatSliceOpportunityResult,
) -> void:
	var actor_is_player: bool = actor.character_id == player_binding.character_id
	var actor_name: String = PLAYER_NAME if actor_is_player else ENEMY_NAME
	var victim_name: String = ENEMY_NAME if actor_is_player else PLAYER_NAME
	hud.append_log_lines(
		_presenter.describe_opportunity(result, actor_name, victim_name)
	)
	hud.refresh_live_state()


func _present_lifecycle(
	victim: CombatSliceCharacterBinding,
	result: CombatSliceLifecycleResult,
) -> void:
	var victim_name: String = PLAYER_NAME if victim == player_binding else ENEMY_NAME
	hud.append_log_lines(_presenter.describe_lifecycle(result, victim_name))
	if victim == player_binding and victim.life_status == CombatSliceLifeStatus.Value.DEAD:
		hud.append_log_lines(["Player defeated. Reset to begin a fresh encounter."])
	hud.refresh_live_state()


func _has_active_relationships() -> bool:
	for participant: CombatSliceCharacterBinding in _participants:
		if participant.exists_in_encounter and participant.relationship.is_fighting():
			return true
	return false


func _on_enemy_selection_requested(_character_id: StringName) -> void:
	select_enemy()


func _on_attack_button_pressed() -> void:
	initiate_selected_combat()


func _on_opportunity_timer_timeout() -> void:
	process_cadence_tick()


func _on_reset_button_pressed() -> void:
	get_tree().reload_current_scene()
