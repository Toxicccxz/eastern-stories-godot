class_name PortugueseText
extends RefCounted

## Brazilian Portuguese as the game shows it (docs/production/portuguese_style.md): RomanceText
## with Portuguese's marks. {npc}{:o} the definite article, contracted with the preposition before
## it (a o → ao, a a → à, de o → do, em a → na, por o → pelo…), {:um} the indefinite, {:os} {:uns}
## the plural, {:0} none, {count} {item}{:pl} counted; {~:ferido|ferida} (three forms você | m | f),
## %d {#:dia|dias}, {jogador:cansado|cansada}. The player is você, kept as a subject: its verb is
## the third person's, so a template needs no form for it.

const LANGUAGE: String = "pt"
const DEFINITE: String = "o"
const INDEFINITE: String = "um"
const BARE: String = "0"
const COUNTED: String = "pl"
const DEFINITE_PLURAL: String = "os"
const INDEFINITE_PLURAL: String = "uns"
const MARKS: PackedStringArray = [DEFINITE, INDEFINITE, DEFINITE_PLURAL, INDEFINITE_PLURAL, BARE, COUNTED]
const PLAYER_MARK: String = "jogador"
const YOU_FORM: String = PortugueseNouns.YOU
## A preposition and the definite article written as one word.
const CONTRACTIONS: Dictionary = {
	"a o": "ao", "a a": "à", "a os": "aos", "a as": "às",
	"de o": "do", "de a": "da", "de os": "dos", "de as": "das",
	"em o": "no", "em a": "na", "em os": "nos", "em as": "nas",
	"por o": "pelo", "por a": "pela", "por os": "pelos", "por as": "pelas",
}

## The player's gender (CharacterState's value): set by the world session once it has its player.
static var player_gender: StringName = &""
static var _text: RomanceText


static func text() -> RomanceText:
	if _text == null:
		_text = RomanceText.new(LANGUAGE, MARKS, PLAYER_MARK, false, CONTRACTIONS, PortugueseNouns.table(), func() -> StringName: return PortugueseText.player_gender)
	return _text


## `text` with every mark it can resolve resolved; unchanged when it has none.
static func finish(line: String) -> String:
	return text().finish(line)
