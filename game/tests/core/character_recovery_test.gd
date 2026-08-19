extends RefCounted

const CharacterAttributesScript := preload(
	"res://core/characters/character_base_attributes.gd"
)
const CharacterResourceScript := preload(
	"res://core/characters/character_resource_state.gd"
)
const CharacterInternalResourceScript := preload(
	"res://core/characters/character_internal_resource_state.gd"
)
const CharacterRecoveryStateScript := preload(
	"res://core/characters/character_recovery_state.gd"
)
const RecoverySkillLevelsScript := preload(
	"res://core/characters/recovery_skill_levels.gd"
)
const CharacterStateScript := preload("res://core/characters/character_state.gd")
const CharacterRecoveryScript := preload(
	"res://core/characters/character_recovery.gd"
)

var _assertion_count: int = 0
var _failures: Array[String] = []


func run_all() -> Dictionary[String, Variant]:
	_test_default_recovery_state_invariants()
	_test_internal_resource_preserves_unrestricted_legacy_values()
	_test_capacity_formulas_preserve_integer_division()
	_test_tick_uses_raw_constitution_and_current_internal_resources()
	_test_player_water_gate_ordering()
	_test_player_food_gate_ordering()
	_test_non_player_ignores_sustenance_gates()
	_test_primary_resource_recovery_boundaries()
	_test_internal_resource_recovery_boundaries()
	_test_recovery_block_short_circuits_entire_tick()
	_test_lifecycle_gating_stays_outside_recovery_calculation()
	_test_sustenance_is_not_capacity_clamped()
	_test_negative_sustenance_is_preserved()
	return {
		"assertions": _assertion_count,
		"failures": _failures.duplicate(),
	}


func _test_default_recovery_state_invariants() -> void:
	var state: CharacterStateScript = CharacterStateScript.new()
	var other_state: CharacterStateScript = CharacterStateScript.new()
	_assert_eq(state.recovery.inner_force.current, 0, "default force")
	_assert_eq(state.recovery.inner_force.maximum, 0, "default max_force")
	_assert_eq(state.recovery.mana.current, 0, "default mana")
	_assert_eq(state.recovery.atman.current, 0, "default atman")
	_assert_eq(state.recovery.food, 0, "default food")
	_assert_eq(state.recovery.water, 0, "default water")
	_assert_true(state.recovery != other_state.recovery, "recovery states are not shared")
	_assert_true(
		state.recovery.inner_force != other_state.recovery.inner_force,
		"force states are not shared",
	)
	_assert_true(state.recovery.mana != state.recovery.atman, "internal tracks are distinct")
	state.recovery.inner_force.current = 20
	state.recovery.food = 5
	_assert_eq(other_state.recovery.inner_force.current, 0, "force mutation is local")
	_assert_eq(other_state.recovery.food, 0, "food mutation is local")


func _test_internal_resource_preserves_unrestricted_legacy_values() -> void:
	var resource: CharacterInternalResourceScript = CharacterInternalResourceScript.new(250, 100)
	_assert_eq(resource.current, 250, "legacy current may start above maximum")
	_assert_eq(resource.maximum, 100, "internal maximum is retained")
	resource.maximum = 50
	_assert_eq(resource.current, 250, "lowering maximum does not clamp current")
	resource.current = -7
	_assert_eq(resource.current, -7, "internal current has no invented zero clamp")
	resource.maximum = -5
	_assert_eq(resource.maximum, -5, "maximum has no invented non-negative constraint")


func _test_capacity_formulas_preserve_integer_division() -> void:
	_assert_eq(CharacterRecoveryScript.maximum_food_capacity(0), 0, "zero food capacity")
	_assert_eq(CharacterRecoveryScript.maximum_food_capacity(199), 0, "food below divisor")
	_assert_eq(CharacterRecoveryScript.maximum_food_capacity(200), 1, "food divisor boundary")
	_assert_eq(CharacterRecoveryScript.maximum_food_capacity(399), 1, "food truncates")
	_assert_eq(CharacterRecoveryScript.maximum_water_capacity(400), 2, "water capacity")
	_assert_eq(CharacterRecoveryScript.maximum_food_capacity(40_000), 200, "human weight capacity")
	_assert_eq(CharacterRecoveryScript.maximum_food_capacity(-199), 0, "negative division truncates")
	_assert_eq(CharacterRecoveryScript.maximum_water_capacity(-200), -1, "capacity has no zero floor")


func _test_tick_uses_raw_constitution_and_current_internal_resources() -> void:
	var state: CharacterStateScript = _character_state(
		11,
		CharacterResourceScript.new(50, 80, 100),
		CharacterResourceScript.new(78, 80, 100),
		CharacterResourceScript.new(100, 100, 100),
		CharacterRecoveryStateScript.new(
			CharacterInternalResourceScript.new(20, 100),
			CharacterInternalResourceScript.new(30, 100),
			CharacterInternalResourceScript.new(10, 100),
			5,
			5,
		),
	)
	state.attributes.constitution_modifier = 99
	var skills: RecoverySkillLevelsScript = RecoverySkillLevelsScript.new(5, 7, 9)

	var updates: int = CharacterRecoveryScript.apply_tick(state, skills, true)

	_assert_eq(updates, 7, "legacy update_flag count")
	_assert_resource(state.essence, 54, 80, 100, "gin uses con/3 + atman/10")
	_assert_resource(state.vitality, 80, 81, 100, "kee reaches old effective then repairs one")
	_assert_resource(state.spirit, 100, 100, 100, "full sen does not update")
	_assert_internal(state.recovery.atman, 12, 100, "atman uses raw magic/2")
	_assert_internal(state.recovery.inner_force, 23, 100, "force uses raw force/2")
	_assert_internal(state.recovery.mana, 34, 100, "mana uses raw spells/2")
	_assert_eq(state.recovery.food, 4, "food consumed first")
	_assert_eq(state.recovery.water, 4, "water consumed first")


func _test_player_water_gate_ordering() -> void:
	var state: CharacterStateScript = _recoverable_state(1, 5)
	var before_essence: int = state.essence.current
	var before_atman: int = state.recovery.atman.current

	var updates: int = CharacterRecoveryScript.apply_tick(
		state,
		RecoverySkillLevelsScript.new(20, 20, 20),
		true,
	)

	_assert_eq(updates, 2, "water and food consumption both count before water gate")
	_assert_eq(state.recovery.water, 0, "last water is consumed")
	_assert_eq(state.recovery.food, 4, "food is consumed before water gate")
	_assert_eq(state.essence.current, before_essence, "water gate blocks gin recovery")
	_assert_eq(state.recovery.atman.current, before_atman, "water gate blocks atman recovery")

	var already_dry: CharacterStateScript = _recoverable_state(0, 5)
	_assert_eq(
		CharacterRecoveryScript.apply_tick(
			already_dry,
			RecoverySkillLevelsScript.new(),
			true,
		),
		1,
		"positive food still counts when water starts empty",
	)
	_assert_eq(already_dry.recovery.food, 4, "dry player still consumes food before exit")


func _test_player_food_gate_ordering() -> void:
	var state: CharacterStateScript = _recoverable_state(5, 1)
	var before_atman: int = state.recovery.atman.current

	var updates: int = CharacterRecoveryScript.apply_tick(
		state,
		RecoverySkillLevelsScript.new(20, 20, 20),
		true,
	)

	_assert_eq(updates, 5, "sustenance plus three primary resources update")
	_assert_eq(state.recovery.water, 4, "water consumed")
	_assert_eq(state.recovery.food, 0, "last food consumed")
	_assert_eq(state.essence.current, 21, "food gate follows exact gin recovery")
	_assert_eq(state.vitality.current, 22, "food gate follows exact kee recovery")
	_assert_eq(state.spirit.current, 23, "food gate follows exact sen recovery")
	_assert_eq(state.recovery.atman.current, before_atman, "food gate blocks atman recovery")
	_assert_eq(state.recovery.inner_force.current, 20, "food gate blocks force recovery")
	_assert_eq(state.recovery.mana.current, 30, "food gate blocks mana recovery")


func _test_non_player_ignores_sustenance_gates() -> void:
	var state: CharacterStateScript = _recoverable_state(0, 0)
	var updates: int = CharacterRecoveryScript.apply_tick(
		state,
		RecoverySkillLevelsScript.new(4, 6, 8),
		false,
	)

	_assert_eq(updates, 6, "non-player updates three primary and three internal tracks")
	_assert_eq(state.essence.current, 21, "non-player gin recovers exactly without water")
	_assert_eq(state.vitality.current, 22, "non-player kee recovers exactly without water")
	_assert_eq(state.spirit.current, 23, "non-player sen recovers exactly without water")
	_assert_internal(state.recovery.atman, 12, 100, "non-player atman recovers without food")
	_assert_internal(state.recovery.inner_force, 23, 100, "non-player force recovery")
	_assert_internal(state.recovery.mana, 34, 100, "non-player mana recovery")
	_assert_eq(state.recovery.food, 0, "non-positive food is not decremented")
	_assert_eq(state.recovery.water, 0, "non-positive water is not decremented")


func _test_primary_resource_recovery_boundaries() -> void:
	var reaches_effective: CharacterStateScript = _character_state(
		3,
		CharacterResourceScript.new(9, 10, 20),
		CharacterResourceScript.new(20, 20, 20),
		CharacterResourceScript.new(20, 20, 20),
		CharacterRecoveryStateScript.new(null, null, null, 2, 2),
	)
	var updates: int = CharacterRecoveryScript.apply_tick(
		reaches_effective,
		RecoverySkillLevelsScript.new(),
		true,
	)
	_assert_eq(updates, 3, "two sustenance updates plus wounded gin")
	_assert_resource(reaches_effective.essence, 10, 11, 20, "exact reach repairs effective by one")

	var zero_gain: CharacterStateScript = _character_state(
		2,
		CharacterResourceScript.new(5, 10, 10),
		CharacterResourceScript.new(10, 10, 10),
		CharacterResourceScript.new(10, 10, 10),
		CharacterRecoveryStateScript.new(null, null, null, 2, 2),
	)
	updates = CharacterRecoveryScript.apply_tick(
		zero_gain,
		RecoverySkillLevelsScript.new(),
		true,
	)
	_assert_eq(updates, 3, "below-effective branch counts even when con/3 is zero")
	_assert_resource(zero_gain.essence, 5, 10, 10, "zero recovery amount leaves current unchanged")


func _test_internal_resource_recovery_boundaries() -> void:
	var state: CharacterStateScript = _character_state(
		0,
		CharacterResourceScript.new(),
		CharacterResourceScript.new(),
		CharacterResourceScript.new(),
		CharacterRecoveryStateScript.new(
			CharacterInternalResourceScript.new(99, 100),
			CharacterInternalResourceScript.new(50, 100),
			CharacterInternalResourceScript.new(0, 0),
			0,
			0,
		),
	)
	var updates: int = CharacterRecoveryScript.apply_tick(
		state,
		RecoverySkillLevelsScript.new(99, 3, 1),
		false,
	)
	_assert_eq(updates, 2, "eligible force and mana branches count")
	_assert_internal(state.recovery.inner_force, 100, 100, "odd raw force truncates and caps")
	_assert_internal(state.recovery.mana, 50, 100, "raw spells one yields zero but still counts")
	_assert_internal(state.recovery.atman, 0, 0, "zero max_atman disables recovery")

	state.recovery.inner_force.current = 120
	state.recovery.mana.current = 100
	updates = CharacterRecoveryScript.apply_tick(
		state,
		RecoverySkillLevelsScript.new(99, 99, 99),
		false,
	)
	_assert_eq(updates, 0, "at-or-above maximum internal tracks do not update")
	_assert_eq(state.recovery.inner_force.current, 120, "over-maximum force is not reduced")

	var negative_maximum: CharacterStateScript = _character_state(
		3,
		CharacterResourceScript.new(),
		CharacterResourceScript.new(),
		CharacterResourceScript.new(),
		CharacterRecoveryStateScript.new(
			CharacterInternalResourceScript.new(-10, -5),
			null,
			null,
			0,
			0,
		),
	)
	updates = CharacterRecoveryScript.apply_tick(
		negative_maximum,
		RecoverySkillLevelsScript.new(0, 4, 0),
		false,
	)
	_assert_eq(updates, 1, "negative nonzero maximum follows LPC truth and comparison")
	_assert_internal(negative_maximum.recovery.inner_force, -8, -5, "negative maximum recovery")


func _test_recovery_block_short_circuits_entire_tick() -> void:
	var state: CharacterStateScript = _recoverable_state(5, 5)
	var updates: int = CharacterRecoveryScript.apply_tick(
		state,
		RecoverySkillLevelsScript.new(20, 20, 20),
		true,
		true,
	)
	_assert_eq(updates, 0, "no-heal block returns zero")
	_assert_eq(state.recovery.water, 5, "no-heal block prevents water consumption")
	_assert_eq(state.recovery.food, 5, "no-heal block prevents food consumption")
	_assert_eq(state.essence.current, 10, "no-heal block prevents primary recovery")
	_assert_eq(state.recovery.atman.current, 10, "no-heal block prevents internal recovery")


func _test_lifecycle_gating_stays_outside_recovery_calculation() -> void:
	var unconscious: CharacterStateScript = _recoverable_state(5, 5)
	unconscious.vitality.apply_damage(101)
	var updates: int = CharacterRecoveryScript.apply_tick(
		unconscious,
		RecoverySkillLevelsScript.new(),
		true,
	)
	_assert_eq(updates, 8, "direct heal_up calculation has no lifecycle gate")
	_assert_eq(unconscious.recovery.water, 4, "calculation consumes water when invoked")
	_assert_eq(unconscious.recovery.food, 4, "calculation consumes food when invoked")
	_assert_resource(unconscious.vitality, 11, 100, 100, "direct calculation can heal current")


func _test_sustenance_is_not_capacity_clamped() -> void:
	var state: CharacterStateScript = _recoverable_state(250, 300)
	_assert_eq(CharacterRecoveryScript.maximum_food_capacity(40_000), 200, "reference capacity")
	_assert_eq(state.recovery.food, 300, "state preserves food above capacity")
	_assert_eq(state.recovery.water, 250, "state preserves water above capacity")
	CharacterRecoveryScript.apply_tick(state, RecoverySkillLevelsScript.new(), true)
	_assert_eq(state.recovery.food, 299, "tick decrements oversupplied food by one")
	_assert_eq(state.recovery.water, 249, "tick decrements oversupplied water by one")


func _test_negative_sustenance_is_preserved() -> void:
	var state: CharacterStateScript = _recoverable_state(-2, -3)
	var updates: int = CharacterRecoveryScript.apply_tick(
		state,
		RecoverySkillLevelsScript.new(20, 20, 20),
		true,
	)
	_assert_eq(updates, 0, "negative water reaches player water gate without mutation")
	_assert_eq(state.recovery.water, -2, "negative water is not clamped or decremented")
	_assert_eq(state.recovery.food, -3, "negative food is not clamped or decremented")
	_assert_eq(state.essence.current, 10, "negative water prevents primary recovery")


func _recoverable_state(water: int, food: int) -> CharacterStateScript:
	return _character_state(
		30,
		CharacterResourceScript.new(10, 100, 100),
		CharacterResourceScript.new(10, 100, 100),
		CharacterResourceScript.new(10, 100, 100),
		CharacterRecoveryStateScript.new(
			CharacterInternalResourceScript.new(20, 100),
			CharacterInternalResourceScript.new(30, 100),
			CharacterInternalResourceScript.new(10, 100),
			food,
			water,
		),
	)


func _character_state(
	constitution: int,
	essence: CharacterResourceScript,
	vitality: CharacterResourceScript,
	spirit: CharacterResourceScript,
	recovery: CharacterRecoveryStateScript,
) -> CharacterStateScript:
	return CharacterStateScript.new(
		CharacterAttributesScript.new(0, 0, 0, 0, 0, 0, constitution),
		essence,
		vitality,
		spirit,
		recovery,
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


func _assert_internal(
	resource: CharacterInternalResourceScript,
	expected_current: int,
	expected_maximum: int,
	label: String,
) -> void:
	_assert_eq(resource.current, expected_current, label + " current")
	_assert_eq(resource.maximum, expected_maximum, label + " maximum")


func _assert_true(condition: bool, label: String) -> void:
	_assertion_count += 1
	if not condition:
		_failures.append(label + ": expected true")


func _assert_eq(actual: Variant, expected: Variant, label: String) -> void:
	_assertion_count += 1
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])
