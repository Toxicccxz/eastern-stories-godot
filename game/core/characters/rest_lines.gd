class_name RestLines
extends RefCounted

## What the player is told about 歇到回满 (RestRules; DECISIONS「歇到回满」).

# TRANSLATORS: the button on the 请教 and 武学 pages that lets time pass until 精, 气 and 神 are full (DECISIONS「歇到回满」).
const BUTTON: String = "歇到回满"
# TRANSLATORS: the hover of 歇到回满: what it does.
const HINT: String = "找个地方坐下歇着，让时间走起来：精、气、神慢慢回满就起身。世界照常运转，有人来袭会把你惊起。"
# TRANSLATORS: said as the player sits down to rest.
const BEGIN: String = "你找个地方坐下，歇一歇。"
# TRANSLATORS: the rest's band over the world while it goes on: {time} how long so far (一盏茶的工夫, 半个时辰 …).
const UNDER_WAY: String = "歇息中……已歇{time}"
# TRANSLATORS: the rest's button that stops it.
const STOP: String = "起身"
# TRANSLATORS: no rest begins in a fight.
const REFUSE_FIGHTING: String = "正在打斗，歇不下来。"
# TRANSLATORS: no rest begins: 精, 气 and 神 are full.
const REFUSE_RESTED: String = "你精神饱满，用不着歇。"
# TRANSLATORS: no rest begins: with no water nothing comes back (damage.c heal_up()).
const REFUSE_THIRSTY: String = "你口干舌燥，歇着也回不过精神来：先找水喝。"
# TRANSLATORS: no rest begins now (a scene holds the player, a map is changing).
const REFUSE_BUSY: String = "现在歇不下来。"
# TRANSLATORS: the rest is over, 精, 气 and 神 full: {time} how long it took (一盏茶的工夫, 半个时辰, 两个时辰 …).
const RESTED: String = "你歇了{time}，精、气、神都回满了。"
# TRANSLATORS: the rest reached its longest: {time} how long it took.
const LIMIT: String = "你歇了{time}，起身活动活动。精、气、神还没全回满：伤要慢慢养，金疮药和运功疗伤快得多。"
# TRANSLATORS: the player stopped the rest: {time} how long it took.
const CANCELLED: String = "你歇了{time}，站了起来。"
# TRANSLATORS: a fight began or a gang noticed the player while they rested: {time} how long they rested.
const ATTACKED: String = "你歇了{time}，忽然有人来袭，你一跃而起！"
# TRANSLATORS: one of 精, 气, 神 went down while the player rested (a hazard, poison): {time} how long they rested.
const HURT: String = "你歇了{time}，身上一阵难受，歇不下去了。"
# TRANSLATORS: the player's water ran out while they rested: {time} how long they rested.
const THIRSTY: String = "你歇了{time}，口干舌燥，再歇也回不过来：先找水喝。"
# TRANSLATORS: a scene began while the player rested: {time} how long they rested.
const SCENE: String = "你歇了{time}，听见动静，站了起来。"
# TRANSLATORS: the player was taken elsewhere while resting: {time} how long they rested.
const MOVED: String = "你歇了{time}。"


## Why no rest begins (RestRules.refusal()), in the shown language; "" for NONE.
static func refusal(outcome: RestRules.Outcome) -> String:
	match outcome:
		RestRules.Outcome.FIGHTING:
			return TranslationServer.translate(REFUSE_FIGHTING)
		RestRules.Outcome.RESTED:
			return TranslationServer.translate(REFUSE_RESTED)
		RestRules.Outcome.THIRSTY:
			return TranslationServer.translate(REFUSE_THIRSTY)
		RestRules.Outcome.NONE:
			return ""
	return TranslationServer.translate(REFUSE_BUSY)


## How a rest of `minutes` game minutes ended; "" when nothing is said (a fall says its own).
static func ended(outcome: RestRules.Outcome, minutes: int) -> String:
	var text: String = ""
	match outcome:
		RestRules.Outcome.RESTED:
			text = RESTED
		RestRules.Outcome.LIMIT:
			text = LIMIT
		RestRules.Outcome.CANCELLED:
			text = CANCELLED
		RestRules.Outcome.ATTACKED:
			text = ATTACKED
		RestRules.Outcome.HURT:
			text = HURT
		RestRules.Outcome.THIRSTY:
			text = THIRSTY
		RestRules.Outcome.SCENE:
			text = SCENE
		RestRules.Outcome.MOVED:
			text = MOVED
	if text.is_empty():
		return ""
	return TranslationServer.translate(text).format({"time": duration(minutes)})


## So far: the band's line.
static func under_way(minutes: int) -> String:
	return TranslationServer.translate(UNDER_WAY).format({"time": duration(minutes)})


## A rest's length as one would say it: by the half 时辰, or 一盏茶的工夫 under it.
static func duration(minutes: int) -> String:
	return CoachLines.duration_text(minutes)
