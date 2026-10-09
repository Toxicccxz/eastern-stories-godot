class_name HauntScribe
extends RefCounted

## daemon/class/taoist/necromancy/haunt.c, 茅山道术's 僵尸追魂符. scribe(): not in a fight,
## 20 mana, a name; the paper becomes 僵尸追魂符 with the name on it (ItemContentDefinition
## haunting_sheet()), for 20 mana and 10 sen. attach.c then puts it on the first zombie
## in the room (do_scribe_haunt()): one that someone's 法力 holds (query("possessed"))
## goes after the one named, present() in its room (DECISIONS 茅山 A: only there; one gone
## leaves the sheet unstuck), kill_ob()s them and makes them its leader, and they fight it
## back; end_tag: it falls apart once that fight is over.
const ID: StringName = &"haunt"
const MANA_COST: int = 20
const SEN_COST: int = 10
## do_haunt()'s message_vision(): $N the zombie, $n the one it goes after; its words in RED.
const KILL_LINE: String = "$N眼睛忽然睁开，喃喃地说道：杀....死....$n...."


## The refusal `me` reads, or "" once the 符 is drawn (its 20 mana and 10 sen paid).
static func scribe(me: SpecialSide, fighting: bool, name: String) -> String:
	if fighting:
		return "你正在战斗中！"
	var mana: CharacterInternalResourceState = me.state.recovery.mana
	if mana.current < MANA_COST:
		return "你的法力不够了！"
	if name.is_empty():
		return "你要在这张符上写谁的名字？"
	mana.current -= MANA_COST
	me.state.spirit.apply_damage(SEN_COST)
	return ""
