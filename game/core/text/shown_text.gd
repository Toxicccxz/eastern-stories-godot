class_name ShownText
extends RefCounted

## A filled line as the shown language shows it. Most languages show it as it is; three finish
## it once the names are in:
##
##   Korean (KoreanText): the particle after a name picked, words kept whole on a wrapped line;
##   Russian (RussianText): a name put in its case, words agreeing with its gender or a number;
##   Spanish (SpanishText): a name given its article, words agreeing with its gender or a number.
##
## Every place that puts a filled line on screen without the control translating it calls of()
## (the log, toasts, the dialogue box, battle lines); a control that translates its own text
## gets it finished from FinishedTranslation.


## `text` as the shown language shows it.
static func of(text: String) -> String:
	if text.is_empty():
		return text
	return finish(text, TranslationServer.get_locale().get_slice("_", 0))


## `text` finished for `language` (a locale's language part: ko, ru…).
static func finish(text: String, language: String) -> String:
	match language:
		KoreanText.LANGUAGE:
			return KoreanText.finish(text)
		RussianText.LANGUAGE:
			return RussianText.finish(text)
		SpanishText.LANGUAGE:
			return SpanishText.finish(text)
	return text


## `text` as a label that stands alone (a topic button): its first letter a capital where the
## shown language has capitals. Russian writes a word that is also filled into sentences (姑娘
## барышня, a topic and a form of address) in lower case; its button still opens with a capital.
static func label(text: String) -> String:
	if text.is_empty():
		return text
	return text.left(1).to_upper() + text.substr(1)


## Whether `language` finishes its lines (and so loads its catalog through FinishedTranslation).
static func finishes(language: String) -> bool:
	return language == KoreanText.LANGUAGE or language == RussianText.LANGUAGE or language == SpanishText.LANGUAGE
