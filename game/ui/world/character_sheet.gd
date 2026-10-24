class_name CharacterSheet
extends VBoxContainer
## The menu's 角色 page: score.c's sheet in blocks (who, 精/气/神 and the other
## resources, progress, gifts, burden). The facts are the sheet's as before; the 任务
## lines moved to the 任务 page.

var identity: Label
var rank: Label
var resource_bars: Dictionary[StringName, ProgressBar] = {}
var resource_values: Dictionary[StringName, Label] = {}
var powers: Label
var supplies: Label
var progress: Label
## A2: unspent potential against the cap, and 落后补偿 while it applies.
var potential_cap: Label
var catch_up: Label
var standing: Label
var gifts: Label
var burden: Label


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
	# TRANSLATORS: the character sheet's heading over the 精/气/神 numbers (score.c's three columns).
	_line(body, "Columns", "当前 / 有效 / 最大").add_theme_color_override("font_color", SharedGameplayLayout.MUTED_COLOR)
	for entry: Array in [[&"essence", "精", SharedGameplayLayout.ESSENCE_COLOR], [&"vitality", "气", SharedGameplayLayout.VITALITY_COLOR], [&"spirit", "神", SharedGameplayLayout.SPIRIT_COLOR]]:
		_resource(body, entry[0], entry[1], entry[2])
	powers = _line(body, "Powers")
	supplies = _line(body, "Supplies")
	var bottom := _row("Bottom")
	var growth: VBoxContainer = _block(bottom, "Growth", "修为")
	progress = _line(growth, "Progress")
	potential_cap = _line(growth, "PotentialCap")
	catch_up = _line(growth, "CatchUp")
	catch_up.add_theme_color_override("font_color", SharedGameplayLayout.ACCENT_COLOR)
	standing = _line(growth, "Standing")
	var nature: VBoxContainer = _block(bottom, "Nature", "天赋")
	gifts = _line(nature, "Gifts")
	burden = _line(self, "Burden")
	burden.add_theme_color_override("font_color", SharedGameplayLayout.MUTED_COLOR)


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
	_show_resource(&"essence", state.essence)
	_show_resource(&"vitality", state.vitality)
	_show_resource(&"spirit", state.spirit)
	# TRANSLATORS: the character sheet, score.c's 灵力 (atman) and 法力 (mana), each current / maximum.
	powers.text = tr("灵力 {atman} / {max_atman} · 法力 {mana} / {max_mana}").format({
		"atman": state.recovery.atman.current, "max_atman": state.recovery.atman.maximum,
		"mana": state.recovery.mana.current, "max_mana": state.recovery.mana.maximum,
	})
	# TRANSLATORS: the character sheet: food and water.
	supplies.text = tr("食物 {food} · 饮水 {water}").format({"food": state.recovery.food, "water": state.recovery.water})
	# TRANSLATORS: the character sheet: experience, potential and the potential spent.
	progress.text = tr("实战经验 {exp} · 潜能 {potential}（已用 {spent}）").format({
		"exp": state.progression.combat_experience, "potential": state.progression.potential, "spent": state.progression.potential_spent,
	})
	_show_pacing(player)
	# TRANSLATORS: the character sheet, score.c's lines: 杀气 (bellicosity), 综合评价 (score) and the NPCs the player has killed.
	standing.text = tr("杀气 {bellicosity} · 综合评价 {score}\n总共杀过 {kills} 个人。").format({
		"bellicosity": attr.bellicosity, "score": state.progression.score, "kills": state.progression.kills,
	})
	# TRANSLATORS: the character sheet: the eight gifts (score.c).
	gifts.text = tr("膂力 {str} · 胆识 {cor} · 悟性 {int} · 灵性 {spi}\n定力 {cps} · 容貌 {per} · 根骨 {con} · 福缘 {kar}").format({
		"str": attr.strength, "cor": attr.courage, "int": attr.intelligence, "spi": attr.spirituality,
		"cps": attr.composure, "per": attr.personality, "con": attr.constitution, "kar": attr.karma,
	})
	if session != null:
		burden.text = tr("负重 {carried} / {capacity} · 体重 {weight}").format({
			"carried": session.inventory_state().contents_weight(ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, player.character_id)),
			"capacity": player.maximum_encumbrance, "weight": player.body_facts.body_weight,
		})


## Native (A2): the potential the player can keep unspent, and the catch-up where they are.
func _show_pacing(player: WorldPlayerRuntimeState) -> void:
	var state: CharacterState = player.state
	var unspent: int = state.progression.potential - state.progression.potential_spent
	var cap: int = WorldProgressionRewards.potential_cap(state)
	# TRANSLATORS: the character sheet (A2): unspent potential / the most kept unspent; full when it is there.
	potential_cap.text = tr("可用潜能 {unspent} / {cap}").format({"unspent": unspent, "cap": cap}) + (tr("（已满，先去请教或研读）") if unspent >= cap else "")
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


## Everything the sheet shows, a line per label (tests and the log's checks).
func text() -> String:
	var lines: Array[String] = []
	for node: Node in find_children("*", "Label", true, false):
		lines.append((node as Label).text)
	return "\n".join(lines)


func _show_resource(key: StringName, resource: CharacterResourceState) -> void:
	var bar: ProgressBar = resource_bars[key]
	bar.max_value = float(maxi(resource.maximum, 1))
	bar.value = float(clampi(resource.current, 0, maxi(resource.maximum, 1)))
	resource_values[key].text = "%d / %d / %d" % [resource.current, resource.effective, resource.maximum]


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
func _resource(parent: Node, key: StringName, caption: String, color: Color) -> void:
	var column := VBoxContainer.new()
	column.name = String(key).capitalize()
	column.add_theme_constant_override("separation", 3)
	parent.add_child(column)
	var row := HBoxContainer.new()
	row.name = "Line"
	column.add_child(row)
	var name_label := Label.new()
	name_label.name = "Caption"
	name_label.text = caption
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_color_override("font_color", color.lightened(0.25))
	row.add_child(name_label)
	var value := Label.new()
	value.name = "Value"
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
