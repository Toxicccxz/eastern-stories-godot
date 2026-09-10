class_name CombatSliceContentProfile
extends RefCounted

const LONG_SWORD_ID: StringName = &"es2:d/oldpine/obj/long_sword"
const LONG_SWORD_SKILL_ID: StringName = &"sword"
const LONG_SWORD_DAMAGE: int = 25
const LONG_SWORD_WEIGHT: int = 7000
const LONG_SWORD_SOURCE: String = "d/oldpine/obj/long_sword.c"
const SLASH_ACTION_ID: StringName = &"es2:adm/daemons/weapond/slash"
const UNARMED_ACTION_ID: StringName = &"es2:adm/daemons/race/human/punch"

enum Readiness {
	READY,
	UNSUPPORTED_RACE,
	MISSING_COMBAT_FACTS,
	EMPTY_LIMBS,
	INVALID_LIMB,
	EMPTY_VERBS,
	UNSUPPORTED_VERB,
	UNSUPPORTED_VERB_DISTRIBUTION,
	INVALID_ACTION_DATA,
	INVALID_WEAPON_PROFILE,
}

var _limbs: Array[StringName] = []
var _slash_action: CombatActionDefinition
var _slash_action_set: CombatActionSet
var _unarmed_action: CombatActionDefinition
var _unarmed_action_set: CombatActionSet
var _verified_weapon_id: StringName
var _verified_weapon_skill_id: StringName
var _verified_weapon_damage: int
var _race_id: StringName
var _beast_facts: NpcAuthoredCombatFacts

var intrinsic_attack: int:
	get:
		return _beast_facts.intrinsic_attack if _beast_facts != null else 0
var intrinsic_armor: int:
	get:
		return _beast_facts.intrinsic_armor if _beast_facts != null else 0
var intrinsic_dodge: int:
	get:
		return _beast_facts.intrinsic_dodge if _beast_facts != null else 0

var target_visible: bool:
	get:
		return true


func _init(
	p_verified_weapon_id: StringName = LONG_SWORD_ID,
	p_verified_weapon_skill_id: StringName = LONG_SWORD_SKILL_ID,
	p_verified_weapon_damage: int = LONG_SWORD_DAMAGE,
	p_race_id: StringName = &"human",
	p_beast_facts: NpcAuthoredCombatFacts = null,
) -> void:
	_race_id = p_race_id
	_beast_facts = (
		p_beast_facts.duplicate_snapshot()
		if p_race_id == &"beast" and p_beast_facts != null else null
	)
	_verified_weapon_id = p_verified_weapon_id
	_verified_weapon_skill_id = p_verified_weapon_skill_id
	_verified_weapon_damage = p_verified_weapon_damage
	_limbs.assign([
		&"头部", &"颈部", &"胸口", &"後心",
		&"左肩", &"右肩", &"左臂", &"右臂",
		&"左手", &"右手", &"腰间", &"小腹",
		&"左腿", &"右腿", &"左脚", &"右脚",
	])
	_slash_action = CombatActionDefinition.new(
		SLASH_ACTION_ID,
		0,
		0,
		&"割伤",
		&"combat.weapon.slash",
		"$N挥动$w，斩向$n的$l",
		"$w",
		&"",
	)
	_slash_action_set = CombatActionSet.new([_slash_action])
	## Source-backed first entry in race/human.c's default action table. It is
	## retained only as an explicit no-primary provider, not as a full port.
	_unarmed_action = CombatActionDefinition.new(
		UNARMED_ACTION_ID,
		0,
		0,
		&"瘀伤",
		&"combat.unarmed.punch",
		"$N挥拳攻击$n的$l",
		"拳",
		&"",
	)
	_unarmed_action_set = CombatActionSet.new([_unarmed_action])
	if _race_id != &"human":
		# Never leave human limbs/punch behind when Beast data is absent/unsupported.
		_limbs.clear()
		_unarmed_action = null
		_unarmed_action_set = CombatActionSet.new()
		if _beast_facts != null:
			for limb: String in _beast_facts.limbs():
				_limbs.append(StringName(limb))
			if _beast_facts.verbs() == [&"bite"]:
				_unarmed_action = BeastCombatActionDefinitions.bite()
				_unarmed_action_set = CombatActionSet.new([_unarmed_action])


## NPC construction always resolves anatomy/intrinsics from its definition;
## the caller's existing verified weapon projection contributes weapons only.
func for_npc_definition(definition: NpcDefinition) -> CombatSliceContentProfile:
	return CombatSliceContentProfile.new(
		_verified_weapon_id, _verified_weapon_skill_id, _verified_weapon_damage,
		definition.race_id if definition != null else &"",
		definition.authored_combat_facts() if definition != null else null,
	)


func is_valid() -> bool:
	return readiness() == Readiness.READY


func readiness() -> Readiness:
	if _race_id not in [&"human", &"beast"]:
		return Readiness.UNSUPPORTED_RACE
	if _race_id == &"beast":
		if _beast_facts == null:
			return Readiness.MISSING_COMBAT_FACTS
		if _limbs.is_empty():
			return Readiness.EMPTY_LIMBS
		for limb: StringName in _limbs:
			if limb.is_empty():
				return Readiness.INVALID_LIMB
		var verbs: Array[StringName] = _beast_facts.verbs()
		if verbs.is_empty():
			return Readiness.EMPTY_VERBS
		for verb: StringName in verbs:
			if verb != &"bite":
				return Readiness.UNSUPPORTED_VERB
		if verbs.size() != 1:
			return Readiness.UNSUPPORTED_VERB_DISTRIBUTION
		if not _same_action(_unarmed_action, BeastCombatActionDefinitions.bite()):
			return Readiness.INVALID_ACTION_DATA
	var has_verified_weapon: bool = (
		not _verified_weapon_id.is_empty()
		and not _verified_weapon_skill_id.is_empty()
		and _verified_weapon_damage >= 0
	)
	var is_unarmed_only: bool = (
		_verified_weapon_id.is_empty()
		and _verified_weapon_skill_id.is_empty()
		and _verified_weapon_damage == 0
	)
	if not has_verified_weapon and not is_unarmed_only:
		return Readiness.INVALID_WEAPON_PROFILE
	if not (
		(_race_id == &"beast" or _limbs.size() == 16)
		and _slash_action_set.is_valid()
		and _slash_action_set.size() == 1
		and _unarmed_action_set.is_valid()
		and _unarmed_action_set.size() == 1
		and _same_action(_unarmed_action_set.action_at(0), _unarmed_action)
	):
		return Readiness.INVALID_ACTION_DATA
	return Readiness.READY


func action_readiness(
	weapon: EquippedWeaponRef,
	action: CombatActionDefinition,
) -> Readiness:
	var status: Readiness = readiness()
	if status != Readiness.READY:
		return status
	if _race_id == &"beast" and not _same_action(action, attack_template_for(weapon)):
		return Readiness.INVALID_ACTION_DATA
	return Readiness.READY


static func _same_action(left: CombatActionDefinition, right: CombatActionDefinition) -> bool:
	return (
		left != null and right != null and left.is_valid() and right.is_valid()
		and left.action_id == right.action_id
		and left.damage_percent == right.damage_percent
		and left.force_percent == right.force_percent
		and left.damage_type == right.damage_type
		and left.presentation_key == right.presentation_key
		and left.legacy_action_text == right.legacy_action_text
		and left.displayed_weapon_or_body_token == right.displayed_weapon_or_body_token
		and left.post_action_policy_id == right.post_action_policy_id
	)


func limbs() -> Array[StringName]:
	return _limbs.duplicate()


func slash_action() -> CombatActionDefinition:
	return _slash_action.duplicate_snapshot()


func slash_action_set() -> CombatActionSet:
	return CombatActionSet.new(_slash_action_set.actions())


func unarmed_action() -> CombatActionDefinition:
	return _unarmed_action.duplicate_snapshot() if _unarmed_action != null else null


func unarmed_action_set() -> CombatActionSet:
	return CombatActionSet.new(_unarmed_action_set.actions())


func is_verified_primary(weapon: EquippedWeaponRef) -> bool:
	return (
		weapon != null
		and weapon.is_valid()
		and weapon.weapon_id == _verified_weapon_id
		and weapon.skill_type == _verified_weapon_skill_id
	)


func projected_apply_damage(weapon: EquippedWeaponRef) -> int:
	var intrinsic_damage: int = _beast_facts.intrinsic_damage if _beast_facts != null else 0
	return intrinsic_damage + (_verified_weapon_damage if is_verified_primary(weapon) else 0)


func attack_template_for(weapon: EquippedWeaponRef) -> CombatActionDefinition:
	return slash_action() if weapon != null else unarmed_action()


func has_attack_skill_definition(skill_id: StringName) -> bool:
	return (
		skill_id == &"unarmed"
		or (
			not _verified_weapon_skill_id.is_empty()
			and skill_id == _verified_weapon_skill_id
		)
	)
