class_name CurrencyArithmetic
extends RefCounted

const MAXIMUM: int = 9223372036854775807

## Nonnegative canonical-money arithmetic. -1 is internal checked failure,
## converted to explicit typed outcomes by each operation at its reached stage.
static func add(a: int, b: int) -> int:
	if a < 0 or b < 0 or a > MAXIMUM - b:
		return -1
	return a + b


@warning_ignore("integer_division")
static func multiply(a: int, b: int) -> int:
	if a < 0 or b < 0 or (b > 0 and a > MAXIMUM / b):
		return -1
	return a * b
