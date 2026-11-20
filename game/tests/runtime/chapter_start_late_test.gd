extends RefCounted

## The dev launcher 从第几章开始 (tests/dev/chapter_start): its starts 第九章 to 终章之后 — with 穿灵 drawn, 第九章's
## 皇叔 side, 第十章 after 潜入 and 私了 (the 抄本 and the 先帝的解读 in hand, 关北's bell by 王府干净), 终章 after the chase
## with 旋芒 in the 皇叔's hands (he came to court: the 皇叔 side) and in 萧辟尘's, and 终章之后 — checked as
## tests/support/chapter_start_check.gd says (chapter_start_test.gd has the rest). And the states no player reaches
## refused by apply() itself; and on the chase's road after 踏平了工地, the 揭发 with the 密信 as its third proof.

const Check := preload("res://tests/support/chapter_start_check.gd")

var _checks: Check = Check.new()


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_refused()
	for spec: ChapterStart.Spec in Check.specs([&"main.chapter9", &"main.chapter10", &"main.finale", &"faction.assembly"], [
		Check.spec_of(&"main.chapter9", {"pulled": true}),
		Check.spec_of(&"main.chapter10", {"side": "uncle"}),
		Check.spec_of(&"main.chapter10", {"raid": false, "side": "deal"}),
		Check.spec_of(&"main.finale", {"chased": true, "pulled": true, "who": "uncle", "side": "uncle", "sword": false}),
		Check.spec_of(&"main.finale", {"who": "xiao", "rome": false}),
		Check.spec_of(&"main.chapter10", {"chased": true, "side": "expose", "sword": false}),
	]):
		await _checks.test_start(tree, spec)
	return _checks.result()


## A state no player reaches is refused before anything is written (the panel corrects it instead; the command
## line says why).
func _test_refused() -> void:
	for values: Dictionary in [
		{"chased": true, "pulled": true, "who": "uncle", "side": "deal"}, # 旋芒 with a 皇叔 who never came to court
		{"line": "niling", "stage": "net", "who": "uncle", "side": "uncle", "quest_at": &"main.chapter10"}, # 卧底's 收网 before 第十章 is over
		{"chased": true, "rome": false, "side": "deal", "who": "self"}, # 自己拔 with five bells
	]:
		var at: StringName = values.get("quest_at", &"main.finale")
		values.erase("quest_at")
		var spec: ChapterStart.Spec = ChapterStart.spec(at, values)
		var problem: String = ChapterStart.apply(null, spec)
		_checks._check(not spec.problems().is_empty() and not problem.is_empty() and problem != "no session", "refused before the session is touched: %s (%s)" % [values, problem])
