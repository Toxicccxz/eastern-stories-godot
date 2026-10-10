class_name NpcPatrol
extends RefCounted

## A constable's beat (d/choyin/npc/yamen_po.c's BigWay and patrol(), repaired: owner,
## DECISIONS 乔阴 A Q1): the zones of its route in order, walked one each time its chat calls
## patrol() — forward (GO, away from the 衙门) to the far end, then back (BACK) — and its
## catch (`arrest`, NpcArrest). BigWay went on past the 北门 into other regions and missed
## s_street3; the route keeps to the town's main street and goes through it.
var route: Array[StringName] = []
var arrest: NpcArrest


## The zone after `zone_id` going back (toward the route's start) or forward; &"" at that end
## (BigWay's 0) or off the route.
func next_zone(zone_id: StringName, back: bool) -> StringName:
	var index: int = route.find(zone_id)
	if index < 0:
		return &""
	var next: int = index - 1 if back else index + 1
	return route[next] if next >= 0 and next < route.size() else &""


func is_valid() -> bool:
	if route.size() < 2 or arrest == null or not arrest.is_valid():
		return false
	for zone_id: StringName in route:
		if zone_id.is_empty() or route.count(zone_id) != 1:
			return false
	return true


## {route: [zone], arrest: NpcArrest}.
static func from_record(reader: ContentRecordReader) -> NpcPatrol:
	var patrol := NpcPatrol.new()
	for zone_id: String in reader.text_list("route"):
		patrol.route.append(StringName(zone_id))
	var arrest: ContentRecordReader = reader.child("arrest")
	if arrest != null:
		patrol.arrest = NpcArrest.from_record(arrest)
	reader.finish()
	if not patrol.is_valid():
		reader.fail("", "needs a route of two or more distinct zones and an arrest")
	return patrol
