extends RefCounted

## The dev launcher 从第几章开始 (tests/dev/chapter_start): every faction line's every stage (ChapterStart.LINES), from the
## first start it can be had at — the line begun at its stage's next step, the player at that step's place — checked as
## tests/support/chapter_start_check.gd says. Half of them (the lines 封山 to 晚月; chapter_start_lines_b_test.gd the rest).

const Check := preload("res://tests/support/chapter_start_check.gd")
const HALF: int = 0

var _checks: Check = Check.new()


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	var lines: Array = ChapterStart.LINES.slice(0, 6) if HALF == 0 else ChapterStart.LINES.slice(6)
	for line: Dictionary in lines:
		for stage: Dictionary in line["stages"]:
			await _checks.test_start(tree, Check.spec_of(stage["from"], {"line": line["key"], "stage": stage["key"], "sword": stage["key"] != "join"}))
	return _checks.result()
