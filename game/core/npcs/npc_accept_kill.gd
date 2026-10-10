class_name NpcAcceptKill
extends RefCounted

## An NPC's own accept_kill(me) (d/choyin/npc/guard.c, d/waterfog/npc/elite_guard.c). No
## mudlib code calls it (kill.c only kill_ob()s), so ES2 never ran one; owner (乔阴 A): it
## runs as its author meant, when the player attacks it. It says `say` and exerts `exert`
## (elite_guard.c's powerup); the others of its kind standing here join the fight against
## the attacker (guard.c's help_hotel_guard(): each says `fellow_say`, then kill_ob()); when
## one did, it says `report_say` (有强人打劫哪... 快去报官！) and the attacker is marked
## vendetta/`report_vendetta`; `grudge` marks vendetta/<grudge> whether anyone helped or not
## (owner: all 红衣武士 turn on the attacker). `hint` is the native line that tells the
## player what the mark means (owner: they are told).
var say: String = ""
var exert: StringName = &""
var fellows: bool = false
var fellow_say: String = ""
var report_say: String = ""
var report_vendetta: String = ""
var grudge: String = ""
var hint: String = ""


## {say?, exert?, fellows?: {say?}, report?: {say, vendetta}, grudge?, hint?}.
static func from_record(reader: ContentRecordReader) -> NpcAcceptKill:
	var rule := NpcAcceptKill.new()
	rule.say = reader.text("say")
	rule.exert = StringName(reader.text("exert"))
	if not rule.exert.is_empty() and not ExertFunctions.has(rule.exert):
		reader.fail("exert", "no exert function %s" % rule.exert)
	var fellows: ContentRecordReader = reader.child("fellows")
	if fellows != null:
		rule.fellows = true
		rule.fellow_say = fellows.text("say")
		fellows.finish()
	var report: ContentRecordReader = reader.child("report")
	if report != null:
		rule.report_say = report.required_text("say")
		rule.report_vendetta = report.text("vendetta")
		report.finish()
		if not rule.fellows:
			reader.fail("report", "is said once a fellow came to help")
	rule.grudge = reader.text("grudge")
	rule.hint = reader.text("hint")
	if rule.hint.is_empty() != (rule.report_vendetta.is_empty() and rule.grudge.is_empty()):
		reader.fail("hint", "tells the player of a vendetta mark, and only of one")
	reader.finish()
	return rule
