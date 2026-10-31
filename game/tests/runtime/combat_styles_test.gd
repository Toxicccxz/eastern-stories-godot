extends RefCounted

## 战斗决策层 4 (DECISIONS「战斗内容」): the NPCs' fight styles — the records and the race
## defaults, the weighted draw of the move telegraphed a beat early (one random(sum), the
## plain random(n) when every weight is 1), the specials' rest after one ran, the courage
## draw taken with the move (「起手：守势」 when it fails the gate) and spent at the beat,
## and 柳绘心's special carrying its announced name to the result.

const Fixtures := preload("res://tests/runtime/combat_encounter_scheduler_test.gd")
const Probe := preload("res://tests/support/cxr5_probe_policy.gd")
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const GIRL: StringName = &"snow.nyard.girl.1.character"
const PLAYER: StringName = Fixtures.ACTOR_ID
const ENEMY: StringName = Fixtures.TARGET_ID
const ID: StringName = Fixtures.ENCOUNTER_ID
const RULES_ARGS: Array = [true, true, 20, 50, 2, 3, 2]

var _assertions: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	var manual_before: bool = BattlePace.manual_turns
	var stance_before: int = BattlePace.stance
	_test_records_and_defaults()
	_test_weighted_draw()
	_test_scheduler_weights_and_rest()
	_test_courage_with_the_move()
	await _test_girl_label_and_rest(tree)
	BattlePace.manual_turns = manual_before
	BattlePace.stance = stance_before
	return {"assertions": _assertions, "failures": _failures.duplicate()}


func _rules() -> CombatDecisionRules:
	return CombatDecisionRules.new(RULES_ARGS[0], RULES_ARGS[1], RULES_ARGS[2], RULES_ARGS[3], RULES_ARGS[4], RULES_ARGS[5], RULES_ARGS[6])


func _fixture(style: CombatStyle = null, draws: Array[int] = []) -> Fixtures.SchedulerFixture:
	var f: Fixtures.SchedulerFixture = Fixtures.new()._fixture(false)
	var registry := CombatTacticalActionRegistry.new()
	registry.register_policy(Probe.new(&"perform.qa", CombatTacticalRequest.TargetRule.CURRENT_HOSTILE))
	f.scheduler.configure_decisions(_rules())
	f.scheduler.configure_player_tactics(PLAYER, registry)
	f.scheduler.configure_styles(func(_id: StringName) -> CombatStyle: return style)
	Probe.prepare(f.bindings[0].state)
	f.encounter.set_current_target(PLAYER, ENEMY)
	if not draws.is_empty():
		var padded: Array[int] = draws.duplicate()
		for _n: int in 400:
			padded.append(0)
		f.random = ScriptedCombatRandomSource.new(padded)
	BattlePace.manual_turns = true
	BattlePace.stance = CombatStance.Value.ATTACK
	return f


func _advance(f: Fixtures.SchedulerFixture, seconds: float = 1.0) -> CombatSchedulerAdvanceResult:
	return f.scheduler.advance(seconds, true, ID, f.bindings, f.random, f.effects)


func _enemy_event(result: CombatSchedulerAdvanceResult) -> CombatSchedulerEvent:
	for event: CombatSchedulerEvent in result.events():
		if event.actor_id == ENEMY and event.kind == CombatSchedulerEvent.Kind.ORDINARY_OPPORTUNITY_RESOLVED:
			return event
	return null


func _test_records_and_defaults() -> void:
	var table: CombatStyleTable = GameContent.catalog().combat_styles()
	_check(not table.is_empty() and table.has(CombatStyle.STEADY) and table.has(&"burst") and table.has(&"guarded") and table.has(CombatStyle.BEAST), "combat_styles.json: 稳健 / 爆发 / 守势 / 兽: %s" % [table.ids()])
	var burst: CombatStyle = table.style(&"burst")
	_check(burst.display_name == "爆发" and burst.tag_weights == ({CombatMoveTags.HEAVY: 2} as Dictionary[StringName, int]) and burst.cooldown_rounds == 2 and burst.hurt_below == 60 and burst.hurt_cooldown_rounds == 1 and burst.specials, "爆发: 重 ×2, rests 2, 1 once below 60%")
	_check(burst.cooldown_at(100, 3) == 2 and burst.cooldown_at(59, 3) == 1 and burst.weights_at(59) == burst.tag_weights, "its rest by 气; no hurt weights: the same weights")
	var guarded: CombatStyle = table.style(&"guarded")
	_check(guarded.weights_at(80) == ({CombatMoveTags.GUARD: 2, CombatMoveTags.FEINT: 2} as Dictionary[StringName, int]) and guarded.weights_at(59) == ({CombatMoveTags.GUARD: 3, CombatMoveTags.FEINT: 2} as Dictionary[StringName, int]) and guarded.cooldown_at(10, 3) == 4, "守势: 守 ×2 虚 ×2, 守 ×3 once hurt, rests 4")
	var steady: CombatStyle = table.style(CombatStyle.STEADY)
	_check(steady.tag_weights.is_empty() and steady.cooldown_at(50, 3) == 3 and steady.weights_at(50).is_empty(), "稳健: no weights, the knob's rest")
	var beast: CombatStyle = table.style(CombatStyle.BEAST)
	_check(not beast.specials and beast.weights_at(100) == ({CombatMoveTags.QUICK: 2} as Dictionary[StringName, int]) and beast.weights_at(30) == ({CombatMoveTags.HEAVY: 3} as Dictionary[StringName, int]), "兽: no specials, 快 ×2, 重 ×3 when cornered")
	var catalog: ContentCatalog = GameContent.catalog()
	_check(table.style_of(catalog.npc(&"snow.npc.dog")) == beast and table.style_of(catalog.npc(&"oldpine.npc.bandit")) == steady, "a beast fights as 兽, a man as 稳健 by default")
	_check(catalog.npc(&"snow.npc.girl").fight_style == &"guarded" and table.style_of(catalog.npc(&"snow.npc.girl")) == guarded and table.style_of(catalog.npc(&"oldpine.npc.maniac")) == burst and table.style_of(catalog.npc(&"oldpine.npc.tall_bandit")) == burst and table.style_of(catalog.npc(&"oldpine.npc.fat_bandit")) == guarded, "柳绘心 守势, 疯老头子 and the tall bandit 爆发, the fat one 守势 (fight_style)")
	_check(table.style_of(null) == null, "no NPC, no style")
	var errors: Array[String] = []
	CombatStyle.from_record(ContentRecordReader.new({"id": "x", "name": "x", "weights": {"wild": 2}}, "s", errors))
	_check(errors.size() == 1, "an unknown tag in the weights is refused: %s" % [errors])
	errors.clear()
	var plain: CombatStyle = CombatStyle.from_record(ContentRecordReader.new({"id": "y", "name": "y", "weights": {"plain": 3, "quick": 0}, "hurt_below": 101}, "s", errors))
	_check(errors.size() == 1 and plain.tag_weights.get(CombatMoveTags.NONE, 0) == 3 and plain.tag_weights.get(CombatMoveTags.QUICK, 1) == 0, "plain weighs 平; a weight may be 0; hurt_below past 100 refused: %s" % [errors])
	var two := CombatStyleTable.new()
	var first := CombatStyle.new(&"a", "a")
	first.default_for = [&"human"]
	var second := CombatStyle.new(&"b", "b")
	second.default_for = [&"human"]
	two.add(first)
	two.add(second)
	_check(two.has(&"a") and two.has(&"b") and two._defaults[&"human"] == first, "the first default of a race holds")


func _test_weighted_draw() -> void:
	var moves := CombatActionSet.new([
		CombatActionDefinition.new(&"a", 0, 0, &"瘀伤", &"a", "$N打$n", "", &"", CombatMoveTags.QUICK, "甲"),
		CombatActionDefinition.new(&"b", 0, 0, &"瘀伤", &"b", "$N踢$n", "", &"", CombatMoveTags.HEAVY, "乙"),
		CombatActionDefinition.new(&"c", 0, 0, &"瘀伤", &"c", "$N抓$n", "", &"", CombatMoveTags.FEINT, "丙"),
		CombatActionDefinition.new(&"d", 0, 0, &"瘀伤", &"d", "$N挡$n", "", &"", CombatMoveTags.GUARD, "丁"),
	])
	var input := CombatActionSelectionInput.new(false, null, false, null, moves)
	var plain := ScriptedCombatRandomSource.new([2])
	var drawn: CombatActionSelectionResult = CombatActionSelector.select_action(input, plain, {CombatMoveTags.HEAVY: 1, CombatMoveTags.QUICK: 1} as Dictionary[StringName, int])
	_check(drawn.succeeded and drawn.selected_action.action_id == &"c" and plain.requested_bounds() == ([4] as Array[int]) and drawn.random_bound == 4, "weights all 1: random(n), the index is the move")
	var picks: Array[StringName] = []
	for draw: int in 6:
		var heavy := ScriptedCombatRandomSource.new([draw])
		var result: CombatActionSelectionResult = CombatActionSelector.select_action(input, heavy, {CombatMoveTags.HEAVY: 3} as Dictionary[StringName, int])
		picks.append(result.selected_action.action_id)
		if draw == 0:
			_check(heavy.requested_bounds() == ([6] as Array[int]) and result.random_bound == 6, "重 ×3: one random(1 + 3 + 1 + 1)")
	_check(picks == ([&"a", &"b", &"b", &"b", &"c", &"d"] as Array[StringName]), "the draw walks the weights: %s" % [picks])
	var none := ScriptedCombatRandomSource.new([1])
	var zeroed: CombatActionSelectionResult = CombatActionSelector.select_action(input, none, {CombatMoveTags.HEAVY: 0, CombatMoveTags.QUICK: 0, CombatMoveTags.FEINT: 0, CombatMoveTags.GUARD: 0} as Dictionary[StringName, int])
	_check(zeroed.succeeded and none.requested_bounds() == ([4] as Array[int]) and zeroed.selected_action.action_id == &"b", "weights that leave nothing: the plain draw")
	var chosen: CombatActionSelectionResult = CombatActionSelector.select_action(CombatActionSelectionInput.new(false, null, false, null, moves, &"d"), ScriptedCombatRandomSource.new([0]), {CombatMoveTags.HEAVY: 3} as Dictionary[StringName, int])
	_check(chosen.succeeded and chosen.selected_action.action_id == &"d" and not chosen.random_attempted, "a chosen move needs no draw, weighted or not")


func _test_scheduler_weights_and_rest() -> void:
	var style := CombatStyle.new(&"t", "t")
	style.tag_weights = {CombatMoveTags.HEAVY: 5} as Dictionary[StringName, int]
	style.cooldown_rounds = 2
	style.hurt_below = 60
	style.hurt_cooldown_rounds = 0
	var f: Fixtures.SchedulerFixture = _fixture(style)
	var set: CombatActionSet = CombatSliceProjectionBuilder.build_action_selection_input(f.bindings[1]).current_action_set()
	var sum: int = 0
	for move: CombatActionDefinition in set.actions():
		sum += 5 if move.tag == CombatMoveTags.HEAVY else 1
	_advance(f, 1.0)
	var bounds: Array[int] = f.random.requested_bounds()
	_check(bounds.size() == 2 and bounds[0] == sum and sum != set.size() and bounds[1] == 60, "at the first wait: the move drawn over the weights (%d, not %d moves), then fight()'s courage random(cps 20 × 3)" % [sum, set.size()])
	_check(not f.scheduler.next_move_tag(ENEMY, f.bindings).is_empty() and not f.scheduler.next_move_guards(ENEMY), "a draw of 0 passes the gate: it attacks")
	# The rest after a special: the knob's 3 rounds, the style's 2, none once hurt.
	var enemy: CombatSliceCharacterBinding = f.bindings[1]
	_check(f.scheduler._can_special(enemy), "no special ran: it may use one")
	f.scheduler._rest_special(enemy)
	_check(not f.scheduler._can_special(enemy) and f.scheduler._special_ready[ENEMY] == f.scheduler.logical_cycle + 3, "ran at cycle %d: the style's two rounds of rest (ready at %d)" % [f.scheduler.logical_cycle, f.scheduler._special_ready[ENEMY]])
	var moves: Array[CombatActionDefinition] = f.scheduler.player_moves(f.bindings)
	f.scheduler.choose_attack(moves[0].action_id, f.bindings)
	_advance(f, 1.0)
	_check(not f.scheduler._can_special(enemy), "one round later: still resting")
	f.scheduler.choose_attack(moves[0].action_id, f.bindings)
	_advance(f, 1.0)
	_check(not f.scheduler._can_special(enemy), "two rounds later: still resting")
	f.scheduler.choose_attack(moves[0].action_id, f.bindings)
	_advance(f, 1.0)
	_check(f.scheduler._can_special(enemy), "three rounds later: ready again")
	enemy.state.vitality = CharacterResourceState.new(100, 220, 220)
	f.scheduler._rest_special(enemy)
	_check(f.scheduler._can_special(enemy), "hurt below 60%: the style's hurt rest is 0, no rest")
	var plain: Fixtures.SchedulerFixture = _fixture(null)
	plain.scheduler._rest_special(plain.bindings[1])
	_check(plain.scheduler._special_ready[ENEMY] == plain.scheduler.logical_cycle + 4, "no style: the knob's three rounds")
	var mute := CombatStyle.new(&"m", "m")
	mute.specials = false
	var muted: Fixtures.SchedulerFixture = _fixture(mute)
	_check(not muted.scheduler._can_special(muted.bindings[1]), "a style without specials never uses one")
	var classic: Fixtures.SchedulerFixture = _fixture(style)
	classic.scheduler.configure_decisions(CombatDecisionRules.new(true, false, 20, 50, 2, 3, 2))
	_check(classic.scheduler._style_of(classic.bindings[1]) == null, "without the telegraph (经典) no style is read")


func _test_courage_with_the_move() -> void:
	# The enemy's first draws: its move (0), then a courage draw of 59 out of random(60):
	# 59 ≥ cor 20 + 0, so it will guard; the player's own courage draw (0) attacks.
	var f: Fixtures.SchedulerFixture = _fixture(null, [0, 59] as Array[int])
	_advance(f, 1.0)
	_check(f.scheduler.next_move_guards(ENEMY) and not f.scheduler.next_move_tag(ENEMY, f.bindings).is_empty(), "the courage draw failed fight()'s gate: 起手：守势 (its move still drawn)")
	var moves: Array[CombatActionDefinition] = f.scheduler.player_moves(f.bindings)
	f.scheduler.choose_attack(moves[0].action_id, f.bindings)
	var round: CombatSchedulerAdvanceResult = _advance(f, 1.0)
	var theirs: CombatRoundModifiers.Fighter = f.scheduler._modifiers.read(ENEMY)
	_check(theirs.move_tag.is_empty(), "one who guards holds no move for the ring")
	var event: CombatSchedulerEvent = _enemy_event(round)
	_check(event != null and event.resolution.outcome == CombatSliceOpportunityResult.Outcome.ENTERED_GUARDING, "at its beat it guards, as fight() does on that draw")
	var mine: CombatSchedulerEvent = null
	for candidate: CombatSchedulerEvent in round.events():
		if candidate.actor_id == PLAYER and candidate.kind == CombatSchedulerEvent.Kind.ORDINARY_OPPORTUNITY_RESOLVED:
			mine = candidate
	_check(mine != null and mine.resolution.forward_result != null and not mine.resolution.fight_decision_result.courage_random_attempted and mine.resolution.fight_decision_result.attack_type == CombatAttackType.Value.REGULAR, "the player's order carries: no courage draw on a chosen move, a REGULAR attack")
	var decision: CombatFightDecisionResult = null if event == null else event.resolution.fight_decision_result
	_check(decision != null and decision.courage_random_draw == 59 and decision.courage_random_bound == 60 and decision.random_draws().has(59), "the beat spent the draw taken with the move (59 of 60), no second draw")
	# Its next move and courage are drawn after its beat; a draw of 0 attacks next round.
	_check(not f.scheduler.next_move_guards(ENEMY), "the next courage draw (0) passes: no 守势")
	f.scheduler.choose_attack(moves[0].action_id, f.bindings)
	var next: CombatSchedulerAdvanceResult = _advance(f, 1.0)
	var attack: CombatSchedulerEvent = _enemy_event(next)
	_check(attack != null and attack.resolution.forward_result != null and attack.resolution.fight_decision_result.courage_random_draw == 0, "and it attacks, on the draw taken early")
	# A draw taken for one victim is not spent on another (the bound or the victim differ).
	var stale := CombatPredrawnCourage.new(&"someone", 60, 59, 20)
	_check(not stale.matches(ENEMY, 60) and stale.matches(&"someone", 60) and not stale.attacks() and CombatPredrawnCourage.new(ENEMY, 0, 0, 20).attacks() and CombatPredrawnCourage.new(ENEMY, 60, 19, 20).attacks(), "matches() by victim and bound; attacks() under the threshold or with no bound")


## A session: 柳绘心 (守势) announces her counterattack, runs it on her next beat under its
## announced name (the result carries it for the card), then rests four rounds.
func _test_girl_label_and_rest(tree: SceneTree) -> void:
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
	var scheduler: CombatEncounterScheduler = coordinator.active_scheduler()
	_check(scheduler._style_of(session.encounter_combat_bindings(coordinator.active_encounter())[1]) == GameContent.catalog().combat_styles().style(&"guarded"), "the coordinator gave the scheduler her style: 守势")
	var announced: String = ""
	var ran_label: String = ""
	var ran_cycle: int = -1
	var ready_at: int = -1
	var seen_after: int = 0
	for round: int in 80:
		if not coordinator.has_active_encounter():
			break
		var before: int = scheduler.events().size()
		coordinator.advance_scheduler(1.0)
		var label: String = coordinator.pending_special_label(GIRL)
		if not label.is_empty() and announced.is_empty():
			announced = label
		for event: CombatSchedulerEvent in scheduler.events().slice(before):
			if event.kind == CombatSchedulerEvent.Kind.NPC_CHAT and event.chat != null and not event.chat.special_label().is_empty() and ran_label.is_empty():
				ran_label = event.chat.special_label()
				ran_cycle = scheduler.logical_cycle
				ready_at = scheduler._special_ready.get(GIRL, 0)
				var lines: Array[BattleNarrationLine] = BattleNarrator.new().opportunity(event, BattleProjectionBuilder.build(session))
				_check(not lines.is_empty() and lines[0].is_special and lines[0].special_title == ran_label and lines[0].actor_id == GIRL, "the card's title is the announced name, whether or not the special struck: %s" % (lines[0].special_title if not lines.is_empty() else "-"))
			elif ran_cycle >= 0 and event.kind == CombatSchedulerEvent.Kind.NPC_CHAT and event.chat != null and event.chat.telegraph() != null and scheduler.logical_cycle <= ran_cycle + 4:
				seen_after += 1
	_check(not announced.is_empty() and announced.contains("「") and announced.contains("」"), "she announced her special by name: %s" % announced)
	_check(ran_label == announced, "the special ran under the announced name (not the line's first 「」): '%s' / '%s'" % [ran_label, announced])
	_check(ran_cycle >= 0 and ready_at == ran_cycle + 5 and seen_after == 0, "守势 rests four rounds after it: ready at %d (ran at %d), nothing announced meanwhile (%d)" % [ready_at, ran_cycle, seen_after])
	session.free()
	await tree.process_frame


func _check(ok: bool, label: String) -> void:
	_assertions += 1
	if not ok:
		_failures.append("combat styles: " + label)
