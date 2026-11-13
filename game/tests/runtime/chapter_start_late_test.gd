extends RefCounted

## The dev launcher 从第几章开始 (tests/dev/chapter_start): its starts 第九章 to 终章, with 穿灵 drawn, 第九章's 皇叔 side, and 终章 with 旋芒 in the 皇叔's and in 萧辟尘's hands, checked as
## tests/support/chapter_start_check.gd says (chapter_start_test.gd has the rest).

const Check := preload("res://tests/support/chapter_start_check.gd")

var _checks: Check = Check.new()


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	for spec: ChapterStart.Spec in Check.specs([&"main.chapter9", &"main.chapter10", &"main.finale"], [
		Check.spec_of(&"main.chapter9", {"pulled": true}),
		Check.spec_of(&"main.chapter10", {"side": "uncle"}),
		Check.spec_of(&"main.finale", {"chased": true, "pulled": true, "who": "uncle", "side": "deal", "sword": false}),
		Check.spec_of(&"main.finale", {"who": "xiao"}),
	]):
		await _checks.test_start(tree, spec)
	return _checks.result()
