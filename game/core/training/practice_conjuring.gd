class_name PracticeConjuring
extends RefCounted

## necromancy.c practice_skill() once its costs are paid: random(sen) below `chance_below`
## and the practice conjures an NPC against the one practising instead of improving.
## Which one: random(query_skill(`skill`, 1)), the first of `npcs` whose `below` it is
## under, else the last (mind_bug below 10, else mind_beast). While the one conjured
## still stands (query_temp("mind_bug")), practice_skill() refuses with `standing`.
## The lines name the NPC as $N.
var chance_below: int
var skill_id: StringName
var npc_ids: Array[StringName] = []
## below[i] for npc_ids[i]; the last has none (any draw).
var below: Array[int] = []
var came: String
var caught: String
var standing: String


func is_valid() -> bool:
	return (
		chance_below > 0 and not skill_id.is_empty() and not npc_ids.is_empty() and below.size() == npc_ids.size() - 1
		and not came.is_empty() and not caught.is_empty() and not standing.is_empty()
	)


## The NPC the practice of `character` conjures now, or "" when the draw keeps the mind
## clear. `random` is a legacy_random() (random(0) is 0: no sen left always conjures).
func draw(character: CharacterState, random: Callable) -> StringName:
	if random.call(character.spirit.current) >= chance_below:
		return &""
	var rnd: int = random.call(character.skills.raw_level(skill_id))
	for index: int in range(below.size()):
		if rnd < below[index]:
			return npc_ids[index]
	return npc_ids[npc_ids.size() - 1]


## `conjure` {"below", "skill", "npcs": [{"npc", "below"?}], "came", "caught", "standing"}.
static func from_record(reader: ContentRecordReader) -> PracticeConjuring:
	var conjuring := PracticeConjuring.new()
	conjuring.chance_below = reader.required_integer("below")
	conjuring.skill_id = StringName(reader.required_text("skill"))
	var choices: Array[ContentRecordReader] = reader.children("npcs")
	for index: int in range(choices.size()):
		var choice: ContentRecordReader = choices[index]
		conjuring.npc_ids.append(StringName(choice.required_text("npc")))
		if index < choices.size() - 1:
			conjuring.below.append(choice.required_integer("below"))
		choice.finish()
	conjuring.came = reader.required_text("came")
	conjuring.caught = reader.required_text("caught")
	conjuring.standing = reader.required_text("standing")
	reader.finish()
	if not conjuring.is_valid():
		reader.fail("", "needs a positive below, the skill, npcs (each but the last with its below) and the three lines")
	return conjuring
