extends RefCounted

## NPC 活起来 A (owner, 2026-11-06「按推荐，开工 A」; DECISIONS「街上的人会动」):
## - data: every 雪亭镇 person has an npc_life.json entry; the file's entries parse; a bad one
##   is refused; pacing's npc_idle on, 经典 off.
## - on 雪亭镇's street with the player far off: a farmer (work) strolls about sroad2 and only
##   there, near its own spot, never into a doorway or the street's mouth, keeps its room; the
##   gate's 刘安禄 (post) never leaves his spot but looks about; the player walks up: the farmer
##   stops and turns to them; 经典: nobody moves.

const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const SouthRoad := preload("res://tests/runtime/snow_south_road_test.gd")
const MapPlaces := preload("res://tests/support/map_places.gd")
const Person := preload("res://presentation/voxel/actors/voxel_person.gd")
## No entry: they never stir (statues, one frozen in ice).
const NOT_STIRRING: Array[StringName] = [&"latemoon.npc.room.fireangel", &"latemoon.npc.upstar.statue", &"native.npc.lihong"]
const FARMER: StringName = &"snow.sroad2.farmer.1.character"
const GUARD: StringName = &"snow.school1.guard.1.character"

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_data()
	await _test_person(tree)
	var session: WorldSessionController = Work.create_session(tree)
	for frame: int in 4:
		await tree.process_frame
	session.set_process(false)
	session.configure_npc_ambience_random_source(SouthRoad.Still.new()) # TEST-ONLY: nobody chats or changes room
	await _test_street(tree, session)
	session.free()
	await tree.process_frame
	return {"assertions": _count, "failures": _failures.duplicate()}


func _test_data() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	# Everyone has an entry (B: every region), but those who walk their own way (a patrol, a
	# night watch) and those who never stir (the training dummies, the two spirit statues, 璃虹
	# in her ice pillar).
	var missing: Array[StringName] = []
	for definition: NpcDefinition in catalog.npcs():
		var id: StringName = NpcDefinition.unnamed_id(definition.definition_id)
		if definition.dealings().patrol != null or definition.dealings().watch != null or NOT_STIRRING.has(id) or String(id).begins_with("native.npc.wooden_dummy."):
			_check(NpcLifeBook.entry(id) == null or definition.dealings().patrol == null, "%s keeps its own walk" % id)
			continue
		if NpcLifeBook.entry(id) == null and not missing.has(id):
			missing.append(id)
	_check(missing.is_empty(), "everyone has a life entry (missing %s)" % [missing])
	for id: StringName in NOT_STIRRING:
		_check(NpcLifeBook.entry(id) == null, "%s never stirs" % id)
	_check(NpcLifeBook.entry(&"native.npc.wooden_dummy.1") == null, "a training dummy never stirs")
	_check(NpcLifeBook.entry(&"waterfog.npc.servant").gesture == "chop" and NpcLifeBook.entry(&"temple.npc.guard_taoist1").mode == NpcLifeBook.Mode.POST and NpcLifeBook.entry(&"native.npc.storyteller").pose == "sit_ground", "a few by hand: 柴房's servant chops, 藏经楼's guards keep their post, the old storyteller sits on his felt")
	_check(NpcLifeBook.entry(&"snow.npc.guard").mode == NpcLifeBook.Mode.POST, "the gate's 刘安禄 keeps his post")
	_check(NpcLifeBook.entry(&"snow.npc.herbalist").mode == NpcLifeBook.Mode.STILL, "杨掌柜 stays at his counter")
	_check(NpcLifeBook.entry(&"snow.npc.traveller").mode == NpcLifeBook.Mode.WANDER, "a traveller wanders")
	var smith: NpcLifeBook.Entry = NpcLifeBook.entry(&"snow.npc.smith")
	_check(smith.mode == NpcLifeBook.Mode.WORK and smith.reach(120) == 32 and smith.gesture == "hammer", "王铁匠 hammers by his forge (32 px)")
	_check(NpcLifeBook.entry(&"snow.npc.beggar").pose == "sit_ground", "the beggar sits on the ground")
	for gesture: String in NpcLifeBook.GESTURES:
		_check(Person.GESTURE_SECONDS.has(gesture), "the voxel person plays %s" % gesture)
	_check(NpcLifeBook.parse("work").reach(120) == NpcLifeBook.WORK_RADIUS_PX and NpcLifeBook.parse("wander").reach(120) == 120, "a work entry stays nearer its spot than a wanderer")
	for bad: Variant in ["dance", {"mode": "wander", "radius": -4}, {"mode": "wander", "pace": 3}, 7, {"mode": "post", "gesture": "hoe"}, {"mode": "wander", "pose": "sit"}, {"mode": "work", "gesture": "juggle"}, {"mode": "still", "pose": "lie_down"}]:
		var problem: Array[String] = []
		_check(NpcLifeBook.parse(bad, problem) == null and not problem.is_empty(), "refused: %s" % [bad])
	_check(NpcLifeBook.entry(&"nobody") == null and NpcLifeBook.entry(&"oldpine.npc.nobody") == null, "no entry: stays put")
	var pacing: PacingDefinition = catalog.pacing()
	_check(pacing.npc_idle.enabled and pacing.npc_idle.speed_px > 0 and pacing.npc_idle.stop_reach_px > 0, "people move about (pacing npc_idle on)")
	_check(not PacePresets.of(pacing, CharacterState.PACE_CLASSIC).npc_idle.enabled, "经典: they stand where they were put")
	_check(pacing.copy().npc_idle == pacing.npc_idle, "a copy of the pacing keeps its npc_idle")


## The voxel person: a gesture's tool in an empty hand (not over the look's own), the arms at
## work and still while it attends to the player; a stool under one that sits, gone as it walks.
func _test_person(tree: SceneTree) -> void:
	var smith: Person = Person.new()
	smith.configure({"coat": "5a4a3a"})
	smith.activity("hammer", "stand")
	tree.root.add_child(smith)
	_check(smith.drawn.has("prop:hammer"), "a smith at work holds a hammer")
	var lifted: bool = false
	for frame: int in 40:
		smith._process(0.05)
		lifted = lifted or smith.arms[0].rotation.x < -1.5
	_check(lifted, "the hammer goes up and down")
	smith.working = false
	smith._process(0.05)
	_check(smith.arms[0].rotation.x > -0.2, "attending to the player, the smith puts the hammer down")
	smith.free()
	var carrier: Person = Person.new()
	carrier.configure({"prop": "staff"})
	carrier.activity("hoe", "stand")
	tree.root.add_child(carrier)
	_check(carrier.drawn.has("prop:staff") and not carrier.drawn.has("prop:hoe"), "a look's own prop in the hand stays, no tool")
	carrier.free()
	var gardener: Person = Person.new()
	gardener.configure({"prop": "sword_waist"})
	gardener.activity("hoe", "stand")
	tree.root.add_child(gardener)
	_check(gardener.drawn.has("prop:sword_waist") and gardener.drawn.has("prop:hoe"), "a sword at the waist leaves the hand free for the hoe")
	gardener.at_ease = false
	gardener._process(0.05)
	_check(gardener.arms[0].rotation.x > -0.2, "fighting or senseless, nobody works")
	gardener.free()
	var sitter: Person = Person.new()
	sitter.configure({})
	sitter.activity("", "sit")
	tree.root.add_child(sitter)
	sitter._process(0.05)
	_check(sitter.drawn.has("pose:sit") and sitter._seat != null and sitter._seat.visible and sitter.legs[0].rotation.x < -1.0 and sitter.torso.position.y < -0.1, "one that sits sits low on a stool, legs forward")
	sitter.walking = true
	sitter._process(0.05)
	_check(not sitter._seat.visible and sitter.torso.position.y > -0.1, "walking, it stands up and leaves the stool")
	sitter.walking = false
	sitter.at_ease = false
	sitter._process(0.05)
	_check(not sitter._seat.visible and sitter.torso.position.y > -0.1 and absf(sitter.legs[0].rotation.x) < 0.01, "knocked senseless, it lies as anyone does (no stool, legs straight)")
	sitter.free()


func _test_street(tree: SceneTree, session: WorldSessionController) -> void:
	var map: WorldMapController = await MapPlaces.go_to(tree, session, &"snow.square")
	_check(map != null and map.map_id() == &"snow.outdoor", "out on the street (the square)")
	if map == null:
		return
	var farmer: NpcRuntimeState = map.find_resident_npc(FARMER)
	var guard: NpcRuntimeState = map.find_resident_npc(GUARD)
	_check(farmer != null and guard != null, "the farmer and 刘安禄 are out")
	if farmer == null or guard == null:
		return
	var farmer_body: WorldCharacterBody2D = map.runtime_body_for_character(FARMER)
	var guard_body: WorldCharacterBody2D = map.runtime_body_for_character(GUARD)
	var home: Vector2 = farmer_body.global_position
	var post: Vector2 = guard_body.global_position
	var post_facing: Vector2 = guard_body.facing
	var tuning: NpcIdleTuning = GameContent.catalog().pacing().npc_idle
	var reach: float = float(NpcLifeBook.entry(&"snow.npc.farmer").reach(tuning.home_radius_px))
	var sroad2: Rect2 = MapPlaces.zone_rect(map, &"snow.sroad2")
	var farthest: float = 0.0
	var strolled: bool = false
	var guard_still: bool = true
	var guard_looked: bool = false
	var in_room: bool = true
	var near_home: bool = true
	var on_spots: bool = true
	var froze_in_place: bool = false
	var marker: WorldSpawnMarker2D = map.resolve_spawn_marker(farmer.spawn_point_id)
	_check(marker != null and home.distance_to(marker.global_position) < 1.0, "the farmer starts on its spawn marker")
	for second: int in 90:
		session.advance_npc_heartbeat(0.5)
		await tree.physics_frame
		strolled = strolled or map.npc_life.npc_walker().is_strolling(FARMER)
		farthest = maxf(farthest, farmer_body.global_position.distance_to(home))
		in_room = in_room and farmer.world_location().zone_id == &"snow.sroad2" and sroad2.has_point(farmer_body.global_position)
		near_home = near_home and farmer_body.global_position.distance_to(home) <= reach + WorldNpcWalker.CELL
		guard_still = guard_still and guard_body.global_position.distance_to(post) < 1.0
		guard_looked = guard_looked or not guard_body.facing.is_equal_approx(post_facing)
		# Wherever a stroll is stopped, the body may stand there (and a save keep it).
		on_spots = on_spots and _off_seams(map, farmer_body.global_position, &"snow.sroad2") and MapPlacementValidator.is_valid_character_position(map, &"snow.sroad2", farmer_body.global_position)
		if not froze_in_place and second > 40 and map.npc_life.npc_walker().is_strolling(FARMER):
			# A fight begins (freeze_world_gameplay finishes the walks): a stroll stops where it is.
			var at: Vector2 = farmer_body.global_position
			map.npc_life.npc_walker().finish_all()
			froze_in_place = farmer_body.global_position.distance_to(at) < 0.5 and not map.npc_life.npc_walker().is_walking(FARMER)
	_check(strolled and farthest > float(tuning.stroll_min_px) * 0.5, "the farmer strolls about (%.0f px at most)" % farthest)
	_check(in_room, "the farmer stays in sroad2")
	_check(near_home, "the farmer stays near its own spot (%.0f px)" % reach)
	_check(on_spots, "every spot of the farmer's strolls is off the street's mouths and free")
	_check(froze_in_place, "a stroll stopped by finish_all() stays where it is (no jump)")
	_check(guard_still and guard_looked, "刘安禄 keeps his spot and looks about")
	# The player leaves the map: a post faces its own way again; home stays the marker.
	map.npc_idle.clear()
	_check(guard_body.facing.is_equal_approx(post_facing), "刘安禄 faces his own way again when the player is gone")
	# The player walks up: the farmer stops and turns to them.
	map.npc_life.npc_walker().finish_all()
	var by: Vector2 = MapPlaces.spot(map, &"snow.sroad2", farmer_body.global_position, float(tuning.stop_reach_px) - 8.0)
	map.player_body.global_position = by # TEST-ONLY: set beside the farmer (the walk there is no part of it)
	await tree.physics_frame
	var stood: Vector2 = farmer_body.global_position
	var stayed: bool = true
	for second: int in 30:
		session.advance_npc_heartbeat(0.5)
		await tree.physics_frame
		stayed = stayed and not map.npc_life.npc_walker().is_strolling(FARMER) and farmer_body.global_position.distance_to(stood) < 1.0
	var toward: Vector2 = (map.player_body.global_position - farmer_body.global_position).normalized()
	_check(stood.distance_to(by) <= float(tuning.stop_reach_px), "the player stands within reach (%.0f px)" % stood.distance_to(by))
	_check(stayed and farmer_body.facing.dot(toward) > 0.7, "the farmer stops and turns to the player")
	# 经典: nobody moves.
	var pacing: PacingDefinition = GameContent.catalog().pacing()
	var kept: NpcIdleTuning = pacing.npc_idle
	pacing.npc_idle = NpcIdleTuning.new() # TEST-ONLY: 经典 as PacePresets.of() makes it, put back below
	map.player_body.global_position = MapPlaces.zone_centre(map, &"snow.square") # TEST-ONLY: far off again
	# Strolls under way stop (the pace is chosen at New Game, before anyone strolls).
	map.npc_life.npc_walker().finish_all()
	await tree.physics_frame
	var places: Dictionary[StringName, Vector2] = {}
	for npc: NpcRuntimeState in map.npc_runtimes():
		places[npc.character_id] = map.runtime_body_for_character(npc.character_id).global_position
	for second: int in 40:
		session.advance_npc_heartbeat(0.5)
		await tree.physics_frame
	pacing.npc_idle = kept
	var moved: Array[StringName] = []
	for character_id: StringName in places:
		var body: Node2D = map.runtime_body_for_character(character_id)
		if body != null and body.global_position.distance_to(places[character_id]) > 1.0:
			moved.append(character_id)
	_check(moved.is_empty(), "经典: nobody moves (%s)" % [moved])


## Whether `point` keeps WorldNpcWalker.SEAM_CLEAR from where `zone_id` meets the map's other
## zones (the street's mouths).
func _off_seams(map: WorldMapController, point: Vector2, zone_id: StringName) -> bool:
	var own: Rect2 = MapPlaces.zone_rect(map, zone_id)
	for zone: WorldPhysicalZoneArea2D in map.physical_zones():
		if zone.zone_id != zone_id and zone.global_rect().grow(1.0).intersects(own) and zone.global_rect().grow(WorldNpcWalker.SEAM_CLEAR - 1.0).has_point(point):
			return false
	return true


func _check(condition: bool, message: String) -> void:
	_count += 1
	if not condition:
		_failures.append(message)
