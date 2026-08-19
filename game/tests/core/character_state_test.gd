extends RefCounted

const CharacterAttributesScript := preload(
	"res://core/characters/character_base_attributes.gd"
)
const CharacterDerivedValuesScript := preload(
	"res://core/characters/character_derived_values.gd"
)
const CharacterResourceScript := preload(
	"res://core/characters/character_resource_state.gd"
)
const CharacterStateScript := preload("res://core/characters/character_state.gd")

var _assertion_count: int = 0
var _failures: Array[String] = []


func run_all() -> Dictionary[String, Variant]:
	_test_default_state_invariants()
	_test_effective_attribute_formulas()
	_test_resource_construction_and_clamping()
	_test_damage_semantics()
	_test_wound_semantics()
	_test_healing_semantics()
	_test_curing_semantics()
	_test_unconscious_and_death_thresholds()
	_test_human_resource_formulas_at_boundaries()
	_test_monster_resource_formulas_at_boundaries()
	_test_weight_and_encumbrance_formulas()
	return {
		"assertions": _assertion_count,
		"failures": _failures.duplicate(),
	}


func _test_default_state_invariants() -> void:
	var state: CharacterStateScript = CharacterStateScript.new()
	var other_state: CharacterStateScript = CharacterStateScript.new()
	_assert_eq(state.attributes.strength, 0, "default strength is neutral")
	_assert_eq(state.essence.current, 0, "default essence current")
	_assert_eq(state.essence.effective, 0, "default essence effective")
	_assert_eq(state.essence.maximum, 0, "default essence maximum")
	_assert_true(state.resources_have_valid_invariants(), "default resource invariants")
	_assert_true(state.attributes != other_state.attributes, "default attributes are not shared")
	_assert_true(state.essence != other_state.essence, "default resource tracks are not shared")
	state.attributes.strength = 10
	state.essence.maximum = 10
	state.essence.effective = 10
	state.essence.current = 10
	_assert_eq(other_state.attributes.strength, 0, "attribute mutation is instance-local")
	_assert_resource(other_state.essence, 0, 0, 0, "resource mutation is instance-local")
	_assert_eq(
		state.life_threshold(),
		CharacterStateScript.LifeThreshold.ACTIVE,
		"zero is not below an LPC incapacity threshold",
	)


func _test_effective_attribute_formulas() -> void:
	var attributes: CharacterAttributesScript = CharacterAttributesScript.new(
		10, 20, 30, 40, 50, 60, 70, 80
	)
	attributes.force_factor = 4
	attributes.bellicosity = 99
	attributes.strength_modifier = 2
	attributes.courage_modifier = 3
	attributes.intelligence_modifier = 4
	attributes.spirituality_modifier = 5
	attributes.composure_modifier = 6
	attributes.personality_modifier = 7
	attributes.constitution_modifier = 8
	attributes.karma_modifier = 9

	_assert_eq(attributes.effective_strength(), 16, "str + force_factor + modifier")
	_assert_eq(attributes.effective_courage(), 24, "cor + bellicosity / 50 + modifier")
	_assert_eq(attributes.effective_intelligence(), 34, "int + modifier")
	_assert_eq(attributes.effective_spirituality(), 45, "spi + modifier")
	_assert_eq(attributes.effective_composure(), 58, "cps + force_factor / 2 + modifier")
	_assert_eq(attributes.effective_personality(), 67, "per + modifier")
	_assert_eq(attributes.effective_constitution(), 78, "con + modifier")
	_assert_eq(attributes.effective_karma(), 89, "kar + modifier")

	attributes.bellicosity = 49
	_assert_eq(attributes.effective_courage(), 23, "bellicosity below 50 adds zero")
	attributes.bellicosity = 50
	_assert_eq(attributes.effective_courage(), 24, "bellicosity 50 boundary adds one")
	attributes.bellicosity = -49
	_assert_eq(attributes.effective_courage(), 23, "negative division truncates toward zero")
	attributes.bellicosity = -50
	_assert_eq(attributes.effective_courage(), 22, "negative bellicosity 50 boundary")
	attributes.force_factor = 5
	_assert_eq(attributes.effective_composure(), 58, "odd force_factor uses integer division")


func _test_resource_construction_and_clamping() -> void:
	var resource: CharacterResourceScript = CharacterResourceScript.new(150, 120, 100)
	_assert_resource(resource, 100, 100, 100, "constructor clamps descending track")

	resource.maximum = 60
	_assert_resource(resource, 60, 60, 60, "lower maximum clamps effective and current")
	resource.effective = 20
	_assert_resource(resource, 20, 20, 60, "lower effective clamps current")
	resource.current = 100
	_assert_resource(resource, 20, 20, 60, "current cannot exceed effective")
	resource.current = -50
	_assert_resource(resource, -1, 20, 60, "current saturates at legacy -1 floor")
	_assert_true(resource.has_valid_invariants(), "clamped resource remains valid")


func _test_damage_semantics() -> void:
	var resource: CharacterResourceScript = CharacterResourceScript.new(80, 100, 100)
	_assert_eq(resource.apply_damage(30), 30, "damage returns requested amount")
	_assert_resource(resource, 50, 100, 100, "damage changes current only")
	_assert_eq(resource.apply_damage(50), 50, "exact damage reaches zero")
	_assert_resource(resource, 0, 100, 100, "zero is preserved")
	_assert_false(resource.is_unconscious_threshold_reached(), "zero is not unconscious")
	resource.apply_damage(1)
	_assert_resource(resource, -1, 100, 100, "damage below zero saturates at -1")
	resource.apply_damage(999)
	_assert_resource(resource, -1, 100, 100, "damage cannot pass -1 floor")


func _test_wound_semantics() -> void:
	var resource: CharacterResourceScript = CharacterResourceScript.new(90, 100, 100)
	_assert_eq(resource.apply_wound(25), 25, "wound returns requested amount")
	_assert_resource(resource, 75, 75, 100, "wound clamps current to effective")
	resource.apply_wound(75)
	_assert_resource(resource, 0, 0, 100, "exact wound reaches zero")
	_assert_false(resource.is_death_threshold_reached(), "zero effective is not death")
	resource.apply_wound(1)
	_assert_resource(resource, -1, -1, 100, "mortal wound saturates both at -1")
	_assert_true(resource.is_death_threshold_reached(), "negative effective reaches death")

	var lower_current: CharacterResourceScript = CharacterResourceScript.new(40, 100, 100)
	lower_current.apply_wound(25)
	_assert_resource(lower_current, 40, 75, 100, "wound does not raise a lower current value")


func _test_healing_semantics() -> void:
	var resource: CharacterResourceScript = CharacterResourceScript.new(40, 70, 100)
	_assert_eq(resource.heal(20), 20, "heal returns requested amount")
	_assert_resource(resource, 60, 70, 100, "heal restores current")
	_assert_eq(resource.heal(10), 10, "exact-cap heal returns requested amount")
	_assert_resource(resource, 70, 70, 100, "exact-cap heal reaches effective")
	_assert_eq(resource.heal(100), 100, "capped heal still returns requested amount")
	_assert_resource(resource, 70, 70, 100, "heal caps at effective")
	resource.heal(0)
	_assert_resource(resource, 70, 70, 100, "zero heal is stable")


func _test_curing_semantics() -> void:
	var resource: CharacterResourceScript = CharacterResourceScript.new(40, 70, 100)
	_assert_eq(resource.cure(20), 20, "uncapped cure returns requested amount")
	_assert_resource(resource, 40, 90, 100, "cure changes effective, not current")
	_assert_eq(resource.cure(10), 10, "exact-cap cure returns requested amount")
	_assert_resource(resource, 40, 100, 100, "cure caps at maximum")
	_assert_eq(resource.cure(10), 0, "curing a full effective track applies zero")

	var capped: CharacterResourceScript = CharacterResourceScript.new(40, 70, 100)
	_assert_eq(capped.cure(50), 30, "over-cap cure returns amount actually applied")
	_assert_resource(capped, 40, 100, 100, "over-cap cure reaches maximum")

	var incapacitated: CharacterResourceScript = CharacterResourceScript.new(-1, -1, 100)
	_assert_eq(incapacitated.heal(50), 50, "heal cannot bypass negative effective state")
	_assert_resource(incapacitated, -1, -1, 100, "wounded track needs curing first")
	_assert_eq(incapacitated.cure(1), 1, "curing can restore effective from -1")
	_assert_resource(incapacitated, -1, 0, 100, "curing does not also heal current")
	incapacitated.heal(1)
	_assert_resource(incapacitated, 0, 0, 100, "healing follows restored effective state")


func _test_unconscious_and_death_thresholds() -> void:
	var unconscious_state: CharacterStateScript = _full_character_state(100, 100, 100)
	unconscious_state.vitality.apply_damage(101)
	_assert_true(
		unconscious_state.is_unconscious_threshold_reached(),
		"one negative current track reaches unconscious threshold",
	)
	_assert_false(
		unconscious_state.is_death_threshold_reached(),
		"current damage alone does not reach death threshold",
	)
	_assert_eq(
		unconscious_state.life_threshold(),
		CharacterStateScript.LifeThreshold.UNCONSCIOUS,
		"aggregate state reports unconscious",
	)

	var dead_state: CharacterStateScript = _full_character_state(100, 100, 100)
	dead_state.spirit.apply_wound(101)
	_assert_true(dead_state.is_death_threshold_reached(), "negative effective reaches death")
	_assert_true(
		dead_state.is_unconscious_threshold_reached(),
		"mortal wound also clamps current below zero",
	)
	_assert_eq(
		dead_state.life_threshold(),
		CharacterStateScript.LifeThreshold.DEAD,
		"death check has the same precedence as std/char.c",
	)


func _test_human_resource_formulas_at_boundaries() -> void:
	_assert_eq(CharacterDerivedValuesScript.human_maximum_essence(14), 100, "human gin age 14")
	_assert_eq(CharacterDerivedValuesScript.human_maximum_essence(15), 120, "human gin age 15")
	_assert_eq(CharacterDerivedValuesScript.human_maximum_essence(20), 220, "human gin age 20")
	_assert_eq(CharacterDerivedValuesScript.human_maximum_essence(21), 220, "human gin age 21")
	_assert_eq(CharacterDerivedValuesScript.human_maximum_essence(30), 220, "human gin age 30")
	_assert_eq(CharacterDerivedValuesScript.human_maximum_essence(31), 215, "human gin age 31")
	_assert_eq(CharacterDerivedValuesScript.human_maximum_essence(60), 70, "human gin age 60")
	_assert_eq(CharacterDerivedValuesScript.human_maximum_essence(61), 70, "human gin age 61")
	_assert_eq(
		CharacterDerivedValuesScript.human_maximum_essence(14, 100),
		125,
		"max_atman quarter bonus",
	)
	_assert_eq(
		CharacterDerivedValuesScript.human_maximum_essence(14, 103),
		125,
		"atman bonus truncates",
	)
	_assert_eq(
		CharacterDerivedValuesScript.human_maximum_essence(14, -100),
		100,
		"negative atman ignored",
	)

	_assert_eq(CharacterDerivedValuesScript.human_maximum_vitality(14), 100, "human kee age 14")
	_assert_eq(CharacterDerivedValuesScript.human_maximum_vitality(15), 120, "human kee age 15")
	_assert_eq(CharacterDerivedValuesScript.human_maximum_vitality(20), 220, "human kee age 20")
	_assert_eq(CharacterDerivedValuesScript.human_maximum_vitality(21), 220, "human kee age 21")
	_assert_eq(
		CharacterDerivedValuesScript.human_maximum_vitality(20, 100),
		245,
		"max_force quarter bonus",
	)

	_assert_eq(CharacterDerivedValuesScript.human_maximum_spirit(30), 100, "human sen age 30")
	_assert_eq(CharacterDerivedValuesScript.human_maximum_spirit(31), 105, "human sen age 31")
	_assert_eq(
		CharacterDerivedValuesScript.human_maximum_spirit(30, 100),
		125,
		"max_mana quarter bonus",
	)


func _test_monster_resource_formulas_at_boundaries() -> void:
	_assert_eq(CharacterDerivedValuesScript.monster_maximum_essence(3), 50, "monster gin age 3")
	_assert_eq(CharacterDerivedValuesScript.monster_maximum_essence(4), 80, "monster gin age 4")
	_assert_eq(CharacterDerivedValuesScript.monster_maximum_essence(10), 260, "monster gin age 10")
	_assert_eq(CharacterDerivedValuesScript.monster_maximum_essence(11), 265, "monster gin age 11")
	_assert_eq(CharacterDerivedValuesScript.monster_maximum_essence(60), 510, "monster gin age 60")
	_assert_eq(CharacterDerivedValuesScript.monster_maximum_essence(61), 511, "monster gin age 61")

	_assert_eq(CharacterDerivedValuesScript.monster_maximum_vitality(10), 100, "monster kee age 10")
	_assert_eq(CharacterDerivedValuesScript.monster_maximum_vitality(11), 130, "monster kee age 11")
	_assert_eq(CharacterDerivedValuesScript.monster_maximum_vitality(30), 700, "monster kee age 30")
	_assert_eq(CharacterDerivedValuesScript.monster_maximum_vitality(31), 710, "monster kee age 31")
	_assert_eq(CharacterDerivedValuesScript.monster_maximum_spirit(30), 50, "monster sen age 30")
	_assert_eq(CharacterDerivedValuesScript.monster_maximum_spirit(31), 60, "monster sen age 31")


func _test_weight_and_encumbrance_formulas() -> void:
	_assert_eq(CharacterDerivedValuesScript.human_weight(10), 40_000, "human base weight at strength 10")
	_assert_eq(CharacterDerivedValuesScript.human_weight(30), 80_000, "human weight strength slope")
	_assert_eq(CharacterDerivedValuesScript.monster_weight(10), 10_000, "monster base weight")
	_assert_eq(CharacterDerivedValuesScript.monster_weight(30), 50_000, "monster weight strength slope")
	_assert_eq(CharacterDerivedValuesScript.maximum_encumbrance(0), 0, "zero strength encumbrance")
	_assert_eq(
		CharacterDerivedValuesScript.maximum_encumbrance(30),
		150_000,
		"encumbrance strength slope",
	)


func _full_character_state(
	maximum_essence: int,
	maximum_vitality: int,
	maximum_spirit: int,
) -> CharacterStateScript:
	return CharacterStateScript.new(
		CharacterAttributesScript.new(),
		CharacterResourceScript.new(maximum_essence, maximum_essence, maximum_essence),
		CharacterResourceScript.new(maximum_vitality, maximum_vitality, maximum_vitality),
		CharacterResourceScript.new(maximum_spirit, maximum_spirit, maximum_spirit),
	)


func _assert_resource(
	resource: CharacterResourceScript,
	expected_current: int,
	expected_effective: int,
	expected_maximum: int,
	label: String,
) -> void:
	_assert_eq(resource.current, expected_current, label + " current")
	_assert_eq(resource.effective, expected_effective, label + " effective")
	_assert_eq(resource.maximum, expected_maximum, label + " maximum")
	_assert_true(resource.has_valid_invariants(), label + " invariants")


func _assert_true(condition: bool, label: String) -> void:
	_assertion_count += 1
	if not condition:
		_failures.append(label + ": expected true")


func _assert_false(condition: bool, label: String) -> void:
	_assertion_count += 1
	if condition:
		_failures.append(label + ": expected false")


func _assert_eq(actual: Variant, expected: Variant, label: String) -> void:
	_assertion_count += 1
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])
