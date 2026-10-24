class_name BountyBoardPanel
extends PanelContainer

## Native (A2 经验节奏): 雪亭驿's bounty board as the player reads it. BountyService gives it
## the postings (WorldBounties.Posting) and acts on what the player asks: 揭榜 (one at a
## time) or 放弃 the one taken.
signal take_requested(slot: int)
signal give_up_requested

var rows: VBoxContainer
var feedback: Label


func _init() -> void:
	name = "Panel"
	var box := VBoxContainer.new()
	box.name = "Box"
	add_child(box)
	var intro := Label.new()
	intro.name = "Intro"
	# TRANSLATORS: native (A2): the 雪亭驿 bounty board's heading.
	intro.text = "官府悬赏：捉拿以下恶人者，赏银由雪亭驿代付。放过的恶人押送官府，一样领赏。"
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(intro)
	rows = VBoxContainer.new()
	rows.name = "Rows"
	box.add_child(rows)
	feedback = Label.new()
	feedback.name = "BoardFeedback"
	feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	box.add_child(feedback)


## One row per posting, in slot order; a note when there is none for the player.
func show_postings(postings: Array[WorldBounties.Posting]) -> void:
	for child: Node in rows.get_children():
		rows.remove_child(child)
		child.queue_free()
	if postings.is_empty():
		var none := Label.new()
		none.name = "None"
		# TRANSLATORS: native (A2): the bounty board has nothing for the player now.
		none.text = tr("榜上暂时没有与阁下相称的悬赏，过些时候再来看看吧。")
		none.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rows.add_child(none)
		return
	var any_taken: bool = postings.any(func(posting: WorldBounties.Posting) -> bool: return posting.taken)
	for posting: WorldBounties.Posting in postings:
		var row := HBoxContainer.new()
		row.name = "Posting%d" % posting.slot
		var text := Label.new()
		text.name = "Text"
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
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
			button.text = "放弃"
			button.pressed.connect(func() -> void: give_up_requested.emit())
		else:
			button.name = "Take"
			button.text = "揭榜"
			button.disabled = any_taken
			if any_taken:
				# TRANSLATORS: native (A2): why 揭榜 is greyed: one bounty at a time.
				button.tooltip_text = "一次只能揭一张榜。"
			var slot: int = posting.slot
			button.pressed.connect(func() -> void: take_requested.emit(slot))
		row.add_child(button)
		rows.add_child(row)


## The line under the postings after 揭榜 or 放弃 (`taken`: which).
func say_done(taken: bool) -> void:
	# TRANSLATORS: native (A2): the bounty board after the player took a bounty, or gave one up.
	feedback.text = tr("你揭下了告示。") if taken else tr("你放弃了这张悬赏。")


func _npc_name(npc_id: StringName) -> String:
	var npc: NpcDefinition = GameContent.catalog().npc(npc_id)
	return "" if npc == null else npc.display_name


func _zone_name(zone_id: StringName) -> String:
	var zone: ZoneDefinition = GameContent.catalog().zone(zone_id)
	return "" if zone == null else zone.display_name


func _region_name(zone_id: StringName) -> String:
	var region: RegionDefinition = WorldProgressionRewards.region_of_zone(zone_id)
	return "" if region == null else region.display_name
