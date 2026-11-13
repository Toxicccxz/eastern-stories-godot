extends RefCounted

## The dev launcher 从第几章开始 (tests/dev/chapter_start): its starts 第五章 to 第八章, with 第五章 and 第六章 after 第三章's chase (the fixtures' chase line, on to 关北), checked as
## tests/support/chapter_start_check.gd says (chapter_start_test.gd has the rest).

const Check := preload("res://tests/support/chapter_start_check.gd")

var _checks: Check = Check.new()


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	for spec: ChapterStart.Spec in Check.specs([&"main.chapter5", &"main.chapter6", &"main.chapter7", &"main.chapter8"], [
		Check.spec_of(&"main.chapter5", {"chased": true}),
		Check.spec_of(&"main.chapter6", {"chased": true, "exploring": true}),
	]):
		await _checks.test_start(tree, spec)
	return _checks.result()
