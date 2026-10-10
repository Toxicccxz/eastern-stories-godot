class_name MartialHitWound
extends RefCounted

## A martial art's own hit_ob() that cracks bones (daemon/skill/spicyclaw.c, 油流麻香手),
## called by combatd.c after the action's force with damage_bonus as it stands then:
## below `at_least` nothing happens (no draw); else random(damage_bonus / 2) over the
## victim's query_str() wounds the victim's kee by (damage_bonus - at_least) / 2 (receive_wound()
## without the attacker) and returns one of `messages` drawn by random(3) (the blow's line,
## $N, $n and $l as combatd.c fills them); else it returns 0 and the blow goes on unchanged.
## skills.json `hit_wound`.
var at_least: int
var messages: Array[String] = []


func _init(p_at_least: int = 0, p_messages: Array[String] = []) -> void:
	at_least = p_at_least
	messages = p_messages.duplicate()


## {at_least, messages: [line]}.
static func from_record(reader: ContentRecordReader) -> MartialHitWound:
	var wound := MartialHitWound.new(reader.required_integer("at_least"), reader.text_list("messages"))
	reader.finish()
	if wound.at_least < 0:
		reader.fail("at_least", "must not be negative")
	if wound.messages.is_empty():
		reader.fail("messages", "names the lines its hit_ob() returns")
	return wound
