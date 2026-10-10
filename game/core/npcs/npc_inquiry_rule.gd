class_name NpcInquiryRule
extends RefCounted

## One branch of an inquiry answered by a function that acts (d/green/npc/shen.c
## give_jade(), sell_drug()): the first rule whose `asker_marks` the asker all has
## decides. It says its lines, sets `mark_asker` on the asker and makes `gives`, an
## item the NPC hands over (give.c); an F_UNIQUE item that already exists somewhere
## (violate_unique()) is not made, and `taken_lines` are said instead, without the mark.
## No rule matching is the function printing nothing (command("?")): ask.c goes on to
## its own lines. The marks hold d/green's set_temp() flags (DECISIONS 青石村 B).
## A rule with a `chance` (chess_player.c play_chess(): random(100) < 50) draws once
## when its marks match; a miss goes on to the next rule. `lines` may be a list in the
## order the function prints them (say, write, say). `hands_over` is something the NPC
## carries (command("give …")), `amount` of it, told by give.c's line; `after` is said
## once it was handed over, `after_empty` when the NPC has none left.
## daemon/class/bonze/master.c ask_for_join() asks the asker's query("class") and
## query("gender") (`asker_class`, `asker_gender`: "" any) and set_temp()s a flag
## (`temp_asker`: a temp, not kept by a save, DECISIONS 晚月庄 A). `forgets` are the topics
## the NPC deletes once it answered (d/choyin/npc/girl.c's delete("inquiry/游晋")).
var asker_marks: Array[String] = []
var asker_class: StringName = &""
var asker_gender: StringName = &""
var lines: Array[NpcLine] = []
var mark_asker: String = ""
var temp_asker: String = ""
var gives: StringName = &""
var taken_lines: Array[NpcLine] = []
var chance_below: int = 0
var chance_of: int = 0
var hands_over: StringName = &""
var amount: int = 0
var after: Array[NpcLine] = []
var after_empty: Array[NpcLine] = []
## feature/vendor.c do_vendor_list() (a vendor's `(: do_vendor_list :)` topic): the
## vendor's goods and prices, write()n to the asker.
var vendor_list: bool = false
var forgets: Array[String] = []


func matches(marks: Dictionary[String, int], class_id: StringName = &"", gender: StringName = &"") -> bool:
	if (not asker_class.is_empty() and class_id != asker_class) or (not asker_gender.is_empty() and gender != asker_gender):
		return false
	for mark: String in asker_marks:
		if marks.get(mark, 0) == 0:
			return false
	return true


static func decide(rules: Array[NpcInquiryRule], marks: Dictionary[String, int], random: WorldInteractionRandomSource = null, class_id: StringName = &"", gender: StringName = &"") -> NpcInquiryRule:
	for rule: NpcInquiryRule in rules:
		if not rule.matches(marks, class_id, gender):
			continue
		if rule.chance_of > 0 and (random == null or random.legacy_random(rule.chance_of) >= rule.chance_below):
			continue
		return rule
	return null


static func from_record(reader: ContentRecordReader) -> NpcInquiryRule:
	var rule := NpcInquiryRule.new()
	rule.asker_marks = reader.text_list("asker_marks")
	rule.asker_class = StringName(reader.text("asker_class"))
	rule.asker_gender = StringName(reader.text("asker_gender"))
	if not rule.asker_gender.is_empty() and not NpcTeaching.GENDERS.has(rule.asker_gender):
		reader.fail("asker_gender", "expected one of %s" % [NpcTeaching.GENDERS])
	if reader.has("lines"):
		for line: ContentRecordReader in reader.children("lines"):
			var parsed: NpcLine = NpcLine.from_record(line)
			line.finish()
			if parsed != null:
				rule.lines.append(parsed)
	else:
		rule.lines = NpcLine.optional_lines(reader)
	var chance: ContentRecordReader = reader.child("chance")
	if chance != null:
		rule.chance_below = chance.required_integer("below")
		rule.chance_of = chance.required_integer("of")
		chance.finish()
		if rule.chance_of < 1 or rule.chance_below < 0 or rule.chance_below > rule.chance_of:
			reader.fail("chance", "needs 0 <= below <= of, of > 0")
	rule.hands_over = StringName(reader.text("hands_over"))
	rule.amount = reader.integer("amount", 0)
	for key: String in ["after", "after_empty"]:
		var said: Array[NpcLine] = []
		if reader.has(key):
			for line: ContentRecordReader in reader.children(key):
				var parsed: NpcLine = NpcLine.from_record(line)
				line.finish()
				if parsed != null:
					said.append(parsed)
		if key == "after":
			rule.after = said
		else:
			rule.after_empty = said
	if rule.hands_over.is_empty() and (rule.amount != 0 or not rule.after.is_empty() or not rule.after_empty.is_empty()):
		reader.fail("hands_over", "amount, after and after_empty go with hands_over")
	rule.vendor_list = reader.boolean("vendor_list", false)
	rule.mark_asker = reader.text("mark_asker")
	rule.temp_asker = reader.text("temp_asker")
	rule.gives = StringName(reader.text("gives"))
	rule.forgets = reader.text_list("forgets")
	var taken: ContentRecordReader = reader.child("taken")
	if taken != null:
		rule.taken_lines = NpcLine.optional_lines(taken)
		taken.finish()
		if rule.gives.is_empty():
			reader.fail("taken", "is said only instead of `gives`")
	reader.finish()
	if rule.lines.is_empty() and rule.gives.is_empty() and rule.hands_over.is_empty() and not rule.vendor_list:
		reader.fail("", "says or gives something")
	return rule
