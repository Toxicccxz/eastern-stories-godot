class_name PlayerTrainingRun
extends RefCounted

## One continuous run of the player's (TrainingRun; DECISIONS「连续修炼」): each step() is
## the call the single button makes (TeacherService.request_learn(), PlayerMartialArts'
## practice, exercise, meditate, respirate), quiet, after a look at what it would do
## (LearnPreview, CultivationService's preview, PracticeService.weak_progress_full()).
## It stops on what TrainingRun decides, or when the player can no longer act: a fight, a
## fall, the menu closed (portable actions), the teacher out of reach. finish() tells the
## run in a few lines (TrainingLines.run()) instead of each step's.
## 自动歇 (成长曲线 B; pacing training_auto_rest; DECISIONS「连续修炼」): at a stop for 精, 气 or 神
## short (TrainingRun.rest_mends()) the run rests by itself — the session's 歇到回满, quiet, the page
## left open (begin_rest(true)) — and step() waits meanwhile. A rest that ends with the three full
## (or at its longest with something come back) takes the same run on; any other end (有人来袭, 掉血,
## 断水, 剧情, 换图, 倒下) ends it with the rest's own line, and so does a rest that cannot begin. Full
## already and still short (气 asked above the maximum): it stops there, as without 自动歇. With
## 朱鸿雪's task running against its time it does not rest by itself (TrainingRun.rest_held_back()).
## The page that starts the run names its window's holds (`window_holds`): only those are lifted.

var training: TrainingRun
## 自动歇 for this run (pacing's knob; the suites may set it).
var auto_rest: bool:
	get:
		return training.auto_rest
	set(value):
		training.auto_rest = value
## The holds on world time of the window the run is on (SharedGameplayUI's popup or menu hold),
## lifted while the run rests by itself; empty: none (a run with no window holding the world).
var window_holds: Array[StringName] = []
## The run's lines, once finished.
var lines: Array[ColoredLine] = []
var _session: WorldSessionController
var _teacher: TeacherService
var _use_id: StringName = &""
var _amount: int = 0
## The skill a step improves (null for cultivation) and the one the stop may name.
var _skill: SkillDefinition
var _basic: SkillDefinition
var _finished: bool = false
## 自动歇: a rest of the run's own is under way, and the three when it began.
var _resting: bool = false
var _rest_from: Vector3i = Vector3i.ZERO


## learn <skill> from the teacher, again and again.
static func learn(session: WorldSessionController, teacher: TeacherService, skill_id: StringName) -> PlayerTrainingRun:
	var run := PlayerTrainingRun.new(session, TrainingRun.Kind.LEARN, skill_id)
	run._teacher = teacher
	return run


## practice <use>, again and again.
static func practice(session: WorldSessionController, use_id: StringName) -> PlayerTrainingRun:
	var state: CharacterState = session.player_runtime().state
	var run := PlayerTrainingRun.new(session, TrainingRun.Kind.PRACTICE, state.skills.mapped_skill(use_id))
	run._use_id = use_id
	run._basic = GameContent.catalog().skill(use_id)
	return run


## exercise / meditate / respirate (`kind`) with `amount`, again and again.
static func cultivate(session: WorldSessionController, kind: TrainingRun.Kind, amount: int) -> PlayerTrainingRun:
	var run := PlayerTrainingRun.new(session, kind, &"")
	run._amount = amount
	# What the bottleneck waits on: exercise.c's force, meditate.c's spells, respirate.c's magic.
	var capped: Dictionary[TrainingRun.Kind, StringName] = {
		TrainingRun.Kind.EXERCISE: SkillIds.FORCE, TrainingRun.Kind.MEDITATE: SkillIds.SPELLS,
		TrainingRun.Kind.RESPIRATE: SkillIds.MAGIC,
	}
	run._basic = GameContent.catalog().skill(capped.get(kind, &""))
	return run


func _init(session: WorldSessionController, kind: TrainingRun.Kind, skill_id: StringName) -> void:
	_session = session
	training = TrainingRun.new(kind, skill_id, session.player_runtime().state)
	training.auto_rest = GameContent.catalog().pacing().training_auto_rest
	_skill = null if skill_id.is_empty() else GameContent.catalog().skill(skill_id)


## One step, or the stop; true while the run goes on (a rest of its own under way included: the
## step waits for it).
func step() -> bool:
	if _resting:
		if _session.resting_for_training():
			return true
		# The rest went without a word to the run (it should not): the run is broken off.
		_resting = false
		_break_off(TrainingRun.Stop.INTERRUPTED, "")
		return false
	if training.stopped():
		return false
	if not can_act():
		training.end(TrainingRun.Stop.INTERRUPTED)
		return false
	match training.kind:
		TrainingRun.Kind.LEARN:
			_learn_step()
		TrainingRun.Kind.PRACTICE:
			_practice_step()
		_:
			_cultivation_step()
	if not training.stopped() and not can_act():
		training.end(TrainingRun.Stop.INTERRUPTED)
	if training.stopped() and training.auto_rest and training.rest_mends():
		return _rest()
	return not training.stopped()


## 自动歇 is resting the player now (a rest gone without a word is not: step() then ends the run).
func resting() -> bool:
	return _resting and _session.resting_for_training()


## Game minutes the run's rest under way has lasted.
func rest_minutes() -> int:
	return _session.rest_minutes() if _resting else 0


## Real seconds between two steps (feel: closer for a run that rests by itself).
func step_seconds() -> float:
	var feel: FeelDefinition = GameContent.catalog().pacing().feel
	return feel.training_auto_step_seconds if training.auto_rest else feel.training_step_seconds


## The player stopped the run (a rest of its own under way stops with it).
func cancel() -> void:
	if _resting:
		if _session.resting_for_training():
			_session.stop_rest() # _on_rest_ended(CANCELLED)
		if _resting:
			_resting = false
			_break_off(TrainingRun.Stop.CANCELLED, "")
	training.end(TrainingRun.Stop.CANCELLED)


## Every step at once (no pacing between them), then finish(). A rest takes world time, which
## does not pass here: the run stops where it would rest, as with 自动歇 off.
func run_to_end() -> Array[ColoredLine]:
	training.auto_rest = false
	while step():
		pass
	return finish()


## 自动歇 at a stop for 精, 气 or 神 short: true while the rest begun goes on. Full already (the
## step asks more than the maximum), the run stops as it is; a rest refused (no water, a scene)
## stops it with why.
func _rest() -> bool:
	var state: CharacterState = _state()
	# Full already; or the player's own 歇到回满 stands under this window (held with it).
	if RestRules.rested(state) or _session.resting():
		return false
	if TrainingRun.rest_held_back(state):
		training.rest_line = TranslationServer.translate(TrainingLines.RUN_TASK_TIME)
		return false
	var refused: String = _session.begin_rest(true, window_holds)
	if not refused.is_empty():
		training.rest_line = refused
		return false
	_resting = true
	_rest_from = RestRules.currents(state)
	if not _session.rest_ended.is_connected(_on_rest_ended):
		_session.rest_ended.connect(_on_rest_ended, CONNECT_ONE_SHOT)
	return true


func _on_rest_ended(outcome: int, line: String) -> void:
	if not _resting:
		return
	_resting = false
	# PlayerRest keeps the last rest's length until the next begins.
	training.rested(_session.rest_world_seconds(), _session.rest_minutes())
	var state: CharacterState = _state()
	match outcome:
		RestRules.Outcome.RESTED:
			training.resume(state)
		RestRules.Outcome.LIMIT:
			# At its longest: on while something came back (a deep wound heals over several), else
			# the stop stands, the rest's line saying why.
			var now: Vector3i = RestRules.currents(state)
			if now.x > _rest_from.x or now.y > _rest_from.y or now.z > _rest_from.z:
				training.resume(state)
			else:
				training.rest_line = line
		RestRules.Outcome.CANCELLED:
			# The page went away under the rest because the teacher left reach (not the player's hand).
			_break_off(TrainingRun.Stop.CANCELLED if can_act() else TrainingRun.Stop.INTERRUPTED, "")
		_:
			# 有人来袭, 掉血, 断水, 剧情, 换图 say their own line; a fall says its own elsewhere.
			_break_off(TrainingRun.Stop.INTERRUPTED, line)


## The run ends during its rest: `why`, with the rest's `line`.
func _break_off(why: TrainingRun.Stop, line: String) -> void:
	training.resume(_state())
	training.end(why)
	training.rest_line = line


## The player may take a step: conscious, not fighting, with portable actions (not in a
## fight or between maps), the teacher in reach for 请教.
func can_act() -> bool:
	var player: WorldPlayerRuntimeState = _session.player_runtime()
	if player == null or player.life_status != CharacterRuntimeLifeStatus.Value.ACTIVE or player.relationship.is_fighting():
		return false
	if not _session.martial_arts().available():
		return false
	return _teacher == null or (is_instance_valid(_teacher) and _teacher.can_teach())


## Tells the run (the log, and the page's last lines) once it has stopped; again, nothing.
func finish() -> Array[ColoredLine]:
	if _finished:
		return lines
	if _resting:
		cancel()
	training.end(TrainingRun.Stop.CANCELLED)
	_finished = true
	var teacher_name: String = "" if _teacher == null else _teacher.display_name()
	lines = TrainingLines.run(training, _skill, teacher_name, _basic, _amount)
	_session.martial_arts().last_lines = lines
	if _teacher != null and is_instance_valid(_teacher):
		_teacher.last_colored = lines
		_teacher.last_lines = ColoredLine.texts(lines)
	var hud: SharedGameplayUI = _session.shared_ui()
	if hud != null and not lines.is_empty():
		hud.append_colored_lines(lines)
	return lines


func is_finished() -> bool:
	return _finished


## The player's state (the progress bar reads it).
func state() -> CharacterState:
	return _state()


## What the run is, for the one that shows it (练功演出): its session, the skill a step improves
## (null for cultivation), the use practised (&"" but for 练习) and the teacher's id (&"" none).
func session() -> WorldSessionController:
	return _session


func skill() -> SkillDefinition:
	return _skill


func use_id() -> StringName:
	return _use_id


func teacher_id() -> StringName:
	return _teacher.npc.character_id if _teacher != null and is_instance_valid(_teacher) and _teacher.npc != null else &""


func _state() -> CharacterState:
	return _session.player_runtime().state


func _learn_step() -> void:
	var preview: LearnResult = _teacher.preview_learn(training.skill_id)
	if preview == null:
		training.end(TrainingRun.Stop.INTERRUPTED)
		return
	var waste: TrainingRun.Stop = training.look_at_learn(preview, _state().progression.combat_experience)
	if waste != TrainingRun.Stop.NONE:
		training.end(waste)
		return
	var result: LearnResult = _teacher.request_learn(training.skill_id, true)
	var after: TrainingRun.Stop = TrainingRun.after_learn(result)
	if result.success:
		training.took_step(_state(), TrainingLines.improved(result.skill_improvement, result.authored_effect, _skill))
	if after == TrainingRun.Stop.REFUSED:
		training.refused(_teacher.last_colored)
	elif after != TrainingRun.Stop.NONE:
		training.end(after)


func _practice_step() -> void:
	var arts: PlayerMartialArts = _session.martial_arts()
	# The command's own refusals come first (weapon, water, kee …), as a single practice's.
	var preview: PracticeResult = arts.preview_practice(_use_id)
	if preview == null:
		training.end(TrainingRun.Stop.INTERRUPTED)
		return
	if preview.failure_reason == PracticeResult.FailureReason.NONE and arts.practice_progress_full(_use_id):
		training.end(TrainingRun.Stop.PROGRESS_FULL)
		return
	var result: PracticeResult = arts.practice(_use_id, true)
	if result == null:
		training.end(TrainingRun.Stop.INTERRUPTED)
		return
	if result.failure_reason == PracticeResult.FailureReason.PRACTICE_CONJURED:
		# Paid for, and its lines (told already) open a fight: the run is interrupted.
		training.took_step(_state())
		training.end(TrainingRun.Stop.INTERRUPTED)
		return
	var after: TrainingRun.Stop = TrainingRun.after_practice(result)
	if after == TrainingRun.Stop.REFUSED:
		training.refused(arts.last_lines, TrainingRun.rest_mends_practice(result))
		return
	training.took_step(_state(), TrainingLines.improved(result.skill_improvement, result.authored_effect, _skill))
	training.end(after)


func _cultivation_step() -> void:
	var arts: PlayerMartialArts = _session.martial_arts()
	var preview: CultivationResult = arts.preview_cultivation(training.kind, _amount)
	if preview == null:
		training.end(TrainingRun.Stop.INTERRUPTED)
		return
	var waste: TrainingRun.Stop = training.look_at_cultivation(preview)
	if waste != TrainingRun.Stop.NONE:
		training.end(waste)
		return
	var result: CultivationResult
	match training.kind:
		TrainingRun.Kind.EXERCISE:
			result = arts.exercise(_amount, true)
		TrainingRun.Kind.MEDITATE:
			result = arts.meditate(_amount, true)
		TrainingRun.Kind.RESPIRATE:
			result = arts.respirate(_amount, true)
	if result == null:
		training.end(TrainingRun.Stop.INTERRUPTED)
		return
	var after: TrainingRun.Stop = TrainingRun.after_cultivation(result, training.target_maximum, cultivated_maximum())
	if after == TrainingRun.Stop.REFUSED:
		training.refused(arts.last_lines, TrainingRun.rest_mends_cultivation(result))
		return
	# The maximum's line (你的内力增强了！), after the sitting down one.
	var kept: Array[ColoredLine] = []
	if result.completion == CultivationResult.Completion.MAXIMUM_INCREASED:
		kept = arts.last_lines.slice(1)
	training.took_step(_state(), kept)
	training.end(after)


## The maximum a cultivation run raises (内力, 法力 or 灵力), now.
func cultivated_maximum() -> int:
	var state: CharacterState = _state()
	match training.kind:
		TrainingRun.Kind.MEDITATE:
			return state.recovery.mana.maximum
		TrainingRun.Kind.RESPIRATE:
			return state.recovery.atman.maximum
	return state.recovery.inner_force.maximum
