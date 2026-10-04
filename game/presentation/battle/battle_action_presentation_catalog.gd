class_name BattleActionPresentationCatalog
extends Resource

## Labels are presentation only. Metadata never registers or enables an action.
@export var action_ids: Array[StringName] = [CombatFleeTacticalPolicy.ACTION_ID]
@export var labels: Array[String] = ["逃跑"]


func label_for(action_id: StringName) -> String:
	var index: int = action_ids.find(action_id)
	if index >= 0 and index < labels.size() and not labels[index].strip_edges().is_empty():
		return tr(labels[index])
	var function_id: StringName = CombatExertTacticalPolicy.function_for(action_id)
	if ExertFunctions.LABELS.has(function_id):
		# TRANSLATORS: a battle button: exert.c with one of its functions ({function}, e.g. 恢复气).
		return tr("运功{function}").format({"function": tr(ExertFunctions.LABELS[function_id])})
	return String(action_id) # Honest semantic-ID fallback for a registered action.
