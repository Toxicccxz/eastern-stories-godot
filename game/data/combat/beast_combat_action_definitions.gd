class_name BeastCombatActionDefinitions
extends RefCounted

const BITE_ACTION_ID: StringName = &"es2:adm/daemons/race/beast/bite"


## reference/es2/mudlib/adm/daemons/race/beast.c: combat_action["bite"].
## This is default ordinary action data, not a skill or tactical action.
static func bite() -> CombatActionDefinition:
	return action(&"bite")


## beast.c combat_action[verb]; null for a verb the table does not have. An
## entry without "damage" (claw) adds nothing to the damage roll.
static func action(verb: StringName) -> CombatActionDefinition:
	match verb:
		&"hoof":
			return _entry(verb, 100, &"瘀伤", "$N用後腿往$n的$l用力一蹬")
		&"bite":
			return _entry(verb, 20, &"咬伤", "$N扑上来张嘴往$n的$l狠狠地一咬")
		&"claw":
			return _entry(verb, 0, &"抓伤", "$N用爪子往$n的$l一抓")
		&"poke":
			return _entry(verb, 30, &"刺伤", "$N用嘴往$n的$l一啄")
	return null


static func _entry(verb: StringName, damage: int, damage_type: StringName, text: String) -> CombatActionDefinition:
	return CombatActionDefinition.new(
		StringName("es2:adm/daemons/race/beast/%s" % verb), damage, 0, damage_type,
		StringName("combat.beast.%s" % verb), text, "", &"",
	)
