class_name TrainingRun
extends RefCounted

## Continuous 请教, 练习, 打坐, 冥思 and 修行 (owner, 2026-10-19; DECISIONS「连续修炼」): the
## same ES2 command again and again, each step through its own service with fresh facts,
## so nothing about a step changes. ES2's commands set no busy and take no count; this
## keeps what the run did: the steps taken, the player's state before and after, the
## lines kept from the steps (a level's, a skill_improved() effect's, a maximum's), the
## refusing command's own lines, and why it stopped.
## A step is looked at first (LearnPreview, CultivationService's preview,
## PracticeService.weak_progress_full()): one that would spend and gain nothing is not
## taken, and the run says why instead (owner, 2026-10-19). One that is refused at no
## cost is taken: its own lines say why.
## 自动歇 (成长曲线 B; pacing training_auto_rest): a stop for 精, 气 or 神 short (rest_mends())
## need not end the run: the player rests (歇到回满) and resume() takes the same run on, its count,
## its summary and its look-ahead as before; the run keeps how often and how long it rested.

enum Kind { LEARN, PRACTICE, EXERCISE, MEDITATE, RESPIRATE }

enum Stop {
	NONE,
	## The command refused (its lines say why) or came to something else than progress
	## (practice's conjured 观想虫).
	REFUSED,
	## The skill gained a level.
	LEVEL_UP,
	## 打坐 / 冥思 / 修行 raised the maximum.
	MAXIMUM_UP,
	## Looked at first: learn would spend all the gin left (gin not above the cost).
	WASTE_ESSENCE,
	## Looked at first: learn would spend gin on a level combat_exp does not reach yet.
	WASTE_EXPERIENCE,
	## Looked at first: practice in weak mode has the next level's progress already.
	PROGRESS_FULL,
	## Looked at first: the amount would gain nothing.
	NO_GAIN,
	## Looked at first: at the bottleneck, the step would take force back to the maximum.
	BOTTLENECK,
	## A fight, a fall, the menu or the teacher out of reach.
	INTERRUPTED,
	## The player stopped it.
	CANCELLED,
	## MAX_STEPS taken without a rest (a guard: every run ends on its own well before).
	LIMIT,
}

const MAX_STEPS: int = 999

## The cultivations refused for 精, 气 or 神 short (the cost, or the 70% exercise.c, meditate.c
## and respirate.c ask of the other two): a rest brings them back.
const MENDED_CULTIVATION: Array[int] = [
	CultivationResult.FailureReason.INSUFFICIENT_ESSENCE,
	CultivationResult.FailureReason.INSUFFICIENT_VITALITY,
	CultivationResult.FailureReason.INSUFFICIENT_SPIRIT,
	CultivationResult.FailureReason.ESSENCE_BELOW_HEALTH_THRESHOLD,
	CultivationResult.FailureReason.VITALITY_BELOW_HEALTH_THRESHOLD,
	CultivationResult.FailureReason.SPIRIT_BELOW_HEALTH_THRESHOLD,
]
## practice_skill()'s checks a rest mends (PracticePolicy.refusal()): kee and sen. Force, mana, the
## weapon and the water it wants are not the rest's.
const MENDED_PRACTICE: Array[StringName] = [&"kee", &"sen"]


## The player's numbers a run changes.
class Snapshot:
	extends RefCounted
	var essence: int
	var vitality: int
	var spirit: int
	var inner_force: int
	var mana: int
	var atman: int
	var potential: int
	var level: int
	var learned: int

	## Adds what changed from `then` to `now` (a rest's drift).
	func add_change(then: Snapshot, now: Snapshot) -> void:
		essence += now.essence - then.essence
		vitality += now.vitality - then.vitality
		spirit += now.spirit - then.spirit
		inner_force += now.inner_force - then.inner_force
		mana += now.mana - then.mana
		atman += now.atman - then.atman
		potential += now.potential - then.potential
		level += now.level - then.level
		learned += now.learned - then.learned

	static func of(state: CharacterState, skill_id: StringName) -> Snapshot:
		var snapshot := Snapshot.new()
		snapshot.essence = state.essence.current
		snapshot.vitality = state.vitality.current
		snapshot.spirit = state.spirit.current
		snapshot.inner_force = state.recovery.inner_force.current
		snapshot.mana = state.recovery.mana.current
		snapshot.atman = state.recovery.atman.current
		snapshot.potential = state.progression.potential - state.progression.potential_spent
		snapshot.level = state.skills.raw_level(skill_id) if not skill_id.is_empty() else 0
		snapshot.learned = state.skills.learned_progress(skill_id) if not skill_id.is_empty() else 0
		return snapshot


var kind: Kind
## The skill a step improves: learn's, practice's special skill; &"" for cultivation.
var skill_id: StringName
var steps: int = 0
var stop: Stop = Stop.NONE
var before: Snapshot
var after: Snapshot
## improve_skill()'s and skill_improved()'s lines, the maximum's, in order.
var kept: Array[ColoredLine] = []
## The refusing command's own lines (Stop.REFUSED).
var refused_lines: Array[ColoredLine] = []
## What the look ahead saw: learn's gin cost, the gin left, the combat_exp it needs.
var cost: int = 0
var have: int = 0
var required: int = 0
## Native (前两小时 A; DECISIONS「新手链与当前目标」): a cultivation run goes on past a raised
## maximum until the maximum reaches this (练到 N 再停); 0 stops at the first raise, as before.
var target_maximum: int = 0
## The stop (WASTE_ESSENCE, or a REFUSED step's) is for 精, 气 or 神 short: a rest mends it.
var mendable: bool = false
## 自动歇 is on for this run (the stop lines leave out the 歇到回满 hint).
var auto_rest: bool = false
## 自动歇: the rests taken during the run, the world seconds and game minutes they lasted.
var rests: int = 0
var rest_world_seconds: float = 0.0
var rest_minutes: int = 0
## Said after the stop: the line of a rest that ended the run (有人来袭 …), or why none could
## begin (no water …); "" when none.
var rest_line: String = ""
## What the rests changed (精, 气, 神 back; 内力, 法力, 灵力 back by heal_up()), not the steps: the
## summary tells the steps' own change.
var drift: Snapshot = Snapshot.new()
## Steps since the run began or last rested (what MAX_STEPS counts).
var _stretch: int = 0


func _init(p_kind: Kind, p_skill_id: StringName, state: CharacterState) -> void:
	kind = p_kind
	skill_id = p_skill_id
	before = Snapshot.of(state, skill_id)
	after = before


func stopped() -> bool:
	return stop != Stop.NONE


## A step was taken (and paid for).
func took_step(state: CharacterState, lines: Array[ColoredLine] = []) -> void:
	steps += 1
	_stretch += 1
	after = Snapshot.of(state, skill_id)
	kept.append_array(lines)
	if stop == Stop.NONE and _stretch >= MAX_STEPS:
		stop = Stop.LIMIT


## The step was refused (or conjured): its own lines say why; `for_rest` when it was for 精, 气
## or 神 short (rest_mends_cultivation(), rest_mends_practice()).
func refused(lines: Array[ColoredLine], for_rest: bool = false) -> void:
	refused_lines = lines
	mendable = for_rest
	stop = Stop.REFUSED


func end(why: Stop) -> void:
	if stop == Stop.NONE:
		stop = why


## The run stopped for 精, 气 or 神 short: a rest would let it go on.
func rest_mends() -> bool:
	return mendable and stop in [Stop.WASTE_ESSENCE, Stop.REFUSED]


## A rest of `world_seconds` (`minutes` game minutes) was taken during the run.
func rested(world_seconds: float, minutes: int) -> void:
	rests += 1
	rest_world_seconds += maxf(world_seconds, 0.0)
	rest_minutes += maxi(minutes, 0)


## After a rest that mended the stop: the same run goes on, as if it had not stopped (`state`:
## the player now, the numbers the look-ahead and the progress read). What the rest changed
## goes to `drift`.
func resume(state: CharacterState) -> void:
	stop = Stop.NONE
	mendable = false
	refused_lines = []
	cost = 0
	have = 0
	required = 0
	_stretch = 0
	var now: Snapshot = Snapshot.of(state, skill_id)
	drift.add_change(after, now)
	after = now


## 自动歇 holds back while 朱鸿雪's task runs against its time (god.c's task_time): a rest would
## spend it unasked. The player rests by hand (歇到回满) if they choose.
static func rest_held_back(state: CharacterState) -> bool:
	return state.quest.has_task() and not state.quest.is_expired()


## A cultivation refused for 精, 气 or 神 short.
static func rest_mends_cultivation(result: CultivationResult) -> bool:
	return result != null and MENDED_CULTIVATION.has(result.failure_reason)


## A practice refused for kee or sen short.
static func rest_mends_practice(result: PracticeResult) -> bool:
	return result != null and result.failure_reason == PracticeResult.FailureReason.PRACTICE_HOOK_REJECTED and MENDED_PRACTICE.has(result.refusal)


## The learn that LearnPreview.next() saw next for a student with `combat_experience`:
## Stop.NONE to take it.
func look_at_learn(preview: LearnResult, combat_experience: int) -> Stop:
	if not LearnPreview.wastes(preview):
		return Stop.NONE
	cost = preview.calculated_essence_cost
	if preview.completion == LearnResult.Completion.NO_PROGRESS_INSUFFICIENT_ESSENCE:
		have = preview.essence_before
		mendable = true
		return Stop.WASTE_ESSENCE
	required = preview.required_combat_experience
	have = combat_experience
	return Stop.WASTE_EXPERIENCE


## A learn taken: Stop.NONE to go on.
static func after_learn(result: LearnResult) -> Stop:
	if result.failure_reason != LearnResult.FailureReason.NONE:
		return Stop.REFUSED
	match result.completion:
		LearnResult.Completion.LEVEL_INCREASED:
			return Stop.LEVEL_UP
		LearnResult.Completion.PROGRESSED:
			return Stop.NONE
	# NO_PROGRESS_*: the look ahead's to keep away; its lines say what happened.
	return Stop.REFUSED


## A practice taken: Stop.NONE to go on.
static func after_practice(result: PracticeResult) -> Stop:
	if result.failure_reason != PracticeResult.FailureReason.NONE:
		return Stop.REFUSED
	return Stop.LEVEL_UP if result.completion == PracticeResult.Completion.LEVEL_INCREASED else Stop.NONE


## The cultivation CultivationService's preview saw next: Stop.NONE to take it (a
## refusal is taken: it costs nothing and says why).
func look_at_cultivation(preview: CultivationResult) -> Stop:
	if preview.failure_reason != CultivationResult.FailureReason.NONE:
		return Stop.NONE
	if preview.completion == CultivationResult.Completion.NO_GAIN:
		return Stop.NO_GAIN
	if preview.completion == CultivationResult.Completion.SKILL_CAP_REACHED and preview.internal_after <= preview.internal_before:
		have = preview.maximum_before
		return Stop.BOTTLENECK
	return Stop.NONE


## A cultivation taken: Stop.NONE to go on. A raised maximum stops the run, unless it
## is still short of `target_maximum` (`maximum_after`: the maximum now).
static func after_cultivation(result: CultivationResult, target_maximum: int = 0, maximum_after: int = 0) -> Stop:
	if result.failure_reason != CultivationResult.FailureReason.NONE:
		return Stop.REFUSED
	if result.completion != CultivationResult.Completion.MAXIMUM_INCREASED:
		return Stop.NONE
	return Stop.NONE if target_maximum > 0 and maximum_after < target_maximum else Stop.MAXIMUM_UP
