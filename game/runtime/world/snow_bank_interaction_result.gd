class_name SnowBankInteractionResult
extends RefCounted

## Runtime availability/input outcome, separate from the unchanged S3B rule result.
enum Outcome { BLOCKED, INVALID_INPUT, CONVERSION }
var outcome: Outcome = Outcome.BLOCKED
var conversion: BankConversionResult


func succeeded() -> bool:
	return outcome == Outcome.CONVERSION and conversion != null and conversion.succeeded()
