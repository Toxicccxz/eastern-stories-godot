class_name BattleActionPresentationCatalog
extends Resource

## Labels are presentation only. Metadata never registers or enables an action.
@export var action_ids: Array[StringName] = [CombatFleeTacticalPolicy.ACTION_ID, CombatSurrenderTacticalPolicy.ACTION_ID, CombatKillTacticalPolicy.ACTION_ID]
@export var labels: Array[String] = ["逃跑", "投降", "攻击"]


func label_for(action_id: StringName) -> String:
	var index: int = action_ids.find(action_id)
	if index >= 0 and index < labels.size() and not labels[index].strip_edges().is_empty():
		return tr(labels[index])
	var function_id: StringName = CombatExertTacticalPolicy.function_for(action_id)
	if ExertFunctions.LABELS.has(function_id):
		# TRANSLATORS: a battle button: exert.c with one of its functions ({function}, e.g. 恢复气).
		return tr("运功{function}").format({"function": tr(ExertFunctions.LABELS[function_id])})
	var perform: PerformFunction = SpecialFunctions.perform(CombatPerformTacticalPolicy.function_for(action_id))
	if perform != null:
		# TRANSLATORS: a battle button: perform.c with one of its actions ({action}, e.g. 「封」字诀).
		return tr("使出{action}").format({"action": tr(perform.label)})
	var spell: CastFunction = SpecialFunctions.cast(CombatCastTacticalPolicy.function_for(action_id))
	if spell != null:
		var name: String = spell.self_label if CombatCastTacticalPolicy.is_self(action_id) else spell.label
		# TRANSLATORS: a battle button: cast.c with one of the player's spells ({spell}, e.g. 遁 or 召天将).
		return tr("施法「{spell}」").format({"spell": tr(String(spell.id) if name.is_empty() else name)})
	return String(action_id) # Honest semantic-ID fallback for a registered action.


## What an exert or a spell does and costs, for its button's hover (owner, modern fixes
## II); "" for the others. The numbers are the files' own. 运功疗伤 has none: it is greyed
## in every fight with heal.c's own line.
func tooltip_for(action_id: StringName) -> String:
	var label: String = label_for(action_id)
	var what: String = ""
	match CombatExertTacticalPolicy.function_for(action_id):
		&"recover", &"refresh", &"regenerate":
			# TRANSLATORS: hover of 运功恢复气/神/精 (recover.c …): {force} internal power brings {track} back.
			what = tr("用 {force} 点内力恢复{track}").format({
				"force": RestoreExertFunction.COST,
				"track": tr({&"recover": "气", &"refresh": "神", &"regenerate": "精"}[CombatExertTacticalPolicy.function_for(action_id)]),
			})
		&"concentrate":
			# TRANSLATORS: hover of 运功灵神诀 (谷衣心法's concentrate.c): {force} internal power and {sen} sen bring mana back.
			what = tr("用 {force} 点内力和 {sen} 点神恢复法力").format({"force": ConcentrateExertFunction.COST, "sen": ConcentrateExertFunction.SEN_COST})
		&"powerup":
			# TRANSLATORS: hover of 运功提升战斗力 (powerup.c): {force} internal power; attack and dodge rise for a while, and bellicosity.
			what = tr("用 {force} 点内力，一段时间内攻击和闪避提升，杀气也随之上升").format({"force": PowerupExertFunction.COST})
		&"powerfade":
			# TRANSLATORS: hover of 运功压制杀气 (powerfade.c): {force} internal power and {sen} sen lower bellicosity; in a fight one may faint.
			what = tr("用 {force} 点内力和 {sen} 点神压下杀气，战斗中可能昏倒").format({"force": PowerfadeExertFunction.COST, "sen": PowerfadeExertFunction.COST})
		&"roar":
			# TRANSLATORS: hover of 运功天邪虎啸 (roar.c): {force} internal power and {kee} kee; the roar hurts everyone else in the room who cannot withstand it.
			what = tr("用 {force} 点内力和 {kee} 点气长啸，在场受不住的人都会受伤").format({"force": RoarExertFunction.COST, "kee": RoarExertFunction.KEE_COST})
		&"chillgaze":
			# TRANSLATORS: hover of 运功意寒睨 (chillgaze.c): {force} internal power and {sen} sen; the gaze hurts the target's gin, unless they look away.
			what = tr("用 {force} 点内力和 {sen} 点神以目光摄住对手，伤其精（对手可能避开）").format({"force": ChillgazeExertFunction.COST, "sen": ChillgazeExertFunction.SEN_COST})
	var spell_id: StringName = CombatCastTacticalPolicy.function_for(action_id)
	if spell_id == &"dun" and CombatCastTacticalPolicy.is_self(action_id):
		# TRANSLATORS: hover of 施法「遁」 (dun.c at oneself): out of the fight to {region}{room} (雪亭镇城隍庙); {mana} mana; it can fail.
		what = tr("脱离战斗，回到{region}{room}（{mana} 法力，可能失败）").format({
			"region": _region_of(DunSpell.DESTINATION), "room": _room_title(DunSpell.DESTINATION), "mana": DunSpell.SELF_MANA_COST,
		})
	elif spell_id == &"dun":
		# TRANSLATORS: hover of 施法「困」 (dun.c at an enemy): the enemy is held for a while; {mana} mana; it can fail.
		what = tr("困住对手，让对方一段时间无法出手（{mana} 法力，可能失败）").format({"mana": DunSpell.MANA_COST})
	elif spell_id == &"saveme":
		# TRANSLATORS: hover of 施法「召天将」 (saveme.c): a heavenly soldier comes to fight on the player's side; {mana} mana; it can fail.
		what = tr("召来一名天将相助（{mana} 法力，可能失败）").format({"mana": SavemeSpell.MANA_COST})
	elif spell_id == &"invocation":
		# TRANSLATORS: hover of 施法「召护法」 (invocation.c): a heavenly soldier or a ghost guard comes to fight on the player's side; {mana} mana and {sen} sen; it can fail.
		what = tr("召来一名天将或阴鬼卒相助（{mana} 法力、{sen} 神，可能失败）").format({"mana": InvocationSpell.MANA_COST, "sen": InvocationSpell.SEN_COST})
	elif SpecialFunctions.cast(spell_id) is BoltSpell:
		var bolt: BoltSpell = SpecialFunctions.cast(spell_id) as BoltSpell
		var hurts: String = {BoltSpell.Track.GIN: tr("吸取对方的精"), BoltSpell.Track.SEN: tr("伤对方的神"), BoltSpell.Track.KEE: tr("伤对方的气")}[bolt.track]
		# TRANSLATORS: hover of 施法「紫光」「白光」「青光」 (the bolts of 茅山道术): {hurts} what a hit does (吸取对方的精); {mana} mana and {sen} sen; it can fail.
		what = tr("{hurts}（{mana} 法力、{sen} 神，可能失败）").format({"hurts": hurts, "mana": BoltSpell.MANA_COST, "sen": bolt.sen_cost})
	if action_id == CombatKillTacticalPolicy.ACTION_ID:
		# TRANSLATORS: hover of 攻击 (kill.c) for a player standing by in a fight they are not in (their zombie's): they join it, and the one they attack kills back.
		what = tr("你也上去和对手性命相搏，对手会反过来对你下杀手")
	if what.is_empty():
		return ""
	# TRANSLATORS: a battle button's hover: {action} its label (施法「遁」), {what} what it does.
	return tr("{action}：{what}").format({"action": label, "what": what})


static func _room_title(room_id: StringName) -> String:
	var room: RoomDefinition = GameContent.catalog().room(room_id)
	return "" if room == null else TranslationServer.translate(room.short)


static func _region_of(room_id: StringName) -> String:
	var catalog: ContentCatalog = GameContent.catalog()
	var zone: ZoneDefinition = catalog.zone_of_room(room_id)
	var map: MapDefinition = null if zone == null else catalog.map(zone.map_id)
	var region: RegionDefinition = null if map == null else catalog.region(map.region_id)
	return "" if region == null else TranslationServer.translate(region.display_name)
