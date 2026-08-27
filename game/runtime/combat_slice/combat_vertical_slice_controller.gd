class_name CombatVerticalSliceController
extends Node2D

const PLAYER_NAME: String = "Player"
const ENEMY_NAME: String = "Human Swordfighter"

@onready var player_body: CombatSliceCharacterBody = $Player
@onready var enemy_body: CombatSliceCharacterBody = $Enemy
@onready var opportunity_timer: Timer = $OpportunityTimer
@onready var hud: CombatSliceHud = $HUD

var player_binding: CombatSliceCharacterBinding
var enemy_binding: CombatSliceCharacterBinding
var inventory_state: InventoryState
var _participants: Array[CombatSliceCharacterBinding] = []
var _selected_target: CombatSliceCharacterBinding
var _random_source: CombatRandomSource
var _presenter: CombatSlicePresenter = CombatSlicePresenter.new()
var _effect_registry: SkillImprovementEffectRegistry
var _lifecycle_pending: bool = false
var _last_tick_order: Array[StringName] = []


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
	if _lifecycle_pending:
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
		_present(actor, result)
		if result.outcome in [
			CombatSliceOpportunityResult.Outcome.LIFECYCLE_REQUIRED_UNCONSCIOUS,
			CombatSliceOpportunityResult.Outcome.LIFECYCLE_REQUIRED_DEATH,
		]:
			_lifecycle_pending = true
			opportunity_timer.stop()
			break
	if not _has_active_relationships():
		opportunity_timer.stop()
	hud.refresh_live_state()
	return results


func last_tick_order() -> Array[StringName]:
	return _last_tick_order.duplicate()


func lifecycle_is_pending() -> bool:
	return _lifecycle_pending


func _initialize_encounter() -> void:
	var created: Array[CombatSliceCharacterBinding] = (
		CombatSliceDemoFactory.create_participants()
	)
	player_binding = created[0]
	enemy_binding = created[1]
	_participants.assign(created)
	inventory_state = CombatSliceDemoFactory.create_inventory_for(_participants)
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


func _has_active_relationships() -> bool:
	for participant: CombatSliceCharacterBinding in _participants:
		if participant.relationship.is_fighting():
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
