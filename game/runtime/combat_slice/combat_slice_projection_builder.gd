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
		primary_set = attacker.content.weapon_action_set()
	return CombatActionSelectionInput.new(
		not mapped_skill_id.is_empty(),
		attacker.content.mapped_action_set(mapped_skill_id),
		primary != null,
		primary_set,
		attacker.content.unarmed_action_set(),
	)


static func build_attack_input(
	attacker: CombatSliceCharacterBinding,
	defender: CombatSliceCharacterBinding,
	selected_action: CombatActionDefinition,
) -> CombatAttackInput:
	if (
		attacker == null or defender == null or selected_action == null
		or not attacker.is_valid() or not defender.is_valid()
		or attacker.content.action_readiness(attacker.state.equipment.primary_weapon(), selected_action)
		!= CombatSliceContentProfile.Readiness.READY
	):
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
	var attack_skill_modifier: int = _apply(attacker, attacker_armor, attack_skill_id)
	var mapped_attack_id: StringName = attacker.state.skills.mapped_skill(
		attack_skill_id
	)
	var approved_actions: CombatActionSet = attacker.content.approved_action_set(primary, attack_skill_id, mapped_attack_id)
	if approved_actions != null and not approved_actions.contains_exact(selected_action):
		return null
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
		_apply(attacker, attacker_armor, &"attack"),
		attacker.content.projected_apply_damage(primary) + attacker.state.timed_applies.value(&"damage") + _secondary_apply(attacker, &"damage"),
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
			else _force_hit_policy(mapped_force_id)
		),
		mapped_attack_id,
		(
			CombatHitPolicyStatus.Value.NOT_APPLICABLE
			if mapped_attack_id.is_empty()
			else _martial_hit_policy(mapped_attack_id, approved_actions)
		),
		(
			CombatHitPolicyStatus.Value.NOT_APPLICABLE
			if primary != null
			else CombatHitPolicyStatus.Value.CONDITION_ON_HIT
			if attacker.content.hit_condition() != null
			else CombatHitPolicyStatus.Value.PROVEN_NO_AUTHORED_EFFECT
		),
		weapon_profile,
		FORCE_SKILL_ID,
		attacker.state.skills.effective_level(FORCE_SKILL_ID, _apply(attacker, attacker_armor, FORCE_SKILL_ID)),
		attacker.content.hit_condition() if primary == null else null,
	)
	var defender_snapshot: CombatDefenderSnapshot = CombatDefenderSnapshot.new(
		defender.character_id,
		defender.life_status == CombatSliceLifeStatus.Value.ACTIVE,
		defender.busy.is_busy(),
		defender.state.progression.combat_experience,
		defender.state.spirit.current,
		defender.state.spirit.maximum,
		defender.state.skills.effective_level(DODGE_SKILL_ID, _apply(defender, defender_armor, DODGE_SKILL_ID)),
		defender.state.skills.effective_level(PARRY_SKILL_ID, _apply(defender, defender_armor, PARRY_SKILL_ID)),
		defender.state.skills.effective_level(UNARMED_SKILL_ID, _apply(defender, defender_armor, UNARMED_SKILL_ID)),
		_apply(defender, defender_armor, &"defense"),
		_apply(defender, defender_armor, &"armor"),
		not defender.state.equipment.is_primary_hand_empty(),
		defender.content.limbs(),
		FORCE_SKILL_ID,
		defender.state.skills.effective_level(FORCE_SKILL_ID, _apply(defender, defender_armor, FORCE_SKILL_ID)),
		defender.state.recovery.inner_force.current,
		_apply(defender, defender_armor, &"armor_vs_force"),
	)
	return CombatAttackInput.new(attacker_snapshot, defender_snapshot, selected_action, approved_actions)


static func build_progression_facts(
	binding: CombatSliceCharacterBinding,
) -> CombatProgressionFacts:
	if binding == null or not binding.is_valid():
		return null
	var primary: EquippedWeaponRef = binding.state.equipment.primary_weapon()
	var attack_skill_id: StringName = (
		primary.skill_type if primary != null else UNARMED_SKILL_ID
	)
	# The player's exp knob (pacing.json); NPCs grow at ES2's pace.
	return CombatProgressionFacts.new(
		binding.character_id,
		binding.is_user,
		binding.state.attributes.intelligence,
		binding.state.attributes.spirituality,
		attack_skill_id,
		binding.content.has_attack_skill_definition(attack_skill_id),
		GameContent.catalog().pacing().player_exp_gain if binding.is_user else 1,
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
		or not attacker.is_valid()
		or not defender.is_valid()
		or request == null
		or request.attacker_id != attacker.character_id
		or request.victim_id != defender.character_id
	):
		return null
	return build_live_projection(attacker, defender)


static func build_live_projection(attacker: CombatSliceCharacterBinding, defender: CombatSliceCharacterBinding) -> CombatReverseAttackProjection:
	if attacker == null or defender == null or not attacker.is_valid() or not defender.is_valid():
		return null
	var primary: EquippedWeaponRef = attacker.state.equipment.primary_weapon()
	var template_action: CombatActionDefinition = (
		template_action_for(attacker)
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
			_apply(attacker, attacker_armor, primary.skill_type if primary != null else UNARMED_SKILL_ID),
			_apply(attacker, attacker_armor, FORCE_SKILL_ID),
			_apply(defender, defender_armor, DODGE_SKILL_ID),
			_apply(defender, defender_armor, PARRY_SKILL_ID),
			_apply(defender, defender_armor, UNARMED_SKILL_ID),
			_apply(defender, defender_armor, FORCE_SKILL_ID),
			_apply(attacker, attacker_armor, &"attack"),
			_apply(defender, defender_armor, &"defense"),
			attacker.content.projected_apply_damage(primary) + attacker.state.timed_applies.value(&"damage") + _secondary_apply(attacker, &"damage"),
			_apply(defender, defender_armor, &"armor"),
			_apply(defender, defender_armor, &"armor_vs_force"),
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


## query_temp("apply/<key>"): what the character's armor gives (equip.c wear()),
## what its wielded weapon and its own create() set (CombatSliceContentProfile) and
## what a special adds for a while (CharacterTimedApplies: powerup).
static func _apply(binding: CombatSliceCharacterBinding, armor: ArmorNumericModifiers, key: StringName) -> int:
	return (
		armor.value(key) + binding.content.apply_value(key, binding.state.equipment.primary_weapon())
		+ binding.state.timed_applies.value(key) + _secondary_apply(binding, key)
	)


## equip.c wield() adds every wielded weapon's weapon_prop to apply/*, the secondary
## hand's too (damage included); only the primary attacks (combatd.c query_temp("weapon")).
static func _secondary_apply(binding: CombatSliceCharacterBinding, key: StringName) -> int:
	var secondary: EquippedWeaponRef = binding.state.equipment.secondary_weapon()
	var content: ItemContentDefinition = null if secondary == null else GameContent.catalog().item(secondary.weapon_id)
	if content == null:
		return 0
	return content.weapon_damage if key == &"damage" else content.weapon_apply.get(key, 0)


## query_temp("apply/<key>") for a participant (special files' query_skill()).
static func apply_of(binding: CombatSliceCharacterBinding, key: StringName) -> int:
	return _apply(binding, binding.armor.aggregate_numeric_modifiers(), key)


## A mapped force skill that inherits std/force.c's hit_ob() (skills.json
## standard_force_hit) takes combatd.c's force hit; any other is not ported.
static func _force_hit_policy(mapped_force_id: StringName) -> CombatHitPolicyStatus.Value:
	var skill: SkillDefinition = GameContent.catalog().skill(mapped_force_id)
	if skill != null and skill.standard_force_hit:
		return CombatHitPolicyStatus.Value.STANDARD_FORCE
	return CombatHitPolicyStatus.Value.AUTHORED_POLICY_UNAVAILABLE


## combatd.c calls the mapped martial art's hit_ob(): proven absent for a skill whose
## moves are data and that does not define one (skills.json `hit_ob`).
static func _martial_hit_policy(mapped_attack_id: StringName, approved_actions: CombatActionSet) -> CombatHitPolicyStatus.Value:
	var skill: SkillDefinition = GameContent.catalog().skill(mapped_attack_id)
	if approved_actions != null and skill != null and not skill.has_own_hit_ob:
		return CombatHitPolicyStatus.Value.PROVEN_NO_AUTHORED_EFFECT
	return CombatHitPolicyStatus.Value.AUTHORED_POLICY_UNAVAILABLE


static func find_binding(
	participants: Array[CombatSliceCharacterBinding],
	character_id: StringName,
) -> CombatSliceCharacterBinding:
	for participant: CombatSliceCharacterBinding in participants:
		if participant != null and participant.character_id == character_id:
			return participant
	return null


static func template_action_for(attacker: CombatSliceCharacterBinding) -> CombatActionDefinition:
	var primary: EquippedWeaponRef = attacker.state.equipment.primary_weapon()
	var skill_id: StringName = primary.skill_type if primary != null else UNARMED_SKILL_ID
	var approved: CombatActionSet = attacker.content.approved_action_set(primary, skill_id, attacker.state.skills.mapped_skill(skill_id))
	# A source-membership witness only. The actual action is selected once later.
	return approved.action_at(0) if approved != null else attacker.content.attack_template_for(primary)
