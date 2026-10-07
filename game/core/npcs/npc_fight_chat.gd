class_name NpcFightChat
extends RefCounted

## Chat functions an NPC runs in a fight (chat_msg_combat) that are data: 青石村's
## villagers. `Wield` (woman1.c wield_weapon(), oldman.c wield_something()): with
## nothing in hand, the say (if any) and command("wield <item>"), then the NPC's
## chat_chance_combat may change (woman1.c: 10) for as long as it lives. `CallPartner`
## (oldman.c/oldwoman.c ask_for_help()): the partner present() in the room and not
## fighting does its line (tell_room() to everyone else) and kill_ob()s whoever this
## NPC fights to the death (query_temp("killer")). `SayByAge` (woman1.c converse_one()):
## younger than the NPC, the `younger` says, else `otherwise` (DECISIONS 青石村 A: the
## enemy's age, not heart_beat()'s this_player(), who is herself).


class Wield:
	extends RefCounted
	var item_id: StringName
	var say: String
	## The NPC's chat_chance_combat afterwards; -1 leaves it.
	var combat_chance: int = -1

	func is_valid() -> bool:
		return not item_id.is_empty() and combat_chance >= -1 and combat_chance <= 100


class CallPartner:
	extends RefCounted
	var partner_id: StringName
	var line: NpcLine

	func is_valid() -> bool:
		return not partner_id.is_empty() and line != null and not NpcTalk.line(line.text).is_empty()


class SayByAge:
	extends RefCounted
	var younger: Array[String] = []
	var otherwise: Array[String] = []

	func is_valid() -> bool:
		return not younger.is_empty() and not otherwise.is_empty()

	## The says for an enemy of `enemy_age` against an NPC of `own_age`.
	func says(enemy_age: int, own_age: int) -> Array[String]:
		return younger if enemy_age < own_age else otherwise


static func is_action(action: String) -> bool:
	return action in ["wield", "call_partner", "say_by_age"]


## {"action": "wield", "item", "say"?, "chat_chance_combat"?} | {"action": "call_partner",
## "partner", "emote" | "say" | "line"} | {"action": "say_by_age", "younger", "otherwise"}.
static func from_record(reader: ContentRecordReader, action: String) -> RefCounted:
	match action:
		"wield":
			var wield := Wield.new()
			wield.item_id = StringName(reader.required_text("item"))
			wield.say = reader.text("say")
			wield.combat_chance = reader.integer("chat_chance_combat", -1)
			if not wield.is_valid():
				reader.fail("", "needs its item; chat_chance_combat 0 to 100")
			return wield
		"call_partner":
			var call := CallPartner.new()
			call.partner_id = StringName(reader.required_text("partner"))
			var lines: Array[NpcLine] = NpcLine.optional_lines(reader)
			call.line = null if lines.size() != 1 else lines[0]
			if not call.is_valid():
				reader.fail("", "needs its partner and exactly one of say, emote and line")
			return call
		_:
			var by_age := SayByAge.new()
			by_age.younger.assign(reader.text_list("younger"))
			by_age.otherwise.assign(reader.text_list("otherwise"))
			if not by_age.is_valid():
				reader.fail("", "needs younger and otherwise")
			return by_age
