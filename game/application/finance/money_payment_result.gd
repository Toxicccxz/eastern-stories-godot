class_name MoneyPaymentResult
extends RefCounted

enum Outcome { SUCCESS, INSUFFICIENT_TOTAL, CANNOT_COMPLETE, INVALID_PRICE, ARITHMETIC_FAILURE, AUTHORITY_FAILURE }
enum Stage { VALIDATION, TOTAL, GOLD, SILVER, COIN, FINAL }
var outcome: Outcome = Outcome.AUTHORITY_FAILURE
var stage: Stage = Stage.VALIDATION
var remaining_price: int = 0
var selected_ids: Array[StringName] = []
var mutations: Array[MoneyMutationResult] = []


func succeeded() -> bool:
	return outcome == Outcome.SUCCESS
