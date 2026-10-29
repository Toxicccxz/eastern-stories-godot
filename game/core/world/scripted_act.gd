class_name ScriptedAct
extends RefCounted

## One branch of an ES2 function that acts on the player where they stand: an NPC's
## greeting() (d/latemoon/room/npc/shinyu.c: a man is shouted at, powdered, kicked out),
## a room's own command (d/latemoon/room/bathroom.c take bath, upstar/uproom3.c ponder,
## latemoon2.c search bracelet) or a carried item's (bracelet.c pray, letter.c fire).
## `gender`, `not_gender` and `not_class` say whom the branch is for (the player's
## query("gender") and query("class")); `temp` and `not_temp` a set_temp() flag the player
## has or lacks, `mark` a saved mark they have (`not_mark` one they lack: d/canyon/npc/
## vice_general.c's marks/军营) and `carries` an id something they carry
## answers to (present(id, me): letter.c's 火摺), `present` an NPC standing in the room
## (present("cook bonze"): d/sanyen/kitchen.c; one lying unconscious says nothing, 默认), `thirsty`
## that they can still drink (query("water") below max_water_capacity(): d/choyin/s_street1.c's
## well), `at_least` their force, max_force and force_factor at least so much (d/canyon/bamboo/
## bamboo3.c's stone), `room` and `not_room` a flag the act's room has or lacks (its set(), set_temp():
## bamboo3.c's exits/enter) and `exists` an item that exists somewhere in the world (F_UNIQUE's
## violate_unique(): train.c's book), `present_in` an NPC standing in another room (present(
## "meloner", find_object(melonguard)): d/village/melonfarm.c), `kar_above` rolls of
## random(kar) > random(n) that all come up (melonfarm.c's pick: [30, 10]; each drawn once
## per use, in order, and only when reached, as the LPC's nested ifs), `kar_draw` {plus, at_least} one
## roll of random(kar + plus) >= at_least (d/city/feiyuan.c's find: random(kar + 30) >= 35), drawn
## only when reached, `per_below` n one roll of random(per) < n (d/chuenyu/npc/jiading3.c's
## checklooking(): query("per"), the raw attribute), drawn the same way, `npc_in` the acting NPC standing
## in that zone (d/chuenyu/xiaojuan2.c: environment() == the 地牢's 刑房). The first branch that is for
## the player acts. `ask` is the owner's question before a choice that can kill (a man walking into
## the bath, DECISIONS 晚月庄 A), with `choice` its button. `ghost` true or false: the player is a
## ghost or not (is_ghost(): d/death/npc/bgargoyle.c death_stage()). The steps run in order:
## - a line (NpcLine: say, emote, line, whisper, in its colour; a room's message_vision()
##   written as the player reads it, 你 for $N);
## - `damage` {gin, kee, sen}: receive_damage() on the player;
## - `hurt` {gin?, kee?, sen?: {base, random}}: set("eff_kee", query("eff_kee") - n) and set("kee",
##   query("kee") - n) with n = base + random(random) (d/chuenyu/trap_castle.c's arrows, center.c's fall);
## - `heal` (gin, kee or sen) `base` + random(`random`): receive_heal();
## - `condition` with `duration`: apply_condition() (it replaces the one there);
## - `calm` n: a bellicosity above 0 goes down random(kar) + n (uproom3.c);
## - `npc_force` n: the NPC's own force grows by n (this_object()->add("force", n));
## - `close_door`: the NPC's command("close door"), on the door the player came by;
## - `move` (a zone, on any map) to `point`: ob->move(), the player taken there;
## - `kill`: kill_ob(player) and the player's fight_ob(): a fight to the death;
## - `give` (an item) `unless_temp`: the item new()'d to the player, unless they carry the
##   set_temp() flag already (which the gift sets), then its `lines`; `give_one_of` (items)
##   new()s the one random(how many) picks (d/choyin/club.c's switch(random(3)));
## - `set_temp` a flag: set_temp(flag, 1) on the player (saved, as all of them);
## - `clear_temp` a flag: set_temp(flag, 0) (d/canyon/canyon4.c's 军营/swear, spent by the oath);
## - `set_room`, `clear_room` a flag of the act's room (bamboo3.c's set("exits/enter"), delete());
## - `unmark` a mark: delete("mark/<mark>") (latemoon8.c's dance-book);
## - `water` n: add("water", n) (s_street1.c's well; above the capacity too, as add() does);
## - `comes` (an NPC) `from` (a zone): the first of them standing there comes beside the player
##   (ob->move(this room): melonfarm.c's 瓜农) and is the act's NPC from then on;
## - `npc_flag` a flag: the NPC's own set_temp(flag, 1) (an object variable, saved with it);
## - `mark` a mark: set("marks/<mark>", 1) on the player (xiaojuan2.c's marks/老刘);
## - `npc_mood` a mood of the NPC's (NpcMood: oldliu.c killhim()'s title, temporary applies and
##   chat), lasting until its room resets;
## - `npc_wield` an item: carry_object(item)->wield(), a new one in the NPC's hand;
## - `leave`: the NPC leaves for good (oldliu.c destruct(): it is not made anew), or, naming
##   an NPC definition, the first of them standing by leaves with it (刘老农领着娟儿匆匆离去);
## - `by` (an NPC definition; native, 主线 A, DECISIONS「剧情演出」): the first of them standing in
##   the room is the act's NPC from then on (its lines in its bubble, its leave, its drop), as
##   `comes` makes the comer so; one not there leaves the act's NPC as it was;
## - `drop` (an item; native): a new one lies down at the act's NPC's feet (at the player's
##   for a room's act), as something let fall in a scene;
## - `reincarnate`: damage.c reincarnate() and ob->move(REVIVE_ROOM) (d/death/npc/wgargoyle.c
##   death_stage(), inn1.c do_stuff()): the ghost lives again at the Snow temple. It is the
##   act's last step; the session makes the move once the act's map has had its beat
##   (WorldSessionController.request_reincarnation()).
enum Kind { LINE, DAMAGE, HEAL, CONDITION, CALM, NPC_FORCE, CLOSE_DOOR, MOVE, KILL, GIVE, SET_TEMP, CLEAR_TEMP, UNMARK, WATER, SET_ROOM, CLEAR_ROOM, COMES, NPC_FLAG, HURT, MARK, NPC_MOOD, NPC_WIELD, LEAVE, REINCARNATE, BY, DROP }

## The resources receive_damage() and receive_heal() name.
const RESOURCES: Array[String] = ["gin", "kee", "sen"]
## What `at_least` may ask of the player: query("force"), query("max_force"), query("force_factor").
const NUMBERS: Array[String] = ["force", "max_force", "force_factor"]

var gender: StringName = &""
var not_gender: StringName = &""
var not_class: StringName = &""
var temp: String = ""
var not_temp: String = ""
var mark: String = ""
var not_mark: String = ""
var carries: String = ""
## An NPC definition present() in the room.
var present: StringName = &""
var thirsty: bool = false
var at_least: Dictionary[String, int] = {}
var room: String = ""
var not_room: String = ""
var exists: StringName = &""
## present_in: an NPC definition standing in another zone.
var present_in_npc: StringName = &""
var present_in_zone: StringName = &""
## The n of each random(kar) > random(n) that must come up, in order.
var kar_above: Array[int] = []
## kar_draw: random(kar + plus) at least `at_least` (0 plus and 0 at_least: no roll).
var kar_draw_plus: int = 0
var kar_draw_at_least: int = 0
## per_below: random(per) below it (0: no roll).
var per_below: int = 0
## npc_in: the zone the acting NPC stands in.
var npc_in: StringName = &""
## is_ghost(): -1 either, 0 a living player only, 1 a ghost only.
var ghost_state: int = -1
var ask: String = ""
var choice: String = ""
var steps: Array[Step] = []


## What a branch may ask of the player besides gender and class: their saved marks, their
## set_temp() flags, the ids of what they carry directly (present(id, me)) and the NPCs
## standing where they stand (present(), by definition); the flags of the act's room and
## which items exist in the world.
class Facts:
	extends RefCounted
	var marks: Dictionary[String, int] = {}
	var temps: Dictionary[String, int] = {}
	var carried: Array[String] = []
	var present_npcs: Array[StringName] = []
	## query("water") below max_water_capacity().
	var thirsty: bool = false
	## force, max_force and force_factor (NUMBERS).
	var numbers: Dictionary[String, int] = {}
	var room: Dictionary[String, int] = {}
	## item definition ID -> whether one exists somewhere in the world; none: nothing does.
	var item_exists: Callable = Callable()
	## (NPC definition ID, zone ID) -> whether one stands there (conscious); none: nobody does.
	var standing_in: Callable = Callable()
	## query("kar") and MudOS random(n) for `kar_above`; without a draw the rolls are not made
	## and count as coming up (whether a branch could be for the player: its button).
	var kar: int = 0
	## query("per") for `per_below`, drawn as the kar rolls are.
	var per: int = 0
	## is_ghost() of the player (`ghost`).
	var ghost: bool = false
	## Where the acting NPC stands (`npc_in`); "" without one.
	var npc_zone: StringName = &""
	var draw: Callable = Callable()
	var _rolls: Array[bool] = []
	var _kar_drawn: int = -1
	var _per_drawn: int = -1

	## Whether random(kar) > random(bound), the `index`-th roll of this use: drawn once, the
	## first time it is reached (random(n) with n <= 0 is 0, DECISIONS' global rule).
	func kar_roll(index: int, bound: int) -> bool:
		if not draw.is_valid():
			return true
		while _rolls.size() <= index:
			var mine: int = int(draw.call(kar)) if kar > 0 else 0
			var theirs: int = int(draw.call(bound)) if bound > 0 else 0
			_rolls.append(mine > theirs)
		return _rolls[index]

	## Whether random(kar + plus) >= at_least: drawn once per use, when first reached (without a
	## draw it counts as coming up, as kar_roll()).
	func kar_draw(plus: int, at_least: int) -> bool:
		if not draw.is_valid():
			return true
		if _kar_drawn < 0:
			var bound: int = kar + plus
			_kar_drawn = int(draw.call(bound)) if bound > 0 else 0
		return _kar_drawn >= at_least

	## Whether random(per) < below: drawn once per use, when first reached (without a draw it
	## counts as coming up, as kar_roll()).
	func per_roll(below: int) -> bool:
		if not draw.is_valid():
			return true
		if _per_drawn < 0:
			_per_drawn = int(draw.call(per)) if per > 0 else 0
		return _per_drawn < below

	## Whether every roll up to `bounds` comes up, drawing only as far as they do.
	func kar_rolls(bounds: Array[int]) -> bool:
		for index: int in bounds.size():
			if not kar_roll(index, bounds[index]):
				return false
		return true


class Step:
	extends RefCounted
	var kind: Kind
	var line: NpcLine
	## damage: by resource name; hurt: the base by resource name, with `randoms`.
	var amounts: Dictionary[String, int] = {}
	var randoms: Dictionary[String, int] = {}
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
	## comes: the NPC definition (from `zone_id`).
	var npc_id: StringName = &""
	## give: the item, the set_temp() flag, what is said after; give_one_of: the items drawn among.
	var item_id: StringName = &""
	var pick: Array[StringName] = []
	var unless_temp: String = ""
	var lines: Array[NpcLine] = []
	## set_temp, clear_temp, unmark, mark, set_room, clear_room, npc_flag, npc_mood: the flag,
	## mark or mood.
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
		and (not_mark.is_empty() or known.marks.get(not_mark, 0) == 0)
		and (carries.is_empty() or known.carried.has(carries))
		and (present.is_empty() or known.present_npcs.has(present))
		and (not thirsty or known.thirsty)
		and at_least.keys().all(func(key: String) -> bool: return known.numbers.get(key, 0) >= at_least[key])
		and (room.is_empty() or known.room.get(room, 0) != 0)
		and (not_room.is_empty() or known.room.get(not_room, 0) == 0)
		and (exists.is_empty() or (known.item_exists.is_valid() and bool(known.item_exists.call(exists))))
		and (present_in_npc.is_empty() or (known.standing_in.is_valid() and bool(known.standing_in.call(present_in_npc, present_in_zone))))
		and (npc_in.is_empty() or known.npc_zone == npc_in)
		and (ghost_state < 0 or known.ghost == (ghost_state == 1))
		# Last: the rolls draw, and only for a branch otherwise for the player.
		and (kar_above.is_empty() or known.kar_rolls(kar_above))
		and (kar_draw_at_least <= 0 or known.kar_draw(kar_draw_plus, kar_draw_at_least))
		and (per_below <= 0 or known.per_roll(per_below))
	)


## The first branch of `acts` that is for the player; null when none is.
static func first_for(acts: Array[ScriptedAct], player_gender: StringName, class_id: StringName, facts: Facts = null) -> ScriptedAct:
	for act: ScriptedAct in acts:
		if act.applies_to(player_gender, class_id, facts):
			return act
	return null


## Whether a branch is drawn for (`kar_above`, `kar_draw`, `per_below`): it is chosen when the command runs.
func draws() -> bool:
	return not kar_above.is_empty() or kar_draw_at_least > 0 or per_below > 0


## Whether a step takes the player elsewhere (the caller closes what they had open).
func moves_player() -> bool:
	return steps.any(func(step: Step) -> bool: return step.kind == Kind.MOVE)


## Whether a step hurts, poisons, attacks or moves the player (a greeting that does so keeps
## ES2's second to walk past: DECISIONS「响应性」).
func harms_player() -> bool:
	return steps.any(func(step: Step) -> bool: return step.kind in [Kind.DAMAGE, Kind.HURT, Kind.CONDITION, Kind.KILL, Kind.MOVE])


## Whether a step brings the ghost back to life (`reincarnate`).
func reincarnates() -> bool:
	return steps.any(func(step: Step) -> bool: return step.kind == Kind.REINCARNATE)


## What the steps' receive_damage() takes from each resource it would take below zero
## (the player would fall unconscious on the next heart beat), in gin, kee, sen order.
func fainting_costs(state: CharacterState) -> Dictionary[String, int]:
	var spent: Dictionary[String, int] = {}
	for step: Step in steps:
		if step.kind == Kind.DAMAGE or step.kind == Kind.HURT:
			# A hurt's roll at its worst: random(n) is at most n - 1.
			for key: String in step.amounts:
				spent[key] = spent.get(key, 0) + step.amounts[key] + maxi(step.randoms.get(key, 0) - 1, 0)
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


## {gender?, not_gender?, not_class?, temp?, not_temp?, mark?, not_mark?, carries?, present?, thirsty?,
## at_least?: {force?, max_force?, force_factor?}, room?, not_room?, exists?, present_in?: {npc, zone},
## kar_above?: [n], kar_draw?, per_below?, npc_in?, ask?, choice?, steps: [step]}.
static func from_record(reader: ContentRecordReader) -> ScriptedAct:
	var act := ScriptedAct.new()
	act.gender = StringName(reader.text("gender"))
	act.not_gender = StringName(reader.text("not_gender"))
	act.not_class = StringName(reader.text("not_class"))
	act.temp = reader.text("temp")
	act.not_temp = reader.text("not_temp")
	act.mark = reader.text("mark")
	act.not_mark = reader.text("not_mark")
	act.carries = reader.text("carries")
	act.present = StringName(reader.text("present"))
	act.thirsty = reader.boolean("thirsty", false)
	var numbers: ContentRecordReader = reader.child("at_least")
	if numbers != null:
		for key: String in numbers.keys():
			if not NUMBERS.has(key):
				numbers.fail(key, "expected one of %s" % [NUMBERS])
			act.at_least[key] = numbers.required_integer(key)
		numbers.finish()
	act.room = reader.text("room")
	act.not_room = reader.text("not_room")
	act.exists = StringName(reader.text("exists"))
	var elsewhere: ContentRecordReader = reader.child("present_in")
	if elsewhere != null:
		act.present_in_npc = StringName(elsewhere.required_text("npc"))
		act.present_in_zone = StringName(elsewhere.required_text("zone"))
		elsewhere.finish()
	for bound: int in reader.integer_list("kar_above"):
		if bound <= 0:
			reader.fail("kar_above", "each roll's bound is positive")
		act.kar_above.append(bound)
	var kar_draw: ContentRecordReader = reader.child("kar_draw")
	if kar_draw != null:
		act.kar_draw_plus = kar_draw.required_integer("plus")
		act.kar_draw_at_least = kar_draw.required_integer("at_least")
		kar_draw.finish()
		if act.kar_draw_plus < 0 or act.kar_draw_at_least <= 0:
			reader.fail("kar_draw", "plus is 0 or more and at_least positive")
		if not act.kar_above.is_empty():
			reader.fail("kar_draw", "a branch rolls kar_above or kar_draw, not both")
	act.per_below = reader.integer("per_below", 0)
	if reader.has("per_below") and act.per_below <= 0:
		reader.fail("per_below", "must be positive")
	act.npc_in = StringName(reader.text("npc_in"))
	if reader.has("ghost"):
		act.ghost_state = 1 if reader.boolean("ghost", false) else 0
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
	for key: String in ["damage", "hurt", "heal", "condition", "calm", "npc_force", "close_door", "move", "kill", "give", "give_one_of", "set_temp", "clear_temp", "unmark", "mark", "water", "set_room", "clear_room", "comes", "npc_flag", "npc_mood", "npc_wield", "leave", "reincarnate", "by", "drop"]:
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
		"hurt":
			step.kind = Kind.HURT
			var hurts: ContentRecordReader = reader.child("hurt")
			if hurts == null:
				reader.fail("hurt", "expected {gin?, kee?, sen?: {base, random}}")
				return null
			for key: String in hurts.keys():
				if not RESOURCES.has(key):
					hurts.fail(key, "expected one of %s" % [RESOURCES])
				var roll: ContentRecordReader = hurts.child(key)
				if roll == null:
					hurts.fail(key, "expected {base, random}")
					continue
				step.amounts[key] = roll.required_integer("base")
				step.randoms[key] = roll.integer("random", 0)
				roll.finish()
				if step.amounts[key] < 0 or step.randoms[key] < 0:
					hurts.fail(key, "base and random must not be negative")
			hurts.finish()
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
		"give", "give_one_of":
			step.kind = Kind.GIVE
			if kinds[0] == "give":
				step.item_id = StringName(reader.required_text("give"))
			else:
				for id: String in reader.text_list("give_one_of"):
					step.pick.append(StringName(id))
				if step.pick.size() < 2:
					reader.fail("give_one_of", "draws among two items or more")
			step.unless_temp = reader.text("unless_temp")
			for record: ContentRecordReader in reader.children("lines"):
				var said: NpcLine = NpcLine.from_record(record, true)
				record.finish()
				if said != null:
					step.lines.append(said)
		"set_temp":
			step.kind = Kind.SET_TEMP
			step.flag = reader.required_text("set_temp")
		"clear_temp":
			step.kind = Kind.CLEAR_TEMP
			step.flag = reader.required_text("clear_temp")
		"unmark":
			step.kind = Kind.UNMARK
			step.flag = reader.required_text("unmark")
		"set_room":
			step.kind = Kind.SET_ROOM
			step.flag = reader.required_text("set_room")
		"clear_room":
			step.kind = Kind.CLEAR_ROOM
			step.flag = reader.required_text("clear_room")
		"comes":
			step.kind = Kind.COMES
			step.npc_id = StringName(reader.required_text("comes"))
			step.zone_id = StringName(reader.required_text("from"))
		"npc_flag":
			step.kind = Kind.NPC_FLAG
			step.flag = reader.required_text("npc_flag")
		"mark":
			step.kind = Kind.MARK
			step.flag = reader.required_text("mark")
		"npc_mood":
			step.kind = Kind.NPC_MOOD
			step.flag = reader.required_text("npc_mood")
		"npc_wield":
			step.kind = Kind.NPC_WIELD
			step.item_id = StringName(reader.required_text("npc_wield"))
		"leave":
			step.kind = Kind.LEAVE
			# true: the NPC itself; a definition: the first of them standing by.
			if reader.is_text("leave"):
				step.npc_id = StringName(reader.required_text("leave"))
			elif not reader.boolean("leave", false):
				reader.fail("leave", "is true or names the NPC that leaves with it")
		"reincarnate":
			step.kind = Kind.REINCARNATE
			if not reader.boolean("reincarnate", false):
				reader.fail("reincarnate", "is true when present")
		"water":
			step.kind = Kind.WATER
			step.value = reader.required_integer("water")
			if step.value <= 0:
				reader.fail("water", "must be positive")
		"by":
			step.kind = Kind.BY
			step.npc_id = StringName(reader.required_text("by"))
		"drop":
			step.kind = Kind.DROP
			step.item_id = StringName(reader.required_text("drop"))
	return step
