class_name KoreanText
extends RefCounted

## Korean as the game shows it (docs/production/korean_style.md): the particles after a
## filled name picked (KoreanParticles), and each word kept whole on a wrapped line.
##
## Korean is written with spaces between words and wraps at them, but the line breaker
## (ICU's default rules) may also break between any two Hangul syllables: 해였 / 다. A word
## joiner (U+2060, no width, no glyph) between the syllables of a word keeps it whole. The
## joiners are put in where the text is shown, never in the .po or a save, and taken out
## again before the particles are read, so a line can pass through here any number of times.

const LANGUAGE: String = "ko"
const WORD_JOINER: String = "⁠"

static var _syllable_pair: RegEx


## `text` as the shown language shows it: finished in Korean, as it is otherwise. Every place
## that puts a filled line on screen without the control translating it calls this (the
## log, toasts, the dialogue box, battle lines); a control that translates its own text gets
## it from KoreanTranslation.
static func shown(text: String) -> String:
	if text.is_empty() or TranslationServer.get_locale().get_slice("_", 0) != LANGUAGE:
		return text
	return finish(text)


## The particles picked and the words kept whole, whatever the shown language.
static func finish(text: String) -> String:
	return keep_words(KoreanParticles.resolve(without_joiners(text)))


## A word joiner between every two Hangul syllables that touch.
static func keep_words(text: String) -> String:
	if _syllable_pair == null:
		_syllable_pair = RegEx.create_from_string("([가-힣])(?=[가-힣])")
	return _syllable_pair.sub(text, "$1" + WORD_JOINER, true)


static func without_joiners(text: String) -> String:
	return text.replace(WORD_JOINER, "") if text.contains(WORD_JOINER) else text


## The index in `text` after its first `shown_count` characters that are not joiners: how
## far a line typed out a character at a time has got.
static func index_after(text: String, shown_count: int) -> int:
	if not text.contains(WORD_JOINER):
		return shown_count
	var seen: int = 0
	for index: int in text.length():
		if text[index] == WORD_JOINER:
			continue
		if seen == shown_count:
			return index
		seen += 1
	return text.length()
