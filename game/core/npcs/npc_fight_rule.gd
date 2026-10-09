class_name NpcFightRule
extends RefCounted

## One branch of an NPC's own accept_fight() (d/snow/npc/fist_trainer.c and the
## like): when the challenger matches, the NPC emotes and/or says a line, then
## accepts or refuses. The first matching rule of a definition decides; an NPC
## without rules uses npc.c accept_fight(). `say` may hold $RESPECT (how the NPC
## addresses the challenger) and $SELF (how it calls itself), from rankd.c.
## `class_id` is the challenger's query("class") (d/sanyen's monks answer a monk
## otherwise).
var family_id: StringName
var gender: StringName
var class_id: StringName
var emote: String
var say: String
var accept: bool
## The NPC answers with kill_ob() (annihir.c): the spar becomes its kill.
var kill: bool


func _init(p_family_id: StringName = &"", p_gender: StringName = &"", p_emote: String = "", p_say: String = "", p_accept: bool = false, p_kill: bool = false, p_class_id: StringName = &"") -> void:
	family_id = p_family_id
	gender = p_gender
	class_id = p_class_id
	emote = p_emote
	say = p_say
	accept = p_accept
	kill = p_kill


func matches(challenger_family_id: StringName, challenger_gender: StringName, challenger_class_id: StringName = &"") -> bool:
	return (
		(family_id.is_empty() or family_id == challenger_family_id) and (gender.is_empty() or gender == challenger_gender)
		and (class_id.is_empty() or class_id == challenger_class_id)
	)
