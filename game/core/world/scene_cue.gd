class_name SceneCue
extends RefCounted

## Native (过场演出 B; DECISIONS「过场动作」): what a scene's step shows besides its words — who does
## what (`do`), how the camera frames it (`shot`) and a 主线场面 played with it (`fx`). Any step
## of a ScriptedAct may carry them; the step's rule (its line, its gift, its mark, who comes and
## who leaves) is settled as ever. Words only: the map's staging (WorldMapStaging) moves the
## bodies and the view shows the poses; with the feel's scene_action_ms at 0 none of it is read.
##
## `do`: one action or a list. An action is a word alone ("kneel") or a record
## {act, who?, <place>?, item?, stay?, hold?}:
## - `who`: who does it — left out, the step's own NPC (the one speaking; the one who comes,
##   leaves or is summoned on those steps); "player"; or an NPC definition standing in the room.
## - a place is "player", an NPC definition (where one of them stands), a door of the map (its
##   doorway) or a spawn point of the map (a marker).
## The words (WORDS):
## - face {toward}: turns to a place.
## - walk {to, stay?}: walks to a place (beside a person); back where it stood when the scene is
##   over unless `stay`.
## - bow {toward?}; kneel; rise (up from kneeling or lying); draw / sheathe (its weapon);
##   startle; shiver {hold?}; reach {toward?, hold?} (both hands out, feeling for something);
##   fall (down on its back, until `rise`).
## - hand / toss {item, to}: a small thing goes from its hand to another's — straight, or in an arc.
## - step_back {from?}: a step away from a place (left out: from the player; the player, from
##   whoever speaks).
## - on a `comes` step: enter {from} (walks in from a door or a point, not put beside the player).
## - on a `leave` step: exit {by} (walks to a door or a point, then is gone); dissolve (thins away
##   where it stands).
## - on a `summon` or `comes` step: emerge (rises out of the ground where it comes).
## The player does only PLAYER_WORDS (they face whoever speaks by themselves).
##
## `shot`: "near" (pushed in on the speaker), "wide" (the whole room), {two: who} (the speaker and
## another, both in the picture) or {look: place} (the camera goes to a thing or a spot). Left
## out: the camera follows whoever speaks, as before.
##
## `fx`: a scene of story_fx.json, played now (its own trigger then stays quiet: once).

const PLAYER: StringName = &"player"

## Each word: `place` the key its place is written under ("" none), `needs` whether it must be
## there, `item` whether it carries a thing, `stay` / `hold` whether it may say so, `on` the step
## kinds it belongs to ([] any), `person` whether its place must be someone (not a door or a spot).
const WORDS: Dictionary[StringName, Dictionary] = {
	&"face": {"place": "toward", "needs": true},
	&"walk": {"place": "to", "needs": true, "stay": true},
	&"bow": {"place": "toward"},
	&"kneel": {},
	&"rise": {},
	&"draw": {},
	&"sheathe": {},
	&"startle": {},
	&"shiver": {"hold": true},
	&"reach": {"place": "toward", "hold": true},
	&"fall": {},
	&"hand": {"place": "to", "needs": true, "item": true, "person": true},
	&"toss": {"place": "to", "needs": true, "item": true, "person": true},
	&"step_back": {"place": "from"},
	&"enter": {"place": "from", "needs": true, "on": ["comes"]},
	&"exit": {"place": "by", "needs": true, "on": ["leave"]},
	&"dissolve": {"on": ["leave"]},
	&"emerge": {"on": ["summon", "comes"]},
}
## What the player's own figure may be told to do.
const PLAYER_WORDS: Array[StringName] = [&"face", &"bow", &"kneel", &"rise", &"step_back", &"startle", &"shiver"]
## The words after which the one who leaves is gone (a `leave` step waits for them).
const LEAVING: Array[StringName] = [&"exit", &"dissolve"]
const FRAMES: Array[StringName] = [&"near", &"wide", &"two", &"look"]

var actions: Array[Action] = []
## null: the camera follows whoever speaks.
var shot: Shot = null
var fx: String = ""


class Action:
	extends RefCounted
	var act: StringName = &""
	## &"": the step's own NPC; PLAYER; else an NPC definition.
	var who: StringName = &""
	## Where to, toward what, from where (the word's place); &"" none.
	var place: StringName = &""
	## hand / toss: the thing.
	var item: StringName = &""
	var stay: bool = false
	var hold: bool = false


class Shot:
	extends RefCounted
	var frame: StringName = &""
	## two: the other one in the picture; look: where the camera goes.
	var place: StringName = &""


## Whether the one who leaves on this step goes by an action of its own (exit, dissolve).
func leaving() -> bool:
	return actions.any(func(action: Action) -> bool: return LEAVING.has(action.act) and action.who.is_empty())


## Every place the cue names, with the field it stands in (the catalog checks each exists).
func places() -> Array[Array]:
	var named: Array[Array] = []
	for action: Action in actions:
		if not action.place.is_empty():
			named.append(["do.%s" % String(WORDS[action.act].get("place", "")), action.place, bool(WORDS[action.act].get("person", false))])
	if shot != null and not shot.place.is_empty():
		named.append(["shot.%s" % shot.frame, shot.place, shot.frame == &"two"])
	return named


## The cue of a step record of `kind` (the step's own key: "line", "leave", "comes", "summon" ...),
## null when it carries none. A word that is not one, a field a word does not take, a word on the
## wrong kind of step: each fails here.
static func read(reader: ContentRecordReader, kind: String) -> SceneCue:
	if not (reader.has("do") or reader.has("shot") or reader.has("fx")):
		return null
	var cue := SceneCue.new()
	if reader.is_text("do"):
		var action: Action = _word(reader, reader.text("do"), kind)
		if action != null:
			cue.actions.append(action)
	elif reader.is_object("do"):
		var action: Action = _action(reader.child("do"), kind)
		if action != null:
			cue.actions.append(action)
	elif reader.has("do"):
		for entry: Variant in reader.strings_or_children("do"):
			var action: Action = _word(reader, entry, kind) if entry is String else _action(entry, kind)
			if action != null:
				cue.actions.append(action)
		if cue.actions.is_empty():
			reader.fail("do", "names at least one action")
	if reader.is_text("shot"):
		cue.shot = Shot.new()
		cue.shot.frame = StringName(reader.text("shot"))
		if not cue.shot.frame in [&"near", &"wide"]:
			reader.fail("shot", "expected near, wide, {two: who} or {look: place}")
	elif reader.has("shot"):
		var framed: ContentRecordReader = reader.child("shot")
		if framed != null:
			cue.shot = Shot.new()
			var frames: Array[String] = framed.keys()
			if frames.size() != 1 or not frames[0] in ["two", "look"]:
				framed.fail("", "expected exactly one of two and look")
			else:
				cue.shot.frame = StringName(frames[0])
				cue.shot.place = StringName(framed.required_text(frames[0]))
			framed.finish()
	cue.fx = reader.text("fx")
	if reader.has("fx") and cue.fx.is_empty():
		reader.fail("fx", "names a scene of story_fx.json")
	return cue


## A word written alone: one that needs nothing more.
static func _word(reader: ContentRecordReader, word: String, kind: String) -> Action:
	var act := StringName(word)
	if not WORDS.has(act):
		reader.fail("do", "'%s' is no action (%s)" % [word, _words(WORDS.keys())])
		return null
	var rule: Dictionary = WORDS[act]
	if bool(rule.get("needs", false)) or bool(rule.get("item", false)):
		reader.fail("do", "'%s' needs more than its word: {act, %s}" % [word, rule.get("place", "item")])
		return null
	if not _fits(rule, kind):
		reader.fail("do", "'%s' belongs on a %s step" % [word, _words(rule["on"])])
		return null
	var action := Action.new()
	action.act = act
	return action


static func _action(reader: ContentRecordReader, kind: String) -> Action:
	if reader == null:
		return null
	var action := Action.new()
	action.act = StringName(reader.required_text("act"))
	if not WORDS.has(action.act):
		reader.fail("act", "'%s' is no action (%s)" % [action.act, _words(WORDS.keys())])
		return null
	var rule: Dictionary = WORDS[action.act]
	if not _fits(rule, kind):
		reader.fail("act", "'%s' belongs on a %s step" % [action.act, _words(rule["on"])])
	action.who = StringName(reader.text("who"))
	if action.who == PLAYER and not PLAYER_WORDS.has(action.act):
		reader.fail("who", "the player's figure does not '%s' (%s)" % [action.act, _words(PLAYER_WORDS)])
	if rule.has("on") and not action.who.is_empty():
		reader.fail("who", "'%s' is done by the one the step brings or sends off" % action.act)
	var key: String = String(rule.get("place", ""))
	if not key.is_empty():
		action.place = StringName(reader.required_text(key) if bool(rule.get("needs", false)) else reader.text(key))
	if bool(rule.get("item", false)):
		action.item = StringName(reader.required_text("item"))
	if bool(rule.get("stay", false)):
		action.stay = reader.boolean("stay", false)
	if bool(rule.get("hold", false)):
		action.hold = reader.boolean("hold", false)
	reader.finish()
	return action


static func _fits(rule: Dictionary, kind: String) -> bool:
	return not rule.has("on") or (rule["on"] as Array).has(kind)


static func _words(words: Array) -> String:
	var listed: PackedStringArray = []
	for word: Variant in words:
		listed.append(String(word))
	return ", ".join(listed)
