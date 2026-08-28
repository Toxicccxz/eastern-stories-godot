extends RefCounted

const SCENE_PATH: String = "res://scenes/combat/combat_vertical_slice.tscn"
const ScriptedRandomScript := preload(
	"res://tests/support/scripted_combat_random_source.gd"
)

var _assertion_count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_godot_random_adapter()
	_test_persisted_project_configuration()
	await _test_scene_smoke_and_live_presentation(tree)
	await _test_movement_and_arena_collision(tree)
	await _test_stable_order_and_lifecycle_staging(tree)
	await _test_player_threshold_waits_for_next_opportunity(tree)
	await _test_reset_reloads_fresh_encounter(tree)
	return {
		"assertions": _assertion_count,
		"failures": _failures.duplicate(),
	}


func _test_godot_random_adapter() -> void:
	var left: GodotCombatRandomSource = GodotCombatRandomSource.new(123456, true)
	var right: GodotCombatRandomSource = GodotCombatRandomSource.new(123456, true)
	for bound: int in [1, 4, 60, 16, 120]:
		var left_draw: int = left.next_below(bound)
		var right_draw: int = right.next_below(bound)
		_assert_eq(left_draw, right_draw, "equal seeds preserve one deterministic stream")
		_assert_true(
			left_draw >= 0 and left_draw < bound,
			"Godot adapter honors exclusive bound",
		)
	_assert_eq(left.next_below(0), -1, "invalid zero bound is not clamped")
	_assert_eq(left.next_below(-5), -1, "invalid negative bound is not randomized")


func _test_persisted_project_configuration() -> void:
	var configured_main: String = String(
		ProjectSettings.get_setting("application/run/main_scene", "")
	)
	var resolved_main: String = configured_main
	if configured_main.begins_with("uid://"):
		resolved_main = ResourceUID.get_id_path(ResourceUID.text_to_id(configured_main))
	_assert_eq(resolved_main, SCENE_PATH, "project main scene resolves to the persisted arena")
	_assert_eq(
		_input_action_names(),
		["move_down", "move_left", "move_right", "move_up"],
		"only the four Phase 6B2 movement actions are authored",
	)
	_assert_key_bindings(&"move_left", [KEY_A, KEY_LEFT])
	_assert_key_bindings(&"move_right", [KEY_D, KEY_RIGHT])
	_assert_key_bindings(&"move_up", [KEY_W, KEY_UP])
	_assert_key_bindings(&"move_down", [KEY_S, KEY_DOWN])


func _test_scene_smoke_and_live_presentation(tree: SceneTree) -> void:
	var controller: CombatVerticalSliceController = _instantiate_scene(tree)
	_assert_true(controller != null, "vertical slice scene loads and instantiates")
	if controller == null:
		return
	await tree.physics_frame
	_assert_eq(
		_top_level_tree(controller),
		[
			"Arena:Node2D",
			"Player:CharacterBody2D",
			"Enemy:CharacterBody2D",
			"Camera2D:Camera2D",
			"OpportunityTimer:Timer",
			"CorpseLayer:Node2D",
			"HUD:CanvasLayer",
		],
		"persisted scene has the exact documented top-level tree",
	)
	_assert_true(
		controller.get_node_or_null("Arena/TopWall/CollisionShape2D") is CollisionShape2D,
		"top wall collision shape persists",
	)
	_assert_true(
		controller.get_node_or_null("Arena/BottomWall/CollisionShape2D") is CollisionShape2D,
		"bottom wall collision shape persists",
	)
	_assert_true(
		controller.get_node_or_null("Arena/LeftWall/CollisionShape2D") is CollisionShape2D,
		"left wall collision shape persists",
	)
	_assert_true(
		controller.get_node_or_null("Arena/RightWall/CollisionShape2D") is CollisionShape2D,
		"right wall collision shape persists",
	)
	_assert_true(
		controller.player_body.get_node_or_null("CollisionShape2D") is CollisionShape2D,
		"player collision shape persists",
	)
	_assert_true(
		controller.enemy_body.get_node_or_null("CollisionShape2D") is CollisionShape2D,
		"enemy collision shape persists",
	)
	var camera: Camera2D = controller.get_node("Camera2D") as Camera2D
	_assert_true(camera.enabled, "arena Camera2D is active")
	_assert_true(controller.player_body.player_controlled, "shared body enables only player movement")
	_assert_false(controller.enemy_body.player_controlled, "shared enemy body remains stationary")
	_assert_true(controller.get_node_or_null("CorpseLayer") is Node2D, "empty corpse placeholder exists")
	_assert_eq(
		(controller.get_node("CorpseLayer") as Node2D).get_child_count(),
		0,
		"corpse placeholder has no Phase 6B3 behavior",
	)
	_assert_independent_bindings(controller)
	_assert_inventory_equipment_coherence(controller)
	_assert_eq(controller.player_binding.location_id, CombatSliceDemoFactory.ARENA_ID, "player uses stable arena location")
	_assert_eq(controller.enemy_binding.location_id, CombatSliceDemoFactory.ARENA_ID, "enemy uses stable arena location")
	_assert_eq(controller.opportunity_timer.wait_time, 1.0, "cadence is exactly one second")
	_assert_false(controller.opportunity_timer.one_shot, "cadence timer repeats")
	_assert_false(controller.opportunity_timer.autostart, "cadence timer does not autostart")
	_assert_true(controller.opportunity_timer.is_stopped(), "timer starts stopped")
	_assert_eq(controller.hud.player_vitality_display(), "220 / 220 / 220", "HUD reads live player vitality triple")
	_assert_eq(controller.hud.enemy_vitality_display(), "220 / 220 / 220", "HUD reads live enemy vitality triple")
	_assert_false(controller.hud.attack_is_enabled(), "attack starts disabled without selection")
	_assert_eq(controller.enemy_body.get_signal_connection_list("selection_requested").size(), 1, "enemy selection signal is connected once")
	_assert_eq(controller.opportunity_timer.get_signal_connection_list("timeout").size(), 1, "timer timeout signal is connected once")
	_assert_eq(controller.hud.attack_button.get_signal_connection_list("pressed").size(), 1, "Attack signal is connected once")
	var reset_button: Button = controller.get_node(
		"HUD/HudRoot/BottomPanel/BottomBox/Actions/ResetButton"
	) as Button
	_assert_eq(reset_button.get_signal_connection_list("pressed").size(), 1, "Reset signal is connected once")
	var scripted: ScriptedCombatRandomSource = ScriptedRandomScript.new(
		_regular_hit_draws(8)
	)
	_assert_true(controller.configure_random_source(scripted), "stopped encounter accepts deterministic test source")
	await _click_enemy_through_viewport(controller, tree)
	_assert_true(controller.hud.attack_is_enabled(), "actual physics picking enables Attack")
	_assert_eq(controller.hud.selected_target_label.text, "Selected: Human Swordfighter", "actual click updates target HUD")
	if not controller.hud.attack_is_enabled():
		controller.select_enemy()
	var player_before_attack: Array[int] = _resource_snapshot(controller.player_binding.state)
	var enemy_before_attack: Array[int] = _resource_snapshot(controller.enemy_binding.state)
	controller.hud.attack_button.pressed.emit()
	_assert_eq(scripted.call_count(), 0, "Attack initiation consumes no combat opportunity RNG")
	_assert_eq(controller.last_tick_order(), [], "Attack initiation executes no immediate opportunity")
	_assert_eq(_resource_snapshot(controller.player_binding.state), player_before_attack, "Attack initiation does not mutate player resources")
	_assert_eq(_resource_snapshot(controller.enemy_binding.state), enemy_before_attack, "Attack initiation does not mutate enemy resources")
	_assert_true(controller.player_binding.relationship.has_opponent(controller.enemy_binding.character_id), "player opponent is established")
	_assert_true(controller.enemy_binding.relationship.has_opponent(controller.player_binding.character_id), "enemy opponent is established")
	_assert_true(controller.player_binding.relationship.has_lethal_target(controller.enemy_binding.character_id), "Attack delegates player lethal marker to Phase 6B1")
	_assert_true(controller.enemy_binding.relationship.has_lethal_target(controller.player_binding.character_id), "Attack delegates reciprocal lethal marker to Phase 6B1")
	_assert_false(controller.opportunity_timer.is_stopped(), "successful initiation starts cadence")
	_assert_false(controller.hud.attack_is_enabled(), "active encounter disables repeated Attack input")
	var time_before_disabled_press: float = controller.opportunity_timer.time_left
	controller.hud.attack_button.pressed.emit()
	_assert_approx(controller.opportunity_timer.time_left, time_before_disabled_press, 0.0001, "repeated signal cannot restart the running Timer")
	_assert_eq(controller.player_binding.relationship.opponent_ids().size(), 1, "repeated initiation cannot duplicate player opponent")
	_assert_eq(controller.enemy_binding.relationship.opponent_ids().size(), 1, "repeated initiation cannot duplicate enemy opponent")
	_assert_eq(scripted.call_count(), 0, "repeated initiation cannot reset or consume encounter RNG")
	controller.opportunity_timer.stop()
	controller.player_binding.state.vitality = CharacterResourceState.new(10000, 10000, 10000)
	controller.enemy_binding.state.vitality = CharacterResourceState.new(10000, 10000, 10000)
	var first_results: Array[CombatSliceOpportunityResult] = controller.process_cadence_tick()
	var draws_after_first_tick: int = scripted.call_count()
	var second_results: Array[CombatSliceOpportunityResult] = controller.process_cadence_tick()
	_assert_eq(first_results.size(), 2, "one timeout processes each eligible participant once")
	_assert_eq(second_results.size(), 2, "next timeout again processes each participant once")
	_assert_eq(controller.last_tick_order(), [CombatSliceDemoFactory.PLAYER_ID, CombatSliceDemoFactory.ENEMY_ID], "timeout order is stable player then enemy")
	_assert_true(draws_after_first_tick > 0, "first timeout consumes the injected encounter stream")
	_assert_true(scripted.call_count() > draws_after_first_tick, "same injected RNG stream continues across timeouts")
	_assert_true(controller.hud.log_lines().size() > 0, "typed results produce combat log cues")
	_assert_true(controller.hud.log_lines().size() <= CombatSliceHud.MAX_LOG_LINES, "combat log remains bounded")
	controller.enemy_binding.state.vitality.current = -7
	controller.hud.refresh_live_state()
	_assert_eq(controller.hud.enemy_vitality.value, 0.0, "HUD bar visually clamps negative current only")
	_assert_eq(controller.hud.enemy_vitality_display(), "-1 / 10000 / 10000", "HUD text preserves negative authoritative current")
	if not first_results.is_empty():
		var presenter: CombatSlicePresenter = CombatSlicePresenter.new()
		var before_present: Array[int] = _resource_snapshot(controller.enemy_binding.state)
		presenter.describe_opportunity(first_results[0], "Player", "Enemy")
		_assert_eq(_resource_snapshot(controller.enemy_binding.state), before_present, "presentation does not mutate Core state")
	controller.queue_free()
	await tree.process_frame


func _test_movement_and_arena_collision(tree: SceneTree) -> void:
	var controller: CombatVerticalSliceController = _instantiate_scene(tree)
	if controller == null:
		_assert_true(false, "movement scene instantiates")
		return
	await tree.physics_frame
	var body: CombatSliceCharacterBody = controller.player_body
	var enemy_start: Vector2 = controller.enemy_body.position
	controller.enemy_body._physics_process(1.0 / 60.0)
	_assert_eq(controller.enemy_body.position, enemy_start, "NPC body has no movement AI")
	body.position = Vector2(300.0, 450.0)
	await tree.physics_frame
	Input.action_press("move_right")
	Input.action_press("move_down")
	body._physics_process(1.0 / 60.0)
	Input.action_release("move_right")
	Input.action_release("move_down")
	_assert_approx(body.velocity.length(), 220.0, 0.01, "diagonal input is normalized to fixed speed")
	await _drive_to_wall(body, &"move_left", Vector2(300.0, 450.0), tree)
	_assert_true(body.position.x >= 63.9, "left wall keeps player inside arena")
	await _drive_to_wall(body, &"move_right", Vector2(300.0, 450.0), tree)
	_assert_true(body.position.x <= 896.1, "right wall keeps player inside arena")
	await _drive_to_wall(body, &"move_up", Vector2(480.0, 300.0), tree)
	_assert_true(body.position.y >= 63.9, "top wall keeps player inside arena")
	await _drive_to_wall(body, &"move_down", Vector2(480.0, 300.0), tree)
	_assert_true(body.position.y <= 516.1, "bottom wall keeps player inside arena")
	_assert_eq(controller.player_binding.location_id, CombatSliceDemoFactory.ARENA_ID, "physical movement does not replace stable binding location")
	controller.queue_free()
	await tree.process_frame


func _test_stable_order_and_lifecycle_staging(tree: SceneTree) -> void:
	var controller: CombatVerticalSliceController = _instantiate_scene(tree)
	if controller == null:
		_assert_true(false, "lifecycle staging scene instantiates")
		return
	var scripted: ScriptedCombatRandomSource = ScriptedRandomScript.new(
		_regular_hit_draws(1)
	)
	_assert_true(controller.configure_random_source(scripted), "lifecycle test injects one encounter RNG before start")
	controller.select_enemy()
	controller.initiate_selected_combat()
	controller.opportunity_timer.stop()
	controller.enemy_binding.state.vitality.current = 0
	var player_before: Array[int] = _resource_snapshot(controller.player_binding.state)
	var relationship_before: Array[StringName] = controller.enemy_binding.relationship.opponent_ids()
	var results: Array[CombatSliceOpportunityResult] = controller.process_cadence_tick()
	_assert_eq(results.size(), 2, "player damage then enemy lifecycle gate run in the same timeout")
	_assert_eq(controller.last_tick_order(), [CombatSliceDemoFactory.PLAYER_ID, CombatSliceDemoFactory.ENEMY_ID], "lifecycle staging preserves stable participant order")
	_assert_eq(controller.enemy_binding.state.vitality.current, 0, "enemy gate immediately consumes the crossed threshold and zeroes current vitality")
	_assert_eq(results[1].outcome, CombatSliceOpportunityResult.Outcome.LIFECYCLE_REQUIRED_UNCONSCIOUS, "enemy next outer opportunity observes the crossed threshold")
	_assert_eq(_resource_snapshot(controller.player_binding.state), player_before, "enemy lifecycle gate executes no enemy attack")
	_assert_false(controller.lifecycle_is_pending(), "completed unconscious lifecycle is not a pending failure")
	_assert_eq(controller.enemy_binding.life_status, CombatSliceLifeStatus.Value.UNCONSCIOUS, "outer lifecycle immediately marks enemy unconscious")
	_assert_true(controller.enemy_binding.relationship.opponent_ids().is_empty(), "unconscious victim clears its local opponents")
	_assert_true(controller.player_binding.relationship.has_opponent(controller.enemy_binding.character_id), "lethal attacker may retain the unconscious victim")
	_assert_false(controller.enemy_binding.relationship.opponent_ids() == relationship_before, "lifecycle cleanup mutates only the victim local list")
	_assert_true(controller.hud.log_lines().back().contains("falls unconscious"), "HUD reports completed lifecycle")
	controller.configure_random_source(ScriptedRandomScript.new(_zeros(20)))
	var later: Array[CombatSliceOpportunityResult] = controller.process_cadence_tick()
	_assert_eq(later.size(), 2, "retained lethal attacker takes QUICK before the reciprocal relationship reaches the inactive victim")
	_assert_eq(later[0].fight_decision_result.outcome, CombatFightDecisionResult.Outcome.QUICK_ATTACK, "later opportunity takes the source QUICK decision branch")
	_assert_eq(later[0].forward_result.attack_type, CombatAttackType.Value.QUICK, "later ordinary attack execution retains QUICK type")
	_assert_eq(later[1].outcome, CombatSliceOpportunityResult.Outcome.ACTOR_NOT_ACTIVE, "unconscious victim cannot execute the reciprocal opportunity re-established by fight()")
	controller.queue_free()
	await tree.process_frame


func _test_player_threshold_waits_for_next_opportunity(tree: SceneTree) -> void:
	var controller: CombatVerticalSliceController = _instantiate_scene(tree)
	if controller == null:
		_assert_true(false, "player threshold timing scene instantiates")
		return
	var scripted: ScriptedCombatRandomSource = ScriptedRandomScript.new(
		_regular_hit_draws(1)
	)
	controller.configure_random_source(scripted)
	controller.select_enemy()
	controller.initiate_selected_combat()
	controller.opportunity_timer.stop()
	controller.player_binding.busy.start_busy(1)
	controller.player_binding.state.vitality.current = 0
	var first_tick: Array[CombatSliceOpportunityResult] = controller.process_cadence_tick()
	_assert_eq(first_tick.size(), 2, "busy player then enemy each receive one scheduled opportunity")
	_assert_eq(first_tick[0].outcome, CombatSliceOpportunityResult.Outcome.BUSY_ADVANCED, "player first opportunity only advances busy")
	_assert_true(controller.player_binding.state.vitality.current < 0, "enemy opportunity crosses player threshold")
	_assert_false(controller.lifecycle_is_pending(), "controller does not poll player threshold after enemy chain")
	var enemy_vitality_before_next_tick: int = controller.enemy_binding.state.vitality.current
	var next_tick: Array[CombatSliceOpportunityResult] = controller.process_cadence_tick()
	_assert_eq(next_tick.size(), 2, "completed player lifecycle permits the later enemy participant")
	_assert_eq(next_tick[0].outcome, CombatSliceOpportunityResult.Outcome.LIFECYCLE_REQUIRED_UNCONSCIOUS, "player threshold waits until player's next outer opportunity")
	_assert_eq(controller.enemy_binding.state.vitality.current, enemy_vitality_before_next_tick, "unconscious player performs no attack before enemy's later opportunity")
	_assert_eq(controller.player_binding.life_status, CombatSliceLifeStatus.Value.UNCONSCIOUS, "player lifecycle executes before the later enemy opportunity")
	controller.queue_free()
	await tree.process_frame


func _test_reset_reloads_fresh_encounter(tree: SceneTree) -> void:
	var packed: PackedScene = load(SCENE_PATH) as PackedScene
	_assert_true(packed != null, "reset test loads persisted PackedScene")
	if packed == null:
		return
	var change_error: Error = tree.change_scene_to_packed(packed)
	_assert_eq(change_error, OK, "arena can become the current main scene")
	await tree.process_frame
	var first: CombatVerticalSliceController = tree.current_scene as CombatVerticalSliceController
	_assert_true(first != null, "current arena initializes before reset")
	if first == null:
		return
	var old_player_state: CharacterState = first.player_binding.state
	first.select_enemy()
	first.initiate_selected_combat()
	var reset_button: Button = first.get_node(
		"HUD/HudRoot/BottomPanel/BottomBox/Actions/ResetButton"
	) as Button
	reset_button.pressed.emit()
	await tree.process_frame
	await tree.process_frame
	var reloaded: CombatVerticalSliceController = tree.current_scene as CombatVerticalSliceController
	_assert_true(reloaded != null, "Reset reloads the current arena scene")
	if reloaded == null:
		return
	_assert_true(reloaded.player_binding.state != old_player_state, "Reset constructs fresh character authorities")
	_assert_true(reloaded.opportunity_timer.is_stopped(), "Reset constructs a fresh stopped Timer")
	_assert_false(reloaded.player_binding.relationship.is_fighting(), "Reset constructs fresh combat relationships")
	_assert_false(reloaded.hud.attack_is_enabled(), "Reset clears target selection")
	_assert_eq(reloaded.enemy_body.get_signal_connection_list("selection_requested").size(), 1, "Reset does not duplicate enemy signal wiring")
	_assert_eq(reloaded.opportunity_timer.get_signal_connection_list("timeout").size(), 1, "Reset does not duplicate Timer signal wiring")


func _assert_independent_bindings(controller: CombatVerticalSliceController) -> void:
	var player: CombatSliceCharacterBinding = controller.player_binding
	var enemy: CombatSliceCharacterBinding = controller.enemy_binding
	_assert_true(player != null and player.is_valid(), "player binding initializes")
	_assert_true(enemy != null and enemy.is_valid(), "enemy binding initializes")
	_assert_true(player.state != enemy.state, "CharacterState authorities are independent")
	_assert_true(player.state.attributes != enemy.state.attributes, "attribute authorities are independent")
	_assert_true(player.state.essence != enemy.state.essence, "essence authorities are independent")
	_assert_true(player.state.vitality != enemy.state.vitality, "vitality authorities are independent")
	_assert_true(player.state.spirit != enemy.state.spirit, "spirit authorities are independent")
	_assert_true(player.state.recovery != enemy.state.recovery, "recovery authorities are independent")
	_assert_true(player.state.skills != enemy.state.skills, "skill authorities are independent")
	_assert_true(player.state.progression != enemy.state.progression, "progression authorities are independent")
	_assert_true(player.state.equipment != enemy.state.equipment, "equipment authorities are independent")
	_assert_true(player.relationship != enemy.relationship, "relationship authorities are independent")
	_assert_true(player.busy != enemy.busy, "busy authorities are independent")
	_assert_true(player.armor != enemy.armor, "armor authorities are independent")


func _assert_inventory_equipment_coherence(controller: CombatVerticalSliceController) -> void:
	_assert_true(controller.inventory_state != null, "encounter owns one narrow InventoryState")
	_assert_eq(controller.inventory_state.registered_item_ids().size(), 2, "two independent sword instances are registered")
	var player_weapon: EquippedWeaponRef = controller.player_binding.state.equipment.primary_weapon()
	var enemy_weapon: EquippedWeaponRef = controller.enemy_binding.state.equipment.primary_weapon()
	_assert_true(player_weapon.instance_id != enemy_weapon.instance_id, "sword ItemInstance identities are independent")
	_assert_eq(player_weapon.weapon_id, CombatSliceContentProfile.LONG_SWORD_ID, "player equipment uses verified long sword definition")
	_assert_eq(enemy_weapon.weapon_id, CombatSliceContentProfile.LONG_SWORD_ID, "enemy equipment uses verified long sword definition")
	_assert_eq(player_weapon.skill_type, &"sword", "long sword projects sword skill type")
	_assert_eq(controller.player_binding.content.projected_apply_damage(player_weapon), 25, "long sword projects source-backed damage 25")
	_assert_eq(controller.player_binding.content.slash_action().action_id, CombatSliceContentProfile.SLASH_ACTION_ID, "verified provider exposes slash only")
	_assert_true(
		controller.inventory_state.is_direct_child(
			player_weapon.instance_id,
			ContainmentEndpoint.new(
				ContainmentEndpoint.Kind.CHARACTER,
				controller.player_binding.character_id,
			),
		),
		"player sword is direct player inventory",
	)
	_assert_true(
		controller.inventory_state.is_direct_child(
			enemy_weapon.instance_id,
			ContainmentEndpoint.new(
				ContainmentEndpoint.Kind.CHARACTER,
				controller.enemy_binding.character_id,
			),
		),
		"enemy sword is direct enemy inventory",
	)


func _click_enemy_through_viewport(
	controller: CombatVerticalSliceController,
	tree: SceneTree,
) -> void:
	var viewport: Viewport = controller.get_viewport()
	var screen_position: Vector2 = controller.enemy_body.get_global_transform_with_canvas().origin
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = screen_position
	motion.global_position = screen_position
	viewport.push_input(motion, true)
	await tree.physics_frame
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = screen_position
	click.global_position = screen_position
	click.pressed = true
	viewport.push_input(click, true)
	await tree.physics_frame
	click.pressed = false
	viewport.push_input(click, true)
	await tree.process_frame


func _drive_to_wall(
	body: CombatSliceCharacterBody,
	action: StringName,
	start_position: Vector2,
	tree: SceneTree,
) -> void:
	body.position = start_position
	body.velocity = Vector2.ZERO
	await tree.physics_frame
	Input.action_press(action)
	for _step: int in range(360):
		body._physics_process(1.0 / 60.0)
	Input.action_release(action)
	await tree.physics_frame


func _instantiate_scene(tree: SceneTree) -> CombatVerticalSliceController:
	var packed: PackedScene = load(SCENE_PATH) as PackedScene
	if packed == null:
		return null
	var controller: CombatVerticalSliceController = packed.instantiate() as CombatVerticalSliceController
	if controller == null:
		return null
	tree.root.add_child(controller)
	return controller


func _input_action_names() -> Array[String]:
	var names: Array[String] = []
	for action: StringName in InputMap.get_actions():
		var action_name: String = String(action)
		if action_name.begins_with("move_"):
			names.append(action_name)
	names.sort()
	return names


func _assert_key_bindings(action: StringName, expected_keys: Array[int]) -> void:
	var actual_keys: Array[int] = []
	for event: InputEvent in InputMap.action_get_events(action):
		var key_event: InputEventKey = event as InputEventKey
		if key_event != null:
			actual_keys.append(key_event.keycode)
	actual_keys.sort()
	var sorted_expected: Array[int] = expected_keys.duplicate()
	sorted_expected.sort()
	_assert_eq(actual_keys, sorted_expected, "%s has exact keyboard bindings" % action)


func _top_level_tree(controller: CombatVerticalSliceController) -> Array[String]:
	var result: Array[String] = []
	for child: Node in controller.get_children():
		result.append("%s:%s" % [child.name, child.get_class()])
	return result


func _zeros(count: int) -> Array[int]:
	var values: Array[int] = []
	values.resize(count)
	values.fill(0)
	return values


func _regular_hit_draws(repetitions: int) -> Array[int]:
	var values: Array[int] = []
	for _index: int in range(repetitions):
		values.append_array([0, 0, 0, 0, 10, 10, 0, 0, 0, 0, 0])
	return values


func _resource_snapshot(state: CharacterState) -> Array[int]:
	return [
		state.essence.current,
		state.essence.effective,
		state.essence.maximum,
		state.vitality.current,
		state.vitality.effective,
		state.vitality.maximum,
		state.spirit.current,
		state.spirit.effective,
		state.spirit.maximum,
	]


func _assert_true(value: bool, message: String) -> void:
	_assertion_count += 1
	if not value:
		_failures.append("FAIL: %s" % message)


func _assert_false(value: bool, message: String) -> void:
	_assert_true(not value, message)


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	_assertion_count += 1
	if actual != expected:
		_failures.append("FAIL: %s (expected %s, got %s)" % [message, expected, actual])


func _assert_approx(actual: float, expected: float, tolerance: float, message: String) -> void:
	_assertion_count += 1
	if absf(actual - expected) > tolerance:
		_failures.append(
			"FAIL: %s (expected %s +/- %s, got %s)"
			% [message, expected, tolerance, actual]
		)
