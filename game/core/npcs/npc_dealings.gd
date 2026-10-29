class_name NpcDealings
extends RefCounted

## How the player deals with an NPC besides talk and fights: the goods it sells
## from its body (feature/vendor.c; `vendor` names the vendors[] record), what it
## takes when given something (accept_object() as NpcObjectRule), the object
## variables its create() sets (drunk.c has_alcohol, `flags`), whether it
## cannot be fought yet (`fight_deferred`, the reason; DECISIONS 4E), the toll it
## takes (`attack_unless_mark`, u/cloud gangster.c: greeting() kills a passer-by
## without marks/<mark>; once it has fought the player it attacks on sight until it
## is created anew, kill_passenger()'s attitude or attack.c's hatred; its greeting
## comes `toll_attack_delay_ms` after the player comes into reach, call_out("greeting",
## 1); `toll_shout`, the chat_msg line it shouts the moment they do, so the wait is seen:
## DECISIONS「响应性」), what it
## steals from an arriving player (`steal`, NpcSteal), its `vendetta_mark` (a
## killer of its kind is marked, and it attacks whoever is: attack.c init()) and
## whether it gives quests (`quest_giver`, u/cloud/npc/god.c give_quest()) and the bets
## it takes (`wager`, NpcWager: u/cloud/npc/judge.c, through an `effect: wager` rule),
## and its own list and buy where it sells nothing (`shop_front`, NpcShopFront: shen.c), and
## its accept_kill() when the player attacks it (`accept_kill`, NpcAcceptKill), the beat it
## patrols and the thieves it catches there (`patrol`, NpcPatrol: d/choyin/npc/yamen_po.c),
## and the sentence it passes on one brought before it (`sentence`, NpcSentence:
## d/choyin/npc/judgeman.c), and how one it caught squares it with it (`settle`, NpcSettle:
## d/village/npc/meloner.c's return melon cost).
var vendor_id: StringName = &""
var object_rules: Array[NpcObjectRule] = []
var initial_flags: Array[StringName] = []
var fight_deferred: String = ""
## The marks of which any one spares the player its toll (`attack_unless_mark` one,
## `attack_unless_marks` several: 主线 A, the keep's gate takes money or a challenge).
var attack_unless_marks: Array[String] = []
## Native (主线 A; DECISIONS「老松寨的三条路」): the toll is the story's parley, held only
## while pacing's story_parley is on; off (经典), it is plain aggressive, as ES2's was.
var parley: bool = false
## Native (逆灵宫 A; DECISIONS「逆灵宫 A」): a journal `when` under which one that attacks on
## sight takes the player for one of its own (the 黑冠 worn, 野羊寨's chief brought home) —
## no shout, no wait, no gang with it; one the player fights still hunts them, and the
## player's own 攻击 brings the room down on them as ever. Null for none.
var ignores_when: JournalEntryDefinition = null
var toll_attack_delay_ms: int = 0
## The index of the chat_msg line shouted at a passer-by coming into reach (-1: none).
var toll_shout: int = -1
var steal: NpcSteal
var vendetta_mark: String = ""
var quest_giver: bool = false
var wager: NpcWager
var shop_front: NpcShopFront
var accept_kill: NpcAcceptKill
var patrol: NpcPatrol
var sentence: NpcSentence
var settle: NpcSettle


func is_fight_deferred() -> bool:
	return not fight_deferred.is_empty()


## Whether it takes a toll at all.
func takes_toll() -> bool:
	return not attack_unless_marks.is_empty()


## Whether the player holds a mark that spares them its toll.
func toll_paid(marks: Dictionary[String, int]) -> bool:
	for mark: String in attack_unless_marks:
		if int(marks.get(mark, 0)) != 0:
			return true
	return false


static func from_record(reader: ContentRecordReader) -> NpcDealings:
	var dealings := NpcDealings.new()
	dealings.vendor_id = StringName(reader.text("vendor"))
	for record: ContentRecordReader in reader.children("accept_object"):
		dealings.object_rules.append(NpcObjectRule.from_record(record))
	for flag: String in reader.text_list("flags"):
		if flag.is_empty() or dealings.initial_flags.has(StringName(flag)):
			reader.fail("flags", "flags must be unique and not empty")
		dealings.initial_flags.append(StringName(flag))
	dealings.fight_deferred = reader.text("fight_deferred")
	if reader.has("attack_unless_mark"):
		dealings.attack_unless_marks.append(reader.required_text("attack_unless_mark"))
	dealings.attack_unless_marks.append_array(reader.text_list("attack_unless_marks"))
	dealings.parley = reader.boolean("parley", false)
	if dealings.parley and dealings.attack_unless_marks.is_empty():
		reader.fail("parley", "only a toll-taker parleys")
	if reader.has("ignores_when"):
		dealings.ignores_when = JournalEntryDefinition.new()
		JournalEntryDefinition.read_when(reader, dealings.ignores_when, "ignores_when")
	dealings.toll_attack_delay_ms = reader.integer("toll_attack_delay_ms", 0)
	if dealings.toll_attack_delay_ms < 0 or (dealings.toll_attack_delay_ms > 0 and dealings.attack_unless_marks.is_empty()):
		reader.fail("toll_attack_delay_ms", "must not be negative, and needs attack_unless_mark")
	dealings.toll_shout = reader.integer("toll_shout", -1)
	if dealings.toll_shout < -1 or (dealings.toll_shout >= 0 and dealings.toll_attack_delay_ms <= 0):
		reader.fail("toll_shout", "a chat_msg index, for a toll-taker that waits")
	dealings.vendetta_mark = reader.text("vendetta_mark")
	dealings.quest_giver = reader.boolean("quest_giver", false)
	var steal: ContentRecordReader = reader.child("steal")
	if steal != null:
		dealings.steal = NpcSteal.from_record(steal)
	var wager: ContentRecordReader = reader.child("wager")
	if wager != null:
		dealings.wager = NpcWager.from_record(wager)
	var killed: ContentRecordReader = reader.child("accept_kill")
	if killed != null:
		dealings.accept_kill = NpcAcceptKill.from_record(killed)
	var beat: ContentRecordReader = reader.child("patrol")
	if beat != null:
		dealings.patrol = NpcPatrol.from_record(beat)
	var judging: ContentRecordReader = reader.child("sentence")
	if judging != null:
		dealings.sentence = NpcSentence.from_record(judging)
	var squaring: ContentRecordReader = reader.child("settle")
	if squaring != null:
		dealings.settle = NpcSettle.from_record(squaring)
	var front: ContentRecordReader = reader.child("shop_front")
	if front != null:
		dealings.shop_front = NpcShopFront.from_record(front)
		if not dealings.vendor_id.is_empty():
			reader.fail("shop_front", "a vendor sells through its vendor record")
	var bets: bool = dealings.object_rules.any(func(rule: NpcObjectRule) -> bool: return rule.effect == NpcObjectRule.EFFECT_WAGER)
	if bets != (dealings.wager != null):
		reader.fail("wager", "an accept_object rule with effect wager and a wager record go together")
	return dealings
