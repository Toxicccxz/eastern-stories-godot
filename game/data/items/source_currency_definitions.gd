class_name SourceCurrencyDefinitions
extends RefCounted

## Explicit canonical content, not a mutable registry or runtime alias resolver.
static func source(denomination: CurrencyDenomination.Value) -> GDScript:
	match denomination:
		CurrencyDenomination.Value.COIN: return SourceCoin
		CurrencyDenomination.Value.SILVER: return SourceSilver
		CurrencyDenomination.Value.GOLD: return SourceGold
	return null


static func identify(id: StringName) -> CurrencyDenomination.Value:
	for denomination: CurrencyDenomination.Value in [CurrencyDenomination.Value.COIN, CurrencyDenomination.Value.SILVER, CurrencyDenomination.Value.GOLD]:
		if source(denomination).DEFINITION_ID == id:
			return denomination
	return CurrencyDenomination.Value.UNSUPPORTED
