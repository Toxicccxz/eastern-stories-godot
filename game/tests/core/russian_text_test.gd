extends RefCounted

## RussianText and RussianNouns: a filled name in the case its mark asks for (вы as вас, a name
## with no row as written), a word agreeing with that name's gender or a number, marks after a
## slot not filled yet kept for the filled line; MessageGrammar's three- and four-form marks by
## the player and the Russian name's gender; capitals for Cyrillic.

const ROWS: Dictionary = {
	"бандит": ["м", "бандита", "бандиту", "бандита", "бандитом", "бандите", "бандита", "бандитов"],
	"бродячая собака": ["ж", "бродячей собаки", "бродячей собаке", "бродячую собаку", "бродячей собакой", "бродячей собаке", "бродячие собаки", "бродячих собак"],
	"кожаный бурдюк": ["м", "кожаного бурдюка", "кожаному бурдюку", "кожаный бурдюк", "кожаным бурдюком", "кожаном бурдюке", "кожаных бурдюка", "кожаных бурдюков"],
	"Лю Чуньфэн": ["м", "Лю Чуньфэна", "Лю Чуньфэну", "Лю Чуньфэна", "Лю Чуньфэном", "Лю Чуньфэне", "", ""],
	"Лань Чжипин": ["ж", "", "", "", "", "", "", ""],
	"слуга": ["м", "слуги", "слуге", "слугу", "слугой", "слуге", "слуги", "слуг"],
}

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	RussianNouns.use(ROWS)
	_test_cases()
	_test_gender()
	_test_numbers()
	_test_unfilled()
	_test_message_grammar()
	_test_shown()
	RussianNouns.reset()
	_test_shipped_rows()
	await tree.process_frame
	return {"assertions": _count, "failures": _failures.duplicate()}


func _test_cases() -> void:
	_same(RussianText.finish("Вы бьёте бандит{:в}."), "Вы бьёте бандита.", "accusative")
	_same(RussianText.finish("Вы отдаёте кожаный бурдюк{:в} бандит{:д}."), "Вы отдаёте кожаный бурдюк бандиту.", "two names, two cases")
	_same(RussianText.finish("Бандит{:и} рычит."), "Бандит рычит.", "a capital kept (nominative)")
	_same(RussianText.finish("Бандит{:т} доволен."), "Бандитом доволен.", "a capital kept")
	_same(RussianText.finish("Вы смотрите на бродячая собака{:в}."), "Вы смотрите на бродячую собаку.", "a name of two words")
	_same(RussianText.finish("Вы кланяетесь Лю Чуньфэн{:д}."), "Вы кланяетесь Лю Чуньфэну.", "a Chinese name that declines")
	_same(RussianText.finish("Вы кланяетесь Лань Чжипин{:д}."), "Вы кланяетесь Лань Чжипин.", "one that does not")
	_same(RussianText.finish("Бандит бьёт вы{:в}!"), "Бандит бьёт вас!", "вы")
	_same(RussianText.finish("Вы{:д} везёт."), "Вам везёт.", "Вы with its capital")
	_same(RussianText.finish("Вы бьёте [color=red]бандит[/color]{:в}."), "Вы бьёте [color=red]бандита[/color].", "past a BBCode tag")
	_same(RussianText.finish("Вы зовёте «бандит»{:в}."), "Вы зовёте «бандита».", "past a quote")
	_same(RussianText.finish("Вы бьёте пугало{:в}."), "Вы бьёте пугало.", "a name with no row stays")
	_same(RussianText.finish("Без меток."), "Без меток.", "no marks")


func _test_gender() -> void:
	_same(RussianText.finish("Бандит{:и} {~:ушёл|ушла|ушло|ушли}."), "Бандит ушёл.", "м")
	_same(RussianText.finish("Бродячая собака{:и} {~:ушёл|ушла|ушло|ушли}."), "Бродячая собака ушла.", "ж by the noun")
	_same(RussianText.finish("Вы{:и} {~:ушёл|ушла|ушло|ушли}."), "Вы ушли.", "вы takes the plural")
	_same(RussianText.finish("Вы{:и} {~:ушёл|ушла}."), "Вы ушёл.", "two forms: мн takes м")
	_same(RussianText.finish("Вам {~:ответил|ответила} Лань Чжипин{:и}."), "Вам ответила Лань Чжипин.", "a name after the word")
	_same(RussianText.finish("Пугало{:и} {~:упал|упала|упало}."), "Пугало упал.", "a name with no row: the first form")
	_same(RussianText.finish("Слуга{:и} {~:пришёл|пришла} к бандит{:д}."), "Слуга пришёл к бандиту.", "the nearest name before")


func _test_numbers() -> void:
	_same(RussianText.finish("Прошло 1 {#:день|дня|дней}."), "Прошло 1 день.", "1")
	_same(RussianText.finish("Прошло 3 {#:день|дня|дней}."), "Прошло 3 дня.", "3")
	_same(RussianText.finish("Прошло 11 {#:день|дня|дней}."), "Прошло 11 дней.", "11")
	_same(RussianText.finish("Прошло 22 {#:день|дня|дней}."), "Прошло 22 дня.", "22")
	_same(RussianText.finish("Прошло 105 {#:день|дня|дней}."), "Прошло 105 дней.", "105")
	_same(RussianText.finish("У вас 1 кожаный бурдюк{:ч}."), "У вас 1 кожаный бурдюк.", "a counted noun: 1")
	_same(RussianText.finish("У вас 2 кожаный бурдюк{:ч}."), "У вас 2 кожаных бурдюка.", "2")
	_same(RussianText.finish("У вас 25 кожаный бурдюк{:ч}."), "У вас 25 кожаных бурдюков.", "25")
	_check(RussianNouns.plural_index(0) == 2 and RussianNouns.plural_index(21) == 0 and RussianNouns.plural_index(114) == 2, "plural_index")


func _test_unfilled() -> void:
	var template: String = "{npc}{:и} {~:ударил|ударила} вас и {count} {#:раз|раза|раз}. $n{:в} %s{:д}"
	_same(RussianText.finish(template), template, "a template keeps every mark after a slot")
	var filled: String = template.replace("{npc}", "Бродячая собака").replace("{count}", "2").replace("$n", "бандит").replace("%s", "слуга")
	_same(RussianText.finish(filled), "Бродячая собака ударила вас и 2 раза. бандита слуге", "and the filled line resolves them")


func _test_message_grammar() -> void:
	var line: String = "$N {N:бьёте|бьёт} $n{:в}, и $n {n:отскочили|отскочил|отскочила|отскочило}."
	_same(MessageGrammar.resolve(line, MessageGrammar.you(), MessageGrammar.other(CharacterState.GENDER_FEMALE)),
		"$N бьёте $n{:в}, и $n отскочила.", "two forms by the player, four by gender")
	_same(MessageGrammar.resolve(line, MessageGrammar.other(), MessageGrammar.you()),
		"$N бьёт $n{:в}, и $n отскочили.", "the player as $n")
	_same(MessageGrammar.resolve("$N {N:упали|упал|упала}.", MessageGrammar.Role.new(false, CharacterState.GENDER_MALE, "бродячая собака")),
		"$N упала.", "the Russian name's gender over the character's")
	_same(MessageGrammar.resolve("$N {N:упали|упал|упала}.", MessageGrammar.other(&"雌性")), "$N упала.", "a female beast with no name")
	_same(MessageGrammar.resolve("$N {N:упали|упал|упала}.", MessageGrammar.other(&"中性神")), "$N упал.", "three forms: no ср, м")


func _test_shown() -> void:
	var before: String = TranslationServer.get_locale()
	var russian := Translation.new()
	russian.locale = "ru"
	TranslationServer.add_translation(russian)
	TranslationServer.set_locale("ru")
	_same(MessageGrammar.fill("$N {N:бьёте|бьёт} $n{:в}.", MessageGrammar.you(), "вы", MessageGrammar.other(), "бандит"),
		"Вы бьёте бандита.", "a filled line: the case, then the capital")
	_same(MessageGrammar.fill("$N {N:бьёте|бьёт} $n{:в}.", MessageGrammar.other(), "бандит", MessageGrammar.you(), "вы"),
		"Бандит бьёт вас.", "Cyrillic capitalised")
	_same(MessageGrammar.fill("$N {N:упали|упал|упала}.", MessageGrammar.other(CharacterState.GENDER_MALE), "бродячая собака"),
		"Бродячая собака упала.", "fill() gives the role its name")
	_same(ShownText.of("Вы бьёте бандит{:в}."), "Вы бьёте бандита.", "ShownText in Russian")
	var wrapped := FinishedTranslation.new(_inner())
	_same(String(wrapped.get_message("{npc}走了。")), "{npc}{:и} {~:ушёл|ушла}.", "a template keeps its marks")
	_same(String(wrapped.get_message("Бандит{:и} {~:ушёл|ушла}.")), "Бандит ушёл.", "a filled line a control translates")
	TranslationServer.set_locale("zh_CN")
	_same(ShownText.of("бандит{:в}"), "бандит{:в}", "left alone outside Russian")
	TranslationServer.remove_translation(russian)
	TranslationServer.set_locale(before)


func _inner() -> Translation:
	var inner := Translation.new()
	inner.locale = "ru"
	inner.add_message("{npc}走了。", "{npc}{:и} {~:ушёл|ушла}.")
	return inner


## The shipped table is well formed: eight fields, a known gender, every name in its own row.
func _test_shipped_rows() -> void:
	if not FileAccess.file_exists(RussianNouns.PATH):
		return
	var rows: Variant = JSON.parse_string(FileAccess.get_file_as_string(RussianNouns.PATH))
	_check(rows is Dictionary, "ru_nouns.json is an object")
	if not rows is Dictionary:
		return
	var bad: Array[String] = []
	for name: String in rows:
		var row: Variant = rows[name]
		if not row is Array or (row as Array).size() != 8 or not RussianNouns.GENDERS.has(String(row[0])):
			bad.append(name)
	_check(bad.is_empty(), "every row: a gender and seven forms (%s)" % ", ".join(bad.slice(0, 5)))


func _same(got: String, want: String, label: String) -> void:
	_count += 1
	if got != want:
		_failures.append("%s: got %s, want %s" % [label, got, want])


func _check(ok: bool, label: String) -> void:
	_count += 1
	if not ok:
		_failures.append(label)
