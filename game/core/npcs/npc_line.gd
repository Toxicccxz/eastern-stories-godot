class_name NpcLine
extends RefCounted

## One thing an NPC says or does in a rule's outcome: `say` is say.c ("<name>说道：
## <text>"), `emote` is a line that follows its name ("<name><text>"), `line` is
## shown as written (the say() efun with the speaker in the text: 屠夫边剔骨头边嘟囔着：…)
## and `whisper` is whisper.c to the player ("<name>在你的耳边悄声说道：<text>", in GRN;
## the room only sees that something was whispered).
## The text may hold $RESPECT (rankd.c query_respect() of whoever the NPC speaks to).
## A line may have its ES2 colour (`color`: shinyu.c's HIY say()); one colour a line.
var emote: bool
var text: String
var as_written: bool
var whisper: bool
var authored_color: StringName = ColoredLine.PLAIN


func _init(p_emote: bool = false, p_text: String = "", p_as_written: bool = false, p_whisper: bool = false) -> void:
	emote = p_emote
	text = p_text
	as_written = p_as_written
	whisper = p_whisper


## The sentence the log shows, in the shown language. `npc_name` and `respect`
## (rankd.c query_respect() of whoever the NPC speaks to, for $RESPECT) are as authored.
func sentence(npc_name: String, respect: String) -> String:
	var body: String = NpcTalk.line(text).replace("$RESPECT", TranslationServer.translate(respect))
	if as_written:
		return body
	var npc: String = TranslationServer.translate(npc_name)
	if whisper:
		# TRANSLATORS: whisper.c, an NPC ({npc}) whispering to the player.
		return TranslationServer.translate("{npc}在你的耳边悄声说道：{line}").format({"npc": npc, "line": body})
	if emote:
		# TRANSLATORS: what an NPC does, after its name: {npc}笑咪咪地说道：……
		return TranslationServer.translate("{npc}{action}").format({"npc": npc, "action": body})
	return TranslationServer.translate("{npc}说道：{line}").format({"npc": npc, "line": body})


## The colour ES2 prints it in: whisper.c's GRN, else its authored colour.
func color() -> StringName:
	return ColoredLine.GRN if whisper else authored_color


## The sentence in its colour.
func colored(npc_name: String, respect: String) -> ColoredLine:
	return ColoredLine.new(sentence(npc_name, respect), color())


## A record with exactly one of `say`, `emote`, `line` and `whisper`, and an optional
## `color` (not for a whisper); null (and a reported failure) otherwise.
static func from_record(reader: ContentRecordReader) -> NpcLine:
	var kinds: int = int(reader.has("say")) + int(reader.has("emote")) + int(reader.has("line")) + int(reader.has("whisper"))
	if kinds != 1:
		reader.fail("", "needs exactly one of say, emote, line and whisper")
		return null
	var parsed: NpcLine
	if reader.has("line"):
		parsed = NpcLine.new(false, reader.required_text("line"), true)
	elif reader.has("whisper"):
		parsed = NpcLine.new(false, reader.required_text("whisper"), false, true)
	else:
		parsed = NpcLine.new(reader.has("emote"), reader.required_text("emote" if reader.has("emote") else "say"))
	if reader.has("color"):
		parsed.authored_color = StringName(reader.required_text("color"))
		if not ColoredLine.COLORS.has(parsed.authored_color) or parsed.whisper:
			reader.fail("color", "expected one of %s, and no colour on a whisper" % [ColoredLine.COLORS])
	return parsed


## The optional `line`, `say`, `emote` and `whisper` of a rule record: a line as
## written first, then emote before say (as NpcFightRule), then the whisper.
static func optional_lines(reader: ContentRecordReader) -> Array[NpcLine]:
	var lines: Array[NpcLine] = []
	if reader.has("line"):
		lines.append(NpcLine.new(false, reader.required_text("line"), true))
	if reader.has("emote"):
		lines.append(NpcLine.new(true, reader.required_text("emote")))
	if reader.has("say"):
		lines.append(NpcLine.new(false, reader.required_text("say")))
	if reader.has("whisper"):
		lines.append(NpcLine.new(false, reader.required_text("whisper"), false, true))
	return lines
