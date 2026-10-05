class_name NpcHitCondition
extends RefCounted

## An NPC's own hit_ob() that poisons (d/oldpine/npc/venomsnake.c, d/latemoon/room/npc/
## shaoin.c): combatd.c calls it on a bare-handed blow the victim did not dodge or parry,
## with the damage bonus so far. When random(damage_bonus) > the victim's apply/armor and
## the victim's `condition` is below `below`, the condition is set to `duration` and the
## victim is told `message` in `color`. It returns nothing: the damage is unchanged.
var condition_id: StringName
var duration: int
var below: int
var message: String
var color: StringName


func _init(p_condition_id: StringName = &"", p_duration: int = 0, p_below: int = 0, p_message: String = "", p_color: StringName = ColoredLine.PLAIN) -> void:
	condition_id = p_condition_id
	duration = p_duration
	below = p_below
	message = p_message
	color = p_color


func is_valid() -> bool:
	return not condition_id.is_empty() and duration > 0 and not message.strip_edges().is_empty()


## `hit_ob` {"condition", "duration", "below", "message", "color"}.
static func from_record(reader: ContentRecordReader) -> NpcHitCondition:
	var color := StringName(reader.text("color"))
	if not color.is_empty() and not ColoredLine.COLORS.has(color):
		reader.fail("color", "expected one of %s" % ", ".join(ColoredLine.COLORS))
	var hit := NpcHitCondition.new(
		StringName(reader.required_text("condition")), reader.required_integer("duration"),
		reader.required_integer("below"), reader.required_text("message"), color,
	)
	reader.finish()
	if not hit.is_valid():
		reader.fail("", "condition and message must not be empty and duration must be positive")
	return hit
