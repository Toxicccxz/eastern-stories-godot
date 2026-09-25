class_name NewPlayerNamePolicy
extends RefCounted

## Owner-approved Native display-name syntax, not account identity/moderation.
## String.length()/iteration count Unicode code points. Never normalize input.
enum Reason {
	VALID, INVALID_RULES, EMPTY, TOO_SHORT, TOO_LONG, INVALID_CHARACTER,
	LEADING_SEPARATOR, TRAILING_SEPARATOR, CONSECUTIVE_SEPARATOR, RESERVED_NAME,
}

class Rules extends RefCounted:
	var minimum_length: int = 1
	var maximum_length: int = 24
	var allow_digits: bool = false # Unicode decimal digits (Nd), not all numbers.
	var allowed_separators: String = " -'’·"
	var reserved_names: Array[String] = [] # Exact, case-sensitive, no normalization.

class ValidationResult extends RefCounted:
	var _reason: Reason
	var reason: Reason:
		get: return _reason
	var succeeded: bool:
		get: return _reason == Reason.VALID

	func _init(p_reason: Reason) -> void:
		_reason = p_reason


static func default_rules() -> Rules:
	return Rules.new()


static func is_valid(value: String, rules: Rules = null) -> bool:
	return validate(value, rules).succeeded


static func validate(value: String, rules: Rules = null) -> ValidationResult:
	var effective: Rules = default_rules() if rules == null else rules
	if effective.minimum_length < 1 or effective.maximum_length < effective.minimum_length:
		return ValidationResult.new(Reason.INVALID_RULES)
	# Explicitly configured separators may be punctuation or ASCII space only.
	# They cannot reclassify a letter, mark, digit, control or arbitrary whitespace.
	var separator_pattern := RegEx.create_from_string("\\A(?:\\p{P}| )\\z")
	for separator: String in effective.allowed_separators:
		if separator_pattern.search(separator) == null:
			return ValidationResult.new(Reason.INVALID_RULES)
	if value.is_empty():
		return ValidationResult.new(Reason.EMPTY)
	if value.length() < effective.minimum_length:
		return ValidationResult.new(Reason.TOO_SHORT)
	if value.length() > effective.maximum_length:
		return ValidationResult.new(Reason.TOO_LONG)
	var character_pattern := RegEx.create_from_string("\\A(?:(\\p{L})|(\\p{M})|(\\p{Nd}))\\z")
	# Some invisible/emoji characters are letters or marks (e.g. Hangul fillers,
	# variation selectors and U+2139). Category checks alone are insufficient.
	var excluded_pattern := RegEx.create_from_string("[\\p{Default_Ignorable_Code_Point}\\p{Extended_Pictographic}]")
	var letter_sequence: bool = false
	var previous_separator: bool = false
	for index: int in value.length():
		var character: String = value[index]
		if excluded_pattern.search(character) != null:
			return ValidationResult.new(Reason.INVALID_CHARACTER)
		if effective.allowed_separators.contains(character):
			if index == 0:
				return ValidationResult.new(Reason.LEADING_SEPARATOR)
			if previous_separator:
				return ValidationResult.new(Reason.CONSECUTIVE_SEPARATOR)
			if index == value.length() - 1:
				return ValidationResult.new(Reason.TRAILING_SEPARATOR)
			previous_separator = true
			letter_sequence = false
			continue
		var matched: RegExMatch = character_pattern.search(character)
		if matched == null:
			return ValidationResult.new(Reason.INVALID_CHARACTER)
		if not matched.get_string(1).is_empty():
			letter_sequence = true
		elif not matched.get_string(2).is_empty():
			if not letter_sequence:
				return ValidationResult.new(Reason.INVALID_CHARACTER)
		else:
			if not effective.allow_digits:
				return ValidationResult.new(Reason.INVALID_CHARACTER)
			letter_sequence = false
		previous_separator = false
	if effective.reserved_names.has(value):
		return ValidationResult.new(Reason.RESERVED_NAME)
	return ValidationResult.new(Reason.VALID)
