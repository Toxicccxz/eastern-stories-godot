class_name ActService
extends WorldService

## A room's own command that acts on the player (RoomActDefinition: d/latemoon/room/
## bathroom.c take bath, upstar/uproom3.c ponder): the context button does it at once.
## The branch for the player is asked first when it says so (a man bathing, owner, 晚月庄
## plan Q2) or when what it costs would knock the player out (owner's rule on choices
## that knock out); otherwise ES2 just does it.
## TRANSLATORS: before a room's command ({verb}: 静修) whose cost ({cost}: 50 点神) would knock the player out.
const FAINT_WARNING: String = "{verb}要耗去{cost}，你现在撑不住，会当场昏过去。\n确定要{verb}吗？"
## TRANSLATORS: one resource a command costs ({amount} points of 精, 气 or 神), joined by 和.
const COST: String = " {amount} 点{resource}"
const RESOURCE_NAMES: Dictionary[String, String] = {"gin": "精", "kee": "气", "sen": "神"}

var last_act: ScriptedAct


func verb() -> String:
	return tr(definition.act.verb)


## The button: the player's branch, asked first when it must be.
func interact() -> void:
	if not in_reach():
		return
	var state: CharacterState = map.player_runtime().state
	var act: ScriptedAct = definition.act.act_for(state.gender, state.affiliation.class_id)
	if act == null:
		return
	if not act.ask.is_empty():
		map.session.shared_ui().ask_first(tr(act.ask), tr(act.choice), perform.bind(act), in_reach)
		return
	var costs: Dictionary[String, int] = act.fainting_costs(state)
	if not costs.is_empty():
		var parts: Array[String] = []
		for key: String in costs:
			parts.append(tr(COST).format({"amount": costs[key], "resource": tr(RESOURCE_NAMES[key])}))
		# TRANSLATORS: the button that goes ahead with a room's command ({verb}: 静修).
		var go: String = tr("确定{verb}").format({"verb": verb()})
		map.session.shared_ui().ask_first(tr(FAINT_WARNING).format({"verb": verb(), "cost": tr("和").join(parts)}), go, perform.bind(act), in_reach)
		return
	perform(act)


## What the command does (WorldMapActs), on the world's interaction stream.
func perform(act: ScriptedAct) -> void:
	if not in_reach():
		return
	last_act = act
	map.acts.run(act, null, map.world_interaction_random_source().legacy_random)
