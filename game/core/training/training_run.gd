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
	## MAX_STEPS taken (a guard: every run ends on its own well before).
	LIMIT,
}

const MAX_STEPS: int = 999


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
	after = Snapshot.of(state, skill_id)
	kept.append_array(lines)
	if stop == Stop.NONE and steps >= MAX_STEPS:
		stop = Stop.LIMIT


## The step was refused (or conjured): its own lines say why.
func refused(lines: Array[ColoredLine]) -> void:
	refused_lines = lines
	stop = Stop.REFUSED


func end(why: Stop) -> void:
	if stop == Stop.NONE:
		stop = why


## The learn that LearnPreview.next() saw next for a student with `combat_experience`:
## Stop.NONE to take it.
func look_at_learn(preview: LearnResult, combat_experience: int) -> Stop:
	if not LearnPreview.wastes(preview):
		return Stop.NONE
	cost = preview.calculated_essence_cost
	if preview.completion == LearnResult.Completion.NO_PROGRESS_INSUFFICIENT_ESSENCE:
		have = preview.essence_before
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


## A cultivation taken: Stop.NONE to go on.
static func after_cultivation(result: CultivationResult) -> Stop:
	if result.failure_reason != CultivationResult.FailureReason.NONE:
		return Stop.REFUSED
	return Stop.MAXIMUM_UP if result.completion == CultivationResult.Completion.MAXIMUM_INCREASED else Stop.NONE
