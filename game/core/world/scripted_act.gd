class_name ScriptedAct
extends RefCounted

## One branch of an ES2 function that acts on the player where they stand: an NPC's
## greeting() (d/latemoon/room/npc/shinyu.c: a man is shouted at, powdered, kicked out),
## a room's own command (d/latemoon/room/bathroom.c take bath, upstar/uproom3.c ponder,
## latemoon2.c search bracelet) or a carried item's (bracelet.c pray, letter.c fire).
## `gender`, `not_gender` and `not_class` say whom the branch is for (the player's
## query("gender") and query("class")); `temp` and `not_temp` a set_temp() flag the player
## has or lacks, `mark` a saved mark they have and `carries` an id something they carry
## answers to (present(id, me): letter.c's 火摺), `present` an NPC standing in the room
## (present("cook bonze"): d/sanyen/kitchen.c; one lying unconscious says nothing, 默认). The first branch that is for
## the player acts. `ask` is the owner's question before a choice that can kill (a man walking into
## the bath, DECISIONS 晚月庄 A), with `choice` its button. The steps run in order:
## - a line (NpcLine: say, emote, line, whisper, in its colour; a room's message_vision()
##   written as the player reads it, 你 for $N);
## - `damage` {gin, kee, sen}: receive_damage() on the player;
## - `heal` (gin, kee or sen) `base` + random(`random`): receive_heal();
## - `condition` with `duration`: apply_condition() (it replaces the one there);
## - `calm` n: a bellicosity above 0 goes down random(kar) + n (uproom3.c);
## - `npc_force` n: the NPC's own force grows by n (this_object()->add("force", n));
## - `close_door`: the NPC's command("close door"), on the door the player came by;
## - `move` (a zone, on any map) to `point`: ob->move(), the player taken there;
## - `kill`: kill_ob(player) and the player's fight_ob(): a fight to the death;
## - `give` (an item) `unless_temp`: the item new()'d to the player, unless they carry the
##   set_temp() flag already (which the gift sets), then its `lines`;
## - `set_temp` a flag: set_temp(flag, 1) on the player (not saved);
## - `unmark` a mark: delete("mark/<mark>") (latemoon8.c's dance-book).
enum Kind { LINE, DAMAGE, HEAL, CONDITION, CALM, NPC_FORCE, CLOSE_DOOR, MOVE, KILL, GIVE, SET_TEMP, UNMARK }

## The resources receive_damage() and receive_heal() name.
const RESOURCES: Array[String] = ["gin", "kee", "sen"]

var gender: StringName = &""
var not_gender: StringName = &""
var not_class: StringName = &""
var temp: String = ""
var not_temp: String = ""
var mark: String = ""
var carries: String = ""
## An NPC definition present() in the room.
var present: StringName = &""
var ask: String = ""
var choice: String = ""
var steps: Array[Step] = []


## What a branch may ask of the player besides gender and class: their saved marks, their
## set_temp() flags, the ids of what they carry directly (present(id, me)) and the NPCs
## standing where they stand (present(), by definition).
class Facts:
	extends RefCounted
	var marks: Dictionary[String, int] = {}
	var temps: Dictionary[String, int] = {}
	var carried: Array[String] = []
	var present_npcs: Array[StringName] = []


class Step:
	extends RefCounted
	var kind: Kind
	var line: NpcLine
	## damage: by resource name.
	var amounts: Dictionary[String, int] = {}
	## heal: the resource; base + random(random_of).
	var resource: String = ""
	var base: int = 0
	var random_of: int = 0
	## condition: the ID and its duration.
	var condition_id: StringName = &""
	var duration: int = 0
	## calm, npc_force: the number.
	var value: int = 0
	## move: where to.
	var zone_id: StringName = &""
	var point_id: StringName = &""
	## give: the item, the set_temp() flag, what is said after.
	var item_id: StringName = &""
	var unless_temp: String = ""
	var lines: Array[NpcLine] = []
	## set_temp, unmark: the flag or mark.
	var flag: String = ""


## Whether the branch is for a player of this gender and class, with these `facts` (none:
## no marks, flags or things carried).
func applies_to(player_gender: StringName, class_id: StringName, facts: Facts = null) -> bool:
	var known: Facts = facts if facts != null else Facts.new()
	return (
		(gender.is_empty() or gender == player_gender)
		and (not_gender.is_empty() or not_gender != player_gender)
		and (not_class.is_empty() or not_class != class_id)
		and (temp.is_empty() or known.temps.get(temp, 0) != 0)
		and (not_temp.is_empty() or known.temps.get(not_temp, 0) == 0)
		and (mark.is_empty() or known.marks.get(mark, 0) != 0)
		and (carries.is_empty() or known.carried.has(carries))
		and (present.is_empty() or known.present_npcs.has(present))
	)


## The first branch of `acts` that is for the player; null when none is.
static func first_for(acts: Array[ScriptedAct], player_gender: StringName, class_id: StringName, facts: Facts = null) -> ScriptedAct:
	for act: ScriptedAct in acts:
		if act.applies_to(player_gender, class_id, facts):
			return act
	return null


## Whether a step takes the player elsewhere (the caller closes what they had open).
func moves_player() -> bool:
	return steps.any(func(step: Step) -> bool: return step.kind == Kind.MOVE)


## What the steps' receive_damage() takes from each resource it would take below zero
## (the player would fall unconscious on the next heart beat), in gin, kee, sen order.
func fainting_costs(state: CharacterState) -> Dictionary[String, int]:
	var spent: Dictionary[String, int] = {}
	for step: Step in steps:
		if step.kind == Kind.DAMAGE:
			for key: String in step.amounts:
				spent[key] = spent.get(key, 0) + step.amounts[key]
	var result: Dictionary[String, int] = {}
	for key: String in RESOURCES:
		if spent.has(key) and resource_of(state, key).current - spent[key] < 0:
			result[key] = spent[key]
	return result


## gin, kee or sen of a character.
static func resource_of(state: CharacterState, key: String) -> CharacterResourceState:
	match key:
		"gin":
			return state.essence
		"kee":
			return state.vitality
	return state.spirit


## {gender?, not_gender?, not_class?, temp?, not_temp?, mark?, carries?, present?, ask?, choice?, steps: [step]}.
static func from_record(reader: ContentRecordReader) -> ScriptedAct:
	var act := ScriptedAct.new()
	act.gender = StringName(reader.text("gender"))
	act.not_gender = StringName(reader.text("not_gender"))
	act.not_class = StringName(reader.text("not_class"))
	act.temp = reader.text("temp")
	act.not_temp = reader.text("not_temp")
	act.mark = reader.text("mark")
	act.carries = reader.text("carries")
	act.present = StringName(reader.text("present"))
	act.ask = reader.text("ask")
	act.choice = reader.text("choice")
	if act.ask.is_empty() != act.choice.is_empty():
		reader.fail("choice", "ask and choice come together")
	for record: ContentRecordReader in reader.children("steps"):
		var step: Step = _step(record)
		record.finish()
		if step != null:
			act.steps.append(step)
	reader.finish()
	if act.steps.is_empty():
		reader.fail("steps", "an act does something")
	return act


## A line record (say, emote, line, whisper) is an act of that one line.
static func of_line(line: NpcLine) -> ScriptedAct:
	var act := ScriptedAct.new()
	var step := Step.new()
	step.kind = Kind.LINE
	step.line = line
	act.steps.append(step)
	return act


static func _step(reader: ContentRecordReader) -> Step:
	var step := Step.new()
	# A line is one step whichever of say, emote, line or whisper it is (NpcLine checks).
	var kinds: Array[String] = []
	if ["say", "emote", "line", "whisper"].any(func(key: String) -> bool: return reader.has(key)):
		kinds.append("line")
	for key: String in ["damage", "heal", "condition", "calm", "npc_force", "close_door", "move", "kill", "give", "set_temp", "unmark"]:
		if reader.has(key):
			kinds.append(key)
	if kinds.size() != 1:
		reader.fail("", "a step does exactly one thing: %s" % [kinds])
		return null
	match kinds[0]:
		"line":
			step.kind = Kind.LINE
			step.line = NpcLine.from_record(reader, true)
			if step.line == null:
				return null
		"damage":
			step.kind = Kind.DAMAGE
			var amounts: ContentRecordReader = reader.child("damage")
			if amounts == null:
				reader.fail("damage", "expected {gin, kee, sen}")
				return null
			for key: String in amounts.keys():
				if not RESOURCES.has(key):
					amounts.fail(key, "expected one of %s" % [RESOURCES])
				step.amounts[key] = amounts.required_integer(key)
				if step.amounts[key] < 0:
					amounts.fail(key, "must not be negative")
			amounts.finish()
		"heal":
			step.kind = Kind.HEAL
			step.resource = reader.required_text("heal")
			step.base = reader.integer("base", 0)
			step.random_of = reader.integer("random", 0)
			if not RESOURCES.has(step.resource) or step.base < 0 or step.random_of < 0:
				reader.fail("heal", "heals gin, kee or sen by base + random(random), neither negative")
		"condition":
			step.kind = Kind.CONDITION
			step.condition_id = StringName(reader.required_text("condition"))
			step.duration = reader.required_integer("duration")
		"calm":
			step.kind = Kind.CALM
			step.value = reader.required_integer("calm")
		"npc_force":
			step.kind = Kind.NPC_FORCE
			step.value = reader.required_integer("npc_force")
		"close_door":
			step.kind = Kind.CLOSE_DOOR
			if not reader.boolean("close_door", false):
				reader.fail("close_door", "is true when present")
		"move":
			step.kind = Kind.MOVE
			step.zone_id = StringName(reader.required_text("move"))
			step.point_id = StringName(reader.required_text("point"))
		"kill":
			step.kind = Kind.KILL
			if not reader.boolean("kill", false):
				reader.fail("kill", "is true when present")
		"give":
			step.kind = Kind.GIVE
			step.item_id = StringName(reader.required_text("give"))
			step.unless_temp = reader.text("unless_temp")
			for record: ContentRecordReader in reader.children("lines"):
				var said: NpcLine = NpcLine.from_record(record, true)
				record.finish()
				if said != null:
					step.lines.append(said)
		"set_temp":
			step.kind = Kind.SET_TEMP
			step.flag = reader.required_text("set_temp")
		"unmark":
			step.kind = Kind.UNMARK
			step.flag = reader.required_text("unmark")
	return step
