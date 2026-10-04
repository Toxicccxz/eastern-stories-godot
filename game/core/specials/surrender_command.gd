class_name SurrenderCommand
extends RefCounted

## cmds/std/surrender.c for an NPC (command("surrender") as a chat function). Its
## last opponent, living and killing it, refuses: the source has
## message_vision("$N向$n求饶，但是$N大声说道：…", ob, me), which makes the opponent
## beg; it is shown as meant, the NPC begging (an obvious slip, fixed: DECISIONS).
## Otherwise remove_all_enemy(): every enemy that is not killing it stops
## fighting it, it stops fighting them all (whom it kills stays), and it says it
## gives up. The score it loses is not ported: an NPC keeps no score.
static func run(context: SpecialContext) -> bool:
	var me: SpecialSide = context.me
	if not context.is_fighting():
		return context.refuse("投降？现在没有人在打你啊....？")
	var ob: SpecialSide = context.other(me.relationship.last_opponent_id)
	if ob != null and ob.living and ob.is_killing(me.character_id):
		var line := VisionLine.new("$n向$N求饶，但是$N大声说道：{rude}废话少说，纳命来！", ob.character_id, me.character_id)
		line.slots["rude"] = RankWords.query_rude(me.state.gender, me.age, me.state.affiliation.class_id)
		context.lines.append(line)
		return true
	for enemy_id: StringName in me.relationship.opponent_ids():
		var enemy: SpecialSide = context.other(enemy_id)
		if enemy != null and enemy.relationship != null:
			enemy.relationship.remove_opponent(me.character_id)
	me.relationship.clear_opponents_preserving_lethal_targets()
	context.say("$N说道：「不打了，不打了，我投降....。」", &"", ColoredLine.HIW)
	return true
