class_name BountyService
extends WorldService

## Native (A2 经验节奏): 雪亭驿's bounty board on the street (WorldBounties). Its panel lists
## the postings: 揭榜 takes one (one at a time), 放弃 gives the one taken up. With the
## pacing knob bounty_board off (ES2) there is no board to read.
var panel: PanelContainer
var rows: VBoxContainer
var feedback: Label


func setup(p_map: WorldMapController, p_definition: ServiceDefinition, p_point: WorldServicePoint) -> void:
	super.setup(p_map, p_definition, p_point)
	panel = PanelContainer.new()
	panel.name = "Panel"
	panel.hide()
	var box := VBoxContainer.new()
	box.name = "Box"
	panel.add_child(box)
	var intro := Label.new()
	intro.name = "Intro"
	# TRANSLATORS: native (A2): the 雪亭驿 bounty board's heading.
	intro.text = tr("官府悬赏：捉拿以下恶人者，赏银由雪亭驿代付。放过的恶人押送官府，一样领赏。")
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(intro)
	rows = VBoxContainer.new()
	rows.name = "Rows"
	box.add_child(rows)
	feedback = Label.new()
	feedback.name = "BoardFeedback"
	feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(feedback)
	ui_layer().add_child(panel)


func verb() -> String:
	return tr("看榜")


func in_reach() -> bool:
	return map.session != null and map.session.bounties().enabled() and super.in_reach()


func interact() -> void:
	if in_reach():
		refresh()
		open_panel(context_title(), panel)


## The rows for the postings now.
func refresh() -> void:
	for child: Node in rows.get_children():
		rows.remove_child(child)
		child.queue_free()
	var postings: Array[WorldBounties.Posting] = map.session.bounties().postings()
	var any_taken: bool = map.session.bounties().taken() != null
	if postings.is_empty():
		var none := Label.new()
		none.name = "None"
		# TRANSLATORS: native (A2): the bounty board has nothing for the player now.
		none.text = tr("榜上暂时没有与阁下相称的悬赏，过些时候再来看看吧。")
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rows.add_child(none)
		return
	for posting: WorldBounties.Posting in postings:
		var row := HBoxContainer.new()
		row.name = "Posting%d" % posting.slot
		var text := Label.new()
		text.name = "Text"
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		# TRANSLATORS: native (A2): one bounty on the board: the outlaw, where it was last seen ({place} in {region}), its silver.
		text.text = tr("{outlaw} · 出没于{region}{place}一带 · 赏银{silver}两").format({
			"outlaw": tr(_npc_name(posting.tier.npc_id)), "region": tr(_region_name(posting.place.zone_id)),
			"place": tr(_zone_name(posting.place.zone_id)), "silver": ChineseNumber.of(posting.tier.silver),
		}) + (tr("（已揭）") if posting.taken else "")
		row.add_child(text)
		var button := Button.new()
		button.custom_minimum_size = Vector2(96, 40)
		if posting.taken:
			button.name = "GiveUp"
			button.text = tr("放弃")
			button.pressed.connect(give_up)
		else:
			button.name = "Take"
			button.text = tr("揭榜")
			button.disabled = any_taken
			if any_taken:
				# TRANSLATORS: native (A2): why 揭榜 is greyed: one bounty at a time.
				button.tooltip_text = tr("一次只能揭一张榜。")
			button.pressed.connect(take.bind(posting.slot))
		row.add_child(button)
		rows.add_child(row)


func take(slot: int) -> bool:
	var done: bool = in_reach() and map.session.bounties().take(slot)
	refresh()
	if done:
		# TRANSLATORS: native (A2): the bounty board after the player took a bounty.
		feedback.text = tr("你揭下了告示。")
	return done


func give_up() -> bool:
	var done: bool = in_reach() and map.session.bounties().give_up()
	refresh()
	if done:
		# TRANSLATORS: native (A2): the bounty board after the player gave a bounty up.
		feedback.text = tr("你放弃了这张悬赏。")
	return done


func _npc_name(npc_id: StringName) -> String:
	var npc: NpcDefinition = GameContent.catalog().npc(npc_id)
	return "" if npc == null else npc.display_name


func _zone_name(zone_id: StringName) -> String:
	var zone: ZoneDefinition = GameContent.catalog().zone(zone_id)
	return "" if zone == null else zone.display_name


func _region_name(zone_id: StringName) -> String:
	var region: RegionDefinition = WorldProgressionRewards.region_of_zone(zone_id)
	return "" if region == null else region.display_name
