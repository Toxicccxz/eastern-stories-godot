class_name CombatLifecycleAnnouncement
extends RefCounted

## combatd.c announce(ob, event) for someone who fell or died in a fight (damage.c
## unconcious() and die()), ordered alongside the fight's other events for the battle
## log. Read-only once the scheduler gave it its place.
const UNCONSCIOUS: StringName = &"unconcious"
const DEAD: StringName = &"dead"

var _victim_id: StringName
var victim_id: StringName:
	get: return _victim_id
var _event: StringName
var event: StringName:
	get: return _event
var _order: int
var progression_order: int:
	get: return _order


func _init(p_victim_id: StringName, p_event: StringName, p_order: int = 0) -> void:
	_victim_id = p_victim_id
	_event = p_event
	_order = p_order


func ordered(order: int) -> CombatLifecycleAnnouncement:
	return CombatLifecycleAnnouncement.new(_victim_id, _event, order)
