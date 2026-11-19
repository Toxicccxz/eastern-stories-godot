class_name TrainingShow
extends Node

## 练功演出 (DECISIONS「练功演出」): what a continuous 练习 / 请教 / 打坐 / 冥思 / 修行 shows on the
## map while its window stands aside (TrainingProgress): the player's own figure at it where it
## stands — the fight's guard and strokes with the skill's weapon and its school's light, the
## fight's dodge or parry, or seated cross-legged with its 气 climbing about it — and for 请教
## the master showing the stroke a moment ahead (one seated or stone talks instead).
## The figures are the view's own (WorldVoxelView.actors); this only moves their limbs, as the
## fight's show does, and puts them back. Presentation only: it reads nothing of the run but
## what it is, takes no step of it and changes nothing saved.

const Person = preload("res://presentation/voxel/actors/voxel_person.gd")

const FORM_STRIKE: String = "strike"
const FORM_REACT: String = "react"
const FORM_SIT: String = "sit"
const FORM_STUDY: String = "study"
const FORMS: Array[String] = [FORM_STRIKE, FORM_REACT, FORM_SIT, FORM_STUDY]
## A stroke's parts, as shares of its round: drawn back, held, struck, held, back on guard.
const DRAW: float = 0.22
const HOLD: float = 0.08
const STRIKE: float = 0.13
const STAY: float = 0.15
const BACK: float = 0.27
## The strokes of a run are not all alike: each one's reach in turn.
const POWERS: Array[float] = [1.0, 0.85, 1.12]
## The limbs come on guard and stand down over this long.
const SETTLE: float = 0.25

## What is shown now ({}: nothing): form, weapon / react / colour (form_for()).
var form: Dictionary = {}
## Strokes, dodges, parries or risings of the 气 begun so far (tests, kits).
var rounds: int = 0
## The run is over and the stage about to be left: what is under way is finished, nothing new
## begun.
var closing: bool = false
var _view: WorldVoxelView
var _player: Person
var _teacher: Person
## The master shows the stroke itself (it stands and has hands); else it talks.
var _teacher_strikes: bool = false
var _colour: Color = Color.WHITE
var _clock: float = 0.0
var _next: float = 0.0
var _zoom_before: float = -1.0
var _limbs: Dictionary[int, Tween] = {}
var _effects: Array[Node] = []
var _rng := RandomNumberGenerator.new()


## How a run of `kind` is shown: `skill` the skill a step improves (null for cultivation),
## `use_id` the use it is practised as (练习), `wielded` the skill of the weapon in the player's
## hand ("" none). {} when growth.json says nothing for it.
static func form_for(kind: TrainingRun.Kind, skill: SkillDefinition, use_id: StringName, wielded: StringName = &"") -> Dictionary:
	var training: Dictionary = GrowthFx.training()
	var names: Dictionary[TrainingRun.Kind, String] = {
		TrainingRun.Kind.EXERCISE: "exercise", TrainingRun.Kind.MEDITATE: "meditate", TrainingRun.Kind.RESPIRATE: "respirate",
	}
	if names.has(kind):
		var look: Dictionary = training.get("cultivation", {}).get(names[kind], {})
		return {"form": FORM_SIT, "colour": String(look.get("colour", "ffe2a8"))}
	var shown: Dictionary = {}
	if kind == TrainingRun.Kind.PRACTICE:
		shown = _form_of_use(use_id)
	elif skill != null:
		# 请教: a basic skill is its own use; a school's skill is shown as the first use it serves.
		shown = _form_of_use(skill.skill_id)
		for use: StringName in skill.valid_enabled_uses():
			if not shown.is_empty():
				break
			shown = _form_of_use(use)
	if shown.is_empty():
		var fallback: Variant = training.get("forms", {}).get("default", {})
		shown = (fallback as Dictionary).duplicate() if fallback is Dictionary else {}
	if not FORMS.has(String(shown.get("form", ""))):
		return {}
	if shown["form"] == FORM_STRIKE:
		shown["colour"] = BattleSceneShow.school_colour(skill.skill_id if skill != null else &"default").to_html(false)
	elif shown["form"] == FORM_REACT:
		# A parry is made with what is in the hand.
		shown["weapon"] = String(wielded) if shown.get("react", "") == "parry" else ""
	return shown


## The form of the use `use_id`: a weapon's is a stroke with it; the others are growth.json's.
static func _form_of_use(use_id: StringName) -> Dictionary:
	var key: String = String(use_id)
	if key.is_empty():
		return {}
	var weapons: Dictionary = BattleArena.data().get("moves", {}).get("weapons", {})
	if weapons.has(key):
		return {"form": FORM_STRIKE, "weapon": key}
	var entry: Variant = GrowthFx.training().get("forms", {}).get(key)
	return (entry as Dictionary).duplicate() if entry is Dictionary and key != "default" else {}


## The show begins on `view`: `player_id`'s figure by `shown` (form_for()), `teacher_id`'s with
## it (&"" none). False (nothing shown) without a view, a figure or a form.
func begin(view: WorldVoxelView, player_id: StringName, teacher_id: StringName, shown: Dictionary) -> bool:
	end()
	if view == null or not view.actors.has(player_id) or not FORMS.has(String(shown.get("form", ""))):
		return false
	_player = _person(view, player_id)
	if _player == null:
		return false
	_view = view
	form = shown
	_teacher = _person(view, teacher_id) if not teacher_id.is_empty() else null
	_teacher_strikes = _teacher != null and form["form"] == FORM_STRIKE and _teacher.stone.is_empty() and not Person.POSE_LEGS.has(_teacher.pose) and _teacher.pose != Person.LIE
	_colour = Color(String(form.get("colour", "ffd98a")))
	_clock = 0.0
	_next = SETTLE
	rounds = 0
	closing = false
	var training: Dictionary = GrowthFx.training()
	_zoom_before = view.zoom()
	view.set_zoom(minf(_zoom_before, float(training.get("zoom", 1.0))), float(training.get("zoom_seconds", 0.0)))
	match String(form["form"]):
		FORM_STRIKE, FORM_REACT:
			_player.take_guard(String(form.get("weapon", "")), SETTLE)
			if _teacher_strikes:
				_teacher.take_guard(String(form.get("weapon", "")), SETTLE)
		FORM_SIT:
			_player.sitting = true
	if _teacher != null and not _teacher_strikes:
		_teacher.showing = "teach"
	return true


func showing() -> bool:
	return not form.is_empty()


## The show is over: the figures stand as they stood, the camera goes back.
func end() -> void:
	if form.is_empty():
		return
	form = {}
	for tween: Tween in _limbs.values():
		if tween.is_valid():
			tween.kill()
	_limbs.clear()
	for person: Person in [_player, _teacher]:
		if is_instance_valid(person):
			person.stand_down(SETTLE)
			person.sitting = false
			person.showing = ""
	_player = null
	_teacher = null
	if is_instance_valid(_view) and _zoom_before > 0.0:
		_view.set_zoom(_zoom_before, float(GrowthFx.training().get("zoom_seconds", 0.0)))
	_view = null
	_zoom_before = -1.0


func _exit_tree() -> void:
	end()
	GrowthFx.clear(_effects)


func _process(delta: float) -> void:
	if form.is_empty():
		return
	if not is_instance_valid(_player) or not is_instance_valid(_view):
		end()
		return
	_clock += delta
	if _clock < _next or closing:
		return
	var training: Dictionary = GrowthFx.training()
	var round_seconds: float = maxf(0.2, float(training.get("round", 1.1)))
	rounds += 1
	match String(form["form"]):
		FORM_STRIKE:
			var lead: float = clampf(float(training.get("teacher_lead", 0.5)), 0.0, 0.9) * round_seconds if _teacher_strikes else 0.0
			if _teacher_strikes and is_instance_valid(_teacher):
				_stroke(_teacher, round_seconds, 0.0, false)
			_stroke(_player, round_seconds, lead, true)
			_next += round_seconds + lead
		FORM_REACT:
			_answer(_player, String(form.get("react", "dodge")), round_seconds)
			_next += round_seconds
		FORM_SIT:
			var sit: Dictionary = training.get("sit", {})
			_effects = GrowthFx.live(_effects)
			_effects.append_array(GrowthFx.play(self, _player, String(sit.get("art", "swirl")), _colour, float(sit.get("seconds", 1.3)), sit.get("light", {}), _rng))
			_next += maxf(0.3, float(sit.get("every", 1.5)))
		_:
			_next += round_seconds


## One stroke of `person`'s, `after` seconds from now, within `round_seconds`: drawn back, struck
## (its edge leaving its light, the whoosh for the player's own), back on guard.
func _stroke(person: Person, round_seconds: float, after: float, mine: bool) -> void:
	var motion: String = BattleSceneShow.motion_of(StringName(String(form.get("weapon", ""))), BattleSceneShow.TEMPLATE_PLAIN)
	var tween: Tween = _limb(person)
	if after > 0.0:
		tween.tween_interval(after)
	tween.tween_callback(_begin_stroke.bind(person, motion, POWERS[rounds % POWERS.size()]))
	tween.tween_property(person, "swing", -1.0, round_seconds * DRAW).set_ease(Tween.EASE_OUT)
	tween.tween_interval(round_seconds * HOLD)
	tween.tween_callback(_trail.bind(person, round_seconds * STRIKE, mine))
	tween.tween_property(person, "swing", 1.0, round_seconds * STRIKE).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.tween_interval(round_seconds * STAY)
	tween.tween_property(person, "swing", 0.0, round_seconds * BACK).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)


func _begin_stroke(person: Variant, motion: String, power: float) -> void:
	if is_instance_valid(person):
		(person as Person).begin_strike(motion, power)


## One dodge or parry of `person`'s within `round_seconds`.
func _answer(person: Person, react: String, round_seconds: float) -> void:
	if not Person.REACTIONS.has(react):
		return
	var tween: Tween = _limb(person)
	tween.tween_callback(_begin_answer.bind(person, react))
	tween.tween_property(person, "react_amount", 1.0, round_seconds * 0.18).set_ease(Tween.EASE_OUT)
	tween.tween_interval(round_seconds * 0.22)
	tween.tween_property(person, "react_amount", 0.0, round_seconds * 0.3).set_ease(Tween.EASE_IN_OUT)
	if react == "dodge":
		BattleSounds.cue(BattleSounds.WHOOSH, BattleSounds.WHOOSH_QUICK_PITCH, float(GrowthFx.training().get("whoosh_db", -12.0)))


func _begin_answer(person: Variant, react: String) -> void:
	if is_instance_valid(person):
		(person as Person).swing = 0.0
		(person as Person).react = react
		(person as Person).react_amount = 0.0


## The light `person`'s edge leaves over `seconds` (the blow's travel), in the school's colour,
## and the whoosh of the player's own stroke.
func _trail(person: Variant, seconds: float, mine: bool) -> void:
	var training: Dictionary = GrowthFx.training()
	if mine:
		BattleSounds.cue(BattleSounds.WHOOSH, 1.0, float(training.get("whoosh_db", -12.0)))
	var fade: float = GameContent.catalog().pacing().feel.afterimage_seconds
	if not is_instance_valid(person) or not bool(training.get("trail", true)) or fade <= 0.0 or (person as Person).get_parent() == null:
		return
	var edge: Array = (person as Person).strike_edge()
	if edge.is_empty():
		return
	var look: Dictionary = BattleArena.data().get("impact", {}).get("trail", {})
	var trail := BattleSwingTrail.new()
	trail.name = "SwingTrail"
	trail.source = edge[0]
	trail.from = (edge[1] as Vector3).lerp(edge[2], float(look.get("inner", 0.5)))
	trail.to = edge[2]
	trail.colour = Color(_colour, float(look.get("alpha", 0.6)))
	trail.sampling = seconds
	trail.fade = fade
	(person as Person).get_parent().add_child(trail)
	_effects = GrowthFx.live(_effects)
	_effects.append(trail)
	var tween: Tween = create_tween()
	tween.tween_interval(seconds + fade + 0.05)
	tween.tween_callback(GrowthFx.drop.bind(trail))


## A fresh tween for `person`'s limbs (the one before, still running, is cut short).
func _limb(person: Person) -> Tween:
	var key: int = person.get_instance_id()
	if _limbs.has(key) and _limbs[key].is_valid():
		_limbs[key].kill()
	_limbs[key] = create_tween()
	return _limbs[key]


static func _person(view: WorldVoxelView, id: StringName) -> Person:
	var actor: Node3D = view.actors.get(id)
	return actor.get_child(0) as Person if actor != null and actor.get_child_count() > 0 else null
