class_name ColoredLine
extends RefCounted

## A line a command prints, with the ES2 colour it prints in (include/ansi.h):
## &"" plain, HIR bright red, HIY bright yellow, HIC bright cyan, HIW bright white,
## HIM bright magenta, HIG bright green, HIB bright blue (hell_guard.c), CYN cyan, RED red,
## GRN green (whisper.c).
## The text is in the shown language; presentation picks the colour's look.
const PLAIN: StringName = &""
const HIR: StringName = &"HIR"
const HIY: StringName = &"HIY"
const HIC: StringName = &"HIC"
const HIW: StringName = &"HIW"
const HIM: StringName = &"HIM"
const HIG: StringName = &"HIG"
const HIB: StringName = &"HIB"
const CYN: StringName = &"CYN"
const RED: StringName = &"RED"
const GRN: StringName = &"GRN"
## Every colour above but PLAIN, for checking authored ones.
const COLORS: Array[StringName] = [HIR, HIY, HIC, HIW, HIM, HIG, HIB, CYN, RED, GRN]

var text: String
var color: StringName
## Native (过场演出 A; DECISIONS「关键信息高亮」): the words of the line the player acts on after
## (a place, a person, a thing, an hour), as authored (message IDs: each is found in the shown
## line in the shown language, KeySpans). Presentation lights them; [] for none.
var keys: Array[String] = []
## Native (过场演出 B; DECISIONS「过场动作」): the page of a scene this line is read on (the map's
## WorldMapStaging.Beat): the dialogue box hands it back as the page shows and goes, so what the
## line's step shows begins and ends with it. null outside a staged scene.
var beat: RefCounted = null


func _init(p_text: String = "", p_color: StringName = PLAIN) -> void:
	text = p_text
	color = p_color


static func texts(lines: Array[ColoredLine]) -> Array[String]:
	var out: Array[String] = []
	for line: ColoredLine in lines:
		out.append(line.text)
	return out
