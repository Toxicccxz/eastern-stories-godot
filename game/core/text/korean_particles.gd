class_name KoreanParticles
extends RefCounted

## Korean particles after a filled slot (docs/production/korean_style.md; KoreanText shows them). A Korean particle
## takes one form after a final consonant (받침) and another after a vowel: 검을 / 칼을 vs
## 부대를. A template does not know the name a slot will hold, so the translation writes both
## forms after a slot or token, the consonant form first, and resolve() picks one once the
## line is filled:
##
##   {npc}이(가)  {item}을(를)  $N은(는)  {name}과(와)  {who}아(야)   one of the pair
##   {place}(으)로  {weapon}(으)로써                         으로, or 로 after a vowel or ㄹ
##   {name}(이)라는  {thing}(이)나  {who}(이)여                이 stays after a consonant
##   {name}이었(였)다                                          이었다 / 였다
##
## The word before the pair is read past closing quotes, brackets and BBCode tags
## (『{topic}』을(를), [color=…]{npc}[/color]이(가)). A word it cannot read (a slot not filled
## yet, a Han character, a symbol) keeps the pair as written: 이(가) still reads as Korean.
## A pair the translator wrote after plain text is a slip check_po.py reports.

## consonant form, vowel form.
const PAIRS: Array[Array] = [
	["은", "는"], ["이", "가"], ["을", "를"], ["과", "와"], ["아", "야"], ["이여", "여"], ["이었", "였"],
]
const _CLOSERS: String = "』」”’\"')]>》〉"  # NO_TRANSLATE: closing quotes and brackets

static var _pattern: RegEx


## `text` with every pair after a readable word resolved; unchanged when it has none.
static func resolve(text: String) -> String:
	if not text.contains("("):
		return text
	if _pattern == null:
		_pattern = RegEx.create_from_string(_pattern_source())
	var found: Array[RegExMatch] = _pattern.search_all(text)
	if found.is_empty():
		return text
	var out: String = ""
	var at: int = 0
	for match_: RegExMatch in found:
		var start: int = match_.get_start()
		out += text.substr(at, start - at)
		at = match_.get_end()
		var ending: int = final_sound(text, start)
		out += _choose(match_.get_string(), ending) if ending != UNKNOWN else match_.get_string()
	out += text.substr(at)
	return out


## What the word before `before` ends in: NO_FINAL (a vowel), RIEUL (ㄹ), FINAL (another
## consonant) or UNKNOWN.
const UNKNOWN: int = -1
const NO_FINAL: int = 0
const FINAL: int = 1
const RIEUL: int = 2


static func final_sound(text: String, before: int) -> int:
	var index: int = before - 1
	while index >= 0:
		var c: String = text[index]
		if c == "]":
			var opening: int = text.rfind("[", index)
			if opening < 0:
				return UNKNOWN
			index = opening - 1
			continue
		if _CLOSERS.contains(c):
			index -= 1
			continue
		break
	if index < 0:
		return UNKNOWN
	var code: int = text.unicode_at(index)
	if code >= 0xAC00 and code <= 0xD7A3:
		var tail: int = (code - 0xAC00) % 28
		if tail == 0:
			return NO_FINAL
		return RIEUL if tail == 8 else FINAL
	if code >= 0x30 and code <= 0x39:
		return _digit_sound(text, index)
	var letter: String = String.chr(code).to_lower()
	if letter >= "a" and letter <= "z":
		var word_start: int = index
		while word_start > 0 and _is_latin(text[word_start - 1]):
			word_start -= 1
		if word_start > 0 and text[word_start - 1] in ["$", "%"]:
			return UNKNOWN  # a token or printf slot not filled yet: $N, $RESPECT, %s
		if letter == "l":
			return RIEUL
		return FINAL if "mnbkpt".contains(letter) else NO_FINAL
	return UNKNOWN


## A number read in Sino-Korean: 1 일, 3 삼, 10 십, 100 백, 1000 천, 10000 만.
## Trailing zeros name the last unit read (10 십, 100 백, 1000 천, 10000 만, 10⁸ 억: all
## closed; 10¹² 조: open); a lone 0 is 영. A thousands comma ends the run (1,000: 천).
const _DIGIT_SOUNDS: Array[int] = [FINAL, RIEUL, NO_FINAL, FINAL, NO_FINAL, NO_FINAL, FINAL, RIEUL, RIEUL, NO_FINAL]


static func _digit_sound(text: String, last: int) -> int:
	var zeros: int = 0
	var index: int = last
	while index >= 0 and text[index] == "0":
		zeros += 1
		index -= 1
	if zeros == 0:
		return _DIGIT_SOUNDS[text.unicode_at(last) - 0x30]
	return NO_FINAL if zeros >= 12 else FINAL


static func _choose(written: String, ending: int) -> String:
	if written.begins_with("(으)"):
		return written.substr(3) if ending != FINAL else "으" + written.substr(3)
	if written.begins_with("(이)"):
		return written.substr(3) if ending == NO_FINAL else "이" + written.substr(3)
	var opening: int = written.find("(")
	var first: String = written.substr(0, opening)
	var second: String = written.substr(opening + 1, written.length() - opening - 2)
	for pair: Array in PAIRS:
		if (first == pair[0] and second == pair[1]) or (first == pair[1] and second == pair[0]):
			return pair[1] if ending == NO_FINAL else pair[0]
	return written


static func _pattern_source() -> String:
	var alternatives: PackedStringArray = ["\\(으\\)로", "\\(이\\)(?=[가-힣])"]
	for pair: Array in PAIRS:
		alternatives.append("%s\\(%s\\)" % [pair[0], pair[1]])
		alternatives.append("%s\\(%s\\)" % [pair[1], pair[0]])
	return "|".join(alternatives)


static func _is_latin(c: String) -> bool:
	var lower: String = c.to_lower()
	return lower >= "a" and lower <= "z"
