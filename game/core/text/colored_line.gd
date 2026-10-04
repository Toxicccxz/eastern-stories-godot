class_name ColoredLine
extends RefCounted

## A line a command prints, with the ES2 colour it prints in (include/ansi.h):
## &"" plain, HIR bright red, HIY bright yellow, HIC bright cyan, HIW bright white,
## HIM bright magenta, CYN cyan.
## The text is in the shown language; presentation picks the colour's look.
const PLAIN: StringName = &""
const HIR: StringName = &"HIR"
const HIY: StringName = &"HIY"
const HIC: StringName = &"HIC"
const HIW: StringName = &"HIW"
const HIM: StringName = &"HIM"
const CYN: StringName = &"CYN"
## Every colour above but PLAIN, for checking authored ones.
const COLORS: Array[StringName] = [HIR, HIY, HIC, HIW, HIM, CYN]

var text: String
var color: StringName


func _init(p_text: String = "", p_color: StringName = PLAIN) -> void:
	text = p_text
	color = p_color


static func texts(lines: Array[ColoredLine]) -> Array[String]:
	var out: Array[String] = []
	for line: ColoredLine in lines:
		out.append(line.text)
	return out
