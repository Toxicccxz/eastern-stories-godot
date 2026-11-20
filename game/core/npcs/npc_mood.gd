class_name NpcMood
extends RefCounted

## A state a function puts an NPC in for the rest of the story (d/village/npc/oldliu.c
## killhim(): set("title", "悲愤欲绝"), set_temp("apply/…"), a new chat): its `title`, the
## `applies` it adds (set_temp("apply/<key>", n); combatd.c reads apply/damage, skill.c
## query_skill() apply/<skill>: whatever else it sets nobody reads, as in ES2), the NPC
## `flags` it holds (kill_ob()'s hatred) and its chat (`chat_chance` with `chat_msg`, which
## replace the definition's). It lasts until the NPC's room resets (owner, 黑松山 plan M7, 默认),
## unless it is `lasting` (d/snow/npc/guard.c ask_me()'s set("revealed", 1): an object
## variable no reset touches; DECISIONS「刘安禄的揭露」). Such a reveal may also set a
## `nickname`, replace the combat chat (`combat_chat_chance` with `combat_chat_msg`) and
## `carry` items the NPC is given as it starts (carry_object()).
## Native (DECISIONS「势力线的仗」): a mood may also set the `combat_exp` and the skills' raw
## levels (`skills`) the NPC fights with while it is in it — one scene's strength for an NPC whose
## record stays as it is for every other meeting; the mood's end puts the record's back.

## The NPC flag that holds a mood: mood/<name> (an object variable, saved with it).
const FLAG_PREFIX: String = "mood/"

var name: String = ""
var title: String = ""
var nickname: String = ""
var applies: Dictionary[String, int] = {}
var flags: Array[StringName] = []
## NpcTalk with only the mood's chat (and combat chat); null when it keeps the definition's.
var talk: NpcTalk = null
## Items made for the NPC as the mood starts (item definitions).
var carry: Array[StringName] = []
## A room reset does not end it.
var lasting: bool = false
## The combat_exp while in the mood; -1 keeps the NPC's own.
var combat_exp: int = -1
## Skill -> raw level while in the mood (the others stay the NPC's own).
var skills: Dictionary[String, int] = {}


func flag() -> StringName:
	return StringName(FLAG_PREFIX + name)


## The mood's talk replaces the definition's combat chat too.
func has_combat_chat() -> bool:
	return talk != null and talk.has_combat_chat()


## {title?, nickname?, applies?: {key: n}, flags?: [flag], chat_chance?, chat_msg?,
## combat_chat_chance?, combat_chat_msg?, carry?: [item], lasting?, combat_exp?, skills?: {skill: n}}
## (chat_msg as the NPC record's).
static func from_record(mood_name: String, reader: ContentRecordReader) -> NpcMood:
	var mood := NpcMood.new()
	mood.name = mood_name
	mood.title = reader.text("title")
	mood.nickname = reader.text("nickname")
	mood.applies = reader.integer_map("applies")
	for flag_name: String in reader.text_list("flags"):
		mood.flags.append(StringName(flag_name))
	for item_id: String in reader.text_list("carry"):
		mood.carry.append(StringName(item_id))
	mood.lasting = reader.boolean("lasting", false)
	mood.combat_exp = reader.integer("combat_exp", -1)
	mood.skills = reader.integer_map("skills")
	if reader.has("chat_chance") != reader.has("chat_msg"):
		reader.fail("chat_chance", "chat_chance and chat_msg come together")
	if reader.has("combat_chat_chance") != reader.has("combat_chat_msg"):
		reader.fail("combat_chat_chance", "combat_chat_chance and combat_chat_msg come together")
	if reader.has("chat_msg") or reader.has("combat_chat_msg"):
		var chance: int = reader.integer("chat_chance", 0)
		var entries: Array = NpcContentRecords.chat_entries(reader, "chat_msg", false) if reader.has("chat_msg") else []
		var combat_chance: int = reader.integer("combat_chat_chance", 0)
		var combat_entries: Array = NpcContentRecords.chat_entries(reader, "combat_chat_msg", true) if reader.has("combat_chat_msg") else []
		mood.talk = NpcTalk.new({}, chance, entries, [], {}, combat_chance, combat_entries)
	reader.finish()
	if mood_name.is_empty() or (mood.title.is_empty() and mood.nickname.is_empty() and mood.applies.is_empty() and mood.flags.is_empty() and mood.talk == null and mood.carry.is_empty() and mood.combat_exp < 0 and mood.skills.is_empty()):
		reader.fail("", "a mood changes something")
	return mood
