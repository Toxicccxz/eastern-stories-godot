extends RefCounted

## 战斗决策层 1B (DECISIONS「战斗决策」) on the scheduler: under player_turns the clock waits
## for the player's order and one order runs one round; the chosen move is the one that
## strikes, with no draw; a busy player's rounds roll; the 自动 switch rolls them all; an
## NPC's next move is drawn a beat early and shown; the stance's percents reach the
## snapshots; a perform cools down.

const Fixtures := preload("res://tests/runtime/combat_encounter_scheduler_test.gd")
const Probe := preload("res://tests/support/cxr5_probe_policy.gd")
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const GIRL: StringName = &"snow.nyard.girl.1.character"
const PLAYER: StringName = Fixtures.ACTOR_ID
const ENEMY: StringName = Fixtures.TARGET_ID
const ID: StringName = Fixtures.ENCOUNTER_ID

var _assertions: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	var manual_before: bool = BattlePace.manual_turns
	var stance_before: int = BattlePace.stance
	_test_turns_and_chosen_move()
	_test_busy_and_auto()
	_test_telegraph_and_stance()
	_test_cooldown()
	_test_classic_is_auto()
	await _test_special_telegraph(tree)
	BattlePace.manual_turns = manual_before
	BattlePace.stance = stance_before
	return {"assertions": _assertions, "failures": _failures.duplicate()}


func _fixture(rules: CombatDecisionRules = CombatDecisionRules.new(true, true, 20, 50, 2)) -> Fixtures.SchedulerFixture:
	var f: Fixtures.SchedulerFixture = Fixtures.new()._fixture(false)
	var registry := CombatTacticalActionRegistry.new()
	registry.register_policy(Probe.new(&"perform.qa", CombatTacticalRequest.TargetRule.CURRENT_HOSTILE))
	registry.register_policy(Probe.new(&"qa.flee", CombatTacticalRequest.TargetRule.NONE, CombatTacticalRequest.Category.FLEE))
	f.scheduler.configure_decisions(rules)
	f.scheduler.configure_player_tactics(PLAYER, registry)
	Probe.prepare(f.bindings[0].state)
	f.encounter.set_current_target(PLAYER, ENEMY)
	BattlePace.manual_turns = true
	BattlePace.stance = CombatStance.Value.ATTACK
	return f


func _advance(f: Fixtures.SchedulerFixture, seconds: float = 1.0) -> CombatSchedulerAdvanceResult:
	return f.scheduler.advance(seconds, true, ID, f.bindings, f.random, f.effects)


func _player_event(result: CombatSchedulerAdvanceResult) -> CombatSchedulerEvent:
	for event: CombatSchedulerEvent in result.events():
		if event.actor_id == PLAYER and event.kind == CombatSchedulerEvent.Kind.ORDINARY_OPPORTUNITY_RESOLVED:
			return event
	return null


func _test_turns_and_chosen_move() -> void:
	var f: Fixtures.SchedulerFixture = _fixture()
	_check(f.scheduler.waiting_for_player(f.bindings), "the clock waits before the first order")
	var waited: CombatSchedulerAdvanceResult = _advance(f, 5.0)
	_check(waited.outcome == CombatSchedulerAdvanceResult.Outcome.WAITING_FOR_PLAYER and waited.cycles_processed == 0 and f.scheduler.logical_cycle == 0 and f.random.call_count() == 2, "no order: no round, no time; the two draws are the enemy's first move and its courage (shown before the first order)")
	var moves: Array[CombatActionDefinition] = f.scheduler.player_moves(f.bindings)
	_check(moves.size() >= 2 and moves.all(func(move: CombatActionDefinition) -> bool: return move.tag != CombatMoveTags.NONE), "the player's moves (the sword's verbs), tagged: %d" % moves.size())
	_check(not f.scheduler.choose_attack(&"not-a-move", f.bindings) and f.scheduler.waiting_for_player(f.bindings), "a move not in the set is refused")
	var chosen: CombatActionDefinition = moves[1]
	_check(f.scheduler.choose_attack(chosen.action_id, f.bindings) and f.scheduler.player_choice() == chosen.action_id and not f.scheduler.waiting_for_player(f.bindings), "a move chosen opens the round")
	var half: CombatSchedulerAdvanceResult = _advance(f, 0.5)
	_check(half.outcome == CombatSchedulerAdvanceResult.Outcome.ADVANCED_NO_OPPORTUNITY and f.scheduler.logical_cycle == 0, "the round takes its combat_round_ms on the clock")
	var round: CombatSchedulerAdvanceResult = _advance(f, 0.5)
	_check(round.outcome == CombatSchedulerAdvanceResult.Outcome.ADVANCED and round.cycles_processed == 1 and f.scheduler.logical_cycle == 1, "one order, one round")
	var event: CombatSchedulerEvent = _player_event(round)
	_check(event != null and event.resolution.forward_result != null and event.resolution.forward_result.selected_action_id == chosen.action_id, "the chosen move struck")
	_check(event != null and event.resolution.forward_result != null and not event.resolution.forward_result.action_selection_result.random_attempted, "and drew no random(n)")
	_check(f.scheduler.waiting_for_player(f.bindings) and f.scheduler.player_choice().is_empty() and _advance(f, 3.0).outcome == CombatSchedulerAdvanceResult.Outcome.WAITING_FOR_PLAYER and f.scheduler.logical_cycle == 1, "then the clock waits again, the choice spent")
	# A frame hitch: one order is still one round.
	f.scheduler.choose_attack(chosen.action_id, f.bindings)
	var hitch: CombatSchedulerAdvanceResult = _advance(f, 7.0)
	_check(hitch.cycles_processed == 1 and f.scheduler.logical_cycle == 2 and f.scheduler.waiting_for_player(f.bindings), "seven seconds in one frame: one round, then waiting")
	# A queued order (perform, flee) is the player's turn too.
	var request := CombatTacticalRequest.new(&"flee-1", ID, PLAYER, &"qa.flee", CombatTacticalRequest.Category.FLEE)
	_check(f.scheduler.player_tactics().submit(request, true, ID, f.bindings).accepted(), "flee queued")
	_check(not f.scheduler.waiting_for_player(f.bindings), "a queued order: the round runs (the coordinator opens it)")


func _test_busy_and_auto() -> void:
	var f: Fixtures.SchedulerFixture = _fixture()
	f.bindings[0].busy.start_busy(2)
	_check(not f.scheduler.waiting_for_player(f.bindings), "a busy player has no order to give: the rounds roll")
	_check(_advance(f, 1.0).cycles_processed == 1 and f.scheduler.logical_cycle == 1, "and they do")
	_check(_advance(f, 1.0).cycles_processed == 1 and not f.bindings[0].busy.is_busy(), "busy 2 wears off over two rounds")
	_check(f.scheduler.waiting_for_player(f.bindings), "free again: the clock waits")
	BattlePace.manual_turns = false
	_check(not f.scheduler.waiting_for_player(f.bindings) and _advance(f, 3.0).cycles_processed == 3, "自动: three seconds, three rounds, as ES2")
	BattlePace.manual_turns = true
	_check(f.scheduler.waiting_for_player(f.bindings), "手动 again: waits")
	f.bindings[0].set_life_status(CombatSliceLifeStatus.Value.UNCONSCIOUS)
	_check(not f.scheduler.waiting_for_player(f.bindings), "an unconscious player gives no orders")
	f.bindings[0].set_life_status(CombatSliceLifeStatus.Value.ACTIVE)


func _test_telegraph_and_stance() -> void:
	var f: Fixtures.SchedulerFixture = _fixture()
	var moves: Array[CombatActionDefinition] = f.scheduler.player_moves(f.bindings)
	_check(f.scheduler.next_move_tag(ENEMY, f.bindings).is_empty(), "before the first wait the enemy has no move drawn")
	_advance(f, 1.0)
	var first: StringName = f.scheduler.next_move_tag(ENEMY, f.bindings)
	_check(not first.is_empty(), "at the first wait its first move is drawn, so the first order is not blind: %s" % first)
	f.scheduler.choose_attack(moves[0].action_id, f.bindings)
	_advance(f, 1.0)
	var tag: StringName = f.scheduler.next_move_tag(ENEMY, f.bindings)
	_check(not tag.is_empty(), "after its beat the enemy's next move is drawn and its tag known: %s" % tag)
	var enemy_moves: CombatActionSet = CombatSliceProjectionBuilder.build_action_selection_input(f.bindings[1]).current_action_set()
	var drawn_id: StringName = f.scheduler._next_moves.get(ENEMY, &"")
	_check(enemy_moves.actions().any(func(move: CombatActionDefinition) -> bool: return move.action_id == drawn_id), "one of its own moves")
	f.scheduler.choose_attack(moves[0].action_id, f.bindings)
	var round: CombatSchedulerAdvanceResult = _advance(f, 1.0)
	var enemy_event: CombatSchedulerEvent = null
	for event: CombatSchedulerEvent in round.events():
		if event.actor_id == ENEMY and event.kind == CombatSchedulerEvent.Kind.ORDINARY_OPPORTUNITY_RESOLVED and event.resolution.forward_result != null:
			enemy_event = event
	_check(enemy_event != null and enemy_event.resolution.forward_result.selected_action_id == drawn_id and not enemy_event.resolution.forward_result.action_selection_result.random_attempted, "next round it uses that move without a draw")
	# The stance and the tags reach the round's modifiers the snapshots are filled from.
	var mine: CombatRoundModifiers.Fighter = f.scheduler._modifiers.read(PLAYER)
	var theirs: CombatRoundModifiers.Fighter = f.scheduler._modifiers.read(ENEMY)
	_check(mine.damage_percent == 20 and mine.dodge_percent == -20 and mine.parry_percent == -20 and mine.attack_percent == 0, "攻: damage +20, dodge and parry −20 on the player's side")
	_check(theirs.move_tag == tag, "the enemy's drawn tag is what its defender snapshot carried: %s" % tag)
	BattlePace.stance = CombatStance.Value.EVADE
	f.scheduler.choose_attack(moves[0].action_id, f.bindings)
	_advance(f, 1.0)
	mine = f.scheduler._modifiers.read(PLAYER)
	_check(mine.attack_percent == -20 and mine.dodge_percent == 20 and mine.damage_percent == 0 and mine.move_tag == moves[0].tag, "游走: attack −20, dodge +20; the chosen move's tag held")


## A session: 柳绘心's perform (chat_chance_combat 25, counterattack) is announced one beat
## before it runs — 蓄势待发 on its card and in the log, the special on her next beat.
func _test_special_telegraph(tree: SceneTree) -> void:
	var session: WorldSessionController = Work.create_session(tree)
	await tree.process_frame
	session.set_process(false)
	BattlePace.manual_turns = false
	var player: WorldPlayerRuntimeState = session.player_runtime()
	player.state.vitality = CharacterResourceState.new(100000, 100000, 100000) # TEST-ONLY: outlast her
	player.state.progression.combat_experience = 100 # TEST-ONLY: her blows land and are survived
	var map: WorldMapController = MapPlaces.enter(session, &"snow.nyard", &"snow.nyard.girl.1")
	await tree.physics_frame
	map.select_npc(GIRL)
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	_check(map.attack_selected().outcome == CombatSliceInitiationResult.Outcome.COMPLETED and coordinator.has_active_encounter(), "the player attacks 柳绘心")
	var announced_at: int = -1
	var ran_at: int = -1
	var seen_label: String = ""
	for round: int in 60:
		if not coordinator.has_active_encounter():
			break
		coordinator.advance_scheduler(1.0)
		var label: String = coordinator.pending_special_label(GIRL)
		if not label.is_empty() and announced_at < 0:
			announced_at = round
			seen_label = label
			# TEST-ONLY: she is busy on her next beat: the announced special is lost.
			map.find_resident_npc(GIRL).busy.start_busy(2)
			var ui: BattlePresentationController = session.get_node("BattlePresentationLayer/BattleSurface")
			ui.refresh_projection()
			var card: BattleParticipantProjection = ui.current_projection().participant(GIRL)
			_check(card != null and card.telegraph == label, "her card shows 要出「%s」" % label)
		elif label.is_empty() and announced_at >= 0 and ran_at < 0:
			ran_at = round
	_check(announced_at >= 0, "she announced a special within 60 rounds (chat_chance_combat 25)")
	_check(ran_at == announced_at + 1, "and it ran (or was lost) on her next beat: %d → %d" % [announced_at, ran_at])
	var lines: Array[String] = []
	for event: CombatSchedulerEvent in coordinator.completed_feedback().ordinary_after(0) if not coordinator.has_active_encounter() and coordinator.completed_feedback() != null else coordinator.active_scheduler().events():
		if event.chat != null:
			for line: VisionLine in event.chat.lines():
				lines.append(line.template)
	_check(lines.any(func(line: String) -> bool: return line.contains("蓄势待发") and line.contains(seen_label)), "the log says 柳绘心蓄势待发，似乎要使出「%s」: %s" % [seen_label, lines.slice(0, 6)])
	_check(lines.any(func(line: String) -> bool: return line.contains("被打断了") and line.contains(seen_label)), "busy on her next beat: 柳绘心的%s被打断了: %s" % [seen_label, lines.slice(0, 8)])
	session.free()
	await tree.process_frame


func _test_cooldown() -> void:
	var f: Fixtures.SchedulerFixture = _fixture()
	var tactics: CombatTacticalRuntime = f.scheduler.player_tactics()
	var first := CombatTacticalRequest.new(&"perform-1", ID, PLAYER, &"perform.qa", CombatTacticalRequest.Category.MARTIAL_SPECIAL, ENEMY)
	_check(tactics.submit(first, true, ID, f.bindings).accepted(), "the perform queued")
	f.scheduler.open_round() # as the coordinator does on an accepted order
	var round: CombatSchedulerAdvanceResult = _advance(f, 1.0)
	_check(round.cycles_processed == 1 and tactics.cooldown_left(&"perform.qa") == 2, "run at the round's start: two rounds of cooldown left")
	var again := CombatTacticalRequest.new(&"perform-2", ID, PLAYER, &"perform.qa", CombatTacticalRequest.Category.MARTIAL_SPECIAL, ENEMY)
	_check(tactics.submit(again, true, ID, f.bindings).code == CombatTacticalResult.Code.COOLING_DOWN, "the same perform refused while it cools")
	var moves: Array[CombatActionDefinition] = f.scheduler.player_moves(f.bindings)
	f.scheduler.choose_attack(moves[0].action_id, f.bindings)
	_advance(f, 1.0)
	_check(tactics.cooldown_left(&"perform.qa") == 1, "a round passed: one left")
	f.scheduler.choose_attack(moves[0].action_id, f.bindings)
	_advance(f, 1.0)
	_check(tactics.cooldown_left(&"perform.qa") == 0 and tactics.submit(CombatTacticalRequest.new(&"perform-3", ID, PLAYER, &"perform.qa", CombatTacticalRequest.Category.MARTIAL_SPECIAL, ENEMY), true, ID, f.bindings).accepted(), "cooled: accepted again")


func _test_classic_is_auto() -> void:
	var f: Fixtures.SchedulerFixture = _fixture(CombatDecisionRules.classic())
	_check(not f.scheduler.waiting_for_player(f.bindings) and _advance(f, 2.0).cycles_processed == 2, "经典: no waiting, whatever the 自动 switch says")
	_check(f.scheduler.next_move_tag(ENEMY, f.bindings).is_empty(), "no telegraph")
	var tactics: CombatTacticalRuntime = f.scheduler.player_tactics()
	_check(tactics.submit(CombatTacticalRequest.new(&"p", ID, PLAYER, &"perform.qa", CombatTacticalRequest.Category.MARTIAL_SPECIAL, ENEMY), true, ID, f.bindings).accepted() and _advance(f, 1.0).cycles_processed == 1 and tactics.cooldown_left(&"perform.qa") == 0, "no cooldown")


func _check(ok: bool, label: String) -> void:
	_assertions += 1
	if not ok:
		_failures.append("combat decision: " + label)
