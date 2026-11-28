extends RefCounted

## PortugueseText and PortugueseNouns (RomanceText with Brazilian Portuguese's marks): a filled name
## given the article its mark asks for and contracted with the preposition before it (ao, à, do,
## da, no, na, pelo, pela and their plurals), a proper name with none, você kept as a subject;
## words agreeing with that name's gender or a number or the player's gender; marks after a slot
## not filled yet kept for the filled line; MessageGrammar's Portuguese forms and the article marks
## inside them.

const ROWS: Dictionary = {
	"bandido": ["m", "bandidos"],
	"garçom da estalagem": ["m", "garçons da estalagem"],
	"espada velha": ["f", "espadas velhas"],
	"cão selvagem": ["m", "cães selvagens"],
	"serpente": ["f", "serpentes"],
	"tesouras": ["fp", "tesouras"],
	"Liu Chunfeng": ["m"],
	"Lan Zhiping": ["f"],
	"Passo do Camelo": ["m", "", "o"],
	"Capital": ["f", "", "a"],
}

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	PortugueseNouns.use(ROWS)
	_test_articles()
	_test_contractions()
	_test_agreement()
	_test_player()
	_test_numbers()
	_test_unfilled()
	_test_message_grammar()
	_test_shown()
	PortugueseNouns.reset()
	_test_spanish_unchanged()
	_test_shipped_rows()
	await tree.process_frame
	return {"assertions": _count, "failures": _failures.duplicate()}


func _test_articles() -> void:
	_same(PortugueseText.finish("Você fala com garçom da estalagem{:o}."), "Você fala com o garçom da estalagem.", "the definite article")
	_same(PortugueseText.finish("Você fala com Garçom da estalagem{:o}."), "Você fala com o garçom da estalagem.", "a common noun shown with its capital goes lower case")
	_same(PortugueseText.finish("Você vê espada velha{:um}."), "Você vê uma espada velha.", "the indefinite article")
	_same(PortugueseText.finish("Você cumprimenta Liu Chunfeng{:o}."), "Você cumprimenta Liu Chunfeng.", "a proper name takes no article")
	_same(PortugueseText.finish("Bandido{:o} rosna."), "O bandido rosna.", "a sentence opened")
	_same(PortugueseText.finish("Diz: \"bandido{:o} fugiu\"."), "Diz: \"O bandido fugiu\".", "a quotation after a colon opens a sentence")
	_same(PortugueseText.finish("Você vê bandido{:0}?"), "Você vê bandido?", "no article, lower case")
	_same(PortugueseText.finish("Você vê espantalho{:o}."), "Você vê espantalho.", "a name with no row stays")
	_same(PortugueseText.finish("Sem marcas."), "Sem marcas.", "no marks")
	_same(PortugueseText.finish("Você{:o} golpeia bandido{:o}."), "Você golpeia o bandido.", "você stays as a subject")
	_same(PortugueseText.finish("Você vê tesouras{:o}."), "Você vê as tesouras.", "a plural noun")
	_same(PortugueseText.finish("Você afia espada velha{:os}, {~:limpo|limpa|limpos|limpas}."), "Você afia as espadas velhas, limpas.", "{:os}: the plural and its article")
	_same(PortugueseText.finish("Chegam garçom da estalagem{:uns}."), "Chegam uns garçons da estalagem.", "{:uns}")
	_same(PortugueseText.finish("Você volta para Capital{:o}."), "Você volta para a Capital.", "a place whose row gives the article")


func _test_contractions() -> void:
	_same(PortugueseText.finish("Você se aproxima de bandido{:o}."), "Você se aproxima do bandido.", "de + o → do")
	_same(PortugueseText.finish("A bolsa de espada velha{:o}."), "A bolsa da espada velha.", "de + a → da")
	_same(PortugueseText.finish("Você entrega a carta a bandido{:o}."), "Você entrega a carta ao bandido.", "a + o → ao")
	_same(PortugueseText.finish("Você se dirige a Capital{:o}."), "Você se dirige à Capital.", "a + a → à")
	_same(PortugueseText.finish("Você chega a Passo do Camelo{:o}."), "Você chega ao Passo do Camelo.", "a place that takes o, contracted")
	_same(PortugueseText.finish("Você entra em Capital{:o}."), "Você entra na Capital.", "em + a → na")
	_same(PortugueseText.finish("Você pensa em bandido{:os}."), "Você pensa nos bandidos.", "em + os → nos")
	_same(PortugueseText.finish("Você passa por espada velha{:os}."), "Você passa pelas espadas velhas.", "por + as → pelas")
	_same(PortugueseText.finish("Você passa por cão selvagem{:o}."), "Você passa pelo cão selvagem.", "por + o → pelo")
	_same(PortugueseText.finish("A bandido{:o} dói o braço."), "Ao bandido dói o braço.", "Ao opening a sentence")
	_same(PortugueseText.finish("De bandido{:o}, nada."), "Do bandido, nada.", "Do opening a sentence")
	_same(PortugueseText.finish("A Capital{:o} chegam todos."), "À Capital chegam todos.", "À opening a sentence")
	_same(PortugueseText.finish("Você golpeia de [color=red]bandido[/color]{:o}."), "Você golpeia [color=red]do bandido[/color].", "past a BBCode tag, contracted")
	_same(PortugueseText.finish("Você fala de Liu Chunfeng{:o}."), "Você fala de Liu Chunfeng.", "de before a proper name stays")
	_same(PortugueseText.finish("Você vem de um lugar e vê bandido{:um}."), "Você vem de um lugar e vê um bandido.", "the indefinite does not contract")
	_same(PortugueseText.finish("Você olha para bandido{:o}."), "Você olha para o bandido.", "para + o stays")
	_same(PortugueseText.finish("Você fala de \"bandido{:o}\"."), "Você fala de \"o bandido\".", "a quoted name: no contraction across the quote")


func _test_agreement() -> void:
	_same(PortugueseText.finish("Bandido{:o} cai {~:ferido|ferida}."), "O bandido cai ferido.", "m")
	_same(PortugueseText.finish("Serpente{:o} cai {~:ferido|ferida}."), "A serpente cai ferida.", "f by the word")
	_same(PortugueseText.finish("Lan Zhiping{:o} está {~:cansado|cansada}."), "Lan Zhiping está cansada.", "f by the person")
	_same(PortugueseText.finish("Tesouras{:o} {~:ficou quebrado|ficou quebrada|ficaram quebrados|ficaram quebradas}."), "As tesouras ficaram quebradas.", "four forms: fp")
	_same(PortugueseText.finish("{~:Calado|Calada}, Lan Zhiping{:o} assente."), "Calada, Lan Zhiping assente.", "a name after the word")
	_same(PortugueseText.finish("Você{:o} {~:sente|sente|sente} frio."), "Você sente frio.", "three forms: você")
	var before: StringName = PortugueseText.player_gender
	PortugueseText.player_gender = CharacterState.GENDER_FEMALE
	_same(PortugueseText.finish("Você{:o} está {~:ferido|ferida}."), "Você está ferida.", "two forms after você: the player's gender")
	PortugueseText.player_gender = before


func _test_player() -> void:
	var before: StringName = PortugueseText.player_gender
	PortugueseText.player_gender = CharacterState.GENDER_FEMALE
	_same(PortugueseText.finish("Você está {jogador:cansado|cansada}, {npc}{:o}."), "Você está cansada, {npc}{:o}.", "the player's gender, in a template too")
	PortugueseText.player_gender = CharacterState.GENDER_MALE
	_same(PortugueseText.finish("Você está {jogador:cansado|cansada}; bandido{:o} está {~:ferido|ferida}."), "Você está cansado; o bandido está ferido.", "a man; other marks still resolve")
	PortugueseText.player_gender = &""
	_same(PortugueseText.finish("{jogador:Pronto|Pronta}."), "Pronto.", "no player yet: the first form")
	_same(PortugueseText.finish("Estás {jugador:cansado|cansada}."), "Estás {jugador:cansado|cansada}.", "the Spanish mark is not Portuguese's")
	PortugueseText.player_gender = before


func _test_numbers() -> void:
	_same(PortugueseText.finish("Passa 1 {#:dia|dias}."), "Passa 1 dia.", "1")
	_same(PortugueseText.finish("Passam 3 {#:dia|dias}."), "Passam 3 dias.", "3")
	_same(PortugueseText.finish("Você tem 1 espada velha{:pl}."), "Você tem 1 espada velha.", "a counted noun: 1")
	_same(PortugueseText.finish("Você tem 3 espada velha{:pl}."), "Você tem 3 espadas velhas.", "3")
	_same(PortugueseText.finish("Você tem 3 cão selvagem{:pl}, {~:sujo|suja|sujos|sujas}."), "Você tem 3 cães selvagens, sujos.", "a counted noun agrees in the plural")


func _test_unfilled() -> void:
	var template: String = "{npc}{:o} olha para você {count} {#:vez|vezes}, {~:sério|séria}. De $n{:o} %s{:um}"
	_same(PortugueseText.finish(template), template, "a template keeps every mark after a slot")
	var filled: String = template.replace("{npc}", "Serpente").replace("{count}", "2").replace("$n", "bandido").replace("%s", "espada velha")
	_same(PortugueseText.finish(filled), "A serpente olha para você 2 vezes, séria. Do bandido uma espada velha", "and the filled line resolves them")


func _test_message_grammar() -> void:
	var before: String = TranslationServer.get_locale()
	var portuguese := Translation.new()
	portuguese.locale = "pt_BR"
	TranslationServer.add_translation(portuguese)
	TranslationServer.set_locale("pt_BR")
	var line: String = "$N{:o} {n:te golpeia|golpeia $n{:o}} e {n:te|o|a} {N:olha|olha}."
	_same(MessageGrammar.resolve(line, MessageGrammar.other(), MessageGrammar.you()),
		"$N{:o} te golpeia e te olha.", "the player as $n: the clitic form")
	_same(MessageGrammar.resolve(line, MessageGrammar.you(), MessageGrammar.other(CharacterState.GENDER_FEMALE)),
		"$N{:o} golpeia $n{:o} e a olha.", "a form holds an article mark; three forms você | m | f")
	_same(MessageGrammar.resolve("$N {N:cai rendido|cai rendida|cai rendido|cai rendida}.", MessageGrammar.Role.new(false, CharacterState.GENDER_MALE, "serpente")),
		"$N cai rendida.", "four forms: the Portuguese word's gender over the character's")
	var player_before: StringName = PortugueseText.player_gender
	PortugueseText.player_gender = CharacterState.GENDER_FEMALE
	_same(MessageGrammar.resolve("$N {N:cai rendido|cai rendida|cai rendido|cai rendida}.", MessageGrammar.you()), "$N cai rendida.", "four forms: the player's gender")
	PortugueseText.player_gender = player_before
	_same(MessageGrammar.fill("$N{:o} golpeia $n{:o}.", MessageGrammar.you(), "você", MessageGrammar.other(), "Bandido"),
		"Você golpeia o bandido.", "você kept and capitalised")
	_same(MessageGrammar.fill("$N{:o} {n:te golpeia|golpeia $n{:o}}.", MessageGrammar.other(), "Bandido", MessageGrammar.you(), "você"),
		"O bandido te golpeia.", "a common noun as $N")
	_same(MessageGrammar.fill("O golpe de $N{:o} acerta $n{:o}.", MessageGrammar.other(), "Bandido", MessageGrammar.other(CharacterState.GENDER_FEMALE), "Serpente"),
		"O golpe do bandido acerta a serpente.", "de + o inside a filled line")
	_same(MessageGrammar.resolve("O golpe abre um corte em $l{:o}{n:| de $n{:o}}.", MessageGrammar.other(), MessageGrammar.you()),
		"O golpe abre um corte em $l{:o}.", "the player's form may be empty")
	_same(MessageGrammar.resolve("O golpe abre um corte em $l{:o}{n:| de $n{:o}}.", MessageGrammar.you(), MessageGrammar.other()),
		"O golpe abre um corte em $l{:o} de $n{:o}.", "and another's holds the name")
	_same(MessageGrammar.capitalize("ela se vai. água fria."), "Ela se vai. Água fria.", "an accented capital")
	TranslationServer.set_locale("zh_CN")
	TranslationServer.remove_translation(portuguese)
	TranslationServer.set_locale(before)


func _test_shown() -> void:
	var before: String = TranslationServer.get_locale()
	var portuguese := Translation.new()
	portuguese.locale = "pt_BR"
	TranslationServer.add_translation(portuguese)
	TranslationServer.set_locale("pt_BR")
	_check(ShownText.finishes("pt"), "Portuguese finishes its lines")
	_same(ShownText.of("Você fala com garçom da estalagem{:o}."), "Você fala com o garçom da estalagem.", "ShownText in Portuguese")
	var wrapped := FinishedTranslation.new(_inner())
	_same(String(wrapped.get_message("{npc}走了。")), "{npc}{:o} foi embora.", "a template keeps its marks")
	_same(String(wrapped.get_message("Bandido{:o} foi embora.")), "O bandido foi embora.", "a filled line a control translates")
	TranslationServer.set_locale("zh_CN")
	_same(ShownText.of("bandido{:o}"), "bandido{:o}", "left alone outside Portuguese")
	TranslationServer.remove_translation(portuguese)
	TranslationServer.set_locale(before)


func _inner() -> Translation:
	var inner := Translation.new()
	inner.locale = "pt_BR"
	inner.add_message("{npc}走了。", "{npc}{:o} foi embora.")
	return inner


## The shared layer leaves Spanish as it was: its own marks, a el → al, tú left out.
func _test_spanish_unchanged() -> void:
	SpanishNouns.use({"bandido": ["m", "bandidos"], "hacha": ["f", "hachas", "el"]})
	_same(SpanishText.finish("Tú{:el} te acercas a bandido{:el} y a hacha{:el}."), "te acercas al bandido y al hacha.", "Spanish: tú left out, a el → al")
	_same(SpanishText.finish("Você vê bandido{:o}."), "Você vê bandido{:o}.", "a Portuguese mark is not Spanish's")
	SpanishNouns.reset()


## The shipped table is well formed: a known gender, a plural, an article from o / a / os / as.
func _test_shipped_rows() -> void:
	if not FileAccess.file_exists(PortugueseNouns.PATH):
		return
	var rows: Variant = JSON.parse_string(FileAccess.get_file_as_string(PortugueseNouns.PATH))
	_check(rows is Dictionary, "pt_BR_nouns.json is an object")
	if not rows is Dictionary:
		return
	var articles: PackedStringArray = PortugueseNouns.table().row_articles()
	var bad: Array[String] = []
	for name: String in rows:
		var row: Variant = rows[name]
		if not row is Array or (row as Array).is_empty() or (row as Array).size() > 3 or not PortugueseNouns.GENDERS.has(String(row[0])):
			bad.append(name)
		elif (row as Array).size() == 3 and not articles.has(String(row[2])):
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
