class_name TeachingContext
extends RefCounted

const TeachingOfferType := preload("res://core/learning/teaching_offer.gd")
const RecognitionPolicyType := preload(
	"res://core/learning/teacher_recognition_policy.gd"
)
const PreventionPolicyType := preload(
	"res://core/learning/teacher_prevention_policy.gd"
)

## Attempt-local dynamic teacher projection. It intentionally exposes no
## CharacterSkillState, Node, world object, or generic payload.
var teacher_id: StringName
var legacy_display_name: String
var teacher_family_id: StringName
var teacher_generation: int
var legacy_family_privileges: int
var base_intelligence: int
var current_spirit: int
var teacher_raw_level: int
var offer: TeachingOfferType
var teacher_is_available: bool
var teacher_is_character: bool
var teacher_is_awake: bool
var teacher_pays_spirit_cost: bool
var teacher_is_spouse: bool
var teaching_temporarily_disabled: bool
var student_is_fighting: bool
var deterministic_improvement_roll: int
var recognition_policy: RecognitionPolicyType
var prevention_policy: PreventionPolicyType


func _init(
	p_teacher_id: StringName = &"",
	p_offer: TeachingOfferType = null,
	p_teacher_raw_level: int = 0,
	p_base_intelligence: int = 0,
	p_current_spirit: int = 0,
	p_teacher_family_id: StringName = &"",
	p_teacher_generation: int = 0,
	p_legacy_family_privileges: int = 0,
	p_legacy_display_name: String = "",
	p_teacher_is_available: bool = true,
	p_teacher_is_character: bool = true,
	p_teacher_is_awake: bool = true,
	p_teacher_pays_spirit_cost: bool = false,
	p_teacher_is_spouse: bool = false,
	p_teaching_temporarily_disabled: bool = false,
	p_student_is_fighting: bool = false,
	p_deterministic_improvement_roll: int = 0,
	p_recognition_policy: RecognitionPolicyType = null,
	p_prevention_policy: PreventionPolicyType = null,
) -> void:
	teacher_id = p_teacher_id
	offer = (
		TeachingOfferType.new(p_offer.skill_id)
		if p_offer != null
		else TeachingOfferType.new()
	)
	teacher_raw_level = p_teacher_raw_level
	base_intelligence = p_base_intelligence
	current_spirit = p_current_spirit
	teacher_family_id = p_teacher_family_id
	teacher_generation = p_teacher_generation
	legacy_family_privileges = p_legacy_family_privileges
	legacy_display_name = p_legacy_display_name
	teacher_is_available = p_teacher_is_available
	teacher_is_character = p_teacher_is_character
	teacher_is_awake = p_teacher_is_awake
	teacher_pays_spirit_cost = p_teacher_pays_spirit_cost
	teacher_is_spouse = p_teacher_is_spouse
	teaching_temporarily_disabled = p_teaching_temporarily_disabled
	student_is_fighting = p_student_is_fighting
	deterministic_improvement_roll = p_deterministic_improvement_roll
	recognition_policy = (
		p_recognition_policy
		if p_recognition_policy != null
		else RecognitionPolicyType.new()
	)
	prevention_policy = (
		p_prevention_policy
		if p_prevention_policy != null
		else PreventionPolicyType.new()
	)
