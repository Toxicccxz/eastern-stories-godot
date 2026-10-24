class_name ShopFrontService
extends NpcService

## A keeper's own list and buy (NpcShopFront, shen.c): 看货 opens what list writes,
## and 购买 runs the keeper's buy_item(), whatever the player would buy. The lines go to
## the log too. Its panel is ShopFrontPanel (ui/).
var panel: ShopFrontPanel
var last_lines: Array[String] = []


func bind_npc(p_map: WorldMapController, p_npc: NpcRuntimeState) -> void:
	super.bind_npc(p_map, p_npc)
	panel = ShopFrontPanel.new()
	panel.hide()
	panel.buy_requested.connect(request_buy)
	ui_layer().add_child(panel)


func shop_front() -> NpcShopFront:
	return npc.definition().dealings().shop_front


func verb() -> String:
	return tr("看货")


## list: 你看到: and the keeper's text.
func interact() -> void:
	if not in_reach():
		return
	last_lines = [tr("你看到:"), NpcTalk.line(shop_front().list)]
	panel.show_listing(last_lines)
	if map.session != null:
		map.session.shared_ui().append_log_lines(last_lines)
	open_panel(context_title(), panel)


func _process(_delta: float) -> void:
	if panel.visible and not in_reach():
		panel.hide()


## buy: the keeper's buy_item(). Its command()s do nothing while it lies unconscious
## (damage.c unconcious() disables its commands); list's write() still shows.
func request_buy() -> Array[String]:
	last_lines = []
	if not in_reach() or npc.life_status != CharacterRuntimeLifeStatus.Value.ACTIVE:
		return last_lines
	var state: CharacterState = map.player_runtime().state
	var respect: String = RankWords.query_respect(state.gender, map.player_runtime().facts.age, state.affiliation.class_id)
	for line: NpcLine in shop_front().buy:
		last_lines.append(line.sentence(display_name(), respect))
	panel.show_answer(last_lines)
	if map.session != null:
		map.session.shared_ui().append_log_lines(last_lines)
	return last_lines
