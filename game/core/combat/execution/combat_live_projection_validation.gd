class_name CombatLiveProjectionValidation
extends RefCounted

const UNARMED_SKILL_ID: StringName = &"unarmed"
const FORCE_SKILL_ID: StringName = &"force"

## Shared non-action live checks, extracted unchanged from reverse validation.
static func matches(
	attacker_id: StringName,
	victim_id: StringName,
	projection: CombatReverseAttackProjection,
) -> bool:
	if projection == null:
		return false
	var attacker_authority: CombatCharacterAuthority = projection.attacker_authority()
	var defender_authority: CombatCharacterAuthority = projection.defender_authority()
	if (
		attacker_authority == null
		or defender_authority == null
		or not attacker_authority.is_valid()
		or not defender_authority.is_valid()
		or attacker_authority == defender_authority
		or attacker_authority.character_id != attacker_id
		or defender_authority.character_id != victim_id
		or attacker_authority.character_id == defender_authority.character_id
		or attacker_authority.state() == defender_authority.state()
	):
		return false
	var attacker: CharacterState = attacker_authority.state()
	var defender: CharacterState = defender_authority.state()
	var input: CombatAttackInput = projection.attack_input_template()
	var attacker_facts: CombatProgressionFacts = projection.attacker_facts()
	var defender_facts: CombatProgressionFacts = projection.defender_facts()
	var busy_projection: CombatBusyInterruptProjection = (
		projection.defender_busy_projection()
	)
	var attacker_relationship: CombatRelationshipState = (
		projection.attacker_relationship()
	)
	var defender_relationship: CombatRelationshipState = (
		projection.defender_relationship()
	)
	var selection_input: CombatActionSelectionInput = projection.action_selection_input()
	var modifiers: CombatReverseModifierProjection = projection.modifier_projection()
	if (
		input == null
		or not input.matches_action_source(selection_input)
		or attacker_facts == null
		or defender_facts == null
		or not attacker_facts.is_valid()
		or not defender_facts.is_valid()
		or busy_projection == null
		or not busy_projection.is_valid()
		or attacker_relationship == null
		or defender_relationship == null
		or attacker_relationship == defender_relationship
		or not attacker_relationship.is_valid()
		or not defender_relationship.is_valid()
		or selection_input == null
		or modifiers == null
		or not modifiers.is_valid()
	):
		return false
	var attacker_snapshot: CombatAttackerSnapshot = input.attacker
	var defender_snapshot: CombatDefenderSnapshot = input.defender
	if attacker_snapshot == null or defender_snapshot == null:
		return false
	if (
		attacker_snapshot.character_id != attacker_id
		or defender_snapshot.character_id != victim_id
		or attacker_facts.character_id != attacker_id
		or defender_facts.character_id != victim_id
		or attacker_relationship.owner_character_id != attacker_id
		or defender_relationship.owner_character_id != victim_id
		or modifiers.attacker_character_id != attacker_id
		or modifiers.defender_character_id != victim_id
		or attacker_snapshot.combat_experience
		!= attacker.progression.combat_experience
		or defender_snapshot.combat_experience
		!= defender.progression.combat_experience
		or attacker_snapshot.current_spirit != attacker.spirit.current
		or attacker_snapshot.maximum_spirit != attacker.spirit.maximum
		or defender_snapshot.current_spirit != defender.spirit.current
		or defender_snapshot.maximum_spirit != defender.spirit.maximum
		or defender_snapshot.current_inner_force
		!= defender.recovery.inner_force.current
	):
		return false
	if (
		attacker_facts.base_intelligence != attacker.attributes.intelligence
		or attacker_facts.base_spirituality != attacker.attributes.spirituality
		or defender_facts.base_intelligence != defender.attributes.intelligence
		or defender_facts.base_spirituality != defender.attributes.spirituality
	):
		return false
	var strength: CombatStrengthProjection = attacker_snapshot.strength_projection
	if (
		strength.base_strength != attacker.attributes.strength
		or strength.force_factor != attacker.attributes.force_factor
		or strength.strength_modifier != attacker.attributes.strength_modifier
	):
		return false
	var current_weapon: EquippedWeaponRef = attacker.equipment.primary_weapon()
	var has_current_weapon: bool = current_weapon != null
	if attacker_snapshot.has_weapon != has_current_weapon:
		return false
	var expected_attack_skill: StringName = UNARMED_SKILL_ID
	if has_current_weapon:
		var weapon_profile: WeaponCombatProfile = attacker_snapshot.weapon_profile
		if (
			weapon_profile == null
			or weapon_profile.weapon_id != current_weapon.weapon_id
			or weapon_profile.skill_type != current_weapon.skill_type
		):
			return false
		expected_attack_skill = current_weapon.skill_type
	if (
		attacker_snapshot.projected_attack_skill_type != expected_attack_skill
		or attacker_facts.attack_skill_definition_id != expected_attack_skill
		or attacker_snapshot.mapped_attack_skill_id
		!= attacker.skills.mapped_skill(expected_attack_skill)
		or attacker_snapshot.mapped_force_skill_id
		!= attacker.skills.mapped_skill(FORCE_SKILL_ID)
		or selection_input.mapped_skill_present
		!= (not attacker_snapshot.mapped_attack_skill_id.is_empty())
		or selection_input.primary_weapon_present != has_current_weapon
		or defender_snapshot.has_primary_weapon
		!= (not defender.equipment.is_primary_hand_empty())
	):
		return false
	if (
		attacker_snapshot.effective_attack_skill_level
		!= attacker.skills.effective_level(
			expected_attack_skill,
			modifiers.attacker_attack_skill_modifier,
		)
		or attacker_snapshot.effective_force_skill_level
		!= attacker.skills.effective_level(
			attacker_snapshot.projected_force_skill_type,
			modifiers.attacker_force_skill_modifier,
		)
		or defender_snapshot.effective_dodge_skill_level
		!= defender.skills.effective_level(
			&"dodge",
			modifiers.defender_dodge_skill_modifier,
		)
		or defender_snapshot.effective_parry_skill_level
		!= defender.skills.effective_level(
			&"parry",
			modifiers.defender_parry_skill_modifier,
		)
		or defender_snapshot.effective_unarmed_skill_level
		!= defender.skills.effective_level(
			UNARMED_SKILL_ID,
			modifiers.defender_unarmed_skill_modifier,
		)
		or defender_snapshot.effective_force_skill_level
		!= defender.skills.effective_level(
			defender_snapshot.projected_force_skill_type,
			modifiers.defender_force_skill_modifier,
		)
		or attacker_snapshot.attack_usage_bonus
		!= modifiers.attacker_attack_usage_bonus
		or defender_snapshot.defense_usage_bonus
		!= modifiers.defender_defense_usage_bonus
		or attacker_snapshot.projected_apply_damage
		!= modifiers.attacker_apply_damage
		or defender_snapshot.armor != modifiers.defender_armor
		or defender_snapshot.armor_vs_force != modifiers.defender_armor_vs_force
	):
		return false
	return _busy_projection_matches(
		defender_snapshot,
		busy_projection,
		projection.defender_busy_state(),
	)


static func _busy_projection_matches(
	defender: CombatDefenderSnapshot,
	projection: CombatBusyInterruptProjection,
	state: ActionBusyState,
) -> bool:
	var projected_busy: bool = (
		projection.busy_kind != CombatBusyInterruptProjection.BusyKind.NOT_BUSY
	)
	if defender.busy != projected_busy:
		return false
	if (
		projection.busy_kind == CombatBusyInterruptProjection.BusyKind.INTEGER
		and projection.interrupt_kind
		== CombatBusyInterruptProjection.InterruptKind.INTEGER
	):
		return state != null and state.is_busy()
	if (
		projection.busy_kind == CombatBusyInterruptProjection.BusyKind.NOT_BUSY
		and projection.interrupt_kind
		== CombatBusyInterruptProjection.InterruptKind.INTEGER
	):
		return state == null or not state.is_busy()
	return state == null
