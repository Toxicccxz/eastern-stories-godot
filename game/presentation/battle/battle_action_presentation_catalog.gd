class_name BattleActionPresentationCatalog
extends Resource

## Labels are presentation only. Metadata never registers or enables an action.
@export var action_ids: Array[StringName] = []
@export var labels: Array[String] = []


func label_for(action_id: StringName) -> String:
	var index: int = action_ids.find(action_id)
	if index >= 0 and index < labels.size() and not labels[index].strip_edges().is_empty():
		return labels[index]
	return String(action_id) # Honest semantic-ID fallback for a registered action.
