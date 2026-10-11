class_name NpcSettle
extends RefCounted

## d/village/npc/meloner.c do_return() (return melon cost): the player squares it with the NPC
## who caught them (both hold the set_temp() flag `temp`): the NPC says `say`, both flags go
## and it goes home (move() to its room). ES2 took nothing for it; the owner's modern fix
## (DECISIONS 玉螺湖村 A, for B): it costs the value of `item` (the 西瓜: 60 文), paid as buying is
## (buy.c can_afford(), pay_money()), and short of it the player reads buy.c's line and the
## fight goes on. `label` is the button (还瓜钱), `hint` its hover.
var temp: String = ""
var item_id: StringName = &""
var label: String = ""
var hint: String = ""
var say: String = ""


func is_valid() -> bool:
	return not temp.is_empty() and not item_id.is_empty() and not label.is_empty() and not hint.is_empty() and not NpcTalk.line(say).is_empty()


## What it costs: the item's value (one home for the price), 0 when the item is unknown.
func price(catalog: ContentCatalog) -> int:
	var item: ItemContentDefinition = null if catalog == null else catalog.item(item_id)
	return 0 if item == null else item.value


## {temp, item, label, hint, say}.
static func from_record(reader: ContentRecordReader) -> NpcSettle:
	var settle := NpcSettle.new()
	settle.temp = reader.required_text("temp")
	settle.item_id = StringName(reader.required_text("item"))
	settle.label = reader.required_text("label")
	settle.hint = reader.required_text("hint")
	settle.say = reader.required_text("say")
	reader.finish()
	if not settle.is_valid():
		reader.fail("", "needs its flag, the item it costs, its button, hover and say")
	return settle
