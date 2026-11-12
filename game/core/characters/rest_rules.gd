class_name RestRules
extends RefCounted

## 歇到回满 (native; DECISIONS「歇到回满」): ES2 has no sleep or rest command; 精, 气 and 神 come
## back only on the heart beat's heal_up() (damage.c), which runs while time passes. The windows
## hold world time (DECISIONS「菜单窗口」「连续修炼」), so the game offers a rest that lets it pass:
## the world runs on as ever (pacing.json rest_world_scale times as fast), and the rest ends when
## the three are full, or something comes at the player, or rest_limit_seconds have gone by. Pure:
## it reads a CharacterState and decides nothing about time.

## Why a rest ends (or does not begin).
enum Outcome {
	NONE,
	## 精, 气 and 神 are full: current and effective at their maximum.
	RESTED,
	## The rest went on rest_limit_seconds and stopped there.
	LIMIT,
	## The player stopped it.
	CANCELLED,
	## A fight began, or a gang noticed the player (its alert beat).
	ATTACKED,
	## One of the three went down (a hazard, a poison's bout): no rest to be had.
	HURT,
	## Without water heal_up() restores nothing to the player (damage.c).
	THIRSTY,
	## A scene holds the player (DECISIONS「剧情演出」).
	SCENE,
	## The player was taken elsewhere (another map).
	MOVED,
	## The player fell (a condition's bout) or died.
	FELL,
	## In a fight: no rest begins.
	FIGHTING,
	## The rest is not offered (pacing.json rest_world_scale 0, ES2).
	OFF,
}


## The three are as full as time makes them: current at effective at maximum.
static func rested(state: CharacterState) -> bool:
	for resource: CharacterResourceState in _resources(state):
		if resource.current < resource.maximum or resource.effective < resource.maximum:
			return false
	return true


## damage.c heal_up(): a player with no water left gets nothing back.
static func can_recover(state: CharacterState) -> bool:
	return state.recovery.water > 0


## The three's current values, to tell a fall from one frame to the next.
static func currents(state: CharacterState) -> Vector3i:
	return Vector3i(state.essence.current, state.vitality.current, state.spirit.current)


## One of the three is lower than in `before` (a hazard, a bout of poison).
static func hurt_since(state: CharacterState, before: Vector3i) -> bool:
	var now: Vector3i = currents(state)
	return now.x < before.x or now.y < before.y or now.z < before.z


## Why no rest begins now, or NONE: in a fight, full already, or without water.
static func refusal(state: CharacterState, fighting: bool) -> Outcome:
	if fighting:
		return Outcome.FIGHTING
	if rested(state):
		return Outcome.RESTED
	if not can_recover(state):
		return Outcome.THIRSTY
	return Outcome.NONE


## Game minutes `world_seconds` of world time come to on a day of `day_length_minutes` real
## minutes (DayClock.advance()).
static func game_minutes(world_seconds: float, day_length_minutes: int) -> int:
	if day_length_minutes <= 0:
		return 0
	return floori(world_seconds * float(DayClock.DAY_MINUTES) / float(day_length_minutes * 60))


static func _resources(state: CharacterState) -> Array[CharacterResourceState]:
	return [state.essence, state.vitality, state.spirit]
