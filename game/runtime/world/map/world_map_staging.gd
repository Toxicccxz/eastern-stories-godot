class_name WorldMapStaging
extends RefCounted
## 过场动作 (过场演出 B; DECISIONS「过场动作」): what a scene's steps show besides their words
## (SceneCue: `do`, `shot`, `fx`) — who walks where, who bows, kneels, draws, hands a thing over,
## how the camera frames it — timed with the page the player reads.
##
## The rules are WorldMapActs': a step is settled as ever when its act runs. This only decides
## when each thing is *shown*, and moves the bodies a walk moves (the 2D map's positions:
## collision, reach and the save follow them); the poses, the flying thing, the camera and the
## 主线场面 are told to the view (figure state, flights(), shot_*(), take_fx()), which draws them.
## - A line's own cue begins as its page shows in the dialogue box; a cue on another step begins
##   once the lines told before it in its act have been read (at once when there were none).
## - One press takes the page on, and every action under way is where it ends (finish()): nobody
##   stops half-way. Going on by itself, the box waits for them (left_seconds()).
## - Actions still under way when the box has closed hold the world as a page does (HOLD): no call
##   comes due, nobody attacks, the player stands; then the scene's next call comes at once.
## - A `leave` whose cue walks out or dissolves leaves when that has been shown; `comes` with an
##   `enter` walks in from its door; a `summon` or `comes` with `emerge` is unseen until it rises.
## - When the scene is over everyone who walked is back where it stood (walking back, or put back
##   at once when the scene was cut short), unless its walk said `stay`; every pose is let go.
## - Cut short (a fight, the player down or off the map, the box shut unread): settle() — what is
##   under way is at its end, what had not begun is not shown, and whoever was to leave has left.
## Off (SceneStage.on() false: the feel's scene_action_ms 0, the suites) nothing here is asked
## and every step is as it was. Not saved: a scene is not saved half-way.

## The hold while actions play on with no page open.
const HOLD: StringName = &"staging"
## The holds under which the actions play on: the dialogue box's own (WorldDialogueBox.HOLD: a page
## is being read) and this one. Any other hold (the menu, a card, a fade) stops them where they are.
const PLAYING_HOLDS: Array[StringName] = [&"dialogue", HOLD]
## A walk beside someone ends this far from them (tried in order).
const BESIDE: Array[int] = [44, 64, 96]

const POSE_BOW: StringName = &"bow"
const POSE_KNEEL: StringName = &"kneel"
const POSE_GUARD: StringName = &"guard"
const POSE_FALL: StringName = &"fall"
const POSE_REACH: StringName = &"reach"
const POSE_GIVE: StringName = &"give"
const POSE_CATCH: StringName = &"catch"
const POSE_SHIVER: StringName = &"shiver"


## One page of a scene (a line told): the dialogue box hands it back as the page shows and goes.
class Beat:
	extends RefCounted
	## Who says it (the camera's default, whom the player turns to); &"" nobody.
	var speaker_id: StringName = &""
	var room: StringName = &""
	## Shown with the page; begun as it is left.
	var own: Array[Bound] = []
	var after: Array[Bound] = []
	var shown: bool = false
	var left: bool = false


## A step's cue and whom the step is about, waiting to begin.
class Bound:
	extends RefCounted
	var cue: SceneCue
	## The step's own people: the speaker; who came, leaves or was summoned.
	var subject_ids: Array[StringName] = []
	var speaker_id: StringName = &""
	var room: StringName = &""
	## The subjects are gone for good once this has been shown (a `leave` that waited).
	var leaves: bool = false


## One action under way.
class Run:
	extends RefCounted
	var act: StringName = &""
	var id: StringName = &""
	var action: SceneCue.Action
	var room: StringName = &""
	var elapsed: float = 0.0
	var seconds: float = 0.0
	## A walk's way (walk, enter, exit); empty: timed.
	var path: PackedVector2Array = PackedVector2Array()
	var walks: bool = false
	## step_back: from and to.
	var from: Vector2 = Vector2.INF
	var to: Vector2 = Vector2.INF
	## hand / toss: who takes it.
	var other_id: StringName = &""
	var leaves: bool = false
	## rise: the pose it gets up from.
	var pose: StringName = &""

	func progress() -> float:
		return 1.0 if seconds <= 0.0 else clampf(elapsed / seconds, 0.0, 1.0)


var _map: WorldMapController
## Pages told and not yet left, oldest first.
var _beats: Array[Beat] = []
var _runs: Array[Run] = []
## Who waits to leave by a cue not yet shown: {character_id: true}.
var _leaving: Dictionary[StringName, bool] = {}
## Where each one who walked stood before ([position, facing]); they go back there.
var _homes: Dictionary[StringName, Array] = {}
## The pose each keeps (kneeling, on guard, lying, reaching, shivering) until told otherwise.
var _held: Dictionary[StringName, StringName] = {}
## Summoned or come and not yet risen: unseen.
var _unseen: Dictionary[StringName, bool] = {}
## Come and not yet walked in: where the rule put it (beside the player).
var _entering: Dictionary[StringName, Vector2] = {}
## Everyone this scene has directed: nothing else turns or moves them (WorldMapNpcIdle).
var _directed: Dictionary[StringName, bool] = {}
## How many times each has started (the view shows the hop as the count changes).
var _hops: Dictionary[StringName, int] = {}
## The shot in force (null: the camera follows whoever speaks) and whose page it is.
var _shot: SceneCue.Shot = null
var _shot_speaker_id: StringName = &""
var _shot_room: StringName = &""
## 主线场面 a step will play: the view keeps their own triggers quiet; and those due now.
var _fx_claimed: Dictionary[String, bool] = {}
var _fx_due: Array[String] = []
## What goes on once the actions after the last page are over (the HUD hurrying the next call).
var _then: Callable = Callable()
var _holding: bool = false
## Something of a scene was told or under way at the last frame (its end is told to the scene once).
var _told: bool = false


func _init(controller: WorldMapController) -> void:
	_map = controller


# --- what the act tells (WorldMapActs) ---


## Whether a scene's cues are shown now: the feel has them, a scene of this map is being told to
## a player who reads it in the dialogue box.
func directs() -> bool:
	var session: WorldSessionController = _map.session
	return (
		SceneStage.on() and session != null and session.active_map() == _map and _map.hud() != null
		and _map.npc_life.scene_running() and not _map.npc_life.teller.is_empty()
		and GameContent.catalog().pacing().feel.shows_dialogue_box()
	)


## A line of the scene `speaker` tells in `room`, with its step's `cue` (null: none): the page it
## will be read on.
func line(cue: SceneCue, speaker: NpcRuntimeState, room: StringName) -> Beat:
	var beat := Beat.new()
	beat.speaker_id = &"" if speaker == null else speaker.character_id
	beat.room = room
	if cue != null:
		beat.own.append(_bind(cue, [] if speaker == null else [speaker], speaker, room))
	_beats.append(beat)
	return beat


## The `cue` of a step that is no line, about `subjects` (who came, was summoned; else the act's
## NPC), `speaker` the act's NPC: shown once `beat` (the last line told before it; null: none)
## has been read, else now.
func after(cue: SceneCue, subjects: Array[NpcRuntimeState], speaker: NpcRuntimeState, room: StringName, beat: Beat) -> void:
	if cue == null:
		return
	var bound: Bound = _bind(cue, subjects, speaker, room)
	_prepare(bound)
	_queue(bound, beat)


## `npc` leaves for good by the step's `cue` (an exit, a dissolve) once that has been shown: until
## then it stands where it stood.
func leave_after(npc: NpcRuntimeState, cue: SceneCue, speaker: NpcRuntimeState, room: StringName, beat: Beat) -> void:
	var bound: Bound = _bind(cue, [npc], speaker, room)
	bound.leaves = true
	_leaving[npc.character_id] = true
	_queue(bound, beat)


func _bind(cue: SceneCue, subjects: Array, speaker: NpcRuntimeState, room: StringName) -> Bound:
	var bound := Bound.new()
	bound.cue = cue
	for subject: NpcRuntimeState in subjects:
		if subject != null:
			bound.subject_ids.append(subject.character_id)
			_directed[subject.character_id] = true
	bound.speaker_id = &"" if speaker == null else speaker.character_id
	bound.room = room
	if not cue.fx.is_empty():
		_fx_claimed[cue.fx] = true
	return bound


func _queue(bound: Bound, beat: Beat) -> void:
	if beat != null and not beat.left and _beats.has(beat):
		beat.after.append(bound)
	else:
		_begin(bound)


## What a cue needs before it begins: one that will rise is unseen until then; one that will walk
## in waits at its door.
func _prepare(bound: Bound) -> void:
	for action: SceneCue.Action in bound.cue.actions:
		if not action.who.is_empty():
			continue
		for id: StringName in bound.subject_ids:
			var body: WorldCharacterBody2D = _body(id)
			if body == null:
				continue
			if action.act == &"emerge":
				_unseen[id] = true
			elif action.act == &"enter":
				var from: Vector2 = _stand_near(_spot(action.place, bound.room))
				if from.is_finite():
					_entering[id] = body.global_position
					body.global_position = from
					body.placed()


# --- what the dialogue box tells (through the HUD) ---


## The page of `beat` shows: the camera and the player turn to who says it, its own cue begins.
func page_shown(beat: Beat) -> void:
	if beat == null or beat.shown or not _beats.has(beat):
		return
	beat.shown = true
	var speaker: NpcRuntimeState = null if beat.speaker_id.is_empty() else _map.npcs.find_resident_npc(beat.speaker_id)
	if speaker != null and speaker.exists_in_map:
		_map.npc_life.scene_look_at(speaker)
		var body: WorldCharacterBody2D = _body(beat.speaker_id)
		if body != null and _map.player_body != null:
			_map.player_body.face_toward(body.global_position)
	# A page without a shot of its own is framed as before (whoever speaks).
	_shot = null
	for bound: Bound in beat.own:
		_begin(bound)


## The page of `beat` goes (read, or taken on by a press): everything under way is at its end,
## and what waited for this line to be read begins.
func page_left(beat: Beat) -> void:
	if beat == null or beat.left or not _beats.has(beat):
		return
	page_shown(beat)
	beat.left = true
	_beats.erase(beat)
	finish()
	for bound: Bound in beat.after:
		_begin(bound)


## The dialogue box closed with its last page read: pages it never showed are gone through, and
## if actions are still under way `then` waits for them (true), the world held meanwhile. False:
## nothing to wait for (the caller goes on now).
func pages_read(then: Callable) -> bool:
	for beat: Beat in _beats.duplicate():
		page_left(beat)
	if _runs.is_empty():
		return false
	_then = then
	_hold(true)
	return true


## Seconds until every action under way is over (the page waits this long before it goes on by
## itself); 0: none is.
func left_seconds() -> float:
	var left: float = 0.0
	for run: Run in _runs:
		if run.walks:
			left = maxf(left, _way_left(run) / SceneStage.walk_speed())
		else:
			left = maxf(left, run.seconds - run.elapsed)
	return left


## Whether actions play on with no page open (the HUD's key takes them to their end).
func between() -> bool:
	return _holding


## Whether anything of a scene is still told or under way.
func busy() -> bool:
	return not _beats.is_empty() or not _runs.is_empty()


# --- the map's frame ---


func advance(delta: float) -> void:
	if busy() or _holding:
		_told = true
		_play(delta)
	# Nothing of the scene is told or under way any more: it may be over (its last line read, or
	# a fight took it), whether or not the world's time runs.
	if _told and not busy() and not _holding:
		_told = false
		_map.npc_life.scene_settled()


func _play(delta: float) -> void:
	if _cut_short():
		settle()
		return
	var session: WorldSessionController = _map.session
	if session.world_time_held_besides(PLAYING_HOLDS) or not is_finite(delta) or delta <= 0.0:
		return
	for run: Run in _runs.duplicate():
		if _runs.has(run):
			_advance_run(run, delta)
	# With no page open what is under way holds the world, as a page does; over, the scene goes on.
	if _beats.is_empty():
		if not _runs.is_empty():
			_hold(true)
		elif _holding:
			_go_on()


## A fight took the screen, the player fell or is on another map: the scene's picture is over.
func _cut_short() -> bool:
	var session: WorldSessionController = _map.session
	var player: WorldPlayerRuntimeState = _map.player_runtime()
	return (
		session == null or session.active_map() != _map or player == null
		or player.life_status != CharacterRuntimeLifeStatus.Value.ACTIVE
		or session.combat_encounter_coordinator().has_active_encounter()
	)


func _go_on() -> void:
	_hold(false)
	var then: Callable = _then
	_then = Callable()
	if not then.is_valid() or not bool(then.call()):
		_map.npc_life.hurry_scene()


func _hold(on: bool) -> void:
	if on == _holding:
		return
	_holding = on
	if _map.session != null:
		_map.session.hold_presentation(HOLD, on)


## Everything under way is where it ends, now (one press takes a line on; nobody stops half-way).
## With no page open the world it held is let go and the scene goes on.
func finish() -> void:
	for run: Run in _runs.duplicate():
		if _runs.has(run):
			_end_run(run, true)
	if _holding and _beats.is_empty() and _runs.is_empty():
		_go_on()


## The scene's picture is cut short: what is under way is at its end, what had not begun is not
## shown — but whoever was to leave has left, who came stands where the rule put it, who was
## summoned is seen.
func settle() -> void:
	# Cut short, nothing goes on by it: the hold is let go first.
	_then = Callable()
	_hold(false)
	finish()
	_beats.clear()
	for id: StringName in _leaving.keys():
		_gone(id)
	_leaving.clear()
	for id: StringName in _entering.keys():
		var body: WorldCharacterBody2D = _body(id)
		if body != null:
			body.global_position = _entering[id]
			body.placed()
	_entering.clear()
	_unseen.clear()
	_shot = null
	_fx_due.clear()
	_then = Callable()
	_hold(false)


## The scene is over (WorldMapNpcLife.end_scene()): every pose is let go and everyone who walked
## goes back where it stood — walking, or at once when the scene was cut short.
func close() -> void:
	var cut: bool = busy() or _cut_short()
	settle()
	for id: StringName in _homes.keys():
		var body: WorldCharacterBody2D = _body(id)
		var home: Array = _homes[id]
		var npc: NpcRuntimeState = _map.npcs.find_resident_npc(id)
		if body == null or npc == null or not npc.exists_in_map or npc.life_status != CharacterRuntimeLifeStatus.Value.ACTIVE:
			continue
		if cut or body.global_position.distance_to(home[0]) < 2.0 or not _map.npc_life.npc_walker().walk_across(id, body, home[0]):
			body.global_position = home[0]
			body.facing = home[1]
			body.queue_redraw()
	_homes.clear()
	for id: StringName in _directed:
		var body: WorldCharacterBody2D = _body(id)
		if body != null:
			body.facing_held = false
	if _map.player_body != null:
		_map.player_body.facing_held = false
	_held.clear()
	_directed.clear()
	_hops.clear()
	_fx_claimed.clear()


# --- what the view reads ---


## Whether the scene shows anything of its own now (the view asks the rest only then).
func shows() -> bool:
	return not _directed.is_empty() or not _unseen.is_empty() or not _runs.is_empty() or not _held.is_empty()


## Whether `id` is one the scene directs: nothing else turns it or sends it strolling.
func directed(id: StringName) -> bool:
	return _directed.has(id)


## Summoned or come and not yet risen: not seen.
func unseen(id: StringName) -> bool:
	return _unseen.has(id)


## How far `id` has risen out of the ground (1: it stands).
func emerged(id: StringName) -> float:
	if _unseen.has(id):
		return 0.0
	for run: Run in _runs:
		if run.id == id and run.act == &"emerge":
			return smoothstep(0.0, 1.0, run.progress())
	return 1.0


## How far `id` has thinned away (0: whole).
func dissolved(id: StringName) -> float:
	for run: Run in _runs:
		if run.id == id and run.act == &"dissolve":
			return run.progress()
	return 0.0


## The pose `id` is in by the scene (&"": none of its own) and how far into it (0..1).
func pose(id: StringName) -> StringName:
	return _pose(id)[0]


func pose_amount(id: StringName) -> float:
	return _pose(id)[1]


func shivers(id: StringName) -> bool:
	if _held.get(id, &"") == POSE_SHIVER:
		return true
	for run: Run in _runs:
		if run.id == id and run.act == &"shiver":
			return true
	return false


## How many times `id` has started in this scene.
func hops(id: StringName) -> int:
	return int(_hops.get(id, 0))


## The weapon `id` draws (its wielded weapon's skill; "" bare hands).
func weapon_of(id: StringName) -> String:
	var npc: NpcRuntimeState = _map.npcs.find_resident_npc(id)
	if npc != null:
		return String(npc.character_state.equipment.primary_weapon_skill_type())
	var player: WorldPlayerRuntimeState = _map.player_runtime()
	return String(player.state.equipment.primary_weapon_skill_type()) if player != null and player.character_id == id else ""


## The things in the air now: [from id, to id, item definition, word (hand / toss), how far 0..1].
func flights() -> Array[Array]:
	var flying: Array[Array] = []
	var look: Dictionary = SceneStage.part("flight")
	var from: float = float(look.get("from", 0.3))
	var to: float = float(look.get("to", 0.8))
	for run: Run in _runs:
		if run.act in [&"hand", &"toss"] and not run.other_id.is_empty():
			var t: float = run.progress()
			if t >= from and t < to:
				flying.append([run.id, run.other_id, run.action.item, run.act, (t - from) / maxf(0.001, to - from)])
	return flying


## The shot's frame now (&"": the camera follows whoever speaks).
func shot_frame() -> StringName:
	return &"" if _shot == null else _shot.frame


## What tells this shot from the last one ("": none): its frame, whose page it is, what it names.
func shot_key() -> String:
	return "" if _shot == null else "%s|%s|%s" % [_shot.frame, _shot_speaker_id, _shot.place]


## Where the shot looks (INF: at whoever speaks): the thing or spot looked at, the middle of the
## two framed, the room's middle.
func shot_anchor() -> Vector2:
	if _shot == null:
		return Vector2.INF
	match _shot.frame:
		&"look":
			return _spot(_shot.place, _shot_room)
		&"two":
			var points: PackedVector2Array = shot_points()
			return (points[0] + points[1]) / 2.0 if points.size() == 2 else Vector2.INF
		&"wide":
			var zone: WorldPhysicalZoneArea2D = _map.physical_zone(_shot_room)
			return zone.global_rect().get_center() if zone != null else Vector2.INF
	return Vector2.INF


## The two a `two` shot keeps in the picture (where they stand); empty otherwise.
func shot_points() -> PackedVector2Array:
	var points := PackedVector2Array()
	if _shot == null or _shot.frame != &"two":
		return points
	var speaker: WorldCharacterBody2D = _body(_shot_speaker_id)
	var other: Vector2 = _spot(_shot.place, _shot_room)
	if speaker != null and other.is_finite():
		points.append(speaker.global_position)
		points.append(other)
	return points


## The 主线场面 steps of this scene will play by name (their own triggers stay quiet).
func fx_claimed() -> Dictionary[String, bool]:
	return _fx_claimed


## The 主线场面 due now, taken (the view plays each once).
func take_fx() -> Array[String]:
	var due: Array[String] = _fx_due
	_fx_due = []
	return due


# --- the actions ---


func _begin(bound: Bound) -> void:
	if bound.cue.shot != null:
		_shot = bound.cue.shot
		_shot_speaker_id = bound.speaker_id
		_shot_room = bound.room
	if not bound.cue.fx.is_empty():
		_fx_due.append(bound.cue.fx)
	var left: Dictionary[StringName, bool] = {}
	for action: SceneCue.Action in bound.cue.actions:
		for id: StringName in _doers(action, bound):
			var run: Run = _start(action, id, bound)
			if run != null and run.leaves:
				left[id] = true
	# One who was to leave by a cue that names no way out of its own leaves as the cue begins.
	if bound.leaves:
		for id: StringName in bound.subject_ids:
			if not left.has(id):
				_leaving.erase(id)
				_gone(id)


func _doers(action: SceneCue.Action, bound: Bound) -> Array[StringName]:
	if action.who.is_empty():
		return bound.subject_ids
	var doers: Array[StringName] = []
	if action.who == SceneCue.PLAYER:
		if _map.player_runtime() != null:
			doers.append(_map.player_runtime().character_id)
	else:
		var npc: NpcRuntimeState = _map.npcs.first_npc_in_zone(action.who, bound.room, true)
		if npc != null:
			doers.append(npc.character_id)
	return doers


## `id` begins `action`; null when there is nothing to show (nobody there, no way).
func _start(action: SceneCue.Action, id: StringName, bound: Bound) -> Run:
	var body: WorldCharacterBody2D = _body(id)
	if body == null:
		return null
	_directed[id] = true
	# A new action lets go of what was only kept up (hands out, a shiver).
	if _held.get(id, &"") in [POSE_REACH, POSE_SHIVER]:
		_held.erase(id)
	var run := Run.new()
	run.act = action.act
	run.id = id
	run.action = action
	run.room = bound.room
	run.seconds = SceneStage.seconds(action.act)
	run.leaves = bound.leaves and SceneCue.LEAVING.has(action.act) and action.who.is_empty()
	var place: Vector2 = _spot(action.place, bound.room)
	match action.act:
		&"face":
			if place.is_finite():
				body.face_toward(place)
		&"bow", &"reach":
			if place.is_finite():
				body.face_toward(place)
		&"walk":
			var to: Vector2 = _beside(action.place, bound.room, place, body)
			if not _walk(run, body, to):
				return null
			if action.stay:
				_homes.erase(id)
		&"enter":
			var to: Vector2 = _entering.get(id, Vector2.INF)
			_entering.erase(id)
			if not to.is_finite() or not _walk(run, body, to, false):
				if to.is_finite():
					body.global_position = to
					body.placed()
				return null
		&"exit":
			if not _walk(run, body, place, false):
				# No way there: it is gone where it stands.
				_leaving.erase(id)
				_gone(id)
				return null
		&"emerge":
			_unseen.erase(id)
		&"rise":
			run.pose = _held.get(id, &"")
			if not run.pose in [POSE_KNEEL, POSE_FALL]:
				return null
		&"sheathe":
			if _held.get(id, &"") != POSE_GUARD:
				return null
			_held.erase(id)
		&"startle":
			_hops[id] = int(_hops.get(id, 0)) + 1
		&"hand", &"toss":
			run.other_id = _person(action.place, bound.room)
			var other: WorldCharacterBody2D = _body(run.other_id)
			if other == null:
				return null
			_directed[run.other_id] = true
		&"step_back":
			var away: Vector2 = place
			if not away.is_finite():
				var facing: Node2D = _map.npc_life.scene_focus_body() if id == _player_id() else _map.player_body
				away = facing.global_position if facing != null else Vector2.INF
			var back: Vector2 = (body.global_position - away).normalized() if away.is_finite() else -body.facing
			if back == Vector2.ZERO:
				back = -body.facing
			run.from = body.global_position
			run.to = body.global_position + back * SceneStage.step_back_px()
			if not MapPlacementValidator.is_valid_character_position(_map, _zone_of(id), run.to):
				run.to = run.from
			elif id != _player_id():
				_remember_home(id, body)
			# It steps back looking where it looked.
			if away.is_finite():
				body.face_toward(away)
			body.facing_held = true
	if run.seconds <= 0.0 and not run.walks:
		_runs.append(run)
		_end_run(run, true)
		return run
	_runs.append(run)
	return run


## `run` walks `body` to `to` over the map's walkable ground; false when no way leads there.
## `home`: it goes back where it stood when the scene is over.
func _walk(run: Run, body: WorldCharacterBody2D, to: Vector2, home: bool = true) -> bool:
	if not to.is_finite():
		return false
	var path: PackedVector2Array = _map.npc_life.npc_walker().path_across(body, to)
	if path.is_empty():
		return false
	if home and run.id != _player_id():
		_remember_home(run.id, body)
	# A room move or a stroll under way gives way to the scene's walk.
	_map.npc_life.npc_walker().cancel(run.id)
	run.path = path
	run.walks = true
	if body is WorldNpcBody2D:
		(body as WorldNpcBody2D).set_walking(true)
	return true


func _remember_home(id: StringName, body: WorldCharacterBody2D) -> void:
	if not _homes.has(id):
		_homes[id] = [body.global_position, body.facing]


func _advance_run(run: Run, delta: float) -> void:
	var body: WorldCharacterBody2D = _body(run.id)
	if body == null:
		_runs.erase(run)
		return
	run.elapsed += delta
	if run.walks:
		var budget: float = SceneStage.walk_speed() * delta
		while not run.path.is_empty() and budget > 0.0:
			var step: float = body.global_position.distance_to(run.path[0])
			if step <= budget:
				body.global_position = run.path[0]
				budget -= step
				run.path.remove_at(0)
			else:
				body.global_position = body.global_position.move_toward(run.path[0], budget)
				budget = 0.0
		if run.path.is_empty():
			_end_run(run, false)
		return
	if run.act == &"step_back" and run.from.is_finite():
		body.global_position = run.from.lerp(run.to, smoothstep(0.0, 1.0, run.progress()))
	if run.elapsed >= run.seconds:
		_end_run(run, false)


## `run` is over: its body where the action ends, the pose it leaves kept, who left gone.
## `at_once`: it was taken to its end (a press, a cut).
func _end_run(run: Run, at_once: bool) -> void:
	_runs.erase(run)
	run.elapsed = maxf(run.elapsed, run.seconds)
	var body: WorldCharacterBody2D = _body(run.id)
	if body != null:
		if run.walks:
			if not run.path.is_empty():
				body.global_position = run.path[run.path.size() - 1]
				run.path = PackedVector2Array()
				if at_once:
					body.placed()
			if body is WorldNpcBody2D:
				(body as WorldNpcBody2D).set_walking(false)
			if run.act == &"walk" and run.action.stay:
				_stays(run.id, body)
		if run.act == &"step_back" and run.to.is_finite():
			body.global_position = run.to
			body.facing_held = false
	match run.act:
		&"kneel":
			_held[run.id] = POSE_KNEEL
		&"fall":
			_held[run.id] = POSE_FALL
		&"draw":
			_held[run.id] = POSE_GUARD
		&"rise":
			_held.erase(run.id)
		&"reach":
			if run.action.hold:
				_held[run.id] = POSE_REACH
		&"shiver":
			if run.action.hold:
				_held[run.id] = POSE_SHIVER
	if run.leaves:
		_leaving.erase(run.id)
		_gone(run.id)


## One who walked somewhere to stay is there by the map's own books: its room is the one it
## stands in.
func _stays(id: StringName, body: WorldCharacterBody2D) -> void:
	var npc: NpcRuntimeState = _map.npcs.find_resident_npc(id)
	if npc == null:
		return
	for zone: WorldPhysicalZoneArea2D in _map.physical_zones():
		if zone.contains_center(body.global_position):
			if zone.zone_id != npc.world_location().zone_id:
				npc.set_world_location(_map.location_for_zone(zone.zone_id))
			return


func _gone(id: StringName) -> void:
	var npc: NpcRuntimeState = _map.npcs.find_resident_npc(id)
	if npc != null:
		_map.npcs.leave_for_good(npc)
	_held.erase(id)
	_homes.erase(id)
	_unseen.erase(id)
	_entering.erase(id)


## [pose, how far into it] of `id` now.
func _pose(id: StringName) -> Array:
	for run: Run in _runs:
		var t: float = run.progress()
		if run.id == id:
			match run.act:
				&"bow":
					return [POSE_BOW, _bell(t)]
				&"kneel":
					return [POSE_KNEEL, smoothstep(0.0, 1.0, t)]
				&"fall":
					return [POSE_FALL, t]
				&"draw":
					return [POSE_GUARD, 1.0]
				&"rise":
					return [run.pose, 1.0 - smoothstep(0.0, 1.0, t)]
				&"reach":
					return [POSE_REACH, smoothstep(0.0, 0.2, t) if run.action.hold else _bell(t)]
				&"hand", &"toss":
					return [POSE_GIVE, _bell(clampf(t / maxf(0.001, float(SceneStage.part("flight").get("to", 0.8))), 0.0, 1.0))]
		elif run.other_id == id and run.act in [&"hand", &"toss"]:
			var from: float = float(SceneStage.part("flight").get("from", 0.3))
			return [POSE_CATCH, _bell(clampf((t - from) / maxf(0.001, 1.0 - from), 0.0, 1.0))]
	var kept: StringName = _held.get(id, &"")
	return [&"" if kept == POSE_SHIVER else kept, 1.0 if not kept.is_empty() else 0.0]


## Up over the first quarter, held, down over the last.
static func _bell(t: float) -> float:
	return smoothstep(0.0, 0.25, t) * (1.0 - smoothstep(0.75, 1.0, t))


func _way_left(run: Run) -> float:
	var body: WorldCharacterBody2D = _body(run.id)
	if body == null or run.path.is_empty():
		return 0.0
	var way: float = body.global_position.distance_to(run.path[0])
	for index: int in range(1, run.path.size()):
		way += run.path[index - 1].distance_to(run.path[index])
	return way


# --- who and where ---


func _player_id() -> StringName:
	return &"" if _map.player_runtime() == null else _map.player_runtime().character_id


func _body(id: StringName) -> WorldCharacterBody2D:
	if id.is_empty():
		return null
	if id == _player_id():
		return _map.player_body
	var body: WorldCharacterBody2D = _map.npcs.runtime_body_for_character(id)
	return body if body != null and is_instance_valid(body) else null


func _zone_of(id: StringName) -> StringName:
	if id == _player_id():
		return _map.player_runtime().world_location().zone_id
	var npc: NpcRuntimeState = _map.npcs.find_resident_npc(id)
	return &"" if npc == null else npc.world_location().zone_id


## The character a place names (the player, or the first of an NPC definition in `room`); &"".
func _person(place: StringName, room: StringName) -> StringName:
	if place == SceneCue.PLAYER:
		return _player_id()
	var npc: NpcRuntimeState = null if place.is_empty() else _map.npcs.first_npc_in_zone(place, room, false)
	return &"" if npc == null else npc.character_id


## Where a place is on this map: the player, one of an NPC definition standing in `room`, a
## door's doorway, a spawn point's marker; INF when it names nothing here.
func _spot(place: StringName, room: StringName) -> Vector2:
	if place.is_empty():
		return Vector2.INF
	var person: WorldCharacterBody2D = _body(_person(place, room))
	if person != null:
		return person.global_position
	var door: WorldDoor = _map.door(place)
	if door != null and door.wall_shape() != null:
		return door.wall_shape().global_position
	var marker: WorldSpawnMarker2D = _map.resolve_spawn_marker(place)
	return marker.global_position if marker != null else Vector2.INF


## Where a walk to `place` ends: beside a person (a free spot by them), else the spot itself.
func _beside(place: StringName, room: StringName, spot: Vector2, body: WorldCharacterBody2D) -> Vector2:
	if not spot.is_finite() or _person(place, room).is_empty():
		return spot
	var location: WorldLocationState = _map.location_for_zone(room)
	if location == null:
		return spot
	# The side it comes from first: it stops short of them, not behind them.
	var best: Vector2 = _map.floor_items.at_feet(location, spot, false, BESIDE)
	var toward: Vector2 = (body.global_position - spot).normalized()
	for distance: int in BESIDE:
		var near: Vector2 = spot + toward * distance
		if MapPlacementValidator.is_valid_character_position(_map, room, near):
			return near.round()
	return best


## The spot nearest `spot` a body may stand on (a doorway's own cell is in its wall).
func _stand_near(spot: Vector2) -> Vector2:
	if not spot.is_finite():
		return Vector2.INF
	return _map.npc_life.npc_walker().stand_near(spot)
