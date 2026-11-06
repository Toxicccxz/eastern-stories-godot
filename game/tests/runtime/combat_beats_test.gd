extends RefCounted

## 战斗拍数 A (DECISIONS「战斗拍数」) on the scheduler: the knobs and their 经典 values; a round
## as a string of beats in exchange order; what a beat costs; a beat won by a school's
## skeleton, once a round; busy confiscating beats across rounds; an NPC's own beats (1vN);
## the settled first beat of an NPC's plan never changing; the two schools' lines and 柳家拳's
## lock; and the one-beat round staying ES2's.

const Fixtures := preload("res://tests/runtime/combat_encounter_scheduler_test.gd")
const Probe := preload("res://tests/support/cxr5_probe_policy.gd")
const PLAYER: StringName = Fixtures.ACTOR_ID
const ENEMY: StringName = Fixtures.TARGET_ID
const THIRD: StringName = Fixtures.THIRD_ID
const ID: StringName = Fixtures.ENCOUNTER_ID
const FONXAN: StringName = &"fonxansword"
const LIUH: StringName = &"liuh-ken"
const HEAVY_FIST: StringName = &"es2:daemon/skill/liuh-ken/huang-shan-hu-yin"
const QUICK_FIST: StringName = &"es2:daemon/skill/liuh-ken/ao-xue-dong-mei"
const FEINT_FIST: StringName = &"es2:daemon/skill/liuh-ken/gu-ya-ting-tao"
const GUARD_FIST: StringName = &"es2:daemon/skill/liuh-ken/gu-song-gua-yue"
const QUICK_SWORD: StringName = &"es2:daemon/skill/fonxansword/feng-hui-lu-zhuan"
const COUNTER: StringName = &"perform/counterattack"

var _assertions: int = 0
var _failures: Array[String] = []
var _npc_beats: Dictionary[StringName, int] = {}


func run_all(_tree: SceneTree) -> Dictionary[String, Variant]:
	var manual_before: bool = BattlePace.manual_turns
	var stance_before: int = BattlePace.stance
	_test_rules()
	_test_one_beat_is_es2()
	_test_exchange_order()
	_test_beat_costs()
	_test_busy_in_beats()
	_test_own_beats()
	_test_opening_earns_once()
	_test_fonxan_line()
	_test_liuh_line_and_lock()
	_test_settled_beat_holds()
	_test_point_one_resolve_one()
	_test_yield()
	_test_orders_cost_beats()
	BattlePace.manual_turns = manual_before
	BattlePace.stance = stance_before
	return {"assertions": _assertions, "failures": _failures.duplicate()}


static func _rules() -> CombatDecisionRules:
	return CombatDecisionRules.new(true, true, 20, 50, 2, 3, 2)


static func _modern(interleaved: bool = true, cap: int = 1, busy_in_beats: bool = true) -> CombatBeatRules:
	var costs: Dictionary[StringName, int] = {
		CombatMoveTags.QUICK: 1, CombatMoveTags.HEAVY: 2, CombatMoveTags.FEINT: 1, CombatMoveTags.GUARD: 1, CombatBeatRules.COST_PLAIN: 1,
		COUNTER: 2, &"perform/fakefault": 1, &"perform/swordjab": 2, &"perform/qa": 2,
	}
	return CombatBeatRules.new(2, costs, cap, busy_in_beats, interleaved)


func _fixture(beats: CombatBeatRules, third: bool = false, draws: Array[int] = []) -> Fixtures.SchedulerFixture:
	var f: Fixtures.SchedulerFixture = Fixtures.new()._fixture(third)
	var registry := CombatTacticalActionRegistry.new()
	registry.register_policy(Probe.new(&"perform.qa", CombatTacticalRequest.TargetRule.CURRENT_HOSTILE))
	f.scheduler.configure_decisions(_rules())
	f.scheduler.configure_player_tactics(PLAYER, registry)
	f.scheduler.configure_styles(func(_id: StringName) -> CombatStyle: return null)
	_npc_beats = {}
	f.scheduler.configure_beats(beats, func(id: StringName) -> int: return _npc_beats.get(id, 1))
	Probe.prepare(f.bindings[0].state)
	f.encounter.set_current_target(PLAYER, ENEMY)
	var padded: Array[int] = draws.duplicate()
	for _n: int in 600:
		padded.append(0)
	f.random = ScriptedCombatRandomSource.new(padded)
	BattlePace.manual_turns = true
	BattlePace.stance = CombatStance.Value.ATTACK
	return f


func _advance(f: Fixtures.SchedulerFixture, seconds: float = 1.0) -> CombatSchedulerAdvanceResult:
	return f.scheduler.advance(seconds, true, ID, f.bindings, f.random, f.effects)


## A whole round from the player's order: 战斗拍数 B stops the round on the player's next
## beat; here the rest is filled in as 自动 does (the kernel's draw, 包 A's rule), and the
## two advances' events come back as one.
func _round(f: Fixtures.SchedulerFixture, seconds: float = 1.0) -> CombatSchedulerAdvanceResult:
	var first: CombatSchedulerAdvanceResult = _advance(f, seconds)
	if first.outcome != CombatSchedulerAdvanceResult.Outcome.WAITING_FOR_PLAYER or not f.scheduler.round_running():
		return first
	BattlePace.manual_turns = false
	var rest: CombatSchedulerAdvanceResult = _advance(f, 0.0)
	BattlePace.manual_turns = true
	return CombatSchedulerAdvanceResult.new(CombatSchedulerAdvanceResult.Outcome.ADVANCED, first.cycles_processed, first.events() + rest.events())


## The actors of a round's ordinary beats, in order.
func _beat_actors(result: CombatSchedulerAdvanceResult) -> Array[StringName]:
	var actors: Array[StringName] = []
	for event: CombatSchedulerEvent in result.events():
		if event.kind == CombatSchedulerEvent.Kind.ORDINARY_OPPORTUNITY_RESOLVED:
			actors.append(event.actor_id)
	return actors


func _ordinary_of(result: CombatSchedulerAdvanceResult, actor_id: StringName) -> Array[CombatSchedulerEvent]:
	var events: Array[CombatSchedulerEvent] = []
	for event: CombatSchedulerEvent in result.events():
		if event.kind == CombatSchedulerEvent.Kind.ORDINARY_OPPORTUNITY_RESOLVED and event.actor_id == actor_id:
			events.append(event)
	return events


func _notes(result: CombatSchedulerAdvanceResult, text: String) -> int:
	var count: int = 0
	for event: CombatSchedulerEvent in result.events():
		if event.kind == CombatSchedulerEvent.Kind.NPC_CHAT and event.chat != null:
			for line: VisionLine in event.chat.lines():
				if line.template.contains(text):
					count += 1
	return count


## The first move of the player's set with `tag`.
func _move_with(f: Fixtures.SchedulerFixture, tag: StringName) -> CombatActionDefinition:
	for move: CombatActionDefinition in f.scheduler.player_moves(f.bindings):
		if move.tag == tag:
			return move
	return null


## `binding` fights with `skill_id` (封山剑法 through its sword, 柳家拳 bare-handed).
static func _learn(binding: CombatSliceCharacterBinding, skill_id: StringName, level: int = 40) -> void:
	binding.state.skills.set_raw_level(skill_id, level)
	if skill_id == LIUH:
		var primary: EquippedWeaponRef = binding.state.equipment.primary_weapon()
		if primary != null:
			binding.state.equipment.unwield(primary.instance_id)
		binding.state.skills.map_skill(&"unarmed", skill_id)
	else:
		binding.state.skills.map_skill(&"sword", skill_id)
		binding.state.skills.map_skill(&"parry", skill_id)


func _test_rules() -> void:
	var rules: CombatBeatRules = GameContent.catalog().pacing().beat_rules()
	_check(rules.round_beats == 2 and rules.earned_beat_cap == 1 and rules.busy_in_beats and rules.interleaved, "pacing.json: two beats a round, one may be won, busy in beats, exchange order")
	_check(rules.cost_of_tag(CombatMoveTags.HEAVY) == 2 and rules.cost_of_tag(CombatMoveTags.QUICK) == 1 and rules.cost_of_tag(&"") == 1 and rules.cost_of_action(COUNTER) == 2 and rules.cost_of_action(&"perform/fakefault") == 1 and rules.cost_of_action(&"perform/swordjab") == 2 and rules.cost_of_action(CombatBeatRules.COST_STANCE) == 1 and rules.cost_of_action(&"perform/unknown") == 1, "the costs: 重 2, the rest 1; 封 2, 缺 1, 逐 2; a key left out costs 1")
	var classic: CombatBeatRules = PacePresets.of(GameContent.catalog().pacing(), CharacterState.PACE_CLASSIC).beat_rules()
	_check(classic.is_classic() and classic.round_beats == 1 and classic.earned_beat_cap == 0 and not classic.busy_in_beats and not classic.interleaved and classic.cost_of_tag(CombatMoveTags.HEAVY) == 1, "经典 puts the round back at ES2's one beat")
	_check(CombatBeatRules.classic().is_classic() and not rules.is_classic() and not CombatBeatRules.new(1, {}, 0, false, true).is_classic(), "is_classic(): the record without the knobs; not with any of them set")
	_check(CombatBeatRules.perform_of(COUNTER) == &"counterattack" and CombatBeatRules.perform_of(QUICK_SWORD).is_empty() and CombatBeatRules.perform_key(&"swordjab") == &"perform/swordjab", "perform/<id> keys")
	var errors: Array[String] = []
	var bad := ContentRecordReader.new({"round_beats": 2, "beat_costs": {"heavy": 0}}, "pacing", errors)
	CombatBeatRules.from_record(bad)
	_check(not errors.is_empty(), "a cost of 0 is refused (a beat always costs one): %s" % errors)
	var skeleton: CombatSchoolSkeleton = GameContent.catalog().skill(FONXAN).skeleton
	_check(skeleton != null and skeleton.earn == CombatSchoolSkeleton.EARN_OPPONENT_MISSED and skeleton.label() == "隙" and skeleton.npc_when == CombatSchoolSkeleton.WHEN_PLAYER_LAST_HEAVY_MISSED and skeleton.npc_do == COUNTER and skeleton.npc_else_cooldown == QUICK_SWORD and not skeleton.tracks_close and skeleton.locks.is_empty(), "封山剑法's skeleton: 隙 on the enemy's miss; the line 封 on a missed 重, 峰回路转 while 封 rests")
	var fists: CombatSchoolSkeleton = GameContent.catalog().skill(LIUH).skeleton
	_check(fists != null and fists.earn == CombatSchoolSkeleton.EARN_OWN_HIT_WHILE_CLOSE and fists.label() == "压" and fists.tracks_close and fists.locks.size() == 1 and fists.locks[0].move == HEAVY_FIST and fists.npc_when == CombatSchoolSkeleton.WHEN_OWN_LAST_LANDED and fists.npc_do == HEAVY_FIST and fists.npc_else_pool == ([QUICK_FIST, FEINT_FIST] as Array[StringName]) and fists.interrupts_tag == CombatMoveTags.HEAVY and fists.interrupts_state == CombatSchoolSkeleton.STATE_CLOSE, "柳家拳's skeleton: 压 on a landed hit while close; 荒山虎吟 locked until close; the line 荒山虎吟 after a landed hit, else 傲雪冬梅 / 孤崖听涛; a close 重 breaks a charge")
	_check(GameContent.catalog().skill(&"sword").skeleton == null and GameContent.catalog().npc(&"snow.npc.girl").beats == 2 and GameContent.catalog().npc(&"snow.npc.fist_trainer").beats == 2 and GameContent.catalog().npc(&"oldpine.npc.tall_bandit").beats == 1 and GameContent.catalog().npc(&"snow.npc.dog").beats == 1, "no skeleton on a basic skill; 柳绘心 and 李火狮 have two beats, a 土匪 and a 野狗 one")


## With one beat a round (the 经典 record) the round is 战斗决策层 1B's: one beat each in
## participant order, the enemy's move drawn once with its courage, no skeleton read.
func _test_one_beat_is_es2() -> void:
	var f: Fixtures.SchedulerFixture = _fixture(CombatBeatRules.classic())
	_learn(f.bindings[0], LIUH)
	_learn(f.bindings[1], FONXAN)
	_advance(f, 1.0)
	_check(f.random.call_count() == 2 and f.scheduler.beat_plan(ENEMY) != null and f.scheduler.beat_plan(ENEMY).size() == 1 and f.scheduler.beat_plan(ENEMY).first().confirmed, "at the wait: one move and one courage draw, a plan of one settled beat")
	_check(f.scheduler.locked_moves(f.bindings).is_empty() and f.scheduler.choose_attack(HEAVY_FIST, f.bindings), "nothing locked: 荒山虎吟 may be chosen apart (ES2's moves are always available)")
	var round: CombatSchedulerAdvanceResult = _round(f)
	_check(_beat_actors(round) == ([PLAYER, ENEMY] as Array[StringName]), "one beat each, in participant order: %s" % str(_beat_actors(round)))
	_check(f.scheduler.round_beats_of(PLAYER).base == 1 and f.scheduler.round_beats_of(PLAYER).spent == ([CombatMoveTags.HEAVY] as Array[StringName]) and f.scheduler.round_beats_of(ENEMY).earned.is_empty(), "the heavy cost the one beat; the enemy (封山) won nothing of the miss")
	_check(_notes(round, "抢得一拍") == 0 and _notes(round, "变招") == 0, "no beat notes")


## Exchange order: the player's first beat, the enemy's first, then the rest by turns; or
## each one's beats together in participant order when not interleaved.
func _test_exchange_order() -> void:
	var f: Fixtures.SchedulerFixture = _fixture(_modern(true))
	_npc_beats[ENEMY] = 2
	_advance(f, 1.0)
	var plan: CombatNpcBeatPlan = f.scheduler.beat_plan(ENEMY)
	_check(plan != null and plan.size() >= 1 and plan.first().confirmed and plan.confirmed_count() == 1, "the enemy's plan: the first beat settled, the rest its read (%d beats)" % (0 if plan == null else plan.size()))
	var quick: CombatActionDefinition = _move_with(f, CombatMoveTags.QUICK)
	f.scheduler.choose_attack(quick.action_id, f.bindings)
	var round: CombatSchedulerAdvanceResult = _round(f)
	var actors: Array[StringName] = _beat_actors(round)
	_check(actors.size() >= 3 and actors[0] == PLAYER and actors[1] == ENEMY and actors[2] == PLAYER, "交手序: the player's first beat, the enemy's first, the player's second: %s" % str(actors))
	var mine: Array[CombatSchedulerEvent] = _ordinary_of(round, PLAYER)
	_check(mine.size() == 2 and mine[0].resolution.forward_result != null and mine[0].resolution.forward_result.selected_action_id == quick.action_id and not mine[0].resolution.forward_result.action_selection_result.random_attempted, "the first beat is the chosen move, no draw")
	_check(f.scheduler.round_beats_of(PLAYER).base == 2 and f.scheduler.round_beats_of(PLAYER).remaining == 0 and f.scheduler.round_beats_of(ENEMY).base == 2, "two base beats each, all spent")
	var apart: Fixtures.SchedulerFixture = _fixture(_modern(false))
	_npc_beats[ENEMY] = 2
	_advance(apart, 1.0)
	apart.scheduler.choose_attack(_move_with(apart, CombatMoveTags.QUICK).action_id, apart.bindings)
	var together: Array[StringName] = _beat_actors(_round(apart))
	_check(together == ([PLAYER, PLAYER, ENEMY, ENEMY] as Array[StringName]), "not interleaved: each one's beats together, in participant order: %s" % str(together))


## A heavy costs two beats (the round); a quick one, then a second beat drawn from the moves
## still affordable; a plain action a round costs one.
func _test_beat_costs() -> void:
	var f: Fixtures.SchedulerFixture = _fixture(_modern())
	_advance(f, 1.0)
	var heavy: CombatActionDefinition = _move_with(f, CombatMoveTags.HEAVY)
	f.scheduler.choose_attack(heavy.action_id, f.bindings)
	var round: CombatSchedulerAdvanceResult = _round(f)
	_check(_ordinary_of(round, PLAYER).size() == 1 and f.scheduler.round_beats_of(PLAYER).spent == ([CombatMoveTags.HEAVY] as Array[StringName]), "a 重 move takes both beats: one player beat")
	_check(_ordinary_of(round, ENEMY).size() == 1 and f.scheduler.round_beats_of(ENEMY).base == 1, "an NPC without `beats` has one")
	f.scheduler.choose_attack(_move_with(f, CombatMoveTags.QUICK).action_id, f.bindings)
	var second: CombatSchedulerAdvanceResult = _round(f)
	var mine: Array[CombatSchedulerEvent] = _ordinary_of(second, PLAYER)
	_check(mine.size() == 2, "a 快 move leaves a beat: two player beats")
	var drawn: CombatSingleAttackExecutionResult = null if mine.size() < 2 else mine[1].resolution.forward_result
	_check(drawn != null and drawn.action_selection_result.selected_action != null and drawn.action_selection_result.selected_action.tag != CombatMoveTags.HEAVY and not drawn.action_selection_result.random_attempted, "the second beat was drawn before the attack from the moves one beat affords (no 重): %s" % (drawn.selected_action_id if drawn != null else "-"))
	var spent: Array[StringName] = f.scheduler.round_beats_of(PLAYER).spent
	_check(spent.size() == 2 and spent[0] == CombatMoveTags.QUICK and spent[1] != CombatMoveTags.HEAVY, "spent: 快 then the drawn move's tag: %s" % str(spent))


## Busy N confiscates N beats from the nearest on, across rounds; ES2's counts once a round.
func _test_busy_in_beats() -> void:
	var f: Fixtures.SchedulerFixture = _fixture(_modern())
	_npc_beats[ENEMY] = 2
	f.bindings[1].busy.start_busy(3)
	_advance(f, 1.0)
	f.scheduler.choose_attack(_move_with(f, CombatMoveTags.QUICK).action_id, f.bindings)
	var first: Array[CombatSchedulerEvent] = _ordinary_of(_round(f), ENEMY)
	_check(first.size() == 2 and first.all(func(event: CombatSchedulerEvent) -> bool: return event.resolution.outcome == CombatSliceOpportunityResult.Outcome.BUSY_ADVANCED) and f.bindings[1].busy.busy_value == 1, "busy 3 with two beats: both beats confiscated this round, one busy left")
	_check(f.scheduler.round_beats_of(ENEMY).spent == ([CombatEncounterScheduler.SPENT_BUSY, CombatEncounterScheduler.SPENT_BUSY] as Array[StringName]), "spent on busy twice")
	f.scheduler.choose_attack(_move_with(f, CombatMoveTags.QUICK).action_id, f.bindings)
	var second: Array[CombatSchedulerEvent] = _ordinary_of(_round(f), ENEMY)
	_check(second.size() == 2 and second[0].resolution.outcome == CombatSliceOpportunityResult.Outcome.BUSY_ADVANCED and second[1].resolution.outcome != CombatSliceOpportunityResult.Outcome.BUSY_ADVANCED and not f.bindings[1].busy.is_busy(), "next round: the first beat pays the last busy, the second acts")
	var es2: Fixtures.SchedulerFixture = _fixture(_modern(true, 1, false))
	_npc_beats[ENEMY] = 2
	es2.bindings[1].busy.start_busy(2)
	_advance(es2, 1.0)
	for round: int in 2:
		es2.scheduler.choose_attack(_move_with(es2, CombatMoveTags.QUICK).action_id, es2.bindings)
		var theirs: Array[CombatSchedulerEvent] = _ordinary_of(_round(es2), ENEMY)
		_check(theirs.size() == 1 and theirs[0].resolution.outcome == CombatSliceOpportunityResult.Outcome.BUSY_ADVANCED and es2.bindings[1].busy.busy_value == 1 - round, "busy by rounds (round %d): one busy beat, the round lost whole" % round)
	_check(not es2.bindings[1].busy.is_busy(), "busy 2 wore off over two rounds, as ES2")


## 1vN: each NPC its own beats (头目 2, 小兵 1), no shared pool.
func _test_own_beats() -> void:
	var f: Fixtures.SchedulerFixture = _fixture(_modern(), true)
	_npc_beats[ENEMY] = 2
	_npc_beats[THIRD] = 1
	_advance(f, 1.0)
	f.scheduler.choose_attack(_move_with(f, CombatMoveTags.QUICK).action_id, f.bindings)
	var round: CombatSchedulerAdvanceResult = _round(f)
	_check(_ordinary_of(round, PLAYER).size() == 2 and _ordinary_of(round, ENEMY).size() == 2 and _ordinary_of(round, THIRD).size() == 1, "two beats for the player and the 头目, one for the 小兵: %s" % str(_beat_actors(round)))
	var actors: Array[StringName] = _beat_actors(round)
	_check(actors.size() == 5 and actors[0] == PLAYER and actors[1] == ENEMY and actors[2] == THIRD and actors[3] == PLAYER and actors[4] == ENEMY, "first beats first, then the second beats of those who have one: %s" % str(actors))


## 封山剑法 wins a beat when the enemy's move misses (隙), once a round whatever the misses.
func _test_opening_earns_once() -> void:
	var f: Fixtures.SchedulerFixture = _fixture(_modern())
	_learn(f.bindings[0], FONXAN)
	_npc_beats[ENEMY] = 2
	_advance(f, 1.0)
	f.scheduler.choose_attack(_move_with(f, CombatMoveTags.QUICK).action_id, f.bindings)
	var round: CombatSchedulerAdvanceResult = _round(f)
	var theirs: Array[CombatSchedulerEvent] = _ordinary_of(round, ENEMY)
	var missed: int = 0
	for event: CombatSchedulerEvent in theirs:
		var forward: CombatSingleAttackExecutionResult = event.resolution.forward_result
		if forward != null and forward.ordinary_attack_result != null and forward.ordinary_attack_result.has_base_result and forward.ordinary_attack_result.base_result.outcome != CombatAttackResult.Outcome.HIT:
			missed += 1
	_check(missed == 2, "the enemy's two moves missed on the zero draws (%d)" % missed)
	var beats: CombatRoundBeats = f.scheduler.round_beats_of(PLAYER)
	_check(beats.earned == ([CombatSchoolSkeleton.EARN_OPPONENT_MISSED] as Array[StringName]) and _ordinary_of(round, PLAYER).size() == 3, "the player won one beat (隙) and took three; the second miss won nothing (cap 1)")
	_check(_notes(round, "抢得一拍（隙）") == 1, "the log says so once")
	var actors: Array[StringName] = _beat_actors(round)
	_check(actors == ([PLAYER, ENEMY, PLAYER, ENEMY, PLAYER] as Array[StringName]), "the won beat comes after the exchange: %s" % str(actors))
	var none: Fixtures.SchedulerFixture = _fixture(_modern(true, 0))
	_learn(none.bindings[0], FONXAN)
	_advance(none, 1.0)
	none.scheduler.choose_attack(_move_with(none, CombatMoveTags.QUICK).action_id, none.bindings)
	var capped: CombatSchedulerAdvanceResult = _round(none)
	_check(_ordinary_of(capped, PLAYER).size() == 2 and _notes(capped, "抢得一拍") == 0, "earned_beat_cap 0: nothing won")


## A 封山 NPC: the player's 重 misses, so it wins a beat (隙) and, the line's `when` holding,
## its read beat turns into 「封」 (变招), run as a beat under its name; while 封 rests, the line
## goes to 峰回路转; a 小兵 of one beat cannot afford 封 (2) and plays 峰回路转 too.
func _test_fonxan_line() -> void:
	var f: Fixtures.SchedulerFixture = _fixture(_modern())
	_learn(f.bindings[1], FONXAN)
	_npc_beats[ENEMY] = 2
	_advance(f, 1.0)
	f.scheduler.choose_attack(_move_with(f, CombatMoveTags.HEAVY).action_id, f.bindings)
	var round: CombatSchedulerAdvanceResult = _round(f)
	var mine: Array[CombatSchedulerEvent] = _ordinary_of(round, PLAYER)
	_check(mine.size() == 1 and mine[0].resolution.forward_result.ordinary_attack_result.base_result.outcome != CombatAttackResult.Outcome.HIT, "the player's 重 missed")
	_check(_notes(round, "抢得一拍（隙）") == 1 and f.scheduler.round_beats_of(ENEMY).earned == ([CombatSchoolSkeleton.EARN_OPPONENT_MISSED] as Array[StringName]), "the enemy won a beat of the miss (隙)")
	var special: CombatSchedulerEvent = null
	for event: CombatSchedulerEvent in round.events():
		if event.actor_id == ENEMY and event.kind == CombatSchedulerEvent.Kind.NPC_CHAT and event.chat != null and event.chat.special_label() == "「封」字诀":
			special = event
	_check(_notes(round, "变招") == 1 and special != null, "its read beat changed on the missed 重 (变招) into 「封」, run as a beat (an NPC_CHAT event under its name)")
	_check(special != null and special.chat.lines().any(func(line: VisionLine) -> bool: return line.template.contains("「封」字诀")), "with counterattack.c's line")
	var spent: Array[StringName] = f.scheduler.round_beats_of(ENEMY).spent
	_check(spent.size() == 2 and spent[1] == COUNTER and _ordinary_of(round, ENEMY).size() == 1, "its beats: the shown move, then perform/counterattack (2, the won beat paid for it): %s" % str(spent))
	_check(not f.scheduler._can_special(f.bindings[1]), "封 rests after it (the knob's rounds)")
	var resting: CombatNpcBeatPlan = f.scheduler.beat_plan(ENEMY)
	_check(resting != null and not resting.is_empty() and resting.first().action == QUICK_SWORD and resting.first().from_line and resting.first().confirmed, "the next plan, the 重 still its target's last miss and 封 resting: 峰回路转 by the line, settled")
	_check(f.scheduler.planned_perform_label(ENEMY).is_empty() and f.scheduler.pending_special_label(ENEMY).is_empty(), "nothing to announce: a move, not a perform")
	# A fresh enemy whose 封 is ready and the 重 missed before its plan is drawn: 封 is its
	# settled first beat, shown as 要出.
	var ready: Fixtures.SchedulerFixture = _fixture(_modern())
	_learn(ready.bindings[1], FONXAN)
	_npc_beats[ENEMY] = 2
	ready.scheduler._skeleton_state(PLAYER).note_attack(&"x", CombatMoveTags.HEAVY, false, false)
	_advance(ready, 1.0)
	var plan: CombatNpcBeatPlan = ready.scheduler.beat_plan(ENEMY)
	_check(plan != null and plan.size() == 1 and plan.first().action == COUNTER and plan.first().from_line and plan.first().is_perform() and plan.first().cost == 2 and plan.first().confirmed, "封 as its settled first beat (two beats, its whole round)")
	_check(ready.scheduler.planned_perform_label(ENEMY) == "「封」字诀" and ready.scheduler.pending_special_label(ENEMY).is_empty() and ready.scheduler.next_move_tag(ENEMY, ready.bindings).is_empty() and not ready.scheduler.next_move_guards(ENEMY), "the card reads 要出「封」字诀 from the plan, not from a chat(); no tag, no 守势")
	# Busy before its turn (封 run on it last round, say): the beat pays the busy through the
	# busy gate, the planned 封 is dropped with it and stays ready (Codex on #249).
	ready.bindings[1].busy.start_busy(1)
	ready.scheduler.choose_attack(_move_with(ready, CombatMoveTags.QUICK).action_id, ready.bindings)
	var held: CombatSchedulerAdvanceResult = _round(ready)
	var theirs: Array[CombatSchedulerEvent] = _ordinary_of(held, ENEMY)
	var ran_special: bool = held.events().any(func(event: CombatSchedulerEvent) -> bool: return event.actor_id == ENEMY and event.kind == CombatSchedulerEvent.Kind.NPC_CHAT and event.chat != null and event.chat.special_label() == "「封」字诀")
	_check(not ran_special and theirs.size() >= 2 and theirs[0].resolution.outcome == CombatSliceOpportunityResult.Outcome.BUSY_ADVANCED and theirs.slice(1).all(func(event: CombatSchedulerEvent) -> bool: return event.resolution.outcome != CombatSliceOpportunityResult.Outcome.BUSY_ADVANCED), "busy 1 with 封 planned: the first beat pays the busy (no 封), the rest act: %s" % str(ready.scheduler.round_beats_of(ENEMY).spent))
	_check(not ready.bindings[1].busy.is_busy() and ready.scheduler.round_beats_of(ENEMY).spent[0] == CombatEncounterScheduler.SPENT_BUSY and ready.scheduler._can_special(ready.bindings[1]), "the busy wore off, the beat went on it, 封 did not rest")
	var small: Fixtures.SchedulerFixture = _fixture(_modern())
	_learn(small.bindings[1], FONXAN)
	small.scheduler._skeleton_state(PLAYER).note_attack(&"x", CombatMoveTags.HEAVY, false, false)
	_advance(small, 1.0)
	var poor: CombatNpcBeatPlan = small.scheduler.beat_plan(ENEMY)
	_check(poor != null and poor.size() == 1 and poor.first().action == QUICK_SWORD and poor.first().from_line, "a 小兵 of one beat cannot afford 封 (2): 峰回路转 instead")


## A 柳家拳 NPC and player: 荒山虎吟 locked until close; the line plays it once its own move
## landed, else draws from 傲雪冬梅 / 孤崖听涛; a read beat changes on the fact and says 变招.
func _test_liuh_line_and_lock() -> void:
	var f: Fixtures.SchedulerFixture = _fixture(_modern())
	_learn(f.bindings[0], LIUH)
	_learn(f.bindings[1], LIUH)
	_npc_beats[ENEMY] = 2
	_advance(f, 1.0)
	var locked: Dictionary[StringName, String] = f.scheduler.locked_moves(f.bindings)
	_check(locked.size() == 1 and locked.get(HEAVY_FIST, "") == "够不着", "the player starts apart: 荒山虎吟 locked, 够不着: %s" % str(locked))
	_check(not f.scheduler.choose_attack(HEAVY_FIST, f.bindings) and f.scheduler.waiting_for_player(f.bindings), "a locked move is refused")
	_check(f.scheduler.player_moves(f.bindings).size() == 4, "the set still lists all four (the buttons never reorder)")
	var plan: CombatNpcBeatPlan = f.scheduler.beat_plan(ENEMY)
	_check(plan != null and plan.size() == 2 and [QUICK_FIST, FEINT_FIST].has(plan.entry(0).action) and [QUICK_FIST, FEINT_FIST].has(plan.entry(1).action) and not plan.entry(0).from_line and not plan.entry(1).confirmed, "the enemy, apart and nothing landed: two beats drawn from the pool 傲雪冬梅 / 孤崖听涛, the second its read")
	# Its own move landed: close, and the line plays 荒山虎吟.
	var state: CombatSkeletonState = f.scheduler._skeleton_state(ENEMY)
	state.attacked = true
	state.last_landed = true
	state.close = true
	var read: CombatNpcBeatPlan.Entry = plan.entry(1)
	var revised: CombatNpcBeatPlan.Entry = f.scheduler._revise_entry(f.bindings[1], read, CombatRoundBeats.new(ENEMY, 2), f.random, f.bindings)
	_check(revised != read and revised.action == HEAVY_FIST and revised.from_line and revised.confirmed, "a read beat revised on the landed hit: 荒山虎吟 by the line")
	_check(f.scheduler._emitted.any(func(event: CombatSchedulerEvent) -> bool: return event.actor_id == ENEMY and event.chat != null and event.chat.lines()[0].template.contains("变招")), "and the log says 变招")
	f.scheduler._plans.erase(ENEMY)
	f.scheduler._draw_plan(f.bindings[1], f.random, f.bindings)
	var pressing: CombatNpcBeatPlan = f.scheduler.beat_plan(ENEMY)
	_check(pressing != null and pressing.first().action == HEAVY_FIST and pressing.first().from_line and pressing.first().cost == 2 and pressing.size() == 1, "drawn afresh while close after a landed hit: 荒山虎吟 (2 beats) is its round")
	# The player close too: the lock lifts.
	f.scheduler._skeleton_state(PLAYER).close = true
	_check(f.scheduler.locked_moves(f.bindings).is_empty() and f.scheduler.choose_attack(HEAVY_FIST, f.bindings), "close: 荒山虎吟 opens and may be chosen")
	var skeleton: CombatSchoolSkeleton = GameContent.catalog().skill(LIUH).skeleton
	_check(skeleton.earns_on_own_attack(true, true, false) and not skeleton.earns_on_own_attack(true, false, false) and not skeleton.earns_on_own_attack(false, true, true) and not skeleton.earns_on_opponent_attack(false), "压: a landed hit while close, and only that")
	_check(skeleton.interrupts(CombatMoveTags.HEAVY, true) and not skeleton.interrupts(CombatMoveTags.HEAVY, false) and not skeleton.interrupts(CombatMoveTags.QUICK, true), "a close 重 breaks a charge; apart or another tag does not")
	var tracker := CombatSkeletonState.new()
	_check(not tracker.note_attack(QUICK_FIST, CombatMoveTags.QUICK, true, true) and tracker.close and tracker.note_attack(FEINT_FIST, CombatMoveTags.FEINT, false, true) and not tracker.close and tracker.round_moves.size() == 2, "the state: close on a landed move, apart on a miss; 换招 on the second move")
	tracker.new_round()
	_check(tracker.round_moves.is_empty() and not tracker.close and tracker.attacked, "a new round forgets the moves, keeps the rest")


## The settled first beat of an NPC's plan never changes after it is shown, whatever the
## player does before it comes.
func _test_settled_beat_holds() -> void:
	var f: Fixtures.SchedulerFixture = _fixture(_modern())
	_learn(f.bindings[1], FONXAN)
	_npc_beats[ENEMY] = 2
	_advance(f, 1.0)
	var plan: CombatNpcBeatPlan = f.scheduler.beat_plan(ENEMY)
	var shown: StringName = plan.first().action
	_check(not plan.first().from_line and not plan.first().is_perform(), "nothing happened yet: its first beat is a drawn move, %s" % shown)
	# The player's 重 misses on the first beat: the line's `when` now holds, but the shown
	# beat is settled; only its read beat may change.
	f.scheduler.choose_attack(_move_with(f, CombatMoveTags.HEAVY).action_id, f.bindings)
	var round: CombatSchedulerAdvanceResult = _round(f)
	var theirs: Array[CombatSchedulerEvent] = _ordinary_of(round, ENEMY)
	_check(not theirs.is_empty() and theirs[0].resolution.forward_result != null and theirs[0].resolution.forward_result.selected_action_id == shown, "its first beat is the move shown, not 封")
	var next: CombatNpcBeatPlan = f.scheduler.beat_plan(ENEMY)
	_check(next != null and not next.is_empty() and next.first().from_line and next.first().confirmed and [COUNTER, QUICK_SWORD].has(next.first().action), "the round after, the line's beat (封, or 峰回路转 while 封 rests) is its settled first: %s" % (next.first().action if next != null and not next.is_empty() else &"-"))


## 战斗拍数 B: point one, resolve one. The player's order is one beat: it and the enemy's
## first beat resolve, then the round waits on the player's next beat (WAITING_FOR_PLAYER,
## the round running, the clock still); the next order goes on from there at once; a 重
## costing more than is left is 拍不够 and refused; the round closes when every beat is
## spent and the next waits afresh. 自动 fills the rest in; 经典 is one order, one round.
func _test_point_one_resolve_one() -> void:
	var f: Fixtures.SchedulerFixture = _fixture(_modern())
	_npc_beats[ENEMY] = 2
	_check(_advance(f, 1.0).outcome == CombatSchedulerAdvanceResult.Outcome.WAITING_FOR_PLAYER and not f.scheduler.round_running(), "the fight waits for the first order, no round running")
	var preview: CombatRoundBeats = f.scheduler.beats_now(PLAYER, f.bindings)
	_check(preview != null and preview.base == 2 and preview.remaining == 2 and preview.spent.is_empty(), "between rounds the beats to come: 2 of 2")
	_check(f.scheduler.unaffordable_moves(f.bindings).is_empty() and f.scheduler.unaffordable_move_reason(_move_with(f, CombatMoveTags.HEAVY).action_id, f.bindings).is_empty(), "with two beats a 重 is affordable")
	var cycle: int = f.scheduler.logical_cycle
	_check(f.scheduler.choose_attack(_move_with(f, CombatMoveTags.QUICK).action_id, f.bindings), "the first order")
	var first: CombatSchedulerAdvanceResult = _advance(f, 1.0)
	_check(first.outcome == CombatSchedulerAdvanceResult.Outcome.WAITING_FOR_PLAYER and first.cycles_processed == 1 and f.scheduler.round_running(), "the round began (one cycle) and waits mid-way: %d" % first.outcome)
	_check(_beat_actors(first) == ([PLAYER, ENEMY] as Array[StringName]), "the player's beat, then the enemy's first, then the wait: %s" % str(_beat_actors(first)))
	_check(f.scheduler.waiting_for_player(f.bindings) and f.scheduler.player_choice().is_empty(), "waiting on the player's second beat, the order spent")
	var mine: CombatRoundBeats = f.scheduler.beats_now(PLAYER, f.bindings)
	_check(mine.remaining == 1 and mine.spent == ([CombatMoveTags.QUICK] as Array[StringName]) and mine == f.scheduler.round_beats_of(PLAYER), "one beat left, the 快 spent: the round running's beats")
	_check(f.scheduler.beats_now(ENEMY, f.bindings).remaining == 1, "the enemy has its second beat still")
	var heavy: CombatActionDefinition = _move_with(f, CombatMoveTags.HEAVY)
	_check(f.scheduler.unaffordable_move_reason(heavy.action_id, f.bindings) == "拍不够" and f.scheduler.unaffordable_moves(f.bindings).has(heavy.action_id) and not f.scheduler.choose_attack(heavy.action_id, f.bindings), "a 重 (2) with one beat left: 拍不够, refused")
	_check(f.scheduler.unaffordable_action_reason(&"perform/qa", f.bindings) == "拍不够" and f.scheduler.unaffordable_action_reason(CombatBeatRules.COST_EXERT, f.bindings).is_empty() and f.scheduler.unaffordable_action_reason(&"", f.bindings).is_empty(), "an order of 2 is 拍不够 too; one of 1 is not; one of nothing never")
	var held: CombatSchedulerAdvanceResult = _advance(f, 1.0)
	_check(held.outcome == CombatSchedulerAdvanceResult.Outcome.WAITING_FOR_PLAYER and held.events().is_empty() and f.scheduler.logical_cycle == cycle + 1, "time does not move while it waits")
	var feint: CombatActionDefinition = _move_with(f, CombatMoveTags.QUICK)
	_check(feint != null and f.scheduler.choose_attack(feint.action_id, f.bindings) and not f.scheduler.waiting_for_player(f.bindings), "the second order, taken at once")
	var rest: CombatSchedulerAdvanceResult = _advance(f, 0.0)
	_check(rest.outcome == CombatSchedulerAdvanceResult.Outcome.ADVANCED and _beat_actors(rest) == ([PLAYER, ENEMY] as Array[StringName]) and not f.scheduler.round_running(), "the round goes on without the clock: the player's second beat, the enemy's second, the round done: %s" % str(_beat_actors(rest)))
	var ordered: CombatSingleAttackExecutionResult = _ordinary_of(rest, PLAYER)[0].resolution.forward_result
	_check(ordered != null and ordered.selected_action_id == feint.action_id and not ordered.action_selection_result.random_attempted, "the second beat is the move ordered, no draw")
	_check(f.scheduler.round_beats_of(PLAYER).spent == ([CombatMoveTags.QUICK, CombatMoveTags.QUICK] as Array[StringName]) and f.scheduler.round_beats_of(PLAYER).remaining == 0, "the round's beats: 快 then 快")
	_check(f.scheduler.logical_cycle == cycle + 1 and f.scheduler.waiting_for_player(f.bindings) and f.scheduler.beats_now(PLAYER, f.bindings).remaining == 2, "one cycle for the whole round; the next waits afresh with two beats")
	# A 重 as the first order spends the round in one: no mid-way wait.
	_check(f.scheduler.choose_attack(heavy.action_id, f.bindings), "a 重 ordered with two beats")
	var whole: CombatSchedulerAdvanceResult = _advance(f, 1.0)
	_check(whole.outcome == CombatSchedulerAdvanceResult.Outcome.ADVANCED and _ordinary_of(whole, PLAYER).size() == 1 and not f.scheduler.round_running(), "the 重 took both beats: the round ran through")
	# 自动 mid-way: the rest is drawn (包 A's rule), the show need not wait.
	f.scheduler.choose_attack(_move_with(f, CombatMoveTags.QUICK).action_id, f.bindings)
	_check(_advance(f, 1.0).outcome == CombatSchedulerAdvanceResult.Outcome.WAITING_FOR_PLAYER, "waits mid-way again")
	BattlePace.manual_turns = false
	var auto: CombatSchedulerAdvanceResult = _advance(f, 0.0)
	BattlePace.manual_turns = true
	_check(auto.outcome == CombatSchedulerAdvanceResult.Outcome.ADVANCED and _ordinary_of(auto, PLAYER).size() == 1 and _ordinary_of(auto, PLAYER)[0].resolution.forward_result.action_selection_result.selected_action.tag != CombatMoveTags.HEAVY and not f.scheduler.round_running(), "改为自动 mid-way: the second beat drawn from what one beat affords, the round done")
	_check(f.scheduler.waiting_for_player(f.bindings), "back on 手动 the next round waits")
	# 经典: one order, one round, never a wait mid-way.
	var es2: Fixtures.SchedulerFixture = _fixture(CombatBeatRules.classic())
	_advance(es2, 1.0)
	es2.scheduler.choose_attack(_move_with(es2, CombatMoveTags.QUICK).action_id, es2.bindings)
	var classic: CombatSchedulerAdvanceResult = _advance(es2, 1.0)
	_check(classic.outcome == CombatSchedulerAdvanceResult.Outcome.ADVANCED and not es2.scheduler.round_running() and es2.scheduler.beats_now(PLAYER, es2.bindings) == es2.scheduler.round_beats_of(PLAYER), "经典: the order's round ran whole; beats_now is the round that ran")
	_check(not es2.scheduler.yield_round(es2.bindings) and es2.scheduler.unaffordable_moves(es2.bindings).is_empty(), "经典 has no 收势 and nothing 拍不够")


## 收势: mid-way the beats left are given up (struck, not spent) and the enemies go on;
## between rounds the whole round; a beat won after it (封山's 隙) still comes to the player.
func _test_yield() -> void:
	var f: Fixtures.SchedulerFixture = _fixture(_modern())
	_npc_beats[ENEMY] = 2
	_advance(f, 1.0)
	f.scheduler.choose_attack(_move_with(f, CombatMoveTags.QUICK).action_id, f.bindings)
	_advance(f, 1.0)
	_check(f.scheduler.waiting_for_player(f.bindings) and f.scheduler.yield_round(f.bindings) and not f.scheduler.waiting_for_player(f.bindings), "收势 mid-way: no longer waiting")
	var rest: CombatSchedulerAdvanceResult = _advance(f, 0.0)
	_check(_beat_actors(rest) == ([ENEMY] as Array[StringName]) and not f.scheduler.round_running(), "the enemy's second beat alone, the round done: %s" % str(_beat_actors(rest)))
	var mine: CombatRoundBeats = f.scheduler.round_beats_of(PLAYER)
	_check(mine.spent == ([CombatMoveTags.QUICK] as Array[StringName]) and mine.yielded == 1 and mine.remaining == 0, "the 快 spent, one beat given up")
	# Between rounds: the round runs without the player's beats.
	_check(f.scheduler.waiting_for_player(f.bindings) and f.scheduler.yield_round(f.bindings), "收势 between rounds")
	_check(f.scheduler.beats_now(PLAYER, f.bindings).yielded == 2 and f.scheduler.beats_now(PLAYER, f.bindings).remaining == 0, "the preview shows the round given up")
	_check(f.scheduler.unaffordable_move_reason(_move_with(f, CombatMoveTags.QUICK).action_id, f.bindings) == "已收势", "the moves say 已收势 until the round plays")
	var passed: CombatSchedulerAdvanceResult = _advance(f, 1.0)
	_check(passed.outcome == CombatSchedulerAdvanceResult.Outcome.ADVANCED and _ordinary_of(passed, PLAYER).is_empty() and _ordinary_of(passed, ENEMY).size() == 2 and f.scheduler.round_beats_of(PLAYER).yielded == 2, "the enemy's two beats, none of the player's")
	# 封山 waits for 隙: 收势, the enemy misses, the won beat comes and waits for the order.
	var sword: Fixtures.SchedulerFixture = _fixture(_modern())
	_learn(sword.bindings[0], FONXAN)
	_npc_beats[ENEMY] = 2
	_advance(sword, 1.0)
	sword.scheduler.yield_round(sword.bindings)
	var baited: CombatSchedulerAdvanceResult = _advance(sword, 1.0)
	_check(baited.outcome == CombatSchedulerAdvanceResult.Outcome.WAITING_FOR_PLAYER and sword.scheduler.round_running() and _notes(baited, "抢得一拍（隙）") == 1, "the enemy's miss won 隙 after 收势: the won beat waits for the order")
	var won: CombatRoundBeats = sword.scheduler.beats_now(PLAYER, sword.bindings)
	_check(won.yielded == 2 and won.earned.size() == 1 and won.remaining == 1, "two given up, one won, one to spend")
	sword.scheduler.choose_attack(_move_with(sword, CombatMoveTags.QUICK).action_id, sword.bindings)
	var struck: CombatSchedulerAdvanceResult = _advance(sword, 0.0)
	_check(_ordinary_of(struck, PLAYER).size() == 1 and not sword.scheduler.round_running() and sword.scheduler.round_beats_of(PLAYER).spent == ([CombatMoveTags.QUICK] as Array[StringName]), "the won beat struck with the 快; the round done")


## An order outside the moves costs its beats: a perform queued between rounds is charged
## to the round it opens (2 here: the player's beats gone), a stance changed likewise; a
## perform mid-way comes off the round running.
func _test_orders_cost_beats() -> void:
	var f: Fixtures.SchedulerFixture = _fixture(_modern())
	_npc_beats[ENEMY] = 2
	_advance(f, 1.0)
	f.scheduler.note_stance_change(f.bindings)
	var preview: CombatRoundBeats = f.scheduler.beats_now(PLAYER, f.bindings)
	_check(preview.spent == ([CombatBeatRules.COST_STANCE] as Array[StringName]) and preview.remaining == 1, "a stance changed between rounds: one beat of the round to come")
	_check(f.scheduler.unaffordable_move_reason(_move_with(f, CombatMoveTags.HEAVY).action_id, f.bindings) == "拍不够", "so a 重 cannot be ordered")
	f.scheduler.choose_attack(_move_with(f, CombatMoveTags.QUICK).action_id, f.bindings)
	var round: CombatSchedulerAdvanceResult = _advance(f, 1.0)
	_check(round.outcome == CombatSchedulerAdvanceResult.Outcome.ADVANCED and _ordinary_of(round, PLAYER).size() == 1 and f.scheduler.round_beats_of(PLAYER).spent == ([CombatBeatRules.COST_STANCE, CombatMoveTags.QUICK] as Array[StringName]), "the round: the stance's beat, the 快, done")
	# A perform queued between rounds (perform/qa costs 2): the round opens on it and the
	# player's beats are gone; the enemy acts.
	_check(f.scheduler.player_tactics().submit(CombatTacticalRequest.new(&"qa-1", ID, PLAYER, &"perform.qa", CombatTacticalRequest.Category.MARTIAL_SPECIAL), true, ID, f.bindings).accepted(), "the perform queued")
	f.scheduler.open_round()
	var spent: CombatSchedulerAdvanceResult = _advance(f, 1.0)
	_check(spent.outcome == CombatSchedulerAdvanceResult.Outcome.ADVANCED and _ordinary_of(spent, PLAYER).is_empty() and _ordinary_of(spent, ENEMY).size() == 2, "the perform took both beats: the enemy's round alone: %s" % str(_beat_actors(spent)))
	_check(f.scheduler.round_beats_of(PLAYER).spent == ([&"perform/qa"] as Array[StringName]) and f.scheduler.round_beats_of(PLAYER).remaining == 0, "charged as perform/qa")
	# Mid-way (a fresh fight: the perform above still cools down): a 快, then a perform of 2
	# with one beat left takes the rest (no debt).
	var g: Fixtures.SchedulerFixture = _fixture(_modern())
	_npc_beats[ENEMY] = 2
	_advance(g, 1.0)
	g.scheduler.choose_attack(_move_with(g, CombatMoveTags.QUICK).action_id, g.bindings)
	_advance(g, 1.0)
	_check(g.scheduler.player_tactics().submit(CombatTacticalRequest.new(&"qa-2", ID, PLAYER, &"perform.qa", CombatTacticalRequest.Category.MARTIAL_SPECIAL), true, ID, g.bindings).accepted() and not g.scheduler.waiting_for_player(g.bindings), "queued mid-way: not waiting (the boundary runs it)")
	var after: CombatSchedulerAdvanceResult = _advance(g, 0.0)
	_check(after.outcome == CombatSchedulerAdvanceResult.Outcome.ADVANCED and _ordinary_of(after, PLAYER).is_empty() and not g.scheduler.round_running() and g.scheduler.round_beats_of(PLAYER).spent == ([CombatMoveTags.QUICK, &"perform/qa"] as Array[StringName]), "the perform ran and took the beat left; the round done: %s" % str(g.scheduler.round_beats_of(PLAYER).spent))
	_check(CombatEncounterScheduler.cost_key_of(CombatTacticalRequest.Category.INTERNAL_FORCE, &"exert.recover") == CombatBeatRules.COST_EXERT and CombatEncounterScheduler.cost_key_of(CombatTacticalRequest.Category.TACTICAL_DEFENSE, CombatSurrenderTacticalPolicy.ACTION_ID).is_empty() and CombatEncounterScheduler.cost_key_of(CombatTacticalRequest.Category.FLEE, CombatFleeTacticalPolicy.ACTION_ID) == CombatBeatRules.COST_FLEE and CombatEncounterScheduler.cost_key_of(CombatTacticalRequest.Category.MARTIAL_SPECIAL, &"perform.counterattack") == COUNTER, "the keys: exert, nothing for 投降, flee, perform/<id>")


func _check(ok: bool, label: String) -> void:
	_assertions += 1
	if not ok:
		_failures.append("combat beats: " + label)
