class_name SpecialContext
extends RefCounted

## What a perform, cast or exert file (daemon/class/<class>/<skill>/<name>.c) works
## with when it runs for `me`: query_enemy() as the fight has it now (the enemies
## still there, in order), MudOS random(n) (`random`, n <= 0 gives 0 without a draw),
## the content and the skill_improved() effects. The file writes the lines
## message_vision() shows into `lines`, or sets the notify_fail() line only its
## performer reads and returns false. `damaged` lists whom it hurt: their
## last_damage_from is `me`. `target` is the one the command named (perform
## <action> <target>), null for none; the do_attack() calls it makes run through
## `attack_source` and are kept in `attacks`, in order with the lines.
var me: SpecialSide
var target: SpecialSide
var attack_source: SpecialAttackSource
var attacks: Array[SpecialAttack] = []
var enemies: Array[SpecialSide] = []
## Everyone else in the fight, enemies or not (remove_all_enemy() asks them all).
var others: Array[SpecialSide] = []
var random: Callable
var catalog: ContentCatalog
var effects: SkillImprovementEffectRegistry
var lines: Array[VisionLine] = []
var fail_line: VisionLine
var damaged: Array[StringName] = []
## NPC definitions the file called into the room on `me`'s side, in order (saveme.c's
## new("/obj/npc/heaven_soldier")): the fight brings each in.
var summons: Array[StringName] = []
## The room the file moved `me` to (dun.c's me->move("/d/snow/temple")), or empty: the
## fight lets `me` go and the world takes them there.
var departure: StringName
## The corpse the cast names (cast animate on corpse), or null.
var corpse: CorpseState
## The file raised `corpse` (corpse.c animate()): the world makes it the raised NPC.
var raised: bool = false
## The file woke `target` (heart_sense.c target->revive()): the world wakes them.
var revived: bool = false
## The file knocked `me` out (heart_sense.c me->unconcious()): the world lets them fall.
var fainted: bool = false
## The file moved `me` to `target`'s room (drift_sense.c me->move(environment(ob))).
var drifted: bool = false
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


## The perform files' `if( !target ) target = offensive_target(me);`.
func target_or_offensive() -> SpecialSide:
	return target if target != null else offensive_target()


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


## write(template): only `me` reads it, so it is shown only when `me` is the player.
func write(template: String, color: StringName = ColoredLine.PLAIN) -> void:
	if me.is_user:
		lines.append(VisionLine.new(template, me.character_id, &"", color))


## combatd.c do_attack(attacker, victim, attacker's weapon), after the lines said so
## far; null (nothing happens) without an attack source.
func do_attack(attacker: SpecialSide, victim: SpecialSide) -> SpecialAttack:
	if attack_source == null or attacker == null or victim == null:
		return null
	var attack: SpecialAttack = attack_source.attack(attacker.character_id, victim.character_id)
	if attack != null:
		attack.line_index = lines.size()
		attacks.append(attack)
	return attack


## combatd.c fight(attacker, victim) (hasten.c): the courage draw, then an attack or a
## guard line, after the lines said so far; null when nothing happened.
func fight(attacker: SpecialSide, victim: SpecialSide) -> SpecialAttack:
	if attack_source == null or attacker == null or victim == null:
		return null
	var attack: SpecialAttack = attack_source.fight(attacker.character_id, victim.character_id)
	if attack != null:
		attack.line_index = lines.size()
		attacks.append(attack)
	return attack


## feature/attack.c clean_up_enemy() and select_opponent() for `me` as the fight
## stands now; without an attack source, from `enemies` as the file started.
func select_opponent() -> SpecialSide:
	if attack_source != null:
		var chosen: StringName = attack_source.select_opponent(me.character_id, random)
		return null if chosen.is_empty() else other(chosen)
	if enemies.is_empty():
		return null
	var which: int = random.call(4)
	return enemies[which] if which >= 0 and which < enemies.size() else enemies[0]


## What the file showed and did: its lines and attacks, or its refusal alone.
func report() -> SpecialReport:
	var shown: Array[VisionLine] = lines
	if lines.is_empty() and attacks.is_empty() and fail_line != null:
		shown = [fail_line]
	return SpecialReport.new(me.character_id, shown, attacks, damaged)


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
