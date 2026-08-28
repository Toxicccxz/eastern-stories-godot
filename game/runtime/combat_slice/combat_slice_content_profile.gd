class_name CombatSliceContentProfile
extends RefCounted

const LONG_SWORD_ID: StringName = &"es2:d/oldpine/obj/long_sword"
const LONG_SWORD_SKILL_ID: StringName = &"sword"
const LONG_SWORD_DAMAGE: int = 25
const LONG_SWORD_WEIGHT: int = 7000
const LONG_SWORD_SOURCE: String = "d/oldpine/obj/long_sword.c"
const SLASH_ACTION_ID: StringName = &"es2:adm/daemons/weapond/slash"
const UNARMED_ACTION_ID: StringName = &"es2:adm/daemons/race/human/punch"

var _limbs: Array[StringName] = []
var _slash_action: CombatActionDefinition
var _slash_action_set: CombatActionSet
var _unarmed_action: CombatActionDefinition
var _unarmed_action_set: CombatActionSet
var _verified_weapon_id: StringName
var _verified_weapon_skill_id: StringName
var _verified_weapon_damage: int

var target_visible: bool:
	get:
		return true


func _init(
	p_verified_weapon_id: StringName = LONG_SWORD_ID,
	p_verified_weapon_skill_id: StringName = LONG_SWORD_SKILL_ID,
	p_verified_weapon_damage: int = LONG_SWORD_DAMAGE,
) -> void:
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


func is_valid() -> bool:
	return (
		_limbs.size() == 16
		and _slash_action_set.is_valid()
		and _slash_action_set.size() == 1
		and _unarmed_action_set.is_valid()
		and _unarmed_action_set.size() == 1
		and not _verified_weapon_id.is_empty()
		and not _verified_weapon_skill_id.is_empty()
		and _verified_weapon_damage >= 0
	)


func limbs() -> Array[StringName]:
	return _limbs.duplicate()


func slash_action() -> CombatActionDefinition:
	return _slash_action.duplicate_snapshot()


func slash_action_set() -> CombatActionSet:
	return CombatActionSet.new(_slash_action_set.actions())


func unarmed_action() -> CombatActionDefinition:
	return _unarmed_action.duplicate_snapshot()


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
	return _verified_weapon_damage if is_verified_primary(weapon) else 0


func attack_template_for(weapon: EquippedWeaponRef) -> CombatActionDefinition:
	return slash_action() if weapon != null else unarmed_action()


func has_attack_skill_definition(skill_id: StringName) -> bool:
	return skill_id == _verified_weapon_skill_id or skill_id == &"unarmed"
