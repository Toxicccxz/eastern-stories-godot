class_name OldPineLandmarkDefinitions
extends RefCounted

const PINE_LANDMARK_ID: StringName = &"oldpine.outdoor.landmark.ancient_pine"
const TREE1_DESCENT_LANDMARK_ID: StringName = (
	&"oldpine.outdoor.landmark.tree1_descent"
)
const VINE_LANDMARK_ID: StringName = &"oldpine.outdoor.landmark.epath2_vine"


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


static func vine_definition() -> OldPineVineInteractionDefinition:
	return OldPineVineInteractionDefinition.new(
		VINE_LANDMARK_ID,
		"藤蔓",
		"其中有一根藤蔓距离你比较近，你可以试著抓住(hold)藤蔓，看看\n"
		+ "能不能像泰山一样荡过去，看看瀑布后面有什么？\n"
		+ "对了，提醒你一点，这座石桥下面是高约百丈的山涧深谷....。\n",
		"Hold vine",
		&"vine",
		"d/oldpine/epath2.c",
		"你爬上石桥的护栏，伸手往不远处的一根藤蔓抓去....",
		"只听见一声杀猪般的惨叫，你已经往山涧中坠了下去。",
		"你听到有人高声惊叫，一条人影从上方掉了下来，「扑通」一声跌进潭中。",
		"你手脚俐落地攀附著藤蔓，慢慢地爬下山涧....。",
		"忽然一条人影从南边的帘幕穿了出来。",
		OldPineWorldDefinitions.VINE_WATERFALL_PORTAL_ID,
		OldPineWorldDefinitions.VINE_PASSAGE_PORTAL_ID,
	)


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
	var vine: OldPineVineInteractionDefinition = vine_definition()
	return (
		vine.is_valid()
		and not seen.has(vine.interaction_id)
		and OldPineWorldDefinitions.portal_by_id(vine.waterfall_portal_id) != null
		and OldPineWorldDefinitions.portal_by_id(vine.passage_portal_id) != null
	)
