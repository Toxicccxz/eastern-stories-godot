class_name BattlePace
extends RefCounted

## The player's 战斗速度 and 受击闪红 (DECISIONS「手感」, B2): settings, not the save. A fight
## keeps its own clock: a round is combat_round_ms of it at every speed, and so is what
## counts on it (timed applies, busy in rounds, 朱鸿雪's task time while it runs); the speed
## changes only how many real seconds that clock takes — 慢 a round in 150 % of the time,
## 快 in 60 % (pacing.json's feel; 标准 is the round itself). The application settings set
## these once loaded and on 应用.

enum Speed { SLOW, NORMAL, FAST }

const STORAGE: Dictionary[int, String] = {Speed.SLOW: "slow", Speed.NORMAL: "normal", Speed.FAST: "fast"}

static var speed: int = Speed.NORMAL
## The fighters' cards flash red when they lose 气.
static var hit_flash: bool = true


## Real time a round takes at `at`, in percent of the round (100: 标准).
static func percent(at: int = speed) -> int:
	var feel: FeelDefinition = GameContent.catalog().pacing().feel
	var value: int = 100
	if at == Speed.SLOW:
		value = feel.battle_slow_percent
	elif at == Speed.FAST:
		value = feel.battle_fast_percent
	return value if value > 0 else 100


## The fight's own time in `real_seconds` of play.
static func fight_seconds(real_seconds: float) -> float:
	return real_seconds * 100.0 / float(percent())


## Real seconds `fight_seconds` of the fight's own time take.
static func real_seconds(fight_seconds_value: float) -> float:
	return fight_seconds_value * float(percent()) / 100.0


static func from_storage(text: String) -> int:
	return STORAGE.find_key(text) if STORAGE.values().has(text) else -1


static func storage_value(at: int) -> String:
	return STORAGE.get(at, STORAGE[Speed.NORMAL])


static func is_valid(at: int) -> bool:
	return STORAGE.has(at)
