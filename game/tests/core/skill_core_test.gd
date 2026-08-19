extends RefCounted

const CharacterStateScript := preload("res://core/characters/character_state.gd")
const CharacterSkillStateScript := preload("res://core/skills/character_skill_state.gd")
const SkillDefinitionScript := preload("res://core/skills/skill_definition.gd")
const SkillProgressStateScript := preload("res://core/skills/skill_progress_state.gd")
const SkillIdsScript := preload("res://core/skills/skill_ids.gd")
const SkillUseIdsScript := preload("res://core/skills/skill_use_ids.gd")
const SkillEnableTransitionScript := preload("res://core/skills/skill_enable_transition.gd")
const SkillMappingChangeResultScript := preload(
	"res://core/skills/skill_mapping_change_result.gd"
)
const RecoverySkillLevelsAdapterScript := preload(
	"res://core/skills/recovery_skill_levels_adapter.gd"
)
const RecoverySkillLevelsScript := preload(
	"res://core/characters/recovery_skill_levels.gd"
)

var _assertion_count: int = 0
var _failures: Array[String] = []


func run_all() -> Dictionary[String, Variant]:
	_test_definition_shapes_from_representative_daemons()
	_test_missing_skill_lookup()
	_test_raw_and_learned_storage()
	_test_basic_effective_level_and_integer_division()
	_test_level_zero_improvement_boundary()
	_test_mapped_special_skill_effective_level()
	_test_mapping_replace_remove_and_missing_target()
	_test_skill_removal_preserves_unrelated_loadout_entry()
	_test_improvement_below_and_at_exact_threshold()
	_test_improvement_level_up_resets_without_carry()
	_test_improvement_penalty_and_minimum_amount()
	_test_weak_improvement_player_and_non_player_boundaries()
	_test_independent_skill_states_and_character_composition()
	_test_recovery_snapshot_uses_raw_levels_only()
	_test_enable_transition_validation()
	_test_enable_transition_internal_resource_reset_results()
	return {
		"assertions": _assertion_count,
		"failures": _failures.duplicate(),
	}


func _test_definition_shapes_from_representative_daemons() -> void:
	var sword: SkillDefinitionScript = _basic_martial(SkillIdsScript.SWORD)
	var literate: SkillDefinitionScript = SkillDefinitionScript.new(
		SkillIdsScript.LITERATE,
		SkillDefinitionScript.Kind.BASIC,
		SkillDefinitionScript.Type.KNOWLEDGE,
		false,
		[],
		"daemon/skill/literate.c",
	)
	var fonxan_sword: SkillDefinitionScript = _specialized_definition(
		SkillIdsScript.FONXAN_SWORD,
		SkillDefinitionScript.Type.MARTIAL,
		false,
		_typed_ids([SkillUseIdsScript.SWORD, SkillUseIdsScript.PARRY]),
	)
	var fonxan_force: SkillDefinitionScript = _specialized_definition(
		SkillIdsScript.FONXAN_FORCE,
		SkillDefinitionScript.Type.MARTIAL,
		true,
		_typed_ids([SkillUseIdsScript.FORCE]),
	)
	var essence_magic: SkillDefinitionScript = _specialized_definition(
		SkillIdsScript.ESSENCE_MAGIC,
		SkillDefinitionScript.Type.KNOWLEDGE,
		false,
		_typed_ids([SkillUseIdsScript.MAGIC]),
	)

	_assert_eq(sword.kind, SkillDefinitionScript.Kind.BASIC, "sword is basic")
	_assert_eq(sword.skill_type, SkillDefinitionScript.Type.MARTIAL, "sword defaults martial")
	_assert_eq(literate.skill_type, SkillDefinitionScript.Type.KNOWLEDGE, "literate is knowledge")
	_assert_eq(fonxan_sword.kind, SkillDefinitionScript.Kind.SPECIALIZED, "fonxansword specialized")
	_assert_true(fonxan_sword.can_enable_for(SkillUseIdsScript.SWORD), "fonxansword enables sword")
	_assert_true(fonxan_sword.can_enable_for(SkillUseIdsScript.PARRY), "fonxansword enables parry")
	_assert_false(fonxan_sword.can_enable_for(SkillUseIdsScript.FORCE), "fonxansword not force")
	_assert_true(fonxan_force.is_force_style, "fonxanforce inherits FORCE")
	_assert_true(fonxan_force.can_enable_for(SkillUseIdsScript.FORCE), "fonxanforce enables force")
	_assert_eq(
		essence_magic.skill_type,
		SkillDefinitionScript.Type.KNOWLEDGE,
		"essencemagic remains knowledge",
	)
	_assert_true(essence_magic.can_enable_for(SkillUseIdsScript.MAGIC), "essencemagic enables magic")

	var source_uses: Array[StringName] = _typed_ids([SkillUseIdsScript.SWORD])
	var isolated_definition: SkillDefinitionScript = _specialized_definition(
		&"isolated-definition",
		SkillDefinitionScript.Type.MARTIAL,
		false,
		source_uses,
	)
	source_uses.clear()
	_assert_true(
		isolated_definition.can_enable_for(SkillUseIdsScript.SWORD),
		"definition copies caller-owned enabled-use collection",
	)


func _test_missing_skill_lookup() -> void:
	var skills: CharacterSkillStateScript = CharacterSkillStateScript.new()
	var progress: SkillProgressStateScript = skills.progress_state(&"missing")
	_assert_eq(skills.raw_level(&"missing"), 0, "missing raw lookup is zero")
	_assert_eq(skills.learned_progress(&"missing"), 0, "missing learned lookup is zero")
	_assert_eq(skills.effective_level(&"missing"), 0, "missing effective lookup is zero")
	_assert_eq(skills.effective_level(&"missing", -3), -3, "modifier applies to missing skill")
	_assert_eq(skills.mapped_skill(&"missing"), &"", "missing mapped lookup is empty")
	_assert_false(progress.has_raw_level, "missing raw entry remains distinguishable")
	_assert_false(progress.has_learned_progress, "missing learned entry remains distinguishable")


func _test_raw_and_learned_storage() -> void:
	var skills: CharacterSkillStateScript = CharacterSkillStateScript.new()
	skills.set_raw_level(SkillIdsScript.SWORD, 7)
	skills.set_learned_progress(SkillIdsScript.SWORD, 12)
	var progress: SkillProgressStateScript = skills.progress_state(SkillIdsScript.SWORD)
	_assert_eq(skills.raw_level(SkillIdsScript.SWORD), 7, "raw level stored")
	_assert_eq(skills.learned_progress(SkillIdsScript.SWORD), 12, "learned progress stored")
	_assert_true(progress.has_raw_level, "raw mapping presence stored")
	_assert_true(progress.has_learned_progress, "learned mapping presence stored")
	_assert_eq(progress.raw_level, 7, "progress snapshot raw")
	_assert_eq(progress.learned_progress, 12, "progress snapshot learned")
	_assert_true(skills.remove_skill(SkillIdsScript.SWORD), "remove reports existing state")
	_assert_eq(skills.raw_level(SkillIdsScript.SWORD), 0, "remove clears raw")
	_assert_eq(skills.learned_progress(SkillIdsScript.SWORD), 0, "remove clears learned")
	_assert_true(
		skills.remove_skill(SkillIdsScript.SWORD),
		"legacy delete reports true once the skills mapping exists",
	)


func _test_basic_effective_level_and_integer_division() -> void:
	var skills: CharacterSkillStateScript = CharacterSkillStateScript.new()
	skills.set_raw_level(SkillIdsScript.SWORD, 5)
	_assert_eq(skills.effective_level(SkillIdsScript.SWORD), 2, "odd raw level halves by integer division")
	_assert_eq(skills.effective_level(SkillIdsScript.SWORD, -1), 1, "temporary modifier added first")
	skills.set_raw_level(SkillIdsScript.SWORD, 1)
	_assert_eq(skills.effective_level(SkillIdsScript.SWORD), 0, "raw one halves to zero")
	skills.set_raw_level(SkillIdsScript.SWORD, 6)
	_assert_eq(skills.effective_level(SkillIdsScript.SWORD), 3, "even raw level halves exactly")


func _test_level_zero_improvement_boundary() -> void:
	var skills: CharacterSkillStateScript = CharacterSkillStateScript.new()
	skills.set_raw_level(SkillIdsScript.SWORD, 0)
	_assert_true(skills.has_raw_level(SkillIdsScript.SWORD), "defined raw level zero preserves presence")
	_assert_eq(skills.raw_level(SkillIdsScript.SWORD), 0, "defined level zero reads as zero")
	_assert_eq(skills.effective_level(SkillIdsScript.SWORD), 0, "defined level zero is effective zero")
	_assert_false(
		skills.improve_skill(SkillIdsScript.SWORD, 1, 30),
		"level-zero exact threshold one does not level",
	)
	_assert_eq(skills.learned_progress(SkillIdsScript.SWORD), 1, "exact level-zero threshold retained")
	_assert_true(
		skills.improve_skill(SkillIdsScript.SWORD, 1, 30),
		"level-zero progress strictly above one levels once",
	)
	_assert_eq(skills.raw_level(SkillIdsScript.SWORD), 1, "level zero advances to one")
	_assert_eq(skills.learned_progress(SkillIdsScript.SWORD), 0, "level-zero advance clears progress")


func _test_mapped_special_skill_effective_level() -> void:
	var skills: CharacterSkillStateScript = CharacterSkillStateScript.new()
	skills.set_raw_level(SkillIdsScript.SWORD, 5)
	skills.set_raw_level(SkillIdsScript.FONXAN_SWORD, 7)
	_assert_true(skills.map_skill(SkillIdsScript.SWORD, SkillIdsScript.FONXAN_SWORD), "mapping succeeds")
	_assert_eq(skills.mapped_skill(SkillIdsScript.SWORD), SkillIdsScript.FONXAN_SWORD, "mapping lookup")
	_assert_eq(skills.effective_level(SkillIdsScript.SWORD), 9, "half basic plus full special")
	_assert_eq(skills.effective_level(SkillIdsScript.SWORD, 3), 12, "modifier plus basic plus special")
	_assert_false(
		skills.progress_state(SkillIdsScript.FONXAN_SWORD).has_learned_progress,
		"mapped raw skill contributes even without a learned entry",
	)
	_assert_true(skills.map_skill(SkillIdsScript.PARRY, SkillIdsScript.FONXAN_SWORD), "base raw not required by map_skill")
	_assert_eq(skills.effective_level(SkillIdsScript.PARRY), 7, "mapped skill works without basic raw entry")


func _test_mapping_replace_remove_and_missing_target() -> void:
	var skills: CharacterSkillStateScript = CharacterSkillStateScript.new()
	_assert_false(skills.map_skill(SkillIdsScript.SWORD, &"unknown"), "undefined target is ignored")
	skills.set_raw_level(&"first_special", 0)
	skills.set_raw_level(&"second_special", 8)
	_assert_true(skills.map_skill(SkillIdsScript.SWORD, &"first_special"), "defined zero target may map")
	_assert_eq(skills.mapped_skill(SkillIdsScript.SWORD), &"first_special", "first mapping stored")
	_assert_true(skills.map_skill(SkillIdsScript.SWORD, &"second_special"), "mapping replacement succeeds")
	_assert_eq(skills.mapped_skill(SkillIdsScript.SWORD), &"second_special", "mapping replaced whole value")
	_assert_true(skills.unmap_skill(SkillIdsScript.SWORD), "unmapping existing use succeeds")
	_assert_eq(skills.mapped_skill(SkillIdsScript.SWORD), &"", "unmapped lookup is empty")
	_assert_false(skills.unmap_skill(SkillIdsScript.SWORD), "unmapping missing use reports false")


func _test_skill_removal_preserves_unrelated_loadout_entry() -> void:
	var skills: CharacterSkillStateScript = CharacterSkillStateScript.new()
	skills.set_raw_level(SkillIdsScript.SWORD, 10)
	skills.set_raw_level(SkillIdsScript.FONXAN_SWORD, 20)
	skills.set_learned_progress(SkillIdsScript.FONXAN_SWORD, 30)
	skills.map_skill(SkillIdsScript.SWORD, SkillIdsScript.FONXAN_SWORD)
	skills.remove_skill(SkillIdsScript.FONXAN_SWORD)
	_assert_eq(
		skills.mapped_skill(SkillIdsScript.SWORD),
		SkillIdsScript.FONXAN_SWORD,
		"delete_skill does not clear skill_map",
	)
	_assert_eq(skills.effective_level(SkillIdsScript.SWORD), 5, "missing mapped raw contributes zero")
	_assert_eq(skills.learned_progress(SkillIdsScript.FONXAN_SWORD), 0, "delete clears learned entry")


func _test_improvement_below_and_at_exact_threshold() -> void:
	var below: CharacterSkillStateScript = CharacterSkillStateScript.new()
	below.set_raw_level(SkillIdsScript.SWORD, 2)
	_assert_false(below.improve_skill(SkillIdsScript.SWORD, 8, 30), "eight is below level-three threshold")
	_assert_eq(below.raw_level(SkillIdsScript.SWORD), 2, "below threshold raw unchanged")
	_assert_eq(below.learned_progress(SkillIdsScript.SWORD), 8, "below threshold progress retained")

	var exact: CharacterSkillStateScript = CharacterSkillStateScript.new()
	exact.set_raw_level(SkillIdsScript.SWORD, 2)
	_assert_false(exact.improve_skill(SkillIdsScript.SWORD, 9, 30), "exact square threshold does not level")
	_assert_eq(exact.raw_level(SkillIdsScript.SWORD), 2, "exact threshold raw unchanged")
	_assert_eq(exact.learned_progress(SkillIdsScript.SWORD), 9, "exact threshold progress retained")


func _test_improvement_level_up_resets_without_carry() -> void:
	var skills: CharacterSkillStateScript = CharacterSkillStateScript.new()
	skills.set_raw_level(SkillIdsScript.SWORD, 2)
	skills.set_learned_progress(SkillIdsScript.SWORD, 9)
	_assert_true(skills.improve_skill(SkillIdsScript.SWORD, 1, 30), "strictly above threshold levels")
	_assert_eq(skills.raw_level(SkillIdsScript.SWORD), 3, "level increases by exactly one")
	_assert_eq(skills.learned_progress(SkillIdsScript.SWORD), 0, "level-up resets learned to zero")

	var oversized: CharacterSkillStateScript = CharacterSkillStateScript.new()
	oversized.set_raw_level(SkillIdsScript.SWORD, 2)
	_assert_true(oversized.improve_skill(SkillIdsScript.SWORD, 20, 30), "large gain levels once")
	_assert_eq(oversized.raw_level(SkillIdsScript.SWORD), 3, "large gain does not loop levels")
	_assert_eq(oversized.learned_progress(SkillIdsScript.SWORD), 0, "large gain has no carry")


func _test_improvement_penalty_and_minimum_amount() -> void:
	var skills: CharacterSkillStateScript = CharacterSkillStateScript.new()
	skills.set_raw_level(SkillIdsScript.SWORD, 5)
	skills.set_learned_progress(SkillIdsScript.SWORD, 0)
	skills.set_learned_progress(SkillIdsScript.LITERATE, 0)
	_assert_false(skills.improve_skill(SkillIdsScript.SWORD, 3, 0), "penalized amount stays below threshold")
	_assert_eq(skills.learned_progress(SkillIdsScript.SWORD), 1, "three divided by two truncates to one")
	_assert_false(skills.improve_skill(SkillIdsScript.SWORD, 1, 0), "minimum amount still below threshold")
	_assert_eq(skills.learned_progress(SkillIdsScript.SWORD), 2, "zero quotient is forced to one")


func _test_weak_improvement_player_and_non_player_boundaries() -> void:
	var player: CharacterSkillStateScript = CharacterSkillStateScript.new()
	player.set_raw_level(SkillIdsScript.SWORD, 2)
	player.set_learned_progress(SkillIdsScript.SWORD, 9)
	_assert_false(
		player.improve_skill(SkillIdsScript.SWORD, 1, 30, true, true),
		"weak player improvement cannot level",
	)
	_assert_eq(player.raw_level(SkillIdsScript.SWORD), 2, "weak player raw remains unchanged")
	_assert_eq(player.learned_progress(SkillIdsScript.SWORD), 10, "weak player progress still accumulates")

	var missing_player_skill: CharacterSkillStateScript = CharacterSkillStateScript.new()
	missing_player_skill.improve_skill(&"future_skill", 1, 30, true, true)
	_assert_false(
		missing_player_skill.has_raw_level(&"future_skill"),
		"weak player improvement does not create raw skill",
	)
	_assert_eq(
		missing_player_skill.learned_progress(&"future_skill"),
		1,
		"weak player improvement creates learned progress",
	)

	var non_player: CharacterSkillStateScript = CharacterSkillStateScript.new()
	non_player.set_raw_level(SkillIdsScript.SWORD, 2)
	non_player.set_learned_progress(SkillIdsScript.SWORD, 9)
	_assert_true(
		non_player.improve_skill(SkillIdsScript.SWORD, 1, 30, true, false),
		"weak mode does not prevent non-player level-up",
	)
	_assert_eq(non_player.raw_level(SkillIdsScript.SWORD), 3, "non-player weak mode levels")
	_assert_eq(non_player.learned_progress(SkillIdsScript.SWORD), 0, "non-player level resets progress")


func _test_independent_skill_states_and_character_composition() -> void:
	var first: CharacterSkillStateScript = CharacterSkillStateScript.new()
	var second: CharacterSkillStateScript = CharacterSkillStateScript.new()
	first.set_raw_level(SkillIdsScript.SWORD, 10)
	first.set_raw_level(SkillIdsScript.FONXAN_SWORD, 20)
	first.map_skill(SkillIdsScript.SWORD, SkillIdsScript.FONXAN_SWORD)
	_assert_eq(second.raw_level(SkillIdsScript.SWORD), 0, "raw dictionaries are independent")
	_assert_eq(second.mapped_skill(SkillIdsScript.SWORD), &"", "loadouts are independent")

	var character: CharacterStateScript = CharacterStateScript.new()
	var other_character: CharacterStateScript = CharacterStateScript.new()
	_assert_true(character.skills != other_character.skills, "default character skill states are not shared")
	character.skills.set_raw_level(SkillIdsScript.FONXAN_SWORD, 20)
	character.skills.map_skill(SkillIdsScript.SWORD, SkillIdsScript.FONXAN_SWORD)
	_assert_eq(
		other_character.skills.mapped_skill(SkillIdsScript.SWORD),
		&"",
		"default character mapping state is not shared",
	)


func _test_recovery_snapshot_uses_raw_levels_only() -> void:
	var skills: CharacterSkillStateScript = CharacterSkillStateScript.new()
	skills.set_raw_level(SkillIdsScript.MAGIC, 5)
	skills.set_raw_level(SkillIdsScript.FORCE, 6)
	skills.set_raw_level(SkillIdsScript.SPELLS, 7)
	skills.set_raw_level(SkillIdsScript.ESSENCE_MAGIC, 99)
	skills.map_skill(SkillIdsScript.MAGIC, SkillIdsScript.ESSENCE_MAGIC)
	var snapshot: RecoverySkillLevelsScript = RecoverySkillLevelsAdapterScript.create_snapshot(skills)
	_assert_eq(snapshot.raw_magic, 5, "recovery magic snapshot is raw basic level")
	_assert_eq(snapshot.raw_force, 6, "recovery force snapshot is raw basic level")
	_assert_eq(snapshot.raw_spells, 7, "recovery spells snapshot is raw basic level")


func _test_enable_transition_validation() -> void:
	var definition: SkillDefinitionScript = _specialized_definition(
		SkillIdsScript.FONXAN_SWORD,
		SkillDefinitionScript.Type.MARTIAL,
		false,
		_typed_ids([SkillUseIdsScript.SWORD, SkillUseIdsScript.PARRY]),
	)
	var missing_target: CharacterSkillStateScript = CharacterSkillStateScript.new()
	missing_target.set_raw_level(SkillIdsScript.SWORD, 10)
	_assert_false(
		SkillEnableTransitionScript.try_enable(missing_target, definition, SkillUseIdsScript.SWORD).applied,
		"enable rejects unknown target skill",
	)

	var missing_basic: CharacterSkillStateScript = CharacterSkillStateScript.new()
	missing_basic.set_raw_level(SkillIdsScript.FONXAN_SWORD, 10)
	_assert_false(
		SkillEnableTransitionScript.try_enable(missing_basic, definition, SkillUseIdsScript.SWORD).applied,
		"enable rejects unknown basic skill",
	)

	var invalid_use: CharacterSkillStateScript = CharacterSkillStateScript.new()
	invalid_use.set_raw_level(SkillIdsScript.FONXAN_SWORD, 10)
	invalid_use.set_raw_level(SkillIdsScript.FORCE, 10)
	_assert_false(
		SkillEnableTransitionScript.try_enable(invalid_use, definition, SkillUseIdsScript.FORCE).applied,
		"enable rejects definition-invalid use",
	)

	var legacy_only: CharacterSkillStateScript = CharacterSkillStateScript.new()
	legacy_only.set_raw_level(SkillUseIdsScript.LEGACY_IRON_CLOTH, 10)
	legacy_only.set_raw_level(&"jin-gang", 10)
	var legacy_only_definition: SkillDefinitionScript = _specialized_definition(
		&"jin-gang",
		SkillDefinitionScript.Type.MARTIAL,
		true,
		_typed_ids([SkillUseIdsScript.LEGACY_IRON_CLOTH]),
	)
	_assert_false(
		SkillEnableTransitionScript.try_enable(
			legacy_only,
			legacy_only_definition,
			SkillUseIdsScript.LEGACY_IRON_CLOTH,
		).applied,
		"jin-gang use is absent from enable.c valid_types",
	)

	var preserved: CharacterSkillStateScript = CharacterSkillStateScript.new()
	preserved.set_raw_level(SkillIdsScript.SWORD, 10)
	preserved.set_raw_level(&"old_sword", 10)
	preserved.set_raw_level(SkillIdsScript.FONXAN_SWORD, 0)
	preserved.map_skill(SkillIdsScript.SWORD, &"old_sword")
	var rejected_zero: SkillMappingChangeResultScript = SkillEnableTransitionScript.try_enable(
		preserved,
		definition,
		SkillUseIdsScript.SWORD,
	)
	_assert_false(rejected_zero.applied, "enable rejects an explicitly zero target level")
	_assert_eq(
		rejected_zero.internal_resource_reset,
		SkillMappingChangeResultScript.InternalResourceReset.NONE,
		"failed validation requests no resource reset",
	)
	_assert_eq(
		preserved.mapped_skill(SkillIdsScript.SWORD),
		&"old_sword",
		"failed validation preserves the previous mapping",
	)

	var negative_levels: CharacterSkillStateScript = CharacterSkillStateScript.new()
	negative_levels.set_raw_level(SkillIdsScript.SWORD, -1)
	negative_levels.set_raw_level(SkillIdsScript.FONXAN_SWORD, -2)
	_assert_true(
		SkillEnableTransitionScript.try_enable(
			negative_levels,
			definition,
			SkillUseIdsScript.SWORD,
		).applied,
		"nonzero negative raw levels remain truthy as in enable.c",
	)


func _test_enable_transition_internal_resource_reset_results() -> void:
	var cases: Array[Array] = [
		[SkillUseIdsScript.MAGIC, &"special_magic", SkillMappingChangeResultScript.InternalResourceReset.ATMAN],
		[SkillUseIdsScript.FORCE, &"special_force", SkillMappingChangeResultScript.InternalResourceReset.INNER_FORCE],
		[SkillUseIdsScript.SPELLS, &"special_spells", SkillMappingChangeResultScript.InternalResourceReset.MANA],
		[SkillUseIdsScript.SWORD, &"special_sword", SkillMappingChangeResultScript.InternalResourceReset.NONE],
	]
	for test_case: Array in cases:
		var use_id: StringName = test_case[0]
		var special_id: StringName = test_case[1]
		var expected_reset: int = test_case[2]
		var skills: CharacterSkillStateScript = CharacterSkillStateScript.new()
		skills.set_raw_level(use_id, 10)
		skills.set_raw_level(special_id, 20)
		var definition: SkillDefinitionScript = _specialized_definition(
			special_id,
			SkillDefinitionScript.Type.MARTIAL,
			use_id == SkillUseIdsScript.FORCE,
			_typed_ids([use_id]),
		)
		var result: SkillMappingChangeResultScript = SkillEnableTransitionScript.try_enable(
			skills,
			definition,
			use_id,
		)
		_assert_true(result.applied, "valid enable applies for %s" % use_id)
		_assert_eq(result.internal_resource_reset, expected_reset, "reset result for %s" % use_id)
		_assert_eq(skills.mapped_skill(use_id), special_id, "enabled mapping stored for %s" % use_id)

		var repeated: SkillMappingChangeResultScript = SkillEnableTransitionScript.try_enable(
			skills,
			definition,
			use_id,
		)
		_assert_true(repeated.applied, "re-enabling the same skill is still applied for %s" % use_id)
		_assert_eq(
			repeated.internal_resource_reset,
			expected_reset,
			"re-enabling same skill preserves LPC reset side effect for %s" % use_id,
		)


func _basic_martial(skill_id: StringName) -> SkillDefinitionScript:
	return SkillDefinitionScript.new(
		skill_id,
		SkillDefinitionScript.Kind.BASIC,
		SkillDefinitionScript.Type.MARTIAL,
	)


func _specialized_definition(
	skill_id: StringName,
	skill_type: int,
	is_force_style: bool,
	valid_uses: Array[StringName],
) -> SkillDefinitionScript:
	return SkillDefinitionScript.new(
		skill_id,
		SkillDefinitionScript.Kind.SPECIALIZED,
		skill_type,
		is_force_style,
		valid_uses,
		"daemon/skill/%s.c" % skill_id,
	)


func _typed_ids(values: Array) -> Array[StringName]:
	var result: Array[StringName] = []
	for value: StringName in values:
		result.append(value)
	return result


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
