class_name NpcOrdination
extends RefCounted

## daemon/class/bonze/master.c do_kneel() (剃度): one its ask_for_join() marked
## (set_temp(`temp`), an inquiry rule's temp_asker) kneels before it, the kneel command
## its init() adds (the 跪下受戒 button). Its `lines` (message_vision(), $N the one
## kneeling, $n the NPC) in `color`; then it says `say`, {name} the new name: one of
## `prefixes` at random (prename[random(sizeof(prename))]) before the first character of
## the kneeling one's name (name[0..1], one character in ES2's double-byte text); then
## command("smile") (an emote: nothing, DECISIONS 4E), and they take that name and the
## class `class_id`.

# TRANSLATORS: the button for the kneel command a temple's master adds (daemon/class/bonze/master.c: 跪下(kneel)受戒).
const LABEL: String = "跪下受戒"

var temp: String = ""
var prefixes: Array[String] = []
var lines: Array[String] = []
var color: StringName = ColoredLine.PLAIN
var say: String = ""
var class_id: StringName = &""


func is_valid() -> bool:
	return (
		not temp.is_empty() and not prefixes.is_empty() and not lines.is_empty() and say.contains("{name}")
		and not class_id.is_empty() and (color == ColoredLine.PLAIN or ColoredLine.COLORS.has(color))
	)


## prename[random(sizeof(prename))] + name[0..1]; `random` is MudOS random(n).
func dharma_name(name: String, random: Callable) -> String:
	var drawn: int = random.call(prefixes.size())
	return prefixes[clampi(drawn, 0, prefixes.size() - 1)] + name.substr(0, 1)


## `ordination` {"temp", "prefixes", "lines", "color"?, "say", "class"}.
static func from_record(reader: ContentRecordReader) -> NpcOrdination:
	var ordination := NpcOrdination.new()
	ordination.temp = reader.required_text("temp")
	ordination.prefixes = reader.text_list("prefixes")
	ordination.lines = reader.text_list("lines")
	ordination.color = StringName(reader.text("color"))
	ordination.say = reader.required_text("say")
	ordination.class_id = StringName(reader.required_text("class"))
	reader.finish()
	for prefix: String in ordination.prefixes:
		if prefix.length() != 1:
			reader.fail("prefixes", "each is one character")
	if not ordination.is_valid():
		reader.fail("", "needs its temp, prefixes, lines (a known color), a say with {name} and a class")
	return ordination
