class_name ActService
extends WorldService

## A room's own command that acts on the player (RoomActDefinition: d/latemoon/room/
## bathroom.c take bath, upstar/uproom3.c ponder, latemoon2.c search bracelet): the
## context button does it at once. The branch for the player is asked first when it says
## so (a man bathing, owner, 晚月庄 plan Q2) or when what it costs would knock the player
## out (owner's rule on choices that knock out); otherwise ES2 just does it. A carried
## item's command (bracelet.c pray) is asked the same way (ask_first_or_run()). With no
## branch for the player there is no button: d/canyon/canyon4.c's swear answers only one the
## 军师 told the secret (add_action() returns 0 for anyone else, ES2's 什么?). A command that
## rolls (d/village/melonfarm.c's pick) draws for its branch when it runs, after the question
## its `stronger` asks while the NPC it may bring down on the player is clearly stronger
## (owner A10: a fight to the death).
## TRANSLATORS: before a command ({verb}: 静修) whose cost ({cost}: 50 点神) would knock the player out.
const FAINT_WARNING: String = "{verb}要耗去{cost}，你现在撑不住，会当场昏过去。\n确定要{verb}吗？"
## TRANSLATORS: one resource a command costs ({amount} points of 精, 气 or 神), joined by 和.
const COST: String = " {amount} 点{resource}"
const RESOURCE_NAMES: Dictionary[String, String] = {"gin": "精", "kee": "气", "sen": "神"}

var last_act: ScriptedAct


func verb() -> String:
	return tr(definition.act.verb)


func context_title() -> String:
	var title: String = super()
	return "" if title.is_empty() or _act_for_player() == null else title


## The button: the player's branch, asked first when it must be.
func interact() -> void:
	if not in_reach():
		return
	var act: ScriptedAct = _act_for_player()
	if act == null:
		return
	var run: Callable = perform_drawn if definition.act.draws() else ask_first_or_run.bind(map, act, verb(), perform.bind(act), in_reach)
	if asks_stronger():
		map.session.shared_ui().ask_first(tr(definition.act.stronger_ask), tr(definition.act.stronger_choice), run, in_reach)
		return
	run.call()


## Whether the command could bring a clearly stronger NPC down on the player (its `stronger`:
## the first of them standing in its room, RelativeStrength).
func asks_stronger() -> bool:
	var act: RoomActDefinition = definition.act
	if act.stronger_npc_id.is_empty() or map == null or map.player_runtime() == null:
		return false
	var npc: NpcRuntimeState = map.npcs.first_npc_in_zone(act.stronger_npc_id, act.stronger_zone_id, true)
	return npc != null and RelativeStrength.clearly_stronger(
		map.player_runtime().state.progression.combat_experience, npc.character_state.progression.combat_experience,
	)


## A command that rolls: the branch its draws (on the world's interaction stream) pick now.
func perform_drawn() -> void:
	if not in_reach() or map.player_runtime() == null:
		return
	var state: CharacterState = map.player_runtime().state
	var facts: ScriptedAct.Facts = map.acts.facts(definition.zone_id)
	facts.draw = map.world_interaction_random_source().legacy_random
	var act: ScriptedAct = definition.act.act_for(state.gender, state.affiliation.class_id, facts)
	if act != null:
		ask_first_or_run(map, act, verb(), perform.bind(act), in_reach)


## The branch for the player as they are now; null when none is.
func _act_for_player() -> ScriptedAct:
	if map == null or map.player_runtime() == null:
		return null
	var state: CharacterState = map.player_runtime().state
	return definition.act.act_for(state.gender, state.affiliation.class_id, map.acts.facts(definition.zone_id))


## `run` at once, or after the player's yes when `act` asks (its `ask`) or what it costs
## would knock them out; `still_valid` keeps the question open, `on_cancel` follows 取消.
static func ask_first_or_run(on: WorldMapController, act: ScriptedAct, verb_text: String, run: Callable, still_valid: Callable, on_cancel: Callable = Callable()) -> void:
	# Led by a constable, nothing takes the player away (WorldMapPatrols.refuses_move()).
	if act.moves_player() and on.patrols.refuses_move():
		return
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
	map.acts.run(act, null, map.world_interaction_random_source().legacy_random, definition.zone_id)
