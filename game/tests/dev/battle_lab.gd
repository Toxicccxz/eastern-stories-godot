extends Node

## Dev only: 试战台 — any fight set up at will, fought as the game fights. Open battle_lab.tscn in the
## editor and press F6. A New Game world with no runtime host: nothing is ever saved. tests/ never
## reaches a release.
##
## The panel sets both sides: the player (a family at a level, or the story-grown sword build; an age),
## their helpers and the foes, each row a family's fighter or a named NPC, at a level (0: as authored)
## and a count; the place (an outdoor one, cleared of its own people) and the seed. Then:
## - 摆好：everyone put down, nobody moving, to look at the lineup;
## - 开打：the fight opened to be played with the game's own battle screen (its 自动 button plays
##   for the player); the result shows here when it ends;
## - 批量：N fights from the same setup on the game's 自动, the totals shown here (BattleLabFight.run).
## The setup is remembered in user://battle_lab.cfg. H hides the panel.

const Roster := preload("res://tests/dev/battle_lab/battle_lab_roster.gd")
const SETTINGS_PATH: String = "user://battle_lab.cfg"
const PANEL_WIDTH: float = 400.0
const NPC_MATCHES: int = 60
const STORY_BUILD: String = "（不入门派·剧情成长的剑）"

signal prepared

## Off for the suite, which must not rewrite the owner's last setup.
@export var remember: bool = true
var fight: BattleLabFight
var _panel: PanelContainer
var _status: Label
var _result: Label
var _place: OptionButton
var _player_family: OptionButton
var _player_level: SpinBox
var _player_age: SpinBox
var _ally_rows: VBoxContainer
var _foe_rows: VBoxContainer
var _seed: SpinBox
var _duels: SpinBox
var _buttons: Array[Button] = []
var _busy: bool = false
## A fight opened with 开打 is running.
var _live: bool = false


## One row of a side: a family's fighter or a named NPC, its level and count.
class Row:
	extends RefCounted
	var box: VBoxContainer
	var kind: OptionButton
	var search: LineEdit
	var matches: OptionButton
	var level: SpinBox
	var count: SpinBox
	var npc_ids: Array[StringName] = []

	func spec() -> Dictionary:
		var out: Dictionary = {"level": int(level.value), "count": int(count.value)}
		var families: Array[BattleLabRoster.Family] = BattleLabRoster.families()
		if kind.selected < families.size():
			out["family"] = String(families[kind.selected].family_id)
		elif matches.selected >= 0 and matches.selected < npc_ids.size():
			out["npc"] = String(npc_ids[matches.selected])
		return out


func _ready() -> void:
	_build_panel()
	_status.text = "正在搭世界……"
	_set_busy(true)
	await get_tree().process_frame
	await get_tree().process_frame
	# Places picked here show at once: no loading screen.
	GameContent.catalog().pacing().feel.with_values({"map_loading_slice_ms": 0})
	fight = BattleLabFight.new(get_tree())
	await fight.make_session(self)
	_load_settings()
	_set_busy(false)
	_status.text = "摆好阵容，点「摆好」「开打」或「批量」"
	prepared.emit()


func _process(_delta: float) -> void:
	if not _live or fight == null or fight.session == null:
		return
	var coordinator: CombatEncounterCoordinator = fight.session.combat_encounter_coordinator()
	if coordinator.has_active_encounter():
		return
	_live = false
	_panel.visible = true
	var completion: CombatEncounterCompletionResult = coordinator.last_completion()
	var ending: CombatEncounterResult = null if completion == null else completion.terminal_result
	var player: WorldPlayerRuntimeState = fight.session.player_runtime()
	var text: String = "打完了：%s" % ("?" if ending == null else CombatEncounterResultKind.Value.find_key(ending.kind))
	text += "\n你：%s，气血 %d/%d" % [CharacterRuntimeLifeStatus.Value.find_key(player.life_status), player.state.vitality.current, player.state.vitality.maximum]
	_result.text = text
	_status.text = "再点「摆好」或「开打」重来"


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_H:
		_panel.visible = not _panel.visible
		get_viewport().set_input_as_handled()


## The panel's setup as a BattleLabFight spec.
func current_spec() -> Dictionary:
	var families: Array[BattleLabRoster.Family] = Roster.families()
	var player: Dictionary = {"level": int(_player_level.value), "age": int(_player_age.value), "family": ""}
	if _player_family.selected > 0:
		player["family"] = String(families[_player_family.selected - 1].family_id)
	var spec: Dictionary = {
		"place": String(BattleLabFight.ARENAS[maxi(_place.selected, 0)]),
		"player": player,
		"allies": _rows_spec(_ally_rows),
		"foes": _rows_spec(_foe_rows),
		"seed": int(_seed.value),
	}
	return spec


## Everyone put down as the panel says. False when it could not be (the status says why).
func set_up() -> bool:
	if _busy:
		return false
	_set_busy(true)
	_live = false
	_save_settings()
	_status.text = "正在摆……"
	_result.text = ""
	var ok: bool = await fight.setup(current_spec())
	_set_busy(false)
	if not ok:
		_status.text = "摆不成：" + fight.error
		return false
	var names: Array = (fight.allies + fight.foes).map(func(npc: NpcRuntimeState) -> String: return npc.definition().display_name)
	_status.text = "摆好了：帮手 %d、对方 %d（%s）" % [fight.allies.size(), fight.foes.size(), "、".join(names)]
	return true


func play() -> void:
	if not await set_up():
		return
	if not fight.start_live():
		_status.text = "开不了战：" + fight.error
		return
	var counts: Array[int] = fight.lineup()
	_status.text = "开打：我方 %d 人对 %d 人（H 收起面板）" % [counts[0], counts[1]]
	_result.text = ""
	_live = true
	_panel.visible = false


func run_many() -> void:
	if not await set_up():
		return
	_set_busy(true)
	var duels: int = int(_duels.value)
	_result.text = ""
	var result: BattleLabFight.Result = await fight.run(duels, int(_seed.value), func(done: int, partial: BattleLabFight.Result) -> void:
		_status.text = "批量：%d / %d，已胜 %d" % [done, duels, partial.wins])
	_set_busy(false)
	_result.text = result.summary()
	_status.text = "批量跑完 %d 场" % duels


func _build_panel() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	_panel = PanelContainer.new()
	_panel.position = Vector2(8, 8)
	var backdrop := StyleBoxFlat.new()
	backdrop.bg_color = Color(0.08, 0.07, 0.06, 0.94)
	backdrop.set_content_margin_all(8.0)
	_panel.add_theme_stylebox_override("panel", backdrop)
	layer.add_child(_panel)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(PANEL_WIDTH + 16.0, 0.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel.add_child(scroll)
	var fit: Callable = func() -> void: scroll.custom_minimum_size.y = maxf(200.0, get_viewport().get_visible_rect().size.y - 32.0)
	get_viewport().size_changed.connect(fit)
	fit.call()
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = PANEL_WIDTH
	scroll.add_child(box)
	_status = _label(box, "")
	_heading(box, "地点")
	_place = _list(box)
	for zone_id: StringName in BattleLabFight.ARENAS:
		var zone: ZoneDefinition = GameContent.catalog().zone(zone_id)
		_place.add_item("%s · %s" % [zone.display_name if zone != null else "?", zone_id])
	_heading(box, "我方 · 你")
	_player_family = _list(box)
	_player_family.add_item(STORY_BUILD)
	for family: BattleLabRoster.Family in Roster.families():
		_player_family.add_item(_family_text(family))
	var line := HBoxContainer.new()
	box.add_child(line)
	_player_level = _spin(line, "等级", 1, Roster.MAX_LEVEL, 20)
	_player_age = _spin(line, "年龄", 14, 60, 14)
	_heading(box, "我方 · 帮手")
	_ally_rows = VBoxContainer.new()
	box.add_child(_ally_rows)
	_button(box, "＋ 加一个帮手", func() -> void: _add_row(_ally_rows, {}))
	_heading(box, "对方")
	_foe_rows = VBoxContainer.new()
	box.add_child(_foe_rows)
	_button(box, "＋ 加一个对手", func() -> void: _add_row(_foe_rows, {}))
	_heading(box, "跑法")
	var dice := HBoxContainer.new()
	box.add_child(dice)
	_seed = _spin(dice, "种子（0 随机）", 0, 999999, 7)
	_seed.custom_minimum_size.x = 90.0
	_duels = _spin(dice, "场数", 1, 1000, 30)
	var actions := HBoxContainer.new()
	box.add_child(actions)
	_buttons.append(_button(actions, "摆好", set_up))
	_buttons.append(_button(actions, "开打", play))
	_buttons.append(_button(actions, "批量", run_many))
	_result = _label(box, "")
	_label(box, "等级 0 = 照原样（只对指定人物和门派模板有用）。\n门派战士 = 该门派经验最高的人，武功全放到这个等级。\n开打后用战斗界面的「自动」可以让它替你打。H：收起面板")


func _add_row(rows: VBoxContainer, spec: Dictionary) -> Row:
	var row := Row.new()
	row.box = VBoxContainer.new()
	rows.add_child(row.box)
	var top := HBoxContainer.new()
	row.box.add_child(top)
	row.kind = _list(top)
	row.kind.custom_minimum_size.x = 150.0
	var families: Array[BattleLabRoster.Family] = Roster.families()
	for family: BattleLabRoster.Family in families:
		row.kind.add_item(_family_text(family))
	row.kind.add_item("指定人物……")
	row.level = _spin(top, "级", 0, Roster.MAX_LEVEL, int(spec.get("level", 20)))
	row.count = _spin(top, "×", 1, 12, int(spec.get("count", 1)))
	_button(top, "删", func() -> void:
		row.box.queue_free())
	var pick := HBoxContainer.new()
	row.box.add_child(pick)
	row.search = LineEdit.new()
	row.search.placeholder_text = "名字或 id"
	row.search.custom_minimum_size.x = 140.0
	pick.add_child(row.search)
	row.matches = _list(pick)
	row.matches.custom_minimum_size.x = 230.0
	row.search.text_changed.connect(func(text: String) -> void: _fill_matches(row, text, &""))
	row.kind.item_selected.connect(func(index: int) -> void: pick.visible = index == families.size())
	row.box.set_meta("row", row)
	var family_index: int = families.find(Roster.family(StringName(str(spec.get("family", "")))))
	if spec.has("npc"):
		row.kind.select(families.size())
		var definition: NpcDefinition = GameContent.catalog().npc(StringName(str(spec["npc"])))
		row.search.text = definition.display_name if definition != null else str(spec["npc"])
		_fill_matches(row, row.search.text, StringName(str(spec["npc"])))
	else:
		row.kind.select(maxi(family_index, 0))
	pick.visible = row.kind.selected == families.size()
	return row


func _fill_matches(row: Row, text: String, keep: StringName) -> void:
	row.matches.clear()
	row.npc_ids.clear()
	var needle: String = text.strip_edges()
	for npc: NpcDefinition in Roster.npcs():
		if row.npc_ids.size() >= NPC_MATCHES:
			break
		if needle.is_empty() or npc.display_name.contains(needle) or String(npc.definition_id).contains(needle):
			row.npc_ids.append(npc.definition_id)
			row.matches.add_item("%s（%s，%d）" % [npc.display_name, npc.definition_id, npc.combat_experience])
	var at: int = row.npc_ids.find(keep)
	if at >= 0:
		row.matches.select(at)


func _rows_spec(rows: VBoxContainer) -> Array:
	var out: Array = []
	for child: Node in rows.get_children():
		if child.is_queued_for_deletion() or not child.has_meta("row"):
			continue
		var row: Row = child.get_meta("row")
		var spec: Dictionary = row.spec()
		if spec.has("family") or spec.has("npc"):
			out.append(spec)
	return out


func _family_text(family: BattleLabRoster.Family) -> String:
	var template: NpcDefinition = GameContent.catalog().npc(family.template_id)
	return "%s · %s" % [family.display_name, template.display_name if template != null else "?"]


func _set_busy(on: bool) -> void:
	_busy = on
	for button: Button in _buttons:
		button.disabled = on


func _heading(parent: Control, text: String) -> void:
	var label := _label(parent, "— %s —" % text)
	label.add_theme_color_override("font_color", Color("e9b84c"))


func _label(parent: Control, text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = PANEL_WIDTH
	parent.add_child(label)
	return label


func _list(parent: Control) -> OptionButton:
	var list := OptionButton.new()
	list.focus_mode = Control.FOCUS_NONE
	list.fit_to_longest_item = false
	list.clip_text = true
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(list)
	return list


func _spin(parent: Control, caption: String, low: int, high: int, value: int) -> SpinBox:
	var label := Label.new()
	label.text = caption
	parent.add_child(label)
	var spin := SpinBox.new()
	spin.min_value = low
	spin.max_value = high
	spin.value = value
	spin.custom_minimum_size.x = 64.0
	spin.select_all_on_focus = true
	parent.add_child(spin)
	return spin


func _button(parent: Control, text: String, pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(pressed)
	parent.add_child(button)
	return button


func _load_settings() -> void:
	var spec: Dictionary = {}
	if remember:
		var settings := ConfigFile.new()
		if settings.load(SETTINGS_PATH) == OK:
			var data: Variant = JSON.parse_string(str(settings.get_value("lab", "spec", "")))
			spec = data if data is Dictionary else {}
			_duels.value = int(settings.get_value("lab", "duels", _duels.value))
	if spec.is_empty():
		spec = {"player": {"family": "family.fonxan", "level": 30, "age": 14}, "foes": [{"family": "family.celestial", "level": 30, "count": 1}], "seed": 7}
	_place.select(maxi(BattleLabFight.ARENAS.find(StringName(str(spec.get("place", BattleLabFight.DEFAULT_PLACE)))), 0))
	var player: Dictionary = spec.get("player", {})
	_player_family.select(Roster.families().find(Roster.family(StringName(str(player.get("family", ""))))) + 1)
	_player_level.value = int(player.get("level", 20))
	_player_age.value = int(player.get("age", 14))
	_seed.value = int(spec.get("seed", 7))
	for fighter: Variant in spec.get("allies", []):
		_add_row(_ally_rows, fighter)
	for fighter: Variant in spec.get("foes", []):
		_add_row(_foe_rows, fighter)
	if _foe_rows.get_child_count() == 0:
		_add_row(_foe_rows, {})


func _save_settings() -> void:
	if not remember:
		return
	var settings := ConfigFile.new()
	settings.set_value("lab", "spec", JSON.stringify(current_spec()))
	settings.set_value("lab", "duels", int(_duels.value))
	settings.save(SETTINGS_PATH)
