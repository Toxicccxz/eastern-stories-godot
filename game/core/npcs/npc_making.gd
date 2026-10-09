class_name NpcMaking
extends RefCounted

## What an NPC makes for a giver after taking their gift (d/latemoon/npc/shaowei.c
## accept_object(): call_out("make_stage", 2, who, 0)): every `every` seconds it tells
## the giver the next of its `lines` (make_stage()'s tell_object()), and with the last
## the `gives` item is new()'d and moved to them (obj->move(who)), wherever they are.
var every: float = 0.0
var lines: Array[NpcLine] = []
var gives: StringName = &""


## {every, lines: [line], gives}.
static func from_record(reader: ContentRecordReader) -> NpcMaking:
	var making := NpcMaking.new()
	making.every = float(reader.required_integer("every"))
	for record: ContentRecordReader in reader.children("lines"):
		var said: NpcLine = NpcLine.from_record(record, true)
		record.finish()
		if said != null:
			making.lines.append(said)
	making.gives = StringName(reader.required_text("gives"))
	reader.finish()
	if making.every <= 0.0:
		reader.fail("every", "must be positive")
	if making.lines.is_empty():
		reader.fail("lines", "a making tells its stages")
	return making
