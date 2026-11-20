extends Control

## Dev only: 从第几章开始 — open chapter_start.tscn in the editor and press F6. Pick the chapter, the build
## and the branches that change what is there (and, if wanted, a faction line and the step it stands at),
## press 开始: the game starts as usual, its menu is driven to a New Game, and the New Game is set up at that
## chapter's first step (ChapterStart); then it is the normal game (a save is an ordinary save, in the
## development slot). A pick no player can reach (旋芒 in the 皇叔's hands when he never came to court, drawn yourself
## under six bells, a faction step before its chapter) is corrected at once and the panel says what changed and
## why (ChapterStart.Spec.corrected). The last pick is remembered in user://chapter_start.cfg. The same as
## tests/dev/chapter_start/run_chapter_start.gd on the command line. tests/ never reaches a release.

const Runner := preload("res://tests/dev/chapter_start/chapter_start_runner.gd")
const SETTINGS_PATH: String = "user://chapter_start.cfg"
const SIDES: Array[String] = ["expose", "deal", "uncle"]
const SIDE_NAMES: Array[String] = ["揭发（庾子建下狱）", "私了", "皇叔（手诏入朝）"]
const WHOS: Array[String] = ["self", "uncle", "xiao"]
const WHO_NAMES: Array[String] = ["你自己", "皇叔", "萧辟尘"]

## Off for the suite, which must neither rewrite the owner's last pick nor start a game.
@export var remember: bool = true
var chapter: OptionButton
var build: OptionButton
var exp_tier: OptionButton
var gender: OptionButton
var line: OptionButton
var road: OptionButton
var camp: OptionButton
var sword_drawn: OptionButton
var side: OptionButton
var who: OptionButton
var faction: OptionButton
var faction_stage: OptionButton
var summary: Label
## What the last refresh corrected (empty: the picks were reachable as made).
var correction: Label
var _rows: Dictionary[OptionButton, Control] = {}
var _stage_line: int = -1
var _refreshing: bool = false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.08, 0.07, 0.06)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(scroll)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	scroll.add_child(margin)
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = 560.0
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)
	var heading := Label.new()
	heading.text = "从第几章开始（开发用）"
	heading.add_theme_font_size_override("font_size", 26)
	box.add_child(heading)
	chapter = _choice(box, "章", [])
	for entry: Dictionary in ChapterStart.START:
		chapter.add_item(ChapterStart.title(entry["quest"]))
	build = _choice(box, "身手", ["封山剑法，手里拿剑", "柳家拳，空手"])
	exp_tier = _choice(box, "经验", ["只走主线的玩家", "边走边逛的玩家"])
	gender = _choice(box, "主角", ["女", "男"])
	line = _choice(box, "第三章", ["救人（霍铮、石头出来）", "追宫主（宝衣带走、放走陈显祖）"])
	road = _choice(box, "第六章", ["借兵（踏平工地）", "潜入（救一半）"])
	camp = _choice(box, "第七章", ["站大秦人", "站浪人"])
	sword_drawn = _choice(box, "第八章", ["没拔穿灵（拿了璃虹的羽）", "拔了穿灵"])
	side = _choice(box, "第九章", SIDE_NAMES)
	who = _choice(box, "第十章 谁拔了旋芒", WHO_NAMES)
	faction = _choice(box, "势力线", ["不选"])
	for entry: Dictionary in ChapterStart.LINES:
		faction.add_item(entry["title"])
	faction_stage = _choice(box, "势力线走到", [])
	summary = Label.new()
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.custom_minimum_size.x = 560.0
	box.add_child(summary)
	correction = Label.new()
	correction.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	correction.custom_minimum_size.x = 560.0
	correction.modulate = Color(1.0, 0.75, 0.45)
	box.add_child(correction)
	var start := Button.new()
	start.text = "开始"
	start.custom_minimum_size = Vector2(160, 40)
	start.pressed.connect(begin)
	box.add_child(start)
	var note := Label.new()
	note.text = "开始后照常走主菜单的「新游戏」，进世界后写好前几章的事（选了势力线，也写好这条线走到的那一步）、长到这一章的经验、给齐该带的东西，前几章打倒、送走的人不再站着，站到这一章第一步（或势力线下一步）的地方。\n之后就是普通的游戏：存档存在开发存档位（手动存档不动，开发存档位的自动存档会被这一局盖掉）。序章就是新游戏本身。"
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size.x = 560.0
	note.modulate = Color(1, 1, 1, 0.7)
	box.add_child(note)
	if remember:
		_load()
	_refresh()
	for option: OptionButton in [chapter, build, exp_tier, gender, line, road, camp, sword_drawn, side, who, faction, faction_stage]:
		option.item_selected.connect(func(_index: int) -> void: _refresh())
	chapter.grab_focus()


## The picks as a spec (as made; _refresh() has corrected them already).
func current_spec() -> ChapterStart.Spec:
	var spec := ChapterStart.Spec.new()
	spec.quest = ChapterStart.START[maxi(chapter.selected, 0)]["quest"]
	spec.sword = build.selected == 0
	spec.exploring = exp_tier.selected == 1
	spec.gender = CharacterState.GENDER_FEMALE if gender.selected == 0 else CharacterState.GENDER_MALE
	spec.chased = line.selected == 1
	spec.raid = road.selected != 1
	spec.rome = camp.selected != 1
	spec.pulled = sword_drawn.selected == 1
	spec.side = SIDES[maxi(side.selected, 0)]
	spec.who = WHOS[maxi(who.selected, 0)]
	if faction.selected > 0 and chapter.selected > 0:
		var entry: Dictionary = ChapterStart.LINES[faction.selected - 1]
		var stages: Array = entry["stages"]
		spec.line = entry["key"]
		spec.stage = stages[clampi(faction_stage.selected, 0, stages.size() - 1)]["key"]
	return spec


## 开始: the picks remembered, the runner on the root, the main scene in this one's place.
func begin() -> void:
	_refresh()
	var runner: Node = Runner.new()
	runner.name = "_dev_chapter_start"
	runner.spec = current_spec()
	if remember:
		_save()
	get_tree().root.add_child(runner)
	get_tree().change_scene_to_file.call_deferred(ProjectSettings.get_setting("application/run/main_scene"))


func _refresh() -> void:
	if _refreshing:
		return
	_refreshing = true
	var at: int = maxi(chapter.selected, 0)
	_rows[line].visible = at >= ChapterStart.index_of(&"main.chapter4")
	_rows[road].visible = at >= ChapterStart.index_of(&"main.chapter7")
	_rows[camp].visible = at >= ChapterStart.index_of(&"main.chapter8")
	_rows[sword_drawn].visible = at >= ChapterStart.index_of(&"main.chapter9")
	_rows[side].visible = at >= ChapterStart.index_of(&"main.chapter10")
	_rows[who].visible = at >= ChapterStart.index_of(&"main.finale")
	_rows[faction].visible = at > 0
	_fill_stages(faction.selected)
	_rows[faction_stage].visible = at > 0 and faction.selected > 0
	var spec: ChapterStart.Spec = current_spec()
	var changes: Array[String] = []
	if at > 0:
		changes = spec.corrected()
	if not changes.is_empty():
		_show(spec)
		spec = current_spec()
	correction.text = "" if changes.is_empty() else "已改：" + "；".join(changes)
	if at == 0:
		summary.text = "序章：就是新游戏，什么都不改。"
	else:
		summary.text = "%s\n实战经验 %d" % [spec.describe(), ChapterStart.arrival_exp(spec)]
		if at >= ChapterStart.index_of(&"main.chapter10"):
			summary.text += "；风铃阁会响 %d 口铃，终章能来 %d 拨帮手（不算势力线的）" % [ChapterStart.bells(spec), ChapterStart.roll_call(spec)]
	_refreshing = false


## The stage options of the line at `line_at` (0: none), refilled only when the line changed.
func _fill_stages(line_at: int) -> void:
	if _stage_line == line_at:
		return
	_stage_line = line_at
	faction_stage.clear()
	if line_at <= 0:
		return
	for entry: Dictionary in ChapterStart.LINES[line_at - 1]["stages"]:
		faction_stage.add_item("%s（从%s起）" % [entry["title"], ChapterStart.title(entry["from"])])
	faction_stage.select(0)


## The options set to `spec`'s choices (after a correction).
func _show(spec: ChapterStart.Spec) -> void:
	road.select(0 if spec.raid else 1)
	camp.select(0 if spec.rome else 1)
	side.select(maxi(SIDES.find(spec.side), 0))
	who.select(maxi(WHOS.find(spec.who), 0))
	var line_at: int = 0
	for at: int in ChapterStart.LINES.size():
		if ChapterStart.LINES[at]["key"] == spec.line:
			line_at = at + 1
	faction.select(line_at)
	_fill_stages(line_at)
	_rows[faction_stage].visible = line_at > 0
	if line_at > 0:
		var stages: Array = ChapterStart.LINES[line_at - 1]["stages"]
		for at: int in stages.size():
			if stages[at]["key"] == spec.stage:
				faction_stage.select(at)


func _choice(box: VBoxContainer, label_text: String, items: Array) -> OptionButton:
	var row := HBoxContainer.new()
	box.add_child(row)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 150.0
	row.add_child(label)
	var option := OptionButton.new()
	option.custom_minimum_size.x = 380.0
	for item: String in items:
		option.add_item(item)
	row.add_child(option)
	_rows[option] = row
	return option


const PICKS: Array[String] = ["chapter", "build", "exp", "gender", "line", "road", "camp", "pulled", "side", "who", "faction", "stage"]


func _options() -> Array[OptionButton]:
	return [chapter, build, exp_tier, gender, line, road, camp, sword_drawn, side, who, faction, faction_stage]


func _load() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	var options: Array[OptionButton] = _options()
	for at: int in PICKS.size():
		if options[at] == faction_stage:
			_fill_stages(faction.selected)
		var index: int = int(config.get_value("pick", PICKS[at], 0))
		if index >= 0 and index < options[at].item_count:
			options[at].select(index)


func _save() -> void:
	var config := ConfigFile.new()
	var options: Array[OptionButton] = _options()
	for at: int in PICKS.size():
		config.set_value("pick", PICKS[at], options[at].selected)
	config.save(SETTINGS_PATH)
