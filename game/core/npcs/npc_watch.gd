class_name NpcWatch
extends RefCounted

## Native (第九章 B, 剧情总纲 §6 皇城卡「夜里禁军巡逻——这是本作唯一的潜行区」; DECISIONS「禁军夜巡」): an NPC that
## keeps a watch — it walks its `route` (the map's markers, there and back, resting `pause_ms` at each) and
## looks ahead of itself: a cone of `cone_degrees` out to `radius` pixels, out to `lit_radius` when the player
## stands in a light (a layout piece whose look carries `light`, or within `lantern` of a watcher, who carries
## one); walls and the pieces whose look carries `cover` stop its eye. A player in sight for `notice_ms` is
## noticed (a ？ over its head while it looks, ！ when it has them); out of sight before that, it forgets.
## Noticed, they are caught, not fought: it says `say`, the player marks `mark` (or `again_mark` and
## `again_lines` the second time, the first time's `lines`), the world clock goes on to the next of
## `until_phase` (the night spent in the 侍卫营) and they are put out at `release_zone` / `release_point`.
## The watch keeps only while its `when` holds (the night) and never while `unless` holds (a 腰牌 at the
## belt). Pacing's `stealth` off (经典) it is ES2's presence: any player within `radius`, any side, seen
## through anything, caught at once.
var route: Array[StringName] = []
var pause_ms: int = 2000
var radius: int = 160
var cone_degrees: int = 100
var lit_radius: int = 260
var lantern: int = 72
var notice_ms: int = 1200
var when: JournalEntryDefinition = null
var unless: JournalEntryDefinition = null
var say: String = ""
var mark: String = ""
var again_mark: String = ""
var lines: Array[String] = []
var again_lines: Array[String] = []
var release_zone_id: StringName = &""
var release_point_id: StringName = &""
var until_phase: Array[StringName] = []


func is_valid() -> bool:
	return (
		route.size() >= 1 and pause_ms >= 0 and radius > 0 and cone_degrees > 0 and cone_degrees <= 360
		and lit_radius >= radius and lantern >= 0 and notice_ms >= 0 and not mark.is_empty()
		and not release_zone_id.is_empty() and not release_point_id.is_empty()
	)


## Whether the point `to` lies in the cone `facing` looks along from `from`, within `reach`.
func sees_direction(from: Vector2, facing: Vector2, to: Vector2, reach: float, stealth: bool) -> bool:
	var offset: Vector2 = to - from
	if offset.length() > reach:
		return false
	if not stealth or cone_degrees >= 360 or offset.length_squared() < 1.0:
		return true
	var ahead: Vector2 = facing.normalized() if facing.length_squared() > 0.0 else Vector2.DOWN
	return absf(rad_to_deg(ahead.angle_to(offset))) <= cone_degrees / 2.0


## {route: [marker], pause_ms?, sight: {radius, cone_degrees?, lit_radius?, lantern?}, notice_ms?, when?,
## unless?, caught: {say?, mark, again_mark?, lines?, again_lines?, release_zone, release_point, until_phase?}}.
static func from_record(reader: ContentRecordReader) -> NpcWatch:
	var watch := NpcWatch.new()
	for point: String in reader.text_list("route"):
		watch.route.append(StringName(point))
	watch.pause_ms = reader.integer("pause_ms", 2000)
	var sight: ContentRecordReader = reader.child("sight")
	if sight != null:
		watch.radius = sight.integer("radius", 160)
		watch.cone_degrees = sight.integer("cone_degrees", 100)
		watch.lit_radius = sight.integer("lit_radius", watch.radius)
		watch.lantern = sight.integer("lantern", 72)
		sight.finish()
	watch.notice_ms = reader.integer("notice_ms", 1200)
	if reader.has("when"):
		watch.when = JournalEntryDefinition.new()
		JournalEntryDefinition.read_when(reader, watch.when, "when")
	if reader.has("unless"):
		watch.unless = JournalEntryDefinition.new()
		JournalEntryDefinition.read_when(reader, watch.unless, "unless")
	var caught: ContentRecordReader = reader.child("caught")
	if caught == null:
		reader.fail("caught", "expected an object")
	else:
		watch.say = caught.text("say")
		watch.mark = caught.required_text("mark")
		watch.again_mark = caught.text("again_mark")
		watch.lines = caught.text_list("lines")
		watch.again_lines = caught.text_list("again_lines")
		watch.release_zone_id = StringName(caught.required_text("release_zone"))
		watch.release_point_id = StringName(caught.required_text("release_point"))
		for phase: String in caught.text_list("until_phase"):
			watch.until_phase.append(StringName(phase))
		caught.finish()
	reader.finish()
	if not watch.is_valid():
		reader.fail("", "needs a route, a sight within reason, a mark and where the caught are put out")
	return watch
