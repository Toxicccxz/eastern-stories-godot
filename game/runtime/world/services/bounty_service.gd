class_name BountyService
extends WorldService

## Native (A2 经验节奏): 雪亭驿's bounty board on the street (WorldBounties). Its panel
## (BountyBoardPanel, ui/) lists the postings; 揭榜 takes one (one at a time), 放弃 gives the
## one taken up. With the pacing knob bounty_board off (ES2) there is no board to read.
var panel: BountyBoardPanel


func setup(p_map: WorldMapController, p_definition: ServiceDefinition, p_point: WorldServicePoint) -> void:
	super.setup(p_map, p_definition, p_point)
	panel = BountyBoardPanel.new()
	panel.hide()
	panel.take_requested.connect(take)
	panel.give_up_requested.connect(give_up)
	ui_layer().add_child(panel)


func verb() -> String:
	return tr("看榜")


func in_reach() -> bool:
	return map.session != null and map.session.bounties().enabled() and super.in_reach()


func interact() -> void:
	if in_reach():
		refresh()
		open_panel(context_title(), panel)


## The panel shows the postings now.
func refresh() -> void:
	panel.show_postings(map.session.bounties().postings())


func take(slot: int) -> bool:
	var done: bool = in_reach() and map.session.bounties().take(slot)
	refresh()
	if done:
		panel.say_done(true)
	return done


func give_up() -> bool:
	var done: bool = in_reach() and map.session.bounties().give_up()
	refresh()
	if done:
		panel.say_done(false)
	return done
