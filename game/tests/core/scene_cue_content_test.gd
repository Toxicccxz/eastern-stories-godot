extends RefCounted

## 过场演出 C (DECISIONS「过场动作」): the actions and shots written on the game's own scenes fit
## the scene they are written on. The catalog already checks that every word, person, thing, door
## and point a cue names exists (ContentCatalogBuilder._check_cue()); this goes through each
## NPC's scene as it is told, call after call, and checks what only the whole scene shows:
## - whoever a cue names by `who` or as a place is of the scene's cast: spawned in a room the
##   teller is spawned in, or named by the scene itself (a `present`, a `by`, one who `comes`, is
##   summoned or sent off). (A step's own NPC is of the cast by what it is.)
## - `rise` follows a kneel or a fall of the same one, `sheathe` a draw (alone they show nothing):
##   somewhere earlier in the scene as written, whichever of its ways is played;
## - nothing is asked of one the same call sends off with a plain `leave` (he is gone as the call
##   begins: where a fighting self is summoned in his place, the cue names that one);
## - a scene that frames its lines frames every line (a line without a shot falls back to the
##   map's own distance in the middle of the scene);
## - the scenes of the main story listed here are staged.
## Steps told after a question or a choice are not gone through (they show no cue: SceneCue.NO_CUE).

## The NPCs whose scene of the main story carries actions and shots (过场演出 B's 唤首 and C's).
const STAGED: Array[StringName] = [
	&"native.npc.shang_jue",
	&"native.npc.bai_daozhang",
	&"goathill.npc.bandit_hwang",
	&"village.npc.woman1",
	&"city.npc.shangshu.qing_chen",
	&"native.npc.yu_steward",
	&"choyin.npc.judgeman",
	&"canyon.npc.general",
	&"native.npc.nan_weishui_guest",
	&"native.npc.lu_sun",
	&"native.npc.passing_taoist",
	&"native.npc.feng_lu",
	&"native.npc.shadow_thief",
	&"native.npc.shang_jue_lake",
	&"native.npc.yulan_zhao",
	&"native.npc.court_herald",
	&"native.npc.yulan_zhao_private",
	&"native.npc.yu_zijian_accused",
	&"native.npc.woman_lakeside",
	&"native.npc.shang_jue_waiting",
	&"native.npc.herald_feng_ce",
	&"native.npc.herald_uncle",
	&"native.npc.herald_ministry",
]

var assertions: int = 0
var failures: Array[String] = []


func run_all(_tree: SceneTree) -> Dictionary:
	var catalog: ContentCatalog = GameContent.catalog()
	var framed: Array[StringName] = []
	for npc: NpcDefinition in catalog.npcs():
		var hooks: NpcHooks = npc.hooks()
		if hooks == null:
			continue
		var calls: Array[NpcHooks.Call] = []
		for call: NpcHooks.Call in hooks.calls:
			if call.scene:
				calls.append(call)
		if calls.is_empty():
			continue
		if _check_scene(catalog, npc, calls):
			framed.append(npc.definition_id)
	for id: StringName in STAGED:
		_check(framed.has(id), "%s's scene is staged (its lines framed)" % id)
	return {"assertions": assertions, "failures": failures}


## One NPC's scene, its calls in the order written. True when its lines carry shots.
func _check_scene(catalog: ContentCatalog, teller: NpcDefinition, calls: Array[NpcHooks.Call]) -> bool:
	var at: String = String(teller.definition_id)
	var cast: Dictionary[StringName, bool] = {teller.definition_id: true}
	var rooms: Dictionary[StringName, bool] = {}
	for spawn: NpcSpawnDefinition in catalog.spawns():
		if NpcDefinition.unnamed_id(spawn.npc_definition_id) == NpcDefinition.unnamed_id(teller.definition_id):
			rooms[spawn.zone_id] = true
	# How many of each kind stand in the teller's rooms (their spawn points).
	var standing: Dictionary[StringName, int] = {}
	for spawn: NpcSpawnDefinition in catalog.spawns():
		if rooms.has(spawn.zone_id):
			var kind: StringName = NpcDefinition.unnamed_id(spawn.npc_definition_id)
			cast[kind] = true
			standing[kind] = int(standing.get(kind, 0)) + spawn.spawn_point_ids().size()
	var cued: int = 0
	var shots: int = 0
	var lines: int = 0
	for call: NpcHooks.Call in calls:
		for id: StringName in [call.act.present] + call.act.presents:
			if not id.is_empty():
				cast[id] = true
		for step: ScriptedAct.Step in call.act.steps:
			if step.kind in [ScriptedAct.Kind.BY, ScriptedAct.Kind.COMES, ScriptedAct.Kind.LEAVE, ScriptedAct.Kind.HOME] and not step.npc_id.is_empty():
				cast[step.npc_id] = true
			if not step.only_present.is_empty():
				cast[step.only_present] = true
			if step.kind == ScriptedAct.Kind.SUMMON:
				for spawn: NpcSpawnDefinition in catalog.spawns():
					if spawn.spawn_id == step.spawn_id:
						cast[NpcDefinition.unnamed_id(spawn.npc_definition_id)] = true
			if step.kind == ScriptedAct.Kind.LINE:
				lines += 1
				if step.cue != null and step.cue.shot != null:
					shots += 1
			if step.cue != null:
				cued += 1
	if cued == 0:
		return false
	# Who kneels, lies or stands on guard as the scene goes: the speaker changes with `by` and `comes`.
	var down: Dictionary[StringName, bool] = {}
	var guard: Dictionary[StringName, bool] = {}
	for index: int in calls.size():
		var speaker: StringName = teller.definition_id
		var steps: Array[ScriptedAct.Step] = calls[index].act.steps
		# Whoever this call sends off with no way out of its own (a plain `leave`: one swapped for a
		# fighting self the same call summons) is gone as the call begins, before any of its pages
		# shows: nothing can be shown of him, and a shot on him finds nobody.
		# (One of several of a kind sent off leaves the others; one who comes or is summoned again in
		# the same call is there. The first page of a call may show before the call's last steps are
		# settled: it is checked like the rest, which errs on the strict side.)
		var gone: Dictionary[StringName, bool] = {}
		var left: Dictionary[StringName, int] = {}
		var back: Dictionary[StringName, bool] = {}
		var leaver: StringName = teller.definition_id
		for step: ScriptedAct.Step in steps:
			if step.kind in [ScriptedAct.Kind.BY, ScriptedAct.Kind.COMES]:
				leaver = step.npc_id
			if step.kind == ScriptedAct.Kind.COMES:
				back[step.npc_id] = true
			if step.kind == ScriptedAct.Kind.SUMMON:
				for spawn: NpcSpawnDefinition in catalog.spawns():
					if spawn.spawn_id == step.spawn_id:
						back[NpcDefinition.unnamed_id(spawn.npc_definition_id)] = true
			if step.kind == ScriptedAct.Kind.LEAVE and (step.cue == null or not step.cue.leaving()):
				var id: StringName = leaver if step.npc_id.is_empty() else step.npc_id
				left[id] = int(left.get(id, 0)) + 1
		for id: StringName in left:
			if not back.has(id) and left[id] >= maxi(1, int(standing.get(id, 0))):
				gone[id] = true
		for number: int in steps.size():
			var step: ScriptedAct.Step = steps[number]
			var where: String = "%s call %d step %d" % [at, index, number]
			if step.kind in [ScriptedAct.Kind.BY, ScriptedAct.Kind.COMES]:
				speaker = step.npc_id
			if step.cue == null:
				continue
			var subject: StringName = step.npc_id if step.kind == ScriptedAct.Kind.LEAVE and not step.npc_id.is_empty() else speaker
			if step.cue.shot != null and step.cue.shot.frame in [&"near", &"two"]:
				_check(not gone.has(speaker), "%s: a %s shot on '%s', whom this call has already sent off (look at who stands there instead)" % [where, step.cue.shot.frame, speaker])
			for action: SceneCue.Action in step.cue.actions:
				var doer: StringName = subject if action.who.is_empty() else action.who
				_check(not gone.has(doer), "%s: '%s' is to %s, but this call has already sent him off" % [where, doer, action.act])
				if doer != SceneCue.PLAYER:
					_check(cast.has(doer), "%s: '%s' who is to %s is of the scene's cast" % [where, doer, action.act])
				match action.act:
					&"kneel", &"fall":
						down[doer] = true
					&"rise":
						_check(down.has(doer), "%s: '%s' rises after kneeling or falling" % [where, doer])
						down.erase(doer)
					&"draw":
						guard[doer] = true
					&"sheathe":
						_check(guard.has(doer), "%s: '%s' sheathes what it drew" % [where, doer])
						guard.erase(doer)
			for named: Array in step.cue.places():
				var place: StringName = named[1]
				if place != SceneCue.PLAYER and catalog.npc(place) != null:
					_check(cast.has(place), "%s: '%s' (%s) is of the scene's cast" % [where, place, named[0]])
					_check(not gone.has(place), "%s: '%s' (%s) is named, but this call has already sent him off" % [where, place, named[0]])
	if shots > 0:
		_check(shots == lines, "%s: a scene that frames its lines frames every line (%d of %d)" % [at, shots, lines])
	return shots > 0


func _check(condition: bool, label: String) -> void:
	assertions += 1
	if not condition:
		failures.append(label)
