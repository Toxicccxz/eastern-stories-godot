class_name GrowthCurveSim
extends ExpPacingSim

## Native (成长曲线计划, 2026-11-19): what a player who follows the main story makes of what it
## pays, chapter by chapter, and what keeping up costs in real time. Its consumers are the knobs
## the plan proposes (common/progression.json's 历练, pacing.json's rest and death knobs, the
## regions' recommended_exp) and the must-win fights tuned against tests/support/
## grown_character.gd: this sim grows the character the way a player would, so the two can be
## compared. Report: tests/sim/run_growth_curve_sim.gd.
## - 历练: the game's own MilestoneRewards along tests/support/story_arrival.gd's ROUTE (the same
##   rewards the must-win fights' character is grown from), with the 落后补偿 of each region; `extra`
##   adds a share of the stage unit after a chapter's own (a faction line's, a boss's),
##   `quest_percents` sets main-story quests' percents, `recommended` overrides regions'
##   recommended_exp (what-ifs for the plan, put back afterwards).
## - 请教: a long sword in hand (封山剑法 is learnt only with a sword wielded: its learn policy), the
##   potential is spent at 柳淳风 (the first sword master) through the real TeacherService,
##   one lesson to each of the sword build's seven skills in turn (grown_character.gd's spread): his
##   own levels cap each skill and learn.c's exp gate holds. `self_learn`: 基本内功 past his level by
##   自学 (one click each; selflearn.c).
## - 打坐: through PlayerMartialArts (pacing's player_exercise_gain) to `force_percent` of exercise.c's
##   bottleneck, 30 气 a time as the 武学 page's default.
## - Time: as TrainingRun runs it (a step holds world time: its 150 ms are counted in the report).
##   A 请教 run stops before a step that would waste 精 and at each level gained; an 打坐 run when
##   气 or the 70% of 精 / 神 it needs runs short. At each stop the player
##   rests (歇到回满, RestRules: until 精, 气 and 神 are full; another press after each
##   rest_limit_seconds) and presses again. Every wait is the real recovery's world seconds; the
##   report turns them into real time with the rest (pacing rest_world_scale times faster) and
##   without it (standing, as before 歇到回满). Seeded; nothing here is read by the game.
## - `auto` (成长曲线 B, pacing training_auto_rest): the runs rest by themselves. The same lessons,
##   sittings and rests; a 请教 run stops only at a level gained and an 打坐 run (to the target) is
##   one press a chapter, each step feel's training_auto_step_ms apart, every rest at pacing's
##   rest_world_scale with no press (a rest at its longest goes on by itself).

const Arrival := preload("res://tests/support/story_arrival.gd")
const Finance := preload("res://tests/runtime/snow_finance_test.gd")

## 柳淳风 in 淳风武馆's hall.
const MASTER: StringName = &"snow.school_compound.schoolhall.master"
## The sword build's seven skills (grown_character.gd's SWORD_PAIRS, chaos-steps on dodge).
const SKILLS: Array[StringName] = [&"sword", &"fonxansword", &"parry", &"dodge", &"chaos-steps", &"force", &"fonxanforce"]
## The specials enabled on their uses once learnt (grown_character.gd's SWORD_PAIRS).
const ENABLES: Dictionary[StringName, StringName] = {&"sword": &"fonxansword", &"parry": &"fonxansword", &"dodge": &"chaos-steps", &"force": &"fonxanforce"}
## What 自学 takes past the teacher (selflearn.c: basic skills from raw 40).
const SELF_SKILLS: Array[StringName] = [&"force"]
const EXERCISE_KEE: int = 30
## Real seconds the player spends at each stop of a run: pressing 歇到回满, then the run again when
## the rest ends (an estimate: two presses with the focus already on the button).
const STOP_SECONDS: float = 2.0
## Real seconds of one 自学 click (it has no continuous run; an estimate).
const CLICK_SECONDS: float = 1.0
## A single rest longer than this many world seconds means something is wrong.
const REST_GUARD_SECONDS: float = 6.0 * 3600.0

## Real seconds of one continuous step (pacing feel training_step_ms).
var step_seconds: float = 0.15
## How fast the world runs while resting (pacing rest_world_scale; 0: no rest offered).
var rest_scale: float = 20.0
## The report's rest scale instead of pacing's (a what-if), when not negative.
var rest_scale_override: float = -1.0
## World seconds a rest runs before it ends and the player must press again (rest_limit_seconds).
var rest_limit: float = 600.0
## Percent of exercise.c's bottleneck 打坐 goes to after each chapter (grown_character.gd: 50).
var force_percent: int = 100
var self_learn: bool = false
## Quest id -> its percent of the stage unit (progression.json quest_percent), for this run.
var quest_percents: Dictionary[StringName, int] = {}
## Chapter (main-story quest id) -> the percents of the stage unit paid after its own rewards.
var extra: Dictionary[StringName, Array] = {}
## Region id -> recommended_exp for this run.
var recommended: Dictionary[StringName, int] = {}
## Whether the potential is spent and 打坐 done between chapters (false: the exp path only).
var train_between: bool = true
## The runs rest by themselves (自动歇): see above.
var auto: bool = false

## Cumulative counts and world seconds.
var lessons: int = 0
var learn_stops: int = 0
## Of learn_stops: the levels gained (a 请教 run stops there with 自动歇 as well).
var level_stops: int = 0
## 打坐 runs pressed (one a chapter that takes a step: the 武学 page's 练到 N).
var exercise_runs: int = 0
## Rests taken (each a stop without 自动歇).
var rests: int = 0
var learn_rest: float = 0.0
var exercises: int = 0
var exercise_stops: int = 0
var exercise_rest: float = 0.0
var self_clicks: int = 0
var self_stops: int = 0
var self_rest: float = 0.0
var potential_earned: int = 0
var potential_cut: int = 0
## One row on arriving at each chapter (before its own rewards), and one at the end.
var rows: Array[Row] = []

var _restore_rules: Dictionary[StringName, int] = {}
var _restore_regions: Dictionary[StringName, int] = {}
var _extra_count: int = 0


class Row:
	extends RefCounted
	var label: String = ""
	var experience: int = 0
	var potential_earned: int = 0
	var potential_cut: int = 0
	var unspent: int = 0
	var levels: Dictionary[StringName, int] = {}
	var max_force: int = 0
	var force_cap: int = 0
	var kee: int = 0
	var gin: int = 0
	var sen: int = 0
	var lessons: int = 0
	var learn_stops: int = 0
	var level_stops: int = 0
	var exercise_runs: int = 0
	var rests: int = 0
	var learn_rest: float = 0.0
	var exercises: int = 0
	var exercise_stops: int = 0
	var exercise_rest: float = 0.0
	var self_clicks: int = 0
	var self_stops: int = 0
	var self_rest: float = 0.0


## The journey from `start_exp` (where the first two hours leave the player: StoryArrival's
## MAIN_START or EXPLORING_START, with half of it as potential, as 历练 pays): train, then each
## chapter's rewards and training in turn.
func journey(start_exp: int) -> void:
	_apply_overrides()
	var rules: ProgressionRules = GameContent.catalog().progression()
	var progression: CharacterProgressionState = state().progression
	var pacing: PacingDefinition = GameContent.catalog().pacing()
	rest_scale = rest_scale_override if rest_scale_override >= 0.0 else float(pacing.rest_world_scale)
	rest_limit = float(pacing.rest_limit_seconds)
	# pacing.json's feel (a cold process turns it off for the session: TestFeel.production keeps it).
	var feel: FeelDefinition = TestFeel.production
	var shipped_step: float = feel.training_auto_step_seconds if auto else feel.training_step_seconds
	if shipped_step > 0.0:
		step_seconds = shipped_step
	progression.combat_experience = start_exp
	_wield(&"es2:obj/longsword")
	@warning_ignore("integer_division")
	var first: int = start_exp * rules.potential_percent / 100
	potential_earned += ProgressionGain.add_potential(progression, first, ProgressionGain.potential_cap(rules, start_exp, pacing.staged_potential_cap))
	potential_cut += first - potential_earned
	if train_between:
		await train()
	for chapter: Array in Arrival.ROUTE:
		rows.append(_row(String(chapter[0])))
		print("growth sim: %s exp %d, %d lessons, %d 打坐 so far" % [chapter[0], rows.back().experience, lessons, exercises])
		for reward: Array in chapter[1]:
			_award(Arrival.KINDS[reward[0]], StringName(reward[1]), chapter[0] if reward[0] == &"quest" else &"")
		for percent: int in extra.get(chapter[0], []):
			_extra(percent, StringName(chapter[1].back()[1]))
		if train_between:
			await train()
	rows.append(_row("end"))
	_restore_overrides()


## TEST-ONLY: `definition_id` in the player's hand (MainlineFightSim's way).
func _wield(definition_id: StringName) -> void:
	var context: MoneyInventoryContext = Finance.session_context(session)
	var item := ItemInstance.new(&"sim:weapon", definition_id)
	context.inventory.register_item(item, GameContent.catalog().item(definition_id).own_weight)
	context.index.register_snapshot(item)
	context.inventory._apply_reparent(item.item_instance_id, context.endpoint())
	OldPineEquipmentInteractionAdapter.new().wield(session.player_runtime(), item.item_instance_id, session._inventory, session._item_index)


## Spends the potential at 柳淳风, 自学 when asked, then 打坐 to `force_percent` of the bottleneck.
func train() -> void:
	var teacher: TeacherService = await _teacher(MASTER)
	if teacher == null:
		return
	await _learn_all(teacher)
	for use_id: StringName in ENABLES:
		if state().skills.raw_level(ENABLES[use_id]) > 0 and state().skills.mapped_skill(use_id) != ENABLES[use_id]:
			session.martial_arts().enable(use_id, ENABLES[use_id])
	await _exercise()


## One lesson to each skill in turn until the potential is spent or no skill can go further.
func _learn_all(teacher: TeacherService) -> void:
	var open: Array[StringName] = SKILLS.duplicate()
	var guard: int = 0
	while not open.is_empty() and unspent() > 0 and guard < 400000:
		guard += 1
		var skill_id: StringName = open[0]
		var preview: LearnResult = teacher.preview_learn(skill_id)
		if preview != null and preview.failure_reason == LearnResult.FailureReason.NONE and preview.completion == LearnResult.Completion.NO_PROGRESS_INSUFFICIENT_ESSENCE:
			learn_stops += 1
			learn_rest += await _rest_counting(&"learn")
			continue
		if preview == null or preview.failure_reason != LearnResult.FailureReason.NONE or preview.completion != LearnResult.Completion.PROGRESSED:
			# His own level, learn.c's exp gate or anything else: this skill is done for now, unless
			# 自学 takes it on.
			var self_took: bool = false
			if self_learn and SELF_SKILLS.has(skill_id):
				self_took = await _self_learn_one(skill_id)
			if self_took:
				open.push_back(open.pop_front())
			else:
				open.pop_front()
			continue
		var result: LearnResult = teacher.request_learn(skill_id, true)
		lessons += 1
		if result != null and result.completion == LearnResult.Completion.LEVEL_INCREASED:
			learn_stops += 1
			level_stops += 1
		open.push_back(open.pop_front())


## One 自学 of `skill_id` (resting first when 精 is short): whether it took a step.
func _self_learn_one(skill_id: StringName) -> bool:
	var s: CharacterState = state()
	if s.skills.raw_level(skill_id) < SelfLearningService.MINIMUM_RAW_SKILL_LEVEL or unspent() <= 0:
		return false
	@warning_ignore("integer_division")
	if s.essence.current <= SelfLearningService.ESSENCE_COST_NUMERATOR / s.attributes.intelligence:
		self_stops += 1
		self_rest += await _rest_counting(&"self")
	var result: SelfLearningResult = session.martial_arts().self_learn(skill_id)
	if result == null or result.failure_reason != SelfLearningResult.FailureReason.NONE:
		return false
	if result.completion == SelfLearningResult.Completion.NO_PROGRESS_COMBAT_EXPERIENCE:
		return false
	self_clicks += 1
	return result.completion in [SelfLearningResult.Completion.PROGRESSED, SelfLearningResult.Completion.LEVEL_INCREASED]


## 打坐 30 气 a time to `force_percent` of the bottleneck ("练到 N 再停").
func _exercise() -> void:
	var arts: PlayerMartialArts = session.martial_arts()
	var s: CharacterState = state()
	@warning_ignore("integer_division")
	var target: int = CultivationService.exercise_cap(s, arts.apply_modifier(&"force")) * force_percent / 100
	var refused_after_rest: int = 0
	var guard: int = 0
	var pressed: bool = false
	while s.recovery.inner_force.maximum < target and guard < 2000000:
		guard += 1
		var preview: CultivationResult = arts.preview_cultivation(TrainingRun.Kind.EXERCISE, EXERCISE_KEE)
		if preview == null:
			return
		if preview.failure_reason in [CultivationResult.FailureReason.IN_COMBAT, CultivationResult.FailureReason.FORCE_STYLE_NOT_ENABLED]:
			push_error("growth sim: 打坐 refused (%s)" % CultivationResult.FailureReason.find_key(preview.failure_reason))
			return
		if preview.failure_reason != CultivationResult.FailureReason.NONE:
			# 气 short, or 精 / 神 under the 70% 打坐 needs: rest.
			if refused_after_rest > 1:
				push_error("growth sim: 打坐 still refused after a rest (%s)" % CultivationResult.FailureReason.find_key(preview.failure_reason))
				return
			refused_after_rest += 1
			exercise_stops += 1
			exercise_rest += await _rest_counting(&"exercise")
			continue
		refused_after_rest = 0
		if preview.completion == CultivationResult.Completion.NO_GAIN:
			return
		if preview.completion == CultivationResult.Completion.SKILL_CAP_REACHED and preview.internal_after <= preview.internal_before:
			return
		arts.exercise(EXERCISE_KEE, true)
		exercises += 1
		if not pressed:
			pressed = true
			exercise_runs += 1


## Rests until 精, 气 and 神 are full (RestRules), in 2 s pulses of the real recovery: the world
## seconds it took. A rest longer than rest_limit_seconds needs another press each time. A frame
## passes after each rest: the walkers' deferred calls are flushed at a frame's end, and thousands
## of rests in one frame overflow the message queue.
func _rest_counting(kind: StringName) -> float:
	var s: CharacterState = state()
	var waited: float = 0.0
	while not RestRules.rested(s) and waited < REST_GUARD_SECONDS:
		_pulse()
		waited += PULSE_SECONDS
	if waited >= REST_GUARD_SECONDS:
		push_error("growth sim: a rest did not end (%s)" % kind)
	rests += 1
	await tree.process_frame
	if rest_limit > 0.0:
		var presses: int = int(waited / rest_limit)
		match kind:
			&"learn":
				learn_stops += presses
			&"exercise":
				exercise_stops += presses
			_:
				self_stops += presses
	return waited


func _award(kind: ProgressionRules.Kind, region_id: StringName, quest_id: StringName) -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var s: CharacterState = state()
	var region: RegionDefinition = catalog.region(region_id)
	var catch_up: int = ProgressionGain.catch_up_percent(s.progression.combat_experience, 0 if region == null else region.recommended_exp, catalog.pacing().catch_up_max_percent)
	var grant: MilestoneRewards.Grant = MilestoneRewards.award(s, catalog.progression(), kind, catch_up, catalog.pacing().staged_potential_cap, quest_id)
	if grant != null:
		potential_earned += grant.potential_gain
		potential_cut += grant.potential_cut


## A share of `percent` of the stage unit (a quest of its own), with `region_id`'s catch-up.
func _extra(percent: int, region_id: StringName) -> void:
	_extra_count += 1
	var quest_id := StringName("sim.extra.%d" % _extra_count)
	var rules: ProgressionRules = GameContent.catalog().progression()
	rules.quest_percent[quest_id] = percent
	_award(ProgressionRules.Kind.QUEST, region_id, quest_id)
	rules.quest_percent.erase(quest_id)


func _apply_overrides() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var rules: ProgressionRules = catalog.progression()
	for quest_id: StringName in quest_percents:
		_restore_rules[quest_id] = int(rules.quest_percent.get(quest_id, -1))
		rules.quest_percent[quest_id] = quest_percents[quest_id]
	for region_id: StringName in recommended:
		var region: RegionDefinition = catalog.region(region_id)
		if region == null:
			push_error("growth sim: no region %s" % region_id)
			continue
		_restore_regions[region_id] = region.recommended_exp
		region._recommended_exp = recommended[region_id]


func _restore_overrides() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var rules: ProgressionRules = catalog.progression()
	for quest_id: StringName in _restore_rules:
		if _restore_rules[quest_id] < 0:
			rules.quest_percent.erase(quest_id)
		else:
			rules.quest_percent[quest_id] = _restore_rules[quest_id]
	for region_id: StringName in _restore_regions:
		catalog.region(region_id)._recommended_exp = _restore_regions[region_id]


func _row(label: String) -> Row:
	var s: CharacterState = state()
	var row := Row.new()
	row.label = label
	row.experience = s.progression.combat_experience
	row.potential_earned = potential_earned
	row.potential_cut = potential_cut
	row.unspent = unspent()
	for skill_id: StringName in SKILLS:
		row.levels[skill_id] = s.skills.raw_level(skill_id)
	row.max_force = s.recovery.inner_force.maximum
	row.force_cap = CultivationService.exercise_cap(s, session.martial_arts().apply_modifier(&"force"))
	row.kee = s.vitality.maximum
	row.gin = s.essence.maximum
	row.sen = s.spirit.maximum
	row.lessons = lessons
	row.learn_stops = learn_stops
	row.level_stops = level_stops
	row.exercise_runs = exercise_runs
	row.rests = rests
	row.learn_rest = learn_rest
	row.exercises = exercises
	row.exercise_stops = exercise_stops
	row.exercise_rest = exercise_rest
	row.self_clicks = self_clicks
	row.self_stops = self_stops
	row.self_rest = self_rest
	return row


## Real seconds the training up to `row` took: with 歇到回满 (`resting`) or standing it out.
func real_seconds(row: Row, resting: bool) -> float:
	var waits: float = row.learn_rest + row.exercise_rest + row.self_rest
	var waited: float = waits / rest_scale if resting and rest_scale > 0.0 else waits
	var stops: int = presses(row) if resting else row.learn_stops + row.exercise_stops + row.self_stops
	return float(row.lessons + row.exercises) * step_seconds + float(stops) * STOP_SECONDS + float(row.self_clicks) * CLICK_SECONDS + waited


## The presses up to `row` (the report's 停下): each stop without 自动歇; with it (`auto`) a 请教
## run's at each level, an 打坐 run's once a chapter and 自学's own (it has no run), the rests none.
func presses(row: Row) -> int:
	if auto:
		return row.level_stops + row.exercise_runs + row.self_stops
	return row.learn_stops + row.exercise_stops + row.self_stops


## The parts of real_seconds(`row`, true): steps, presses and rests, in seconds.
func real_parts(row: Row) -> Vector3:
	var steps: float = float(row.lessons + row.exercises) * step_seconds + float(row.self_clicks) * CLICK_SECONDS
	var stops: int = presses(row)
	var waits: float = row.learn_rest + row.exercise_rest + row.self_rest
	return Vector3(steps, float(stops) * STOP_SECONDS, waits / rest_scale if rest_scale > 0.0 else waits)


## The row labelled `label` (a chapter's arrival, or "end"), or null.
func row_of(label: String) -> Row:
	for row: Row in rows:
		if row.label == label:
			return row
	return null


## Lessons an hour of training (resting) between arriving at `from` and at `to`.
func lessons_per_hour(from: String, to: String) -> float:
	var a: Row = row_of(from)
	var b: Row = row_of(to)
	if a == null or b == null:
		return 0.0
	var hours: float = (real_seconds(b, true) - real_seconds(a, true)) / 3600.0
	return float(b.lessons - a.lessons) / hours if hours > 0.0 else 0.0


## The report's last lines: training time to the finale and past it, its parts, and lessons an hour late.
func summary() -> String:
	var lines: Array[String] = []
	lines.append("mode: %s; step %.0f ms; rest x%.0f" % ["自动歇" if auto else "today (stop at each want of 精/气)", step_seconds * 1000.0, rest_scale])
	for label: String in ["main.finale", "end"]:
		var row: Row = row_of(label)
		if row == null:
			continue
		var parts: Vector3 = real_parts(row)
		lines.append("training to %s: %.2f h (steps %.0f min, presses %.0f min, rests %.0f min; %d lessons, %d 打坐, %d rests, %d presses)" % [
			label, real_seconds(row, true) / 3600.0, parts.x / 60.0, parts.y / 60.0, parts.z / 60.0,
			row.lessons, row.exercises, row.rests, roundi(parts.y / STOP_SECONDS),
		])
	lines.append("lessons an hour: chapter9->10 %.0f, chapter10->finale %.0f" % [
		lessons_per_hour("main.chapter9", "main.chapter10"), lessons_per_hour("main.chapter10", "main.finale"),
	])
	return "\n".join(lines)


## The report: one line per chapter (on arriving there, after the training before it).
func table() -> String:
	var lines: Array[String] = []
	lines.append("| 章（到达时） | 经验 | 潜能累计 | 被截 | 未用 | 剑法/封山剑法/招架/闪躲/七星步/内功/封山内功 | 内力上限/瓶颈 | 气/精/神 | 请教 | 打坐 | 自学 | 停下 | 等（世界分钟） | 真实·歇（分钟） | 真实·站着等（分钟） |")
	lines.append("|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|")
	for row: Row in rows:
		var levels: Array[String] = []
		for skill_id: StringName in SKILLS:
			levels.append(str(row.levels[skill_id]))
		lines.append("| %s | %d | %d | %d | %d | %s | %d/%d | %d/%d/%d | %d | %d | %d | %d | %.0f | %.1f | %.1f |" % [
			row.label, row.experience, row.potential_earned, row.potential_cut, row.unspent, "/".join(levels),
			row.max_force, row.force_cap, row.kee, row.gin, row.sen, row.lessons, row.exercises, row.self_clicks,
			presses(row), (row.learn_rest + row.exercise_rest + row.self_rest) / 60.0,
			real_seconds(row, true) / 60.0, real_seconds(row, false) / 60.0,
		])
	return "\n".join(lines)
