class_name NpcSentence
extends RefCounted

## A magistrate's settle_lawsuit() for one brought before it (d/choyin/npc/judgeman.c,
## `after` seconds after the constable delivers them; repaired: owner, DECISIONS 乔阴 A Q1).
## With crime_lv: beat_line (打 crime_lv * 10 大板), then crime_lv strokes. Each stroke
## takes from gin, kee and sen 10 - max_atman / 100, 10 - max_force / 100 and
## 10 - max_mana / 100 (at least 0), off both the current and the effective value; one whose
## effective value is below that is left at 1 instead, and a stroke that leaves all three so
## knocks the convict out (faint_lines) and ends the beating. Then warn_line, the crime is
## cleared and they are put out at the 衙门口 (`out`). Without crime_lv only sorry_line.
## Obvious slips fixed (DECISIONS 乔阴 D): settle_lawsuit() set a value to 1 and then took the
## stroke off it all the same (receive_wound() to -1: the next heart_beat killed the convict
## its lines carry out), beat on after knocking them out, and said warn_line after every
## stroke; the crime stayed (Q1: it is cleared).

const STROKE: int = 10
const PER_POINT: int = 100

var after: float = 0.0
## $N the convict (你), {boards} the number of boards in words.
var beat_line: String = ""
var faint_lines: Array[String] = []
## $N the magistrate, $n the convict.
var warn_line: String = ""
var sorry_line: String = ""
var out_zone_id: StringName = &""
var out_point_id: StringName = &""


## What the strokes did: the convict was knocked out by them (all three left at 1).
class Beating:
	extends RefCounted
	var strokes: int = 0
	var fainted: bool = false


## settle_lawsuit()'s loop for `level` strokes on `state`.
static func beat(state: CharacterState, level: int) -> Beating:
	var beating := Beating.new()
	if state == null:
		return beating
	var tracks: Array[CharacterResourceState] = [state.essence, state.vitality, state.spirit]
	var maxima: Array[int] = [state.recovery.atman.maximum, state.recovery.inner_force.maximum, state.recovery.mana.maximum]
	for _stroke: int in range(level):
		beating.strokes += 1
		var floored: int = 0
		for index: int in range(tracks.size()):
			var track: CharacterResourceState = tracks[index]
			var blow: int = stroke_of(maxima[index])
			if track.effective < blow:
				track.effective = 1
				track.current = 1
				floored += 1
			else:
				track.apply_damage(blow)
				track.apply_wound(blow)
		if floored == tracks.size():
			beating.fainted = true
			break
	return beating


## 10 - max / 100, at least 0.
@warning_ignore("integer_division")
static func stroke_of(maximum: int) -> int:
	return maxi(0, STROKE - maximum / PER_POINT)


func is_valid() -> bool:
	return (
		after >= 0.0 and not beat_line.is_empty() and faint_lines.size() >= 1 and not warn_line.is_empty()
		and not sorry_line.is_empty() and not out_zone_id.is_empty() and not out_point_id.is_empty()
	)


## {after, beat_line, faint_lines, warn_line, sorry_line, out: {zone, point}}.
static func from_record(reader: ContentRecordReader) -> NpcSentence:
	var sentence := NpcSentence.new()
	sentence.after = float(reader.required_integer("after"))
	sentence.beat_line = reader.required_text("beat_line")
	sentence.faint_lines = reader.text_list("faint_lines")
	sentence.warn_line = reader.required_text("warn_line")
	sentence.sorry_line = reader.required_text("sorry_line")
	var out: ContentRecordReader = reader.child("out")
	if out != null:
		sentence.out_zone_id = StringName(out.required_text("zone"))
		sentence.out_point_id = StringName(out.required_text("point"))
		out.finish()
	reader.finish()
	if not sentence.is_valid():
		reader.fail("", "needs its lines and the zone and point it puts the convict out at")
	return sentence
