class_name RoarExertFunction
extends ExertFunction

## daemon/class/fighter/celestial/roar.c (天邪虎啸), only in a fight: for 150 force
## and 10 kee the user is busy 5 and roars. Everyone else living in the room is
## struck unless skill / 2 + random(skill / 2) < its cps * 2 (skill =
## query_skill("force")): it loses skill - max_force / 10 sen when that is above 0,
## and a wound of half of it when its force is below skill * 2 (它眼前一阵金星乱冒 is
## told to it alone); then it kill_ob()s the user unless it already kills them. Who
## withstands the roar is not hurt and does not join. A player in the room would
## fight_ob(); there is none.
const COST: int = 150
const KEE_COST: int = 10
const BUSY: int = 5
const CPS_MULTIPLIER: int = 2


func _init() -> void:
	id = &"roar"
	fight_only = true


func exert(context: ExertContext) -> bool:
	if not context.is_fighting:
		context.fail_line = _t("天邪虎啸只能在战斗中使用。")
		return false
	var force: CharacterInternalResourceState = context.character.recovery.inner_force
	if force.current < COST:
		context.fail_line = _t("你的内力不够。")
		return false
	var skill: int = context.force_level
	force.current -= COST
	context.character.vitality.apply_damage(KEE_COST)
	context.busy.start_busy(BUSY)
	context.vision("$N深深地吸一口气，开始发出有如猛虎般的啸声！", ColoredLine.HIR)
	@warning_ignore("integer_division")
	var half: int = skill / 2
	for other: SpecialSide in context.room:
		if not other.living or other.character_id == context.actor_id or other.state == context.character:
			continue
		if half + context.legacy_random(half) < other.state.attributes.composure * CPS_MULTIPLIER:
			continue
		@warning_ignore("integer_division")
		var damage: int = skill - other.state.recovery.inner_force.maximum / 10
		if damage > 0:
			other.state.spirit.apply_damage(damage)
			if other.state.recovery.inner_force.current < skill * 2:
				@warning_ignore("integer_division")
				other.state.spirit.apply_wound(damage / 2)
		if not other.is_killing(context.actor_id):
			context.killers.append(other.character_id)
	return true


## Whether roar would run for `character` now (its refusals), as the question
## before it needs to know.
static func would_run(character: CharacterState, is_fighting: bool) -> bool:
	return is_fighting and character.recovery.inner_force.current >= COST
