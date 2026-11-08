class_name BattleSceneShow
extends Node

## 战斗拍数 C (DECISIONS「战斗拍数 C」): the fight shown in the scene — the fighters' voxel
## figures (WorldVoxelView.actors) lunge, crouch, lean, recoil, flash and leave dust and
## afterimages as the battle strip tells each line, the frame the cards play it
## (BattlePresentationController._show_line()). Four things and no more (纪要 §九):
## - the hit-stop: a freeze with a 2 px shake, only on a 重 that lands, a special's blow
##   and a felling blow;
## - the step: the attacker slides toward the target (快 short, 重 long), the one hit falls
##   back half a step to one by the ring's verdict (克 farther, 被克 barely), everyone eases
##   back to where they stand between rounds; 柳家拳's close is the two standing nearer;
## - the lean, about 10°: forward in a windup, back when hit;
## - the flash: one frame of white on the one hit (gold for 克, dim red for 被克), a puff of
##   dust where feet land.
## Templates by tag: 快 a short dash leaving a fading ghost; 重 a crouch (0.92 tall) held
## half a beat, then the lunge, the freeze and the shake; 虚 a dash stopped half way, the
## ghost left where it started, the body sliding aside; 守 a sink, and on a parry an arc of
## light with sparks before the chest. The camera moves twice: a little nearer as the fight
## begins, nearer again on its last blow (WorldVoxelView.set_zoom()).
## Presentation only: it moves each figure's model (the child of the view's actor node,
## whose own position the view sets from the 2D body every frame), never the 2D body, a
## rule, a draw or a saved value. Every duration is pacing.json's feel, 0 = that piece is
## not shown; all scale with the 战斗速度 (BattlePace) and the 自动 pace the strip uses.

## Steps, in voxel units (a figure is about 1.8 tall).
const STEP_QUICK: float = 0.35
const STEP_HEAVY: float = 0.6
const STEP_FEINT: float = 0.5
const STEP_PLAIN: float = 0.42
const STEP_SPECIAL: float = 0.3
## The one hit falls back this far by the ring's verdict (1 克, 0 相持, -1 被克), never
## farther than KNOCKBACK_CAP from where it stands.
const KNOCKBACK: Dictionary[int, float] = {1: 0.5, 0: 0.3, -1: 0.15}
const KNOCKBACK_CAP: float = 1.0
const DODGE_SIDE: float = 0.25
const PARRY_BACK: float = 0.1
const FEINT_SIDE: float = 0.2
## Standing close (柳家拳): this much nearer the target.
const CLOSE_STANCE: float = 0.3
## The crouch and the sink: never squashed past 10 %.
const CROUCH: float = 0.92
const SINK: float = 0.95
const LEAN: float = 10.0 * PI / 180.0
const SHAKE: float = 0.04
## The flashes: white for a hit, gold for 克, dim red for 被克, gold for a beat won.
const FLASH_HIT: Color = Color(1.0, 1.0, 1.0, 0.75)
const FLASH_COUNTER: Color = Color(1.0, 0.86, 0.45, 0.9)
const FLASH_COUNTERED: Color = Color(0.5, 0.18, 0.16, 0.55)
const FLASH_EARNED: Color = Color(1.0, 0.84, 0.4, 0.8)
const FLASH_SPECIAL: Color = Color(1.0, 0.9, 0.6, 0.6)
const GHOST: Color = Color(0.78, 0.86, 0.95, 0.35)
const DUST: Color = Color("b8a080")
const SPARK: Color = Color("ffe9a0")
const ARC: Color = Color(0.95, 0.9, 0.7, 0.8)
## The camera: a little nearer as the fight begins, nearer on its last blow. 战斗演出 B: when
## the fight's opening stages the camera (BattleStageOpening), the begin leaves it to that, and
## the last blow pushes FINAL_PUSH nearer than wherever the opening left it (never farther out
## than ZOOM_FINAL).
const ZOOM_OPEN: float = 0.9
const ZOOM_FINAL: float = 0.8
const FINAL_PUSH: float = 0.05
## The templates, by tag (play_line() reports which played, for the suites).
const TEMPLATE_QUICK: StringName = &"quick"
const TEMPLATE_HEAVY: StringName = &"heavy"
const TEMPLATE_FEINT: StringName = &"feint"
const TEMPLATE_GUARD: StringName = &"guard"
const TEMPLATE_PLAIN: StringName = &"plain"

var view: WorldVoxelView
## The strip's pace over the feel's seconds (1: 手动; the 快 share under 自动).
var pace: float = 1.0
## Where each figure stands, off the body's point (XZ): nearer its target when close.
var _rest: Dictionary[StringName, Vector3] = {}
## What each figure was knocked back by this round (cleared between rounds).
var _knock: Dictionary[StringName, Vector3] = {}
## 战斗演出 B: how far each figure stands raised (on the stage's top step).
var _lift: Dictionary[StringName, float] = {}
var _tweens: Dictionary[StringName, Tween] = {}
var _wound_up: Dictionary[StringName, bool] = {}
## Figures to ease home once the show they are in ends (the round ended on their blow).
var _go_home: Dictionary[StringName, bool] = {}
var _effects: Array[Node3D] = []
var _effect_tweens: Dictionary[Node3D, Tween] = {}
var _earned_shown: bool = false
var _final_zoomed: bool = false
var _dust_rng := RandomNumberGenerator.new()
## What played, as [actor_id, template, outcome] (tests, kits), newest last.
var played: Array[Array] = []
## How many times the camera moved this fight (tests: twice at most).
var zoom_moves: int = 0


func _ready() -> void:
	_dust_rng.seed = 7


## A fight begins in `p_view`'s map (null: no scene to show it in): the camera a little nearer,
## unless the fight's opening moves it (`camera_staged`).
func begin(p_view: WorldVoxelView, camera_staged: bool = false) -> void:
	end()
	view = p_view
	_earned_shown = false
	_final_zoomed = false
	zoom_moves = 0
	played.clear()
	if not camera_staged:
		_zoom(ZOOM_OPEN)


## The fight is over (or the panel left it): everything back, the camera back.
func end() -> void:
	for id: StringName in _tweens.keys():
		_stop(id)
	for id: StringName in _rest.keys():
		var model: Node3D = _model(id)
		if model != null:
			model.position = Vector3.ZERO
			model.scale = Vector3.ONE
			model.rotation.x = 0.0
			_unflash(model)
	_rest.clear()
	_knock.clear()
	_lift.clear()
	_wound_up.clear()
	_go_home.clear()
	for effect: Node3D in _effects:
		var tween: Tween = _effect_tweens.get(effect)
		if tween != null and tween.is_valid():
			tween.kill()
		if is_instance_valid(effect):
			effect.queue_free()
	_effects.clear()
	_effect_tweens.clear()
	# A staged camera is the opening's to give back (BattleStageOpening.close()).
	if view != null and is_instance_valid(view) and view.zoom() != 1.0 and not view.staged:
		_zoom(1.0)
	view = null


## Where the fighters stand: `stances` is [id, target_id, close] each (the projection); a
## figure close to its target stands CLOSE_STANCE nearer it. One not in a show eases there.
func settle(stances: Array) -> void:
	if view == null:
		return
	var seconds: float = _seconds(_feel().scene_return_seconds)
	for stance: Array in stances:
		var id: StringName = stance[0]
		var model: Node3D = _model(id)
		if model == null:
			continue
		var rest := Vector3.ZERO
		if bool(stance[2]):
			var target: Node3D = _model(stance[1])
			rest = _direction(model, target) * CLOSE_STANCE
		var changed: bool = not _rest.has(id) or not _rest[id].is_equal_approx(rest)
		_rest[id] = rest
		if changed:
			if _running(id):
				_go_home[id] = true
			else:
				_ease_home(id, model, seconds)


## The round is over: everyone knocked back eases home (回合间归位).
func round_over() -> void:
	if view == null:
		return
	var seconds: float = _seconds(_feel().scene_return_seconds)
	for id: StringName in _knock.keys():
		_knock.erase(id)
		var model: Node3D = _model(id)
		if model == null:
			continue
		# Still in the blow's own show (the round ended on it): home once that is done.
		if _running(id):
			_go_home[id] = true
		else:
			_ease_home(id, model, seconds)


## The half beat before a 重: the attacker crouches now (the strip waits scene_windup_ms
## before telling the blow); play_line() lunges from the crouch.
func windup(actor_id: StringName) -> void:
	var model: Node3D = _model(actor_id)
	var seconds: float = _seconds(_feel().scene_windup_seconds)
	if model == null or seconds <= 0.0:
		return
	_stop(actor_id)
	_wound_up[actor_id] = true
	var tween: Tween = _tween(actor_id)
	tween.set_parallel(true)
	tween.tween_property(model, "scale:y", CROUCH, seconds * 0.5).set_ease(Tween.EASE_OUT)
	tween.tween_property(model, "rotation:x", LEAN * 0.5, seconds * 0.5).set_ease(Tween.EASE_OUT)


## The line told now plays in the scene: a blow's attacker steps by its template, the one
## hit answers (flash, dust, recoil, or the dodge aside, or the parry's arc); `fatal`: the
## blow fells its target (the hit-stop, the camera's last move). A special's opening line is
## the attacker's windup with a gold flash; a beat won is a gold flash on the one who won
## it, with a hop the first time in the fight.
func play_line(line: BattleNarrationLine, fatal: bool = false) -> void:
	if view == null:
		return
	if line.cue == BattleNarrationLine.CUE_EARNED:
		_earned(line.actor_id)
		return
	if line.is_special and not line.has_blow:
		_special_opening(line.actor_id, line.target_id)
		return
	if not line.has_blow:
		return
	var me: Node3D = _model(line.actor_id)
	if me == null:
		return
	var you: Node3D = _model(line.target_id)
	var direction: Vector3 = _direction(me, you)
	var template: StringName = template_of(line.tag)
	var landed: bool = line.outcome == CombatAttackResult.Outcome.HIT
	var stop: float = _seconds(_feel().hit_stop_seconds) if landed and (template == TEMPLATE_HEAVY or line.in_special or fatal) else 0.0
	played.append([line.actor_id, template, line.outcome, stop > 0.0])
	if played.size() > 64:
		played.pop_front()
	var impact: float = _attack(line.actor_id, me, direction, template, stop, line.in_special)
	if you != null and not line.target_id.is_empty():
		_defend(line.target_id, you, direction, line, impact, stop)
	if fatal and not _final_zoomed:
		_final_zoomed = true
		_zoom(minf(ZOOM_FINAL, view.zoom() - FINAL_PUSH))


## The template a move's tag plays.
static func template_of(tag: StringName) -> StringName:
	if tag == CombatMoveTags.QUICK:
		return TEMPLATE_QUICK
	if tag == CombatMoveTags.HEAVY:
		return TEMPLATE_HEAVY
	if tag == CombatMoveTags.FEINT:
		return TEMPLATE_FEINT
	if tag == CombatMoveTags.GUARD:
		return TEMPLATE_GUARD
	return TEMPLATE_PLAIN


## The attacker's step by `template`; returns when its blow lands (seconds from now).
func _attack(id: StringName, model: Node3D, direction: Vector3, template: StringName, stop: float, special: bool) -> float:
	var feel: FeelDefinition = _feel()
	var step: float = _seconds(feel.scene_step_seconds)
	var windup_seconds: float = _seconds(feel.scene_windup_seconds)
	var back: float = _seconds(feel.scene_return_seconds)
	var home: Vector3 = _stand(id)
	var side := Vector3(-direction.z, 0.0, direction.x)
	_stop(id)
	if step <= 0.0 and windup_seconds <= 0.0 and stop <= 0.0:
		# The feel off: nothing moves.
		model.position = home
		model.scale = Vector3.ONE
		model.rotation.x = 0.0
		return 0.0
	var tween: Tween = _tween(id)
	var impact: float = 0.0
	match template:
		TEMPLATE_QUICK:
			_ghost(model)
			tween.tween_property(model, "position", home + direction * STEP_QUICK, step * 0.7).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
			impact = step * 0.7
		TEMPLATE_HEAVY:
			if not _wound_up.get(id, false) and windup_seconds > 0.0:
				_together(tween).tween_property(model, "scale:y", CROUCH, windup_seconds * 0.5).set_ease(Tween.EASE_OUT)
				tween.tween_property(model, "rotation:x", LEAN * 0.5, windup_seconds * 0.5).set_ease(Tween.EASE_OUT)
				tween.set_parallel(false)
				tween.tween_interval(windup_seconds * 0.5)
				impact += windup_seconds
			_together(tween).tween_property(model, "position", home + direction * STEP_HEAVY, step * 1.3).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
			tween.tween_property(model, "scale:y", 1.0, step * 1.3)
			tween.tween_property(model, "rotation:x", LEAN, step * 1.3)
			tween.set_parallel(false)
			impact += step * 1.3
		TEMPLATE_FEINT:
			_ghost(model)
			tween.tween_property(model, "position", home + direction * STEP_FEINT * 0.5, step * 0.6).set_trans(Tween.TRANS_LINEAR)
			tween.tween_property(model, "position", home + direction * STEP_FEINT * 0.5 + side * FEINT_SIDE, step * 0.5).set_ease(Tween.EASE_OUT)
			impact = step * 0.6
		TEMPLATE_GUARD:
			_together(tween).tween_property(model, "scale:y", SINK, step).set_ease(Tween.EASE_OUT)
			tween.tween_property(model, "rotation:x", -LEAN * 0.4, step).set_ease(Tween.EASE_OUT)
			tween.set_parallel(false)
			tween.tween_interval(step)
			impact = step
		_:
			var reach: float = STEP_SPECIAL if special else STEP_PLAIN
			tween.tween_property(model, "position", home + direction * reach, step).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
			impact = step
	_wound_up.erase(id)
	if stop > 0.0:
		# The hit-stop: held at the lunge's end, a 2 px shake across it.
		var struck: Vector3 = home + direction * (STEP_HEAVY if template == TEMPLATE_HEAVY else STEP_PLAIN)
		for shake: int in 2:
			tween.tween_property(model, "position", struck + side * SHAKE, stop * 0.25)
			tween.tween_property(model, "position", struck - side * SHAKE, stop * 0.25)
		tween.tween_property(model, "position", struck, 0.0)
	_together(tween).tween_property(model, "position", home, back).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(model, "scale:y", 1.0, back)
	tween.tween_property(model, "rotation:x", 0.0, back)
	tween.set_parallel(false)
	tween.tween_callback(_done.bind(id))
	return impact


## The one hit answers the blow at `impact`: a hit flashes (by the ring), raises dust,
## leans back and falls back after the hit-stop; a dodge steps aside; a parry shows the
## arc and sparks and gives a little.
func _defend(id: StringName, model: Node3D, direction: Vector3, line: BattleNarrationLine, impact: float, stop: float) -> void:
	var feel: FeelDefinition = _feel()
	var step: float = _seconds(feel.scene_step_seconds)
	var back: float = _seconds(feel.scene_return_seconds)
	var flash_seconds: float = _seconds(feel.scene_flash_seconds)
	var side := Vector3(-direction.z, 0.0, direction.x)
	_stop(id)
	if step <= 0.0 and flash_seconds <= 0.0 and back <= 0.0:
		model.position = _stand(id)
		return
	var tween: Tween = _tween(id)
	if impact > 0.0:
		tween.tween_interval(impact)
	match line.outcome:
		CombatAttackResult.Outcome.HIT:
			var colour: Color = FLASH_COUNTER if line.ring > 0 else FLASH_COUNTERED if line.ring < 0 else FLASH_HIT
			tween.tween_callback(_flash.bind(model, colour, flash_seconds))
			tween.tween_callback(_dust.bind(model))
			var knocked: Vector3 = _knock.get(id, Vector3.ZERO) + direction * KNOCKBACK.get(line.ring, KNOCKBACK[0])
			if knocked.length() > KNOCKBACK_CAP:
				knocked = knocked.normalized() * KNOCKBACK_CAP
			_knock[id] = knocked
			tween.tween_property(model, "rotation:x", -LEAN, 0.0)
			if stop > 0.0:
				tween.tween_interval(stop)
			_together(tween).tween_property(model, "position", _stand(id), step).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
			tween.tween_property(model, "rotation:x", 0.0, back).set_ease(Tween.EASE_OUT)
			tween.tween_property(model, "scale:y", 1.0, back)
			tween.set_parallel(false)
		CombatAttackResult.Outcome.DODGE:
			var home: Vector3 = _stand(id)
			tween.tween_property(model, "position", home + side * DODGE_SIDE, step * 0.5).set_ease(Tween.EASE_OUT)
			tween.tween_callback(_dust.bind(model))
			_together(tween).tween_property(model, "position", home, back * 0.5).set_ease(Tween.EASE_IN_OUT)
			tween.tween_property(model, "scale:y", 1.0, back * 0.5)
			tween.tween_property(model, "rotation:x", 0.0, back * 0.5)
			tween.set_parallel(false)
		CombatAttackResult.Outcome.PARRY:
			var home: Vector3 = _stand(id)
			tween.tween_callback(_parry_arc.bind(model, -direction))
			_together(tween).tween_property(model, "position", home + direction * PARRY_BACK, step * 0.5).set_ease(Tween.EASE_OUT)
			tween.tween_property(model, "scale:y", SINK, step * 0.5)
			_together(tween).tween_property(model, "position", home, back * 0.6).set_ease(Tween.EASE_IN_OUT)
			tween.tween_property(model, "scale:y", 1.0, back * 0.6)
			tween.tween_property(model, "rotation:x", 0.0, back * 0.6)
			tween.set_parallel(false)
	tween.tween_callback(_done.bind(id))


## A special's opening line: the attacker gathers (the crouch and lean) in a gold flash.
func _special_opening(actor_id: StringName, target_id: StringName) -> void:
	var model: Node3D = _model(actor_id)
	var windup_seconds: float = _seconds(_feel().scene_windup_seconds)
	if model == null or windup_seconds <= 0.0:
		return
	_stop(actor_id)
	_flash(model, FLASH_SPECIAL, _seconds(_feel().scene_flash_seconds) * 2.0)
	var direction: Vector3 = _direction(model, _model(target_id))
	var tween: Tween = _tween(actor_id)
	tween.set_parallel(true)
	tween.tween_property(model, "scale:y", CROUCH, windup_seconds * 0.5).set_ease(Tween.EASE_OUT)
	tween.tween_property(model, "rotation:x", LEAN * 0.5, windup_seconds * 0.5).set_ease(Tween.EASE_OUT)
	tween.tween_property(model, "position", _stand(actor_id) - direction * 0.1, windup_seconds * 0.5)
	tween.set_parallel(false)
	tween.tween_callback(_done.bind(actor_id))
	_wound_up[actor_id] = true


## A beat won: the winner flashes gold; the first time in a fight, a hop with it.
func _earned(actor_id: StringName) -> void:
	var model: Node3D = _model(actor_id)
	var flash_seconds: float = _seconds(_feel().scene_flash_seconds)
	if model == null or flash_seconds <= 0.0:
		return
	_flash(model, FLASH_EARNED, flash_seconds * 3.0)
	if _earned_shown or _running(actor_id):
		return
	_earned_shown = true
	var hop: float = _seconds(_feel().scene_step_seconds)
	if hop <= 0.0:
		return
	var tween: Tween = _tween(actor_id)
	var home: Vector3 = _stand(actor_id)
	tween.tween_property(model, "position", home + Vector3.UP * 0.12, hop * 0.5).set_ease(Tween.EASE_OUT)
	tween.tween_property(model, "position", home, hop * 0.5).set_ease(Tween.EASE_IN)
	tween.tween_callback(_done.bind(actor_id))


## Whether the first beat won this fight had its whole ceremony already (the sounds follow).
func earned_shown() -> bool:
	return _earned_shown


# --- the figures ----------------------------------------------------------------------------


## The figure's model: the first child of the view's actor node for `id` (its position is the
## show's; the actor node's is the body's), null when there is none.
func _model(id: StringName) -> Node3D:
	if view == null or not is_instance_valid(view) or id.is_empty() or not view.actors.has(id):
		return null
	var actor: Node3D = view.actors[id]
	if not is_instance_valid(actor) or actor.get_child_count() == 0:
		return null
	return actor.get_child(0) as Node3D


## Where `id` stands now: its rest (nearer its target when close) plus what it was knocked
## back by this round, raised onto the stage when it stands on it.
func _stand(id: StringName) -> Vector3:
	return _rest.get(id, Vector3.ZERO) + _knock.get(id, Vector3.ZERO) + Vector3.UP * _lift.get(id, 0.0)


## 战斗演出 B: `id` steps up onto the stage (`height` over the ground; 0 down again) over
## `seconds`.
func set_lift(id: StringName, height: float, seconds: float) -> void:
	_lift[id] = height
	var model: Node3D = _model(id)
	if model == null:
		return
	if _running(id):
		_go_home[id] = true
	else:
		_ease_home(id, model, seconds)


## How far `id` stands raised (tests).
func lift_of(id: StringName) -> float:
	return _lift.get(id, 0.0)


## The way from `me` to `you` along the ground; without `you`, the way `me` faces.
static func _direction(me: Node3D, you: Node3D) -> Vector3:
	var way := Vector3.ZERO
	if you != null and is_instance_valid(you):
		way = you.global_position - me.global_position
	else:
		way = me.global_transform.basis.z
	way.y = 0.0
	return way.normalized() if way.length_squared() > 0.0001 else Vector3.FORWARD


func _ease_home(id: StringName, model: Node3D, seconds: float) -> void:
	var home: Vector3 = _stand(id)
	if model.position.is_equal_approx(home) and model.scale.is_equal_approx(Vector3.ONE) and is_zero_approx(model.rotation.x):
		return
	if seconds <= 0.0:
		model.position = home
		model.scale = Vector3.ONE
		model.rotation.x = 0.0
		return
	var tween: Tween = _tween(id)
	tween.set_parallel(true)
	tween.tween_property(model, "position", home, seconds).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(model, "scale:y", 1.0, seconds)
	tween.tween_property(model, "rotation:x", 0.0, seconds)
	tween.set_parallel(false)
	tween.tween_callback(_done.bind(id))


func _tween(id: StringName) -> Tween:
	_stop(id)
	var tween: Tween = create_tween()
	_tweens[id] = tween
	return tween


## The tweeners appended next run together, after everything appended before (a parallel
## group after sequential steps: set_parallel() alone would join the last step).
static func _together(tween: Tween) -> Tween:
	tween.set_parallel(true)
	return tween.chain()


func _stop(id: StringName) -> void:
	var tween: Tween = _tweens.get(id)
	if tween != null and tween.is_valid():
		tween.kill()
	_tweens.erase(id)


func _done(id: StringName) -> void:
	_tweens.erase(id)
	if _go_home.erase(id):
		var model: Node3D = _model(id)
		if model != null:
			_ease_home(id, model, _seconds(_feel().scene_return_seconds))


## Whether `id`'s figure is in a show now.
func _running(id: StringName) -> bool:
	var tween: Tween = _tweens.get(id)
	return tween != null and tween.is_valid() and tween.is_running()


# --- the flash, the ghost, the dust, the arc --------------------------------------------------


## One frame of `colour` over every part of the figure (material_overlay), off after `seconds`.
func _flash(model: Node3D, colour: Color, seconds: float) -> void:
	if seconds <= 0.0 or not is_instance_valid(model):
		return
	var overlay := StandardMaterial3D.new()
	overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	overlay.albedo_color = colour
	for part: GeometryInstance3D in _parts(model):
		part.material_overlay = overlay
	model.set_meta("battle_flash", overlay)
	var tween: Tween = create_tween()
	tween.tween_interval(seconds)
	tween.tween_callback(_unflash.bind(model, overlay))


func _unflash(model: Node3D, overlay: Material = null) -> void:
	if not is_instance_valid(model):
		return
	if overlay != null and model.get_meta("battle_flash", null) != overlay:
		return # A newer flash took over.
	for part: GeometryInstance3D in _parts(model):
		part.material_overlay = null
	model.remove_meta("battle_flash")


## The afterimage: the figure's parts copied where it stands, pale and seen through, fading.
func _ghost(model: Node3D) -> void:
	var seconds: float = _seconds(_feel().afterimage_seconds)
	if seconds <= 0.0 or not is_instance_valid(model) or model.get_parent() == null:
		return
	var ghost := model.duplicate(0) as Node3D
	if ghost == null:
		return
	ghost.name = "Afterimage"
	var pale := StandardMaterial3D.new()
	pale.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pale.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pale.albedo_color = GHOST
	for part: GeometryInstance3D in _parts(ghost):
		part.material_override = pale
		part.material_overlay = null
		part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	model.get_parent().add_child(ghost)
	ghost.transform = model.transform
	_effects.append(ghost)
	var tween: Tween = create_tween()
	_effect_tweens[ghost] = tween
	tween.tween_property(pale, "albedo_color:a", 0.0, seconds)
	tween.tween_callback(_drop_effect.bind(ghost))


## A puff of dust at the figure's feet: a few small cubes rising and spreading, shrinking away.
func _dust(model: Node3D) -> void:
	var seconds: float = _seconds(_feel().scene_dust_seconds)
	if seconds <= 0.0 or not is_instance_valid(model) or model.get_parent() == null:
		return
	var puff := Node3D.new()
	puff.name = "Dust"
	puff.position = model.position
	model.get_parent().add_child(puff)
	_effects.append(puff)
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE * 0.13
	var material := StandardMaterial3D.new()
	material.albedo_color = DUST
	material.roughness = 1.0
	var tween: Tween = create_tween().set_parallel(true)
	_effect_tweens[puff] = tween
	for index: int in 4:
		var mote := MeshInstance3D.new()
		mote.mesh = mesh
		mote.material_override = material
		mote.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var angle: float = _dust_rng.randf_range(0.0, TAU)
		var out := Vector3(cos(angle), 0.0, sin(angle))
		mote.position = out * 0.12 + Vector3.UP * 0.06
		puff.add_child(mote)
		tween.tween_property(mote, "position", out * 0.4 + Vector3.UP * 0.25, seconds).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tween.tween_property(mote, "scale", Vector3.ONE * 0.05, seconds).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(_drop_effect.bind(puff))


## A parry: an arc of light before the chest, facing `toward`, and three sparks off it.
func _parry_arc(model: Node3D, toward: Vector3) -> void:
	var seconds: float = _seconds(_feel().scene_step_seconds)
	if seconds <= 0.0 or not is_instance_valid(model) or model.get_parent() == null:
		return
	var arc := Node3D.new()
	arc.name = "ParryArc"
	arc.position = model.position + Vector3.UP * 1.1 + toward * 0.35
	model.get_parent().add_child(arc)
	_effects.append(arc)
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.albedo_color = ARC
	var side := Vector3(-toward.z, 0.0, toward.x)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.1, 0.1, 0.04)
	for index: int in 5:
		var angle: float = (float(index) - 2.0) * 0.4
		var part := MeshInstance3D.new()
		part.mesh = mesh
		part.material_override = glow
		part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		part.position = side * sin(angle) * 0.45 + Vector3.UP * (cos(angle) * 0.45 - 0.3)
		arc.add_child(part)
	var spark := StandardMaterial3D.new()
	spark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spark.albedo_color = SPARK
	var tween: Tween = create_tween().set_parallel(true)
	_effect_tweens[arc] = tween
	for index: int in 3:
		var bit := MeshInstance3D.new()
		bit.mesh = mesh
		bit.scale = Vector3.ONE * 0.5
		bit.material_override = spark
		bit.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		arc.add_child(bit)
		var fly: Vector3 = (side * (float(index) - 1.0) * 0.5 + Vector3.UP * 0.6 + toward * 0.3)
		tween.tween_property(bit, "position", fly, seconds * 1.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tween.tween_property(bit, "scale", Vector3.ZERO, seconds * 1.5).set_ease(Tween.EASE_IN)
	tween.tween_property(glow, "albedo_color:a", 0.0, seconds * 1.2)
	tween.chain().tween_callback(_drop_effect.bind(arc))


## An effect's time is up (its tween's last step; the effect may be gone with end() already).
func _drop_effect(effect: Variant) -> void:
	if not is_instance_valid(effect):
		return
	_effects.erase(effect)
	_effect_tweens.erase(effect)
	(effect as Node3D).queue_free()


## Every drawn part under `node`.
static func _parts(node: Node) -> Array[GeometryInstance3D]:
	var parts: Array[GeometryInstance3D] = []
	for child: Node in node.get_children():
		if child is GeometryInstance3D:
			parts.append(child)
		parts.append_array(_parts(child))
	return parts


## The effects standing now (tests).
func effect_count() -> int:
	return _effects.size()


# --- time and the camera ---------------------------------------------------------------------


func _feel() -> FeelDefinition:
	return GameContent.catalog().pacing().feel


## The feel's seconds at the 战斗速度 and the strip's pace.
func _seconds(feel_seconds: float) -> float:
	return BattlePace.real_seconds(feel_seconds) * pace if feel_seconds > 0.0 else 0.0


func _zoom(factor: float) -> void:
	var seconds: float = _feel().battle_zoom_seconds
	if seconds <= 0.0 or view == null or not is_instance_valid(view):
		return
	view.set_zoom(factor, _seconds(seconds))
	zoom_moves += 1
