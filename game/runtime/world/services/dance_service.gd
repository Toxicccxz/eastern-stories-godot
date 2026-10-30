class_name DanceService
extends WorldService

## d/latemoon/latemoon8.c and miroom.c `dancing` (DanceDefinition): the floor's panel offers
## the dances the player heard named (雨梅's 学舞, 昭仪, the 书房's picture) and one of their
## own, which ES2 answers 不得要领 after the sen is spent. A dance that would knock the
## player out is asked first (owner's rule on choices that knock out); one that moves them
## does so through its portal, and the faint comes where they arrive. Its panel is
## DancePanel (ui/).
const FAINT_WARNING: String = "这一曲要耗去 {sen} 点神，你现在撑不住，跳完就会昏过去。\n确定要跳吗？"

var panel: DancePanel
var last_result: DanceDefinition.Result


func setup(p_map: WorldMapController, p_definition: ServiceDefinition, p_point: WorldServicePoint) -> void:
	super.setup(p_map, p_definition, p_point)
	panel = DancePanel.new()
	panel.hide()
	panel.step_chosen.connect(choose)
	ui_layer().add_child(panel)


func verb() -> String:
	return tr("跳舞")


func interact() -> void:
	if not in_reach():
		return
	panel.show_steps(known_steps())
	open_panel(context_title(), panel)


func _process(_delta: float) -> void:
	if panel.visible and not in_reach():
		panel.hide()


## The dances the player knows here, in the floor's order.
func known_steps() -> Array[DanceDefinition.Step]:
	return definition.dance.known_steps(map.player_runtime().state.marks)


## A button: asked first when the dance would knock the player out.
func choose(step: DanceDefinition.Step) -> void:
	if not in_reach():
		return
	var state: CharacterState = map.player_runtime().state
	var after: int = definition.dance.sen_after(state, step)
	if after < 0:
		map.session.shared_ui().ask_first(tr(FAINT_WARNING).format({"sen": state.spirit.current - after}), tr("确定起舞"), dance.bind(step), in_reach)
		return
	dance(step)


## do_dancing(): the sen and the lines; a known dance moves the player through its portal.
func dance(step: DanceDefinition.Step) -> DanceDefinition.Result:
	last_result = DanceDefinition.Result.new()
	if not in_reach():
		return last_result
	var player: WorldPlayerRuntimeState = map.player_runtime()
	last_result = definition.dance.dance(player.state, step)
	var hud: SharedGameplayUI = map.session.shared_ui()
	hud.append_log_lines(last_result.lines)
	# A dance that acts where the dancer stands (第四章: the 冰匣 opens, the 宝衣 falls).
	if last_result.act != null:
		hud.dismiss_current_panel()
		map.acts.run(last_result.act, null, map.world_interaction_random_source().legacy_random, definition.zone_id)
		_fall_if_spent(map)
		return last_result
	if last_result.refused or last_result.portal_id.is_empty():
		_fall_if_spent(map)
		return last_result
	hud.dismiss_current_panel()
	var session: WorldSessionController = map.session
	WorldLandmarkPolicy.move_through(map, GameContent.catalog().portal(last_result.portal_id))
	var arrived: WorldMapController = session.active_map() as WorldMapController
	_fall_if_spent(map if arrived == null else arrived)
	return last_result


## receive_damage("sen") below 0: the next heart beat knocks the player out.
func _fall_if_spent(on: WorldMapController) -> void:
	if on != null and on.player_runtime().state.life_threshold() != CharacterState.LifeThreshold.ACTIVE:
		on.player_fall_below_zero()
