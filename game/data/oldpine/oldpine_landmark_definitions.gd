class_name OldPineLandmarkDefinitions
extends RefCounted

## Transitional view over the landmarks[] data until the Old Pine maps read
## them directly.
const PINE_LANDMARK_ID: StringName = &"oldpine.outdoor.landmark.ancient_pine"
const TREE1_DESCENT_LANDMARK_ID: StringName = (
	&"oldpine.outdoor.landmark.tree1_descent"
)
const VINE_LANDMARK_ID: StringName = &"oldpine.outdoor.landmark.epath2_vine"
const RIVERBANK_CLIFF_LANDMARK_ID: StringName = (
	&"oldpine.outdoor.landmark.riverbank1_cliff"
)
const CLIFF1_DOWN_LANDMARK_ID: StringName = (
	&"oldpine.outdoor.landmark.cliff1_down"
)
const CLIFF1_UP_LANDMARK_ID: StringName = &"oldpine.outdoor.landmark.cliff1_up"


static func definitions() -> Array[WorldLandmarkDefinition]:
	var result: Array[WorldLandmarkDefinition] = []
	for id: StringName in [PINE_LANDMARK_ID, TREE1_DESCENT_LANDMARK_ID, RIVERBANK_CLIFF_LANDMARK_ID, CLIFF1_DOWN_LANDMARK_ID, CLIFF1_UP_LANDMARK_ID]:
		result.append(GameContent.catalog().landmark(id))
	return result


static func definition_by_id(landmark_id: StringName) -> WorldLandmarkDefinition:
	for definition: WorldLandmarkDefinition in definitions():
		if definition != null and definition.landmark_id == landmark_id:
			return definition
	return null


static func vine_definition() -> OldPineVineInteractionDefinition:
	var vine: WorldLandmarkDefinition = GameContent.catalog().landmark(VINE_LANDMARK_ID)
	if vine == null:
		return OldPineVineInteractionDefinition.new()
	return OldPineVineInteractionDefinition.new(
		vine.landmark_id,
		vine.display_name,
		vine.description,
		vine.action_label,
		&"vine",
		vine.legacy_source_path,
		vine.message("hold"),
		vine.message("fall"),
		vine.message("fall_observer"),
		vine.message("climb"),
		vine.message("climb_observer"),
		vine.portal_ids()[0],
		vine.portal_ids()[1],
	)


static func validate() -> bool:
	for definition: WorldLandmarkDefinition in definitions():
		if definition == null or not definition.is_valid():
			return false
	return vine_definition().is_valid()
