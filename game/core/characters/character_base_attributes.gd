class_name CharacterBaseAttributes
extends RefCounted

## Typed replacement for the legacy base fields str/cor/int/spi/cps/per/con/kar.
## Effective-value formulas are translated from:
## reference/es2/mudlib/feature/attribute.c

var strength: int
var courage: int
var intelligence: int
var spirituality: int
var composure: int
var personality: int
var constitution: int
var karma: int

## Legacy persistent adjustments used by feature/attribute.c.
var force_factor: int = 0
var bellicosity: int = 0

## Typed equivalents of query_temp("apply/<attribute>"). Producers of these
## modifiers (equipment, conditions, and so on) are deliberately out of scope.
var strength_modifier: int = 0
var courage_modifier: int = 0
var intelligence_modifier: int = 0
var spirituality_modifier: int = 0
var composure_modifier: int = 0
var personality_modifier: int = 0
var constitution_modifier: int = 0
var karma_modifier: int = 0


func _init(
	p_strength: int = 0,
	p_courage: int = 0,
	p_intelligence: int = 0,
	p_spirituality: int = 0,
	p_composure: int = 0,
	p_personality: int = 0,
	p_constitution: int = 0,
	p_karma: int = 0,
) -> void:
	strength = p_strength
	courage = p_courage
	intelligence = p_intelligence
	spirituality = p_spirituality
	composure = p_composure
	personality = p_personality
	constitution = p_constitution
	karma = p_karma


func effective_strength() -> int:
	return strength + force_factor + strength_modifier


func effective_courage() -> int:
	return courage + _legacy_int_divide(bellicosity, 50) + courage_modifier


func effective_intelligence() -> int:
	return intelligence + intelligence_modifier


func effective_spirituality() -> int:
	return spirituality + spirituality_modifier


func effective_composure() -> int:
	return composure + _legacy_int_divide(force_factor, 2) + composure_modifier


func effective_personality() -> int:
	return personality + personality_modifier


func effective_constitution() -> int:
	return constitution + constitution_modifier


func effective_karma() -> int:
	return karma + karma_modifier


static func _legacy_int_divide(dividend: int, divisor: int) -> int:
	@warning_ignore("integer_division")
	return dividend / divisor
