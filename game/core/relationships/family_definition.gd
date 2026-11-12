class_name FamilyDefinition
extends RefCounted

## A family (门派) by its ES2 family_name. Characters keep the ID (FamilyState);
## NPC records name the family as their create_family() does.
## 战斗拍数 D (DECISIONS「战斗拍数 D」, native): a family's schools may each have a guide
## (`guides`: the disciple who explains the school's way in their own words and spars three
## harmless rounds to show it) and the town's hearsay about them (`hearsay`: lines hung on
## other NPCs' 打听 topics, heard one by one). Lines may carry {requires}: the master's
## conditions (胆识 20、定力 20) read from his `apprentice.requires`, kept in one place.
var family_id: StringName
var display_name: String
var guides: Array[SchoolGuide] = []
var hearsay: Array[Hearsay] = []
## Where the guides and hearsay come from (native work, named in the data); "" for none.
var origin: String = ""
## The 百科's 门派 entry (DECISIONS「百科重写」): what a traveller hears of the family, shown once
## one of its people is met; `head_id` its head (an NPC id; "" none), named with `seat` (where
## they sit, player text) once that person is met too.
var intro: String = ""
var head_id: StringName = &""
var seat: String = ""


## One school's guide: `npc_id` the disciple, `master_id` whose `requires` the lines quote,
## `teach` what 请教打法 says, `lesson` the three rounds' lines, the verdicts and the refusals.
class SchoolGuide:
	extends RefCounted
	var skill_id: StringName
	var npc_id: StringName
	var master_id: StringName
	var teach: Array[String] = []
	## The 打听 topic the guide answers with `teach` (请教打法 opens it).
	var teach_topic: String = ""
	## Said as each of the three rounds begins (fewer: the rest say nothing).
	var rounds: Array[String] = []
	## The one line after the rounds: the guide won a beat its way (`earned`), never did
	## (`not_earned`), or the player won one the same way (`player_earned`, first).
	var earned: String = ""
	var not_earned: String = ""
	var player_earned: String = ""
	## Why the guide will not spar now: the player is hurt, or of another family.
	var refuse_hurt: String = ""
	var refuse_family: String = ""
	## What the guide says taking the player on (a default when "").
	var accept: String = ""

	func rounds_count() -> int:
		return rounds.size()


## One line of hearsay: said by `npc_id` when asked `topic` (as an inquiry rule put first on
## that topic), about `skill_id` ("" for a line that belongs to no school: the doctor's
## "no wound"); `asker_marks` the marks the asker must hold (the doctor reads the wound's
## school from `wounded_by/<skill>`).
class Hearsay:
	extends RefCounted
	var skill_id: StringName
	var npc_id: StringName
	var topic: String
	var say: String
	var asker_marks: Array[String] = []
	## CombatInsights' key for having heard it (hearsay/<skill>/<n>); "" for a line of no school.
	var key: String = ""


func _init(p_family_id: StringName = &"", p_display_name: String = "") -> void:
	family_id = p_family_id
	display_name = p_display_name


## The guide of `skill_id`, or null.
func guide_for(skill_id: StringName) -> SchoolGuide:
	for guide: SchoolGuide in guides:
		if guide.skill_id == skill_id:
			return guide
	return null


static func from_record(reader: ContentRecordReader) -> FamilyDefinition:
	var definition := FamilyDefinition.new(StringName(reader.required_text("id")), reader.required_text("name"))
	definition.origin = reader.text("origin")
	definition.intro = reader.text("intro")
	definition.head_id = StringName(reader.text("head"))
	definition.seat = reader.text("seat")
	if definition.seat.is_empty() != definition.head_id.is_empty():
		reader.fail("seat", "a head and their seat go together")
	for record: ContentRecordReader in reader.children("guides"):
		var guide := SchoolGuide.new()
		guide.skill_id = StringName(record.required_text("skill"))
		guide.npc_id = StringName(record.required_text("npc"))
		guide.master_id = StringName(record.text("master"))
		guide.teach = record.text_list("teach")
		guide.teach_topic = record.text("teach_topic", "打法")
		if guide.teach.is_empty():
			record.fail("teach", "the guide needs lines to teach")
		var lesson: ContentRecordReader = record.child("lesson")
		if lesson != null:
			guide.rounds = lesson.text_list("rounds")
			guide.earned = lesson.text("earned")
			guide.not_earned = lesson.text("not_earned")
			guide.player_earned = lesson.text("player_earned")
			guide.refuse_hurt = lesson.text("refuse_hurt")
			guide.refuse_family = lesson.text("refuse_family")
			guide.accept = lesson.text("accept")
			if guide.rounds.is_empty() or guide.earned.is_empty() or guide.not_earned.is_empty():
				lesson.fail("", "needs rounds, earned and not_earned")
			lesson.finish()
		if definition.guide_for(guide.skill_id) != null:
			record.fail("skill", "'%s' already has a guide" % guide.skill_id)
		definition.guides.append(guide)
		record.finish()
	var counts: Dictionary[StringName, int] = {}
	for record: ContentRecordReader in reader.children("hearsay"):
		var line := Hearsay.new()
		line.skill_id = StringName(record.text("skill"))
		line.npc_id = StringName(record.required_text("npc"))
		line.topic = record.required_text("topic")
		line.say = record.required_text("say")
		line.asker_marks = record.text_list("asker_marks")
		if not line.skill_id.is_empty():
			counts[line.skill_id] = counts.get(line.skill_id, 0) + 1
			line.key = "%s%s/%d" % [CombatInsights.HEARSAY, line.skill_id, counts[line.skill_id]]
		definition.hearsay.append(line)
		record.finish()
	reader.finish()
	return definition
