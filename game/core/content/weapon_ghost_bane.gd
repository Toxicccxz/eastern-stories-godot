class_name WeaponGhostBane
extends RefCounted

## A weapon's own hit_ob(me, victim, damage_bonus) against a ghost (daemon/class/taoist/
## sword.c, 咒剑王禅): when random(the wielder's max_atman) is above the ghost's atman / 2,
## the ghost's gin is wounded by the wielder's query_spi(), who heals gin, kee and sen by as
## much, and the `line` (in `color`, $N the wielder) is told; otherwise random(query_spi())
## adds to damage_bonus. Against anything else it returns 0: nothing.
var line: String = ""
var color: StringName = ColoredLine.PLAIN


## {line, color?}.
static func from_record(reader: ContentRecordReader) -> WeaponGhostBane:
	var bane := WeaponGhostBane.new()
	bane.line = reader.required_text("line")
	bane.color = StringName(reader.text("color"))
	if bane.color != ColoredLine.PLAIN and not ColoredLine.COLORS.has(bane.color):
		reader.fail("color", "expected one of %s" % ", ".join(ColoredLine.COLORS))
	reader.finish()
	return bane
