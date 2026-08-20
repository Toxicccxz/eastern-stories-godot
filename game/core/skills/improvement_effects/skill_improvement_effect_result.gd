class_name SkillImprovementEffectResult
extends RefCounted

enum Status {
	NOT_LEVELED_UP,
	NO_AUTHORED_EFFECT,
	EVALUATED_NO_MUTATION,
	APPLIED,
}

enum Mutation {
	NONE,
	STRENGTH,
	INTELLIGENCE,
	SPIRITUALITY,
	COMPOSURE,
	PERSONALITY,
	CONSTITUTION,
	BELLICOSITY,
}

var skill_id: StringName
var status: int
var mutation: int
var mutation_amount: int
var previous_value: int
var current_value: int


func _init(
	p_skill_id: StringName = &"",
	p_status: int = Status.NO_AUTHORED_EFFECT,
	p_mutation: int = Mutation.NONE,
	p_mutation_amount: int = 0,
	p_previous_value: int = 0,
	p_current_value: int = 0,
) -> void:
	skill_id = p_skill_id
	status = p_status
	mutation = p_mutation
	mutation_amount = p_mutation_amount
	previous_value = p_previous_value
	current_value = p_current_value
