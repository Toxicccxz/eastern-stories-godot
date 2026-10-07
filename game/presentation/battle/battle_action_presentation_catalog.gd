class_name BattleActionPresentationCatalog
extends Resource

## Labels are presentation only. Metadata never registers or enables an action.
@export var action_ids: Array[StringName] = [CombatFleeTacticalPolicy.ACTION_ID, CombatSurrenderTacticalPolicy.ACTION_ID]
@export var labels: Array[String] = ["逃跑", "投降"]


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
