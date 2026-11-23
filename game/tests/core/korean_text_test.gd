extends RefCounted

## KoreanText: a Korean line finished for the screen (particles picked, a word joiner between
## the syllables of a word, none twice), only under Korean; a typed line's joiners take no
## time; KoreanTranslation gives back its messages and the filled lines it is shown finished.

const WJ: String = KoreanText.WORD_JOINER

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_keep_words()
	_test_finish()
	_test_index_after()
	_test_shown_only_in_korean()
	_test_translation()
	await tree.process_frame
	return {"assertions": _count, "failures": _failures.duplicate()}


func _test_keep_words() -> void:
	_same(KoreanText.keep_words("해였다. 설정진"), "해" + WJ + "였" + WJ + "다. 설" + WJ + "정" + WJ + "진", "joiners inside words only")
	_same(KoreanText.keep_words("新游戏 OK"), "新游戏 OK", "no Hangul, no joiner")
	_same(KoreanText.keep_words("UI 크기"), "UI 크" + WJ + "기", "Latin beside Hangul keeps its break")


func _test_finish() -> void:
	var once: String = KoreanText.finish("산적이(가) 웃었다.")
	_same(KoreanText.without_joiners(once), "산적이 웃었다.", "particles picked")
	_same(KoreanText.finish(once), once, "finishing twice changes nothing")
	var template: String = KoreanText.finish("{npc}이었(였)다")
	_check(template.contains("이" + WJ + "었(였)"), "a pair's own syllables get a joiner")
	_same(KoreanText.without_joiners(KoreanText.finish(template.replace("{npc}", "점소이"))), "점소이였다", "joiners inside a pair do not hide it")
	_same(KoreanText.without_joiners(KoreanText.finish(template.replace("{npc}", "산적"))), "산적이었다", "the consonant form")


func _test_index_after() -> void:
	var text: String = KoreanText.keep_words("가나 다")
	_check(KoreanText.index_after(text, 0) == 0, "nothing typed")
	_check(KoreanText.index_after(text, 1) == 2, "past the first syllable and its joiner")
	_check(KoreanText.index_after(text, 2) == 3, "two syllables")
	_check(KoreanText.index_after(text, 9) == text.length(), "all of it")
	_check(KoreanText.index_after("abc", 2) == 2, "no joiners: as counted")


func _test_shown_only_in_korean() -> void:
	var before: String = TranslationServer.get_locale()
	TranslationServer.set_locale("zh_CN")
	_same(KoreanText.shown("산적이(가)"), "산적이(가)", "left alone outside Korean")
	TranslationServer.set_locale("ko")
	_same(KoreanText.without_joiners(KoreanText.shown("산적이(가)")), "산적이", "finished in Korean")
	TranslationServer.set_locale(before)


func _test_translation() -> void:
	var inner := Translation.new()
	inner.locale = "ko"
	inner.add_message("你好", "안녕하시오")
	inner.add_message("{npc}笑了。", "{npc}이(가) 웃었다.")
	var wrapped := KoreanTranslation.new(inner)
	_same(_plain(wrapped.get_message("你好")), "안녕하시오", "a message")
	_check(String(wrapped.get_message("你好")).contains(WJ), "a message's words kept whole")
	_same(_plain(wrapped.get_message("{npc}笑了。")), "{npc}이(가) 웃었다.", "a template keeps its pair")
	_same(_plain(wrapped.get_message("산적이(가) 웃었다.")), "산적이 웃었다.", "a filled line")
	_same(String(wrapped.get_message("没有")), "", "not a message")
	_check(wrapped.locale == "ko", "the wrapper keeps the locale")


func _plain(text: StringName) -> String:
	return KoreanText.without_joiners(String(text))


func _same(got: String, want: String, label: String) -> void:
	_check(got == want, "%s: got %s, want %s" % [label, got, want])


func _check(ok: bool, label: String) -> void:
	_count += 1
	if not ok:
		_failures.append("korean_text: " + label)
