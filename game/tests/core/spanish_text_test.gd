extends RefCounted

## SpanishText and SpanishNouns: a filled name given the article its mark asks for (a + el and
## de + el contracted, el hacha, a proper name with none, tú left out as a subject), words agreeing
## with that name's gender or a number or the player's gender, marks after a slot not filled yet
## kept for the filled line; MessageGrammar's Spanish forms (two, three, four) and the article
## marks inside them; capitals for accented letters and after ¿ ¡.

const ROWS: Dictionary = {
	"bandido": ["m", "bandidos"],
	"mozo de la posada": ["m", "mozos de la posada"],
	"espada vieja": ["f", "espadas viejas"],
	"hacha": ["f", "hachas", "el"],
	"perro salvaje": ["m", "perros salvajes"],
	"serpiente": ["f", "serpientes"],
	"tijeras": ["fp", "tijeras"],
	"Liu Chunfeng": ["m"],
	"Lan Zhiping": ["f"],
	"Paso del Camello": ["m", "", "el"],
	"Capital": ["f", "", "la"],
}

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	SpanishNouns.use(ROWS)
	_test_articles()
	_test_agreement()
	_test_player()
	_test_numbers()
	_test_unfilled()
	_test_message_grammar()
	_test_shown()
	SpanishNouns.reset()
	_test_shipped_rows()
	await tree.process_frame
	return {"assertions": _count, "failures": _failures.duplicate()}


func _test_articles() -> void:
	_same(SpanishText.finish("Hablas con mozo de la posada{:el}."), "Hablas con el mozo de la posada.", "the definite article")
	_same(SpanishText.finish("Hablas con Mozo de la posada{:el}."), "Hablas con el mozo de la posada.", "a common noun shown with its capital goes lower case")
	_same(SpanishText.finish("Ves espada vieja{:un}."), "Ves una espada vieja.", "the indefinite article")
	_same(SpanishText.finish("Empuñas hacha{:el}."), "Empuñas el hacha.", "el hacha")
	_same(SpanishText.finish("Ves hacha{:un}."), "Ves un hacha.", "un hacha")
	_same(SpanishText.finish("Te acercas a bandido{:el}."), "Te acercas al bandido.", "a + el → al")
	_same(SpanishText.finish("La bolsa de bandido{:el} pesa."), "La bolsa del bandido pesa.", "de + el → del")
	_same(SpanishText.finish("Te acercas a espada vieja{:el}."), "Te acercas a la espada vieja.", "a + la stays")
	_same(SpanishText.finish("Saludas a Liu Chunfeng{:el}."), "Saludas a Liu Chunfeng.", "a proper name takes no article")
	_same(SpanishText.finish("Llegas a Paso del Camello{:el}."), "Llegas al Paso del Camello.", "a place that takes el, contracted")
	_same(SpanishText.finish("Vuelves a Capital{:el}."), "Vuelves a la Capital.", "la Capital")
	_same(SpanishText.finish("Bandido{:el} gruñe."), "El bandido gruñe.", "a sentence opened")
	_same(SpanishText.finish("A bandido{:el} le duele."), "Al bandido le duele.", "Al opening a sentence")
	_same(SpanishText.finish("Dice: \"bandido{:el} se fue\"."), "Dice: \"El bandido se fue\".", "a quotation after a colon opens a sentence")
	_same(SpanishText.finish("¿Ves bandido{:0}?"), "¿Ves bandido?", "no article, lower case")
	_same(SpanishText.finish("Golpeas a [color=red]bandido[/color]{:el}."), "Golpeas [color=red]al bandido[/color].", "past a BBCode tag, contracted")
	_same(SpanishText.finish("Ves espantapájaros{:el}."), "Ves espantapájaros.", "a name with no row stays")
	_same(SpanishText.finish("Sin marcas."), "Sin marcas.", "no marks")
	_same(SpanishText.finish("Tú{:el} golpeas a bandido{:el}."), "golpeas al bandido.", "tú as a subject is left out (MessageGrammar capitalises)")
	_same(SpanishText.finish("Ves tijeras{:el}."), "Ves las tijeras.", "a plural noun")
	_same(SpanishText.finish("Afilas espada vieja{:los}, {~:limpio|limpia|limpios|limpias}."), "Afilas las espadas viejas, limpias.", "{:los}: the plural and its article")
	_same(SpanishText.finish("Llegan mozo de la posada{:unos}."), "Llegan unos mozos de la posada.", "{:unos}")
	_same(SpanishText.finish("Ves hacha{:los}."), "Ves las hachas.", "las hachas")


func _test_agreement() -> void:
	_same(SpanishText.finish("Bandido{:el} cae {~:herido|herida}."), "El bandido cae herido.", "m")
	_same(SpanishText.finish("Serpiente{:el} cae {~:herido|herida}."), "La serpiente cae herida.", "f by the word")
	_same(SpanishText.finish("Lan Zhiping{:el} está {~:cansado|cansada}."), "Lan Zhiping está cansada.", "f by the person")
	_same(SpanishText.finish("Tijeras{:el} {~:quedó rota|quedó rota|quedaron rotos|quedaron rotas}."), "Las tijeras quedaron rotas.", "four forms: fp")
	_same(SpanishText.finish("{~:Callado|Callada}, Lan Zhiping{:el} asiente."), "Callada, Lan Zhiping asiente.", "a name after the word")
	_same(SpanishText.finish("Espantapájaros{:el} cae {~:herido|herida}."), "Espantapájaros cae herido.", "a name with no row: m")


func _test_player() -> void:
	var before: StringName = SpanishText.player_gender
	SpanishText.player_gender = CharacterState.GENDER_FEMALE
	_same(SpanishText.finish("Estás {jugador:cansado|cansada}, {npc}{:el}."), "Estás cansada, {npc}{:el}.", "the player's gender, in a template too")
	SpanishText.player_gender = CharacterState.GENDER_MALE
	_same(SpanishText.finish("Estás {jugador:cansado|cansada}; bandido{:el} está {~:herido|herida}."), "Estás cansado; el bandido está herido.", "a man; other marks still resolve")
	SpanishText.player_gender = &""
	_same(SpanishText.finish("{jugador:Listo|Lista}."), "Listo.", "no player yet: the first form")
	SpanishText.player_gender = before


func _test_numbers() -> void:
	_same(SpanishText.finish("Pasa 1 {#:día|días}."), "Pasa 1 día.", "1")
	_same(SpanishText.finish("Pasan 3 {#:día|días}."), "Pasan 3 días.", "3")
	_same(SpanishText.finish("Pasan 0 {#:día|días}."), "Pasan 0 días.", "0")
	_same(SpanishText.finish("Tienes 1 espada vieja{:pl}."), "Tienes 1 espada vieja.", "a counted noun: 1")
	_same(SpanishText.finish("Tienes 3 espada vieja{:pl}."), "Tienes 3 espadas viejas.", "3")
	_same(SpanishText.finish("Tienes 3 espada vieja{:pl}, {~:afilado|afilada|afilados|afiladas}."), "Tienes 3 espadas viejas, afiladas.", "a counted noun agrees in the plural")


func _test_unfilled() -> void:
	var template: String = "{npc}{:el} te mira {count} {#:vez|veces}, {~:serio|seria}. $n{:el} %s{:un}"
	_same(SpanishText.finish(template), template, "a template keeps every mark after a slot")
	var filled: String = template.replace("{npc}", "Serpiente").replace("{count}", "2").replace("$n", "bandido").replace("%s", "hacha")
	_same(SpanishText.finish(filled), "La serpiente te mira 2 veces, seria. El bandido un hacha", "and the filled line resolves them")


func _test_message_grammar() -> void:
	var before: String = TranslationServer.get_locale()
	var spanish := Translation.new()
	spanish.locale = "es"
	TranslationServer.add_translation(spanish)
	TranslationServer.set_locale("es_419")
	var line: String = "$N{:el} {n:te golpea|golpea a $n{:el}} y {n:te|lo|la} {N:miras|mira}."
	_same(MessageGrammar.resolve(line, MessageGrammar.other(), MessageGrammar.you()),
		"$N{:el} te golpea y te mira.", "the player as $n: the clitic form")
	_same(MessageGrammar.resolve(line, MessageGrammar.you(), MessageGrammar.other(CharacterState.GENDER_FEMALE)),
		"$N{:el} golpea a $n{:el} y la miras.", "a form holds an article mark; three forms tú | m | f")
	_same(MessageGrammar.resolve("$N {N:caes rendido|caes rendida|cae rendido|cae rendida}.", MessageGrammar.Role.new(false, CharacterState.GENDER_MALE, "serpiente")),
		"$N cae rendida.", "four forms: the Spanish word's gender over the character's")
	var player_before: StringName = SpanishText.player_gender
	SpanishText.player_gender = CharacterState.GENDER_FEMALE
	_same(MessageGrammar.resolve("$N {N:caes rendido|caes rendida|cae rendido|cae rendida}.", MessageGrammar.you()), "$N caes rendida.", "four forms: the player's gender")
	SpanishText.player_gender = player_before
	_same(MessageGrammar.fill("$N{:el} {N:golpeas|golpea} a $n{:el}.", MessageGrammar.you(), "tú", MessageGrammar.other(), "Bandido"),
		"Golpeas al bandido.", "tú left out, the article contracted, the capital")
	_same(MessageGrammar.fill("$N{:el} {n:te golpea|golpea a $n{:el}}.", MessageGrammar.other(), "Bandido", MessageGrammar.you(), "tú"),
		"El bandido te golpea.", "a common noun as $N")
	_same(MessageGrammar.fill("¿$N{:el} {N:estás|está} bien?", MessageGrammar.other(), "Liu Chunfeng"), "¿Liu Chunfeng está bien?", "past ¿")
	_same(MessageGrammar.capitalize("él se va. ésa es."), "Él se va. Ésa es.", "an accented capital")
	TranslationServer.set_locale("zh_CN")
	TranslationServer.remove_translation(spanish)
	TranslationServer.set_locale(before)


func _test_shown() -> void:
	var before: String = TranslationServer.get_locale()
	var spanish := Translation.new()
	spanish.locale = "es"
	TranslationServer.add_translation(spanish)
	TranslationServer.set_locale("es_419")
	_check(ShownText.finishes("es"), "Spanish finishes its lines")
	_same(ShownText.of("Hablas con mozo de la posada{:el}."), "Hablas con el mozo de la posada.", "ShownText in Spanish")
	var wrapped := FinishedTranslation.new(_inner())
	_same(String(wrapped.get_message("{npc}走了。")), "{npc}{:el} se fue.", "a template keeps its marks")
	_same(String(wrapped.get_message("Bandido{:el} se fue.")), "El bandido se fue.", "a filled line a control translates")
	TranslationServer.set_locale("zh_CN")
	_same(ShownText.of("bandido{:el}"), "bandido{:el}", "left alone outside Spanish")
	TranslationServer.remove_translation(spanish)
	TranslationServer.set_locale(before)


func _inner() -> Translation:
	var inner := Translation.new()
	inner.locale = "es"
	inner.add_message("{npc}走了。", "{npc}{:el} se fue.")
	return inner


## The shipped table is well formed: a known gender, a plural, an article from el / la / los / las.
func _test_shipped_rows() -> void:
	if not FileAccess.file_exists(SpanishNouns.PATH):
		return
	var rows: Variant = JSON.parse_string(FileAccess.get_file_as_string(SpanishNouns.PATH))
	_check(rows is Dictionary, "es_nouns.json is an object")
	if not rows is Dictionary:
		return
	var bad: Array[String] = []
	for name: String in rows:
		var row: Variant = rows[name]
		if not row is Array or (row as Array).is_empty() or (row as Array).size() > 3 or not SpanishNouns.GENDERS.has(String(row[0])):
			bad.append(name)
		elif (row as Array).size() == 3 and not ["", "el", "la", "los", "las"].has(String(row[2])):
			bad.append(name)
	_check(bad.is_empty(), "every row: a gender, a plural, an article (%s)" % ", ".join(bad.slice(0, 5)))


func _same(got: String, want: String, label: String) -> void:
	_count += 1
	if got != want:
		_failures.append("%s: got %s, want %s" % [label, got, want])


func _check(ok: bool, label: String) -> void:
	_count += 1
	if not ok:
		_failures.append(label)
