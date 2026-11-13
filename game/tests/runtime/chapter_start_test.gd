extends RefCounted

## The dev launcher 从第几章开始 (tests/dev/chapter_start; ROADMAP「After the grey box」step 1): its
## command-line words, its F6 panel, the runner driving the real shell's menu to a New Game set up at
## 第七章, and the starts 序章 to 第四章 (with 第三章 bare-handed and 第四章 after the chase) checked as
## tests/support/chapter_start_check.gd says. The later chapters: chapter_start_middle_test.gd and
## chapter_start_late_test.gd.

const Check := preload("res://tests/support/chapter_start_check.gd")
const Runner := preload("res://tests/dev/chapter_start/chapter_start_runner.gd")
const PickerScene := preload("res://tests/dev/chapter_start.tscn")
const ShellFixtures := preload("res://tests/application/application_shell_phase10c1c_test.gd")
const SHELL_SCENE: PackedScene = preload("res://scenes/application/application_shell.tscn")

var _checks: Check = Check.new()


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_words()
	await _test_panel(tree)
	for spec: ChapterStart.Spec in Check.specs([&"main.prologue", &"main.chapter1", &"main.chapter2", &"main.chapter3", &"main.chapter4"], [
		Check.spec_of(&"main.chapter3", {"sword": false, "gender": CharacterState.GENDER_MALE}),
		Check.spec_of(&"main.chapter4", {"chased": true}),
	]):
		await _checks.test_start(tree, spec)
	await _test_through_the_shell(tree)
	return _checks.result()


func _test_words() -> void:
	var spec: ChapterStart.Spec = Runner.parse(PackedStringArray(["7", "fist", "chase", "male"]))
	_check(spec != null and spec.quest == &"main.chapter7" and not spec.sword and spec.chased and spec.gender == CharacterState.GENDER_MALE, "words: 7 fist chase male")
	spec = Runner.parse(PackedStringArray(["finale", "pulled", "side=deal", "who=xiao", "explore"]))
	_check(spec != null and spec.quest == &"main.finale" and spec.pulled and spec.side == "deal" and spec.who == "xiao" and spec.exploring and spec.sword, "words: finale pulled side=deal who=xiao explore")
	_check(Runner.parse(PackedStringArray(["chapter10"])).quest == &"main.chapter10" and Runner.parse(PackedStringArray(["prologue"])).quest == &"main.prologue", "words: chapter10, prologue")
	_check(Runner.parse(PackedStringArray(["11"])) == null and Runner.parse(PackedStringArray(["3", "who=me"])) == null and Runner.parse(PackedStringArray()) == null, "words: an unknown chapter or word is refused")
	_check(ChapterStart.title(&"main.chapter7") == "第七章 番坊" and ChapterStart.title(&"main.prologue") == "序章 寻剑令" and ChapterStart.title(&"main.finale") == "终章 回到湖底", "titles as the journal names the chapters")
	var previous: int = -1
	for entry: Dictionary in ChapterStart.START:
		var arrival: int = ChapterStart.arrival_exp(Check.spec_of(entry["quest"]))
		_check(arrival >= previous and arrival > 0, "%s: arrival exp %d, not below the chapter before" % [entry["quest"], arrival])
		previous = arrival


func _test_panel(tree: SceneTree) -> void:
	var panel: Control = PickerScene.instantiate()
	panel.remember = false
	tree.root.add_child(panel)
	await tree.process_frame
	_check(panel.chapter.item_count == ChapterStart.START.size() and panel.chapter.get_item_text(7) == "第七章 番坊", "the panel offers every chapter, 序章 to 终章")
	panel.chapter.select(ChapterStart.index_of(&"main.chapter2"))
	panel.chapter.item_selected.emit(panel.chapter.selected)
	_check(not panel.line.get_parent().visible and not panel.who.get_parent().visible, "第二章: no branch rows")
	panel.chapter.select(ChapterStart.index_of(&"main.finale"))
	panel.chapter.item_selected.emit(panel.chapter.selected)
	panel.build.select(1)
	panel.line.select(1)
	panel.sword_drawn.select(1)
	panel.side.select(2)
	panel.who.select(2)
	panel.build.item_selected.emit(1)
	var spec: ChapterStart.Spec = panel.current_spec()
	_check(panel.line.get_parent().visible and panel.who.get_parent().visible, "终章: every branch row")
	_check(spec.quest == &"main.finale" and not spec.sword and spec.chased and spec.pulled and spec.side == "uncle" and spec.who == "xiao", "the picks as a spec: %s" % spec.describe())
	_check(panel.summary.text.contains("旋芒在萧辟尘手里") and panel.summary.text.contains(str(ChapterStart.arrival_exp(spec))), "the summary names the branches and the exp: %s" % panel.summary.text)
	panel.free()


## The runner on the real shell: its main menu driven to a New Game, the New Game set up at 第七章.
func _test_through_the_shell(tree: SceneTree) -> void:
	var shell: ApplicationShellController = SHELL_SCENE.instantiate()
	_check(shell.configure_before_start(GameSaveStorageProfile.isolated_test("chapter-start-shell"), ShellFixtures.MemoryFiles.new(), null, ShellFixtures.MemoryFiles.new(), ShellFixtures.FakeWindowCapability.new()), "the shell on a test profile")
	tree.root.add_child(shell)
	var scene: Node = tree.current_scene
	tree.current_scene = shell
	var runner: Node = Runner.new()
	runner.spec = Runner.parse(PackedStringArray(["7", "fist"]))
	tree.root.add_child(runner)
	for frame: int in 60 * 60:
		if not is_instance_valid(runner):
			break
		await tree.process_frame
	_check(not is_instance_valid(runner), "the runner has done its work and gone")
	var session: WorldSessionController = null if shell.runtime_host() == null else shell.runtime_host().current_session()
	_check(shell.shell_state().mode() == ApplicationShellState.Mode.PLAYING and session != null, "the shell plays the New Game")
	if session != null:
		var state: CharacterState = session.player_runtime().state
		var quest: StoryQuestDefinition = GameContent.catalog().story_quest(&"main.chapter7")
		_check(StoryQuestLog.current_step(state, quest) == quest.steps[0] and session.player_runtime().world_location().zone_id == &"village.valley1", "第七章's first step, outside 忘情谷")
		_check(session.shared_ui().log_lines().any(func(line: String) -> bool: return line.contains("第七章 番坊") and line.contains("拳")), "the log says where the dev start began")
	if is_instance_valid(runner):
		runner.free()
	tree.current_scene = scene
	shell.get_parent().remove_child(shell)
	shell.free()
	await tree.process_frame


func _check(ok: bool, label: String) -> void:
	_checks._check(ok, label)
