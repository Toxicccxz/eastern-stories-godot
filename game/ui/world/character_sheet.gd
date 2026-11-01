class_name CharacterSheet
extends VBoxContainer
## The menu's 角色 page: score.c's sheet in blocks (who, 精/气/神 and the other
## resources, progress, gifts, burden). The facts are the sheet's as before; the 任务
## lines moved to the 任务 page. 现代基线 C (DECISIONS「数值用到才出现」): every number is a
## StatCell with its line from stats_display.json, and 法力, 灵力, 杀气 and 加力 only once used.

var identity: Label
var rank: Label
var resource_bars: Dictionary[StringName, ProgressBar] = {}
var resource_values: Dictionary[StringName, Label] = {}
## The numbers by their stats_display.json IDs.
var cells: Dictionary[StringName, StatCell] = {}
## A2: unspent potential against the cap, and 落后补偿 while it applies.
var potential_cap: StatCell
var catch_up: Label
var kills: StatCell
## 前两小时 E: the pace the character plays at (现代 / 经典).
var pace: Label
## 前两小时 A: the one-time 历练 rewards given (CharacterState.milestones), newest first.
var milestones: Label
## How many 历练 lines the sheet shows; the rest is a count.
const MILESTONES_SHOWN: int = 8
const GIFTS: Array[Array] = [[&"strength", &"courage", &"intelligence", &"spirituality"], [&"composure", &"personality", &"constitution", &"karma"]]


func _init() -> void:
	name = "CharacterSheet"
	add_theme_constant_override("separation", 10)
	var top := _row("Top")
	var who: VBoxContainer = _block(top, "Who", "身份")
	identity = _line(who, "Identity")
	identity.add_theme_font_size_override("font_size", 19)
	identity.add_theme_color_override("font_color", SharedGameplayLayout.NAME_COLOR)
	rank = _line(who, "Rank")
	rank.add_theme_color_override("font_color", SharedGameplayLayout.ACCENT_COLOR)
	var body: VBoxContainer = _block(top, "Body", "精气神")
	_cells(body, "Columns", [&"tracks"])
	cells[&"tracks"].add_theme_color_override("font_color", SharedGameplayLayout.MUTED_COLOR)
	for entry: Array in [[&"essence", SharedGameplayLayout.ESSENCE_COLOR], [&"vitality", SharedGameplayLayout.VITALITY_COLOR], [&"spirit", SharedGameplayLayout.SPIRIT_COLOR]]:
		_resource(body, entry[0], entry[1])
	_cells(body, "Powers", [&"force", &"enforce", &"mana", &"atman"])
	_cells(body, "Supplies", [&"food", &"water"])
	var bottom := _row("Bottom")
	var growth: VBoxContainer = _block(bottom, "Growth", "修为")
	_cells(growth, "Progress", [&"combat_experience", &"potential"])
	potential_cap = StatCell.new("PotentialCap")
	potential_cap.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	growth.add_child(potential_cap)
	catch_up = _line(growth, "CatchUp")
	catch_up.add_theme_color_override("font_color", SharedGameplayLayout.ACCENT_COLOR)
	_cells(growth, "Standing", [&"bellicosity", &"score"])
	kills = StatCell.new("Kills")
	kills.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	growth.add_child(kills)
	pace = _line(growth, "Pace")
	pace.add_theme_color_override("font_color", SharedGameplayLayout.MUTED_COLOR)
	var nature: VBoxContainer = _block(bottom, "Nature", "天赋")
	for row: int in GIFTS.size():
		_cells(nature, "Gifts%d" % row, GIFTS[row])
	# TRANSLATORS: the character sheet's heading over the 历练 rewards the player has earned (A2, 前两小时 A).
	var deeds: VBoxContainer = _block(self, "Milestones", "历练")
	milestones = _line(deeds, "MilestoneLines")
	_cells(self, "Burden", [&"burden", &"weight"])
	for stat_id: StringName in [&"burden", &"weight"]:
		cells[stat_id].add_theme_color_override("font_color", SharedGameplayLayout.MUTED_COLOR)


## Fills the sheet from the player's state, in the shown language.
func refresh(player: WorldPlayerRuntimeState, session: WorldSessionController) -> void:
	if player == null:
		return
	var state: CharacterState = player.state
	var attr := state.attributes
	# TRANSLATORS: the character sheet (score): name, gender and age.
	identity.text = tr("{name} · {gender} · {age}岁").format({
		"name": (tr("(鬼气) ") if state.ghost else "") + player.facts.display_name, "gender": tr(state.gender), "age": player.facts.age,
	})
	# rankd.c's rank (【 武  者 】), then the title.
	rank.text = tr(RankWords.query_rank(state.gender, state.affiliation.class_id, CrimeRecord.thief(state), state.ghost)) + player.shown_title()
	cells[&"tracks"].show_stat(StatCell.stat_name(&"tracks"), StatCell.stat_hint(&"tracks"))
	_show_resource(&"essence", state.essence)
	_show_resource(&"vitality", state.vitality)
	_show_resource(&"spirit", state.spirit)
	_show(state, &"force", "%d / %d" % [state.recovery.inner_force.current, state.recovery.inner_force.maximum])
	_show(state, &"enforce", str(attr.force_factor))
	_show(state, &"mana", "%d / %d" % [state.recovery.mana.current, state.recovery.mana.maximum])
	_show(state, &"atman", "%d / %d" % [state.recovery.atman.current, state.recovery.atman.maximum])
	_show(state, &"food", str(state.recovery.food))
	_show(state, &"water", str(state.recovery.water))
	_show(state, &"combat_experience", str(state.progression.combat_experience))
	# TRANSLATORS: the character sheet: potential and the potential spent.
	_show(state, &"potential", tr("{potential}（已用 {spent}）").format({"potential": state.progression.potential, "spent": state.progression.potential_spent}))
	_show_pacing(player)
	_show(state, &"bellicosity", str(attr.bellicosity))
	_show(state, &"score", str(state.progression.score))
	# TRANSLATORS: the character sheet, score.c's line: the NPCs the player has killed.
	kills.show_stat(tr("总共杀过 {kills} 个人。").format({"kills": state.progression.kills}), StatCell.stat_hint(&"kills"))
	var gifts: Dictionary[StringName, int] = {
		&"strength": attr.strength, &"courage": attr.courage, &"intelligence": attr.intelligence, &"spirituality": attr.spirituality,
		&"composure": attr.composure, &"personality": attr.personality, &"constitution": attr.constitution, &"karma": attr.karma,
	}
	for stat_id: StringName in gifts:
		_show(state, stat_id, str(gifts[stat_id]))
	# TRANSLATORS: the character sheet: {pace} is 现代 or 经典 (DECISIONS「经典模式总开关」).
	pace.text = tr("节奏：{pace}（开局选定）").format({"pace": PacePresets.shown_name(state.pace)})
	milestones.text = milestone_text(state)
	if session != null:
		var carried: int = session.inventory_state().contents_weight(ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, player.character_id))
		_show(state, &"burden", "%d / %d" % [carried, player.maximum_encumbrance])
		_show(state, &"weight", str(player.body_facts.body_weight))


## A number's cell: its name and `value`, or nothing while it has no use.
func _show(state: CharacterState, stat_id: StringName, value: String) -> void:
	var cell: StatCell = cells[stat_id]
	cell.visible = GameContent.catalog().stat_shown(stat_id, state)
	cell.show_stat("%s %s" % [StatCell.stat_name(stat_id), value], StatCell.stat_hint(stat_id))


## Native (A2): the potential the player can keep unspent, and the catch-up where they are.
func _show_pacing(player: WorldPlayerRuntimeState) -> void:
	var state: CharacterState = player.state
	var unspent: int = state.progression.potential - state.progression.potential_spent
	var cap: int = WorldProgressionRewards.potential_cap(state)
	# TRANSLATORS: the character sheet (A2): unspent potential / the most kept unspent; full when it is there.
	potential_cap.show_stat(tr("可用潜能 {unspent} / {cap}").format({"unspent": unspent, "cap": cap}) + (tr("（已满，先去请教或自学）") if unspent >= cap else ""), StatCell.stat_hint(&"potential"))
	var location: WorldLocationState = player.world_location()
	var zone_id: StringName = &"" if location == null else location.zone_id
	var percent: int = WorldProgressionRewards.catch_up_percent(state, zone_id)
	catch_up.visible = percent > 0
	if percent > 0:
		var region: RegionDefinition = WorldProgressionRewards.region_of_zone(zone_id)
		# TRANSLATORS: the character sheet (A2 落后补偿): {region} recommends {recommended} combat experience; below it the player's gains are {percent}% larger.
		catch_up.text = tr("落后补偿：{region}推荐实战经验 {recommended}，你在这里所得的经验和潜能 +{percent}%，赶上后恢复。").format({
			"region": tr(region.display_name), "recommended": region.recommended_exp, "percent": percent,
		})


## The 历练 block (前两小时 A): each reward given, newest first, named as its toast named it.
## The birthplace, written down first at New Game and never rewarded
## (WorldProgressionRewards.note_birthplace()), reads as where the player was born.
func milestone_text(state: CharacterState) -> String:
	var keys: Array[String] = state.milestones.keys()
	if keys.is_empty():
		# TRANSLATORS: the character sheet's 历练 block before any reward.
		return tr("还没有历练。切磋取胜、了结一段经历、第一次到一个地方，都算。")
	keys.sort_custom(func(a: String, b: String) -> bool: return int(state.milestones[a]) > int(state.milestones[b]))
	var lines: Array[String] = []
	for key: String in keys.slice(0, MILESTONES_SHOWN):
		lines.append(_milestone_line(key, int(state.milestones[key]) == 1 and key.begins_with("region/")))
	if keys.size() > MILESTONES_SHOWN:
		# TRANSLATORS: the character sheet's 历练 block: {count} more rewards than the lines shown.
		lines.append(tr("……还有 {count} 项").format({"count": keys.size() - MILESTONES_SHOWN}))
	return "\n".join(lines)


func _milestone_line(key: String, birthplace: bool) -> String:
	var catalog: ContentCatalog = GameContent.catalog()
	var kind: String = key.get_slice("/", 0)
	var id := StringName(key.substr(kind.length() + 1))
	if birthplace:
		var home: RegionDefinition = catalog.region(id)
		# TRANSLATORS: the character sheet's 历练 block: the region {name} the player was born in (New Game).
		return tr("生在{name}").format({"name": tr(home.display_name) if home != null else String(id)})
	match kind:
		"spar":
			var npc: NpcDefinition = catalog.npc(id)
			# TRANSLATORS: a 历练 line on the character sheet: the first spar won against {name}.
			return tr("切磋胜过{name}").format({"name": tr(npc.display_name) if npc != null else String(id)})
		"defeat":
			var npc: NpcDefinition = catalog.npc(id)
			# TRANSLATORS: a 历练 line: the first time {name} (someone of note) was beaten.
			return tr("击败{name}").format({"name": tr(npc.display_name) if npc != null else String(id)})
		"chain":
			var title: String = String(id)
			for chain: JournalChainDefinition in catalog.journal_chains():
				if chain.chain_id == id:
					title = tr(chain.title)
			# TRANSLATORS: a 历练 line: the story {name} (a 任务 chain's title) seen through.
			return tr("了结「{name}」").format({"name": title})
		"book":
			var item: ItemContentDefinition = catalog.item(id)
			# TRANSLATORS: a 历练 line: {name} (a book) read through.
			return tr("读通{name}").format({"name": tr(item.display_name) if item != null else String(id)})
		"region":
			var region: RegionDefinition = catalog.region(id)
			# TRANSLATORS: a 历练 line: the first time in {name} (a region).
			return tr("到过{name}").format({"name": tr(region.display_name) if region != null else String(id)})
		"place":
			var zone: ZoneDefinition = catalog.zone(id)
			# TRANSLATORS: a 历练 line: the first time at {name} (a named place).
			return tr("到过{name}").format({"name": tr(zone.display_name) if zone != null else String(id)})
		"force":
			# TRANSLATORS: a 历练 line: max_force reached {name} (a number) by 打坐.
			return tr("内力练到 {name}").format({"name": String(id)})
		"quest":
			var quest: StoryQuestDefinition = catalog.story_quest(id)
			# TRANSLATORS: a 历练 line: the quest {name} (its title) done.
			return tr("办成「{name}」").format({"name": tr(quest.title) if quest != null else String(id)})
	return key


## Everything the sheet shows, a line per label (tests and the log's checks).
func text() -> String:
	var lines: Array[String] = []
	for node: Node in find_children("*", "Label", true, false):
		if (node as Label).visible:
			lines.append((node as Label).text)
	return "\n".join(lines)


func _show_resource(key: StringName, resource: CharacterResourceState) -> void:
	var bar: ProgressBar = resource_bars[key]
	bar.max_value = float(maxi(resource.maximum, 1))
	bar.value = float(clampi(resource.current, 0, maxi(resource.maximum, 1)))
	resource_values[key].text = "%d / %d / %d" % [resource.current, resource.effective, resource.maximum]
	var hint: String = StatCell.stat_hint(key)
	cells[key].show_stat(StatCell.stat_name(key), hint)
	resource_values[key].tooltip_text = hint
	bar.tooltip_text = hint


## A row of number cells, wrapping as the block's width allows.
func _cells(parent: Node, node_name: String, stat_ids: Array) -> void:
	var row := HFlowContainer.new()
	row.name = node_name
	row.add_theme_constant_override("h_separation", 14)
	parent.add_child(row)
	for stat_id: StringName in stat_ids:
		cells[stat_id] = StatCell.new(String(stat_id).capitalize().replace(" ", ""))
		row.add_child(cells[stat_id])


func _row(node_name: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = node_name
	row.add_theme_constant_override("separation", 10)
	add_child(row)
	return row


## A block: its heading, then its lines.
func _block(parent: Node, node_name: String, heading: String) -> VBoxContainer:
	var box := PanelContainer.new()
	box.name = node_name
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_stylebox_override("panel", SharedGameplayLayout.item_style())
	parent.add_child(box)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 6)
	box.add_child(rows)
	var title := Label.new()
	title.name = "Heading"
	title.text = heading
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", SharedGameplayLayout.ACCENT_COLOR)
	rows.add_child(title)
	return rows


func _line(parent: Node, node_name: String, text: String = "") -> Label:
	var label := Label.new()
	label.name = node_name
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if text.is_empty():
		# Filled in the shown language (tr()).
		label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	parent.add_child(label)
	return label


## One of 精/气/神: its name and current / effective / maximum over a bar. Both labels
## expand: the menu's layout wraps every label, and one left at its minimum would shrink
## to a column of single characters.
func _resource(parent: Node, key: StringName, color: Color) -> void:
	var column := VBoxContainer.new()
	column.name = String(key).capitalize()
	column.add_theme_constant_override("separation", 3)
	parent.add_child(column)
	var row := HBoxContainer.new()
	row.name = "Line"
	column.add_child(row)
	var name_label := StatCell.new("Caption")
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_color_override("font_color", color.lightened(0.25))
	row.add_child(name_label)
	cells[key] = name_label
	var value := Label.new()
	value.name = "Value"
	value.mouse_filter = Control.MOUSE_FILTER_STOP
	value.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value.size_flags_stretch_ratio = 3.0
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value)
	resource_values[key] = value
	var bar := ProgressBar.new()
	bar.name = "Bar"
	bar.show_percentage = false
	bar.custom_minimum_size.y = 8
	var track := StyleBoxFlat.new()
	track.bg_color = Color(1, 1, 1, 0.09)
	track.set_corner_radius_all(4)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("background", track)
	bar.add_theme_stylebox_override("fill", fill)
	column.add_child(bar)
	resource_bars[key] = bar
