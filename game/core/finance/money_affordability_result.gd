class_name MoneyAffordabilityResult
extends RefCounted

## First three numeric values retain the LPC 0/1/2 meanings.
enum Outcome { INSUFFICIENT_TOTAL, AFFORDABLE, DENOMINATION_REJECTED, INVALID_PRICE, AUTHORITY_FAILURE, ARITHMETIC_FAILURE }
var outcome: Outcome = Outcome.AUTHORITY_FAILURE
var gold_id: StringName = &""
var silver_id: StringName = &""
var coin_id: StringName = &""
