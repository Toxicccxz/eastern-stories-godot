class_name DanceService
extends WorldService

## d/latemoon/latemoon8.c and miroom.c `dancing` (DanceDefinition): the floor's panel offers
## the dances the player heard named (雨梅's 学舞, 昭仪, the 书房's picture) and one of their
## own, which ES2 answers 不得要领 after the sen is spent. A dance that would knock the
## player out is asked first (owner's rule on choices that knock out); one that moves them
## does so through its portal, and the faint comes where they arrive.
const FAINT_WARNING: String = "这一曲要耗去 {sen} 点神，你现在撑不住，跳完就会昏过去。\n确定要跳吗？"

var panel: PanelContainer
var steps: VBoxContainer
var last_result: DanceDefinition.Result


func setup(p_map: WorldMapController, p_definition: ServiceDefinition, p_point: WorldServicePoint) -> void:
	super.setup(p_map, p_definition, p_point)
	panel = PanelContainer.new()
	panel.name = "Panel"
	panel.hide()
	var rows := VBoxContainer.new()
	rows.name = "Rows"
	rows.add_theme_constant_override("separation", 10)
	panel.add_child(rows)
	var heading := Label.new()
	heading.name = "Heading"
	heading.text = "你想跳哪一曲？"
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rows.add_child(heading)
	steps = VBoxContainer.new()
	steps.name = "Steps"
	rows.add_child(steps)
	ui_layer().add_child(panel)


func verb() -> String:
	return tr("跳舞")


func interact() -> void:
	if not in_reach():
		return
	_refill()
	open_panel(context_title(), panel)


func _process(_delta: float) -> void:
	if panel.visible and not in_reach():
		panel.hide()


## The buttons: each known dance, then the player's own.
func _refill() -> void:
	for child: Node in steps.get_children():
		child.queue_free()
	for step: DanceDefinition.Step in known_steps():
		# TRANSLATORS: a dance the player may dance on the floor ({name}: 西出阳关).
		steps.add_child(_button(tr("跳「{name}」").format({"name": tr(step.name)}), step))
	steps.add_child(_button(tr("随意起舞"), null))


func _button(text: String, step: DanceDefinition.Step) -> Button:
	var button := Button.new()
	button.name = "Step"
	button.text = text
	button.custom_minimum_size = Vector2(0, 44)
	button.pressed.connect(choose.bind(step))
	return button


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
