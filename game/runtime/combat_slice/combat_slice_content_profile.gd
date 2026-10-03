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
var _weapon_action_set: CombatActionSet
var _unarmed_action: CombatActionDefinition
var _unarmed_action_set: CombatActionSet
var _verified_weapon_id: StringName
var _verified_weapon_skill_id: StringName
var _verified_weapon_damage: int
var _race_id: StringName
var _beast_facts: NpcAuthoredCombatFacts
## The NPC's own set_temp("apply/...") values, for any race.
var _authored: NpcAuthoredCombatFacts
## The verified weapon's weapon_prop values other than damage.
var _weapon_apply: Dictionary[StringName, int] = {}

var target_visible: bool:
	get:
		return true


func _init(
	p_verified_weapon_id: StringName = LONG_SWORD_ID,
	p_verified_weapon_skill_id: StringName = LONG_SWORD_SKILL_ID,
	p_verified_weapon_damage: int = LONG_SWORD_DAMAGE,
	p_race_id: StringName = &"human",
	p_authored_facts: NpcAuthoredCombatFacts = null,
) -> void:
	_race_id = p_race_id
	_authored = p_authored_facts.duplicate_snapshot() if p_authored_facts != null else null
	_beast_facts = _authored if p_race_id == &"beast" else null
	_verified_weapon_id = p_verified_weapon_id
	_verified_weapon_skill_id = p_verified_weapon_skill_id
	_verified_weapon_damage = p_verified_weapon_damage
	_limbs.assign([
		&"头部", &"颈部", &"胸口", &"後心",
		&"左肩", &"右肩", &"左臂", &"右臂",
		&"左手", &"右手", &"腰间", &"小腹",
		&"左腿", &"右腿", &"左脚", &"右脚",
	])
	var weapon_content: ItemContentDefinition = GameContent.catalog().item(_verified_weapon_id)
	if weapon_content != null:
		_weapon_apply = weapon_content.weapon_apply
	var tables: CombatActionTables = GameContent.catalog().combat_actions()
	# feature/attack.c reset_action(): the weapon's verbs (weapond.c), else the
	# race's own moves (default_actions).
	_weapon_action_set = tables.weapon_action_set(_verified_weapon_skill_id)
	var race_actions: CombatActionSet = tables.race_action_set(&"human")
	_unarmed_action_set = race_actions if race_actions != null else CombatActionSet.new()
	_unarmed_action = _unarmed_action_set.action_at(0)
	if _race_id != &"human":
		# Never leave human limbs/punch behind when Beast data is absent/unsupported.
		_limbs.clear()
		_unarmed_action = null
		_unarmed_action_set = CombatActionSet.new()
		if _beast_facts != null:
			for limb: String in _beast_facts.limbs():
				_limbs.append(StringName(limb))
			# beast.c query_action(): combat_action[verbs[random(sizeof(verbs))]].
			var verb_actions: Array[CombatActionDefinition] = []
			for verb: StringName in _beast_facts.verbs():
				verb_actions.append(BeastCombatActionDefinitions.action(verb))
			if not verb_actions.is_empty() and not verb_actions.has(null):
				_unarmed_action = verb_actions[0]
				_unarmed_action_set = CombatActionSet.new(verb_actions)


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
		var seen: Dictionary[StringName, bool] = {}
		for verb: StringName in verbs:
			if BeastCombatActionDefinitions.action(verb) == null:
				return Readiness.UNSUPPORTED_VERB
			if seen.has(verb):
				# A repeated verb weights the draw; not modelled yet.
				return Readiness.UNSUPPORTED_VERB_DISTRIBUTION
			seen[verb] = true
		if _unarmed_action_set.size() != verbs.size():
			return Readiness.INVALID_ACTION_DATA
		for index: int in range(verbs.size()):
			if not _same_action(_unarmed_action_set.action_at(index), BeastCombatActionDefinitions.action(verbs[index])):
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
		and _weapon_action_set.is_valid()
		and _unarmed_action_set.is_valid()
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
	if _race_id == &"beast" and not (
		_unarmed_action_set.contains_exact(action) if weapon == null
		else _same_action(action, attack_template_for(weapon))
	):
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


## The verified weapon's first verb (a sword's slash).
func weapon_action() -> CombatActionDefinition:
	return _weapon_action_set.action_at(0)


## The verified weapon's verbs (weapond.c query_action draws one).
func weapon_action_set() -> CombatActionSet:
	return CombatActionSet.new(_weapon_action_set.actions())


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
	return apply_value(&"damage", weapon) + (_verified_weapon_damage if is_verified_primary(weapon) else 0)


## query_temp("apply/<key>") without armor (ArmorNumericModifiers has those): what
## the NPC set on itself plus the wielded weapon's weapon_prop (equip.c wield()).
func apply_value(key: StringName, weapon: EquippedWeaponRef) -> int:
	var value: int = _authored.apply_value(key) if _authored != null else 0
	if is_verified_primary(weapon):
		value += _weapon_apply.get(key, 0)
	return value


func attack_template_for(weapon: EquippedWeaponRef) -> CombatActionDefinition:
	return weapon_action() if weapon != null else unarmed_action()


func has_attack_skill_definition(skill_id: StringName) -> bool:
	return (
		skill_id == &"unarmed"
		or (
			not _verified_weapon_skill_id.is_empty()
			and skill_id == _verified_weapon_skill_id
		)
	)


## feature/attack.c reset_action(): the actions an attack draws from — a mapped
## martial art's moves, else the verified weapon's verbs, else the race's own
## moves (a beast's verbs, beast.c query_action). Null when there is no data for
## the source (an unverified weapon keeps its single-template comparison).
func approved_action_set(weapon: EquippedWeaponRef, attack_skill_id: StringName, mapped_skill_id: StringName) -> CombatActionSet:
	if not mapped_skill_id.is_empty():
		return mapped_action_set(mapped_skill_id)
	if not is_valid():
		return null
	if weapon != null:
		return weapon_action_set() if is_verified_primary(weapon) else null
	return unarmed_action_set()


## SKILL_D(mapped)->query_action(): the mapped skill's moves (skills.json); null
## when the skill has none in data, which the fight cannot use.
func mapped_action_set(mapped_skill_id: StringName) -> CombatActionSet:
	if not is_valid() or mapped_skill_id.is_empty():
		return null
	var skill: SkillDefinition = GameContent.catalog().skill(mapped_skill_id)
	return null if skill == null else skill.action_set()
