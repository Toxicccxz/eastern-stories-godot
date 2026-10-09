class_name ActService
extends WorldService

## A room's own command that acts on the player (RoomActDefinition: d/latemoon/room/
## bathroom.c take bath, upstar/uproom3.c ponder, latemoon2.c search bracelet): the
## context button does it at once. The branch for the player is asked first when it says
## so (a man bathing, owner, 晚月庄 plan Q2) or when what it costs would knock the player
## out (owner's rule on choices that knock out); otherwise ES2 just does it. A carried
## item's command (bracelet.c pray) is asked the same way (ask_first_or_run()).
## TRANSLATORS: before a command ({verb}: 静修) whose cost ({cost}: 50 点神) would knock the player out.
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
	var act: ScriptedAct = definition.act.act_for(state.gender, state.affiliation.class_id, map.acts.facts())
	if act == null:
		return
	ask_first_or_run(map, act, verb(), perform.bind(act), in_reach)


## `run` at once, or after the player's yes when `act` asks (its `ask`) or what it costs
## would knock them out; `still_valid` keeps the question open, `on_cancel` follows 取消.
static func ask_first_or_run(on: WorldMapController, act: ScriptedAct, verb_text: String, run: Callable, still_valid: Callable, on_cancel: Callable = Callable()) -> void:
	if not act.ask.is_empty():
		on.session.shared_ui().ask_first(TranslationServer.translate(act.ask), TranslationServer.translate(act.choice), run, still_valid, on_cancel)
		return
	var costs: Dictionary[String, int] = act.fainting_costs(on.player_runtime().state)
	if not costs.is_empty():
		var parts: Array[String] = []
		for key: String in costs:
			parts.append(TranslationServer.translate(COST).format({"amount": costs[key], "resource": TranslationServer.translate(RESOURCE_NAMES[key])}))
		# TRANSLATORS: the button that goes ahead with a command ({verb}: 静修).
		var go: String = TranslationServer.translate("确定{verb}").format({"verb": verb_text})
		on.session.shared_ui().ask_first(TranslationServer.translate(FAINT_WARNING).format({"verb": verb_text, "cost": TranslationServer.translate("和").join(parts)}), go, run, still_valid, on_cancel)
		return
	run.call()


## What the command does (WorldMapActs), on the world's interaction stream.
func perform(act: ScriptedAct) -> void:
	if not in_reach():
		return
	last_act = act
	map.acts.run(act, null, map.world_interaction_random_source().legacy_random)
