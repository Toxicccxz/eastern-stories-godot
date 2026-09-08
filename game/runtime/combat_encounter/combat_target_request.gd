class_name CombatTargetRequest
extends RefCounted

var encounter_id: StringName
var actor_id: StringName
var target_id: StringName


func _init(encounter: StringName, actor: StringName, target: StringName) -> void:
	encounter_id = encounter
	actor_id = actor
	target_id = target
