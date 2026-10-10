class_name ZoneExitRuleDefinition
extends RefCounted

## A room's valid_leave() that refuses one way out while a condition holds:
## d/waterfog/entrance.c (north with a weapon in hand while a 水烟阁武士 is there),
## d/green/entrance.c (east into the 迷阵 below 100000 combat_exp),
## d/green/outdoor.c (enter only for 绝尘子's apprentices: family/master_id),
## d/temple/road2.c (enter only for 茅山派: family/family_name) and d/temple/road1.c
## (random(kar) < 3 slips on the moss: unconcious() and no way through).
## The player stays where they are and reads `lines`: the room's message() and then
## notify_fail(). `present` is the NPC that must be in the room (present() finds one
## lying unconscious too; a dead one is a corpse). The way out may be a walk into the
## next zone or a passage (portal) from `from_zone` to `to_zone`. `pass_lines` are what
## the room's message_vision() tells one who goes through (book_room1.c's 拉开门大步走了
## 出去); a rule `never` refuses nobody and only says them.
## `ask` is no valid_leave(): the owner's question before a way in that can kill (晚月庄
## plan Q2: a man walking into the changing room). Anyone not of `unless_gender` is
## stopped and asked (`ask`, `choice`); one who chooses to go is put at `point` inside. It
## guards a walk between two zones of one map, never a passage (the catalog checks): a
## passage's own bookkeeping (its mark, its arrival) would be skipped by that move.
## `takes_back` (d/latemoon/latemoon3.c) refuses nobody: one who carries the `item` and
## the set_temp() flag `temp` hands it back (`taken`, the flag deleted); one who carries
## none reads `without`; one who carries it without the flag keeps it, without a word.
## With `items` instead (d/choyin/club.c: the hermit's books, any of their drawn names) and
## no flag, every one carried goes back, each told by `taken`.
## `no_mark` (d/choyin/entrance.c: east into the 桃林 only with marks/书生) refuses one without
## the saved `mark`.
enum Condition { WEAPON_IN_HAND, COMBAT_EXP_BELOW, NOT_APPRENTICE_OF, NOT_FAMILY, KAR_SLIP, NEVER, ASK, TAKES_BACK, NO_MARK }

const CONDITIONS: Dictionary[String, Condition] = {
	"weapon_in_hand": Condition.WEAPON_IN_HAND,
	"combat_exp_below": Condition.COMBAT_EXP_BELOW,
	"not_apprentice_of": Condition.NOT_APPRENTICE_OF,
	"not_family": Condition.NOT_FAMILY,
	"kar_slip": Condition.KAR_SLIP,
	"never": Condition.NEVER,
	"ask": Condition.ASK,
	"takes_back": Condition.TAKES_BACK,
	"no_mark": Condition.NO_MARK,
}

var rule_id: StringName
var room_id: StringName
var from_zone_id: StringName
var to_zone_id: StringName
var condition: Condition
var present_npc_id: StringName
## combat_exp_below: the combat_exp the player needs; kar_slip: random(kar) below it slips.
var value: int = 0
## not_apprentice_of: the master (an NPC definition ID) whose apprentices may pass.
var npc_id: StringName
## not_family: the family (a families.json ID) whose members may pass.
var family_id: StringName
var lines: Array[String] = []
var pass_lines: Array[String] = []
var legacy_source_path: String
## ask: who walks in unasked, the question, its button and where the player is put.
var unless_gender: StringName = &""
var ask: String = ""
var choice: String = ""
var point_id: StringName = &""
## takes_back: the item, the flag, what the hand-back says and what leaving without it says;
## `items`: all of these go back (named forms too), no flag asked.
var item_id: StringName = &""
var item_ids: Array[StringName] = []
var temp: String = ""
var taken: Array[NpcLine] = []
var without: Array[String] = []
## no_mark: the saved mark (CharacterState marks) one needs to pass.
var mark: String = ""

## kar_slip: the refused leaver also falls unconscious (unconcious()).
var knocks_out: bool:
	get: return condition == Condition.KAR_SLIP

## ask: the way is asked about first (the rule stops one who has not chosen to go yet).
var asks: bool:
	get: return condition == Condition.ASK


## What a rule looks at when the player tries to leave. `draw` is MudOS random(n) on
## the world's interaction stream; kar_slip draws once each time its rule is asked.
class Leaver:
	extends RefCounted
	var weapon_in_hand: bool
	var combat_exp: int
	var master_id: StringName
	var family_id: StringName
	## query("kar"): the attribute as set, without karma_modifier.
	var kar: int
	var draw: Callable
	var gender: StringName = &""
	## The saved marks (query("marks/<name>")).
	var marks: Dictionary = {}

	func _init(
		p_weapon_in_hand: bool = false, p_combat_exp: int = 0, p_master_id: StringName = &"",
		p_family_id: StringName = &"", p_kar: int = 0, p_draw: Callable = Callable(), p_gender: StringName = &"",
	) -> void:
		weapon_in_hand = p_weapon_in_hand
		combat_exp = p_combat_exp
		master_id = p_master_id
		family_id = p_family_id
		kar = p_kar
		draw = p_draw
		gender = p_gender

	static func of(state: CharacterState, p_draw: Callable = Callable()) -> Leaver:
		var leaver := Leaver.new(
			not state.equipment.is_primary_hand_empty(), state.progression.combat_experience,
			state.apprenticeship.master_teacher_id, state.family.family_id, state.attributes.karma, p_draw,
			state.gender,
		)
		leaver.marks = state.marks.duplicate()
		return leaver


## Whether the rule stops `leaver`, with `present` true when an NPC of
## `present_npc_id` is in the room.
func refuses(leaver: Leaver, present: bool) -> bool:
	match condition:
		Condition.WEAPON_IN_HAND:
			return leaver.weapon_in_hand and present
		Condition.COMBAT_EXP_BELOW:
			return leaver.combat_exp < value
		Condition.NOT_APPRENTICE_OF:
			return leaver.master_id != npc_id
		Condition.NOT_FAMILY:
			return leaver.family_id != family_id
		Condition.KAR_SLIP:
			# random(n) with n <= 0 is 0 without a draw (DECISIONS' global rule).
			var drawn: int = 0 if leaver.kar <= 0 or not leaver.draw.is_valid() else int(leaver.draw.call(leaver.kar))
			return drawn < value
		Condition.ASK:
			return leaver.gender != unless_gender
		Condition.NO_MARK:
			return int(leaver.marks.get(mark, 0)) == 0
	return false


## {id, room, from_zone, to_zone, when, lines: [line], pass_lines?: [line], legacy_source}
## and per `when`: weapon_in_hand {present: npc id}, combat_exp_below {value},
## not_apprentice_of {npc}, not_family {family}, kar_slip {value}, no_mark {mark}, never (pass_lines only),
## ask {unless_gender, ask, choice, point; no lines}, takes_back {item, temp | items, taken:
## [NpcLine record], without: [line]; no lines}.
static func from_record(reader: ContentRecordReader) -> ZoneExitRuleDefinition:
	var rule := ZoneExitRuleDefinition.new()
	rule.rule_id = StringName(reader.required_text("id"))
	rule.room_id = StringName(reader.required_text("room"))
	rule.from_zone_id = StringName(reader.required_text("from_zone"))
	rule.to_zone_id = StringName(reader.required_text("to_zone"))
	var when: String = reader.required_text("when")
	if not CONDITIONS.has(when):
		reader.fail("when", "expected one of %s" % ", ".join(CONDITIONS.keys()))
	rule.condition = CONDITIONS.get(when, Condition.WEAPON_IN_HAND)
	match rule.condition:
		Condition.WEAPON_IN_HAND:
			rule.present_npc_id = StringName(reader.required_text("present"))
		Condition.COMBAT_EXP_BELOW, Condition.KAR_SLIP:
			rule.value = reader.required_integer("value")
			if rule.value <= 0:
				reader.fail("value", "must be positive")
		Condition.NOT_APPRENTICE_OF:
			rule.npc_id = StringName(reader.required_text("npc"))
		Condition.NOT_FAMILY:
			rule.family_id = StringName(reader.required_text("family"))
		Condition.NO_MARK:
			rule.mark = reader.required_text("mark")
		Condition.ASK:
			rule.unless_gender = StringName(reader.required_text("unless_gender"))
			rule.ask = reader.required_text("ask")
			rule.choice = reader.required_text("choice")
			rule.point_id = StringName(reader.required_text("point"))
		Condition.TAKES_BACK:
			for id: String in reader.text_list("items"):
				rule.item_ids.append(StringName(id))
			if rule.item_ids.is_empty():
				rule.item_id = StringName(reader.required_text("item"))
				rule.temp = reader.required_text("temp")
			elif reader.has("item") or reader.has("temp"):
				reader.fail("items", "items go back without item or temp")
			for record: ContentRecordReader in reader.children("taken"):
				var line: NpcLine = NpcLine.from_record(record, true)
				record.finish()
				if line != null:
					rule.taken.append(line)
			rule.without.assign(reader.text_list("without"))
	rule.lines.assign(reader.text_list("lines"))
	rule.pass_lines.assign(reader.text_list("pass_lines"))
	if rule.condition == Condition.NEVER:
		if not rule.lines.is_empty() or rule.pass_lines.is_empty():
			reader.fail("pass_lines", "a rule that never refuses only says its pass_lines")
	elif rule.condition == Condition.ASK or rule.condition == Condition.TAKES_BACK:
		if not rule.lines.is_empty() or not rule.pass_lines.is_empty():
			reader.fail("lines", "an ask or takes_back rule says only its own lines")
		if rule.condition == Condition.TAKES_BACK and rule.taken.is_empty():
			reader.fail("taken", "the hand-back is told")
	elif rule.lines.is_empty():
		reader.fail("lines", "a refusal says why")
	rule.legacy_source_path = reader.required_text("legacy_source")
	reader.finish()
	return rule
