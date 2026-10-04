class_name SpecialContext
extends RefCounted

## What a perform, cast or exert file (daemon/class/<class>/<skill>/<name>.c) works
## with when it runs for `me`: query_enemy() as the fight has it now (the enemies
## still there, in order), MudOS random(n) (`random`, n <= 0 gives 0 without a draw),
## the content and the skill_improved() effects. The file writes the lines
## message_vision() shows into `lines`, or sets the notify_fail() line only its
## performer reads and returns false. `damaged` lists whom it hurt: their
## last_damage_from is `me`.
var me: SpecialSide
var enemies: Array[SpecialSide] = []
## Everyone else in the fight, enemies or not (remove_all_enemy() asks them all).
var others: Array[SpecialSide] = []
var random: Callable
var catalog: ContentCatalog
var effects: SkillImprovementEffectRegistry
var lines: Array[VisionLine] = []
var fail_line: VisionLine
var damaged: Array[StringName] = []
## Keeps the object `random` calls alive (a Callable does not).
var _random_source: Object


func _init(p_me: SpecialSide = null, p_enemies: Array[SpecialSide] = [], p_random: Callable = Callable(),
	p_catalog: ContentCatalog = null, p_effects: SkillImprovementEffectRegistry = null, p_others: Array[SpecialSide] = [],
) -> void:
	me = p_me
	enemies = p_enemies.duplicate()
	others = p_others.duplicate()
	random = p_random
	_random_source = p_random.get_object() if p_random.is_valid() else null
	catalog = p_catalog
	effects = p_effects


## feature/attack.c is_fighting(): `me` has an enemy.
func is_fighting() -> bool:
	return me.relationship != null and me.relationship.is_fighting()


## std/sserver.c offensive_target(me): one of the first four enemies, at random.
func offensive_target() -> SpecialSide:
	var size: int = mini(enemies.size(), 4)
	if size <= 0:
		return null
	return enemies[clampi(random.call(size), 0, size - 1)]


## The one in the fight with `character_id`, or null.
func other(character_id: StringName) -> SpecialSide:
	for side: SpecialSide in others:
		if side.character_id == character_id:
			return side
	return null


## message_vision(template, me, target).
func say(template: String, target_id: StringName = &"", color: StringName = ColoredLine.PLAIN) -> VisionLine:
	var line := VisionLine.new(template, me.character_id, target_id, color)
	lines.append(line)
	return line


## notify_fail(template): what only the performer reads; the file returns 0.
func refuse(template: String, target_id: StringName = &"") -> bool:
	fail_line = VisionLine.new(template, me.character_id, target_id)
	return false


## improve_skill(skill, amount, weak_mode) for `me`, and its skill_improved() effect.
func improve(skill_id: StringName, amount: int, weak_mode: bool) -> SkillImprovementResult:
	var result: SkillImprovementResult = me.state.skills.improve_skill(
		skill_id, amount, me.state.attributes.spirituality, weak_mode, me.is_user,
	)
	if effects != null:
		effects.apply(me.state, result)
	return result
