class_name NpcArrest
extends RefCounted

## What a patrolling constable does with a thief (d/choyin/npc/yamen_po.c init(),
## catchyou(), accept_bribery(), die(); repaired: owner, DECISIONS 乔阴 A Q1). Meeting a
## player with a caught steal on record (query("thief")) while it patrols, random(out_of) <
## catch_below takes them: its say, crime_lv + crime, thief - 1, and it leads them back
## along its route to the 衙门 and into the 大堂 (`court`, a zone and a point there), where it
## says deliver_say and goes back to its beat. On the way the player may bribe it: money worth
## bribe_at or more (accept_bribery()'s base_value * amount >= 100000: ten gold) frees them
## (its taken lines; crime_lv - pardon, none left deleted), less is refused (refused_line;
## crime_lv + bribe_crime). Its killer gets crime_lv + killed_crime.

var catch_below: int = 0
var out_of: int = 10
## say(HIR ...) with {name}, the thief's name.
var catch_say: String = ""
var crime: int = 0
## do_go(): what a led player who tries to walk away reads.
var escape_line: String = ""
var deliver_say: String = ""
var court_zone_id: StringName = &""
var court_point_id: StringName = &""
var bribe_at: int = 0
var taken_lines: Array[String] = []
var refused_line: String = ""
var bribe_crime: int = 0
var pardon: int = 0
var killed_crime: int = 0


## init()'s random(10) < 7, drawn with `random` (a legacy_random()).
func catches(random: Callable) -> bool:
	return int(random.call(out_of)) < catch_below


## accept_bribery(): bv1 * amount >= 100000.
func takes_bribe(value: int) -> bool:
	return value >= bribe_at


func is_valid() -> bool:
	return (
		catch_below > 0 and out_of >= catch_below and not catch_say.is_empty() and crime > 0
		and not escape_line.is_empty() and not deliver_say.is_empty() and not court_zone_id.is_empty()
		and not court_point_id.is_empty() and bribe_at > 0 and not taken_lines.is_empty()
		and not refused_line.is_empty() and bribe_crime >= 0 and pardon >= 0 and killed_crime >= 0
	)


## {catch_below, out_of?, catch_say, crime, escape_line, deliver_say, court: {zone, point},
## bribe_at, taken_lines, refused_line, bribe_crime, pardon, killed_crime}.
static func from_record(reader: ContentRecordReader) -> NpcArrest:
	var arrest := NpcArrest.new()
	arrest.catch_below = reader.required_integer("catch_below")
	arrest.out_of = reader.integer("out_of", 10)
	arrest.catch_say = reader.required_text("catch_say")
	arrest.crime = reader.required_integer("crime")
	arrest.escape_line = reader.required_text("escape_line")
	arrest.deliver_say = reader.required_text("deliver_say")
	var court: ContentRecordReader = reader.child("court")
	if court != null:
		arrest.court_zone_id = StringName(court.required_text("zone"))
		arrest.court_point_id = StringName(court.required_text("point"))
		court.finish()
	arrest.bribe_at = reader.required_integer("bribe_at")
	arrest.taken_lines = reader.text_list("taken_lines")
	arrest.refused_line = reader.required_text("refused_line")
	arrest.bribe_crime = reader.integer("bribe_crime", 0)
	arrest.pardon = reader.integer("pardon", 0)
	arrest.killed_crime = reader.integer("killed_crime", 0)
	reader.finish()
	if not arrest.is_valid():
		reader.fail("", "needs its catch, lines, court, bribe and crimes")
	return arrest
