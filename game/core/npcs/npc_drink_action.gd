class_name NpcDrinkAction
extends RefCounted

## d/snow/npc/drunk.c do_drink() as a chat action: sated at `sated_water` water it
## only sings; else it drinks (feature/liquid.c do_drink) from the alcohol it carries
## and drops the container once it is empty (cmds/std/drop.c); with none left it
## clears `dry_clears` and says `dry_say`. sing and sigh print nothing (DECISIONS 4E).
var sated_water: int
var dry_say: String
var dry_clears: StringName


func _init(p_sated_water: int = 0, p_dry_say: String = "", p_dry_clears: StringName = &"") -> void:
	sated_water = p_sated_water
	dry_say = p_dry_say
	dry_clears = p_dry_clears


func is_valid() -> bool:
	return sated_water > 0 and not dry_say.strip_edges().is_empty()


static func from_record(reader: ContentRecordReader) -> NpcDrinkAction:
	var action := NpcDrinkAction.new(
		reader.required_integer("sated_water"), reader.required_text("dry_say"), StringName(reader.text("dry_clears")),
	)
	if not action.is_valid():
		reader.fail("", "sated_water must be positive and dry_say not empty")
	return action
