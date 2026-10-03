class_name NpcLine
extends RefCounted

## One thing an NPC says or does in a rule's outcome: `say` is say.c ("<name>说道：
## <text>"), `emote` is a line that follows its name ("<name><text>"). The text may
## hold $RESPECT (rankd.c query_respect() of whoever the NPC speaks to).
var emote: bool
var text: String


func _init(p_emote: bool = false, p_text: String = "") -> void:
	emote = p_emote
	text = p_text


## The sentence the log shows, in the shown language. `npc_name` and `respect`
## (rankd.c query_respect() of whoever the NPC speaks to, for $RESPECT) are as authored.
func sentence(npc_name: String, respect: String) -> String:
	var body: String = NpcTalk.line(text).replace("$RESPECT", TranslationServer.translate(respect))
	var npc: String = TranslationServer.translate(npc_name)
	if emote:
		# TRANSLATORS: what an NPC does, after its name: {npc}笑咪咪地说道：……
		return TranslationServer.translate("{npc}{action}").format({"npc": npc, "action": body})
	return TranslationServer.translate("{npc}说道：{line}").format({"npc": npc, "line": body})


## A record with exactly one of `say` and `emote`; null (and a reported failure) otherwise.
static func from_record(reader: ContentRecordReader) -> NpcLine:
	if reader.has("say") == reader.has("emote"):
		reader.fail("", "needs exactly one of say and emote")
		return null
	return NpcLine.new(reader.has("emote"), reader.required_text("emote" if reader.has("emote") else "say"))


## The optional `say` and `emote` of a rule record, emote first (as NpcFightRule).
static func optional_lines(reader: ContentRecordReader) -> Array[NpcLine]:
	var lines: Array[NpcLine] = []
	if reader.has("emote"):
		lines.append(NpcLine.new(true, reader.required_text("emote")))
	if reader.has("say"):
		lines.append(NpcLine.new(false, reader.required_text("say")))
	return lines
