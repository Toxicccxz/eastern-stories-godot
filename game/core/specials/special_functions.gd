class_name SpecialFunctions
extends RefCounted

## The perform and spell files the game has, by name. A martial skill's
## perform_action_file() and a spells skill's cast_spell_file() reach those
## skills.json lists under `perform` and `cast`; exert files are ExertFunctions.
const PERFORMS: Array[StringName] = [&"counterattack", &"swordjab", &"fakefault"]
const CASTS: Array[StringName] = [&"drainerbolt", &"feeblebolt", &"netherbolt", &"invocation", &"dun", &"saveme"]

static var _performs: Dictionary[StringName, PerformFunction] = {}
static var _casts: Dictionary[StringName, CastFunction] = {}


static func perform(function_id: StringName) -> PerformFunction:
	if _performs.is_empty():
		for function: PerformFunction in [CounterattackPerform.new(), SwordjabPerform.new(), FakefaultPerform.new()]:
			_performs[function.id] = function
	return _performs.get(function_id)


## The perform file whose timed apply `effect_id` is (its remove_effect()), or null.
static func ending(effect_id: StringName) -> PerformFunction:
	if effect_id.is_empty():
		return null
	for function_id: StringName in PERFORMS:
		var function: PerformFunction = perform(function_id)
		if function != null and function.effect_id == effect_id:
			return function
	return null


static func cast(function_id: StringName) -> CastFunction:
	if _casts.is_empty():
		var drainer := BoltSpell.new(&"drainerbolt", BoltSpell.Track.GIN)
		drainer.label = "紫光"
		drainer.sen_cost = 20
		drainer.flash = "$N口中喃喃地念著咒文，左手一挥，手中聚起一团紫光射向$n！"
		drainer.flash_color = ColoredLine.HIM
		drainer.hit = "结果「嗤」地一声，紫光从$p身上透体而过，拖出一条长长的七彩光气，光气绕了回转过来又从$N顶门注入$P的体内！"
		drainer.miss = "结果「嗤」地一声，紫光从$p身上透体而过，无声无息地钻入地下！"
		var feeble := BoltSpell.new(&"feeblebolt", BoltSpell.Track.SEN)
		feeble.label = "白光"
		feeble.sen_cost = 10
		feeble.flash = "$N口中喃喃地念著咒文，左手一挥，手中聚起一团白光射向$n！"
		feeble.flash_color = ColoredLine.HIW
		feeble.hit = "结果「嗤」地一声，白光从$p身上透体而过，拖出一条长长的黑气直射到两三丈外的地下！"
		feeble.miss = "结果「嗤」地一声，白光从$p身上透体而过，无声无息地钻入地下！"
		var nether := BoltSpell.new(&"netherbolt", BoltSpell.Track.KEE)
		nether.label = "青光"
		nether.sen_cost = 10
		nether.mana_divisor = 10
		nether.fail_line = "你失败了！"
		nether.flash = "$N口中喃喃地念著咒文，左手一挥，手中聚起一团青光射向$n！"
		nether.flash_color = ColoredLine.HIC
		nether.hit = "结果「嗤」地一声，青光从$p身上透体而过，拖出一条长长的血箭直射到两三丈外的地下！"
		nether.miss = "结果「嗤」地一声，青光从$p身上透体而过，无声无息地钻入地下！"
		for spell: CastFunction in [drainer, feeble, nether, InvocationSpell.new(), DunSpell.new(), SavemeSpell.new()]:
			_casts[spell.id] = spell
	return _casts.get(function_id)
