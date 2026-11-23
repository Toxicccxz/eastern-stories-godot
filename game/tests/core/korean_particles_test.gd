extends RefCounted

## KoreanParticles: a pair after a filled word takes the form its last sound wants (a final
## consonant, none, or ㄹ for (으)로), read past quotes and BBCode; a pair after a slot not
## filled yet, or a word it cannot read, stays as written; a line with no pair is untouched.

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_pairs()
	_test_eu_ro()
	_test_i_forms()
	_test_reading_back()
	_test_numbers()
	_test_left_as_written()
	await tree.process_frame
	return {"assertions": _count, "failures": _failures.duplicate()}


func _test_pairs() -> void:
	_same(KoreanParticles.resolve("장검을(를) 들었다."), "장검을 들었다.", "을 after a consonant")
	_same(KoreanParticles.resolve("술부대을(를) 건넸다."), "술부대를 건넸다.", "를 after a vowel")
	_same(KoreanParticles.resolve("유순풍이(가) 웃었다."), "유순풍이 웃었다.", "이")
	_same(KoreanParticles.resolve("점소이이(가) 웃었다."), "점소이가 웃었다.", "가")
	_same(KoreanParticles.resolve("당신은(는) 피했다."), "당신은 피했다.", "은")
	_same(KoreanParticles.resolve("산적은(는) 쓰러졌다."), "산적은 쓰러졌다.", "은 after ㄱ")
	_same(KoreanParticles.resolve("그녀은(는) 웃었다."), "그녀는 웃었다.", "는")
	_same(KoreanParticles.resolve("사부과(와) 제자"), "사부와 제자", "와")
	_same(KoreanParticles.resolve("검과(와) 칼"), "검과 칼", "과")
	_same(KoreanParticles.resolve("순풍아(야)!"), "순풍아!", "아")
	_same(KoreanParticles.resolve("점소이아(야)!"), "점소이야!", "야")
	_same(KoreanParticles.resolve("술부대를(을) 건넸다."), "술부대를 건넸다.", "the pair in either order")


func _test_eu_ro() -> void:
	_same(KoreanParticles.resolve("노송림(으)로 갔다."), "노송림으로 갔다.", "으로 after ㅁ")
	_same(KoreanParticles.resolve("설정진(으)로 갔다."), "설정진으로 갔다.", "으로 after ㄴ")
	_same(KoreanParticles.resolve("경사(으)로 갔다."), "경사로 갔다.", "로 after a vowel")
	_same(KoreanParticles.resolve("관북의 길(으)로 갔다."), "관북의 길로 갔다.", "로 after ㄹ")
	_same(KoreanParticles.resolve("장검(으)로써 막았다."), "장검으로써 막았다.", "으로써 keeps what follows")


func _test_i_forms() -> void:
	_same(KoreanParticles.resolve("유순풍(이)라는 사람"), "유순풍이라는 사람", "이라는")
	_same(KoreanParticles.resolve("점소이(이)라는 사람"), "점소이라는 사람", "라는")
	_same(KoreanParticles.resolve("술(이)나 차"), "술이나 차", "이나")
	_same(KoreanParticles.resolve("차(이)나 술"), "차나 술", "나")
	_same(KoreanParticles.resolve("산적이었(였)다"), "산적이었다", "이었다")
	_same(KoreanParticles.resolve("점소이이었(였)다"), "점소이였다", "였다")


func _test_reading_back() -> void:
	_same(KoreanParticles.resolve("『선망보검』을(를) 찾는다."), "『선망보검』을 찾는다.", "past a closing quote")
	_same(KoreanParticles.resolve("[color=#c33]산적[/color]이(가) 덤빈다."), "[color=#c33]산적[/color]이 덤빈다.", "past BBCode")
	_same(KoreanParticles.resolve("“술부대”을(를)"), "“술부대”를", "past a curly quote")


func _test_numbers() -> void:
	_same(KoreanParticles.resolve("1을(를)"), "1을", "1 일")
	_same(KoreanParticles.resolve("2을(를)"), "2를", "2 이")
	_same(KoreanParticles.resolve("10을(를)"), "10을", "10 십")
	_same(KoreanParticles.resolve("1,000을(를)"), "1,000을", "1,000 천")
	_same(KoreanParticles.resolve("7(으)로"), "7로", "7 칠 takes 로")
	_same(KoreanParticles.resolve("3(으)로"), "3으로", "3 삼 takes 으로")


func _test_left_as_written() -> void:
	_same(KoreanParticles.resolve("{npc}이(가) 웃었다."), "{npc}이(가) 웃었다.", "an unfilled slot")
	_same(KoreanParticles.resolve("$N은(는) 피했다."), "$N은(는) 피했다.", "an unfilled token")
	_same(KoreanParticles.resolve("%s을(를) 샀다."), "%s을(를) 샀다.", "an unfilled printf slot")
	_same(KoreanParticles.resolve("$RESPECT은(는)"), "$RESPECT은(는)", "an unfilled $RESPECT")
	_same(KoreanParticles.resolve("이(가) 웃었다."), "이(가) 웃었다.", "nothing before it (an action after a name)")
	_same(KoreanParticles.resolve("店小二이(가)"), "店小二이(가)", "a Han character")
	_same(KoreanParticles.resolve("검 (劍)과 칼"), "검 (劍)과 칼", "a parenthesis that is no pair")
	_same(KoreanParticles.resolve("저장했습니다."), "저장했습니다.", "no pair")


func _same(got: String, want: String, label: String) -> void:
	_check(got == want, "%s: got %s, want %s" % [label, got, want])


func _check(ok: bool, label: String) -> void:
	_count += 1
	if not ok:
		_failures.append("korean_particles: " + label)
