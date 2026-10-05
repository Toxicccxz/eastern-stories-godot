class_name NpcLine
extends RefCounted

## One thing an NPC says or does in a rule's outcome: `say` is say.c ("<name>说道：
## <text>"), `emote` is a line that follows its name ("<name><text>") and `line` is
## shown as written (the say() efun with the speaker in the text: 屠夫边剔骨头边嘟囔着：…).
## The text may hold $RESPECT (rankd.c query_respect() of whoever the NPC speaks to).
var emote: bool
var text: String
var as_written: bool


func _init(p_emote: bool = false, p_text: String = "", p_as_written: bool = false) -> void:
	emote = p_emote
	text = p_text
	as_written = p_as_written


## The sentence the log shows, in the shown language. `npc_name` and `respect`
## (rankd.c query_respect() of whoever the NPC speaks to, for $RESPECT) are as authored.
func sentence(npc_name: String, respect: String) -> String:
	var body: String = NpcTalk.line(text).replace("$RESPECT", TranslationServer.translate(respect))
	if as_written:
		return body
	var npc: String = TranslationServer.translate(npc_name)
	if emote:
		# TRANSLATORS: what an NPC does, after its name: {npc}笑咪咪地说道：……
		return TranslationServer.translate("{npc}{action}").format({"npc": npc, "action": body})
	return TranslationServer.translate("{npc}说道：{line}").format({"npc": npc, "line": body})


## A record with exactly one of `say`, `emote` and `line`; null (and a reported failure) otherwise.
static func from_record(reader: ContentRecordReader) -> NpcLine:
	var kinds: int = int(reader.has("say")) + int(reader.has("emote")) + int(reader.has("line"))
	if kinds != 1:
		reader.fail("", "needs exactly one of say, emote and line")
		return null
	if reader.has("line"):
		return NpcLine.new(false, reader.required_text("line"), true)
	return NpcLine.new(reader.has("emote"), reader.required_text("emote" if reader.has("emote") else "say"))


## The optional `line`, `say` and `emote` of a rule record: a line as written first,
## then emote before say (as NpcFightRule).
static func optional_lines(reader: ContentRecordReader) -> Array[NpcLine]:
	var lines: Array[NpcLine] = []
	if reader.has("line"):
		lines.append(NpcLine.new(false, reader.required_text("line"), true))
	if reader.has("emote"):
		lines.append(NpcLine.new(true, reader.required_text("emote")))
	if reader.has("say"):
		lines.append(NpcLine.new(false, reader.required_text("say")))
	return lines
