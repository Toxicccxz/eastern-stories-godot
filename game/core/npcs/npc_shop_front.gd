class_name NpcShopFront
extends RefCounted

## A shopkeeper's own `list` and `buy` commands (its init() add_action()s) where it
## sells nothing (d/green/npc/shen.c list_item(), buy_item()): `list` is what list
## writes after 你看到: and `buy` what the keeper does to any buy (its emotes print
## nothing; DECISIONS 4E).
var list: String = ""
var buy: Array[NpcLine] = []


func is_valid() -> bool:
	return not list.strip_edges().is_empty() and not buy.is_empty()


static func from_record(reader: ContentRecordReader) -> NpcShopFront:
	var front := NpcShopFront.new()
	front.list = reader.required_text("list")
	for said: ContentRecordReader in reader.children("buy"):
		var line: NpcLine = NpcLine.from_record(said)
		said.finish()
		if line != null:
			front.buy.append(line)
	reader.finish()
	if not front.is_valid():
		reader.fail("", "needs list text and at least one buy line")
	return front
