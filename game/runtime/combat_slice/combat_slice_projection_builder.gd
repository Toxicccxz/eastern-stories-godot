class_name CombatSliceProjectionBuilder
extends RefCounted

const FORCE_SKILL_ID: StringName = &"force"
const UNARMED_SKILL_ID: StringName = &"unarmed"
const DODGE_SKILL_ID: StringName = &"dodge"
const PARRY_SKILL_ID: StringName = &"parry"
const PERCEPTION_SKILL_ID: StringName = &"perception"


static func build_opponent_availability(
	owner: CombatSliceCharacterBinding,
	participants: Array[CombatSliceCharacterBinding],
) -> Array[CombatOpponentAvailabilityFacts]:
	var facts: Array[CombatOpponentAvailabilityFacts] = []
	if owner == null or not owner.is_valid():
		return facts
	for opponent_id: StringName in owner.relationship.opponent_ids():
		var opponent: CombatSliceCharacterBinding = find_binding(
			participants,
			opponent_id,
		)
		if opponent == null:
			facts.append(CombatOpponentAvailabilityFacts.new(opponent_id))
			continue
		var exists: bool = (
			opponent.exists_in_encounter
			and opponent.life_status != CombatSliceLifeStatus.Value.DEAD
		)
		facts.append(
			CombatOpponentAvailabilityFacts.new(
				opponent_id,
				exists,
				owner.location_id == opponent.location_id,
				opponent.life_status == CombatSliceLifeStatus.Value.ACTIVE,
			)
		)
	return facts


static func build_fight_facts(
	attacker: CombatSliceCharacterBinding,
	victim: CombatSliceCharacterBinding,
) -> CombatFightDecisionFacts:
	if attacker == null or victim == null:
		return null
	return CombatFightDecisionFacts.new(
		attacker.character_id,
		attacker.life_status == CombatSliceLifeStatus.Value.ACTIVE,
		attacker.content.target_visible,
		CombatPerceptionSkillProjection.new(
			PERCEPTION_SKILL_ID,
			attacker.state.skills.effective_level(PERCEPTION_SKILL_ID),
		),
		attacker.state.attributes.courage,
		attacker.state.attributes.bellicosity,
		victim.character_id,
		victim.life_status == CombatSliceLifeStatus.Value.ACTIVE,
		victim.busy.is_busy(),
		victim.state.attributes.composure,
	)


static func build_action_selection_input(
	attacker: CombatSliceCharacterBinding,
) -> CombatActionSelectionInput:
	if attacker == null or not attacker.is_valid():
		return null
	var primary: EquippedWeaponRef = attacker.state.equipment.primary_weapon()
	var attack_skill_id: StringName = (
		primary.skill_type if primary != null else UNARMED_SKILL_ID
	)
	var mapped_skill_id: StringName = attacker.state.skills.mapped_skill(
		attack_skill_id
	)
	var primary_set: CombatActionSet = null
	if primary != null and attacker.content.is_verified_primary(primary):
		primary_set = attacker.content.slash_action_set()
	return CombatActionSelectionInput.new(
		not mapped_skill_id.is_empty(),
		null,
		primary != null,
		primary_set,
		attacker.content.unarmed_action_set(),
	)


static func build_attack_input(
	attacker: CombatSliceCharacterBinding,
	defender: CombatSliceCharacterBinding,
	selected_action: CombatActionDefinition,
) -> CombatAttackInput:
	if attacker == null or defender == null or selected_action == null:
		return null
	var attacker_armor: ArmorNumericModifiers = (
		attacker.armor.aggregate_numeric_modifiers()
	)
	var defender_armor: ArmorNumericModifiers = (
		defender.armor.aggregate_numeric_modifiers()
	)
	var primary: EquippedWeaponRef = attacker.state.equipment.primary_weapon()
	var attack_skill_id: StringName = (
		primary.skill_type if primary != null else UNARMED_SKILL_ID
	)
	var attack_skill_modifier: int = (
		attacker_armor.unarmed if primary == null else 0
	)
	var mapped_attack_id: StringName = attacker.state.skills.mapped_skill(
		attack_skill_id
	)
	var mapped_force_id: StringName = attacker.state.skills.mapped_skill(
		FORCE_SKILL_ID
	)
	var weapon_profile: WeaponCombatProfile = null
	if primary != null:
		var weapon_policy: int = CombatHitPolicyStatus.Value.AUTHORED_POLICY_UNAVAILABLE
		if attacker.content.is_verified_primary(primary):
			weapon_policy = CombatHitPolicyStatus.Value.PROVEN_NO_AUTHORED_EFFECT
		weapon_profile = WeaponCombatProfile.new(
			primary.weapon_id,
			primary.skill_type,
			weapon_policy,
		)
	var attacker_snapshot: CombatAttackerSnapshot = CombatAttackerSnapshot.new(
		attacker.character_id,
		attacker.life_status == CombatSliceLifeStatus.Value.ACTIVE,
		attacker.state.progression.combat_experience,
		attacker.state.spirit.current,
		attacker.state.spirit.maximum,
		attack_skill_id,
		attacker.state.skills.effective_level(
			attack_skill_id,
			attack_skill_modifier,
		),
		attacker_armor.attack,
		attacker.content.projected_apply_damage(primary),
		CombatStrengthProjection.new(
			attacker.state.attributes.strength,
			attacker.state.attributes.force_factor,
			attacker.state.attributes.strength_modifier,
		),
		attacker.relationship.has_lethal_target(defender.character_id),
		mapped_force_id,
		(
			CombatHitPolicyStatus.Value.NOT_APPLICABLE
			if mapped_force_id.is_empty()
			else CombatHitPolicyStatus.Value.AUTHORED_POLICY_UNAVAILABLE
		),
		mapped_attack_id,
		(
			CombatHitPolicyStatus.Value.NOT_APPLICABLE
			if mapped_attack_id.is_empty()
			else CombatHitPolicyStatus.Value.AUTHORED_POLICY_UNAVAILABLE
		),
		(
			CombatHitPolicyStatus.Value.PROVEN_NO_AUTHORED_EFFECT
			if primary == null
			else CombatHitPolicyStatus.Value.NOT_APPLICABLE
		),
		weapon_profile,
		FORCE_SKILL_ID,
		attacker.state.skills.effective_level(FORCE_SKILL_ID),
	)
	var defender_snapshot: CombatDefenderSnapshot = CombatDefenderSnapshot.new(
		defender.character_id,
		defender.life_status == CombatSliceLifeStatus.Value.ACTIVE,
		defender.busy.is_busy(),
		defender.state.progression.combat_experience,
		defender.state.spirit.current,
		defender.state.spirit.maximum,
		defender.state.skills.effective_level(DODGE_SKILL_ID, defender_armor.dodge),
		defender.state.skills.effective_level(PARRY_SKILL_ID),
		defender.state.skills.effective_level(UNARMED_SKILL_ID, defender_armor.unarmed),
		defender_armor.defense,
		defender_armor.armor,
		not defender.state.equipment.is_primary_hand_empty(),
		defender.content.limbs(),
		FORCE_SKILL_ID,
		defender.state.skills.effective_level(FORCE_SKILL_ID),
		defender.state.recovery.inner_force.current,
		defender_armor.armor_vs_force,
	)
	return CombatAttackInput.new(attacker_snapshot, defender_snapshot, selected_action)


static func build_progression_facts(
	binding: CombatSliceCharacterBinding,
) -> CombatProgressionFacts:
	if binding == null or not binding.is_valid():
		return null
	var primary: EquippedWeaponRef = binding.state.equipment.primary_weapon()
	var attack_skill_id: StringName = (
		primary.skill_type if primary != null else UNARMED_SKILL_ID
	)
	return CombatProgressionFacts.new(
		binding.character_id,
		binding.is_user,
		binding.state.attributes.intelligence,
		binding.state.attributes.spirituality,
		attack_skill_id,
		binding.content.has_attack_skill_definition(attack_skill_id),
	)


static func build_busy_projection(
	binding: CombatSliceCharacterBinding,
) -> CombatBusyInterruptProjection:
	if binding == null or binding.busy == null:
		return null
	return CombatBusyInterruptProjection.new(
		(
			CombatBusyInterruptProjection.BusyKind.INTEGER
			if binding.busy.is_busy()
			else CombatBusyInterruptProjection.BusyKind.NOT_BUSY
		),
		CombatBusyInterruptProjection.InterruptKind.INTEGER,
	)


static func build_reverse_projection(
	attacker: CombatSliceCharacterBinding,
	defender: CombatSliceCharacterBinding,
	request: CombatRiposteRequest,
) -> CombatReverseAttackProjection:
	if (
		attacker == null
		or defender == null
		or request == null
		or request.attacker_id != attacker.character_id
		or request.victim_id != defender.character_id
	):
		return null
	var primary: EquippedWeaponRef = attacker.state.equipment.primary_weapon()
	var template_action: CombatActionDefinition = (
		attacker.content.attack_template_for(primary)
	)
	var attacker_armor: ArmorNumericModifiers = (
		attacker.armor.aggregate_numeric_modifiers()
	)
	var defender_armor: ArmorNumericModifiers = (
		defender.armor.aggregate_numeric_modifiers()
	)
	var modifier_projection: CombatReverseModifierProjection = (
		CombatReverseModifierProjection.new(
			attacker.character_id,
			defender.character_id,
			attacker_armor.unarmed if primary == null else 0,
			0,
			defender_armor.dodge,
			0,
			defender_armor.unarmed,
			0,
			attacker_armor.attack,
			defender_armor.defense,
			attacker.content.projected_apply_damage(primary),
			defender_armor.armor,
			defender_armor.armor_vs_force,
		)
	)
	return CombatReverseAttackProjection.new(
		CombatCharacterAuthority.new(attacker.character_id, attacker.state),
		CombatCharacterAuthority.new(defender.character_id, defender.state),
		build_action_selection_input(attacker),
		build_attack_input(attacker, defender, template_action),
		build_progression_facts(attacker),
		build_progression_facts(defender),
		build_busy_projection(defender),
		defender.busy if defender.busy.is_busy() else null,
		attacker.relationship,
		defender.relationship,
		modifier_projection,
	)


static func find_binding(
	participants: Array[CombatSliceCharacterBinding],
	character_id: StringName,
) -> CombatSliceCharacterBinding:
	for participant: CombatSliceCharacterBinding in participants:
		if participant != null and participant.character_id == character_id:
			return participant
	return null
