class_name NpcMood
extends RefCounted

## A state a function puts an NPC in for the rest of the story (d/village/npc/oldliu.c
## killhim(): set("title", "悲愤欲绝"), set_temp("apply/…"), a new chat): its `title`, the
## `applies` it adds (set_temp("apply/<key>", n); combatd.c reads apply/damage, skill.c
## query_skill() apply/<skill>: whatever else it sets nobody reads, as in ES2), the NPC
## `flags` it holds (kill_ob()'s hatred) and its chat (`chat_chance` with `chat_msg`, which
## replace the definition's). It lasts until the NPC's room resets (owner, 黑松山 plan M7, 默认).

## The NPC flag that holds a mood: mood/<name> (an object variable, saved with it).
const FLAG_PREFIX: String = "mood/"

var name: String = ""
var title: String = ""
var applies: Dictionary[String, int] = {}
var flags: Array[StringName] = []
## NpcTalk with only the mood's chat; null when it keeps the definition's.
var talk: NpcTalk = null


func flag() -> StringName:
	return StringName(FLAG_PREFIX + name)


## {title?, applies?: {key: n}, flags?: [flag], chat_chance?, chat_msg?} (chat_msg as the NPC
## record's).
static func from_record(mood_name: String, reader: ContentRecordReader) -> NpcMood:
	var mood := NpcMood.new()
	mood.name = mood_name
	mood.title = reader.text("title")
	mood.applies = reader.integer_map("applies")
	for flag_name: String in reader.text_list("flags"):
		mood.flags.append(StringName(flag_name))
	if reader.has("chat_chance") != reader.has("chat_msg"):
		reader.fail("chat_chance", "chat_chance and chat_msg come together")
	elif reader.has("chat_msg"):
		mood.talk = NpcTalk.new({}, reader.required_integer("chat_chance"), NpcContentRecords.chat_entries(reader, "chat_msg", false))
	reader.finish()
	if mood_name.is_empty() or (mood.title.is_empty() and mood.applies.is_empty() and mood.flags.is_empty() and mood.talk == null):
		reader.fail("", "a mood changes something")
	return mood
