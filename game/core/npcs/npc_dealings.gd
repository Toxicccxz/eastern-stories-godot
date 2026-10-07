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
## 1)), what it
## steals from an arriving player (`steal`, NpcSteal), its `vendetta_mark` (a
## killer of its kind is marked, and it attacks whoever is: attack.c init()) and
## whether it gives quests (`quest_giver`, u/cloud/npc/god.c give_quest()) and the bets
## it takes (`wager`, NpcWager: u/cloud/npc/judge.c, through an `effect: wager` rule),
## and its own list and buy where it sells nothing (`shop_front`, NpcShopFront: shen.c).
var vendor_id: StringName = &""
var object_rules: Array[NpcObjectRule] = []
var initial_flags: Array[StringName] = []
var fight_deferred: String = ""
var attack_unless_mark: String = ""
var toll_attack_delay_ms: int = 0
var steal: NpcSteal
var vendetta_mark: String = ""
var quest_giver: bool = false
var wager: NpcWager
var shop_front: NpcShopFront


func is_fight_deferred() -> bool:
	return not fight_deferred.is_empty()


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
	dealings.attack_unless_mark = reader.text("attack_unless_mark")
	dealings.toll_attack_delay_ms = reader.integer("toll_attack_delay_ms", 0)
	if dealings.toll_attack_delay_ms < 0 or (dealings.toll_attack_delay_ms > 0 and dealings.attack_unless_mark.is_empty()):
		reader.fail("toll_attack_delay_ms", "must not be negative, and needs attack_unless_mark")
	dealings.vendetta_mark = reader.text("vendetta_mark")
	dealings.quest_giver = reader.boolean("quest_giver", false)
	var steal: ContentRecordReader = reader.child("steal")
	if steal != null:
		dealings.steal = NpcSteal.from_record(steal)
	var wager: ContentRecordReader = reader.child("wager")
	if wager != null:
		dealings.wager = NpcWager.from_record(wager)
	var front: ContentRecordReader = reader.child("shop_front")
	if front != null:
		dealings.shop_front = NpcShopFront.from_record(front)
		if not dealings.vendor_id.is_empty():
			reader.fail("shop_front", "a vendor sells through its vendor record")
	var bets: bool = dealings.object_rules.any(func(rule: NpcObjectRule) -> bool: return rule.effect == NpcObjectRule.EFFECT_WAGER)
	if bets != (dealings.wager != null):
		reader.fail("wager", "an accept_object rule with effect wager and a wager record go together")
	return dealings
