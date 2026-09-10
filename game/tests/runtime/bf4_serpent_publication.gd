extends Node

## QA-only precondition + observation, loaded explicitly into a real New Game.
## Never bootstrapped by production. Sanitizer removes all res://tests/ files.
## DO NOT SAVE this QA Session. It deliberately has no production spawn slot.
const ID: StringName = &"qa.bf4.serpent"
## Owner-authorized Run B only. Ordinal script fixed BEFORE execution; -1
## means bound-1, not a negative draw. No seed search or adaptive branch policy.
class WoundedProofRandom extends CombatRandomSource:
	# Serpent: courage/action/limb/dodge/defender progression (all zero).
	# Player: courage/action/limb=0; dodge/parry=MAX; weapon/strength/defense=0;
	# wound=91; attacker progression=0; defender progression=MAX. Exactly once.
	const SCRIPT: Array[int] = [0, 0, 0, 0, 0, 0, 0, 0, -1, -1, 0, 0, 0, 91, 0, -1]
	var bounds: Array[int] = []
	var draws: Array[int] = []
	var valid: bool = true
	func next_below(bound: int) -> int:
		var index: int = bounds.size()
		bounds.append(bound)
		if index >= SCRIPT.size() or bound <= 0:
			valid = false
			draws.append(-1)
			return -1
		var draw: int = bound - 1 if SCRIPT[index] == -1 else SCRIPT[index]
		valid = valid and draw >= 0 and draw < bound
		draws.append(draw)
		return draw

var session: OldPineWorldSessionController
var npc: NpcRuntimeState
var body: WorldCharacterBody2D
var observed_scheduler: CombatEncounterScheduler
var saw_encounter: bool = false
var initial: Dictionary[String, Variant] = {}
var proof_random: WoundedProofRandom
var player_precondition: Dictionary[String, Variant] = {}


func publish(value: OldPineWorldSessionController, wounded: bool = false) -> bool:
	if session != null or value == null or not value.is_initialized():
		return false
	var map: OldPineOutdoorController = value.outdoor_map()
	if value.combat_encounter_coordinator().has_active_encounter() or map.npc_runtimes().size() != 5:
		return false
	session = value
	npc = NpcCharacterStateFactory.new().create_one(
		OldPineNpcDefinitions.serpent_definition(), ID, &"qa.bf4.spawn", &"qa.bf4.point",
		map.player_runtime().world_location(), session.inventory_state(),
		session.stack_collection(), session.npc_random_source(), [],
	)
	if npc == null:
		return false
	if wounded:
		npc.character_state.vitality = CharacterResourceState.new(1, 1, 1800)
	body = WorldCharacterBody2D.new()
	body.name = "QAOnlySerpent"
	body.position = Vector2(700, 300) # Existing clearing, NOT authored serpent geography.
	var shape: CollisionShape2D = CollisionShape2D.new()
	shape.name = "CollisionShape2D"
	var rectangle: RectangleShape2D = RectangleShape2D.new()
	rectangle.size = Vector2(36, 36)
	shape.shape = rectangle
	body.add_child(shape)
	var visual: ColorRect = ColorRect.new()
	visual.position = Vector2(-18, -18)
	visual.size = Vector2(36, 36)
	visual.color = Color(0.2, 0.3, 0.2)
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(visual)
	var label: Label = Label.new()
	label.name = "NameLabel"
	label.position = Vector2(-55, -48)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(label)
	var presence: Area2D = Area2D.new()
	presence.name = "AggressionPresence"
	presence.collision_layer = 0
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = 80.0
	var presence_shape: CollisionShape2D = CollisionShape2D.new()
	presence_shape.shape = circle
	presence.add_child(presence_shape)
	body.add_child(presence)
	map.get_node("Characters").add_child(body)
	if not map.register_npc_body(npc, body, presence, CombatSliceContentProfile.new()):
		body.queue_free()
		return false
	initial = facts()
	initial["wounded_precondition"] = wounded
	print("BF4 QA ONLY; production Save forbidden for this test Session: ", initial)
	return true


## Call once, before physical approach. Does not initiate combat or mutate NPC.
func prepare_wounded_proof() -> bool:
	if session == null or proof_random != null or not initial.get("wounded_precondition", false):
		return false
	if session.combat_encounter_coordinator().has_active_encounter():
		return false
	var player: CharacterState = session.player_runtime().state
	var attributes: CharacterBaseAttributes = player.attributes
	player_precondition = {"base_strength": attributes.strength,
		"force_factor": attributes.force_factor, "modifier_before": attributes.strength_modifier,
		"experience_before": player.progression.combat_experience}
	attributes.strength_modifier = 200 - attributes.strength - attributes.force_factor
	player.progression.combat_experience = 250000
	player_precondition["modifier_after"] = attributes.strength_modifier
	player_precondition["experience_after"] = player.progression.combat_experience
	player_precondition["effective_strength"] = CombatMath.effective_strength(CombatStrengthProjection.new(
		attributes.strength, attributes.force_factor, attributes.strength_modifier))
	proof_random = WoundedProofRandom.new()
	return session.configure_combat_random_source(proof_random)


func remove_publication() -> bool:
	if not is_instance_valid(session) or not session.outdoor_map().unregister_npc_body(ID):
		return false
	body.queue_free()
	return true


func _process(_delta: float) -> void:
	if not is_instance_valid(session):
		return
	var current: CombatEncounterScheduler = session.combat_encounter_coordinator().active_scheduler()
	if current != null:
		observed_scheduler = current
		saw_encounter = true


func facts() -> Dictionary[String, Variant]:
	var state: CharacterState = npc.character_state
	var content: CombatSliceContentProfile = WorldCombatBindingAdapter.from_npc(npc, CombatSliceContentProfile.new()).content
	return {
		"id": npc.character_id, "name": npc.definition().display_name,
		"age": npc.age, "weight": npc.body_weight, "capacity": npc.maximum_encumbrance,
		"kee": [state.vitality.current, state.vitality.effective, state.vitality.maximum],
		"exp": state.progression.combat_experience,
		"limbs": content.limbs(), "verbs": npc.definition().authored_combat_facts().verbs(),
		"intrinsic": [content.intrinsic_attack, npc.definition().authored_combat_facts().intrinsic_damage, content.intrinsic_armor, content.intrinsic_dodge],
		"exists": npc.exists_in_map, "life": npc.life_status,
	}


func evidence() -> Dictionary[String, Variant]:
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	var actions: Array[Dictionary] = []
	if observed_scheduler != null:
		for event: CombatSchedulerEvent in observed_scheduler.events():
			if event.resolution == null or event.resolution.forward_result == null:
				continue
			var attack: CombatSingleAttackExecutionResult = event.resolution.forward_result
			var record: Dictionary[String, Variant] = {"actor": event.actor_id, "action": attack.selected_action_id,
				"selection_bounds": [] if attack.action_selection_result == null else attack.action_selection_result.random_upper_bounds()}
			if attack.ordinary_attack_result != null and attack.ordinary_attack_result.has_base_result:
				var result: CombatAttackResult = attack.ordinary_attack_result.base_result
				var calculation: CombatAttackCalculation = result.calculation
				record.merge({"outcome": result.outcome, "threshold": result.threshold_candidate,
					"strength": calculation.initial_strength_bonus, "weapon": attack.post_action_weapon_id,
					"apply_damage": calculation.base_apply_damage, "damage": calculation.requested_damage,
					"armor": calculation.armor, "wound": calculation.wound_amount,
					"bounds": calculation.random_upper_bounds(), "draws": calculation.random_draws(),
					"effective_after": result.resource_mutation.vitality_effective_after})
			actions.append(record)
	var lifecycle: Array[Dictionary] = []
	for receipt: CombatSliceLifecycleResult in session.outdoor_map().last_lifecycle_results():
		lifecycle.append({"victim": receipt.victim_id, "outcome": receipt.outcome,
			"requested": receipt.requested_kind, "stage": receipt.partial_stage,
			"death_inventory": -1 if receipt.death_inventory_result == null else receipt.death_inventory_result.outcome,
			"corpse": receipt.corpse_item_instance_id})
	return {"initial": initial, "now": facts(), "saw_encounter": saw_encounter,
		"player_precondition": player_precondition, "lifecycle": lifecycle,
		"rng_bounds": [] if proof_random == null else proof_random.bounds,
		"rng_draws": [] if proof_random == null else proof_random.draws,
		"rng_valid": proof_random == null or proof_random.valid,
		"active": coordinator.has_active_encounter(), "scheduler": coordinator.active_scheduler() != null,
		"world_open": session.world_simulation_gate().is_open(), "old_cadence": session.outdoor_map().cadence_is_running(),
		"actions": actions, "player_life": session.player_runtime().life_status,
		"corpses": session.outdoor_map().corpse_states().size(),
		"player_position": session.outdoor_map().player_body.position,
		"terminal": -1 if coordinator.last_completion() == null else coordinator.last_completion().terminal_result.kind}
