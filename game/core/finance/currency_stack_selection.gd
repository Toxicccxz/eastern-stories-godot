class_name CurrencyStackSelection
extends RefCounted

enum Outcome { ABSENT, FOUND, AUTHORITY_FAILURE }
var outcome: Outcome = Outcome.ABSENT
var item_id: StringName = &""
var amount: int = 0
