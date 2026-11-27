extends RefCounted

## 师娘彩蛋 A (DECISIONS「师娘彩蛋 A」): 封山剑法's 「听雨」 (perform rainpress) — only for one taught,
## one move and some force for one thrust the enemy has to answer; dodged or parried, it leaves
## them open (露空, by the skill's open_percent) and wins its performer a hand this round as a 隙
## does (within the round's one), landed it is only the blow. Data first, then real fights through the scheduler.
## TEST-ONLY fixtures, each marked where used: the fighters' skills, marks and force, the
## scripted draws.
const Fixtures := preload("res://tests/runtime/combat_encounter_scheduler_test.gd")
const Beats := preload("res://tests/runtime/combat_beats_test.gd")
const PLAYER: StringName = Fixtures.ACTOR_ID
const ENEMY: StringName = Fixtures.TARGET_ID
const ID: StringName = Fixtures.ENCOUNTER_ID
const RAIN: StringName = &"rainpress"
const ACTION: StringName = &"perform.rainpress"
const KEY: StringName = &"perform/rainpress"
const MARK: String = "学了听雨"

## The fixture's fight is a SCRIPTED one (TEST-ONLY): the perform's own policy, taking it.
class AnyMode:
	extends CombatPerformTacticalPolicy

	func supports_mode(_mode: int) -> bool:
		return true


var _count: int = 0
var _failures: Array[String] = []
var _npc_beats: Dictionary[StringName, int] = {}
var _requests: int = 0


func run_all(_tree: SceneTree) -> Dictionary[String, Variant]:
	var pace_turns: bool = BattlePace.manual_turns
	var pace_stance: CombatStance.Value = BattlePace.stance
	_test_data()
	_test_forced_wins_a_hand()
	_test_landed_is_only_the_blow()
	_test_cap_and_refusals()
	BattlePace.manual_turns = pace_turns
	BattlePace.stance = pace_stance
	return {"assertions": _count, "failures": _failures.duplicate()}


func _test_data() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var sword: SkillDefinition = catalog.skill(Beats.FONXAN)
	_check(sword.perform_functions.has(RAIN) and sword.perform_when.has(RAIN) and sword.perform_number(RAIN, "force") == 20 and sword.perform_number(RAIN, "damage") == 6 and sword.perform_number(RAIN, "damage_percent") == 12 and sword.perform_number(RAIN, "open_percent") == 85, "封山剑法 lists 「听雨」, with a condition and its numbers")
	_check(SpecialFunctions.perform(RAIN).label == "「听雨」" and catalog.pacing().beat_rules().cost_of_action(KEY) == 1, "「听雨」 costs one move")
	var state := CharacterState.new()
	state.skills.set_raw_level(&"sword", 40) # TEST-ONLY
	state.skills.set_raw_level(Beats.FONXAN, 40) # TEST-ONLY
	state.skills.map_skill(&"sword", Beats.FONXAN)
	_check(not sword.performs(RAIN, state), "untaught: not theirs")
	state.marks[MARK] = 1 # TEST-ONLY
	_check(sword.performs(RAIN, state), "taught: theirs")
	_check(BattleActionPresentationCatalog.new().tooltip_for(ACTION).contains("用 20 点内力"), "its button says what it costs")


## Dodged or parried: the enemy stands open, and a hand is won within the round (隙).
func _test_forced_wins_a_hand() -> void:
	var f: Fixtures.SchedulerFixture = _fixture(_zeros())
	_npc_beats[ENEMY] = 2
	_advance(f)
	var kee_before: int = f.bindings[1].state.vitality.current
	_check(_order(f), "taught, with a sword: the order is taken")
	f.scheduler.open_round()
	var round: CombatSchedulerAdvanceResult = _advance(f)
	var mine: CombatRoundBeats = f.scheduler.round_beats_of(PLAYER)
	_check(f.bindings[1].state.vitality.current == kee_before, "the scripted draws: the thrust did not land")
	_check(mine.spent.has(KEY) and mine.earned == ([CombatSchoolSkeleton.EARN_OPPONENT_MISSED] as Array[StringName]), "one move paid, one won: spent %s earned %s" % [mine.spent, mine.earned])
	_check(_notes(round, "抢得一手") == 1, "the log says so, once")
	_check(f.scheduler.exposed(ENEMY) and f.scheduler.waiting_for_player(f.bindings), "the enemy stands open while the round waits on the next move of the player: exposed %s" % f.scheduler.exposed(ENEMY))
	_check(f.bindings[0].state.recovery.inner_force.current == 80, "20 force spent (%d)" % f.bindings[0].state.recovery.inner_force.current)
	_check(not f.scheduler.exposed(PLAYER), "and its striker does not stand open (露空 is a 重's)")


## Landed: the blow, and no hand.
func _test_landed_is_only_the_blow() -> void:
	var f: Fixtures.SchedulerFixture = _fixture(Beats.TopRandom.new())
	_npc_beats[ENEMY] = 2
	_advance(f)
	var kee_before: int = f.bindings[1].state.vitality.current
	_check(_order(f), "ordered")
	f.scheduler.open_round()
	var round: CombatSchedulerAdvanceResult = _advance(f)
	var mine: CombatRoundBeats = f.scheduler.round_beats_of(PLAYER)
	_check(f.bindings[1].state.vitality.current < kee_before, "the top draws: the thrust landed")
	_check(mine.spent.has(KEY) and mine.earned.is_empty() and _notes(round, "抢得一手") == 0 and not f.scheduler.exposed(ENEMY), "one move paid, none won, nobody open: spent %s earned %s" % [mine.spent, mine.earned])


## One hand a round, however it was won; untaught or short of force: refused, nothing spent.
func _test_cap_and_refusals() -> void:
	var capped: Fixtures.SchedulerFixture = _fixture(_zeros(), 0)
	_npc_beats[ENEMY] = 2
	_advance(capped)
	_order(capped)
	capped.scheduler.open_round()
	var none: CombatSchedulerAdvanceResult = _advance(capped)
	_check(capped.scheduler.round_beats_of(PLAYER).spent.has(KEY) and capped.scheduler.round_beats_of(PLAYER).earned.is_empty() and _notes(none, "抢得一手") == 0, "earned_beat_cap 0: forced, and no hand")
	var short: Fixtures.SchedulerFixture = _fixture(_zeros())
	_npc_beats[ENEMY] = 2
	short.bindings[0].state.recovery.inner_force.current = 19 # TEST-ONLY
	_advance(short)
	_order(short)
	short.scheduler.open_round()
	_advance(short)
	_check(short.bindings[0].state.recovery.inner_force.current == 19 and not short.scheduler.round_beats_of(PLAYER).spent.has(KEY), "short of force: refused, no force and no move spent")
	var untaught: Fixtures.SchedulerFixture = _fixture(_zeros())
	_npc_beats[ENEMY] = 2
	untaught.bindings[0].state.marks.erase(MARK)
	_advance(untaught)
	_order(untaught)
	untaught.scheduler.open_round()
	_advance(untaught)
	_check(untaught.bindings[0].state.recovery.inner_force.current == 100 and not untaught.scheduler.round_beats_of(PLAYER).spent.has(KEY), "untaught: refused, nothing spent")


## 封山's sword in the player's hand, taught 「听雨」, 100 force; the enemy two moves a round.
func _fixture(random: CombatRandomSource, cap: int = 1) -> Fixtures.SchedulerFixture:
	var f: Fixtures.SchedulerFixture = Fixtures.new()._fixture(false)
	var registry := CombatTacticalActionRegistry.new()
	registry.register_policy(AnyMode.new(RAIN))
	f.scheduler.configure_decisions(Beats._rules())
	f.scheduler.configure_player_tactics(PLAYER, registry)
	f.scheduler.configure_styles(func(_id: StringName) -> CombatStyle: return null)
	_npc_beats = {}
	var costs: Dictionary[StringName, int] = {
		CombatMoveTags.QUICK: 1, CombatMoveTags.HEAVY: 2, CombatMoveTags.FEINT: 1, CombatMoveTags.GUARD: 1, CombatBeatRules.COST_PLAIN: 1, KEY: 1,
	}
	f.scheduler.configure_beats(CombatBeatRules.new(2, costs, cap, true, true), func(id: StringName) -> int: return _npc_beats.get(id, 1))
	Beats._learn(f.bindings[0], Beats.FONXAN) # TEST-ONLY
	f.bindings[0].state.marks[MARK] = 1 # TEST-ONLY
	f.bindings[0].state.recovery.inner_force = CharacterInternalResourceState.new(100, 100) # TEST-ONLY
	f.encounter.set_current_target(PLAYER, ENEMY)
	f.random = random
	BattlePace.manual_turns = true
	BattlePace.stance = CombatStance.Value.ATTACK
	return f


## Every draw 0 (TEST-ONLY): the attack's gates fail, the blow is dodged or parried.
static func _zeros() -> ScriptedCombatRandomSource:
	var draws: Array[int] = []
	for _n: int in 600:
		draws.append(0)
	return ScriptedCombatRandomSource.new(draws)


func _advance(f: Fixtures.SchedulerFixture, seconds: float = 1.0) -> CombatSchedulerAdvanceResult:
	return f.scheduler.advance(seconds, true, ID, f.bindings, f.random, f.effects)


func _order(f: Fixtures.SchedulerFixture) -> bool:
	_requests += 1
	return f.scheduler.player_tactics().submit(CombatTacticalRequest.new(StringName("rain-%d" % _requests), ID, PLAYER, ACTION, CombatTacticalRequest.Category.MARTIAL_SPECIAL), true, ID, f.bindings).accepted()


func _notes(result: CombatSchedulerAdvanceResult, text: String) -> int:
	var count: int = 0
	for event: CombatSchedulerEvent in result.events():
		if event.kind == CombatSchedulerEvent.Kind.NPC_CHAT and event.chat != null:
			for line: VisionLine in event.chat.lines():
				if line.template.contains(text):
					count += 1
	return count


func _check(ok: bool, label: String) -> void:
	_count += 1
	if not ok:
		_failures.append("rainpress: " + label)
