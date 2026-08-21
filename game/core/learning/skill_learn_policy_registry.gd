class_name SkillLearnPolicyRegistry
extends RefCounted

const SkillIdsType := preload("res://core/skills/skill_ids.gd")
const SkillLearnPolicyType := preload("res://core/learning/skill_learn_policy.gd")
const PolicyResultType := preload("res://core/learning/skill_learn_policy_result.gd")
const DefaultPolicyType := preload("res://core/learning/default_skill_learn_policy.gd")
const DependencyPolicyType := preload(
	"res://core/learning/dependency_unavailable_skill_learn_policy.gd"
)
const MinimumInnerForcePolicyType := preload(
	"res://core/learning/minimum_inner_force_skill_learn_policy.gd"
)
const MaximumBellicosityPolicyType := preload(
	"res://core/learning/maximum_bellicosity_skill_learn_policy.gd"
)
const ScaledBellicosityPolicyType := preload(
	"res://core/learning/scaled_bellicosity_skill_learn_policy.gd"
)
const StrengthForcePolicyType := preload(
	"res://core/learning/strength_force_skill_learn_policy.gd"
)
const ScaledMaximumManaPolicyType := preload(
	"res://core/learning/scaled_maximum_mana_skill_learn_policy.gd"
)
const MinimumRawSkillPolicyType := preload(
	"res://core/learning/minimum_raw_skill_learn_policy.gd"
)
const MinimumEffectivePolicyType := preload(
	"res://core/learning/minimum_effective_skill_learn_policy.gd"
)
const MinimumEffectiveRatioPolicyType := preload(
	"res://core/learning/minimum_effective_skill_ratio_learn_policy.gd"
)
const StrictlyGreaterEffectivePolicyType := preload(
	"res://core/learning/strictly_greater_effective_skill_learn_policy.gd"
)
const RequiredMappedPolicyType := preload(
	"res://core/learning/required_mapped_skill_learn_policy.gd"
)
const OrderedPolicyType := preload("res://core/learning/ordered_skill_learn_policy.gd")

var _policies: Dictionary[StringName, SkillLearnPolicyType] = {}


func register_policy(policy: SkillLearnPolicyType) -> void:
	_policies[policy.skill_id] = policy


func has_policy(skill_id: StringName) -> bool:
	return _policies.has(skill_id)


func policy_for(skill_id: StringName) -> SkillLearnPolicyType:
	return _policies.get(skill_id)


func registered_count() -> int:
	return _policies.size()


## Explicit registry for all 45 active daemon/skill valid_learn() overrides.
func register_active_legacy_policies() -> void:
	_policies.clear()
	_register_always_allowed()
	_register_existing_state_policies()
	_register_deferred_policies()


## Complete known active daemon/skill inventory: the 45 explicit overrides
## plus the 25 definitions that inherit std/skill.c's permissive default.
## Unknown IDs remain unregistered and are never guessed to be allowed.
func register_known_legacy_policies() -> void:
	register_active_legacy_policies()
	_register_inherited_default_policies()


func _register_inherited_default_policies() -> void:
	var skill_ids: Array[StringName] = [
		SkillIdsType.AXE,
		SkillIdsType.BLADE,
		SkillIdsType.CHANTING,
		SkillIdsType.DAGGER,
		SkillIdsType.DODGE,
		SkillIdsType.FORK,
		SkillIdsType.HAMMER,
		SkillIdsType.INSTRUMENTS,
		SkillIdsType.IRON_CLOTH,
		SkillIdsType.LITERATE,
		SkillIdsType.MAGIC,
		SkillIdsType.MOVE,
		SkillIdsType.MUSIC,
		SkillIdsType.PARRY,
		SkillIdsType.PERCEPTION,
		SkillIdsType.SPELLS,
		SkillIdsType.SPIDER_ARRAY,
		SkillIdsType.STAFF,
		SkillIdsType.STEALING,
		SkillIdsType.SWORD,
		SkillIdsType.TAO_MYSTERY,
		SkillIdsType.THROWING,
		SkillIdsType.UNARMED,
		SkillIdsType.WHIP,
		SkillIdsType.YIRONG,
	]
	for skill_id: StringName in skill_ids:
		register_policy(DefaultPolicyType.new(skill_id))


func _register_always_allowed() -> void:
	var skill_ids: Array[StringName] = [
		SkillIdsType.BOLOMIDUO,
		SkillIdsType.FONXAN_FORCE,
		SkillIdsType.FORCE,
		SkillIdsType.ICEFORCE,
		SkillIdsType.JIN_GANG,
		SkillIdsType.JUECHEN_FORCE,
		SkillIdsType.MYSTFORCE,
		SkillIdsType.PYROBAT_STEPS,
		SkillIdsType.QIDAOFORCE,
		SkillIdsType.SERPENTFORCE,
		SkillIdsType.SHORTSONG_BLADE,
		SkillIdsType.SNOWSHADE_FORCE,
		SkillIdsType.SPRING_BLADE,
	]
	for skill_id: StringName in skill_ids:
		register_policy(DefaultPolicyType.new(skill_id))


func _register_existing_state_policies() -> void:
	register_policy(MaximumBellicosityPolicyType.new(SkillIdsType.BUDDHISM, 100))
	register_policy(
		ScaledBellicosityPolicyType.new(
			SkillIdsType.CELESTIAL,
			SkillIdsType.CELESTIAL,
			50,
		)
	)
	for skill_id: StringName in [SkillIdsType.CHAOS_STEPS, SkillIdsType.FALL_STEPS, SkillIdsType.NOTRACES]:
		register_policy(MinimumInnerForcePolicyType.new(skill_id, 50))
	register_policy(MinimumInnerForcePolicyType.new(SkillIdsType.SCRATCHING, 80))
	register_policy(StrengthForcePolicyType.new(SkillIdsType.CLOUDSTAFF, 50, 10))
	register_policy(StrengthForcePolicyType.new(SkillIdsType.JINGANG_STAFF, 50, 10))
	var essence_magic_steps: Array[SkillLearnPolicyType] = []
	essence_magic_steps.append(
		MinimumEffectivePolicyType.new(
			SkillIdsType.ESSENCE_MAGIC,
			SkillIdsType.BUDDHISM,
			10,
		)
	)
	essence_magic_steps.append(
		StrictlyGreaterEffectivePolicyType.new(
			SkillIdsType.ESSENCE_MAGIC,
			SkillIdsType.BUDDHISM,
			SkillIdsType.ESSENCE_MAGIC,
		)
	)
	register_policy(OrderedPolicyType.new(SkillIdsType.ESSENCE_MAGIC, essence_magic_steps))
	register_policy(
		ScaledMaximumManaPolicyType.new(
			SkillIdsType.GOUYEE,
			SkillIdsType.GOUYEE,
			5,
		)
	)
	register_policy(
		MinimumRawSkillPolicyType.new(
			SkillIdsType.LINBO_STEPS,
			SkillIdsType.LITERATE,
			60,
		)
	)
	register_policy(
		MinimumEffectiveRatioPolicyType.new(
			SkillIdsType.LOTUSFORCE,
			SkillIdsType.BUDDHISM,
			SkillIdsType.LOTUSFORCE,
		)
	)
	register_policy(
		StrictlyGreaterEffectivePolicyType.new(
			SkillIdsType.MAGIC_ARRAY,
			SkillIdsType.TAO_MYSTERY,
			SkillIdsType.MAGIC_ARRAY,
		)
	)
	var mysterrier_steps: Array[SkillLearnPolicyType] = []
	mysterrier_steps.append(
		RequiredMappedPolicyType.new(
			SkillIdsType.MYSTERRIER,
			SkillIdsType.FORCE,
			SkillIdsType.MYSTFORCE,
		)
	)
	mysterrier_steps.append(
		MinimumEffectiveRatioPolicyType.new(
			SkillIdsType.MYSTERRIER,
			SkillIdsType.MUSIC,
			SkillIdsType.MYSTERRIER,
			2,
		)
	)
	register_policy(OrderedPolicyType.new(SkillIdsType.MYSTERRIER, mysterrier_steps))
	register_policy(
		MinimumEffectiveRatioPolicyType.new(
			SkillIdsType.NECROMANCY,
			SkillIdsType.TAOISM,
			SkillIdsType.NECROMANCY,
			2,
		)
	)
	register_policy(MaximumBellicosityPolicyType.new(SkillIdsType.TAOISM, 100))
	register_policy(
		MinimumEffectiveRatioPolicyType.new(
			SkillIdsType.WU_SHUN,
			SkillIdsType.LITERATE,
			SkillIdsType.WU_SHUN,
		)
	)


func _register_deferred_policies() -> void:
	var equipment_skill_ids: Array[StringName] = [
		SkillIdsType.BLOODY_STRIKE,
		SkillIdsType.CELESTRIKE,
		SkillIdsType.DEISWORD,
		SkillIdsType.FONXAN_SWORD,
		SkillIdsType.LIUH_KEN,
		SkillIdsType.MEIHUA_SHOU,
		SkillIdsType.MYSTSWORD,
		SkillIdsType.SIX_CHAOS_SWORD,
		SkillIdsType.SNOWSHADE_SWORD,
		SkillIdsType.SNOWWHIP,
		SkillIdsType.SPICYCLAW,
		SkillIdsType.TENDERZHI,
		SkillIdsType.TS_FIST,
	]
	for skill_id: StringName in equipment_skill_ids:
		register_policy(
			DependencyPolicyType.new(
				skill_id,
				PolicyResultType.Reason.EQUIPMENT_STATE_UNAVAILABLE,
			)
		)
	register_policy(
		DependencyPolicyType.new(
			SkillIdsType.STORMDANCE,
			PolicyResultType.Reason.GENDER_STATE_UNAVAILABLE,
		)
	)
	register_policy(
		DependencyPolicyType.new(
			SkillIdsType.NINE_MOON,
			PolicyResultType.Reason.LEGACY_REQUIRED_SKILL_MISSING,
		)
	)
