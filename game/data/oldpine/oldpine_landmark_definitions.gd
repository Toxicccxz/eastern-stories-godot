class_name OldPineLandmarkDefinitions
extends RefCounted

const PINE_LANDMARK_ID: StringName = &"oldpine.outdoor.landmark.ancient_pine"
const TREE1_DESCENT_LANDMARK_ID: StringName = (
	&"oldpine.outdoor.landmark.tree1_descent"
)


static func definitions() -> Array[WorldLandmarkDefinition]:
	return [
		WorldLandmarkDefinition.new(
			PINE_LANDMARK_ID,
			"大松树",
			"一株又高又大的松树，当你抬头往上看的时候似乎有个人影\n"
			+ "在树梢之间移动，不过也许是风吹动所造成的错觉。\n",
			OldPineWorldDefinitions.CLIMB_PINE_PORTAL_ID,
			"Climb",
			"d/oldpine/clearing.c",
		),
		WorldLandmarkDefinition.new(
			TREE1_DESCENT_LANDMARK_ID,
			"大松树上",
			"你现在正攀附在一株大松树的树干上，从这里可以很清楚地望见树\n"
			+ "下的一切动静，而不被人发觉，似乎是个干偷鸡摸狗勾当的好地方。\n",
			OldPineWorldDefinitions.DESCEND_TREE1_PORTAL_ID,
			"Descend",
			"d/oldpine/tree1.c",
		),
	]


static func definition_by_id(landmark_id: StringName) -> WorldLandmarkDefinition:
	for definition: WorldLandmarkDefinition in definitions():
		if definition.landmark_id == landmark_id:
			return definition
	return null


static func validate() -> bool:
	var seen: Dictionary[StringName, bool] = {}
	for definition: WorldLandmarkDefinition in definitions():
		if (
			definition == null
			or not definition.is_valid()
			or seen.has(definition.landmark_id)
			or OldPineWorldDefinitions.portal_by_id(definition.portal_id) == null
		):
			return false
		seen[definition.landmark_id] = true
	return true
