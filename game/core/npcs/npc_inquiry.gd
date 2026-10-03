class_name NpcInquiry
extends RefCounted

## cmds/std/ask.c with adm/daemons/inquiryd.c: the player asks a speaking NPC in
## the same place about a topic. Lines come back as the player reads them (你).
## The topic list stands in for typing `ask <npc> about <topic>`: ES2's own list
## (这里, 名字, 传闻, then the NPC's set("inquiry") keys), with an NPC's English
## `here`/`name`/`rumors` answer behind the Chinese topic instead of a second entry.

const HERE: String = "这里"
const NAME: String = "名字"
const RUMORS: String = "传闻"
const DEFAULT_TOPICS: Array[String] = [HERE, NAME, RUMORS]
const ENGLISH_TOPICS: Dictionary[String, String] = {HERE: "here", NAME: "name", RUMORS: "rumors"}

## ask.c msg_dunno, $n the NPC.
const DUNNO: Array[String] = [
	"%s摇摇头，说道：没听说过。",
	"%s睁大眼睛望著你，显然不知道你在说什麽。",
	"%s耸了耸肩，很抱歉地说：无可奉告。",
	"%s说道：嗯....这我可不清楚，你最好问问别人吧。",
	"%s想了一会儿，说道：对不起，你问的事我实在没有印象。",
]


## The asking player's rankd.c facts, and eff_kee * 100 / max_kee for an answer
## judged on how hurt they are (NpcTalk.KeeAnswer).
class Asker:
	extends RefCounted
	var gender: StringName
	var age: int
	var class_id: StringName
	var kee_percent: int

	func _init(p_gender: StringName = &"", p_age: int = 0, p_class_id: StringName = &"", p_kee_percent: int = 100) -> void:
		gender = p_gender
		age = p_age
		class_id = p_class_id
		kee_percent = p_kee_percent


## What the player can ask `definition` about, in ES2's listing order.
static func topics(definition: NpcDefinition) -> Array[String]:
	var result: Array[String] = DEFAULT_TOPICS.duplicate()
	if definition == null:
		return result
	for topic: String in definition.talk().inquiry_topics():
		if not result.has(topic) and not ENGLISH_TOPICS.values().has(topic):
			result.append(topic)
	return result


## The key ES2 is asked for a listed topic: 这里 asks `here` when only that is answered.
static func asked_key(definition: NpcDefinition, topic: String) -> String:
	var talk: NpcTalk = definition.talk()
	if ENGLISH_TOPICS.has(topic) and not talk.has_answer(topic) and talk.has_answer(ENGLISH_TOPICS[topic]):
		return ENGLISH_TOPICS[topic]
	return topic


## ask.c main() after present(): the question, then the answer. `conscious` is
## living(ob); `room_short` the NPC's room title; `random` draws msg_dunno.
static func ask(
	npc_definition: NpcDefinition,
	npc_gender: StringName,
	npc_age: int,
	conscious: bool,
	asker: Asker,
	topic: String,
	room_short: String,
	random: WorldInteractionRandomSource,
) -> Array[String]:
	var lines: Array[String] = []
	if npc_definition == null or not npc_definition.can_speak() or asker == null or topic.is_empty() or random == null:
		return lines
	var name: String = npc_definition.display_name
	var key: String = asked_key(npc_definition, topic)
	# Lines are put together in the shown language; `name`, `key` and `topic` stay as
	# authored for the matching below.
	var npc: String = _t(name)
	var npc_respect: String = _t(RankWords.query_respect(npc_gender, npc_age, &"", npc_definition.rank_respect))
	# inquiryd.c parse_inquiry(), else ask.c's own line.
	match key:
		"name", NAME:
			lines.append(_t("你向{npc}问道：敢问{respect}尊姓大名？").format({"npc": npc, "respect": npc_respect}))
		"here", HERE:
			lines.append(_t("你向{npc}问道：这位{respect}，{self}初到贵宝地，不知这里有些什麽风土人情？").format({
				"npc": npc, "respect": npc_respect, "self": _t(RankWords.query_self(asker.gender, asker.age, asker.class_id)),
			}))
		"rumors", RUMORS:
			lines.append(_t("你向{npc}问道：这位{respect}，不知最近有没有听说什麽消息？").format({"npc": npc, "respect": npc_respect}))
		_:
			lines.append(_t("你向{npc}打听有关『{topic}』的消息。").format({"npc": npc, "topic": _t(topic)}))
	if not conscious:
		lines.append(_t("但是很显然的，%s现在的状况没有办法给你任何答覆。") % npc)
		return lines
	var talk: NpcTalk = npc_definition.talk()
	var answer: PackedStringArray = talk.answer(key, asker.kee_percent)
	# An answer function that returns 0 leaves ask.c to its own lines.
	if talk.has_answer(key) and not (answer.is_empty() and talk.answers_by_kee(key)):
		var asker_respect: String = _t(RankWords.query_respect(asker.gender, asker.age, asker.class_id))
		for text: String in answer:
			lines.append(_t("{npc}说道：{line}").format({"npc": npc, "line": NpcTalk.line(text).replace("$RESPECT", asker_respect)}))
		return lines
	if key == name or key == "name" or key == NAME:
		match npc_definition.attitude:
			NpcDefinition.Attitude.AGGRESSIVE:
				lines.append(_t("{npc}对你把眼一瞪：{self}的名字是可以随便提的吗？！我看你这{rude}是活腻了！").format({
					"npc": npc, "self": _t(RankWords.query_self_rude(npc_gender, npc_age, &"")),
					"rude": _t(RankWords.query_rude(asker.gender, asker.age, asker.class_id)),
				}))
			NpcDefinition.Attitude.HEROISM:
				lines.append(_t("{npc}对你哈哈一笑：{npc}便是{self}！").format({
					"npc": npc, "self": _t(RankWords.query_self_rude(npc_gender, npc_age, &"")),
				}))
			_:
				# The EMOTE_D "sigh" that follows prints nothing: data/emoted.o is not in the mudlib.
				lines.append(_t("{npc}对你作了一揖：这位{respect}可真会开玩笑，怎么会突然问起{self}的名字？").format({
					"npc": npc, "respect": _t(RankWords.query_respect(asker.gender, asker.age, asker.class_id)),
					"self": _t(RankWords.query_self(npc_gender, npc_age, &"")),
				}))
		return lines
	if key == "here" or key == HERE:
		lines.append(_t("{npc}对你说道：这里是{place}，至于其它的，{self}不便多说。").format({
			"npc": npc, "place": _t(room_short), "self": _t(RankWords.query_self(npc_gender, npc_age, &"")),
		}))
		return lines
	var drawn: int = random.legacy_random(DUNNO.size())
	if drawn >= 0 and drawn < DUNNO.size():
		lines.append(_t(DUNNO[drawn]) % npc)
	return lines


static func _t(text: String) -> String:
	return TranslationServer.translate(text)
