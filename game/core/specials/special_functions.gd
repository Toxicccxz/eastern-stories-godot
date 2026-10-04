class_name SpecialFunctions
extends RefCounted

## The perform and spell files the game has, by name. A martial skill's
## perform_action_file() and a spells skill's cast_spell_file() reach those
## skills.json lists under `perform` and `cast`; exert files are ExertFunctions.
const PERFORMS: Array[StringName] = [&"counterattack"]
const CASTS: Array[StringName] = [&"drainerbolt", &"feeblebolt"]

static var _performs: Dictionary[StringName, PerformFunction] = {}
static var _casts: Dictionary[StringName, CastFunction] = {}


static func perform(function_id: StringName) -> PerformFunction:
	if _performs.is_empty():
		var counterattack := CounterattackPerform.new()
		_performs[counterattack.id] = counterattack
	return _performs.get(function_id)


static func cast(function_id: StringName) -> CastFunction:
	if _casts.is_empty():
		for spell: CastFunction in [
			BoltSpell.new(&"drainerbolt", BoltSpell.Track.GIN, 20,
				"$N口中喃喃地念著咒文，左手一挥，手中聚起一团紫光射向$n！", ColoredLine.HIM,
				"结果「嗤」地一声，紫光从$p身上透体而过，拖出一条长长的七彩光气，光气绕了回转过来又从$N顶门注入$P的体内！",
				"结果「嗤」地一声，紫光从$p身上透体而过，无声无息地钻入地下！"),
			BoltSpell.new(&"feeblebolt", BoltSpell.Track.SEN, 10,
				"$N口中喃喃地念著咒文，左手一挥，手中聚起一团白光射向$n！", ColoredLine.HIW,
				"结果「嗤」地一声，白光从$p身上透体而过，拖出一条长长的黑气直射到两三丈外的地下！",
				"结果「嗤」地一声，白光从$p身上透体而过，无声无息地钻入地下！"),
		]:
			_casts[spell.id] = spell
	return _casts.get(function_id)
