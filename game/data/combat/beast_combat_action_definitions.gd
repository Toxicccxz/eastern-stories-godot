class_name BeastCombatActionDefinitions
extends RefCounted

const BITE_ACTION_ID: StringName = &"es2:adm/daemons/race/beast/bite"


## reference/es2/mudlib/adm/daemons/race/beast.c: combat_action["bite"].
## This is default ordinary action data, not a skill or tactical action.
static func bite() -> CombatActionDefinition:
	return CombatActionDefinition.new(
		BITE_ACTION_ID, 20, 0, &"咬伤", &"combat.beast.bite",
		"$N扑上来张嘴往$n的$l狠狠地一咬", "", &"",
	)
