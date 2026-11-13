extends Control

## Dev only: 从第几章开始 — open chapter_start.tscn in the editor and press F6. Pick the chapter, the build
## and the branches that change what is there, press 开始: the game starts as usual, its menu is driven to
## a New Game, and the New Game is set up at that chapter's first step (ChapterStart); then it is the
## normal game (a save is an ordinary save, in the development slot). The last pick is remembered in
## user://chapter_start.cfg. The same as tests/dev/chapter_start/run_chapter_start.gd on the command line.
## tests/ never reaches a release.

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
var sword_drawn: OptionButton
var side: OptionButton
var who: OptionButton
var summary: Label
var _rows: Dictionary[OptionButton, Control] = {}


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.08, 0.07, 0.06)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var box := VBoxContainer.new()
	box.position = Vector2(32, 24)
	box.custom_minimum_size.x = 520.0
	box.add_theme_constant_override("separation", 8)
	add_child(box)
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
	sword_drawn = _choice(box, "第八章", ["没拔穿灵（拿了璃虹的羽）", "拔了穿灵"])
	side = _choice(box, "第九章", SIDE_NAMES)
	who = _choice(box, "第十章 谁拔了旋芒", WHO_NAMES)
	summary = Label.new()
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.custom_minimum_size.x = 520.0
	box.add_child(summary)
	var start := Button.new()
	start.text = "开始"
	start.custom_minimum_size = Vector2(160, 40)
	start.pressed.connect(begin)
	box.add_child(start)
	var note := Label.new()
	note.text = "开始后照常走主菜单的「新游戏」，进世界后写好前几章的事、长到这一章的经验、给齐该带的东西，站到这一章第一步的地方。\n之后就是普通的游戏：存档存在开发存档位。序章就是新游戏本身。"
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size.x = 520.0
	note.modulate = Color(1, 1, 1, 0.7)
	box.add_child(note)
	if remember:
		_load()
	_refresh()
	for option: OptionButton in [chapter, build, exp_tier, gender, line, sword_drawn, side, who]:
		option.item_selected.connect(func(_index: int) -> void: _refresh())
	chapter.grab_focus()


## The picks as a spec.
func current_spec() -> ChapterStart.Spec:
	var spec := ChapterStart.Spec.new()
	spec.quest = ChapterStart.START[maxi(chapter.selected, 0)]["quest"]
	spec.sword = build.selected == 0
	spec.exploring = exp_tier.selected == 1
	spec.gender = CharacterState.GENDER_FEMALE if gender.selected == 0 else CharacterState.GENDER_MALE
	spec.chased = line.selected == 1
	spec.pulled = sword_drawn.selected == 1
	spec.side = SIDES[maxi(side.selected, 0)]
	spec.who = WHOS[maxi(who.selected, 0)]
	return spec


## 开始: the picks remembered, the runner on the root, the main scene in this one's place.
func begin() -> void:
	var runner: Node = Runner.new()
	runner.name = "_dev_chapter_start"
	runner.spec = current_spec()
	if remember:
		_save()
	get_tree().root.add_child(runner)
	get_tree().change_scene_to_file.call_deferred(ProjectSettings.get_setting("application/run/main_scene"))


func _refresh() -> void:
	var at: int = maxi(chapter.selected, 0)
	_rows[line].visible = at >= ChapterStart.index_of(&"main.chapter4")
	_rows[sword_drawn].visible = at >= ChapterStart.index_of(&"main.chapter9")
	_rows[side].visible = at >= ChapterStart.index_of(&"main.chapter10")
	_rows[who].visible = at >= ChapterStart.index_of(&"main.finale")
	var spec: ChapterStart.Spec = current_spec()
	summary.text = "%s\n实战经验 %d" % [spec.describe(), ChapterStart.arrival_exp(spec)] if at > 0 else "序章：就是新游戏，什么都不改。"


func _choice(box: VBoxContainer, label_text: String, items: Array) -> OptionButton:
	var row := HBoxContainer.new()
	box.add_child(row)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 150.0
	row.add_child(label)
	var option := OptionButton.new()
	option.custom_minimum_size.x = 340.0
	for item: String in items:
		option.add_item(item)
	row.add_child(option)
	_rows[option] = row
	return option


func _load() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	for pair: Array in [[chapter, "chapter"], [build, "build"], [exp_tier, "exp"], [gender, "gender"], [line, "line"], [sword_drawn, "pulled"], [side, "side"], [who, "who"]]:
		var option: OptionButton = pair[0]
		var index: int = int(config.get_value("pick", pair[1], 0))
		if index >= 0 and index < option.item_count:
			option.select(index)


func _save() -> void:
	var config := ConfigFile.new()
	for pair: Array in [[chapter, "chapter"], [build, "build"], [exp_tier, "exp"], [gender, "gender"], [line, "line"], [sword_drawn, "pulled"], [side, "side"], [who, "who"]]:
		config.set_value("pick", pair[1], (pair[0] as OptionButton).selected)
	config.save(SETTINGS_PATH)
