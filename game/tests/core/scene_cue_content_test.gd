extends RefCounted

## 过场演出 C (DECISIONS「过场动作」): the actions and shots written on the game's own scenes fit
## the scene they are written on. The catalog already checks that every word, person, thing, door
## and point a cue names exists (ContentCatalogBuilder._check_cue()); this goes through each
## NPC's scene as it is told, call after call, and checks what only the whole scene shows:
## - whoever a cue names is of the scene's cast: spawned in the teller's room, or named by the
##   scene itself (a `present`, a `by`, one who `comes`, is summoned or sent off);
## - `rise` follows a kneel or a fall of the same one, `sheathe` a draw (alone they show nothing);
## - a scene that frames its lines frames every line (a line without a shot falls back to the
##   map's own distance in the middle of the scene);
## - the scenes of the main story are staged, each with its 主线场面 where it has one.

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
	for spawn: NpcSpawnDefinition in catalog.spawns():
		if rooms.has(spawn.zone_id):
			cast[NpcDefinition.unnamed_id(spawn.npc_definition_id)] = true
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
		for number: int in steps.size():
			var step: ScriptedAct.Step = steps[number]
			var where: String = "%s call %d step %d" % [at, index, number]
			if step.kind in [ScriptedAct.Kind.BY, ScriptedAct.Kind.COMES]:
				speaker = step.npc_id
			if step.cue == null:
				continue
			var subject: StringName = step.npc_id if step.kind == ScriptedAct.Kind.LEAVE and not step.npc_id.is_empty() else speaker
			for action: SceneCue.Action in step.cue.actions:
				var doer: StringName = subject if action.who.is_empty() else action.who
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
	if shots > 0:
		_check(shots == lines, "%s: a scene that frames its lines frames every line (%d of %d)" % [at, shots, lines])
	return shots > 0


func _check(condition: bool, label: String) -> void:
	assertions += 1
	if not condition:
		failures.append(label)
