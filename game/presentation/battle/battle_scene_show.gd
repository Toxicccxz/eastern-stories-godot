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
## whose own position the view sets from the 2D body every frame — or, 战斗演出 D, from its place
## on the raised stage, WorldVoxelView.place_actor()), never the 2D body, a
## rule, a draw or a saved value. Every duration is pacing.json's feel, 0 = that piece is
## not shown; all scale with the 战斗速度 (BattlePace) and the 自动 pace the strip uses.
## 战斗拍数 E (DECISIONS「战斗拍数 E · 重招」): a 重 is two beats and looks it — a longer crouch
## with the 气 gathering into the figure (motes drawn in, a warm glow), then a freeze HEAVY_STOP
## times longer, the one hit thrown HEAVY_KNOCK times farther in a bigger burst of dust; a 快 is
## quicker and sharper. A 重 that lands throws the one hit off balance (失衡: they reel side to
## side in a dull red), one dodged or parried leaves its striker open (露空: a stumble forward
## in a cold flash).
## 战斗肢体 (DECISIONS「战斗肢体」): the figures fight with their limbs. Everyone in the fight
## stands on guard with its weapon in its hand (settle(): the weapon's skill from the projection;
## VoxelPerson.take_guard()); a blow swings the arm by the weapon's motion (battle_stage.json
## moves.weapons, the one the move's name over the head drops in by; a 重 with a sword, a sabre
## or a staff is the two-handed blow from overhead): wound up as the line is told, through as
## the step lands, held over the hit-stop, back on guard; the one struck at is thrown open by a
## hit, leans out of a miss, or brings its weapon across for a parry. A beast (the view marks its
## model `pounce`) leaps at its target instead of sliding. The figures stand down as the fight ends.
## The rules fell a fighter as its round is worked out and the blow that did it is told later:
## the figure stands until then (WorldVoxelView.hold_fall(); with the feel's fall_ms 0 nothing is
## held) and falls as that blow lands (`fatal`), or once the lines are all told (lines_told()).

## 战斗特效 (DECISIONS「战斗特效」): what a blow leaves in the scene (battle_stage.json `impact`).
## A swung weapon leaves its light (BattleSwingTrail, along VoxelPerson.strike_edge(), coloured
## by the wound; a bare hand leaves none); something thrown flies to the one struck at (on past
## a dodge, up off a parry); chips fly off the one hit, the colours of its coat (dark ones among
## them in a 死斗, `blood_chips`); the base answers — its bricks hop under a 重, a special's blow
## and a felling blow, its braziers leap and its flags snap at a special's opening and a felling
## blow (BattleArena.jolt(), flare()); a beast leaps all the way to the one it strikes at.

const Person := preload("res://presentation/voxel/actors/voxel_person.gd")
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
## 战斗拍数 E: a 重's freeze and throw against an ordinary blow's; a 快's lunge as a part of the step.
const HEAVY_STOP: float = 1.8
const HEAVY_KNOCK: float = 1.7
const QUICK_LUNGE: float = 0.5
## 失衡's reel (radians, side to side) and 露空's stumble (forward, voxel units).
const REEL: float = 14.0 * PI / 180.0
const STUMBLE: float = 0.18
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
## 战斗拍数 E: the 气 gathering before a 重, 失衡's dull red, 露空's cold flash.
const FLASH_CHARGE: Color = Color(1.0, 0.7, 0.32, 0.3)
const CHARGE_MOTE: Color = Color("ffcf6a")
const FLASH_STAGGER: Color = Color(0.62, 0.16, 0.12, 0.6)
const FLASH_EXPOSED: Color = Color(0.62, 0.78, 0.95, 0.55)
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
## 战斗肢体: how far a blow's swing goes by its template (a feint and a guarded blow stop short)
## and how much farther than the plain one its pose reaches (a 重 more, a 快 less); where a feint
## draws back to; a beast's leap as a share of the model's `pounce` height.
const SWING_REACH: Dictionary[StringName, float] = {&"feint": 0.55, &"guard": 0.6}
const SWING_POWER: Dictionary[StringName, float] = {&"heavy": 1.15, &"quick": 0.9}
const FEINT_DRAW: float = -0.25
const HEAVY_POUNCE: float = 1.5
const POUNCE_PITCH: float = 0.28
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
var _tweens: Dictionary[StringName, Tween] = {}
## 战斗拍数 E: 失衡's reel and 露空's stumble, apart from the blow's own show (rotation:z, a lean).
var _side_tweens: Dictionary[StringName, Tween] = {}
var _wound_up: Dictionary[StringName, bool] = {}
## 战斗肢体: who stands on guard and with what (the weapon's skill, "" bare-handed), and each
## figure's limbs in a blow or an answer (apart from its step: easing home does not stop them).
var _guards: Dictionary[StringName, String] = {}
## 战斗特效: a chip is in the air this many times the dust's time.
const CHIP_FLIGHT: float = 1.4
## 战斗特效: how many dark chips fly with the others off one hit (the controller sets it by the
## fight's look; 0 none), the fight's base (the controller hands it over; null: none laid), and
## the blow being shown now: the colour of its light, whom it is struck at and how it ended
## (_swing() binds them into the blow's own show as it is laid out).
var blood_chips: int = 0
var stage: BattleArena
var _blow_colour: Color = Color.WHITE
var _blow_target: StringName = &""
var _blow_outcome: int = -1
## Whose fall the show has let go already this fight (its felling blow was told), and the falls
## still waiting on their blow to land.
var _felled: Dictionary[StringName, bool] = {}
var _fall_tweens: Array[Tween] = []
## Whose felling blow is told and has yet to land: they stand until it does.
var _falling: Dictionary[StringName, bool] = {}
var _limb_tweens: Dictionary[StringName, Tween] = {}
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
	for tween: Tween in _side_tweens.values():
		if tween.is_valid():
			tween.kill()
	for id: StringName in _side_tweens.keys():
		var reeled: Node3D = _model(id)
		if reeled != null:
			reeled.rotation.z = 0.0
	_side_tweens.clear()
	for tween: Tween in _limb_tweens.values():
		if tween.is_valid():
			tween.kill()
	_limb_tweens.clear()
	for id: StringName in _guards.keys():
		var person: Person = _model(id) as Person
		if person != null:
			person.stand_down(_seconds(_feel().scene_return_seconds))
	_guards.clear()
	for tween: Tween in _fall_tweens:
		if tween.is_valid():
			tween.kill()
	_fall_tweens.clear()
	_falling.clear()
	_felled.clear()
	stage = null
	if view != null and is_instance_valid(view):
		view.release_falls()
	for id: StringName in _rest.keys():
		var model: Node3D = _model(id)
		if model != null:
			model.position = Vector3.ZERO
			model.scale = Vector3.ONE
			model.rotation.x = 0.0
			model.rotation.z = 0.0
			_unflash(model)
	_rest.clear()
	_knock.clear()
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


## Where the fighters stand: `stances` is [id, target_id, close, weapon skill] each (the
## projection; the weapon may be left out: bare-handed); a figure close to its target stands
## CLOSE_STANCE nearer it. One not in a show eases there. 战斗肢体: each stands on guard with that
## weapon in its hand; one no longer listed (it walked out of the fight) stands down.
func settle(stances: Array) -> void:
	if view == null:
		return
	var seconds: float = _seconds(_feel().scene_return_seconds)
	var listed: Dictionary[StringName, bool] = {}
	for stance: Array in stances:
		var id: StringName = stance[0]
		var model: Node3D = _model(id)
		if model == null:
			continue
		listed[id] = true
		if _feel().fall_seconds > 0.0 and not _felled.has(id):
			view.hold_fall(id)
		var person: Person = model as Person
		if person != null:
			var weapon: String = String(stance[3]) if stance.size() > 3 else ""
			if _guards.get(id) != weapon or not person.fighting:
				person.take_guard(weapon, seconds)
			_guards[id] = weapon
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
	for id: StringName in _guards.keys():
		if not listed.has(id):
			_guards.erase(id)
			var gone: Person = _model(id) as Person
			if gone != null:
				gone.stand_down(seconds)


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
	_charge(model, seconds)
	_raise(actor_id, model, TEMPLATE_HEAVY, seconds * 0.5)
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
	if line.cue == BattleNarrationLine.CUE_STAGGER:
		_staggered(line.actor_id)
		return
	if line.cue == BattleNarrationLine.CUE_EXPOSED:
		_exposed(line.actor_id, line.target_id)
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
	if template == TEMPLATE_HEAVY:
		stop *= HEAVY_STOP
	played.append([line.actor_id, template, line.outcome, stop > 0.0])
	if played.size() > 64:
		played.pop_front()
	_blow_colour = trail_colour(line)
	_blow_target = line.target_id
	_blow_outcome = line.outcome
	# How far the one struck at is from where the striker stands (not from where a blow just
	# before left it: a beast still coming back leaps from its place all the same).
	var stand: Vector3 = me.global_position - me.position + _stand(line.actor_id)
	var apart: float = 0.0 if you == null else Vector2(you.global_position.x - stand.x, you.global_position.z - stand.z).length()
	var impact: float = _attack(line.actor_id, me, direction, template, stop, line.in_special, motion_of(line.weapon_skill, template), apart)
	if you != null and not line.target_id.is_empty():
		_defend(line.target_id, you, direction, line, impact, stop)
	if fatal and not line.target_id.is_empty():
		# The one felled falls as the blow lands (after its freeze), dust rising where it comes down.
		var fall: Tween = create_tween()
		_fall_tweens = _fall_tweens.filter(func(tween: Tween) -> bool: return tween.is_valid() and tween.is_running())
		_fall_tweens.append(fall)
		_falling[line.target_id] = true
		fall.tween_interval(maxf(impact, 0.001))
		fall.tween_callback(_flare_stage)
		fall.tween_interval(maxf(stop, 0.001))
		fall.tween_callback(_fell.bind(line.target_id))
		var landing: float = _feel().fall_seconds * 0.8
		if landing > 0.0 and _seconds(_feel().scene_dust_seconds) > 0.0:
			fall.tween_interval(landing)
			fall.tween_callback(_dust_of.bind(line.target_id, 2.0))
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


## 战斗肢体: the motion a blow with `weapon_skill` swings by (VoxelPerson.STRIKES): the weapon's
## own (battle_stage.json), or for a 重 with a weapon that cuts down, sideways or up, the
## two-handed blow from overhead.
static func motion_of(weapon_skill: StringName, template: StringName) -> String:
	var motion: String = String(BattleSounds.weapon_look(weapon_skill).get("motion", "fist"))
	if template == TEMPLATE_HEAVY and motion in ["slam", "slash", "rise"]:
		return "heavy"
	return motion


## The attacker's step by `template`; returns when its blow lands (seconds from now). 战斗肢体:
## its arm swings by `motion` with the step; a beast leaps.
func _attack(id: StringName, model: Node3D, direction: Vector3, template: StringName, stop: float, special: bool, motion: String = "fist", apart: float = 0.0) -> float:
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
	var pounce: float = float(model.get_meta("pounce", 0.0))
	# Where a beast's leap comes down (INF: no leap).
	var landing := Vector3.INF
	var wound: bool = _wound_up.get(id, false)
	var lead_in: float = 0.0
	match template:
		TEMPLATE_QUICK:
			_ghost(model)
			if pounce > 0.0:
				landing = home + direction * _beast_reach(STEP_QUICK, apart)
				_leap(tween, model, landing, step, pounce * 0.6)
				impact = step
			else:
				tween.tween_property(model, "position", home + direction * STEP_QUICK, step * QUICK_LUNGE).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
				impact = step * QUICK_LUNGE
		TEMPLATE_HEAVY:
			if not wound and windup_seconds > 0.0:
				lead_in = windup_seconds
				_charge(model, windup_seconds)
				_together(tween).tween_property(model, "scale:y", CROUCH, windup_seconds * 0.5).set_ease(Tween.EASE_OUT)
				tween.tween_property(model, "rotation:x", LEAN * 0.5, windup_seconds * 0.5).set_ease(Tween.EASE_OUT)
				tween.set_parallel(false)
				tween.tween_interval(windup_seconds * 0.5)
				impact += windup_seconds
			if pounce > 0.0:
				_together(tween).tween_property(model, "scale:y", 1.0, step * 1.3)
				landing = home + direction * _beast_reach(STEP_HEAVY, apart)
				_leap(tween, model, landing, step * 1.3, pounce * HEAVY_POUNCE)
			else:
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
			if pounce > 0.0:
				landing = home + direction * _beast_reach(reach, apart)
				_leap(tween, model, landing, step, pounce)
			else:
				tween.tween_property(model, "position", home + direction * reach, step).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
			impact = step
	_wound_up.erase(id)
	_swing(id, model, motion, template, wound, lead_in, impact - lead_in, stop, back)
	if stop > 0.0:
		# The hit-stop: held at the lunge's end, a 2 px shake across it.
		var struck: Vector3 = landing if landing.is_finite() else home + direction * (STEP_HEAVY if template == TEMPLATE_HEAVY else STEP_PLAIN)
		for shake: int in 2:
			tween.tween_property(model, "position", struck + side * SHAKE, stop * 0.25)
			tween.tween_property(model, "position", struck - side * SHAKE, stop * 0.25)
		tween.tween_property(model, "position", struck, 0.0)
	if template == TEMPLATE_QUICK:
		back *= 0.6 # 快 is back on guard at once.
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
	_answer(id, model, line.outcome, impact, stop, step, back)
	var tween: Tween = _tween(id)
	if impact > 0.0:
		tween.tween_interval(impact)
	match line.outcome:
		CombatAttackResult.Outcome.HIT:
			var colour: Color = FLASH_COUNTER if line.ring > 0 else FLASH_COUNTERED if line.ring < 0 else FLASH_HIT
			var heavy: bool = template_of(line.tag) == TEMPLATE_HEAVY
			tween.tween_callback(_flash.bind(model, colour, flash_seconds * (2.0 if heavy else 1.0)))
			tween.tween_callback(_dust.bind(model, 2.0 if heavy else 1.0))
			tween.tween_callback(_chips.bind(id, direction, heavy))
			if stop > 0.0:
				tween.tween_callback(_jolt_stage.bind(id, heavy))
			var knocked: Vector3 = _knock.get(id, Vector3.ZERO) + direction * KNOCKBACK.get(line.ring, KNOCKBACK[0]) * (HEAVY_KNOCK if heavy else 1.0)
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
	_raise(actor_id, model, TEMPLATE_PLAIN, windup_seconds * 0.5)
	_flare_stage()
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


## 战斗拍数 E: 失衡 — the one a 重 landed on reels side to side in a dull red, after the blow's
## freeze and recoil (the note comes the frame after the blow's line).
func _staggered(actor_id: StringName) -> void:
	var model: Node3D = _model(actor_id)
	var seconds: float = _seconds(_feel().scene_return_seconds)
	if model == null or seconds <= 0.0:
		return
	var tween: Tween = _side_tween(actor_id)
	tween.tween_interval(_seconds(_feel().hit_stop_seconds) * HEAVY_STOP + _seconds(_feel().scene_step_seconds))
	tween.tween_callback(_flash.bind(model, FLASH_STAGGER, seconds * 1.2))
	for sway: float in [REEL, -REEL * 0.8, REEL * 0.5, 0.0]:
		tween.tween_property(model, "rotation:z", sway, seconds * 0.3).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)


## 战斗拍数 E: 露空 — the striker whose 重 missed lurches on past where it meant to land, in a
## cold flash, and rights itself.
func _exposed(actor_id: StringName, _target_id: StringName) -> void:
	var model: Node3D = _model(actor_id)
	var seconds: float = _seconds(_feel().scene_return_seconds)
	if model == null or seconds <= 0.0:
		return
	var tween: Tween = _side_tween(actor_id)
	tween.tween_interval(_seconds(_feel().scene_step_seconds) * 1.3)
	tween.tween_callback(_flash.bind(model, FLASH_EXPOSED, seconds * 0.8))
	tween.tween_property(model, "rotation:z", -REEL * 0.6, seconds * 0.25).set_ease(Tween.EASE_OUT)
	tween.tween_property(model, "rotation:z", REEL * 0.3, seconds * 0.3).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(model, "rotation:z", 0.0, seconds * 0.3).set_ease(Tween.EASE_IN_OUT)


func _side_tween(id: StringName) -> Tween:
	var old: Tween = _side_tweens.get(id)
	if old != null and old.is_valid():
		old.kill()
	var tween: Tween = create_tween()
	_side_tweens[id] = tween
	return tween


## Whether `id` reels or lurches now (tests).
func side_running(id: StringName) -> bool:
	var tween: Tween = _side_tweens.get(id)
	return tween != null and tween.is_valid() and tween.is_running()


## Whether the first beat won this fight had its whole ceremony already (the sounds follow).
func earned_shown() -> bool:
	return _earned_shown


# --- 战斗肢体: the fall and the limbs -------------------------------------------------------------


## The fight's lines are all told (`told`) or some still wait: told, whoever fell without a
## felling blow of its own being told (a poison, a blow the strip folded away) falls now; one
## whose felling blow is told and still on its way waits for it to land.
func lines_told(told: bool) -> void:
	if told and view != null and is_instance_valid(view):
		for id: StringName in view.release_fallen(_falling):
			_felled[id] = true


## `id`'s felling blow has landed: its figure falls.
func _fell(id: StringName) -> void:
	_falling.erase(id)
	_felled[id] = true
	if view != null and is_instance_valid(view):
		view.release_fall(id)


func _dust_of(id: StringName, amount: float) -> void:
	var model: Node3D = _model(id)
	if model != null:
		_dust(model, amount)


## The arm goes up before the blow (a 重's half beat, a special's opening line): wound up within
## `seconds`, by the motion of the weapon the figure stands on guard with.
func _raise(id: StringName, model: Node3D, template: StringName, seconds: float) -> void:
	var person: Person = model as Person
	if person == null or seconds <= 0.0:
		return
	person.begin_strike(motion_of(StringName(_guards.get(id, "")), template), SWING_POWER.get(template, 1.0))
	_limb(id).tween_property(person, "swing", -1.0, seconds).set_ease(Tween.EASE_OUT)


## The blow's swing: wound up (over `lead_in`, or at once when the figure is `wound` up already or
## the blow has no windup of its own: the travel is what is seen), through within `strike`, held
## over the hit-stop and a moment more, back on guard within `back`.
func _swing(id: StringName, model: Node3D, motion: String, template: StringName, wound: bool, lead_in: float, strike: float, stop: float, back: float) -> void:
	var person: Person = model as Person
	if person == null or strike <= 0.0:
		return
	# Wound up already (a 重's half beat, a special's opening): the hand that is up strikes.
	person.begin_strike(motion, SWING_POWER.get(template, 1.0), wound and person.swing < 0.0)
	var tween: Tween = _limb(id)
	if lead_in > 0.0:
		tween.tween_property(person, "swing", -1.0, lead_in * 0.5).set_ease(Tween.EASE_OUT)
		tween.tween_interval(lead_in * 0.5)
	elif not wound or person.swing > -1.0:
		person.swing = -1.0
	# 战斗特效: as the blow sets off its edge leaves its light; what is thrown leaves the hand.
	if motion == "thrown":
		tween.tween_callback(_throw.bind(id, _blow_target, _blow_outcome, strike))
	else:
		tween.tween_callback(_trail.bind(id, strike, _blow_colour))
	tween.tween_property(person, "swing", float(SWING_REACH.get(template, 1.0)), strike).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.tween_interval(stop + _seconds(_feel().scene_step_seconds))
	if template == TEMPLATE_FEINT:
		tween.tween_property(person, "swing", FEINT_DRAW, back * 0.3).set_ease(Tween.EASE_OUT)
	tween.tween_property(person, "swing", 0.0, back).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)


## The one struck at answers with its limbs at `impact`: thrown open by a hit (held over the
## hit-stop), leaning out of a miss, the weapon across for a parry (up a little before the blow).
func _answer(id: StringName, model: Node3D, outcome: int, impact: float, stop: float, step: float, back: float) -> void:
	var person: Person = model as Person
	if person == null or back <= 0.0:
		return
	var tween: Tween = _limb(id)
	person.swing = 0.0
	match outcome:
		CombatAttackResult.Outcome.HIT:
			tween.tween_interval(impact)
			tween.tween_callback(_react.bind(id, "hit", 1.0))
			tween.tween_interval(stop + step)
			tween.tween_property(person, "react_amount", 0.0, back).set_ease(Tween.EASE_OUT)
		CombatAttackResult.Outcome.DODGE:
			tween.tween_interval(impact)
			tween.tween_callback(_react.bind(id, "dodge", 0.0))
			tween.tween_property(person, "react_amount", 1.0, step * 0.5).set_ease(Tween.EASE_OUT)
			tween.tween_property(person, "react_amount", 0.0, back * 0.5).set_ease(Tween.EASE_IN_OUT)
		CombatAttackResult.Outcome.PARRY:
			tween.tween_interval(impact * 0.5)
			tween.tween_callback(_react.bind(id, "parry", 0.0))
			tween.tween_property(person, "react_amount", 1.0, impact * 0.5).set_ease(Tween.EASE_OUT)
			tween.tween_interval(stop + step * 0.5)
			tween.tween_property(person, "react_amount", 0.0, back * 0.6).set_ease(Tween.EASE_IN_OUT)
		_:
			tween.tween_interval(impact)


## `id`'s figure answers a blow now (the figure may be gone by then).
func _react(id: StringName, kind: String, amount: float) -> void:
	var person: Person = _model(id) as Person
	if person != null:
		person.swing = 0.0
		person.react = kind
		person.react_amount = amount


## A new show for `id`'s limbs (the one before it stops where it is).
func _limb(id: StringName) -> Tween:
	var old: Tween = _limb_tweens.get(id)
	if old != null and old.is_valid():
		old.kill()
	var tween: Tween = create_tween()
	_limb_tweens[id] = tween
	return tween


## Whether `id`'s limbs are in a blow or an answer now (tests).
func limbs_running(id: StringName) -> bool:
	var tween: Tween = _limb_tweens.get(id)
	return tween != null and tween.is_valid() and tween.is_running()


## A beast's leap to `to` within `seconds`: an arc `height` high from where it is, nose up as it
## leaves the ground and down as it lands.
func _leap(tween: Tween, model: Node3D, to: Vector3, seconds: float, height: float) -> void:
	tween.tween_method(_leap_step.bind(model, [], to, height), 0.0, 1.0, seconds)


## One moment `t` (0..1) of a leap (`model` may be gone by then; `from` holds where it began).
func _leap_step(t: float, model: Variant, from: Array, to: Vector3, height: float) -> void:
	if not is_instance_valid(model):
		return
	var beast: Node3D = model
	if from.is_empty():
		from.append(beast.position)
	beast.position = (from[0] as Vector3).lerp(to, t) + Vector3.UP * height * sin(t * PI)
	beast.rotation.x = lerpf(-POUNCE_PITCH, POUNCE_PITCH, t)


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
## back by this round (战斗演出 D: the stage's place is the actor node's, not the model's).
func _stand(id: StringName) -> Vector3:
	return _rest.get(id, Vector3.ZERO) + _knock.get(id, Vector3.ZERO)


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
	if overlay != null and (not model.has_meta("battle_flash") or model.get_meta("battle_flash") != overlay):
		return # A newer flash took over (or the show ended and took it off).
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
	pale.render_priority = VoxelBackdrop.OVER_BACKDROP
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
func _dust(model: Node3D, amount: float = 1.0) -> void:
	var seconds: float = _seconds(_feel().scene_dust_seconds) * sqrt(amount)
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
	for index: int in roundi(4.0 * amount):
		var mote := MeshInstance3D.new()
		mote.mesh = mesh
		mote.material_override = material
		mote.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var angle: float = _dust_rng.randf_range(0.0, TAU)
		var out := Vector3(cos(angle), 0.0, sin(angle))
		mote.position = out * 0.12 + Vector3.UP * 0.06
		puff.add_child(mote)
		tween.tween_property(mote, "position", out * 0.4 * amount + Vector3.UP * 0.25 * sqrt(amount), seconds).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tween.tween_property(mote, "scale", Vector3.ONE * 0.05, seconds).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(_drop_effect.bind(puff))


## 战斗拍数 E: the 气 gathering before a 重 — a warm glow over the figure the crouch long, and
## eight motes drawn in from a ring round it to its chest, brightening as they come.
func _charge(model: Node3D, seconds: float) -> void:
	if seconds <= 0.0 or not is_instance_valid(model) or model.get_parent() == null:
		return
	_flash(model, FLASH_CHARGE, seconds)
	var gather := Node3D.new()
	gather.name = "Charge"
	gather.position = model.position
	model.get_parent().add_child(gather)
	_effects.append(gather)
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE * 0.09
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.albedo_color = Color(CHARGE_MOTE, 0.25)
	glow.render_priority = VoxelBackdrop.OVER_BACKDROP
	var tween: Tween = create_tween().set_parallel(true)
	_effect_tweens[gather] = tween
	var chest := Vector3.UP * 1.0
	for index: int in 8:
		var mote := MeshInstance3D.new()
		mote.mesh = mesh
		mote.material_override = glow
		mote.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var angle: float = TAU * float(index) / 8.0 + _dust_rng.randf_range(-0.2, 0.2)
		mote.position = Vector3(cos(angle) * 0.75, _dust_rng.randf_range(0.3, 1.6), sin(angle) * 0.75)
		gather.add_child(mote)
		tween.tween_property(mote, "position", chest, seconds).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		tween.tween_property(mote, "scale", Vector3.ONE * 0.4, seconds).set_ease(Tween.EASE_IN)
	tween.tween_property(glow, "albedo_color:a", 0.95, seconds * 0.8)
	tween.chain().tween_callback(_drop_effect.bind(gather))


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
	glow.render_priority = VoxelBackdrop.OVER_BACKDROP
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


# --- 战斗特效: the light of a swing, what is thrown, the chips, the base -------------------------


static func _impact(key: String) -> Dictionary:
	var block: Variant = BattleArena.data().get("impact", {}).get(key, {})
	return block if block is Dictionary else {}


## The colour of the light a blow's weapon leaves: a special's gold, else by the wound it deals
## (battle_stage.json moves.colours), else the plain one.
static func trail_colour(line: BattleNarrationLine) -> Color:
	var trail: Dictionary = _impact("trail")
	var hex: String = String(trail.get("plain", "f4f1e6"))
	if line.in_special:
		hex = String(trail.get("special", hex))
	else:
		hex = String(BattleArena.data().get("moves", {}).get("colours", {}).get(line.damage_type, hex))
	return Color(Color(hex), float(trail.get("alpha", 0.6)))


## How many dark chips fly off one hit in a fight of `mode` (battle_stage.json impact.blood by
## the fight's look: none in a 切磋 or a 拆招).
static func blood_for(mode: int) -> int:
	return int(_impact("blood").get(BattleArena.look_for(mode), 0))


## How far a beast leaps at one `apart` away: to within the gap of it, never short of the
## step a blow takes anyway (`step`) nor past its reach.
static func _beast_reach(step: float, apart: float) -> float:
	var beast: Dictionary = _impact("beast")
	return maxf(step, minf(apart - float(beast.get("gap", 0.85)), float(beast.get("reach", 2.4))))


## `id`'s weapon leaves its light for the `seconds` its blow travels (nothing for a bare hand).
func _trail(id: StringName, seconds: float, colour: Color) -> void:
	var person: Person = _model(id) as Person
	var fade: float = _seconds(_feel().afterimage_seconds)
	if person == null or fade <= 0.0 or seconds <= 0.0 or person.get_parent() == null:
		return
	var edge: Array = person.strike_edge()
	if edge.is_empty():
		return
	var trail := BattleSwingTrail.new()
	trail.name = "SwingTrail"
	trail.source = edge[0]
	# The outer part of the edge: a band of light, not a filled fan.
	trail.from = (edge[1] as Vector3).lerp(edge[2], float(_impact("trail").get("inner", 0.5)))
	trail.to = edge[2]
	trail.colour = colour
	trail.sampling = seconds
	trail.fade = fade
	person.get_parent().add_child(trail)
	_effects.append(trail)
	var tween: Tween = create_tween()
	_effect_tweens[trail] = tween
	tween.tween_interval(seconds + fade + 0.05)
	tween.tween_callback(_drop_effect.bind(trail))


## What `id` throws flies from its hand to `target_id`'s chest within `seconds` (the blow's
## travel): gone as it hits, on past one who dodged, spun up and away off a parry.
func _throw(id: StringName, target_id: StringName, outcome: int, seconds: float) -> void:
	var me: Node3D = _model(id)
	var you: Node3D = _model(target_id)
	if me == null or me.get_parent() == null or seconds <= 0.0:
		return
	var thrown: Dictionary = _impact("thrown")
	var from: Vector3 = (me as Person).striking_hand() if me is Person else me.global_position + Vector3.UP
	var to: Vector3 = you.global_position + Vector3.UP * (1.0 if you is Person else 0.45) if you != null else from + _direction(me, null) * 2.0
	var way: Vector3 = (to - from).normalized() if to.distance_squared_to(from) > 0.0001 else Vector3.FORWARD
	var dart := Node3D.new()
	dart.name = "Thrown"
	dart.top_level = true
	me.get_parent().add_child(dart)
	dart.global_position = from
	if absf(way.dot(Vector3.UP)) < 0.99:
		dart.look_at(from + way, Vector3.UP)
	_effects.append(dart)
	var length: float = float(thrown.get("length", 0.24))
	for part: Array in [[Vector3(0.035, 0.035, length), Vector3.ZERO, Color("d8dce0")], [Vector3(0.06, 0.06, 0.05), Vector3(0, 0, length * 0.5), Color("a8322a")]]:
		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = part[0]
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = part[2]
		material.render_priority = VoxelBackdrop.OVER_BACKDROP
		box.material = material
		mesh.mesh = box
		mesh.position = part[1]
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		dart.add_child(mesh)
	var tween: Tween = create_tween()
	_effect_tweens[dart] = tween
	tween.tween_property(dart, "global_position", to, seconds)
	match outcome:
		CombatAttackResult.Outcome.DODGE:
			_together(tween).tween_property(dart, "global_position", to + way * float(thrown.get("past", 1.6)), seconds * 0.8)
			tween.tween_property(dart, "scale", Vector3.ONE * 0.05, seconds * 0.8).set_ease(Tween.EASE_IN)
			tween.set_parallel(false)
		CombatAttackResult.Outcome.PARRY:
			_together(tween).tween_property(dart, "global_position", to + Vector3.UP * 1.1 - way * 0.6, seconds * 1.6).set_ease(Tween.EASE_OUT)
			tween.tween_property(dart, "rotation:x", dart.rotation.x + TAU * 1.5, seconds * 1.6)
			tween.tween_property(dart, "scale", Vector3.ONE * 0.05, seconds * 1.6).set_ease(Tween.EASE_IN)
			tween.set_parallel(false)
	tween.tween_callback(_drop_effect.bind(dart))


## Chips fly off `id` as it is hit, on the blow's way (`direction`) and up, and fall: the
## colours of its coat (a beast's: the plain one), `blood_chips` dark ones among them; more for a 重.
func _chips(id: StringName, direction: Vector3, heavy: bool) -> void:
	var model: Node3D = _model(id)
	var data: Dictionary = _impact("chips")
	var seconds: float = _seconds(_feel().scene_dust_seconds) * CHIP_FLIGHT
	var count: int = int(data.get("heavy_count" if heavy else "count", 5))
	if model == null or model.get_parent() == null or seconds <= 0.0 or count + blood_chips <= 0:
		return
	var burst := Node3D.new()
	burst.name = "Chips"
	burst.position = model.position + Vector3.UP * (1.0 if model is Person else 0.45)
	model.get_parent().add_child(burst)
	_effects.append(burst)
	var shades: Array[Color] = []
	var cloth := Color(String(data.get("plain", "b8a080")))
	if model is Person and Color.html_is_valid((model as Person).coat):
		cloth = Color((model as Person).coat)
	for index: int in count:
		shades.append(cloth.lightened(0.3) if index % 2 == 1 else cloth)
	var blood: Array = _impact("blood").get("colours", ["b3261e"])
	for index: int in blood_chips:
		shades.append(Color(String(blood[index % blood.size()])))
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE * float(data.get("size", 0.1))
	var side := Vector3(-direction.z, 0.0, direction.x)
	var gravity: float = float(data.get("gravity", 14.0))
	var floor_y: float = 0.04 - burst.position.y
	var tween: Tween = create_tween().set_parallel(true)
	_effect_tweens[burst] = tween
	# Each chip's flight: [the chip, the way it flies, how it spins].
	var flights: Array[Array] = []
	for shade: Color in shades:
		var chip := MeshInstance3D.new()
		chip.mesh = mesh
		var material := StandardMaterial3D.new()
		material.albedo_color = shade
		material.roughness = 1.0
		chip.material_override = material
		chip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		burst.add_child(chip)
		var velocity: Vector3 = (
			direction * float(data.get("speed", 2.4)) * _dust_rng.randf_range(0.35, 1.0)
			+ side * float(data.get("spread", 0.9)) * _dust_rng.randf_range(-1.0, 1.0)
			+ Vector3.UP * float(data.get("rise", 2.0)) * _dust_rng.randf_range(0.45, 1.0)
		)
		flights.append([chip, velocity, Vector3(_dust_rng.randf_range(-9.0, 9.0), _dust_rng.randf_range(-9.0, 9.0), 0.0)])
		tween.tween_property(chip, "scale", Vector3.ONE * 0.25, seconds).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.tween_method(_fly_chips.bind(burst, flights, gravity, floor_y), 0.0, seconds, seconds)
	tween.chain().tween_callback(_drop_effect.bind(burst))


## The chips of `burst` `t` seconds into their flight (the burst may be gone with the one it
## flew off): each on its way, pulled down, never under the ground, turning as it goes.
func _fly_chips(t: float, burst: Variant, flights: Array, gravity: float, floor_y: float) -> void:
	if not is_instance_valid(burst):
		return
	for flight: Array in flights:
		var chip: Node3D = flight[0]
		var at: Vector3 = (flight[1] as Vector3) * t + Vector3.DOWN * 0.5 * gravity * t * t
		at.y = maxf(at.y, floor_y)
		chip.position = at
		chip.rotation = (flight[2] as Vector3) * t


## The fight's base, when one is laid (`stage`: the controller hands over the opening's).
func _stage() -> BattleArena:
	return stage if stage != null and is_instance_valid(stage) and stage.is_inside_tree() else null


## The base's bricks hop round `id` as a blow with weight lands on it (a 重: higher).
func _jolt_stage(id: StringName, heavy: bool) -> void:
	var base: BattleArena = _stage()
	var model: Node3D = _model(id)
	var seconds: float = _seconds(_feel().scene_dust_seconds)
	if base == null or model == null or seconds <= 0.0:
		return
	var data: Dictionary = _impact("stage")
	base.jolt(base.to_local(model.global_position), float(data.get("jolt_radius", 1.5)), float(data.get("jolt_height", 0.12)) * (float(data.get("heavy_jolt", 1.7)) if heavy else 1.0), seconds)


## The base's braziers leap and its flags snap (a special's opening, a felling blow).
func _flare_stage() -> void:
	var base: BattleArena = _stage()
	var seconds: float = _seconds(_feel().scene_windup_seconds) * 2.0
	if base != null and seconds > 0.0:
		base.flare(float(_impact("stage").get("flare", 1.3)), seconds)


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
