extends RefCounted

## 过场演出 B (DECISIONS「过场动作」): what a scene's step may show besides its words (SceneCue: `do`,
## `shot`, `fx`), as data — every word of the list reads, a word that is not one fails, as does a
## field a word does not take, a word on the wrong kind of step and one the player's figure does
## not do; and what a cue names is checked against the game (ContentCatalogBuilder.cue_problems()).

var assertions: int = 0
var failures: Array[String] = []


func run_all(_tree: SceneTree) -> Dictionary:
	_check_words()
	_check_wrong()
	_check_shots()
	_check_steps()
	_check_names()
	_check_timing()
	return {"assertions": assertions, "failures": failures}


## Every word reads, alone or with what it needs.
func _check_words() -> void:
	for word: StringName in SceneCue.WORDS:
		var rule: Dictionary = SceneCue.WORDS[word]
		var record: Dictionary = {"act": String(word)}
		if rule.has("place"):
			record[rule["place"]] = "player"
		if bool(rule.get("item", false)):
			record["item"] = "t:thing"
		var kind: String = String((rule["on"] as Array)[0]) if rule.has("on") else "line"
		var errors: Array[String] = []
		var cue: SceneCue = _read({"do": record}, kind, errors)
		_check(errors.is_empty() and cue != null and cue.actions.size() == 1 and cue.actions[0].act == word, "'%s' reads: %s" % [word, errors])
		if cue != null and rule.has("place"):
			_check(cue.actions[0].place == &"player" and cue.places().size() == 1, "'%s' keeps its place under %s" % [word, rule["place"]])
	_check(SceneCue.WORDS.size() == 18, "the list of words: %d" % SceneCue.WORDS.size())
	# Alone, as a list, with who.
	var errors: Array[String] = []
	var alone: SceneCue = _read({"do": "kneel"}, "line", errors)
	_check(errors.is_empty() and alone.actions[0].act == &"kneel" and alone.actions[0].who.is_empty(), "a word alone: the step's own NPC does it")
	var several: SceneCue = _read({"do": ["startle", {"who": "player", "act": "step_back"}, {"act": "walk", "to": "t.point", "stay": true}]}, "line", errors)
	_check(errors.is_empty() and several.actions.size() == 3 and several.actions[1].who == SceneCue.PLAYER and several.actions[2].stay, "a list of actions, the player's among them, a walk that stays: %s" % [errors])
	var held: SceneCue = _read({"do": {"act": "reach", "hold": true}}, "line", errors)
	_check(errors.is_empty() and held.actions[0].hold and held.actions[0].place.is_empty(), "reach may be kept up, toward nothing in particular")
	_check(_read({"say": "x"}, "line", errors) == null, "a step without do, shot or fx carries no cue")


## What is not a word, or not allowed, fails where it is written.
func _check_wrong() -> void:
	_check(_problems({"do": "knel"}, "line").size() == 1 and _problems({"do": "knel"}, "line")[0].contains("'knel' is no action"), "a misspelt word fails: %s" % [_problems({"do": "knel"}, "line")])
	_check(_problems({"do": {"act": "dance"}}, "line")[0].contains("'dance' is no action"), "so does one in a record")
	_check(_problems({"do": "walk"}, "line")[0].contains("needs more than its word"), "walk alone says nowhere to go")
	_check(_problems({"do": {"act": "face"}}, "line")[0].contains("toward: is required"), "face needs its place: %s" % [_problems({"do": {"act": "face"}}, "line")])
	_check(_problems({"do": {"act": "toss", "to": "player"}}, "line")[0].contains("item: is required"), "a toss needs its thing")
	_check(_problems({"do": {"act": "kneel", "toward": "player"}}, "line")[0].contains("toward: unknown field"), "kneel takes no place")
	_check(_problems({"do": {"act": "face", "toward": "player", "stay": true}}, "line")[0].contains("stay: unknown field"), "only a walk stays")
	_check(_problems({"do": {"who": "player", "act": "draw"}}, "line")[0].contains("the player's figure does not 'draw'"), "the player's figure does only its own words")
	for word: StringName in SceneCue.PLAYER_WORDS:
		var record: Dictionary = {"who": "player", "act": String(word)}
		if SceneCue.WORDS[word].has("place"):
			record[SceneCue.WORDS[word]["place"]] = "t.point"
		_check(_problems({"do": record}, "line").is_empty(), "the player may '%s'" % word)
	_check(_problems({"do": []}, "line")[0].contains("names at least one action"), "an empty list is no cue")
	_check(_problems({"fx": ""}, "line")[0].contains("names a scene"), "an empty fx is none")


func _check_shots() -> void:
	var errors: Array[String] = []
	for frame: String in ["near", "wide"]:
		var cue: SceneCue = _read({"shot": frame}, "line", errors)
		_check(errors.is_empty() and cue.shot != null and cue.shot.frame == StringName(frame) and cue.shot.place.is_empty(), "shot %s" % frame)
	var two: SceneCue = _read({"shot": {"two": "native.npc.x"}}, "line", errors)
	_check(errors.is_empty() and two.shot.frame == &"two" and two.shot.place == &"native.npc.x" and bool(two.places()[0][2]), "two: with someone")
	var look: SceneCue = _read({"shot": {"look": "t.door"}, "fx": "shade_called"}, "line", errors)
	_check(errors.is_empty() and look.shot.frame == &"look" and look.fx == "shade_called" and not bool(look.places()[0][2]), "look: at a place; fx beside it")
	_check(_problems({"shot": "close"}, "line")[0].contains("expected near, wide"), "an unknown frame fails")
	_check(_problems({"shot": {"two": "a", "look": "b"}}, "line")[0].contains("exactly one of two and look"), "one frame a shot")
	_check(SceneCue.FRAMES.size() == 4, "four frames")


## The words that belong to a kind of step: who comes walks in or rises, who leaves walks out or
## thins away, who is summoned rises; and a whole step reads its cue beside its own key.
func _check_steps() -> void:
	_check(_problems({"do": "emerge"}, "line")[0].contains("belongs on a summon, comes step"), "emerge is for who is summoned or comes: %s" % [_problems({"do": "emerge"}, "line")])
	_check(_problems({"do": {"act": "exit", "by": "t.door"}}, "line")[0].contains("belongs on a leave step"), "exit is for who leaves")
	_check(_problems({"do": "dissolve"}, "comes")[0].contains("belongs on a leave step"), "dissolve too")
	_check(_problems({"do": {"act": "enter", "from": "t.door"}}, "leave")[0].contains("belongs on a comes step"), "enter is for who comes")
	_check(_problems({"do": {"who": "native.npc.x", "act": "exit", "by": "t.door"}}, "leave")[0].contains("done by the one the step brings or sends off"), "nobody else leaves for them")
	var errors: Array[String] = []
	var act: ScriptedAct = ScriptedAct.from_record(ContentRecordReader.new({"steps": [
		{"say": "一", "do": "bow", "shot": "near"},
		{"leave": true, "do": {"act": "exit", "by": "t.door"}},
		{"summon": "t.spawn", "do": "emerge", "fx": "shade_called"},
		{"comes": "t.npc", "from": "t.zone", "do": {"act": "enter", "from": "t.door"}},
		{"mark": "x"},
	]}, "t", errors))
	_check(errors.is_empty() and act.steps.size() == 5, "a branch's steps read their cues: %s" % [errors])
	_check(act.steps[0].cue != null and act.steps[0].cue.actions[0].act == &"bow" and act.steps[0].cue.shot.frame == &"near", "a line's cue")
	_check(act.steps[1].cue.leaving() and act.steps[1].kind == ScriptedAct.Kind.LEAVE, "a leave that walks out is one the step waits for")
	_check(not act.steps[2].cue.leaving() and act.steps[2].cue.fx == "shade_called" and act.steps[2].spawn_id == &"t.spawn", "a summon keeps its spawn beside its cue")
	_check(act.steps[3].zone_id == &"t.zone" and act.steps[3].cue.actions[0].place == &"t.door", "comes keeps its own `from` (the room); the door is the action's")
	_check(act.steps[4].cue == null, "a step without one has none")
	# A step that waits on the player or takes them away shows nothing of its own.
	for kind: String in SceneCue.NO_CUE:
		_check(_problems({"do": "kneel", "shot": "near"}, kind).size() == 2 and _problems({"do": "kneel"}, kind)[0].contains("a %s step shows nothing of its own" % kind), "no cue on a %s step" % kind)
	var wrong: Array[String] = []
	ScriptedAct.from_record(ContentRecordReader.new({"steps": [{"say": "一", "do": "bwo"}]}, "t", wrong))
	_check(wrong.size() == 1 and wrong[0].begins_with("t.steps[0].do: 'bwo' is no action"), "a wrong word in content fails the load: %s" % [wrong])


## What a cue names exists in the game, and is one thing only.
func _check_names() -> void:
	var builder: ContentCatalogBuilder = GameContent.read_documents()
	_check(builder.build() != null, "the shipped content builds for the check")
	var teller: StringName = &"native.npc.shang_jue"
	var errors: Array[String] = []
	var fine: SceneCue = _read({"do": [
		{"act": "face", "toward": "player"},
		{"act": "toss", "item": "native:niling/cell_key", "to": "native.npc.xuan_mingzi"},
		{"act": "walk", "to": "niling.altar.master_return"},
		{"who": "native.npc.headless_shade", "act": "reach"},
	], "shot": {"look": "niling.master.door"}, "fx": "shade_called"}, "line", errors)
	_check(errors.is_empty() and builder.cue_problems("t", fine, teller).is_empty(), "the player, an NPC, a door, a spawn point, an item and a 主线场面 the game has: %s" % [builder.cue_problems("t", fine, teller)])
	_check(builder.cue_problems("t", _read({"do": {"act": "face", "toward": "native.npc.nobody"}}, "line", errors), teller) == ["t.do.toward: 'native.npc.nobody' is not the player, an NPC, a door or a spawn point"], "a place that is nothing: %s" % [builder.cue_problems("t", _read({"do": {"act": "face", "toward": "native.npc.nobody"}}, "line", errors), teller)])
	_check(builder.cue_problems("t", _read({"do": {"who": "native.npc.nobody", "act": "bow"}}, "line", errors), teller) == ["t.do.who: unknown NPC 'native.npc.nobody'"], "someone who is nobody")
	_check(builder.cue_problems("t", _read({"do": {"act": "hand", "item": "t:nothing", "to": "player"}}, "line", errors), teller) == ["t.do.item: unknown item 't:nothing'"], "a thing that is nothing")
	_check(builder.cue_problems("t", _read({"do": {"act": "toss", "item": "native:niling/cell_key", "to": "niling.master.door"}}, "line", errors), teller) == ["t.do.to: 'niling.master.door' is a door, not someone"], "a thing is handed to someone, not to a door")
	_check(builder.cue_problems("t", _read({"shot": {"two": "niling.altar.shade.1"}}, "line", errors), teller) == ["t.shot.two: 'niling.altar.shade.1' is a spawn point, not someone"], "two frames two people")
	_check(builder.cue_problems("t", _read({"fx": "no_such_scene"}, "line", errors), teller) == ["t.fx: 'no_such_scene' is no scene of story_fx.json"], "a 主线场面 that is none")
	var elsewhere: Array[String] = builder.cue_problems("t", _read({"do": {"act": "walk", "to": "snow.square.inn_entry"}}, "line", errors), teller)
	_check(elsewhere.size() == 1 and elsewhere[0].contains("where native.npc.shang_jue is never spawned"), "a spot of another map than the teller's: %s" % [elsewhere])
	_check(builder.cue_problems("t", _read({"do": {"act": "walk", "to": "snow.square.inn_entry"}}, "line", errors)).is_empty(), "a room's own act has no teller to judge the map by")
	_check(errors.is_empty(), "the records themselves read: %s" % [errors])
	_check(SceneStage.fx_names().has("shade_called") and SceneStage.fx_names().size() >= 6, "the 主线场面 are known by name: %s" % [SceneStage.fx_names()])


## scene_stage.json times every word, in units of the feel's scene_action_ms; off, nothing shows.
func _check_timing() -> void:
	var seconds: Dictionary = SceneStage.part("seconds")
	for word: StringName in SceneCue.WORDS:
		if not word in [&"walk", &"enter", &"exit"]:
			_check(seconds.has(String(word)) and float(seconds[String(word)]) > 0.0, "'%s' has its time" % word)
	_check(SceneStage.walk_speed() > 0.0 and SceneStage.step_back_px() > 0.0, "a walk's speed and a step's length")
	_check(not SceneStage.on() and is_zero_approx(SceneStage.seconds(&"bow")), "the suites' feel: no action is shown")
	var shipped: FeelDefinition = TestFeel.production
	_check(shipped.scene_action_seconds() > 0.0, "pacing.json shows them: %s" % shipped.scene_action_seconds())
	var shots: Dictionary = SceneStage.part("shots")
	_check(float(shots.get("near", 0.0)) > 0.0 and float(shots.get("near", 0.0)) < 1.0 and String(shots.get("move", "")) in ["pan", "cut"], "the shots' framing")
	var art: String = String(SceneStage.part("dissolve").get("art", ""))
	_check(BattleArts.KINDS.has(art), "the smoke of one thinning away is an art the fight draws: %s" % art)


func _read(record: Dictionary, kind: String, errors: Array[String]) -> SceneCue:
	return SceneCue.read(ContentRecordReader.new(record, "t", errors), kind)


func _problems(record: Dictionary, kind: String) -> Array[String]:
	var errors: Array[String] = []
	var reader := ContentRecordReader.new(record, "t", errors)
	SceneCue.read(reader, kind)
	return errors


func _check(condition: bool, label: String) -> void:
	assertions += 1
	if not condition:
		failures.append(label)
