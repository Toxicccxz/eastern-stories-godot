class_name NpcDealings
extends RefCounted

## How the player deals with an NPC besides talk and fights: the goods it sells
## from its body (feature/vendor.c; `vendor` names the vendors[] record), what it
## takes when given something (accept_object() as NpcObjectRule), the object
## variables its create() sets (drunk.c has_alcohol, `flags`), whether it
## cannot be fought yet (`fight_deferred`, the reason; DECISIONS 4E), the toll it
## takes (`attack_unless_mark`, u/cloud gangster.c: greeting() kills a passer-by
## without marks/<mark>; once it has fought the player it attacks on sight until it
## is created anew, kill_passenger()'s attitude or attack.c's hatred) and what it
## steals from an arriving player (`steal`, NpcSteal).
var vendor_id: StringName = &""
var object_rules: Array[NpcObjectRule] = []
var initial_flags: Array[StringName] = []
var fight_deferred: String = ""
var attack_unless_mark: String = ""
var steal: NpcSteal


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
	var steal: ContentRecordReader = reader.child("steal")
	if steal != null:
		dealings.steal = NpcSteal.from_record(steal)
	return dealings
