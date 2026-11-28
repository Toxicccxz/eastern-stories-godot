class_name SpanishText
extends RefCounted

## Spanish as the game shows it (docs/production/spanish_style.md): RomanceText with Spanish's
## marks. {npc}{:el} the definite article (a el → al, de el → del), {:un} the indefinite, {:los}
## {:unos} the plural, {:0} none, {count} {item}{:pl} counted; {~:herido|herida} (three forms
## tú | m | f), %d {#:día|días}, {jugador:cansado|cansada}; tú as a subject opening a sentence is
## left out («$N{:el} {N:golpeas|golpea}» → «Golpeas»).

const LANGUAGE: String = "es"
const DEFINITE: String = "el"
const INDEFINITE: String = "un"
const BARE: String = "0"
const COUNTED: String = "pl"
const DEFINITE_PLURAL: String = "los"
const INDEFINITE_PLURAL: String = "unos"
const MARKS: PackedStringArray = [DEFINITE, INDEFINITE, DEFINITE_PLURAL, INDEFINITE_PLURAL, BARE, COUNTED]
const PLAYER_MARK: String = "jugador"
const YOU_FORM: String = SpanishNouns.YOU

## The player's gender (CharacterState's value): set by the world session once it has its player.
static var player_gender: StringName = &""
static var _text: RomanceText


static func text() -> RomanceText:
	if _text == null:
		_text = RomanceText.new(LANGUAGE, MARKS, PLAYER_MARK, true, {"a el": "al", "de el": "del"}, SpanishNouns.table(), func() -> StringName: return SpanishText.player_gender)
	return _text


## `text` with every mark it can resolve resolved; unchanged when it has none.
static func finish(line: String) -> String:
	return text().finish(line)
