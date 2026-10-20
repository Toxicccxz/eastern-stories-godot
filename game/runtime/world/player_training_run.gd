class_name PlayerTrainingRun
extends RefCounted

## One continuous run of the player's (TrainingRun; DECISIONS「连续修炼」): each step() is
## the call the single button makes (TeacherService.request_learn(), PlayerMartialArts'
## practice, exercise, meditate, respirate), quiet, after a look at what it would do
## (LearnPreview, CultivationService's preview, PracticeService.weak_progress_full()).
## It stops on what TrainingRun decides, or when the player can no longer act: a fight, a
## fall, the menu closed (portable actions), the teacher out of reach. finish() tells the
## run in a few lines (TrainingLines.run()) instead of each step's.

var training: TrainingRun
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
	_skill = null if skill_id.is_empty() else GameContent.catalog().skill(skill_id)


## One step, or the stop; true while the run goes on.
func step() -> bool:
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
	return not training.stopped()


## The player stopped the run.
func cancel() -> void:
	training.end(TrainingRun.Stop.CANCELLED)


## Every step at once (no pacing between them), then finish().
func run_to_end() -> Array[ColoredLine]:
	while step():
		pass
	return finish()


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
		training.refused(arts.last_lines)
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
	var after: TrainingRun.Stop = TrainingRun.after_cultivation(result)
	if after == TrainingRun.Stop.REFUSED:
		training.refused(arts.last_lines)
		return
	# The maximum's line (你的内力增强了！), after the sitting down one.
	var kept: Array[ColoredLine] = []
	if after == TrainingRun.Stop.MAXIMUM_UP:
		kept = arts.last_lines.slice(1)
	training.took_step(_state(), kept)
	training.end(after)
